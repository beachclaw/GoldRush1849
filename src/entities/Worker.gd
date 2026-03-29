extends CharacterBody3D

# AI-driven prospector worker — the RTS "SCV" equivalent.
# Walks to assigned zones, mines/chops, carries resources back to camp.

const ToolMeshesClass = preload("res://src/entities/ToolMeshes.gd")

enum State { IDLE, MOVING, MINING, CHOPPING, BUILDING, RETURNING }

const SPEED          := 4.0
const GRAVITY        := 9.8
const CARRY_CAPACITY := 5.0   # max gold per trip
const ARRIVAL_DIST   := 2.0   # how close to target before arriving

var state: int         = State.IDLE
var assigned_zone      = null   # MiningZone or TimberZone
var target_pos: Vector3 = Vector3.ZERO
var home_pos: Vector3   = Vector3.ZERO   # camp position for drop-off

var carried_gold: float = 0.0
var carried_timber: int = 0
var is_selected: bool   = false

var walk_cycle: float   = 0.0
var action_blend: float = 0.0
var action_cycle: float = 0.0
var _current_tool: String = "pan"

# Body references
var body: Node3D
var left_arm: MeshInstance3D
var right_arm: MeshInstance3D
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var _tool_mount: Node3D
var _active_tool: Node3D
var _selection_ring: MeshInstance3D

signal work_completed(worker, resource_type: String, amount: float)

func _ready() -> void:
	add_to_group("workers")
	add_to_group("selectable")
	_build_body()
	_build_selection_ring()

# ─── Body builder ─────────────────────────────────────────────────────────────

func _build_body() -> void:
	# Collision
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.38
	shape.height = 1.7
	col.shape = shape
	add_child(col)

	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	var mat_skin := StandardMaterial3D.new()
	mat_skin.albedo_color = Color(0.76, 0.58, 0.42)
	mat_skin.roughness = 0.88

	var mat_shirt := StandardMaterial3D.new()
	mat_shirt.albedo_color = Color(0.78, 0.72, 0.62)
	mat_shirt.roughness = 0.85

	var mat_overalls := StandardMaterial3D.new()
	mat_overalls.albedo_color = Color(0.42, 0.36, 0.26)
	mat_overalls.roughness = 0.85

	var mat_hat := StandardMaterial3D.new()
	mat_hat.albedo_color = Color(0.40, 0.28, 0.15)
	mat_hat.roughness = 0.82

	var mat_boot := StandardMaterial3D.new()
	mat_boot.albedo_color = Color(0.28, 0.20, 0.12)
	mat_boot.roughness = 0.78

	# Head
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_m := SphereMesh.new()
	head_m.radius = 0.22; head_m.height = 0.40
	head_m.radial_segments = 16; head_m.rings = 12
	head.mesh = head_m
	head.position = Vector3(0, 0.62, 0)
	head.set_surface_override_material(0, mat_skin)
	body.add_child(head)

	# Hat brim
	var brim := MeshInstance3D.new()
	var brim_m := CylinderMesh.new()
	brim_m.top_radius = 0.30; brim_m.bottom_radius = 0.28
	brim_m.height = 0.035; brim_m.radial_segments = 16
	brim.mesh = brim_m
	brim.position = Vector3(0, 0.20, 0.02)
	brim.set_surface_override_material(0, mat_hat)
	head.add_child(brim)

	# Hat crown
	var crown := MeshInstance3D.new()
	var crown_m := CylinderMesh.new()
	crown_m.top_radius = 0.12; crown_m.bottom_radius = 0.18
	crown_m.height = 0.18; crown_m.radial_segments = 12
	crown.mesh = crown_m
	crown.position = Vector3(0, 0.30, 0)
	crown.set_surface_override_material(0, mat_hat)
	head.add_child(crown)

	# Torso (shirt)
	var torso := MeshInstance3D.new()
	var torso_m := CapsuleMesh.new()
	torso_m.radius = 0.28; torso_m.height = 0.62
	torso_m.radial_segments = 16
	torso.mesh = torso_m
	torso.position = Vector3(0, 0.18, 0)
	torso.set_surface_override_material(0, mat_shirt)
	body.add_child(torso)

	# Overalls (lower torso)
	var overalls := MeshInstance3D.new()
	var ov_m := CapsuleMesh.new()
	ov_m.radius = 0.29; ov_m.height = 0.44
	ov_m.radial_segments = 16
	overalls.mesh = ov_m
	overalls.position = Vector3(0, 0.02, 0)
	overalls.set_surface_override_material(0, mat_overalls)
	body.add_child(overalls)

	# Suspenders
	for sx in [-0.10, 0.10]:
		var strap := MeshInstance3D.new()
		var strap_m := BoxMesh.new()
		strap_m.size = Vector3(0.05, 0.50, 0.03)
		strap.mesh = strap_m
		strap.position = Vector3(sx, 0.18, 0.12)
		strap.set_surface_override_material(0, mat_overalls)
		body.add_child(strap)

	# Arms
	left_arm = _build_arm(mat_shirt, mat_skin, -0.34)
	right_arm = _build_arm(mat_shirt, mat_skin, 0.34)

	# Tool mount on right hand
	_tool_mount = Node3D.new()
	_tool_mount.name = "ToolMount"
	_tool_mount.position = Vector3(0.0, -0.04, 0.16)
	var right_hand: MeshInstance3D = right_arm.get_node("Hand")
	if right_hand:
		right_hand.add_child(_tool_mount)
	else:
		right_arm.add_child(_tool_mount)

	# Legs
	left_leg = _build_leg(mat_overalls, mat_boot, -0.14)
	right_leg = _build_leg(mat_overalls, mat_boot, 0.14)

