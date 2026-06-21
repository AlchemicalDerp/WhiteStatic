class_name NotebookView
extends Control
## Renders the player's notebook. It re-reads from the Notebook singleton, so
## when the SymptomSystem corrupts an entry the page simply shows the changed
## text — never a "this was altered" flag. Deciding what to trust is the game.

const KIND_NAMES := [
	"Transcript", "Map", "Patrol", "Sketch", "Mission",
	"Radio diagram", "Wound", "Observation", "Personal",
]

var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	EventBus.notebook_entry_added.connect(_on_changed)
	EventBus.notebook_corrupted.connect(func(_e, _k): _on_changed({}))
	hide()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 140
	panel.offset_top = 60
	panel.offset_right = -140
	panel.offset_bottom = -60
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "NOTEBOOK"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var hint := Label.new()
	hint.text = "What you wrote down. Not all of it may be true."
	hint.modulate = Color(0.7, 0.72, 0.74)
	vbox.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var entries := Notebook.entries()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.modulate = Color(0.6, 0.62, 0.64)
		_list.add_child(empty)
		return
	for i in range(entries.size() - 1, -1, -1):
		_list.add_child(_entry_label(entries[i]))


func _entry_label(entry: Dictionary) -> Label:
	var kind: int = entry["kind"]
	var header := "%s · %s · %s" % [
		entry.get("stamp", ""),
		KIND_NAMES[kind] if kind < KIND_NAMES.size() else "Note",
		entry.get("title", ""),
	]
	var l := Label.new()
	l.text = "%s\n%s\n" % [header, entry.get("body", "")]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(720, 0)
	return l


func _on_changed(_e: Dictionary) -> void:
	if visible:
		refresh()
