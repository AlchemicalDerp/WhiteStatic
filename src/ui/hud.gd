class_name Hud
extends Control
## Always-on overlay: crosshair, clock, vitals + hand steadiness, the recon /
## radio goals, direction-finding risk, the interaction prompt, and a transient
## caption line used for symptom episodes, hallucinated voices, and send
## results. Notebook corruption is deliberately NOT surfaced here.

const INVOLUNTARY_TEXT := {
	SymptomSystem.Involuntary.STAB_SURFACE: "Your hand drives the tool into the table.",
	SymptomSystem.Involuntary.OVERTIGHTEN: "You overtighten the screw until it strips.",
	SymptomSystem.Involuntary.SNAP_WIRE: "A wire snaps between your fingers.",
	SymptomSystem.Involuntary.MISPLACE_PART: "A part is gone. You don't remember moving it.",
	SymptomSystem.Involuntary.WAKE_OUTSIDE_CAMP: "You come to outside the camp.",
	SymptomSystem.Involuntary.CHAMBER_ROUND: "You've chambered a round without meaning to.",
	SymptomSystem.Involuntary.SPILL_WATER: "The water tips into the snow.",
	SymptomSystem.Involuntary.DAMAGE_COMPONENT: "Something fragile cracks in your grip.",
	SymptomSystem.Involuntary.LOSE_TIME: "Time is missing. The light has moved.",
}
const SYMPTOM_TEXT := {
	SymptomSystem.Symptom.ANXIETY: "Your chest tightens.",
	SymptomSystem.Symptom.ANGER: "Heat rises behind your eyes.",
	SymptomSystem.Symptom.RAGE: "You want to break something.",
	SymptomSystem.Symptom.FEAR: "Fear closes your throat.",
	SymptomSystem.Symptom.NUMBNESS: "Everything goes distant and flat.",
	SymptomSystem.Symptom.HYPERVIGILANCE: "Every sound is a threat.",
	SymptomSystem.Symptom.DISSOCIATION: "Your hands feel like someone else's.",
	SymptomSystem.Symptom.EXHAUSTION: "Your eyes drag shut.",
}
const HALLUCINATION_TEXT := {
	"squadmate_treeline": "Someone is standing in the tree line.",
	"hanging_parachute": "A parachute hangs in the branches.",
	"lantern_to_moonlight": "A lantern — no, only the moon.",
	"vanishing_patrol": "A patrol, there — and then gone.",
	"footprints_that_stop": "Footprints in the snow that simply stop.",
	"dead_friend_walking": "He's walking toward you. He shouldn't be.",
}

var _time_label: Label
var _prompt_label: Label
var _caption_label: Label
var _stage_label: Label
var _goal_label: Label
var _df_bar: ProgressBar
var _bars: Dictionary = {}
var _caption_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_connect()


func _build() -> void:
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.55)
	dot.custom_minimum_size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_top = -2
	dot.offset_right = 2
	dot.offset_bottom = 2
	add_child(dot)

	_time_label = _mk_label()
	_time_label.position = Vector2(16, 12)
	add_child(_time_label)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vbox.offset_left = 16
	vbox.offset_top = -168
	vbox.offset_bottom = -16
	add_child(vbox)
	for key in ["Warmth", "Health", "Hunger", "Thirst", "Steadiness"]:
		_bars[key] = _mk_bar(vbox, key)

	var rbox := VBoxContainer.new()
	rbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	rbox.offset_left = -264
	rbox.offset_top = 12
	rbox.offset_right = -16
	add_child(rbox)
	_stage_label = _mk_label()
	rbox.add_child(_stage_label)
	_goal_label = _mk_label()
	rbox.add_child(_goal_label)
	var df_caption := _mk_label()
	df_caption.text = "DF risk"
	rbox.add_child(df_caption)
	_df_bar = ProgressBar.new()
	_df_bar.max_value = 1.0
	_df_bar.show_percentage = false
	_df_bar.custom_minimum_size = Vector2(240, 12)
	rbox.add_child(_df_bar)

	_prompt_label = _mk_label()
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_top = -96
	_prompt_label.offset_left = -140
	add_child(_prompt_label)

	_caption_label = _mk_label()
	_caption_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_caption_label.offset_top = 64
	_caption_label.offset_left = -240
	_caption_label.offset_right = 240
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.modulate.a = 0.0
	add_child(_caption_label)

	_stage_label.text = "Radio: none"
	_goal_label.text = _goal_string()
	_time_label.text = GameClock.stamp()


