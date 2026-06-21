extends Node
## The psychological model. NOT a sanity meter — a set of symptoms, each with
## its own intensity, fed by stressors (cold, wounds, the enemy, hunger,
## darkness) and decaying over time. When symptoms run high the system rolls
## "episodes": involuntary actions, hallucination requests, and silent notebook
## corruption. It also degrades hand steadiness, so the trauma ultimately
## expresses itself in whether a Morse message gets out clean.
##
## This system never reaches into the world directly. It announces what is
## happening on the EventBus; the player, radio, and world realize it.

enum Symptom { ANXIETY, ANGER, RAGE, FEAR, NUMBNESS, HYPERVIGILANCE, DISSOCIATION, EXHAUSTION }

enum Involuntary {
	STAB_SURFACE, OVERTIGHTEN, SNAP_WIRE, MISPLACE_PART, WAKE_OUTSIDE_CAMP,
	CHAMBER_ROUND, SPILL_WATER, DAMAGE_COMPONENT, LOSE_TIME,
}

## Seconds between episode rolls.
@export var episode_interval: float = 12.0
## Per-second pull of every symptom back toward calm.
@export var decay_per_second: float = 0.012

var intensity: Dictionary = {}   ## Symptom -> 0..1
var _roll_accum: float = 0.0


func _ready() -> void:
	for s in Symptom.values():
		intensity[s] = 0.0
	EventBus.warmth_changed.connect(_on_warmth)
	EventBus.hunger_changed.connect(_on_hunger)
	EventBus.exhaustion_changed.connect(_on_exhaustion)
	EventBus.wound_added.connect(_on_wound)
	EventBus.enemy_alerted.connect(_on_enemy_alerted)
	EventBus.player_spotted.connect(func(_a): add_stress(Symptom.FEAR, 0.4))
	EventBus.phase_changed.connect(_on_phase)


func _process(delta: float) -> void:
	for s in intensity:
		if intensity[s] > 0.0:
			_apply(s, intensity[s] - decay_per_second * delta)
	_roll_accum += delta
	if _roll_accum >= episode_interval:
		_roll_accum = 0.0
		_roll_episode()


# --- Inputs --------------------------------------------------------------

## Raise a symptom. Stressors across the game funnel through here.
func add_stress(symptom: Symptom, amount: float) -> void:
	_apply(symptom, intensity[symptom] + amount)


# --- Outputs other systems read -----------------------------------------

## Multiplier on hand steadiness, 0.1..1.0 (1 = unaffected). Fear, anger,
## rage, and exhaustion shake the hands the most.
func steadiness_modifier() -> float:
	var impair: float = (
		0.40 * intensity[Symptom.FEAR]
		+ 0.30 * intensity[Symptom.ANGER]
		+ 0.50 * intensity[Symptom.RAGE]
		+ 0.30 * intensity[Symptom.EXHAUSTION]
		+ 0.15 * intensity[Symptom.ANXIETY]
	)
	return clampf(1.0 - impair, 0.1, 1.0)


## Aggregate "holding together" value, 0 (shattered)..1 (composed). Used only
## for ending evaluation — it does not govern play (the symptoms do).
func mental_integrity() -> float:
	var total := 0.0
	for s in intensity:
		total += intensity[s]
	return clampf(1.0 - total / float(intensity.size()), 0.0, 1.0)


func dominant() -> Symptom:
	var best: Symptom = Symptom.ANXIETY
	var best_v := -1.0
	for s in intensity:
		if intensity[s] > best_v:
			best_v = intensity[s]
			best = s
	return best


# --- Episodes ------------------------------------------------------------

func _roll_episode() -> void:
	var pressure := 1.0 - mental_integrity()  # 0 calm .. 1 unraveling
	if randf() > pressure:
		return  # held it together this time
	# Higher pressure leans toward hallucination and notebook corruption;
	# anger/rage lean toward destructive involuntary actions.
	var anger := maxf(intensity[Symptom.ANGER], intensity[Symptom.RAGE])
	var roll := randf()
	if roll < 0.45 + 0.25 * anger:
		_trigger_involuntary(pressure)
	elif roll < 0.8:
		_trigger_hallucination(pressure)
	else:
		Notebook.corrupt_random()


