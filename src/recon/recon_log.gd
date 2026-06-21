class_name ReconLog
extends Node
## The reconnaissance record. The protagonist was trained to observe, count,
## time, and map — and the best endings come from accurate intelligence, not
## combat. Each observation stores what the player *recorded* alongside the
## ground *truth*, so accuracy can be scored. The player only ever sees their
## record (mirrored into the notebook); the truth drives endings.

## Each: { id, kind, recorded, truth, weight }
var observations: Array = []

## How far a position estimate may be off (metres) before it scores zero.
@export var position_tolerance: float = 25.0

var _next_id: int = 1


## Record an observation. `kind` is free-form ("vehicle_count",
## "installation", "artillery_position", "patrol_route", ...). `recorded` is
## the player's reading; `truth` is the real value (number, String, or Vector3).
func log_observation(kind: String, recorded: Variant, truth: Variant, weight: float = 1.0) -> Dictionary:
	var obs := {
		"id": _next_id, "kind": kind,
		"recorded": recorded, "truth": truth, "weight": weight,
	}
	_next_id += 1
	observations.append(obs)
	Notebook.add_entry(Notebook.Kind.OBSERVATION, kind.capitalize(),
		"%s: %s" % [kind, str(recorded)], {"recon_id": obs["id"]})
	EventBus.observation_logged.emit(obs)
	EventBus.recon_accuracy_changed.emit(accuracy())
	return obs


## Weighted accuracy of all observations, 0..1.
func accuracy() -> float:
	if observations.is_empty():
		return 0.0
	var sum := 0.0
	var weight := 0.0
	for obs in observations:
		sum += _match(obs["recorded"], obs["truth"]) * obs["weight"]
		weight += obs["weight"]
	return sum / weight if weight > 0.0 else 0.0


func _match(recorded: Variant, truth: Variant) -> float:
	var tr := typeof(recorded)
	var tt := typeof(truth)
	if (tr == TYPE_INT or tr == TYPE_FLOAT) and (tt == TYPE_INT or tt == TYPE_FLOAT):
		var denom: float = maxf(absf(float(truth)), 1.0)
		return clampf(1.0 - absf(float(recorded) - float(truth)) / denom, 0.0, 1.0)
	if tr == TYPE_VECTOR3 and tt == TYPE_VECTOR3:
		return clampf(1.0 - (recorded as Vector3).distance_to(truth) / position_tolerance, 0.0, 1.0)
	if tr == TYPE_VECTOR2 and tt == TYPE_VECTOR2:
		return clampf(1.0 - (recorded as Vector2).distance_to(truth) / position_tolerance, 0.0, 1.0)
	# Fall back to case-insensitive string comparison.
	return 1.0 if str(recorded).to_upper() == str(truth).to_upper() else 0.0
	# TODO: let SymptomSystem notebook corruption feed back into the recorded
	# value, so a shaken mind literally degrades the intelligence.
