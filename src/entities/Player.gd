extends CharacterBody3D

const ToolMeshesClass = preload("res://src/entities/ToolMeshes.gd")

const SPEED = 5.0
const GRAVITY = 9.8

var current_tool: String  = "pan"
var current_zone          = null   # MiningZone or null
var _zone_stack: Array    = []     # overlapping mining zones
var current_timber_zone   = null   # TimberZone or null
var current_cabin_zone    = null   # CabinZone or null
var is_mining: bool       = false
var is_chopping: bool     = false
var chop_count: int       = 0      # hits so far (3 = 1 timber)
var camera_pivot: Node3D  = null

var walk_cycle: float  = 0.0
var action_blend: float = 0.0
var action_cycle: float = 0.0

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
	# Create mount point on right hand
	_tool_mount = Node3D.new()
	_tool_mount.name = "ToolMount"
	var hand = $Body/RightArm/RightHand
	if hand:
		_tool_mount.position = Vector3(0.0, -0.04, 0.16)
		hand.add_child(_tool_mount)
	else:
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
	# Always use the zone's required tool, not whatever the player has selected
	var tool_id: String = current_zone.get_tool_id() if current_zone else current_tool
	# Check if player owns the required tool
	if not SaveManager.has_tool(tool_id) and tool_id != "pan":
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
	if zone not in _zone_stack:
		_zone_stack.append(zone)
	current_zone = zone
	current_tool = zone.get_tool_id()

func exit_mining_zone() -> void:
	# Remove the exited zone and restore the previous one if overlapping
	if current_zone in _zone_stack:
		_zone_stack.erase(current_zone)
	if _zone_stack.size() > 0:
		current_zone = _zone_stack.back()
		current_tool = current_zone.get_tool_id()
	else:
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
	var working := is_mining or is_chopping
	action_blend = lerp(action_blend, 1.0 if working else 0.0, delta * 6.0)

	if action_blend > 0.01:
		action_cycle += delta
		if is_chopping:
			_animate_axe_chop(delta)
		else:
			match current_tool:
				"pan", "pan_upgraded":
					_animate_pan(delta)
				"pickaxe":
					_animate_pickaxe(delta)
				"shovel":
					_animate_shovel(delta)
				_:
					_animate_pan(delta)
		walk_cycle = 0.0
		return

	action_cycle = 0.0

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
		body.rotation.z      = lerp(body.rotation.z,      0.0, delta * 10.0)
		body.position.y      = lerp(body.position.y,      0.0, delta * 10.0)

# ─── Pan: crouch down, swirl arms side to side ──────────────────────────────

func _animate_pan(delta: float) -> void:
	var b := action_blend
	var swirl := sin(action_cycle * 5.0) * 0.4
	# Crouch low, lean forward
	body.rotation.x      = lerp(body.rotation.x,      b * 0.55, delta * 8.0)
	body.position.y      = lerp(body.position.y,      b * -0.20, delta * 8.0)
	# Arms reach forward and swirl together (holding pan)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  b * 1.2 + swirl * 0.2, delta * 8.0)
	right_arm.rotation.x = lerp(right_arm.rotation.x, b * 1.2 + swirl * 0.2, delta * 8.0)
	# Subtle body sway with the swirl
	body.rotation.z      = lerp(body.rotation.z,      swirl * b * 0.12, delta * 8.0)
	# Legs braced
	left_leg.rotation.x  = lerp(left_leg.rotation.x,  b * -0.3, delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, b * -0.2, delta * 8.0)

# ─── Pickaxe: overhead swing down with follow-through ───────────────────────

func _animate_pickaxe(delta: float) -> void:
	var b := action_blend
	# Repeating swing cycle: wind up (0-0.4), slam down (0.4-0.6), hold (0.6-1.0)
	var t := fmod(action_cycle * 2.5, 1.0)
	var right_rot: float
	var left_rot: float
	var body_lean: float
	var body_dip: float

	if t < 0.4:
		# Wind up — arms go back over head
		var wind := t / 0.4
		right_rot = b * (-1.8 * wind)        # arms swing back
		left_rot  = b * (-1.5 * wind)
		body_lean = b * (-0.15 * wind)        # lean back slightly
		body_dip  = 0.0
	elif t < 0.6:
		# Slam down — fast forward swing
		var slam := (t - 0.4) / 0.2
		right_rot = b * (-1.8 + 3.0 * slam)  # swing through to forward
		left_rot  = b * (-1.5 + 2.6 * slam)
		body_lean = b * (-0.15 + 0.55 * slam) # lurch forward
		body_dip  = b * -0.08 * slam          # body drops with impact
	else:
		# Recovery — ease back to ready
		var ease := (t - 0.6) / 0.4
		right_rot = b * (1.2 - 1.2 * ease)
		left_rot  = b * (1.1 - 1.1 * ease)
		body_lean = b * (0.4 - 0.4 * ease)
		body_dip  = b * -0.08 * (1.0 - ease)

	right_arm.rotation.x = lerp(right_arm.rotation.x, right_rot, delta * 12.0)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  left_rot,  delta * 12.0)
	body.rotation.x      = lerp(body.rotation.x,      body_lean, delta * 10.0)
	body.position.y      = lerp(body.position.y,      body_dip,  delta * 10.0)
	# Legs spread for stability
	left_leg.rotation.x  = lerp(left_leg.rotation.x,  b * -0.15, delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, b * 0.1,   delta * 8.0)

