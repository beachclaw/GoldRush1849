extends Node3D

const DEMO_END_GOLD := 500.0
const CABIN_GOLD    := 100.0

@onready var player:      CharacterBody3D = $Player
@onready var hud:         CanvasLayer     = $HUD
@onready var store_ui:    CanvasLayer     = $Store
@onready var pause_menu:  CanvasLayer     = $PauseMenu
@onready var inventory:   CanvasLayer     = $Inventory
@onready var demo_end:    CanvasLayer     = $DemoEnd
@onready var cam_pivot:   Node3D          = $CameraPivot

# Zones
@onready var pan_zone:     Area3D = $World/River/PanZone
@onready var rich_zone:    Area3D = $World/River/RichZone
@onready var shallow_zone: Area3D = $World/River/ShallowZone
@onready var rock_zone:    Area3D = $World/RockZone
@onready var earth_zone:   Area3D = $World/EarthZone
@onready var store_zone:   Area3D = $World/StoreZone

var _near_store: bool     = false
var _demo_ended: bool     = false
var _cabin_built: bool    = false

func _ready() -> void:
	cam_pivot.target    = player
	player.camera_pivot = cam_pivot

	# Wire zones
	for zone in [pan_zone, rich_zone, shallow_zone, rock_zone, earth_zone]:
		zone.player_entered.connect(_on_zone_entered)
		zone.player_exited.connect(_on_zone_exited)
	store_zone.player_entered.connect(_on_store_entered)
	store_zone.player_exited.connect(_on_store_exited)

	# Wire UI
	store_ui.closed.connect(_on_store_closed)
	pause_menu.get_node("Panel/VBox/ResumeBtn").pressed.connect(pause_menu._on_resume_pressed)
	pause_menu.get_node("Panel/VBox/SaveBtn").pressed.connect(pause_menu._on_save_pressed)
	pause_menu.get_node("Panel/VBox/QuitBtn").pressed.connect(pause_menu._on_quit_pressed)
	demo_end.get_node("Panel/VBox/ContinueBtn").pressed.connect(demo_end._on_continue_pressed)
	demo_end.get_node("Panel/VBox/MenuBtn").pressed.connect(demo_end._on_menu_pressed)

	# Wire player signals
	player.mining_started.connect(_on_mining_started)
	player.mining_finished.connect(_on_mining_finished)

	# Wire save progression
	SaveManager.gold_changed.connect(_on_gold_changed)
	SaveManager.tool_unlocked.connect(_on_tool_event)

	# Init tutorial
	Tutorial.init(hud)
	_show_intro_tutorial()

	# Sync cabin if already built
	if SaveManager.data.get("camp_level", 0) >= 1:
		_build_cabin()

func _show_intro_tutorial() -> void:
	Tutorial.show_step("move",  "💡 Use WASD to move, mouse to look around", 1.5)
	await get_tree().create_timer(6.0).timeout
	Tutorial.show_step("river", "💡 Walk to the blue river and press SPACE to pan for gold", 0.5)
	await get_tree().create_timer(8.0).timeout
	Tutorial.show_step("store", "💡 Visit the General Store (brown building) to buy better tools", 0.5)

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Pause — only when store/inventory/demo not open
	if event.is_action_pressed("ui_cancel"):
		if store_ui.visible or inventory.visible or demo_end.visible:
			return
		if pause_menu.visible:
			pause_menu.close()
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()
		return

	# Store open
	if event.is_action_pressed("ui_accept") and _near_store and not store_ui.visible \
			and not pause_menu.visible and not inventory.visible:
		store_ui.open()
		get_viewport().set_input_as_handled()

# ─── Zone signals ─────────────────────────────────────────────────────────────

func _on_zone_entered(zone) -> void:
	var tool_id: String = zone.get_tool_id()
	hud.set_tool(tool_id)
	if SaveManager.has_tool(tool_id) or tool_id == "pan":
		hud.set_prompt("SPACE — %s" % zone.zone_name)
	else:
		var cost: float   = ToolSystem.get_unlock_cost(tool_id)
		var tname: String = str(ToolSystem.TOOLS.get(tool_id, {}).get("name", tool_id))
		hud.set_prompt("Need %s — buy at store (%dg)" % [tname, int(cost)])

