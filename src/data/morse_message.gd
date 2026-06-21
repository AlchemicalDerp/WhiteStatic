class_name MorseMessage
extends Resource
## An incoming or scripted Morse transmission. Some are friendly, some are
## enemy deception (false traffic to draw the player out or to mislead), and
## some "may not be real at all" — a hallucination the player hears in the
## static. The player cannot always tell which.

@export var id: String = ""
@export var call_sign: String = ""
@export var sender: String = ""
@export_multiline var text: String = ""
@export var wpm: float = 12.0
@export var is_friendly: bool = true
## Enemy false traffic. Answering it can lead to the "false rescue" ending.
@export var is_deception: bool = false
## Possibly a hallucination — never logged as reliable.
@export var may_be_unreal: bool = false


## Pack into the plain dictionary the EventBus / AudioDirector consume.
func to_payload() -> Dictionary:
	return {
		"id": id,
		"call_sign": call_sign,
		"sender": sender,
		"text": text,
		"wpm": wpm,
		"is_friendly": is_friendly,
		"is_deception": is_deception,
		"may_be_unreal": may_be_unreal,
		"fidelity": 1.0,
	}
