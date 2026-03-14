extends CanvasLayer

signal closed

const ITEMS := [
	{ "id": "axe",        "label": "Axe",          "desc": "Chop trees for timber.",                      "cost": 10  },
	{ "id": "shovel",     "label": "Shovel",        "desc": "Fast, low yield. Works loose earth.",        "cost": 15  },
	{ "id": "pickaxe",    "label": "Pickaxe",       "desc": "Medium yield. Works rock faces.",            "cost": 20  },
	{ "id": "better_pan", "label": "Better Pan",    "desc": "Upgraded pan. 1.5x river yield.",            "cost": 30  },
	{ "id": "sluice_box", "label": "Sluice Box",    "desc": "High yield river tool.",                     "cost": 50  },
	{ "id": "cabin_kit",  "label": "Cabin Kit",     "desc": "Upgrade tent to cabin. Requires 5 timber.",  "cost": 100, "timber_cost": 5 },
]

# Warm color palette
const COL_BG       := Color(0.12, 0.08, 0.05, 1.0)   # dark wood
const COL_PANEL    := Color(0.18, 0.13, 0.08, 1.0)   # warm brown panel
const COL_HEADER   := Color(0.24, 0.16, 0.09, 1.0)   # header bar
const COL_ROW_EVEN := Color(0.16, 0.11, 0.07, 1.0)   # alternating rows
const COL_ROW_ODD  := Color(0.20, 0.14, 0.09, 1.0)
const COL_GOLD     := Color(1.0, 0.85, 0.2, 1.0)     # gold accent
const COL_CREAM    := Color(0.92, 0.86, 0.72, 1.0)    # light text
const COL_DIM      := Color(0.65, 0.55, 0.42, 1.0)    # dim text
const COL_ACCENT   := Color(0.72, 0.52, 0.18, 1.0)    # warm accent
const COL_BTN      := Color(0.28, 0.20, 0.10, 1.0)    # button bg
const COL_BTN_HOVER := Color(0.38, 0.28, 0.14, 1.0)

var _gold_label: Label
var _rows: Array = []

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Full dark background
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Outer container — centers everything
	var outer := MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 200)
	outer.add_theme_constant_override("margin_right", 200)
	outer.add_theme_constant_override("margin_top", 80)
	outer.add_theme_constant_override("margin_bottom", 80)
	add_child(outer)

	# Main card panel
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COL_PANEL
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = COL_ACCENT
	card_style.content_margin_left = 0
	card_style.content_margin_right = 0
	card_style.content_margin_top = 0
	card_style.content_margin_bottom = 0
	card.add_theme_stylebox_override("panel", card_style)
	outer.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	# ── Header bar ────────────────────────────────────────────────────────
	var header := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = COL_HEADER
	header_style.corner_radius_top_left = 6
	header_style.corner_radius_top_right = 6
	header_style.content_margin_left = 28
	header_style.content_margin_right = 28
	header_style.content_margin_top = 18
	header_style.content_margin_bottom = 18
	header.add_theme_stylebox_override("panel", header_style)
	vbox.add_child(header)

	var header_row := HBoxContainer.new()
	header.add_child(header_row)

	var title := Label.new()
	title.text = "WILD WEST DEPOT"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", COL_CREAM)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(_gold_label)

	# ── Divider ───────────────────────────────────────────────────────────
	var divider := ColorRect.new()
	divider.color = COL_ACCENT
	divider.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(divider)

	# ── Item rows ─────────────────────────────────────────────────────────
	for i in range(ITEMS.size()):
		var item: Dictionary = ITEMS[i]
		var row_color: Color = COL_ROW_EVEN if i % 2 == 0 else COL_ROW_ODD
		var row := _build_item_row(item, row_color)
		vbox.add_child(row)
		_rows.append({ "item": item, "row": row })

	# ── Footer ────────────────────────────────────────────────────────────
	var footer := PanelContainer.new()
	var footer_style := StyleBoxFlat.new()
	footer_style.bg_color = COL_HEADER
	footer_style.corner_radius_bottom_left = 6
	footer_style.corner_radius_bottom_right = 6
	footer_style.content_margin_left = 28
	footer_style.content_margin_right = 28
	footer_style.content_margin_top = 14
	footer_style.content_margin_bottom = 14
	footer.add_theme_stylebox_override("panel", footer_style)
	vbox.add_child(footer)

	var leave_btn := Button.new()
	leave_btn.text = "Leave Store"
	leave_btn.custom_minimum_size = Vector2(160, 42)
	leave_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var lb_style := StyleBoxFlat.new()
	lb_style.bg_color = COL_BTN
	lb_style.corner_radius_top_left = 4
	lb_style.corner_radius_top_right = 4
	lb_style.corner_radius_bottom_left = 4
	lb_style.corner_radius_bottom_right = 4
	lb_style.border_width_top = 1
	lb_style.border_width_bottom = 1
	lb_style.border_width_left = 1
	lb_style.border_width_right = 1
	lb_style.border_color = COL_ACCENT
	leave_btn.add_theme_stylebox_override("normal", lb_style)

	var lb_hover := StyleBoxFlat.new()
	lb_hover.bg_color = COL_BTN_HOVER
	lb_hover.corner_radius_top_left = 4
	lb_hover.corner_radius_top_right = 4
	lb_hover.corner_radius_bottom_left = 4
	lb_hover.corner_radius_bottom_right = 4
	lb_hover.border_width_top = 1
	lb_hover.border_width_bottom = 1
	lb_hover.border_width_left = 1
	lb_hover.border_width_right = 1
	lb_hover.border_color = COL_GOLD
	leave_btn.add_theme_stylebox_override("hover", lb_hover)

	leave_btn.add_theme_font_size_override("font_size", 16)
	leave_btn.add_theme_color_override("font_color", COL_CREAM)
	leave_btn.pressed.connect(close)
	footer.add_child(leave_btn)

