extends Node
## The Morse heart of the game. Pure logic, no scene state:
##   - International Morse codec (encode / decode)
##   - PARIS-standard WPM timing and tone timelines for AudioDirector
##   - classification of the player's hand keying back into symbols
##   - steadiness-driven jitter ("calm hands produce cleaner Morse")
##   - fidelity scoring of a sent message vs. what was intended
##
## Units follow the standard: a "dit" is 1 time unit, a "dah" is 3, the gap
## inside a character is 1, between characters 3, between words 7.

const DEFAULT_WPM: float = 12.0  ## novice field-operator speed

## International Morse. Letters, digits, common punctuation, and a few prosigns.
const TABLE := {
	"A": ".-", "B": "-...", "C": "-.-.", "D": "-..", "E": ".",
	"F": "..-.", "G": "--.", "H": "....", "I": "..", "J": ".---",
	"K": "-.-", "L": ".-..", "M": "--", "N": "-.", "O": "---",
	"P": ".--.", "Q": "--.-", "R": ".-.", "S": "...", "T": "-",
	"U": "..-", "V": "...-", "W": ".--", "X": "-..-", "Y": "-.--",
	"Z": "--..",
	"0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
	"5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----.",
	".": ".-.-.-", ",": "--..--", "?": "..--..", "'": ".----.",
	"!": "-.-.--", "/": "-..-.", "(": "-.--.", ")": "-.--.-",
	"&": ".-...", ":": "---...", ";": "-.-.-.", "=": "-...-",
	"+": ".-.-.", "-": "-....-", "_": "..--.-", "\"": ".-..-.",
	"@": ".--.-.",
	# Prosigns used in traffic; kept as readable tokens.
	"<AR>": ".-.-.", "<SK>": "...-.-", "<BT>": "-...-", "<KN>": "-.--.",
	"<SOS>": "...---...",
}

var _decode_table: Dictionary = {}


func _ready() -> void:
	for key in TABLE:
		_decode_table[TABLE[key]] = key


## Milliseconds in one Morse time unit (a dit) at the given speed.
func unit_ms(wpm: float = DEFAULT_WPM) -> float:
	return 1200.0 / maxf(wpm, 1.0)


# --- Encoding ------------------------------------------------------------

## Morse for a single character, or "" if unknown. Case-insensitive.
func encode_char(c: String) -> String:
	return TABLE.get(c.to_upper(), "")


## Encode plain text to canonical Morse: characters separated by " ",
## words separated by " / ".  Unknown characters are skipped.
func encode(text: String) -> String:
	var words: PackedStringArray = []
	for word in text.strip_edges().to_upper().split(" ", false):
		var letters: PackedStringArray = []
		for i in word.length():
			var code := encode_char(word[i])
			if code != "":
				letters.append(code)
		if not letters.is_empty():
			words.append(" ".join(letters))
	return " / ".join(words)


# --- Decoding ------------------------------------------------------------

## Decode canonical Morse ("-.-. --- -.. . / .-- ---") back to text.
## "/" (optionally surrounded by spaces) marks a word boundary. Unknown
## tokens become "#" so corruption stays visible to the player.
func decode(morse: String) -> String:
	var out := ""
	var normalized := morse.strip_edges().replace("/", " / ")
	for token in normalized.split(" ", false):
		if token == "/":
			out += " "
		elif _decode_table.has(token):
			out += _decode_table[token]
		else:
			out += "#"
	return out


# --- Timelines (for AudioDirector / animation) ---------------------------

## Build a tone timeline for `text`: an ordered Array of segments
## { "on": bool, "ms": float, "sym": String }. `on` segments are tones whose
## `sym` is "." or "-"; off segments are gaps whose `sym` is
## "intra" / "char" / "word".
func build_timeline(text: String, wpm: float = DEFAULT_WPM) -> Array:
	var u := unit_ms(wpm)
	var segments: Array = []
	var words := text.strip_edges().to_upper().split(" ", false)
	for wi in words.size():
		var word: String = words[wi]
		var first_char := true
		for ci in word.length():
			var code := encode_char(word[ci])
			if code == "":
				continue
			if not first_char:
				segments.append({"on": false, "ms": 3.0 * u, "sym": "char"})
			first_char = false
			for si in code.length():
				var symbol := code[si]
				var length := (3.0 if symbol == "-" else 1.0) * u
				segments.append({"on": true, "ms": length, "sym": symbol})
				if si < code.length() - 1:
					segments.append({"on": false, "ms": u, "sym": "intra"})
		if wi < words.size() - 1:
			segments.append({"on": false, "ms": 7.0 * u, "sym": "word"})
	return segments


## Total duration of a timeline in seconds.
func timeline_seconds(timeline: Array) -> float:
	var ms := 0.0
	for seg in timeline:
		ms += seg["ms"]
	return ms / 1000.0


# --- Hand keying ---------------------------------------------------------

