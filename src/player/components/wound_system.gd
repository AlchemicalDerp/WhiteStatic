class_name WoundSystem
extends Node
## Discrete wounds that bleed, can become infected, and bring fever. Vitals
## reads the aggregate drain from here; the SymptomSystem reacts to new wounds
## (pain and fear feed the mind). Wounds can be dressed (stops bleeding) and
## treated (clears infection) with the right supplies.

## Each wound: { id:int, kind:String, bleeding:0..1, infection:0..1, dressed:bool }
var wounds: Array = []
var _next_id: int = 1


func _ready() -> void:
	EventBus.minute_passed.connect(_on_minute)


func add_wound(kind: String, bleeding: float = 0.4, infection: float = 0.0) -> Dictionary:
	var w := {
		"id": _next_id,
		"kind": kind,
		"bleeding": clampf(bleeding, 0.0, 1.0),
		"infection": clampf(infection, 0.0, 1.0),
		"dressed": false,
	}
	_next_id += 1
	wounds.append(w)
	EventBus.wound_added.emit(w)
	return w


func dress(wound_id: int) -> void:
	var w := _find(wound_id)
	if w.is_empty():
		return
	w["dressed"] = true
	w["bleeding"] = 0.0
	EventBus.wound_changed.emit(w)


func treat_infection(wound_id: int) -> void:
	var w := _find(wound_id)
	if w.is_empty():
		return
	w["infection"] = 0.0
	EventBus.wound_changed.emit(w)


func total_bleeding() -> float:
	var t := 0.0
	for w in wounds:
		t += w["bleeding"]
	return t


func total_fever() -> float:
	var t := 0.0
	for w in wounds:
		t += w["infection"]
	return t


func _on_minute(_total: int) -> void:
	for w in wounds:
		# Undressed wounds keep weeping and tend to turn septic.
		if not w["dressed"] and w["bleeding"] > 0.0:
			w["infection"] = clampf(w["infection"] + 0.0008, 0.0, 1.0)
			w["bleeding"] = clampf(w["bleeding"] - 0.0003, 0.0, 1.0)
			EventBus.wound_changed.emit(w)
		elif w["dressed"] and w["bleeding"] <= 0.0 and w["infection"] > 0.0:
			# Dressed but infected: fever lingers, slowly fading on its own.
			w["infection"] = clampf(w["infection"] - 0.0002, 0.0, 1.0)
			if w["infection"] <= 0.0:
				EventBus.wound_healed.emit(w)


func _find(id: int) -> Dictionary:
	for w in wounds:
		if w["id"] == id:
			return w
	return {}
