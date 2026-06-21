class_name Vitals
extends Node
## The protagonist's body: warmth, hunger, thirst, exhaustion, and overall
## health. Cold is the main enemy — it falls fastest at night and out of
## shelter, and once you are freezing it eats your health. Ticks once per
## in-game minute off GameClock and publishes every change on the EventBus so
## the symptom system, hand steadiness, and HUD can react.

# 0..1 scales. Warmth/health: 1 is good. Hunger/thirst/exhaustion: 1 is bad.
@export var warmth: float = 0.8
@export var hunger: float = 0.1
@export var thirst: float = 0.1
@export var exhaustion: float = 0.1
@export var health: float = 1.0

# Per-in-game-minute rates.
@export var hunger_rate: float = 0.00035
@export var thirst_rate: float = 0.00070
@export var exhaustion_rate: float = 0.00055
@export var warmth_loss_day: float = 0.0010
@export var warmth_loss_night: float = 0.0020
@export var warmth_gain_fire: float = 0.0040

## Set by the world/camp.
var near_fire: bool = false
var sheltered: bool = false
## 0 resting .. 1 exerting; scales exhaustion and warmth burn.
var activity: float = 0.3

var alive: bool = true
## Injected by Player so health can include bleeding/fever drain.
var wound_system: WoundSystem


func _ready() -> void:
	EventBus.minute_passed.connect(_on_minute)
	_broadcast_all()


func _on_minute(_total: int) -> void:
	if not alive:
		return
	_tick_warmth()
	_apply("hunger", hunger + hunger_rate * (1.0 + 0.5 * activity))
	_apply("thirst", thirst + thirst_rate)
	_apply("exhaustion", exhaustion + exhaustion_rate * (0.5 + activity))
	_tick_health()


## Re-emit every value, e.g. so a HUD created after the player can sync up.
func broadcast() -> void:
	_broadcast_all()


func rest(minutes: float = 1.0) -> void:
	_apply("exhaustion", exhaustion - 0.01 * minutes)


func drink() -> void:
	_apply("thirst", thirst - 0.5)

func eat(amount: float = 0.4) -> void:
	_apply("hunger", hunger - amount)


func _tick_warmth() -> void:
	if near_fire:
		_apply("warmth", warmth + warmth_gain_fire)
		return
	var loss := lerpf(warmth_loss_day, warmth_loss_night, GameClock.darkness())
	if sheltered:
		loss *= 0.5
	loss *= 1.0 + 0.4 * activity
	_apply("warmth", warmth - loss)


func _tick_health() -> void:
	var delta := 0.0
	if warmth <= 0.05:
		delta -= 0.0020          # freezing
	if hunger >= 0.98 or thirst >= 0.98:
		delta -= 0.0010          # starvation / dehydration
	if wound_system != null:
		delta -= wound_system.total_bleeding() * 0.0030
		delta -= wound_system.total_fever() * 0.0015
	if delta == 0.0 and warmth > 0.5 and hunger < 0.7 and thirst < 0.7:
		delta += 0.0006          # slow recovery when stable
	if delta != 0.0:
		_apply("health", health + delta)
	if health <= 0.0:
		_die()


func _die() -> void:
	if not alive:
		return
	alive = false
	var cause := "wounds"
	if warmth <= 0.05:
		cause = "cold"
	elif hunger >= 0.98 or thirst >= 0.98:
		cause = "starvation"
	EventBus.player_died.emit(cause)


func _apply(field: String, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(get(field), clamped):
		return
	set(field, clamped)
	match field:
		"warmth": EventBus.warmth_changed.emit(clamped)
		"hunger": EventBus.hunger_changed.emit(clamped)
		"thirst": EventBus.thirst_changed.emit(clamped)
		"exhaustion": EventBus.exhaustion_changed.emit(clamped)
		"health": EventBus.health_changed.emit(clamped)


func _broadcast_all() -> void:
	EventBus.warmth_changed.emit(warmth)
	EventBus.hunger_changed.emit(hunger)
	EventBus.thirst_changed.emit(thirst)
	EventBus.exhaustion_changed.emit(exhaustion)
	EventBus.health_changed.emit(health)
