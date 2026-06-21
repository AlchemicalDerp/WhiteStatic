class_name RadioView
extends Control
## The radio panel. Two faces of the same set:
##  - WORKBENCH: see what's built, what the next stage needs, and build it.
##  - RADIO: listen to incoming traffic (some friendly, some deception, some
##    maybe unreal), copy it to the notebook, and transmit — either auto-keyed
##    or hand-keyed by holding [K], with hand steadiness shaping fidelity and
##    time on the air feeding the enemy's direction-finding fix.

const INCOMING := [
	{"sender": "BASE", "text": "CQ CQ DE BASE K", "is_friendly": true},
	{"sender": "BASE", "text": "REPORT POSITION OVER", "is_friendly": true},
	{"sender": "????", "text": "FRIEND COME TO GRID 44 SAFE K", "is_deception": true},
	{"sender": "(static)", "text": "YOU LEFT US", "may_be_unreal": true},
]
const OUTGOING := [
	"CQ DE PARA K",
	"SITREP 3 TANKS ROAD JUNCTION",
	"GRID 1234 ENEMY BATTERY",
	"REQUEST EXTRACTION K",
]

var radio_build: RadioBuild

var _keyer := MorseKeyer.new()
var _last_received := ""

var _title: Label
var _build_section: VBoxContainer
var _operate_section: VBoxContainer
var _current_label: Label
var _next_label: Label
var _parts_label: Label
var _build_button: Button
var _recv_status: Label
var _incoming_opt: OptionButton
var _listen_button: Button
var _copy_button: Button
var _steady_bar: ProgressBar
var _df_bar: ProgressBar
var _outgoing_opt: OptionButton
var _intel_check: CheckBox
var _live_label: Label
var _key_state: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	EventBus.radio_stage_changed.connect(_on_stage_changed)
	EventBus.steadiness_changed.connect(func(v): _steady_bar.value = v)
	EventBus.direction_finding_progress.connect(func(v): _df_bar.value = v)
	EventBus.morse_symbol.connect(_on_symbol)
	hide()


func _on_stage_changed(_id: String) -> void:
	refresh_build()
	_update_enabled()


func set_radio(rb: RadioBuild) -> void:
	radio_build = rb
	refresh_build()
	_update_enabled()


func open_build() -> void:
	show()
	_title.text = "WORKBENCH"
	_build_section.show()
	_operate_section.hide()
	refresh_build()


func open_operate() -> void:
	show()
	_title.text = "RADIO"
	_operate_section.show()
	_build_section.hide()
	_update_enabled()


func close() -> void:
	AudioDirector.stop_sidetone()
	hide()


# --- input (hand keying) -------------------------------------------------

func _input(event: InputEvent) -> void:
	if not (visible and _operate_section.visible):
		return
	if radio_build == null or not radio_build.can_transmit():
		return
	if event is InputEventKey and event.keycode == KEY_K:
		if event.pressed and not event.echo:
			_keyer.key_down(Time.get_ticks_msec())
			AudioDirector.start_sidetone()
			_key_state.text = "keying…"
		elif not event.pressed:
			_keyer.key_up(Time.get_ticks_msec())
			AudioDirector.stop_sidetone()


func _on_symbol(sym: String, keyed: bool) -> void:
	if keyed and visible and _operate_section.visible:
		_live_label.text = "Keyed: " + _live_label.text.trim_prefix("Keyed: ") + sym


# --- build face ----------------------------------------------------------

func refresh_build() -> void:
	if radio_build == null:
		return
	var cur := radio_build.current()
	_current_label.text = "Built: " + (cur["name"] if not cur.is_empty() else "nothing yet")
	var check := radio_build.check_next()
	var stage: Dictionary = check["stage"]
	if stage.is_empty():
		_next_label.text = "The hidden field station is complete."
		_build_button.disabled = true
	else:
		_next_label.text = "Next: %s\nNeeds: %s" % [stage["name"], ", ".join(PackedStringArray(stage["required"]))]
		if not check["missing"].is_empty():
			_next_label.text += "\nMissing: " + ", ".join(check["missing"])
		_build_button.disabled = not check["ok"]
	_parts_label.text = "Parts on hand: " + _parts_on_hand()


func _on_build() -> void:
	if radio_build != null and radio_build.build_next():
		refresh_build()


func _parts_on_hand() -> String:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return "—"
	var held := p.inventory.components_held()
	return ", ".join(held) if not held.is_empty() else "none"


# --- operate face --------------------------------------------------------

func _on_listen() -> void:
	if radio_build == null or not radio_build.can_receive():
		return
	var msg: Dictionary = INCOMING[_incoming_opt.selected]
	_last_received = msg["text"]
	EventBus.morse_incoming.emit({
		"text": msg["text"], "wpm": MorseSystem.DEFAULT_WPM, "fidelity": 1.0,
		"sender": msg.get("sender", ""),
		"is_friendly": msg.get("is_friendly", false),
		"is_deception": msg.get("is_deception", false),
		"may_be_unreal": msg.get("may_be_unreal", false),
	})
	_recv_status.text = "Heard from %s:\n%s" % [msg.get("sender", ""), msg["text"]]
	_copy_button.disabled = false


