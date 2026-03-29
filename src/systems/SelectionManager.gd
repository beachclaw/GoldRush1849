extends Node

# RTS selection system — click select, box select, right-click command.

signal selection_changed(units: Array)
signal command_issued(target_position: Vector3, target_node: Node3D)
signal build_command(building_id: String)

var selected_units: Array = []
var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_rect: ColorRect = null
var _camera: Node3D = null  # RTSCamera reference

func set_camera(cam: Node3D) -> void:
	_camera = cam

func _ready() -> void:
	# Drag rectangle overlay
	_drag_rect = ColorRect.new()
	_drag_rect.color = Color(0.2, 0.8, 0.2, 0.15)
	_drag_rect.visible = false
	_drag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Will be added to a CanvasLayer by RTSGame

func get_drag_rect() -> ColorRect:
	return _drag_rect

func _unhandled_input(event: InputEvent) -> void:
	if not _camera:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_is_dragging = false
			else:
				if _is_dragging:
					_box_select(event.position)
					_is_dragging = false
					_drag_rect.visible = false
				else:
					_click_select(event.position, event.shift_pressed)

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if selected_units.size() > 0:
				_issue_command(event.position)

	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _drag_start.distance_to(event.position) > 8:
			_is_dragging = true
			_update_drag_rect(event.position)

func _click_select(screen_pos: Vector2, add: bool) -> void:
	var world_pos: Vector3 = _camera.get_ground_position(screen_pos)
	var closest: Node3D = null
	var closest_dist: float = 2.0  # max click distance

	for worker in get_tree().get_nodes_in_group("workers"):
		var worker_screen: Vector2 = _camera.camera.unproject_position(worker.global_position)
		var dist := screen_pos.distance_to(worker_screen)
		if dist < 40 and dist < closest_dist:  # 40px click radius
			closest = worker
			closest_dist = dist

	if closest:
		if add:
			if closest in selected_units:
				_deselect(closest)
			else:
				_add_select(closest)
		else:
			clear_selection()
			_add_select(closest)
	elif not add:
		clear_selection()

func _box_select(end_pos: Vector2) -> void:
	clear_selection()
	var rect := Rect2(_drag_start, end_pos - _drag_start).abs()
	for worker in get_tree().get_nodes_in_group("workers"):
		var sp: Vector2 = _camera.camera.unproject_position(worker.global_position)
		if rect.has_point(sp):
			_add_select(worker)

func _issue_command(screen_pos: Vector2) -> void:
	var world_pos: Vector3 = _camera.get_ground_position(screen_pos)

	# Check if clicking on a mining/timber zone
	var target_node: Node3D = null
	for zone in get_tree().get_nodes_in_group("mining_zones"):
		var zone_pos: Vector3 = zone.global_position
		if Vector2(world_pos.x - zone_pos.x, world_pos.z - zone_pos.z).length() < 5.0:
			target_node = zone
			break

	if not target_node:
		for zone in get_tree().get_nodes_in_group("timber_zones"):
			var zone_pos: Vector3 = zone.global_position
			if Vector2(world_pos.x - zone_pos.x, world_pos.z - zone_pos.z).length() < 4.0:
				target_node = zone
				break

	command_issued.emit(world_pos, target_node)

func _add_select(unit: Node3D) -> void:
	if unit not in selected_units:
		selected_units.append(unit)
		if unit.has_method("set_selected"):
			unit.set_selected(true)
	selection_changed.emit(selected_units)

func _deselect(unit: Node3D) -> void:
	selected_units.erase(unit)
	if unit.has_method("set_selected"):
		unit.set_selected(false)
	selection_changed.emit(selected_units)

func clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit) and unit.has_method("set_selected"):
			unit.set_selected(false)
	selected_units.clear()
	selection_changed.emit(selected_units)

func _update_drag_rect(current: Vector2) -> void:
	_drag_rect.visible = true
	var rect := Rect2(_drag_start, current - _drag_start).abs()
	_drag_rect.position = rect.position
	_drag_rect.size = rect.size