func _build_arm(mat_sleeve: StandardMaterial3D, mat_skin: StandardMaterial3D, x: float) -> MeshInstance3D:
	var arm := MeshInstance3D.new()
	arm.name = "RightArm" if x > 0 else "LeftArm"
	var arm_m := CapsuleMesh.new()
	arm_m.radius = 0.09; arm_m.height = 0.36
	arm.mesh = arm_m
	arm.position = Vector3(x, 0.20, 0)
	arm.set_surface_override_material(0, mat_sleeve)
	body.add_child(arm)

	var hand := MeshInstance3D.new()
	hand.name = "Hand"
	var hand_m := SphereMesh.new()
	hand_m.radius = 0.07; hand_m.height = 0.10
	hand_m.radial_segments = 10
	hand.mesh = hand_m
	hand.position = Vector3(0, -0.20, 0)
	hand.set_surface_override_material(0, mat_skin)
	arm.add_child(hand)

	return arm

func _build_leg(mat_pants: StandardMaterial3D, mat_boot: StandardMaterial3D, x: float) -> MeshInstance3D:
	var leg := MeshInstance3D.new()
	leg.name = "RightLeg" if x > 0 else "LeftLeg"
	var leg_m := CapsuleMesh.new()
	leg_m.radius = 0.11; leg_m.height = 0.40
	leg.mesh = leg_m
	leg.position = Vector3(x, -0.42, 0)
	leg.set_surface_override_material(0, mat_pants)
	body.add_child(leg)

	var boot := MeshInstance3D.new()
	var boot_m := CapsuleMesh.new()
	boot_m.radius = 0.12; boot_m.height = 0.18
	boot.mesh = boot_m
	boot.position = Vector3(0, -0.24, 0.02)
	boot.set_surface_override_material(0, mat_boot)
	leg.add_child(boot)

	return leg

func _build_selection_ring() -> void:
	_selection_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 0.52
	ring.rings = 16
	ring.ring_segments = 16
	_selection_ring.mesh = ring
	_selection_ring.position = Vector3(0, 0.05, 0)
	_selection_ring.rotation.x = 0  # flat on ground
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 1.0, 0.2, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_ring.set_surface_override_material(0, mat)
	_selection_ring.visible = false
	add_child(_selection_ring)

