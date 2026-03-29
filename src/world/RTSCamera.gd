extends Node3D

# Top-down RTS camera with pan, zoom, rotate, and edge scrolling.

const PAN_SPEED       := 25.0
const EDGE_MARGIN     := 20     # pixels from edge to trigger scroll
const EDGE_SPEED      := 18.0
const ZOOM_SPEED      := 2.0
const ZOOM_MIN        := 8.0
const ZOOM_MAX        := 45.0
const ROTATE_SPEED    := 0.005
const BOUNDS          := 40.0   # keep camera within world

var _zoom: float       = 20.0
var _yaw: float        = 0.0
var _pitch: float      = -1.1   # ~63 degrees down
var _rotating: bool    = false

# Camera shake
var _shake_timer: float  = 0.0
var _shake_strength: float = 0.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	_update_camera()

func _process(delta: float) -> void:
	_handle_pan(delta)
	_handle_edge_scroll(delta)
	_update_camera()
	_process_shake(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = max(_zoom - ZOOM_SPEED, ZOOM_MIN)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = min(_zoom + ZOOM_SPEED, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = event.pressed

	# Rotate
	if event is InputEventMouseMotion and _rotating:
		_yaw -= event.relative.x * ROTATE_SPEED
		_pitch = clamp(_pitch - event.relative.y * ROTATE_SPEED, -1.4, -0.5)

func _handle_pan(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length() < 0.01:
		return
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right   := Vector3(cos(_yaw), 0, -sin(_yaw))
	var move    := (right * input_dir.x + forward * input_dir.y) * PAN_SPEED * delta
	position += move
	_clamp_position()

func _handle_edge_scroll(delta: float) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var mouse   := get_viewport().get_mouse_position()
	var dir     := Vector2.ZERO
	if mouse.x < EDGE_MARGIN:
		dir.x = -1
	elif mouse.x > vp_size.x - EDGE_MARGIN:
		dir.x = 1
	if mouse.y < EDGE_MARGIN:
		dir.y = -1
	elif mouse.y > vp_size.y - EDGE_MARGIN:
		dir.y = 1
	if dir.length() < 0.01:
		return
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	var right   := Vector3(cos(_yaw), 0, -sin(_yaw))
	var move    := (right * dir.x + forward * dir.y) * EDGE_SPEED * delta
	position += move
	_clamp_position()

func _clamp_position() -> void:
	position.x = clamp(position.x, -BOUNDS, BOUNDS)
	position.z = clamp(position.z, -BOUNDS, BOUNDS)

func _update_camera() -> void:
	var offset := Vector3(0, 0, _zoom)
	offset = offset.rotated(Vector3.RIGHT, _pitch)
	offset = offset.rotated(Vector3.UP, _yaw)
	camera.position = offset
	camera.look_at(position, Vector3.UP)

# ─── Camera shake (reused from original) ────────────────────────────────────

func shake(duration: float = 0.3, strength: float = 0.3) -> void:
	_shake_timer = duration
	_shake_strength = strength

func _process_shake(delta: float) -> void:
	if _shake_timer > 0:
		_shake_timer -= delta
		var offset := Vector3(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength),
			0
		)
		camera.position += offset
	else:
		_shake_strength = 0.0

# ─── Utility: project screen position to ground plane ───────────────────────

func get_ground_position(screen_pos: Vector2) -> Vector3:
	var from  := camera.project_ray_origin(screen_pos)
	var dir   := camera.project_ray_normal(screen_pos)
	if dir.y >= 0:
		return position  # looking up, return camera position
	var t := -from.y / dir.y
	return from + dir * t