func _on_copy() -> void:
	if _last_received == "":
		return
	Notebook.add_entry(Notebook.Kind.MORSE_TRANSCRIPT, "Copied traffic",
		_last_received, {"morse": MorseSystem.encode(_last_received)}, Notebook.Trust.UNCERTAIN)
	_copy_button.disabled = true


func _on_transmit_auto() -> void:
	if radio_build == null or not radio_build.can_transmit():
		return
	_report(radio_build.transmit(OUTGOING[_outgoing_opt.selected], _steadiness(), _intel_check.button_pressed))


func _on_send_keyed() -> void:
	if radio_build == null or not radio_build.can_transmit() or _keyer.is_empty():
		return
	var result := _keyer.finish(OUTGOING[_outgoing_opt.selected], _steadiness())
	radio_build.report_transmission(result, _intel_check.button_pressed)
	_report(result)
	_keyer.reset()
	_live_label.text = ""


func _report(result: Dictionary) -> void:
	if result.is_empty():
		_key_state.text = "Transmitter not built."
		return
	_key_state.text = "Sent — likely read at %d%% (%.1fs on air)" % [
		int(result["fidelity"] * 100.0), result["duration"]]


func _steadiness() -> float:
	var p := get_tree().get_first_node_in_group("player") as Player
	return p.hand_steadiness.value if p != null else 1.0


func _update_enabled() -> void:
	var can_rx := radio_build != null and radio_build.can_receive()
	var can_tx := radio_build != null and radio_build.can_transmit()
	_listen_button.disabled = not can_rx
	if not can_rx:
		_recv_status.text = "No working receiver yet."
	_outgoing_opt.disabled = not can_tx
	_intel_check.disabled = not can_tx
	if not can_tx:
		_key_state.text = "No transmitter yet — build the weak transmitter."
	if _steady_bar != null:
		_steady_bar.value = _steadiness()
		_df_bar.value = radio_build.df_confidence if radio_build != null else 0.0


# --- construction --------------------------------------------------------

func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_top = 50
	panel.offset_right = -120
	panel.offset_bottom = -50
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	margin.add_child(root)

	_title = _label("RADIO", 22)
	root.add_child(_title)

	_build_section = _make_build_section()
	root.add_child(_build_section)
	_operate_section = _make_operate_section()
	root.add_child(_operate_section)


func _make_build_section() -> VBoxContainer:
	var v := VBoxContainer.new()
	_current_label = _label("Built: nothing yet")
	_next_label = _label("Next: —")
	_parts_label = _label("Parts on hand: —")
	_build_button = Button.new()
	_build_button.text = "Build next stage"
	_build_button.pressed.connect(_on_build)
	v.add_child(_current_label)
	v.add_child(_next_label)
	v.add_child(_parts_label)
	v.add_child(_build_button)
	v.add_child(_label("Tip: search the cache and the fallen operator for parts.", 14))
	return v


func _make_operate_section() -> VBoxContainer:
	var v := VBoxContainer.new()

	v.add_child(_label("RECEIVER", 18))
	_incoming_opt = OptionButton.new()
	for m in INCOMING:
		_incoming_opt.add_item("%s: %s" % [m["sender"], m["text"]])
	v.add_child(_incoming_opt)
	var rx_row := HBoxContainer.new()
	_listen_button = _button("Listen", _on_listen)
	_copy_button = _button("Copy to notebook", _on_copy)
	_copy_button.disabled = true
	rx_row.add_child(_listen_button)
	rx_row.add_child(_copy_button)
	v.add_child(rx_row)
	_recv_status = _label("No working receiver yet.")
	v.add_child(_recv_status)

	v.add_child(_label("TRANSMITTER", 18))
	v.add_child(_label("Hand: hold [K] to key, then Send keyed. Or auto-key.", 14))
	var steady_row := HBoxContainer.new()
	steady_row.add_child(_label("Steadiness", 14))
	_steady_bar = _bar()
	steady_row.add_child(_steady_bar)
	v.add_child(steady_row)
	var df_row := HBoxContainer.new()
	df_row.add_child(_label("DF risk", 14))
	_df_bar = _bar()
	df_row.add_child(_df_bar)
	v.add_child(df_row)

	_outgoing_opt = OptionButton.new()
	for t in OUTGOING:
		_outgoing_opt.add_item(t)
	v.add_child(_outgoing_opt)
	_intel_check = CheckBox.new()
	_intel_check.text = "Carries the reconnaissance report"
	v.add_child(_intel_check)

	_live_label = _label("Keyed: ")
	v.add_child(_live_label)
	var tx_row := HBoxContainer.new()
	tx_row.add_child(_button("Transmit (auto-key)", _on_transmit_auto))
	tx_row.add_child(_button("Send keyed", _on_send_keyed))
	v.add_child(tx_row)
	_key_state = _label("")
	v.add_child(_key_state)
	return v


func _label(text: String, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _bar() -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 1.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(220, 12)
	return b