# ─── Selection ────────────────────────────────────────────────────────────────

func set_selected(val: bool) -> void:
	is_selected = val
	_selection_ring.visible = val

# ─── Tool equip ───────────────────────────────────────────────────────────────

func equip_tool(tool_id: String) -> void:
	_current_tool = tool_id
	if _active_tool:
		_active_tool.queue_free()
		_active_tool = null
	_active_tool = ToolMeshesClass.create(tool_id)
	_tool_mount.add_child(_active_tool)

# ─── Commands ─────────────────────────────────────────────────────────────────

func command_move(pos: Vector3) -> void:
	assigned_zone = null
	target_pos = pos
	state = State.MOVING

func command_mine(zone) -> void:
	assigned_zone = zone
	target_pos = zone.global_position
	var tool_id: String = zone.get_tool_id() if zone.has_method("get_tool_id") else "pan"
	equip_tool(tool_id)
	_current_tool = tool_id
	state = State.MOVING

func command_chop(zone) -> void:
	assigned_zone = zone
	target_pos = zone.global_position
	equip_tool("axe")
	_current_tool = "axe"
	state = State.MOVING

func command_stop() -> void:
	assigned_zone = null
	state = State.IDLE

# ─── Physics / AI ─────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	match state:
		State.IDLE:
			_do_idle(delta)
		State.MOVING:
			_do_moving(delta)
		State.MINING:
			_do_mining(delta)
		State.CHOPPING:
			_do_chopping(delta)
		State.RETURNING:
			_do_returning(delta)

	move_and_slide()
	_animate(delta)

func _do_idle(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, SPEED * 2)
	velocity.z = move_toward(velocity.z, 0, SPEED * 2)

func _do_moving(delta: float) -> void:
	var to_target := target_pos - global_position
	to_target.y = 0
	var dist := to_target.length()

	if dist < ARRIVAL_DIST:
		velocity.x = 0
		velocity.z = 0
		_on_arrived()
		return

	var dir := to_target.normalized()
	velocity.x = dir.x * SPEED
	velocity.z = dir.z * SPEED
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 0.15)

func _on_arrived() -> void:
	if assigned_zone == null:
		state = State.IDLE
		return

	# Check if this is a return trip to camp
	if state == State.RETURNING:
		_deposit_resources()
		return

	# Check zone type
	if assigned_zone.is_in_group("mining_zones"):
		state = State.MINING
		action_cycle = 0.0
		_start_mine_action()
	elif assigned_zone.is_in_group("timber_zones"):
		state = State.CHOPPING
		action_cycle = 0.0
		_start_chop_action()
	else:
		state = State.IDLE

func _start_mine_action() -> void:
	var tool_id: String = assigned_zone.get_tool_id() if assigned_zone.has_method("get_tool_id") else "pan"
	var action_time := ToolSystem.get_action_time(tool_id)

	# Face the zone center
	var dir := (assigned_zone.global_position - global_position).normalized()
	if dir.length() > 0.01:
		rotation.y = atan2(dir.x, dir.z)

	await get_tree().create_timer(action_time).timeout

	if state != State.MINING:
		return  # interrupted

	var quality: float = assigned_zone.quality if "quality" in assigned_zone else 1.0
	var result: Dictionary = ToolSystem.calculate_yield(tool_id, quality)
	carried_gold += result.amount
	work_completed.emit(self, "gold", result.amount)

	if carried_gold >= CARRY_CAPACITY:
		_begin_return_trip()
	else:
		# Keep mining
		_start_mine_action()

func _start_chop_action() -> void:
	await get_tree().create_timer(3.0).timeout

	if state != State.CHOPPING:
		return

	carried_timber += 1
	work_completed.emit(self, "timber", 1.0)

	if carried_timber >= 3:
		_begin_return_trip()
	else:
		_start_chop_action()

