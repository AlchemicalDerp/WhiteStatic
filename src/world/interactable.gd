class_name Interactable
extends StaticBody3D
## A configurable world object the Interactor can focus and use: a supply cache
## or fallen squadmate to search, the radio workbench, the radio itself, a
## water source. It builds its own simple visual + label so the test field is
## legible without art. UI panels (workbench/radio) are opened by GameUi, which
## listens for EventBus.interacted — Interactable stays UI-agnostic.

enum Kind { SCAVENGE, CORPSE, WORKBENCH, RADIO, WATER }

@export var kind: Kind = Kind.SCAVENGE
@export var prompt: String = "Search"
## item_id -> count, granted on a SCAVENGE/CORPSE search.
@export var loot: Dictionary = {}
@export var one_shot: bool = true
## For CORPSE: the GameState.squad id this body belongs to.
@export var squad_id: String = ""

signal used(by: Node)

var _spent: bool = false
var _label: Label3D


func _ready() -> void:
	collision_layer = 5  # world + interactable, so it is solid and focusable
	_ensure_visual()


func get_prompt() -> String:
	return "" if (_spent and one_shot) else prompt


func interact(player: Node) -> void:
	match kind:
		Kind.SCAVENGE, Kind.CORPSE:
			if _spent:
				return
			_give_loot(player)
			if kind == Kind.CORPSE:
				_squad_memory()
			Stimulus.emit(Stimulus.Type.DISTURBED_LOOT, global_position, 0.6, 12.0, self)
			_spent = true
			_refresh_label()
		Kind.WATER:
			var who := player as Player
			if who != null:
				who.vitals.drink()
		Kind.WORKBENCH, Kind.RADIO:
			pass  # GameUi opens the matching panel
	used.emit(player)


func _give_loot(player: Node) -> void:
	var who := player as Player
	if who == null:
		return
	for id in loot:
		who.inventory.add(id, loot[id])


func _squad_memory() -> void:
	for m in GameState.squad:
		if m["id"] == squad_id:
			Notebook.add_entry(Notebook.Kind.PERSONAL, m["name"],
				"%s — %s. Found in the snow." % [m["name"], m["role"]],
				{"squad_id": squad_id})
			return


# --- Visual --------------------------------------------------------------

func _ensure_visual() -> void:
	if has_node("Body"):
		return
	var size := _size_for_kind()
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.name = "Body"
	col.shape = box
	col.position = Vector3(0, size.y * 0.5, 0)
	add_child(col)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.position = Vector3(0, size.y * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _color_for_kind()
	mesh.material_override = mat
	add_child(mesh)

	_label = Label3D.new()
	_label.text = prompt
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, size.y + 0.4, 0)
	_label.modulate = Color(0.85, 0.88, 0.9)
	_label.outline_size = 6
	add_child(_label)


func _refresh_label() -> void:
	if _label != null:
		_label.text = get_prompt()
		_label.visible = get_prompt() != ""


func _size_for_kind() -> Vector3:
	match kind:
		Kind.WORKBENCH:
			return Vector3(1.6, 0.9, 0.8)
		Kind.CORPSE:
			return Vector3(1.8, 0.4, 0.7)
		Kind.RADIO:
			return Vector3(0.6, 0.5, 0.5)
		Kind.WATER:
			return Vector3(1.2, 0.2, 1.2)
		_:
			return Vector3(0.8, 0.8, 0.8)


func _color_for_kind() -> Color:
	match kind:
		Kind.WORKBENCH:
			return Color(0.35, 0.27, 0.18)
		Kind.CORPSE:
			return Color(0.3, 0.3, 0.33)
		Kind.RADIO:
			return Color(0.2, 0.28, 0.32)
		Kind.WATER:
			return Color(0.2, 0.35, 0.45)
		_:
			return Color(0.4, 0.36, 0.25)
