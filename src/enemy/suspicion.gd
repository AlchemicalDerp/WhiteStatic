class_name Suspicion
extends RefCounted
## A patrol's belief that something is wrong and roughly where. Inference, not
## omniscience: it rises from perceived stimuli and the last place the player
## was sensed, and decays when nothing reinforces it.

enum Level { CALM, CURIOUS, ALERTED, SEARCHING }

var value: float = 0.0
var last_known_position: Vector3 = Vector3.ZERO
var has_target: bool = false


func add(amount: float, position: Vector3) -> void:
	value = clampf(value + amount, 0.0, 1.0)
	if amount > 0.0:
		last_known_position = position
		has_target = true


func decay(amount: float) -> void:
	value = maxf(value - amount, 0.0)
	if value <= 0.0:
		has_target = false


func level() -> Level:
	if value < 0.2:
		return Level.CALM
	elif value < 0.5:
		return Level.CURIOUS
	elif value < 0.8:
		return Level.ALERTED
	return Level.SEARCHING


func reset() -> void:
	value = 0.0
	has_target = false
