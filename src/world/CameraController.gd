extends Node3D

var yaw: float   = 0.0
var pitch: float = -0.08
var target: Node3D = null

const MOUSE_SENSITIVITY = 0.003
const PITCH_MIN    = -1.0
const PITCH_MAX    = 0.4
const CAM_DISTANCE = 7.0
const CAM_MIN_DIST = 1.5
const CAM_HEIGHT   = 1.2

var shake_intensity: float = 0.0
var shake_timer: float     = 0.0

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw   -= event.relative.x * MOUSE_SENSITIVITY
		pitch -= event.relative.y * MOUSE_SENSITIVITY
		pitch  = clamp(pitch, PITCH_MIN, PITCH_MAX)
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not target:
		return

	global_position = target.global_position + Vector3(0, CAM_HEIGHT, 0)
	rotation.y = yaw
	rotation.x = pitch

	# Spring arm — pull camera in if something's in the way
	_update_spring_arm()

	# Screen shake
	if shake_timer > 0.0:
		shake_timer -= delta
		var offset := Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			0.0
		)
		camera.position += offset
	else:
		camera.position.x = lerp(camera.position.x, 0.0, delta * 20.0)
		camera.position.y = lerp(camera.position.y, 0.0, delta * 20.0)
		camera.position.z = lerp(camera.position.z, CAM_DISTANCE, delta * 10.0)

func _update_spring_arm() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var from  := global_position
	var to    := global_position + global_transform.basis * Vector3(0, 0, CAM_DISTANCE)
	var params := PhysicsRayQueryParameters3D.create(from, to)
	var player_nodes: Array = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var rid := (player_nodes[0] as CollisionObject3D).get_rid()
		params.exclude = [rid]
	var result := space.intersect_ray(params)
	if result:
		var dist: float = from.distance_to(result.position) - 0.3
		camera.position.z = max(CAM_MIN_DIST, dist)
	else:
		camera.position.z = lerp(camera.position.z, CAM_DISTANCE, 0.15)

func shake(intensity: float = 0.25, duration: float = 0.35) -> void:
	shake_intensity = intensity
	shake_timer     = duration
