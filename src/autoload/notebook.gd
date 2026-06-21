extends Node
## The player's NOTEBOOK: their *record* of the world — transcripts, map marks,
## patrol notes, mission details, radio diagrams, wound records, observations.
##
## It is also a horror object. Under stress the SymptomSystem calls the
## corruption hooks here and the record changes *silently*: a coordinate drifts,
## a patrol marking shifts, a dead squadmate's name appears in the margin, a
## transcript gains a line no one sent. The notebook never flags these to the
## player — deciding what to trust is the game. (notebook_corrupted is emitted
## only for systems/telemetry, not for the UI to highlight.)

enum Kind {
	MORSE_TRANSCRIPT, MAP_MARK, PATROL_NOTE, SKETCH,
	MISSION, RADIO_DIAGRAM, WOUND_RECORD, OBSERVATION, PERSONAL,
}

enum Trust { RELIABLE, UNCERTAIN, CORRUPTED }

enum Corruption {
	COORDINATE_DRIFT, PATROL_SHIFT, DEAD_NAME, IMPOSSIBLE_PHRASE, PHANTOM_ENTRY,
}

const _IMPOSSIBLE_PHRASES := [
	"THEY ARE STILL DROPPING",
	"WE NEVER LANDED",
	"COME BACK FOR US",
	"YOU LEFT US IN THE SNOW",
	"STATION SILENT SINCE DAY ZERO",
	"DO NOT ANSWER THE SECOND VOICE",
]
const _DIRECTIONS := ["NORTH", "SOUTH", "EAST", "WEST"]

## Names of fallen squadmates, set by GameState so DEAD_NAME corruption can use
## the people the player actually lost.
var dead_names: PackedStringArray = []

var _entries: Array = []
var _next_id: int = 1


# --- Recording -----------------------------------------------------------

## Add an entry and return it. `data` carries structured extras (coordinates,
## morse, recon payloads). Returns the stored Dictionary.
func add_entry(kind: Kind, title: String, body: String, data: Dictionary = {}, trust: Trust = Trust.RELIABLE) -> Dictionary:
	var entry := {
		"id": _next_id,
		"kind": kind,
		"title": title,
		"body": body,
		"stamp": GameClock.stamp(),
		"trust": trust,
		"data": data,
	}
	_next_id += 1
	_entries.append(entry)
	EventBus.notebook_entry_added.emit(entry)
	return entry


func entries() -> Array:
	return _entries


func by_kind(kind: Kind) -> Array:
	return _entries.filter(func(e): return e["kind"] == kind)


func clear() -> void:
	_entries.clear()
	_next_id = 1


# --- Corruption (called by SymptomSystem under stress) -------------------

## Apply a random plausible corruption. Returns the kind applied, or -1 if
## nothing could be corrupted.
func corrupt_random() -> int:
	var kind: int = [
		Corruption.COORDINATE_DRIFT, Corruption.PATROL_SHIFT,
		Corruption.DEAD_NAME, Corruption.IMPOSSIBLE_PHRASE,
		Corruption.PHANTOM_ENTRY,
	].pick_random()
	return corrupt(kind)


func corrupt(kind: Corruption) -> int:
	var entry: Dictionary
	match kind:
		Corruption.COORDINATE_DRIFT:
			entry = _drift_coordinate()
		Corruption.PATROL_SHIFT:
			entry = _shift_patrol()
		Corruption.DEAD_NAME:
			entry = _insert_dead_name()
		Corruption.IMPOSSIBLE_PHRASE:
			entry = _insert_impossible_phrase()
		Corruption.PHANTOM_ENTRY:
			entry = _phantom_entry()
	if entry.is_empty():
		return -1
	entry["trust"] = Trust.CORRUPTED
	EventBus.notebook_corrupted.emit(entry, kind)
	return kind


func _drift_coordinate() -> Dictionary:
	var candidates := _entries.filter(func(e): return _has_digit(e["body"]))
	if candidates.is_empty():
		return {}
	var entry: Dictionary = candidates.pick_random()
	entry["body"] = _mutate_one_digit(entry["body"])
	return entry


func _shift_patrol() -> Dictionary:
	var candidates := by_kind(Kind.PATROL_NOTE)
	if candidates.is_empty():
		return {}
	var entry: Dictionary = candidates.pick_random()
	var body: String = entry["body"]
	for dir in _DIRECTIONS:
		if body.find(dir) != -1:
			var other: String = _DIRECTIONS[(_DIRECTIONS.find(dir) + 2) % 4]
			entry["body"] = body.replace(dir, other)
			return entry
	# No direction present: drift a number instead (e.g. a patrol time/count).
	entry["body"] = _mutate_one_digit(body)
	return entry


func _insert_dead_name() -> Dictionary:
	if _entries.is_empty() or dead_names.is_empty():
		return {}
	var entry: Dictionary = _entries.pick_random()
	var name: String = dead_names[randi() % dead_names.size()]
	entry["body"] = "%s\n   — %s?" % [entry["body"], name]
	return entry


func _insert_impossible_phrase() -> Dictionary:
	var transcripts := by_kind(Kind.MORSE_TRANSCRIPT)
	var entry: Dictionary
	if transcripts.is_empty():
		entry = add_entry(Kind.MORSE_TRANSCRIPT, "Copied — fragment",
			"... ... ...", {}, Trust.UNCERTAIN)
	else:
		entry = transcripts.pick_random()
	entry["body"] = "%s\n%s" % [entry["body"], _IMPOSSIBLE_PHRASES.pick_random()]
	return entry


## A whole entry in the player's own handwriting that they do not remember
## making — coordinates from nowhere.
func _phantom_entry() -> Dictionary:
	var grid := "GRID %d%d-%d%d" % [randi() % 9 + 1, randi() % 9, randi() % 9 + 1, randi() % 9]
	return add_entry(Kind.MAP_MARK, "(in my handwriting)",
		"%s\nwho marked this" % grid, {"phantom": true}, Trust.CORRUPTED)


# --- Helpers -------------------------------------------------------------

func _has_digit(s: String) -> bool:
	for i in s.length():
		if s[i] >= "0" and s[i] <= "9":
			return true
	return false


func _mutate_one_digit(s: String) -> String:
	var indices: Array[int] = []
	for i in s.length():
		if s[i] >= "0" and s[i] <= "9":
			indices.append(i)
	if indices.is_empty():
		return s
	var idx: int = indices.pick_random()
	var original := s[idx].to_int()
	var replacement := (original + randi_range(1, 8)) % 10
	return s.substr(0, idx) + str(replacement) + s.substr(idx + 1)


# --- Save / load ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {"entries": _entries.duplicate(true), "next_id": _next_id}


func from_dict(d: Dictionary) -> void:
	_entries = d.get("entries", []).duplicate(true)
	_next_id = d.get("next_id", _entries.size() + 1)
