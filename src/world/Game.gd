extends Node3D

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

var _near_store:   bool   = false
var _current_zone: String = ""
var _demo_ended: bool     = false
var _cabin_built: bool    = false

func _ready() -> void:
	cam_pivot.target    = player
	player.camera_pivot = cam_pivot

	# Wire mining zones
	for zone in [pan_zone, rich_zone, shallow_zone, rock_zone, earth_zone]:
		zone.player_entered.connect(_on_zone_entered)
		zone.player_exited.connect(_on_zone_exited)
	store_zone.player_entered.connect(_on_store_entered)
	store_zone.player_exited.connect(_on_store_exited)

	# Wire timber zones (spawned procedurally by Scenery)
	var scenery: Node3D = $World/Scenery
	for tzone in scenery.timber_zones:
		tzone.player_entered.connect(_on_timber_zone_entered)
		tzone.player_exited.connect(_on_timber_zone_exited)

	# Wire cabin zones (spawned procedurally by Scenery)
	for czone in scenery.cabin_zones:
		czone.player_entered.connect(_on_cabin_zone_entered)
		czone.player_exited.connect(_on_cabin_zone_exited)

	# Wire UI
	hud.tool_selected.connect(_on_tool_selected)
	store_ui.closed.connect(_on_store_closed)
	pause_menu.get_node("Panel/VBox/ResumeBtn").pressed.connect(pause_menu._on_resume_pressed)
	pause_menu.get_node("Panel/VBox/SaveBtn").pressed.connect(pause_menu._on_save_pressed)
	pause_menu.get_node("Panel/VBox/QuitBtn").pressed.connect(pause_menu._on_quit_pressed)
	demo_end.get_node("Panel/VBox/ContinueBtn").pressed.connect(demo_end._on_continue_pressed)
	demo_end.get_node("Panel/VBox/MenuBtn").pressed.connect(demo_end._on_menu_pressed)

	# Wire player signals
	player.mining_started.connect(_on_mining_started)
	player.mining_finished.connect(_on_mining_finished)
	player.chopping_started.connect(_on_chopping_started)
	player.chopping_hit.connect(_on_chopping_hit)
	player.chopping_finished.connect(_on_chopping_finished)
	player.cabin_placed.connect(_on_cabin_placed)

	# Wire save progression
	SaveManager.gold_changed.connect(_on_gold_changed)
	SaveManager.tool_unlocked.connect(_on_tool_event)

	# Init tutorial
	Tutorial.init(hud)
	_show_intro_tutorial()

	# Spatial ambient audio — river at x=-18, campfire near camp
	Audio.start_ambient("river", Vector3(-18.0, 0.5, 0.0),  -8.0, 35.0)
	Audio.start_ambient("fire",  Vector3(6.5,   0.7, 10.5), -14.0, 18.0)

	# Forest ambient — one emitter per timber grove
	Audio.start_ambient("forest_pine",  Vector3(-30, 0.5, 20),  -16.0, 25.0)
	Audio.start_ambient("forest_oak",   Vector3(25,  0.5, -15), -16.0, 25.0)
	Audio.start_ambient("forest_cedar", Vector3(-10, 0.5, -35), -16.0, 25.0)

	# Sync cabin if already placed
	if SaveManager.has_cabin():
		_build_cabin()
		_hide_cabin_zone_markers()

func _show_intro_tutorial() -> void:
	Tutorial.show_step("move",  "💡 Use WASD to move, mouse to look around", 1.5)
	await get_tree().create_timer(6.0).timeout
	Tutorial.show_step("river", "💡 Walk to the blue river and press SPACE to pan for gold", 0.5)
	await get_tree().create_timer(8.0).timeout
	Tutorial.show_step("store", "💡 Visit the General Store (brown building) to buy better tools", 0.5)

# ─── Input ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Footsteps — check if player is moving on ground
	if player and player.is_on_floor():
		var moving: bool = player.velocity.length() > 0.5
		Audio.update_footsteps(moving, delta)
	else:
		Audio.update_footsteps(false, delta)

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


# ─── Zone signals ─────────────────────────────────────────────────────────────

func _on_tool_selected(tool_id: String) -> void:
	player.current_tool = tool_id
	player.equip_tool(tool_id)

