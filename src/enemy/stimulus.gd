class_name Stimulus
extends RefCounted
## A thing in the world the enemy can perceive and infer from: a sound, a
## light, smoke, fresh tracks, a radio direction-finding fix, a disturbed
## supply cache, a cut wire. The enemy is never told where the player is — it
## reacts to these. Anything that gives the player away should emit one.

enum Type { SOUND, LIGHT, SMOKE, TRACKS, RADIO, DISTURBED_LOOT, CUT_WIRE }


## Broadcast a stimulus on the bus for any patrol in range to weigh.
static func emit(type: Type, position: Vector3, intensity: float = 1.0, radius: float = 12.0, source: Node = null) -> void:
	EventBus.stimulus_emitted.emit({
		"type": type,
		"position": position,
		"intensity": clampf(intensity, 0.0, 1.0),
		"radius": radius,
		"source": source,
	})
