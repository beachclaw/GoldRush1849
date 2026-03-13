extends CharacterBody3D

const SPEED = 5.0
const GRAVITY = 9.8

var current_tool: String  = "pan"
var current_zone          = null   # MiningZone or null
var current_timber_zone   = null   # TimberZone or null
var current_cabin_zone    = null   # CabinZone or null
var is_mining: bool       = false
var is_chopping: bool     = false
var chop_count: int       = 0      # hits so far (3 = 1 timber)
var camera_pivot: Node3D  = null

var walk_cycle: float = 0.0
var pan_blend: float  = 0.0

signal mining_started(tool_id: String)
signal mining_finished(tool_id: String, amount: float, lucky: bool)
signal chopping_started()
signal chopping_hit(hits_done: int)
signal chopping_finished()
signal cabin_placed(zone)

@onready var body: Node3D              = $Body
@onready var left_arm: MeshInstance3D  = $Body/LeftArm
@onready var right_arm: MeshInstance3D = $Body/RightArm
@onready var left_leg: MeshInstance3D  = $Body/LeftLeg
@onready var right_leg: MeshInstance3D = $Body/RightLeg

func _ready() -> void:
	add_to_group("player")
	_build_pan_tool()
	# Sync gold from save
	SaveManager.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(amount: float) -> void:
	pass  # HUD listens directly to SaveManager

# ─── Tool mesh ────────────────────────────────────────────────────────────────

func _build_pan_tool() -> void:
	var tool_root := Node3D.new()
	tool_root.name = "ToolRoot"
	tool_root.position = Vector3(0.18, -0.05, 0.28)
	$Body/RightArm.add_child(tool_root)

	# Weathered tin/iron — authentic 1850s gold pan colors
	var mat_tin := StandardMaterial3D.new()
	mat_tin.albedo_color = Color(0.48, 0.44, 0.40)
	mat_tin.metallic     = 0.55
	mat_tin.roughness    = 0.50

	var mat_inner := StandardMaterial3D.new()
	mat_inner.albedo_color = Color(0.38, 0.32, 0.26)
	mat_inner.metallic     = 0.4
	mat_inner.roughness    = 0.65

	var mat_rim := StandardMaterial3D.new()
	mat_rim.albedo_color = Color(0.42, 0.38, 0.34)
	mat_rim.metallic     = 0.6
	mat_rim.roughness    = 0.40

	# Outer bowl — wide shallow dish, sloped sides (wider at top, narrow bottom)
	var bowl := MeshInstance3D.new()
	var bm   := CylinderMesh.new()
	bm.top_radius = 0.28; bm.bottom_radius = 0.15; bm.height = 0.09
	bm.radial_segments = 16
	bowl.mesh = bm
	tool_root.add_child(bowl)
	bowl.set_surface_override_material(0, mat_tin)

	# Inner floor — flat dark bottom visible inside the pan
	var floor_mi := MeshInstance3D.new()
	var fm       := CylinderMesh.new()
	fm.top_radius = 0.14; fm.bottom_radius = 0.14; fm.height = 0.015
	fm.radial_segments = 16
	floor_mi.mesh     = fm
	floor_mi.position = Vector3(0, 0.01, 0)
	tool_root.add_child(floor_mi)
	floor_mi.set_surface_override_material(0, mat_inner)

	# Rolled rim — thin ring at the top lip
	var rim := MeshInstance3D.new()
	var rim_m := TorusMesh.new()
	rim_m.inner_radius = 0.27; rim_m.outer_radius = 0.29
	rim_m.rings = 12; rim_m.ring_segments = 8
	rim.mesh     = rim_m
	rim.position = Vector3(0, 0.04, 0)
	tool_root.add_child(rim)
	rim.set_surface_override_material(0, mat_rim)

# ─── Physics ──────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if not is_mining and not is_chopping:
		var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var cam_yaw: float     = camera_pivot.yaw if camera_pivot else 0.0
		var direction: Vector3 = (Basis(Vector3.UP, cam_yaw) * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if direction:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.15)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2)
		velocity.z = move_toward(velocity.z, 0, SPEED * 2)

	move_and_slide()
	_animate_body(delta)

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if current_cabin_zone != null and not is_mining and not is_chopping:
			if SaveManager.has_cabin_kit():
				cabin_placed.emit(current_cabin_zone)
		elif current_timber_zone != null and not is_chopping and not is_mining:
			_start_chopping()
		elif current_zone != null and not is_mining and not is_chopping:
			_start_mining()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_save_screenshot()

