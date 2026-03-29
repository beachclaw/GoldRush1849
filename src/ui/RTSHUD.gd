extends CanvasLayer

# StarCraft-style RTS HUD: resource bar, unit info panel, command buttons.

var _gold_label: Label
var _timber_label: Label
var _worker_label: Label
var _info_panel: PanelContainer
var _info_label: Label
var _message_label: Label
var _command_panel: HBoxContainer

# Bottom panel
var _bottom_bg: PanelContainer

# Command buttons
var _btn_stop: Button
var _btn_mine: Button
var _btn_chop: Button

var _selected_units: Array = []

func _ready() -> void:
	_build_resource_bar()
	_build_bottom_panel()
	_build_message_label()

	SaveManager.gold_changed.connect(_on_gold_changed)
	SaveManager.timber_changed.connect(_on_timber_changed)
	_on_gold_changed(SaveManager.get_gold())
	_on_timber_changed(SaveManager.get_timber())

# ─── Resource bar (top) ──────────────────────────────────────────────────────

func _build_resource_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 36)
	bar.add_theme_constant_override("separation", 32)

	var bar_bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar_bg.add_theme_stylebox_override("panel", style)
	bar_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_bg.size = Vector2(1920, 36)
	add_child(bar_bg)
	bar_bg.add_child(bar)

	_gold_label = _make_label("Gold: 0.0g", 16)
	bar.add_child(_gold_label)

	_timber_label = _make_label("Timber: 0", 16)
	bar.add_child(_timber_label)

	_worker_label = _make_label("Workers: 0", 16)
	bar.add_child(_worker_label)

# ─── Bottom panel (unit info + commands) ─────────────────────────────────────

func _build_bottom_panel() -> void:
	_bottom_bg = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.88)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_bottom_bg.add_theme_stylebox_override("panel", style)
	_bottom_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_bg.position = Vector2(0, 940)
	_bottom_bg.size = Vector2(1920, 140)
	add_child(_bottom_bg)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	_bottom_bg.add_child(hbox)

	# Unit info section
	_info_panel = PanelContainer.new()
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.12, 0.10, 0.07, 0.7)
	info_style.content_margin_left = 12
	info_style.content_margin_right = 12
	info_style.content_margin_top = 8
	info_style.content_margin_bottom = 8
	info_style.corner_radius_top_left = 4
	info_style.corner_radius_top_right = 4
	info_style.corner_radius_bottom_left = 4
	info_style.corner_radius_bottom_right = 4
	_info_panel.add_theme_stylebox_override("panel", info_style)
	_info_panel.custom_minimum_size = Vector2(320, 100)
	hbox.add_child(_info_panel)

	_info_label = _make_label("Select a worker", 14)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_panel.add_child(_info_label)

	# Command buttons
	_command_panel = HBoxContainer.new()
	_command_panel.add_theme_constant_override("separation", 8)
	hbox.add_child(_command_panel)

	_btn_stop = _make_cmd_button("Stop (S)")
	_btn_mine = _make_cmd_button("Mine (M)")
	_btn_chop = _make_cmd_button("Chop (C)")

	_btn_stop.pressed.connect(_on_stop_pressed)

func _make_cmd_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 50)
	btn.add_theme_font_size_override("font_size", 13)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.14, 0.10, 0.9)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.4, 0.32, 0.20, 0.6)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate()
	hover.bg_color = Color(0.25, 0.20, 0.14, 0.95)
	hover.border_color = Color(0.6, 0.48, 0.25, 0.8)
	btn.add_theme_stylebox_override("hover", hover)

	_command_panel.add_child(btn)
	return btn

# ─── Message label (center screen) ──────────────────────────────────────────

func _build_message_label() -> void:
	_message_label = _make_label("", 20)
	_message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message_label.position = Vector2(-300, 60)
	_message_label.size = Vector2(600, 40)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.visible = false
	add_child(_message_label)

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _make_label(text: String, size: int = 14) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	return lbl

# ─── Updates ─────────────────────────────────────────────────────────────────

func _on_gold_changed(amount: float) -> void:
	_gold_label.text = "Gold: %.1fg" % amount

func _on_timber_changed(amount: int) -> void:
	_timber_label.text = "Timber: %d" % amount

func update_worker_count(current: int, maximum: int) -> void:
	_worker_label.text = "Workers: %d/%d" % [current, maximum]

func update_selection(units: Array) -> void:
	_selected_units = units
	if units.size() == 0:
		_info_label.text = "Select a worker (left-click)\nRight-click to give orders"
	elif units.size() == 1:
		var w = units[0]
		if w.has_method("get_state_text"):
			_info_label.text = "Prospector\nStatus: %s\nGold carried: %.1fg" % [w.get_state_text(), w.carried_gold]
		else:
			_info_label.text = "Unit selected"
	else:
		_info_label.text = "%d Prospectors selected" % units.size()

func show_message(text: String, duration: float = 3.0) -> void:
	_message_label.text = text
	_message_label.visible = true
	await get_tree().create_timer(duration).timeout
	_message_label.visible = false

func _on_stop_pressed() -> void:
	for unit in _selected_units:
		if unit.has_method("command_stop"):
			unit.command_stop()

# ─── Keyboard shortcuts ─────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S and _selected_units.size() > 0:
			_on_stop_pressed()
			get_viewport().set_input_as_handled()

# ─── Per-frame info update ──────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _selected_units.size() == 1:
		var w = _selected_units[0]
		if is_instance_valid(w) and w.has_method("get_state_text"):
			_info_label.text = "Prospector\nStatus: %s\nGold carried: %.1fg" % [w.get_state_text(), w.carried_gold]
