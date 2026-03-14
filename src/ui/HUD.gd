extends CanvasLayer

signal tool_selected(tool_id: String)

@onready var gold_label:    Label       = $GoldLabel
@onready var timber_label:  Label       = $TimberLabel
@onready var tool_label:    Label       = $ToolLabel
@onready var prompt_label:  Label       = $PromptLabel
@onready var pan_bar:       ProgressBar = $PanBar
@onready var message_label: Label       = $MessageLabel
@onready var notify_label:  Label       = $NotifyLabel

# Hotbar — tool slots at bottom of screen
const HOTBAR_TOOLS := ["pan", "axe", "shovel", "pickaxe", "sluice_box"]
const HOTBAR_KEYS  := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
var _hotbar_container: HBoxContainer
var _hotbar_slots: Array = []  # array of PanelContainer
var _active_tool: String = "pan"

func _ready() -> void:
	pan_bar.visible       = false
	message_label.visible = false
	notify_label.visible  = false
	set_prompt("")
	# Add dark outline to HUD labels for visibility against sky/clouds
	for lbl: Label in [gold_label, timber_label, tool_label, prompt_label, message_label, notify_label]:
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	# Hook into SaveManager
	SaveManager.gold_changed.connect(_on_gold_changed)
	SaveManager.timber_changed.connect(_on_timber_changed)
	SaveManager.tool_unlocked.connect(_on_tool_unlocked)
	_on_gold_changed(SaveManager.get_gold())
	_on_timber_changed(SaveManager.get_timber())
	_build_hotbar()
	_refresh_hotbar()

func _on_gold_changed(amount: float) -> void:
	gold_label.text = "⚙  %.2fg" % amount

func _on_timber_changed(amount: int) -> void:
	timber_label.text = "🪵  %d timber" % amount

func _on_tool_unlocked(tool_id: String) -> void:
	if tool_id.ends_with("_available"):
		var tid: String   = tool_id.replace("_available", "")
		var tname: String = str(ToolSystem.TOOLS.get(tid, {}).get("name", tid))
		show_notify("🔓 %s now available at the store!" % tname)
	else:
		var tname: String = str(ToolSystem.TOOLS.get(tool_id, {}).get("name", tool_id))
		show_notify("✅ %s purchased!" % tname)
		_refresh_hotbar()

func set_tool(tool_id: String) -> void:
	tool_label.text = ToolSystem.get_display(tool_id)

func set_prompt(text: String) -> void:
	prompt_label.text    = text
	prompt_label.visible = text != ""

func show_mining(tool_id: String, action_time: float) -> void:
	pan_bar.visible = true
	pan_bar.value   = 0
	var tween := create_tween()
	tween.tween_property(pan_bar, "value", 100.0, action_time)

func hide_mining() -> void:
	pan_bar.visible = false

func show_message(text: String, duration: float = 3.0) -> void:
	message_label.text    = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	message_label.visible = false

func show_notify(text: String, duration: float = 4.0) -> void:
	notify_label.text    = text
	notify_label.visible = true
	await get_tree().create_timer(duration).timeout
	notify_label.visible = false

# ─── Hotbar ───────────────────────────────────────────────────────────────────

func _build_hotbar() -> void:
	_hotbar_container = HBoxContainer.new()
	_hotbar_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar_container.position = Vector2(-200, -110)
	_hotbar_container.add_theme_constant_override("separation", 6)
	add_child(_hotbar_container)

	for i in range(HOTBAR_TOOLS.size()):
		var tid: String = HOTBAR_TOOLS[i]
		var tool_data: Dictionary = ToolSystem.TOOLS.get(tid, {})

		var slot := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.08, 0.05, 0.85)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_color = Color(0.3, 0.22, 0.12, 0.6)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		slot.add_theme_stylebox_override("panel", style)
		slot.custom_minimum_size = Vector2(72, 48)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 1)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(vbox)

		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.add_theme_font_size_override("font_size", 11)
		key_label.add_theme_color_override("font_color", Color(0.55, 0.45, 0.3, 0.7))
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(key_label)

		var name_label := Label.new()
		name_label.text = str(tool_data.get("name", tid))
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)

		_hotbar_container.add_child(slot)
		_hotbar_slots.append(slot)

func _refresh_hotbar() -> void:
	var visible_index: int = 0
	for i in range(HOTBAR_TOOLS.size()):
		var tid: String = HOTBAR_TOOLS[i]
		var slot: PanelContainer = _hotbar_slots[i]
		var owned: bool = SaveManager.has_tool(tid) or tid == "pan"
		var active: bool = tid == _active_tool

		# Only show owned tools
		slot.visible = owned
		if not owned:
			continue

		visible_index += 1
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
		if active:
			style.bg_color = Color(0.22, 0.16, 0.08, 0.95)
			style.border_color = Color(1.0, 0.85, 0.2, 0.9)
		else:
			style.bg_color = Color(0.12, 0.08, 0.05, 0.85)
			style.border_color = Color(0.3, 0.22, 0.12, 0.6)
		slot.add_theme_stylebox_override("panel", style)

		var vbox: VBoxContainer = slot.get_child(0)
		var key_label: Label = vbox.get_child(0)
		key_label.text = str(visible_index)
		var name_label: Label = vbox.get_child(1)
		if active:
			name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			name_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))

func select_tool(tool_id: String) -> void:
	if not SaveManager.has_tool(tool_id) and tool_id != "pan":
		return
	_active_tool = tool_id
	set_tool(tool_id)
	_refresh_hotbar()
	tool_selected.emit(tool_id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Build list of owned tools to map key presses to visible slots
		var owned_tools: Array[String] = []
		for tid in HOTBAR_TOOLS:
			if SaveManager.has_tool(tid) or tid == "pan":
				owned_tools.append(tid)
		for i in range(HOTBAR_KEYS.size()):
			if event.keycode == HOTBAR_KEYS[i]:
				if i < owned_tools.size():
					select_tool(owned_tools[i])
				get_viewport().set_input_as_handled()
				return
