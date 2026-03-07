extends CharacterBody3D

const SPEED = 5.0
const GRAVITY = 9.8

var gold_dust: float = 0.0
var is_panning: bool = false
var can_pan: bool = false
var pan_zone = null

signal gold_updated(amount: float)
signal pan_started
signal pan_finished(found: float)

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# WASD movement (relative to world, not camera)
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = Vector3(input_dir.x, 0, input_dir.y).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		var target_angle = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.12)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Pan
	if event.is_action_pressed("ui_accept") and can_pan and not is_panning:
		_start_panning()
	# Screenshot (F12)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		_save_screenshot()

func _start_panning() -> void:
	is_panning = true
	pan_started.emit()
	await get_tree().create_timer(2.0).timeout
	var found = _calculate_yield()
	gold_dust += found
	pan_finished.emit(found)
	gold_updated.emit(gold_dust)
	is_panning = false

func _calculate_yield() -> float:
	var base = randf_range(0.3, 2.5)
	if randf() > 0.95:
		base *= 5.0  # Lucky strike!
	return base

func enter_pan_zone(zone) -> void:
	can_pan = true
	pan_zone = zone

func exit_pan_zone() -> void:
	can_pan = false
	pan_zone = null

func _save_screenshot() -> void:
	var img = get_viewport().get_texture().get_image()
	var path = "user://screenshot.png"
	img.save_png(path)
	print("Screenshot saved to: " + OS.get_user_data_dir() + "/screenshot.png")
