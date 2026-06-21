class_name Camp
extends Area3D
## A temporary camp: while the player is inside and the fire is lit they warm up
## and are sheltered from the cold. The catch is the fire — it throws light and
## smoke that patrols can see, so a warm camp is also a beacon. Camps are meant
## to be hidden, defended, and abandoned once discovered (future work).

@export var lit: bool = true
## Real seconds between smoke stimuli while lit.
@export var smoke_interval: float = 8.0

var _player: Player
var _smoke_accum: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # detect the player body (layer 2)
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ensure_shape()


func _process(delta: float) -> void:
	if not lit:
		return
	_smoke_accum += delta
	if _smoke_accum >= smoke_interval:
		_smoke_accum = 0.0
		Stimulus.emit(Stimulus.Type.SMOKE, global_position, 0.5, 22.0, self)
	if _player != null:
		_apply(_player, true)


func set_lit(value: bool) -> void:
	lit = value
	if _player != null:
		_apply(_player, true)


func _on_body_entered(body: Node) -> void:
	var who := body as Player
	if who != null:
		_player = who
		_apply(_player, true)


func _on_body_exited(body: Node) -> void:
	if body == _player:
		_apply(_player, false)
		_player = null


func _apply(p: Player, inside: bool) -> void:
	p.vitals.near_fire = inside and lit
	p.vitals.sheltered = inside


func _ensure_shape() -> void:
	if has_node("Reach"):
		return
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	var col := CollisionShape3D.new()
	col.name = "Reach"
	col.shape = sphere
	add_child(col)

	# A faint fire so the camp reads in the test field.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position = Vector3(0, 0.6, 0)
	add_child(light)