func _connect() -> void:
	EventBus.minute_passed.connect(func(_t): _time_label.text = GameClock.stamp())
	EventBus.warmth_changed.connect(func(v): _set_bar("Warmth", v))
	EventBus.health_changed.connect(func(v): _set_bar("Health", v))
	EventBus.hunger_changed.connect(func(v): _set_bar("Hunger", v))
	EventBus.thirst_changed.connect(func(v): _set_bar("Thirst", v))
	EventBus.steadiness_changed.connect(func(v): _set_bar("Steadiness", v))
	EventBus.radio_stage_changed.connect(func(id): _stage_label.text = "Radio: " + id.replace("_", " "))
	EventBus.goal_updated.connect(func(_g, _p): _goal_label.text = _goal_string())
	EventBus.direction_finding_progress.connect(func(v): _df_bar.value = v)
	EventBus.interactable_focused.connect(_on_focus)
	EventBus.interactable_unfocused.connect(func(_n): _prompt_label.text = "")
	EventBus.involuntary_action.connect(func(a, _c): show_caption(INVOLUNTARY_TEXT.get(a, "")))
	EventBus.symptom_onset.connect(func(s, _i): show_caption(SYMPTOM_TEXT.get(s, "")))
	EventBus.hallucination_requested.connect(_on_hallucination)
	EventBus.morse_message_sent.connect(_on_sent)


func show_caption(text: String, color: Color = Color(0.85, 0.86, 0.88)) -> void:
	if text == "":
		return
	_caption_label.text = text
	_caption_label.modulate = color
	_caption_label.modulate.a = 1.0
	if _caption_tween != null and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_tween = create_tween()
	_caption_tween.tween_interval(3.0)
	_caption_tween.tween_property(_caption_label, "modulate:a", 0.0, 1.5)


func _on_focus(node: Node) -> void:
	var prompt := "Use"
	if node.has_method("get_prompt"):
		prompt = node.call("get_prompt")
	_prompt_label.text = ("[E] " + prompt) if prompt != "" else ""


func _on_hallucination(h: Dictionary) -> void:
	if h.get("channel", "") == "visual":
		show_caption(HALLUCINATION_TEXT.get(h.get("id", ""), ""), Color(0.7, 0.74, 0.82))


func _on_sent(_text: String, fidelity: float, duration: float) -> void:
	show_caption("Keyed %.0fs — likely read at %d%%" % [duration, int(fidelity * 100.0)])


# --- widgets -------------------------------------------------------------

func _mk_label() -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", Color(0.86, 0.88, 0.9))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _mk_bar(parent: Node, label: String) -> ProgressBar:
	var row := HBoxContainer.new()
	var name_label := _mk_label()
	name_label.text = label
	name_label.custom_minimum_size = Vector2(88, 0)
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(160, 12)
	row.add_child(bar)
	parent.add_child(row)
	return bar


func _set_bar(key: String, v: float) -> void:
	if _bars.has(key):
		_bars[key].value = v


func _goal_string() -> String:
	return "Survive %d%%  Radio %d%%  Recon %d%%" % [
		int(GameState.goals["survive"] * 100.0),
		int(GameState.goals["build_radio"] * 100.0),
		int(GameState.goals["recon"] * 100.0),
	]
