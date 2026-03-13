extends CharacterBody3D

const ToolMeshesClass = preload("res://src/entities/ToolMeshes.gd")

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

var _tool_mount: Node3D  # attachment point on right arm
var _active_tool: Node3D # currently equipped tool mesh

func _ready() -> void:
	add_to_group("player")
	# Create mount point on right arm
	_tool_mount = Node3D.new()
	_tool_mount.name = "ToolMount"
	_tool_mount.position = Vector3(0.18, -0.05, 0.28)
	$Body/RightArm.add_child(_tool_mount)
	equip_tool("pan")
	# Sync gold from save
	SaveManager.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(amount: float) -> void:
	pass  # HUD listens directly to SaveManager

# ─── Tool equip ───────────────────────────────────────────────────────────────

func equip_tool(tool_id: String) -> void:
	if _active_tool:
		_active_tool.queue_free()
		_active_tool = null
	_active_tool = ToolMeshesClass.create(tool_id)
	_tool_mount.add_child(_active_tool)

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
	if not SaveManager.has_tool("axe"):
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