# ─── Shovel: dig and lift motion ────────────────────────────────────────────

func _animate_shovel(delta: float) -> void:
	var b := action_blend
	# Cycle: push down (0-0.35), scoop up (0.35-0.65), toss (0.65-1.0)
	var t := fmod(action_cycle * 2.0, 1.0)
	var right_rot: float
	var left_rot: float
	var body_lean: float
	var body_dip: float

	if t < 0.35:
		# Push shovel into ground — lean forward, arms down
		var push := t / 0.35
		right_rot = b * (0.8 + 0.5 * push)
		left_rot  = b * (0.6 + 0.4 * push)
		body_lean = b * (0.35 + 0.2 * push)
		body_dip  = b * -0.12 * push
	elif t < 0.65:
		# Scoop up — lift arms, straighten body
		var lift := (t - 0.35) / 0.3
		right_rot = b * (1.3 - 1.8 * lift)
		left_rot  = b * (1.0 - 1.4 * lift)
		body_lean = b * (0.55 - 0.55 * lift)
		body_dip  = b * (-0.12 + 0.12 * lift)
	else:
		# Toss to side — twist and dump
		var toss := (t - 0.65) / 0.35
		right_rot = b * (-0.5 + 0.5 * toss)
		left_rot  = b * (-0.4 + 0.4 * toss)
		body_lean = b * (0.1 * (1.0 - toss))
		body_dip  = 0.0

	right_arm.rotation.x = lerp(right_arm.rotation.x, right_rot, delta * 10.0)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  left_rot,  delta * 10.0)
	body.rotation.x      = lerp(body.rotation.x,      body_lean, delta * 10.0)
	body.position.y      = lerp(body.position.y,      body_dip,  delta * 10.0)
	# Foot on shovel — one leg pushes down
	left_leg.rotation.x  = lerp(left_leg.rotation.x,  b * -0.25, delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, b * 0.15,  delta * 8.0)

# ─── Axe chop: side swing ───────────────────────────────────────────────────

func _animate_axe_chop(delta: float) -> void:
	var b := action_blend
	# Cycle: wind (0-0.3), chop (0.3-0.5), hold (0.5-1.0)
	var t := fmod(action_cycle * 3.0, 1.0)
	var right_rot: float
	var left_rot: float
	var body_twist: float
	var body_lean: float

	if t < 0.3:
		# Wind up — arms back and to the right
		var wind := t / 0.3
		right_rot  = b * (-1.4 * wind)
		left_rot   = b * (-0.8 * wind)
		body_twist = b * (-0.25 * wind)
		body_lean  = b * (-0.1 * wind)
	elif t < 0.5:
		# Chop — fast swing across
		var chop := (t - 0.3) / 0.2
		right_rot  = b * (-1.4 + 2.4 * chop)
		left_rot   = b * (-0.8 + 1.6 * chop)
		body_twist = b * (-0.25 + 0.45 * chop)
		body_lean  = b * (-0.1 + 0.4 * chop)
	else:
		# Recovery
		var ease := (t - 0.5) / 0.5
		right_rot  = b * (1.0 - 1.0 * ease)
		left_rot   = b * (0.8 - 0.8 * ease)
		body_twist = b * (0.2 - 0.2 * ease)
		body_lean  = b * (0.3 - 0.3 * ease)

	right_arm.rotation.x = lerp(right_arm.rotation.x, right_rot,  delta * 14.0)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  left_rot,   delta * 14.0)
	body.rotation.z      = lerp(body.rotation.z,       body_twist, delta * 12.0)
	body.rotation.x      = lerp(body.rotation.x,       body_lean,  delta * 10.0)
	left_leg.rotation.x  = lerp(left_leg.rotation.x,   b * 0.15,  delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x,  b * -0.1,  delta * 8.0)
	body.position.y      = lerp(body.position.y,       0.0,       delta * 8.0)

func _save_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://screenshot.png")
	print("Screenshot: " + OS.get_user_data_dir() + "/screenshot.png")
