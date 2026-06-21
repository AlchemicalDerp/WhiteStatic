class_name HandSteadiness
extends Node
## The keystone that connects everything to the Morse heart: a single 0..1
## value (1 = rock steady, 0 = shaking uncontrollably) derived from cold
## (primary), hunger, exhaustion, wounds, and the active symptom set. The Morse
## keyer feeds this into MorseSystem.apply_jitter, so the cold, the wound, the
## fear, and the trauma all decide whether the message gets out clean.
##
## Listens entirely on the EventBus; needs no references to other components.

var value: float = 1.0

var _warmth: float = 0.8
var _hunger: float = 0.1
var _exhaustion: float = 0.1
var _wounds: Dictionary = {}   ## wound id -> severity (bleeding + infection)


func _ready() -> void:
	EventBus.warmth_changed.connect(_on_warmth)
	EventBus.hunger_changed.connect(_on_hunger)
	EventBus.exhaustion_changed.connect(_on_exhaustion)
	EventBus.wound_added.connect(_on_wound)
	EventBus.wound_changed.connect(_on_wound)
	EventBus.wound_healed.connect(_on_wound_healed)
	EventBus.symptom_onset.connect(_on_symptom_onset)
	EventBus.symptom_intensity_changed.connect(_on_symptom_changed)
	EventBus.symptom_cleared.connect(_on_symptom_cleared)
	_recompute()


func current() -> float:
	return value


func _on_warmth(v: float) -> void:
	_warmth = v
	_recompute()


func _on_hunger(v: float) -> void:
	_hunger = v
	_recompute()


func _on_exhaustion(v: float) -> void:
	_exhaustion = v
	_recompute()


func _on_wound(w: Dictionary) -> void:
	_wounds[w["id"]] = clampf(w["bleeding"] + w["infection"], 0.0, 1.0)
	_recompute()


func _on_wound_healed(w: Dictionary) -> void:
	_wounds.erase(w["id"])
	_recompute()


func _on_symptom_onset(_s: int, _i: float) -> void:
	_recompute()


func _on_symptom_changed(_s: int, _i: float) -> void:
	_recompute()


func _on_symptom_cleared(_s: int) -> void:
	_recompute()


func _recompute() -> void:
	var wound_severity := 0.0
	for s in _wounds.values():
		wound_severity += s
	wound_severity = clampf(wound_severity, 0.0, 1.0)

	var physical := 1.0
	physical -= (1.0 - _warmth) * 0.50   # cold is the main enemy
	physical -= _hunger * 0.15
	physical -= _exhaustion * 0.20
	physical -= wound_severity * 0.25
	physical = clampf(physical, 0.05, 1.0)

	var new_value := clampf(physical * SymptomSystem.steadiness_modifier(), 0.0, 1.0)
	if not is_equal_approx(new_value, value):
		value = new_value
		EventBus.steadiness_changed.emit(value)
