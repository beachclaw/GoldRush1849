extends CanvasLayer

@onready var gold_val:  Label = $Panel/VBox/GoldRow/Val
@onready var tools_box: VBoxContainer = $Panel/VBox/ToolsBox

const ALL_TOOLS := ["pan", "pickaxe", "shovel"]

func _ready() -> void:
	visible = false
	SaveManager.gold_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		visible = not visible
		if visible:
			_refresh(SaveManager.get_gold())
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

func _refresh(_v: float = 0.0) -> void:
	if not visible:
		return
	gold_val.text = "%.2fg" % SaveManager.get_gold()
	# Clear and rebuild tools list
	for child in tools_box.get_children():
		child.queue_free()
	for tool_id in ALL_TOOLS:
		var row := HBoxContainer.new()
		var icon := Label.new()
		var tdata: Dictionary = ToolSystem.TOOLS.get(tool_id, {})
		icon.text = str(tdata.get("icon", "")) + "  " + str(tdata.get("name", tool_id))
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon.add_theme_font_size_override("font_size", 15)
		row.add_child(icon)
		var status := Label.new()
		if SaveManager.has_tool(tool_id):
			status.text = "✓ Owned"
			status.modulate = Color(0.4, 0.9, 0.4)
		else:
			var cost: float = ToolSystem.get_unlock_cost(tool_id)
			status.text = "%dg" % int(cost)
			status.modulate = Color(0.7, 0.7, 0.7)
		status.add_theme_font_size_override("font_size", 15)
		row.add_child(status)
		tools_box.add_child(row)