func _trigger_involuntary(pressure: float) -> void:
	var action: Involuntary
	match dominant():
		Symptom.RAGE, Symptom.ANGER:
			action = [Involuntary.STAB_SURFACE, Involuntary.SNAP_WIRE,
				Involuntary.OVERTIGHTEN, Involuntary.DAMAGE_COMPONENT].pick_random()
		Symptom.DISSOCIATION:
			action = [Involuntary.WAKE_OUTSIDE_CAMP, Involuntary.LOSE_TIME,
				Involuntary.MISPLACE_PART].pick_random()
		Symptom.NUMBNESS:
			action = [Involuntary.SPILL_WATER, Involuntary.MISPLACE_PART].pick_random()
		Symptom.HYPERVIGILANCE, Symptom.FEAR:
			action = Involuntary.CHAMBER_ROUND
		_:
			action = Involuntary.values().pick_random()
	EventBus.involuntary_action.emit(action, {"severity": pressure})


func _trigger_hallucination(pressure: float) -> void:
	var visual := {
		"channel": "visual",
		"id": ["squadmate_treeline", "hanging_parachute", "lantern_to_moonlight",
			"vanishing_patrol", "footprints_that_stop", "dead_friend_walking"].pick_random(),
		"intensity": pressure,
	}
	var audio := {
		"channel": "audio",
		"id": ["morse_in_wind", "boots_in_snow", "whispered_command",
			"aircraft_engine", "rifle_bolt", "own_name_in_static"].pick_random(),
		"intensity": pressure,
	}
	var h: Dictionary = audio if intensity[Symptom.HYPERVIGILANCE] > intensity[Symptom.DISSOCIATION] else visual
	EventBus.hallucination_requested.emit(h)


# --- Stressor handlers ---------------------------------------------------

func _on_warmth(value: float) -> void:
	if value < 0.3:
		add_stress(Symptom.FEAR, (0.3 - value) * 0.02)
		add_stress(Symptom.ANXIETY, (0.3 - value) * 0.02)

func _on_hunger(value: float) -> void:
	if value > 0.6:
		add_stress(Symptom.ANGER, (value - 0.6) * 0.015)
		add_stress(Symptom.NUMBNESS, (value - 0.6) * 0.01)

func _on_exhaustion(value: float) -> void:
	_apply(Symptom.EXHAUSTION, maxf(intensity[Symptom.EXHAUSTION], value))
	if value > 0.7:
		add_stress(Symptom.DISSOCIATION, (value - 0.7) * 0.02)

func _on_wound(_w: Dictionary) -> void:
	add_stress(Symptom.FEAR, 0.2)
	add_stress(Symptom.ANGER, 0.1)

func _on_enemy_alerted(_agent: Node, level: int) -> void:
	add_stress(Symptom.HYPERVIGILANCE, 0.1 * (level + 1))
	add_stress(Symptom.FEAR, 0.05 * (level + 1))

func _on_phase(phase: int) -> void:
	if phase == GameClock.Phase.NIGHT:
		add_stress(Symptom.ANXIETY, 0.15)
		add_stress(Symptom.DISSOCIATION, 0.1)


# --- Internal ------------------------------------------------------------

func _apply(s: Symptom, value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	var was: float = intensity[s]
	if is_equal_approx(was, clamped):
		return
	intensity[s] = clamped
	if was <= 0.0 and clamped > 0.0:
		EventBus.symptom_onset.emit(s, clamped)
	elif clamped <= 0.0 and was > 0.0:
		EventBus.symptom_cleared.emit(s)
	else:
		EventBus.symptom_intensity_changed.emit(s, clamped)