## Perturb captured (or generated) key events by how unsteady the hand is.
## steadiness 1.0 leaves timing clean; lower values stretch/compress
## durations and, when very low, occasionally drop or split a tone so the
## message itself degrades — not just a hidden score.
## Each event is { "on": bool, "ms": float, ... }.
func apply_jitter(events: Array, steadiness: float) -> Array:
	var s := clampf(steadiness, 0.0, 1.0)
	var spread := (1.0 - s) * 0.6          # up to +/-60% timing wobble
	var glitch := (1.0 - s) * 0.15         # chance to drop/split a tone
	var out: Array = []
	for e in events:
		var ms: float = e["ms"]
		ms *= 1.0 + randf_range(-spread, spread)
		ms = maxf(ms, 1.0)
		var copy := {"on": e["on"], "ms": ms, "sym": e.get("sym", "")}
		if e["on"] and randf() < glitch:
			# A shaking hand: sometimes the contact drops mid-tone (split)
			# or barely registers (drop).
			if randf() < 0.5:
				continue  # dropped tone
			var half := copy.duplicate()
			half["ms"] = ms * 0.45
			out.append(half)
			out.append({"on": false, "ms": ms * 0.2, "sym": "intra"})
			copy["ms"] = ms * 0.35
		out.append(copy)
	return out


## Classify a stream of raw key on/off events back into Morse and text.
## `events` is an ordered Array of { "on": bool, "ms": float }. If `wpm_hint`
## is 0 the dit length is estimated from the shortest tone. Returns
## { "morse": String, "text": String, "unit_ms": float }.
func classify_keying(events: Array, wpm_hint: float = 0.0) -> Dictionary:
	var u := unit_ms(wpm_hint) if wpm_hint > 0.0 else _estimate_unit(events)
	var morse := ""
	for e in events:
		var ms: float = e["ms"]
		if e["on"]:
			morse += "-" if ms >= 2.0 * u else "."
		else:
			if ms >= 5.0 * u:
				morse += " / "
			elif ms >= 2.0 * u:
				morse += " "
			# else: intra-character gap, no separator
	return {
		"morse": morse,
		"text": decode(morse),
		"unit_ms": u,
	}


## Fidelity of a produced message against what was intended, 0..1. Blends how
## close the decoded text is (most of the weight) with how regular the keying
## rhythm was (a clean fist reads better even when letters survive).
func score_fidelity(intended_text: String, produced_text: String, events: Array = []) -> float:
	var text_match := _string_similarity(
		intended_text.strip_edges().to_upper(),
		produced_text.strip_edges().to_upper())
	var rhythm := _rhythm_consistency(events)
	return clampf(0.8 * text_match + 0.2 * rhythm, 0.0, 1.0)


## Convenience: simulate keying `text` at a given hand steadiness without a
## live player, for testing and the simple "send" path in RadioUI. Returns
## { "text", "morse", "fidelity", "duration" (seconds) }.
func simulate_send(text: String, steadiness: float, wpm: float = DEFAULT_WPM) -> Dictionary:
	var clean := build_timeline(text, wpm)
	var keyed := apply_jitter(clean, steadiness)
	var result := classify_keying(keyed, wpm)
	return {
		"text": result["text"],
		"morse": result["morse"],
		"fidelity": score_fidelity(text, result["text"], keyed),
		"duration": timeline_seconds(keyed),
	}


# --- Internals -----------------------------------------------------------

func _estimate_unit(events: Array) -> float:
	var shortest := INF
	for e in events:
		if e["on"]:
			shortest = minf(shortest, e["ms"])
	return shortest if shortest < INF else unit_ms()


## Lower coefficient of variation among same-class tones => steadier rhythm.
func _rhythm_consistency(events: Array) -> float:
	var ons: Array[float] = []
	for e in events:
		if e["on"]:
			ons.append(e["ms"])
	if ons.size() < 2:
		return 1.0
	var mean := 0.0
	for v in ons:
		mean += v
	mean /= ons.size()
	if mean <= 0.0:
		return 1.0
	var variance := 0.0
	for v in ons:
		variance += (v - mean) * (v - mean)
	variance /= ons.size()
	var cv := sqrt(variance) / mean
	return clampf(1.0 - cv, 0.0, 1.0)


## Normalized Levenshtein similarity, 0 (different) .. 1 (identical).
func _string_similarity(a: String, b: String) -> float:
	if a == b:
		return 1.0
	var la := a.length()
	var lb := b.length()
	if la == 0 or lb == 0:
		return 0.0
	var prev: Array[int] = []
	prev.resize(lb + 1)
	for j in lb + 1:
		prev[j] = j
	for i in range(1, la + 1):
		var curr: Array[int] = []
		curr.resize(lb + 1)
		curr[0] = i
		for j in range(1, lb + 1):
			var cost := 0 if a[i - 1] == b[j - 1] else 1
			curr[j] = mini(mini(prev[j] + 1, curr[j - 1] + 1), prev[j - 1] + cost)
		prev = curr
	var dist := float(prev[lb])
	return 1.0 - dist / float(maxi(la, lb))
