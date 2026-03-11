extends CanvasLayer

signal closed

const ITEMS := [
	{ "id": "shovel",     "label": "⛏  Shovel",      "desc": "Fast, low yield. Works loose earth.",   "cost": 15  },
	{ "id": "pickaxe",   "label": "⛏  Pickaxe",     "desc": "Medium yield. Works rock faces.",        "cost": 20  },
	{ "id": "better_pan","label": "🪣  Better Pan",  "desc": "Upgraded pan. 1.5× river yield.",        "cost": 30  },
	{ "id": "sluice_box","label": "🏗  Sluice Box",  "desc": "High yield river tool.",                 "cost": 50  },
	{ "id": "cabin_kit", "label": "🏠  Cabin Kit",   "desc": "Upgrade tent to cabin. Requires 5 timber.", "cost": 100, "timber_cost": 5 },
]

var _panel: Panel
var _gold_label: Label
var _rows: Array = []

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	# Dim background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main panel
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.size = Vector2(520, 420)
	_panel.position = Vector2(-260, -210)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.position = Vector2(20, 16)
	vbox.size = Vector2(480, 388)
	_panel.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var title := Label.new()
	title.text = "🏪  General Store"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	_gold_label = Label.new()
	_gold_label.text = "Gold: 0.00g"
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_gold_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Item rows
	for item in ITEMS:
		var row := _build_item_row(item)
		vbox.add_child(row)
		_rows.append({ "item": item, "row": row })

	# Close hint
	var hint := Label.new()
	hint.text = "ESC to close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.6
	vbox.add_child(hint)

func _build_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = item.label
	name_label.add_theme_font_size_override("font_size", 17)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.desc
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.modulate.a = 0.7
	info.add_child(desc_label)

	row.add_child(info)

	var cost_label := Label.new()
	var cost_text := "%dg" % item.cost
	if int(item.get("timber_cost", 0)) > 0:
		cost_text += " +%dt" % int(item.get("timber_cost", 0))
	cost_label.text = cost_text
	cost_label.add_theme_font_size_override("font_size", 17)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.custom_minimum_size = Vector2(80, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost_label)

	var btn := Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(70, 36)
	btn.pressed.connect(_on_buy.bind(item, btn, cost_label))
	row.add_child(btn)

	return row

func open() -> void:
	_refresh()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func _refresh() -> void:
	_gold_label.text = "Gold: %.2fg  |  Timber: %d" % [SaveManager.get_gold(), SaveManager.get_timber()]
	for entry in _rows:
		var item: Dictionary = entry.item
		var row: HBoxContainer = entry.row
		var btn: Button = row.get_child(row.get_child_count() - 1)
		var owned: bool = SaveManager.has_tool(str(item.get("id", ""))) or (str(item.get("id","")) == "better_pan" and SaveManager.has_tool("pan_upgraded"))
		if owned:
			btn.text     = "Owned"
			btn.disabled = true
		elif SaveManager.get_gold() < item.cost:
			btn.disabled = true
			btn.text     = "Buy"
		elif int(item.get("timber_cost", 0)) > 0 and SaveManager.get_timber() < int(item.get("timber_cost", 0)):
			btn.disabled = true
			btn.text     = "Buy"
		else:
			btn.disabled = false
			btn.text     = "Buy"

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
	if iid == "better_pan":
		SaveManager.unlock_tool("pan_upgraded")
	else:
		SaveManager.unlock_tool(iid)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