func _begin_return_trip() -> void:
	target_pos = home_pos
	state = State.RETURNING

func _do_mining(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

func _do_chopping(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

func _do_returning(delta: float) -> void:
	_do_moving(delta)

func _deposit_resources() -> void:
	if carried_gold > 0:
		SaveManager.add_gold(carried_gold)
		carried_gold = 0.0
	if carried_timber > 0:
		SaveManager.add_timber(carried_timber)
		carried_timber = 0

	# Go back to assigned zone to keep working
	if assigned_zone and is_instance_valid(assigned_zone):
		target_pos = assigned_zone.global_position
		state = State.MOVING
	else:
		state = State.IDLE

# ─── Animation ────────────────────────────────────────────────────────────────

func _animate(delta: float) -> void:
	var speed_xz := Vector2(velocity.x, velocity.z).length()
	var working := state == State.MINING or state == State.CHOPPING
	action_blend = lerp(action_blend, 1.0 if working else 0.0, delta * 6.0)

	if action_blend > 0.01:
		action_cycle += delta
		if state == State.CHOPPING:
			_anim_axe_chop(delta)
		else:
			match _current_tool:
				"pan", "pan_upgraded":
					_anim_pan(delta)
				"pickaxe":
					_anim_pickaxe(delta)
				"shovel":
					_anim_shovel(delta)
				_:
					_anim_pan(delta)
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
		body.rotation.x = 0.0
		body.position.y = abs(sin(walk_cycle * 2.0)) * 0.03
	else:
		left_arm.rotation.x  = lerp(left_arm.rotation.x,  0.0, delta * 10.0)
		right_arm.rotation.x = lerp(right_arm.rotation.x, 0.0, delta * 10.0)
		left_leg.rotation.x  = lerp(left_leg.rotation.x,  0.0, delta * 10.0)
		right_leg.rotation.x = lerp(right_leg.rotation.x, 0.0, delta * 10.0)
		body.rotation.x = lerp(body.rotation.x, 0.0, delta * 10.0)
		body.position.y = lerp(body.position.y, 0.0, delta * 10.0)

func _anim_pan(delta: float) -> void:
	var b := action_blend
	var swirl := sin(action_cycle * 5.0) * 0.4
	body.rotation.x      = lerp(body.rotation.x,      b * 0.55, delta * 8.0)
	body.position.y      = lerp(body.position.y,      b * -0.20, delta * 8.0)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  b * 1.2 + swirl * 0.2, delta * 8.0)
	right_arm.rotation.x = lerp(right_arm.rotation.x, b * 1.2 + swirl * 0.2, delta * 8.0)
	left_leg.rotation.x  = lerp(left_leg.rotation.x,  b * -0.3, delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, b * -0.2, delta * 8.0)

func _anim_pickaxe(delta: float) -> void:
	var b := action_blend
	var t := fmod(action_cycle * 2.5, 1.0)
	var r_rot: float; var l_rot: float; var b_lean: float; var b_dip: float

	if t < 0.4:
		var w := t / 0.4
		r_rot = b * (-1.8 * w); l_rot = b * (-1.5 * w)
		b_lean = b * (-0.15 * w); b_dip = 0.0
	elif t < 0.6:
		var s := (t - 0.4) / 0.2
		r_rot = b * (-1.8 + 3.0 * s); l_rot = b * (-1.5 + 2.6 * s)
		b_lean = b * (-0.15 + 0.55 * s); b_dip = b * -0.08 * s
	else:
		var e := (t - 0.6) / 0.4
		r_rot = b * (1.2 - 1.2 * e); l_rot = b * (1.1 - 1.1 * e)
		b_lean = b * (0.4 - 0.4 * e); b_dip = b * -0.08 * (1.0 - e)

	right_arm.rotation.x = lerp(right_arm.rotation.x, r_rot, delta * 12.0)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  l_rot, delta * 12.0)
	body.rotation.x      = lerp(body.rotation.x,      b_lean, delta * 10.0)
	body.position.y      = lerp(body.position.y,      b_dip,  delta * 10.0)
	left_leg.rotation.x  = lerp(left_leg.rotation.x,  b * -0.15, delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, b * 0.1,   delta * 8.0)

