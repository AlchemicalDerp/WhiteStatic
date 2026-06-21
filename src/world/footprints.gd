class_name Footprints
extends Node3D
## Trails the player and, every few metres of travel, emits a TRACKS stimulus —
## the prints a patrol or its dogs can cut and follow. Fresh tracks read more
## strongly by day; deep night hides them a little. Add it as a child of the
## player (or anywhere — it will find the player group).
##
## TODO: spawn persistent decals/quads that fade as snow falls.

@export var spacing: float = 2.5        ## metres between prints
@export var track_intensity: float = 0.35
@export var track_radius: float = 16.0

var _target: Node3D
var _last_pos: Vector3


func _ready() -> void:
	_target = get_parent() as Node3D
	if _target == null or not (_target is Player):
		_target = get_tree().get_first_node_in_group("player") as Node3D
	if _target != null:
		_last_pos = _target.global_position


func _physics_process(_delta: float) -> void:
	if _target == null:
		return
	var pos := _target.global_position
	if _last_pos.distance_to(pos) >= spacing:
		_last_pos = pos
		var visibility := lerpf(1.0, 0.6, GameClock.darkness())
		Stimulus.emit(Stimulus.Type.TRACKS, pos, track_intensity * visibility, track_radius, _target)