func _on_zone_entered(zone) -> void:
	var tool_id: String = zone.get_tool_id()
	_current_zone = zone.zone_name.to_lower().replace(" ", "_")
	if SaveManager.has_tool(tool_id) or tool_id == "pan":
		hud.set_prompt("SPACE — %s" % zone.zone_name)
	else:
		var cost: float   = ToolSystem.get_unlock_cost(tool_id)
		var tname: String = str(ToolSystem.TOOLS.get(tool_id, {}).get("name", tool_id))
		hud.set_prompt("Need %s — buy at store (%dg)" % [tname, int(cost)])

func _on_zone_exited(_zone) -> void:
	_current_zone = ""
	hud.set_prompt("")

func _on_store_entered() -> void:
	_near_store = true
	if not store_ui.visible and not pause_menu.visible and not inventory.visible:
		store_ui.open()

func _on_store_exited() -> void:
	_near_store = false

func _on_store_closed() -> void:
	hud._refresh_hotbar()

# ─── Timber zone signals ─────────────────────────────────────────────────────

func _on_timber_zone_entered(zone) -> void:
	if SaveManager.has_tool("axe"):
		hud.set_prompt("SPACE — Chop trees (%s)" % zone.zone_name)
	else:
		hud.set_prompt("Need Axe — buy at store (10g)")

func _on_timber_zone_exited(_zone) -> void:
	hud.set_prompt("")

# ─── Cabin zone signals ─────────────────────────────────────────────────────

func _on_cabin_zone_entered(zone) -> void:
	if SaveManager.has_cabin():
		return
	if SaveManager.has_cabin_kit():
		hud.set_prompt("SPACE — Place Cabin (%s)" % zone.zone_name)
	else:
		hud.set_prompt("Buy a Cabin Kit at the store first")

func _on_cabin_zone_exited(_zone) -> void:
	hud.set_prompt("")

func _on_cabin_placed(zone) -> void:
	if _cabin_built:
		return
	SaveManager.place_cabin()
	_build_cabin_at_zone(zone)
	Audio.play("wood_collect", -4.0)
	hud.show_message("Cabin placed!", 5.0)
	# Cabin is the demo milestone — show end screen after a moment
	if not _demo_ended:
		_demo_ended = true
		await get_tree().create_timer(3.0).timeout
		demo_end.show_end(SaveManager.get_gold())

func _build_cabin_at_zone(zone) -> void:
	_cabin_built = true
	if zone.marker:
		zone.marker.queue_free()
		zone.marker = null
	_spawn_log_cabin(zone.global_position)
	_hide_cabin_zone_markers()
	zone.set_deferred("monitoring", false)

func _hide_cabin_zone_markers() -> void:
	var scenery: Node3D = $World/Scenery
	for czone in scenery.cabin_zones:
		if czone.marker:
			czone.marker.queue_free()
			czone.marker = null
		czone.set_deferred("monitoring", false)

# ─── Mining signals ───────────────────────────────────────────────────────────

func _on_mining_started(tool_id: String) -> void:
	if tool_id == "locked":
		hud.show_message("Buy this tool at the General Store first!")
		Audio.play("ui_click", -12.0)
		return
	Audio.play("mining_hit", -8.0)
	# Pan splash when mining in water zones
	if _current_zone in ["american_river", "rich_bend", "shallow_ford"]:
		Audio.play("pan_splash", -10.0)
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

# ─── Chopping signals ─────────────────────────────────────────────────────────

func _on_chopping_started() -> void:
	Audio.play("wood_chop", -6.0)
	hud.show_mining("pickaxe", player.CHOP_TIME * player.CHOPS_PER_LOG)

func _on_chopping_hit(hits_done: int) -> void:
	Audio.play("wood_chop", -8.0)
	hud.show_message("Chop %d/%d" % [hits_done, player.CHOPS_PER_LOG], 1.0)

func _on_chopping_finished() -> void:
	hud.hide_mining()
	Audio.play("wood_collect", -4.0)
	hud.show_message("Timber +1 log!", 3.0)

# ─── Gold progression ─────────────────────────────────────────────────────────

func _on_gold_changed(amount: float) -> void:
	# Cabin unlock
	if not _cabin_built and amount >= CABIN_GOLD and SaveManager.data.get("camp_level", 0) < 1:
		Tutorial.show_step("cabin", "🏠 You can now upgrade to a Cabin! Visit the store.", 0.0)


func _on_tool_event(tool_id: String) -> void:
	pass

# ─── Cabin upgrade ────────────────────────────────────────────────────────────

func _build_cabin() -> void:
	# Used when loading a save with cabin already placed — spawn at default position
	_cabin_built = true
	_spawn_log_cabin(Vector3(10, 0, 5))

