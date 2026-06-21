extends Node
## Campaign-level state: the three overlapping goals (survive, build the radio,
## complete recon), the run metrics that decide the ending, the fallen squad,
## and save/load orchestration. GameState mostly *observes* the EventBus and
## records; the systems themselves live elsewhere.

const SAVE_PATH := "user://whitestatic_save.json"

## The fallen squad. Each leaves equipment, knowledge, and a "voice" the
## SymptomSystem draws on. Authorable richer via SquadMember resources in
## src/data/; these defaults seed a run.
const DEFAULT_SQUAD := [
	{"id": "operator", "name": "Cpl. Hartley", "role": "Radio operator"},
	{"id": "medic", "name": "Pvt. Greer", "role": "Medic"},
	{"id": "scout", "name": "Sgt. Voss", "role": "Scout"},
	{"id": "sergeant", "name": "Sgt. Lowe", "role": "Section sergeant"},
	{"id": "friend", "name": "Danny", "role": "Close friend"},
]

# Run metrics tracked off the bus.
var radio_stage_id: String = "none"
var recon_accuracy: float = 0.0
var best_fidelity: float = 0.0
var sent_accurate_coordinates: bool = false
var detection: float = 0.0          ## max direction-finding confidence reached
var was_spotted: bool = false
var ended: bool = false

var goals := {
	"survive": 0.0,
	"build_radio": 0.0,
	"recon": 0.0,
}
var flags := {}                     ## free-form campaign flags
var squad: Array = DEFAULT_SQUAD.duplicate(true)


func _ready() -> void:
	var names := PackedStringArray()
	for m in squad:
		names.append(m["name"])
	Notebook.dead_names = names

	EventBus.radio_stage_changed.connect(_on_radio_stage)
	EventBus.recon_accuracy_changed.connect(_on_recon)
	EventBus.morse_message_sent.connect(_on_message_sent)
	EventBus.direction_finding_progress.connect(_on_df)
	EventBus.player_spotted.connect(func(_a): was_spotted = true)
	EventBus.player_died.connect(_on_player_died)


func start_run() -> void:
	ended = false
	EventBus.game_started.emit()


# --- Flags & goals -------------------------------------------------------

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value

func has_flag(key: String) -> bool:
	return flags.get(key, false)

func set_goal(goal_id: String, progress: float) -> void:
	goals[goal_id] = clampf(progress, 0.0, 1.0)
	EventBus.goal_updated.emit(goal_id, goals[goal_id])


# --- Endings -------------------------------------------------------------

## Resolve the run to an ending id, emit it once, and return it. Precedence
## runs from the most decisive outcomes (death, capture) down to the quieter
## ones (failed intelligence). See docs/DESIGN.md for the full set.
func evaluate_ending(death_cause: String = "") -> String:
	if ended:
		return str(flags.get("ending", "unknown"))
	var integrity := SymptomSystem.mental_integrity()
	var has_station := radio_stage_id == "field_station"
	var got_truth_out := sent_accurate_coordinates and best_fidelity >= 0.6
	var id := ""

	if death_cause == "cold":
		id = "freezing"
	elif death_cause == "wounds" or death_cause == "starvation":
		id = "perished"
	elif was_spotted and detection > 0.8:
		id = "capture"
	elif has_flag("answered_deception"):
		id = "false_rescue"
	elif has_flag("called_artillery") or has_flag("sabotage"):
		id = "revenge"
	elif has_station and got_truth_out and integrity > 0.35:
		id = "rescue"
	elif got_truth_out and recon_accuracy >= 0.7:
		id = "successful_mission"
	elif integrity < 0.2 and has_station:
		# Body found beside a dead radio; the call sign keeps transmitting.
		id = "ghost_signal"
	elif recon_accuracy < 0.4:
		id = "failed_intelligence"
	else:
		id = "ambiguous"

	ended = true
	flags["ending"] = id
	EventBus.ending_reached.emit(id)
	return id


# --- Save / load ---------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"day": GameClock.day,
		"minute_of_day": GameClock.minute_of_day,
		"radio_stage_id": radio_stage_id,
		"recon_accuracy": recon_accuracy,
		"best_fidelity": best_fidelity,
		"sent_accurate_coordinates": sent_accurate_coordinates,
		"detection": detection,
		"was_spotted": was_spotted,
		"goals": goals,
		"flags": flags,
		"notebook": Notebook.to_dict(),
	}


func save_game() -> Error:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("WhiteStatic: could not open save file for writing.")
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return OK


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	GameClock.day = int(data.get("day", GameClock.day))
	GameClock.minute_of_day = float(data.get("minute_of_day", GameClock.minute_of_day))
	radio_stage_id = data.get("radio_stage_id", "none")
	recon_accuracy = data.get("recon_accuracy", 0.0)
	best_fidelity = data.get("best_fidelity", 0.0)
	sent_accurate_coordinates = data.get("sent_accurate_coordinates", false)
	detection = data.get("detection", 0.0)
	was_spotted = data.get("was_spotted", false)
	goals = data.get("goals", goals)
	flags = data.get("flags", {})
	Notebook.from_dict(data.get("notebook", {}))
	return true


# --- Bus handlers --------------------------------------------------------

func _on_radio_stage(stage_id: String) -> void:
	radio_stage_id = stage_id
	var rank := {"none": 0.0, "crude_receiver": 0.25, "better_receiver": 0.5,
		"weak_transmitter": 0.75, "field_station": 1.0}
	set_goal("build_radio", rank.get(stage_id, 0.0))

func _on_recon(value: float) -> void:
	recon_accuracy = value
	set_goal("recon", value)

func _on_message_sent(_text: String, fidelity: float, _duration: float) -> void:
	best_fidelity = maxf(best_fidelity, fidelity)

func _on_df(value: float) -> void:
	detection = maxf(detection, value)

func _on_player_died(cause: String) -> void:
	set_goal("survive", 0.0)
	evaluate_ending(cause)