# ─── Mining ───────────────────────────────────────────────────────────────────

func _start_mining() -> void:
	var tool_id := current_tool
	# Check if player owns the tool
	if not SaveManager.has_tool(tool_id) and tool_id != "pan":
		# Prompt them to buy it
		mining_started.emit("locked")
		return

	is_mining = true
	mining_started.emit(tool_id)

	var action_time := ToolSystem.get_action_time(tool_id)
	await get_tree().create_timer(action_time).timeout

	var quality: float      = current_zone.quality if current_zone else 1.0
	var result: Dictionary  = ToolSystem.calculate_yield(tool_id, quality)

	# Better pan upgrade multiplier
	if SaveManager.has_tool("pan_upgraded") and tool_id == "pan":
		result.amount *= 1.5

	SaveManager.add_gold(result.amount)
	mining_finished.emit(tool_id, result.amount, result.lucky)
	is_mining = false

# ─── Zone entry / exit ────────────────────────────────────────────────────────

func enter_mining_zone(zone) -> void:
	current_zone = zone
	current_tool = zone.get_tool_id()

func exit_mining_zone() -> void:
	current_zone = null
	current_tool = "pan"  # default back to pan

# ─── Timber zone entry / exit ────────────────────────────────────────────────

func enter_timber_zone(zone) -> void:
	current_timber_zone = zone

func exit_timber_zone() -> void:
	current_timber_zone = null
	chop_count = 0

# ─── Cabin zone entry / exit ────────────────────────────────────────────────

func enter_cabin_zone(zone) -> void:
	current_cabin_zone = zone

func exit_cabin_zone() -> void:
	current_cabin_zone = null

# ─── Chopping ────────────────────────────────────────────────────────────────

const CHOPS_PER_LOG := 3
const CHOP_TIME     := 1.0   # seconds per swing

func _start_chopping() -> void:
	if not SaveManager.has_tool("pickaxe"):
		mining_started.emit("locked")
		return

	is_chopping = true
	chop_count = 0
	chopping_started.emit()

	for i in range(CHOPS_PER_LOG):
		await get_tree().create_timer(CHOP_TIME).timeout
		chop_count += 1
		chopping_hit.emit(chop_count)

	SaveManager.add_timber(1)
	chopping_finished.emit()
	is_chopping = false

# ─── Animation ────────────────────────────────────────────────────────────────

func _animate_body(delta: float) -> void:
	var speed_xz := Vector2(velocity.x, velocity.z).length()
	pan_blend = lerp(pan_blend, 1.0 if (is_mining or is_chopping) else 0.0, delta * 6.0)

	if pan_blend > 0.01:
		body.rotation.x      = lerp(body.rotation.x,      pan_blend * 0.45,  delta * 8.0)
		left_arm.rotation.x  = lerp(left_arm.rotation.x,  pan_blend * 1.1,   delta * 8.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, pan_blend * 1.1,   delta * 8.0)
		left_leg.rotation.x  = lerp(left_leg.rotation.x,  pan_blend * -0.2,  delta * 8.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, pan_blend * -0.2,  delta * 8.0)
		body.position.y      = lerp(body.position.y,      pan_blend * -0.15, delta * 8.0)
		walk_cycle = 0.0
		return

	if speed_xz > 0.5:
		walk_cycle += delta * 9.0
		var swing := sin(walk_cycle) * 0.5
		left_arm.rotation.x  =  swing
		right_arm.rotation.x = -swing
		left_leg.rotation.x  = -swing * 0.8
		right_leg.rotation.x =  swing * 0.8
		body.rotation.x      = 0.0
		body.position.y      = abs(sin(walk_cycle * 2.0)) * 0.03
	else:
		left_arm.rotation.x  = lerp(left_arm.rotation.x,  0.0, delta * 10.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 10.0)
		left_leg.rotation.x  = lerp(left_leg.rotation.x,  0.0, delta * 10.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 10.0)
		body.rotation.x      = lerp(body.rotation.x,      0.0, delta * 10.0)
		body.position.y      = lerp(body.position.y,      0.0, delta * 10.0)

func _save_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://screenshot.png")
	print("Screenshot: " + OS.get_user_data_dir() + "/screenshot.png")
