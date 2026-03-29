extends Node3D

# RTS game hub — replaces Game.gd for the StarCraft-style mode.
# Spawns workers, wires selection/commands, manages resource loop.

const WorkerScene = preload("res://src/entities/Worker.gd")

const STARTING_WORKERS := 3
const MAX_WORKERS      := 10
const WIN_GOLD         := 1000.0
const CAMP_POS         := Vector3(10.0, 0.0, 12.0)

@onready var hud: CanvasLayer       = $RTSHUD
@onready var cam: Node3D            = $RTSCamera
@onready var pause_menu: CanvasLayer = $PauseMenu

var _workers: Array = []
var _worker_count: int = 0
var _max_workers: int = MAX_WORKERS
var _game_won: bool = false

func _ready() -> void:
	# Set up camera
	cam.position = Vector3(0, 0, 5)   # start near camp area
	SelectionManager.set_camera(cam)

	# Add drag rect to a UI layer
	var drag_layer := CanvasLayer.new()
	drag_layer.layer = 10
	add_child(drag_layer)
	drag_layer.add_child(SelectionManager.get_drag_rect())

	# Wire selection signals
	SelectionManager.selection_changed.connect(_on_selection_changed)
	SelectionManager.command_issued.connect(_on_command_issued)

	# Wire save signals
	SaveManager.gold_changed.connect(_on_gold_changed)

	# Add mining zones to groups for selection system detection
	_setup_zone_groups()

	# Wire pause menu
	pause_menu.get_node("Panel/VBox/ResumeBtn").pressed.connect(pause_menu._on_resume_pressed)
	pause_menu.get_node("Panel/VBox/SaveBtn").pressed.connect(pause_menu._on_save_pressed)
	pause_menu.get_node("Panel/VBox/QuitBtn").pressed.connect(pause_menu._on_quit_pressed)

	# Spatial ambient audio
	Audio.start_ambient("river", Vector3(-18.0, 0.5, 0.0), -8.0, 35.0)
	Audio.start_ambient("fire", Vector3(6.5, 0.7, 10.5), -14.0, 18.0)

	# Spawn starting workers
	for i in range(STARTING_WORKERS):
		var offset := Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		_spawn_worker(CAMP_POS + offset)

	hud.update_worker_count(_worker_count, _max_workers)
	hud.show_message("Welcome to Gold Rush 1849! Select workers and right-click to mine.", 5.0)

func _setup_zone_groups() -> void:
	# Add zones to groups so SelectionManager can find them
	for zone_path in ["World/River/PanZone", "World/River/RichZone", "World/River/ShallowZone",
					   "World/RockZone", "World/EarthZone"]:
		var zone := get_node_or_null(zone_path)
		if zone:
			zone.add_to_group("mining_zones")

	# Timber zones are spawned by Scenery
	var scenery = $World/Scenery
	if scenery and "timber_zones" in scenery:
		for tzone in scenery.timber_zones:
			tzone.add_to_group("timber_zones")

func _spawn_worker(pos: Vector3) -> void:
	var worker := CharacterBody3D.new()
	# Can't instantiate a script directly on CharacterBody3D like this,
	# so we use a different approach: create the node and set the script
	worker.set_script(WorkerScene)
	worker.position = pos + Vector3(0, 1, 0)
	worker.home_pos = CAMP_POS
	$Workers.add_child(worker)
	worker.equip_tool("pan")
	worker.work_completed.connect(_on_work_completed)
	_workers.append(worker)
	_worker_count += 1

# ─── Selection ────────────────────────────────────────────────────────────────

func _on_selection_changed(units: Array) -> void:
	hud.update_selection(units)

# ─── Commands ─────────────────────────────────────────────────────────────────

func _on_command_issued(world_pos: Vector3, target_node: Node3D) -> void:
	for unit in SelectionManager.selected_units:
		if not is_instance_valid(unit):
			continue

		if target_node:
			if target_node.is_in_group("mining_zones"):
				unit.command_mine(target_node)
				Audio.play("ui_click", -12.0)
			elif target_node.is_in_group("timber_zones"):
				unit.command_chop(target_node)
				Audio.play("ui_click", -12.0)
		else:
			unit.command_move(world_pos)

	# Visual feedback — spawn a move marker
	_spawn_move_marker(world_pos)

func _spawn_move_marker(pos: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.3
	mesh.outer_radius = 0.4
	mesh.rings = 12
	mesh.ring_segments = 12
	marker.mesh = mesh
	marker.position = pos + Vector3(0, 0.1, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.2, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.set_surface_override_material(0, mat)
	add_child(marker)

	# Fade out and remove
	var tween := create_tween()
	tween.tween_property(mat, "albedo_color", Color(0.2, 1.0, 0.2, 0.0), 1.0)
	tween.tween_callback(marker.queue_free)

# ─── Work completed ──────────────────────────────────────────────────────────

func _on_work_completed(worker, resource_type: String, amount: float) -> void:
	if resource_type == "gold":
		_spawn_gold_burst(worker.global_position)
		Audio.play("gold_chime", -8.0)
	elif resource_type == "timber":
		Audio.play("wood_collect", -6.0)

# ─── Gold progression ────────────────────────────────────────────────────────

func _on_gold_changed(amount: float) -> void:
	if amount >= WIN_GOLD and not _game_won:
		_game_won = true
		hud.show_message("You struck it rich! %.1fg gold collected!" % amount, 10.0)

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu.visible:
			pause_menu.close()
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()

# ─── Gold particles ──────────────────────────────────────────────────────────

func _spawn_gold_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position              = pos + Vector3(0, 1.2, 0)
	p.amount                = 10
	p.lifetime              = 0.8
	p.one_shot              = true
	p.explosiveness         = 0.95
	p.direction             = Vector3(0, 1, 0)
	p.spread                = 55.0
	p.gravity               = Vector3(0, -6.0, 0)
	p.initial_velocity_min  = 2.0
	p.initial_velocity_max  = 4.0
	p.scale_amount_min      = 0.06
	p.scale_amount_max      = 0.16
	p.color                 = Color(1.0, 0.85, 0.1, 1.0)
	add_child(p)
	p.emitting = true
	await get_tree().create_timer(2.0).timeout
	p.queue_free()