func _on_zone_exited(_zone) -> void:
	hud.set_prompt("")
	hud.set_tool("pan")

func _on_store_entered() -> void:
	_near_store = true
	hud.set_prompt("SPACE — General Store")

func _on_store_exited() -> void:
	_near_store = false
	hud.set_prompt("")

func _on_store_closed() -> void:
	pass

# ─── Mining signals ───────────────────────────────────────────────────────────

func _on_mining_started(tool_id: String) -> void:
	if tool_id == "locked":
		hud.show_message("Buy this tool at the General Store first!")
		Audio.play("ui_click", -12.0)
		return
	Audio.play("mining_hit", -8.0)
	hud.show_mining(tool_id, ToolSystem.get_action_time(tool_id))

func _on_mining_finished(tool_id: String, amount: float, lucky: bool) -> void:
	hud.hide_mining()
	_spawn_gold_burst(player.global_position)
	if lucky:
		cam_pivot.shake(0.3, 0.4)
		Audio.play("lucky_fanfare", -3.0)
		hud.show_message("⭐ Lucky strike! Found %.2fg!" % amount, 4.0)
	elif amount >= 2.5:
		Audio.play("gold_big", -6.0)
		hud.show_message("Good find: %.2fg" % amount)
	else:
		Audio.play("gold_chime", -8.0)
		hud.show_message("Found %.2fg" % amount)

# ─── Gold progression ─────────────────────────────────────────────────────────

func _on_gold_changed(amount: float) -> void:
	# Cabin unlock
	if not _cabin_built and amount >= CABIN_GOLD and SaveManager.data.get("camp_level", 0) < 1:
		Tutorial.show_step("cabin", "🏠 You can now upgrade to a Cabin! Visit the store.", 0.0)

	# Demo end
	if not _demo_ended and amount >= DEMO_END_GOLD:
		_demo_ended = true
		await get_tree().create_timer(2.0).timeout
		demo_end.show_end(amount)

func _on_tool_event(tool_id: String) -> void:
	# Cabin bought through store triggers camp upgrade
	if tool_id == "cabin_kit":
		_build_cabin()
		SaveManager.set_camp_level(1)

# ─── Cabin upgrade ────────────────────────────────────────────────────────────

func _build_cabin() -> void:
	_cabin_built = true
	# Find and remove tent via Scenery (replace with cabin mesh)
	# For now: just spawn a simple cabin at the tent position
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.42, 0.28, 0.14)
	var mat_roof := StandardMaterial3D.new()
	mat_roof.albedo_color = Color(0.25, 0.14, 0.08)

	# Main cabin body
	var cabin := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(3.8, 2.8, 3.5)
	cabin.mesh = cm
	cabin.position = Vector3(6, 1.4, 5)
	cabin.set_surface_override_material(0, mat_wood)
	add_child(cabin)

	# Cabin roof
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.05; rm.bottom_radius = 2.8; rm.height = 1.4; rm.radial_segments = 4
	roof.mesh = rm
	roof.position = Vector3(6, 3.5, 5)
	roof.rotation.y = PI / 4.0
	roof.set_surface_override_material(0, mat_roof)
	add_child(roof)

	hud.show_message("🏠 Cabin built! You're putting down roots.", 5.0)

# ─── Gold particles ───────────────────────────────────────────────────────────

func _spawn_gold_burst(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position              = pos + Vector3(0, 1.2, 0)
	p.amount                = 14
	p.lifetime              = 0.9
	p.one_shot              = true
	p.explosiveness         = 0.95
	p.direction             = Vector3(0, 1, 0)
	p.spread                = 65.0
	p.gravity               = Vector3(0, -6.0, 0)
	p.initial_velocity_min  = 2.5
	p.initial_velocity_max  = 5.0
	p.scale_amount_min      = 0.08
	p.scale_amount_max      = 0.22
	p.color                 = Color(1.0, 0.85, 0.1, 1.0)
	add_child(p)
	p.emitting = true
	await get_tree().create_timer(2.0).timeout
	p.queue_free()
