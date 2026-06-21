extends Node
## Game time: minutes, hours, days, and the day/night phase. Winter days are
## short, so dawn is late and dusk is early. Other systems read time from here
## and react to EventBus.phase_changed / day_passed rather than polling.

enum Phase { DAWN, DAY, DUSK, NIGHT }

## In-game minutes that pass per real second. 60 => one in-game hour per
## real minute. Tune for pacing; pausing sets this aside via `running`.
@export var minutes_per_second: float = 30.0
@export var start_day: int = 1
@export var start_minute_of_day: int = 7 * 60  # 07:00, near a winter dawn

## Winter daylight window, in minutes-of-day. Short days by design.
const DAWN_START := 7 * 60      # 07:00
const DAY_START := 8 * 60       # 08:00
const DUSK_START := 16 * 60     # 16:00
const NIGHT_START := 17 * 60    # 17:00
const MINUTES_PER_DAY := 24 * 60

var running: bool = true
var day: int = 1
var minute_of_day: float = 0.0
var phase: Phase = Phase.DAY

var _minute_accum: float = 0.0
var _last_minute: int = -1
var _last_hour: int = -1


func _ready() -> void:
	day = start_day
	minute_of_day = float(start_minute_of_day)
	_last_minute = int(minute_of_day)
	_last_hour = hour()
	phase = _phase_for(minute_of_day)


func _process(delta: float) -> void:
	if not running:
		return
	minute_of_day += minutes_per_second * delta
	while minute_of_day >= MINUTES_PER_DAY:
		minute_of_day -= MINUTES_PER_DAY
		day += 1
		EventBus.day_passed.emit(day)
		_last_minute = -1
		_last_hour = -1

	var whole_minute := int(minute_of_day)
	if whole_minute != _last_minute:
		_last_minute = whole_minute
		EventBus.minute_passed.emit(day * MINUTES_PER_DAY + whole_minute)

	var h := hour()
	if h != _last_hour:
		_last_hour = h
		EventBus.hour_passed.emit(h, day)

	var p := _phase_for(minute_of_day)
	if p != phase:
		phase = p
		EventBus.phase_changed.emit(phase)


func hour() -> int:
	return int(minute_of_day) / 60


func minute() -> int:
	return int(minute_of_day) % 60


func is_night() -> bool:
	return phase == Phase.NIGHT


## How dark it is right now, 0 (full day) .. 1 (deep night). Useful for
## lighting, cold, and how easily lights/fires give the player away.
func darkness() -> float:
	match phase:
		Phase.DAY:
			return 0.0
		Phase.NIGHT:
			return 1.0
		Phase.DAWN:
			return 1.0 - inverse_lerp(DAWN_START, DAY_START, minute_of_day)
		Phase.DUSK:
			return inverse_lerp(DUSK_START, NIGHT_START, minute_of_day)
	return 0.0


## "Day 3 — 16:42" style stamp for the notebook and HUD.
func stamp() -> String:
	return "Day %d — %02d:%02d" % [day, hour(), minute()]


func set_paused(p: bool) -> void:
	running = not p


func _phase_for(mod: float) -> Phase:
	if mod < DAWN_START or mod >= NIGHT_START:
		return Phase.NIGHT
	elif mod < DAY_START:
		return Phase.DAWN
	elif mod < DUSK_START:
		return Phase.DAY
	else:
		return Phase.DUSK
