class_name PatrolAgent
extends CharacterBody3D
## A patrol that walks a route and *infers* the player's presence from stimuli
## and line of sight — it is intelligent, not supernatural. Movement is
## deliberately simple for the scaffold (steer toward a target on a flat
## field); real navigation, dogs, listening posts, and direction-finding teams
## are future work (see docs/ROADMAP.md).

enum State { PATROL, INVESTIGATE, SEARCH, RETURN }

@export var waypoints: Array[Vector3] = []
@export var speed: float = 2.0
@export var view_range: float = 18.0
@export var view_angle_deg: float = 70.0
@export var hearing_range: float = 14.0
@export var suspicion_decay: float = 0.06

var suspicion := Suspicion.new()
var state: State = State.PATROL

var _wp_index: int = 0
var _search_anchor: Vector3 = Vector3.ZERO
var _search_target: Vector3 = Vector3.ZERO
var _search_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _last_level: int = -1
var _seeing_player: bool = false


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 8   # enemy
	collision_mask = 1    # world
	_ensure_visual()
	EventBus.stimulus_emitted.connect(_on_stimulus)


func _physics_process(delta: float) -> void:
	_sense_player()
	suspicion.decay(suspicion_decay * delta)
	_update_state()
	_steer(delta, _current_target())
	_emit_level_changes()


# --- Sensing -------------------------------------------------------------

func _sense_player() -> void:
	var seen := _can_see_player()
	if seen:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		suspicion.value = 1.0
		suspicion.last_known_position = p.global_position
		suspicion.has_target = true
		if not _seeing_player:
			EventBus.player_spotted.emit(self)
	_seeing_player = seen


func _can_see_player() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return false
	var to := p.global_position - global_position
	var dist := to.length()
	if dist > view_range:
		return false
	var forward := -global_transform.basis.z
	if rad_to_deg(forward.angle_to(to)) > view_angle_deg:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5, p.global_position + Vector3.UP * 0.9)
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	return hit.is_empty() or hit.get("collider") == p


func _on_stimulus(s: Dictionary) -> void:
	var dist := global_position.distance_to(s["position"])
	var reach: float = s["radius"]
	var is_audible: bool = s["type"] in [Stimulus.Type.SOUND, Stimulus.Type.RADIO]
	if is_audible:
		reach += hearing_range
	else:
		reach += view_range
	if dist > reach:
		return
	var falloff := 1.0 - dist / reach
	suspicion.add(s["intensity"] * falloff * 0.6, s["position"])


# --- State & movement ----------------------------------------------------

func _update_state() -> void:
	var new_state := state
	match suspicion.level():
		Suspicion.Level.CALM:
			new_state = State.PATROL
		Suspicion.Level.CURIOUS, Suspicion.Level.ALERTED:
			new_state = State.INVESTIGATE
		Suspicion.Level.SEARCHING:
			if state != State.SEARCH:
				_search_anchor = suspicion.last_known_position
				_search_target = _search_anchor
				_search_timer = 0.0
			new_state = State.SEARCH
	if new_state != state:
		state = new_state
		EventBus.enemy_state_changed.emit(self, state)


func _current_target() -> Vector3:
	match state:
		State.INVESTIGATE:
			return suspicion.last_known_position
		State.SEARCH:
			return _search_target
		_:
			if waypoints.is_empty():
				return global_position
			return waypoints[_wp_index]


func _steer(delta: float, target: Vector3) -> void:
	var to := target - global_position
	to.y = 0.0
	var reached := to.length() < 1.0

	if reached:
		match state:
			State.PATROL:
				if not waypoints.is_empty():
					_wp_index = (_wp_index + 1) % waypoints.size()
			State.SEARCH:
				_search_timer -= delta
				if _search_timer <= 0.0:
					_search_timer = randf_range(1.5, 3.0)
					var off := Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
					_search_target = _search_anchor + off
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var horiz := to.normalized() * speed
		velocity.x = horiz.x
		velocity.z = horiz.z
		look_at(Vector3(target.x, global_position.y, target.z), Vector3.UP)

	velocity.y = velocity.y - _gravity * delta if not is_on_floor() else 0.0
	move_and_slide()


func _emit_level_changes() -> void:
	var lvl := suspicion.level()
	if lvl != _last_level:
		_last_level = lvl
		if lvl >= Suspicion.Level.CURIOUS:
			EventBus.enemy_alerted.emit(self, lvl)


# --- Visual (self-contained so the test field shows the patrol) ----------

func _ensure_visual() -> void:
	if has_node("Body"):
		return
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	var col := CollisionShape3D.new()
	col.name = "Body"
	col.shape = shape
	col.position = Vector3(0, 0.95, 0)
	add_child(col)

	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.7
	var mesh := MeshInstance3D.new()
	mesh.mesh = cap
	mesh.position = Vector3(0, 0.95, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.24, 0.2)
	mesh.material_override = mat
	add_child(mesh)