# ─── Log cabin builder ────────────────────────────────────────────────────────
# Authentic 1850s gold rush log cabin: stacked horizontal logs with chinking,
# gable roof, stone chimney, front porch, door, and windows.

func _spawn_log_cabin(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Cabin"
	root.position = pos
	add_child(root)

	# ── Materials ──────────────────────────────────────────────────────────
	var mat_log     := _cabin_mat(Color(0.48, 0.36, 0.20), 0.85)  # weathered pine
	var mat_log_dk  := _cabin_mat(Color(0.38, 0.28, 0.15), 0.90)  # alternating darker
	var mat_chink   := _cabin_mat(Color(0.72, 0.66, 0.54), 0.95)  # mud/mortar chinking
	var mat_roof    := _cabin_mat(Color(0.30, 0.22, 0.14), 0.90)  # dark wood shingles
	var mat_stone   := _cabin_mat(Color(0.50, 0.48, 0.44), 0.95)  # chimney stone
	var mat_stone_dk := _cabin_mat(Color(0.38, 0.36, 0.33), 0.95)  # darker stone
	var mat_door    := _cabin_mat(Color(0.32, 0.22, 0.10), 0.88)  # plank door
	var mat_window  := _cabin_mat(Color(0.22, 0.28, 0.38), 0.50)  # glass pane
	var mat_sash    := _cabin_mat(Color(0.30, 0.20, 0.10), 0.90)  # window frame
	var mat_porch   := _cabin_mat(Color(0.50, 0.38, 0.22), 0.88)  # porch planks
	var mat_dark    := _cabin_mat(Color(0.18, 0.12, 0.06), 0.92)  # dark trim

	# ── Dimensions ─────────────────────────────────────────────────────────
	var W      := 4.2    # width (X)
	var D      := 3.6    # depth (Z)
	var log_r  := 0.14   # log radius
	var log_d  := 0.28   # log diameter / vertical spacing
	var n_logs := 8      # logs per wall
	var wall_h := n_logs * log_d   # 2.24
	var ovh    := 0.20   # corner overhang (log ends sticking out)
	var door_w := 0.90   # door width
	var door_n := 6      # bottom N logs have door gap
	var ridge_h := 1.35  # gable peak above wall top

	# ── Helper: horizontal log cylinder ────────────────────────────────────
	# axis "x" = log runs along X, "z" = log runs along Z
	var _add_log := func(length: float, radius: float, axis: String, p: Vector3, mat: StandardMaterial3D) -> void:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius; cm.bottom_radius = radius
		cm.height = length; cm.radial_segments = 8
		mi.mesh = cm
		if axis == "x":
			mi.rotation.z = PI / 2.0
		else:
			mi.rotation.x = PI / 2.0
		mi.position = p
		mi.set_surface_override_material(0, mat)
		root.add_child(mi)

	# ── Helper: box ────────────────────────────────────────────────────────
	var _add_box := func(p: Vector3, s: Vector3, mat: StandardMaterial3D) -> void:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s
		mi.mesh = bm; mi.position = p
		mi.set_surface_override_material(0, mat)
		root.add_child(mi)

	# ── 1. Wall logs ───────────────────────────────────────────────────────
	for i in range(n_logs):
		var y := log_r + i * log_d
		var mat: StandardMaterial3D = mat_log if i % 2 == 0 else mat_log_dk
		var full_x := W + 2.0 * ovh   # full front/back log length
		var full_z := D + 2.0 * ovh   # full side log length

		# Back wall — full continuous log
		_add_log.call(full_x, log_r, "x", Vector3(0, y, D / 2.0), mat)

		# Front wall — split for door on lower logs
		if i < door_n:
			var seg := (W / 2.0 - door_w / 2.0) + ovh
			_add_log.call(seg, log_r, "x", Vector3(-(door_w / 2.0 + seg / 2.0), y, -D / 2.0), mat)
			_add_log.call(seg, log_r, "x", Vector3( (door_w / 2.0 + seg / 2.0), y, -D / 2.0), mat)
		else:
			_add_log.call(full_x, log_r, "x", Vector3(0, y, -D / 2.0), mat)

		# Side walls
		_add_log.call(full_z, log_r, "z", Vector3(-W / 2.0, y, 0), mat)
		_add_log.call(full_z, log_r, "z", Vector3( W / 2.0, y, 0), mat)

	# ── 2. Chinking (light strips between logs) ───────────────────────────
	for i in range(n_logs - 1):
		var y := log_d + i * log_d   # midpoint between log i and i+1
		var ch := 0.05               # chinking strip height
		var cd := 0.06               # chinking strip depth

		# Back wall
		_add_box.call(Vector3(0, y, D / 2.0 + log_r * 0.6), Vector3(W - 0.2, ch, cd), mat_chink)

		# Front wall (with door gap)
		if i < door_n - 1:
			var sw := W / 2.0 - door_w / 2.0 - 0.15
			_add_box.call(Vector3(-(door_w / 2.0 + sw / 2.0 + 0.05), y, -(D / 2.0 + log_r * 0.6)), Vector3(sw, ch, cd), mat_chink)
			_add_box.call(Vector3( (door_w / 2.0 + sw / 2.0 + 0.05), y, -(D / 2.0 + log_r * 0.6)), Vector3(sw, ch, cd), mat_chink)
		else:
			_add_box.call(Vector3(0, y, -(D / 2.0 + log_r * 0.6)), Vector3(W - 0.2, ch, cd), mat_chink)

		# Side walls
		_add_box.call(Vector3(-(W / 2.0 + log_r * 0.6), y, 0), Vector3(cd, ch, D - 0.2), mat_chink)
		_add_box.call(Vector3( (W / 2.0 + log_r * 0.6), y, 0), Vector3(cd, ch, D - 0.2), mat_chink)

	# ── 3. Gable end triangles (stacked shorter logs) ─────────────────────
	# Front and back gable: progressively shorter logs above wall top
	var gable_logs := 5
	for i in range(gable_logs):
		var y := wall_h + log_r + i * log_d
		var shrink := (float(i + 1) / float(gable_logs + 1)) * (W / 2.0)
		var gable_len := W - 2.0 * shrink
		if gable_len < 0.3:
			break
		var mat: StandardMaterial3D = mat_log if (n_logs + i) % 2 == 0 else mat_log_dk
		# Front gable
		_add_log.call(gable_len, log_r, "x", Vector3(0, y, -D / 2.0), mat)
		# Back gable
		_add_log.call(gable_len, log_r, "x", Vector3(0, y,  D / 2.0), mat)

	# ── 4. Gable roof (two tilted planes) ─────────────────────────────────
	var eave_ovh := 0.35   # roof overhang beyond walls
	var half_w := W / 2.0 + eave_ovh
	var slope_len := sqrt(half_w * half_w + ridge_h * ridge_h)
	var roof_angle := atan2(ridge_h, half_w)
	var roof_depth := D + 0.7  # front/back overhang
	var roof_thick := 0.10

	# Left roof plane
	var left_roof := MeshInstance3D.new()
	var lrm := BoxMesh.new()
	lrm.size = Vector3(slope_len, roof_thick, roof_depth)
	left_roof.mesh = lrm
	left_roof.position = Vector3(-half_w / 2.0, wall_h + ridge_h / 2.0, 0)
	left_roof.rotation.z = roof_angle
	left_roof.set_surface_override_material(0, mat_roof)
	root.add_child(left_roof)

	# Right roof plane
	var right_roof := MeshInstance3D.new()
	right_roof.mesh = lrm   # reuse mesh
	right_roof.position = Vector3(half_w / 2.0, wall_h + ridge_h / 2.0, 0)
	right_roof.rotation.z = -roof_angle
	right_roof.set_surface_override_material(0, mat_roof)
	root.add_child(right_roof)

	# Ridge beam (dark log along the peak)
	_add_log.call(roof_depth, 0.08, "z", Vector3(0, wall_h + ridge_h + 0.02, 0), mat_dark)

	# ── 5. Stone chimney (right side) ─────────────────────────────────────
	var chim_x := W / 2.0 + 0.30
	var chim_w := 0.70
	var chim_d := 0.65
	var chim_h := wall_h + ridge_h + 0.5

	# Main chimney column
	_add_box.call(Vector3(chim_x, chim_h / 2.0, 0), Vector3(chim_w, chim_h, chim_d), mat_stone)
	# Chimney cap (slightly wider)
	_add_box.call(Vector3(chim_x, chim_h + 0.06, 0), Vector3(chim_w + 0.12, 0.12, chim_d + 0.12), mat_stone_dk)
	# Base (wider footing like the reference photos)
	_add_box.call(Vector3(chim_x, 0.6, 0), Vector3(chim_w + 0.25, 1.2, chim_d + 0.20), mat_stone)
	# Stone course lines (horizontal dark strips for stone rows)
	for si in range(1, int(chim_h / 0.45)):
		var sy := si * 0.45
		if sy < chim_h - 0.2:
			_add_box.call(Vector3(chim_x + chim_w / 2.0 + 0.01, sy, 0), Vector3(0.02, 0.03, chim_d - 0.08), mat_stone_dk)

	# ── 6. Door ────────────────────────────────────────────────────────────
	var door_h := door_n * log_d   # 1.68
	# Door recess (dark opening)
	_add_box.call(Vector3(0, door_h / 2.0, -(D / 2.0 + 0.02)), Vector3(door_w - 0.08, door_h - 0.06, 0.08), mat_dark)
	# Door plank
	_add_box.call(Vector3(0.08, door_h / 2.0, -(D / 2.0 + 0.06)), Vector3(door_w - 0.15, door_h - 0.10, 0.06), mat_door)
	# Door frame (lintel log above door)
	_add_log.call(door_w + 0.4, log_r + 0.02, "x", Vector3(0, door_h + 0.02, -(D / 2.0 + 0.04)), mat_log_dk)

	# ── 7. Windows ─────────────────────────────────────────────────────────
	var win_w := 0.55
	var win_h := 0.50
	var win_y := wall_h * 0.58   # ~58% up the wall

	# Front windows (left and right of door)
	for wx in [-1.25, 1.25]:
		# Glass pane
		_add_box.call(Vector3(wx, win_y, -(D / 2.0 + log_r + 0.01)), Vector3(win_w, win_h, 0.03), mat_window)
		# Sash frame (4 bars forming a cross)
		_add_box.call(Vector3(wx, win_y, -(D / 2.0 + log_r + 0.03)), Vector3(0.04, win_h + 0.06, 0.03), mat_sash)  # vertical
		_add_box.call(Vector3(wx, win_y, -(D / 2.0 + log_r + 0.03)), Vector3(win_w + 0.06, 0.04, 0.03), mat_sash)  # horizontal

	# Side windows (one per side wall)
	for sz in [-1]:   # one window on left wall
		_add_box.call(Vector3(-(W / 2.0 + log_r + 0.01), win_y, sz * 0.3), Vector3(0.03, win_h, win_w), mat_window)
		_add_box.call(Vector3(-(W / 2.0 + log_r + 0.03), win_y, sz * 0.3), Vector3(0.03, win_h + 0.06, 0.04), mat_sash)
		_add_box.call(Vector3(-(W / 2.0 + log_r + 0.03), win_y, sz * 0.3), Vector3(0.03, 0.04, win_w + 0.06), mat_sash)

	# ── 8. Front porch ────────────────────────────────────────────────────
	var porch_d := 1.4    # porch depth from front wall
	var porch_w := W + 0.6

	# Porch floor
	_add_box.call(Vector3(0, 0.10, -(D / 2.0 + porch_d / 2.0)), Vector3(porch_w, 0.12, porch_d), mat_porch)

	# Plank lines on porch floor
	for pi in range(-2, 3):
		_add_box.call(Vector3(pi * 0.9, 0.17, -(D / 2.0 + porch_d / 2.0)), Vector3(0.04, 0.01, porch_d), mat_dark)

	# Porch posts (2 posts)
	for px in [-(porch_w / 2.0 - 0.3), porch_w / 2.0 - 0.3]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.07; pm.bottom_radius = 0.09; pm.height = wall_h * 0.85
		pm.radial_segments = 8
		post.mesh = pm
		post.position = Vector3(px, wall_h * 0.85 / 2.0 + 0.16, -(D / 2.0 + porch_d - 0.15))
		post.set_surface_override_material(0, mat_dark)
		root.add_child(post)

	# Porch roof (extends from front wall outward)
	var porch_roof_angle := 0.12   # slight downward tilt
	_add_box.call(
		Vector3(0, wall_h * 0.85 + 0.22, -(D / 2.0 + porch_d / 2.0 - 0.1)),
		Vector3(porch_w + 0.1, 0.08, porch_d + 0.3),
		mat_roof
	)

	# Step up to porch
	_add_box.call(Vector3(0, 0.04, -(D / 2.0 + porch_d + 0.18)), Vector3(1.2, 0.08, 0.35), mat_porch)

	# ── 9. Collision body (simplified box for the whole cabin) ─────────────
	var body := StaticBody3D.new()
	body.position = Vector3(0, wall_h / 2.0, 0)
	root.add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W + 0.3, wall_h + 0.2, D + 0.3)
	col.shape = shape
	body.add_child(col)

func _cabin_mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

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