func _anim_shovel(delta: float) -> void:
	var b := action_blend
	var t := fmod(action_cycle * 2.0, 1.0)
	var r_rot: float; var l_rot: float; var b_lean: float; var b_dip: float

	if t < 0.35:
		var p := t / 0.35
		r_rot = b * (0.8 + 0.5 * p); l_rot = b * (0.6 + 0.4 * p)
		b_lean = b * (0.35 + 0.2 * p); b_dip = b * -0.12 * p
	elif t < 0.65:
		var l := (t - 0.35) / 0.3
		r_rot = b * (1.3 - 1.8 * l); l_rot = b * (1.0 - 1.4 * l)
		b_lean = b * (0.55 - 0.55 * l); b_dip = b * (-0.12 + 0.12 * l)
	else:
		var ts := (t - 0.65) / 0.35
		r_rot = b * (-0.5 + 0.5 * ts); l_rot = b * (-0.4 + 0.4 * ts)
		b_lean = b * (0.1 * (1.0 - ts)); b_dip = 0.0

	right_arm.rotation.x = lerp(right_arm.rotation.x, r_rot, delta * 10.0)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  l_rot, delta * 10.0)
	body.rotation.x      = lerp(body.rotation.x,      b_lean, delta * 10.0)
	body.position.y      = lerp(body.position.y,      b_dip,  delta * 10.0)
	left_leg.rotation.x  = lerp(left_leg.rotation.x,  b * -0.25, delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, b * 0.15,  delta * 8.0)

func _anim_axe_chop(delta: float) -> void:
	var b := action_blend
	var t := fmod(action_cycle * 3.0, 1.0)
	var r_rot: float; var l_rot: float; var twist: float; var b_lean: float

	if t < 0.3:
		var w := t / 0.3
		r_rot = b * (-1.4 * w); l_rot = b * (-0.8 * w)
		twist = b * (-0.25 * w); b_lean = b * (-0.1 * w)
	elif t < 0.5:
		var c := (t - 0.3) / 0.2
		r_rot = b * (-1.4 + 2.4 * c); l_rot = b * (-0.8 + 1.6 * c)
		twist = b * (-0.25 + 0.45 * c); b_lean = b * (-0.1 + 0.4 * c)
	else:
		var e := (t - 0.5) / 0.5
		r_rot = b * (1.0 - 1.0 * e); l_rot = b * (0.8 - 0.8 * e)
		twist = b * (0.2 - 0.2 * e); b_lean = b * (0.3 - 0.3 * e)

	right_arm.rotation.x = lerp(right_arm.rotation.x, r_rot, delta * 14.0)
	left_arm.rotation.x  = lerp(left_arm.rotation.x,  l_rot, delta * 14.0)
	body.rotation.x      = lerp(body.rotation.x,      b_lean, delta * 10.0)
	body.position.y      = lerp(body.position.y,      0.0,    delta * 8.0)
	left_leg.rotation.x  = lerp(left_leg.rotation.x,  b * 0.15, delta * 8.0)
	right_leg.rotation.x = lerp(right_leg.rotation.x, b * -0.1, delta * 8.0)

# ─── State display ────────────────────────────────────────────────────────────

func get_state_text() -> String:
	match state:
		State.IDLE:      return "Idle"
		State.MOVING:    return "Moving"
		State.MINING:    return "Mining"
		State.CHOPPING:  return "Chopping"
		State.RETURNING: return "Returning (%.1fg)" % carried_gold
		_:               return "Unknown"
