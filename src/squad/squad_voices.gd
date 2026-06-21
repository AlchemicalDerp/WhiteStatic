class_name SquadVoices
extends Node
## Realizes the SymptomSystem's audio hallucinations as a specific dead
## squadmate's voice — the sergeant's accusation, a friend's plea, the
## operator's call signs through the static. Emits `voice` for the HUD to
## caption and asks the AudioDirector for the matching one-shot.

signal voice(line: String, speaker: String)

const LINES := {
	"whispered_command": {
		"speaker": "sergeant",
		"lines": ["Hold your position.", "On your feet, soldier.", "You let them die."],
	},
	"own_name_in_static": {
		"speaker": "friend",
		"lines": ["...you still there?", "come back for me", "it's so cold out here"],
	},
	"morse_in_wind": {
		"speaker": "operator",
		"lines": ["dah-dit-dah... that's our call sign", "...is anyone answering?"],
	},
	"boots_in_snow": {"speaker": "", "lines": ["Boots. Behind you. Then nothing."]},
	"rifle_bolt": {"speaker": "", "lines": ["A bolt drawn back, close enough to touch."]},
	"aircraft_engine": {"speaker": "", "lines": ["Engines overhead — ours? theirs? gone."]},
}


func _ready() -> void:
	EventBus.hallucination_requested.connect(_on_hallucination)


func _on_hallucination(h: Dictionary) -> void:
	if h.get("channel", "") != "audio":
		return
	var id: String = h.get("id", "")
	AudioDirector.play_oneshot(id)
	if LINES.has(id):
		var entry: Dictionary = LINES[id]
		voice.emit(entry["lines"].pick_random(), _name_for(entry["speaker"]))


func _name_for(role_id: String) -> String:
	if role_id == "":
		return ""
	for m in GameState.squad:
		if m["id"] == role_id:
			return m["name"]
	return ""