func _build_item_row(item: Dictionary, bg_color: Color) -> PanelContainer:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	container.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	container.add_child(row)

	# Item info
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = item.label
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COL_CREAM)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.desc
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", COL_DIM)
	info.add_child(desc_label)

	row.add_child(info)

	# Cost
	var cost_label := Label.new()
	var cost_text := "%dg" % item.cost
	if int(item.get("timber_cost", 0)) > 0:
		cost_text += "  +%d timber" % int(item.get("timber_cost", 0))
	cost_label.text = cost_text
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", COL_GOLD)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.custom_minimum_size = Vector2(120, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_label)

	# Buy button
	var btn := Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(90, 40)

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = COL_BTN
	btn_normal.corner_radius_top_left = 4
	btn_normal.corner_radius_top_right = 4
	btn_normal.corner_radius_bottom_left = 4
	btn_normal.corner_radius_bottom_right = 4
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_color = COL_ACCENT
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = COL_BTN_HOVER
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4
	btn_hover.border_width_top = 1
	btn_hover.border_width_bottom = 1
	btn_hover.border_width_left = 1
	btn_hover.border_width_right = 1
	btn_hover.border_color = COL_GOLD
	btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.14, 0.10, 0.07, 1.0)
	btn_disabled.corner_radius_top_left = 4
	btn_disabled.corner_radius_top_right = 4
	btn_disabled.corner_radius_bottom_left = 4
	btn_disabled.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("disabled", btn_disabled)

	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", COL_CREAM)
	btn.add_theme_color_override("font_disabled_color", COL_DIM)
	btn.pressed.connect(_on_buy.bind(item, btn, cost_label))
	row.add_child(btn)

	return container

func open() -> void:
	_refresh()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func _refresh() -> void:
	_gold_label.text = "%.1fg gold   |   %d timber" % [SaveManager.get_gold(), SaveManager.get_timber()]
	for entry in _rows:
		var item: Dictionary = entry.item
		var row: PanelContainer = entry.row
		var hbox: HBoxContainer = row.get_child(0)
		var btn: Button = hbox.get_child(hbox.get_child_count() - 1)
		var cost_label: Label = hbox.get_child(hbox.get_child_count() - 2)
		var iid: String = str(item.get("id", ""))
		var owned: bool = SaveManager.has_tool(iid) or (iid == "better_pan" and SaveManager.has_tool("pan_upgraded")) or (iid == "cabin_kit" and (SaveManager.has_cabin_kit() or SaveManager.has_cabin()))
		if owned:
			btn.text     = "Owned"
			btn.disabled = true
			cost_label.add_theme_color_override("font_color", COL_DIM)
		elif SaveManager.get_gold() < item.cost:
			btn.disabled = true
			btn.text     = "Buy"
			cost_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.2))
		elif int(item.get("timber_cost", 0)) > 0 and SaveManager.get_timber() < int(item.get("timber_cost", 0)):
			btn.disabled = true
			btn.text     = "Buy"
			cost_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.2))
		else:
			btn.disabled = false
			btn.text     = "Buy"
			cost_label.add_theme_color_override("font_color", COL_GOLD)

func _on_buy(item: Dictionary, btn: Button, _cost_label: Label) -> void:
	Audio.play("ui_click")
	var timber_cost: int = int(item.get("timber_cost", 0))
	if timber_cost > 0 and SaveManager.get_timber() < timber_cost:
		return
	if not SaveManager.spend_gold(float(item.get("cost", 999))):
		return
	if timber_cost > 0:
		SaveManager.spend_timber(timber_cost)
	var iid: String = str(item.get("id", ""))
	if iid == "cabin_kit":
		SaveManager.give_cabin_kit()
	elif iid == "better_pan":
		SaveManager.unlock_tool("pan_upgraded")
	else:
		SaveManager.unlock_tool(iid)
	# Brief "Purchased!" feedback
	btn.text = "Purchased!"
	btn.disabled = true
	btn.add_theme_color_override("font_disabled_color", COL_GOLD)
	await get_tree().create_timer(1.5).timeout
	btn.remove_theme_color_override("font_disabled_color")
	btn.add_theme_color_override("font_disabled_color", COL_DIM)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
