class_name MorseKeyer
extends RefCounted
## Captures the player's live hand keying as a stream of on/off durations, then
## hands it to MorseSystem to be jittered by hand steadiness, classified, and
## scored. The RadioUI drives it: key_down on press, key_up on release (using
## millisecond timestamps), then finish() to resolve the message.

var events: Array = []

var _down: bool = false
var _last_change_ms: int = 0


func reset() -> void:
	events.clear()
	_down = false
	_last_change_ms = 0


func key_down(now_ms: int) -> void:
	if _down:
		return
	if not events.is_empty():
		events.append({"on": false, "ms": float(now_ms - _last_change_ms)})
	_down = true
	_last_change_ms = now_ms


func key_up(now_ms: int) -> void:
	if not _down:
		return
	var dur := float(now_ms - _last_change_ms)
	events.append({"on": true, "ms": dur})
	_down = false
	_last_change_ms = now_ms
	# Live feedback: best-guess the symbol at standard speed.
	var unit := MorseSystem.unit_ms()
	EventBus.morse_symbol.emit("-" if dur >= 2.0 * unit else ".", true)


func is_empty() -> bool:
	return events.is_empty()


## Resolve what was keyed. Steadiness jitters the captured timing (a shaking
## hand smears dits and dahs). Returns
## { "text", "morse", "fidelity", "duration" (seconds) }.
func finish(intended_text: String, steadiness: float) -> Dictionary:
	var jittered := MorseSystem.apply_jitter(events, steadiness)
	var classified := MorseSystem.classify_keying(jittered)
	return {
		"text": classified["text"],
		"morse": classified["morse"],
		"fidelity": MorseSystem.score_fidelity(intended_text, classified["text"], jittered),
		"duration": MorseSystem.timeline_seconds(jittered),
	}
