class_name GameUi
extends CanvasLayer
## Top-level UI: owns the HUD and the toggleable Notebook and Radio panels,
## routes the toggle inputs, dims the world behind an open panel, and frees the
## cursor / freezes the player while a panel is up. Workbench and radio
## interactions open the right panel via EventBus.interacted, so world objects
## stay UI-agnostic. Also shows the ending card.

const ENDINGS := {
	"freezing": ["FROZEN", "The cold finished what the drop began. The set never warmed."],
	"perished": ["LOST", "Wounds, hunger, and snow. The mission ends in the white."],
	"capture": ["TAKEN", "They followed the wire, the smoke, the signal — and found you."],
	"false_rescue": ["FALSE RESCUE", "The friendly voice was theirs all along. You walked to it."],
	"revenge": ["RECKONING", "You couldn't go home, so you made them pay for the others."],
	"rescue": ["EXFIL", "The field station reached them. They came for you in the dark."],
	"successful_mission": ["MISSION", "The truth got out, even if you didn't. It was enough."],
	"ghost_signal": ["GHOST SIGNAL", "They found your body beside a dead radio. Your call sign kept transmitting for days."],
	"failed_intelligence": ["SILENCE", "What you sent was wrong, or never understood. Nothing came."],
	"ambiguous": ["STATIC", "Whether any of it was real, you will never be sure."],
}

var radio_build: RadioBuild

var _hud: Hud
var _notebook: NotebookView
var _radio: RadioView
var _squad_voices: SquadVoices
var _dim: ColorRect


func _ready() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.hide()
	add_child(_dim)

	_hud = Hud.new()
	add_child(_hud)
	_notebook = NotebookView.new()
	add_child(_notebook)
	_radio = RadioView.new()
	add_child(_radio)
	_squad_voices = SquadVoices.new()
	add_child(_squad_voices)
	_squad_voices.voice.connect(_on_squad_voice)

	EventBus.interacted.connect(_on_interacted)
	EventBus.ending_reached.connect(_on_ending)

	if radio_build != null:
		_radio.set_radio(radio_build)


func set_radio_build(rb: RadioBuild) -> void:
	radio_build = rb
	if _radio != null:
		_radio.set_radio(rb)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_notebook"):
		if _notebook.visible:
			_close_all()
		else:
			_open(_notebook, true)
	elif event.is_action_pressed("toggle_radio"):
		if _radio.visible:
			_close_all()
		else:
			_open_radio_operate()
	elif event.is_action_pressed("pause"):
		if _any_open():
			_close_all()


func _on_interacted(node: Node) -> void:
	var it := node as Interactable
	if it == null:
		return
	match it.kind:
		Interactable.Kind.WORKBENCH:
			_open_radio_build()
		Interactable.Kind.RADIO:
			_open_radio_operate()


# --- panel management ----------------------------------------------------

func _open(panel: Control, do_refresh: bool = false) -> void:
	_hide_panels()
	panel.show()
	if do_refresh and panel.has_method("refresh"):
		panel.call("refresh")
	_dim.show()
	_set_player(false)


func _open_radio_operate() -> void:
	_hide_panels()
	_radio.open_operate()
	_dim.show()
	_set_player(false)


func _open_radio_build() -> void:
	_hide_panels()
	_radio.open_build()
	_dim.show()
	_set_player(false)


func _hide_panels() -> void:
	if _notebook.visible:
		_notebook.hide()
	if _radio.visible:
		_radio.close()


func _close_all() -> void:
	_hide_panels()
	_dim.hide()
	_set_player(true)


func _any_open() -> bool:
	return _notebook.visible or _radio.visible


func _set_player(is_active: bool) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null:
		p.set_active(is_active)


# --- captions & endings --------------------------------------------------

func _on_squad_voice(line: String, speaker: String) -> void:
	var text := "\"%s\"" % line
	if speaker != "":
		text = "%s: %s" % [speaker, text]
	_hud.show_caption(text, Color(0.82, 0.79, 0.7))


func _on_ending(id: String) -> void:
	_hide_panels()
	_set_player(false)
	var info: Array = ENDINGS.get(id, ["END", ""])
	var card := ColorRect.new()
	card.color = Color(0, 0, 0, 0.92)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(card)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -300
	box.offset_right = 300
	card.add_child(box)
	var title := Label.new()
	title.text = info[0]
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := Label.new()
	body.text = info[1]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(600, 0)
	box.add_child(body)
