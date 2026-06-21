class_name Player
extends CharacterBody3D
## First-person controller. Owns movement and looking; survival state lives in
## the component children (Vitals, WoundSystem, HandSteadiness, Inventory) and
## interaction in the Interactor. When a UI panel opens, the UI calls
## set_active(false) so the world freezes and the cursor frees.

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.2
@export var crouch_speed: float = 1.6
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.0025

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interactor: Interactor = $Head/Camera3D/Interactor
@onready var vitals: Vitals = $Vitals
@onready var wound_system: WoundSystem = $WoundSystem
@onready var hand_steadiness: HandSteadiness = $HandSteadiness
@onready var inventory: Inventory = $Inventory

var active: bool = true
var _pitch: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)


func _ready() -> void:
	add_to_group("player")
	interactor.player = self
	vitals.wound_system = wound_system
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	# Mouse look is handled in _input (before the GUI) so HUD Controls such as
	# the crosshair can't swallow the motion events.
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
		head.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# Recapture the cursor on click (focus loss, or web pointer-lock which needs
	# a user gesture before it will engage).
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event.is_action_pressed("interact"):
		interactor.try_interact()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var sprinting := active and Input.is_action_pressed("sprint")
	var crouching := active and Input.is_action_pressed("crouch")
	var speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)

	var input_dir := Vector2.ZERO
	if active:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if dir != Vector3.ZERO:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	if active and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	move_and_slide()

	# Exertion feeds exhaustion, hunger, and warmth burn in Vitals.
	var moving := dir != Vector3.ZERO
	if sprinting and moving:
		vitals.activity = 0.9
	elif moving:
		vitals.activity = 0.5
	else:
		vitals.activity = 0.15


## Toggle player control. UI panels call this; false frees the cursor.
func set_active(value: bool) -> void:
	active = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
