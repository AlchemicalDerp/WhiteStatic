extends Node3D
## Boot scene. Assembles a small, playable winter test field so the core loop is
## reachable immediately: scavenge parts from a cache and the fallen operator,
## build the radio at the workbench, listen and transmit at the radio, watch the
## cold and the mind degrade your keying, and avoid the patrol. The geometry is
## placeholder; this is a scaffold harness, not a level.

const PLAYER := preload("res://src/player/player.tscn")

const RADIO_POS := Vector3(6, 0, -6)


func _ready() -> void:
	_build_environment()

	var player := PLAYER.instantiate() as Player
	player.position = Vector3(0, 1, 0)
	add_child(player)
	player.add_child(Footprints.new())

	var radio := RadioBuild.new()
	radio.inventory = player.inventory
	radio.transmit_origin = RADIO_POS
	add_child(radio)

	var recon := ReconLog.new()
	add_child(recon)

	var ui := GameUi.new()
	add_child(ui)
	ui.set_radio_build(radio)

	# Sync the freshly-built HUD with current values.
	player.vitals.broadcast()
	EventBus.steadiness_changed.emit(player.hand_steadiness.value)

	_build_interactables()
	_build_patrol()
	_seed_run(player, recon)

	GameState.start_run()


# --- world ---------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.26, 0.34)
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.55, 0.66)
	env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 35, 0)
	moon.light_color = Color(0.7, 0.78, 0.95)
	moon.light_energy = 0.6
	moon.shadow_enabled = true
	add_child(moon)

	_ground()
	for pos in [Vector3(8, 0, -4), Vector3(-6, 0, -11), Vector3(3, 0, -15), Vector3(-12, 0, 2), Vector3(11, 0, -12)]:
		_tree(pos)


func _ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(120, 1, 120)
	mesh.mesh = bm
	mesh.position = Vector3(0, -0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.82, 0.88)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _tree(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = pos
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.4
	cyl.height = 5.0
	shape.shape = cyl
	shape.position = Vector3(0, 2.5, 0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.4
	cm.height = 5.0
	mesh.mesh = cm
	mesh.position = Vector3(0, 2.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.12)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)


func _build_interactables() -> void:
	_interactable(Interactable.Kind.WORKBENCH, "Use workbench", Vector3(4, 0, -3), {}, "")
	_interactable(Interactable.Kind.RADIO, "Use radio", RADIO_POS, {}, "")
	_interactable(Interactable.Kind.WATER, "Melt snow", Vector3(10, 0, 2), {}, "")
	_interactable(Interactable.Kind.SCAVENGE, "Search supply cache", Vector3(-3, 0, -5),
		{"coil": 1, "crystal": 1, "valve": 1, "battery": 1, "insulator": 1}, "")
	_interactable(Interactable.Kind.SCAVENGE, "Search scattered drop", Vector3(-8, 0, -3),
		{"coil": 1, "crystal": 1, "battery": 1, "antenna_wire": 1, "field_wire": 1, "scrap_metal": 1}, "")
	_interactable(Interactable.Kind.CORPSE, "Search the operator", Vector3(2, 0, -9),
		{"antenna_wire": 1, "valve": 1, "headphones": 1, "insulator": 1, "tools": 1}, "operator")

	var camp := Camp.new()
	camp.position = Vector3(0, 0, 4)
	add_child(camp)


func _interactable(kind: Interactable.Kind, prompt: String, pos: Vector3, loot: Dictionary, squad_id: String) -> void:
	var node := Interactable.new()
	node.kind = kind
	node.prompt = prompt
	node.loot = loot
	node.squad_id = squad_id
	node.position = pos
	add_child(node)


func _build_patrol() -> void:
	var patrol := PatrolAgent.new()
	patrol.position = Vector3(-4, 0, -18)
	patrol.waypoints = [
		Vector3(-4, 0, -18), Vector3(9, 0, -18),
		Vector3(9, 0, -7), Vector3(-9, 0, -8),
	]
	add_child(patrol)


# --- seeding -------------------------------------------------------------

func _seed_run(player: Player, recon: ReconLog) -> void:
	# Minimal landing kit, and a wound so the steadiness link is visible early.
	player.inventory.add("headphones", 1)
	player.inventory.add("scrap_metal", 2)
	player.wound_system.add_wound("shrapnel", 0.4)

	Notebook.add_entry(Notebook.Kind.MISSION, "Mission orders",
		"Build a working radio. Observe enemy dispositions. Get the truth out before the cold or the enemy do.")

	# A demo observation: you counted 3 vehicles; there were 4 (75% accurate).
	recon.log_observation("vehicle_count", 3, 4)
