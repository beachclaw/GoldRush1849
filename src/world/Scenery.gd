extends Node3D

# Procedural scenery — seeded 1849 for a reproducible world

const RIVER_X = -18.0
const RIVER_WIDTH = 8.0
const FIELD_HALF = 38.0

var rng := RandomNumberGenerator.new()

var mat_trunk: StandardMaterial3D
var mat_leaves: StandardMaterial3D
var mat_leaves_dark: StandardMaterial3D
var mat_rock: StandardMaterial3D
var mat_mountain: StandardMaterial3D
var mat_mountain_snow: StandardMaterial3D
var mat_dirt: StandardMaterial3D
var mat_cloud: StandardMaterial3D
var mat_sun: StandardMaterial3D

func _ready() -> void:
	rng.seed = 1849
	_setup_materials()
	_setup_environment()
	_spawn_sun()
	_spawn_clouds()
	_spawn_camp()
	_spawn_store_building()
	_spawn_rock_face()
	_spawn_loose_earth()
	_spawn_mountains()
	_spawn_trees(50)
	_spawn_timber_groves()
	_spawn_rocks(30)
	_spawn_river_banks()
	_spawn_rich_vein_markers()
	_spawn_campfire_particles()
	_spawn_cabin_zones()

func _setup_materials() -> void:
	mat_trunk         = _mat(Color(0.38, 0.25, 0.12))
	mat_leaves        = _mat(Color(0.20, 0.48, 0.18))
	mat_leaves_dark   = _mat(Color(0.13, 0.32, 0.13))
	mat_rock          = _mat(Color(0.55, 0.52, 0.48))
	mat_mountain      = _mat(Color(0.46, 0.42, 0.36))
	mat_mountain_snow = _mat(Color(0.93, 0.92, 0.88))
	mat_dirt          = _mat(Color(0.60, 0.46, 0.28))

	# Clouds — unshaded bright white so they glow regardless of sun angle
	mat_cloud = _mat(Color(1.0, 1.0, 1.0))
	mat_cloud.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Sun disc — unshaded warm yellow with emission
	mat_sun = _mat(Color(1.0, 0.96, 0.72))
	mat_sun.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_sun.emission_enabled = true
	mat_sun.emission = Color(1.0, 0.92, 0.55)
	mat_sun.emission_energy_multiplier = 3.0

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

func _set_mat(mi: MeshInstance3D, mat: StandardMaterial3D) -> void:
	mi.set_surface_override_material(0, mat)

# ─── Sky & Environment ────────────────────────────────────────────────────────

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color        = Color(0.05, 0.18, 0.65)   # deep blue zenith
	sky_mat.sky_horizon_color    = Color(0.55, 0.76, 0.98)   # bright horizon
	sky_mat.ground_horizon_color = Color(0.58, 0.50, 0.35)
	sky_mat.ground_bottom_color  = Color(0.25, 0.20, 0.12)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode      = Environment.BG_SKY
	env.sky                  = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.75, 0.68, 0.58)
	env.ambient_light_energy = 0.7
	env.fog_enabled          = true
	env.fog_light_color      = Color(0.72, 0.78, 0.85)
	env.fog_light_energy     = 1.0
	env.fog_density          = 0.004

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

# ─── Sun Disc ─────────────────────────────────────────────────────────────────

func _spawn_sun() -> void:
	# Sun in the clear gap between mountains (x=23–34 zone), elev ~18° in viewport
	var sun_pos := Vector3(28, 24, -40)

	var sun_disc := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius          = 5.0
	mesh.height          = 10.0
	mesh.radial_segments = 16
	mesh.rings           = 8
	sun_disc.mesh     = mesh
	sun_disc.position = sun_pos
	add_child(sun_disc)
	_set_mat(sun_disc, mat_sun)

	# Soft translucent glow halo
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color               = Color(1.0, 0.95, 0.6, 0.20)
	glow_mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.emission_enabled           = true
	glow_mat.emission                   = Color(1.0, 0.88, 0.4)
	glow_mat.emission_energy_multiplier = 1.2
	glow_mat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.cull_mode                  = BaseMaterial3D.CULL_DISABLED

	var glow := MeshInstance3D.new()
	var gmesh := SphereMesh.new()
	gmesh.radius          = 9.0
	gmesh.height          = 18.0
	gmesh.radial_segments = 16
	gmesh.rings           = 8
	glow.mesh     = gmesh
	glow.position = sun_pos
	add_child(glow)
	glow.set_surface_override_material(0, glow_mat)

# ─── Camp ─────────────────────────────────────────────────────────────────────

func _spawn_camp() -> void:
	var mat_canvas  := _mat(Color(0.82, 0.72, 0.52))   # canvas tan
	var mat_pole    := _mat(Color(0.32, 0.20, 0.10))   # dark wood
	var mat_fire    := StandardMaterial3D.new()
	mat_fire.albedo_color               = Color(1.0, 0.45, 0.05)
	mat_fire.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fire.emission_enabled           = true
	mat_fire.emission                   = Color(1.0, 0.35, 0.0)
	mat_fire.emission_energy_multiplier = 3.0
	var mat_coal    := _mat(Color(0.18, 0.14, 0.10))
	var mat_log     := _mat(Color(0.35, 0.22, 0.10))

	# ═══ CAMP LAYOUT ════════════════════════════════════════════════════════
	# Camp is tucked in the SE corner (10, 0, 12), sheltered by trees
	# Campfire slightly west of tent creates a natural gathering point
	# Store sits NW of the spawn point (-6, 0, -3), facing south toward river trail
	# Natural path: Camp (SE) → Spawn (0,0) → Store (NW) → River (W)

	var TENT_POS  := Vector3(10.0, 0.0, 12.0)
	var FIRE_POS  := Vector3(6.5,  0.0, 10.5)

	# ── Tent — pyramid shape
	var tent := MeshInstance3D.new()
	var tm   := CylinderMesh.new()
	tm.top_radius      = 0.08
	tm.bottom_radius   = 2.2
	tm.height          = 2.6
	tm.radial_segments = 4
	tm.rings           = 1
	tent.mesh     = tm
	tent.position = TENT_POS + Vector3(0, 1.3, 0)
	tent.rotation.y = PI / 4.0
	add_child(tent)
	_set_mat(tent, mat_canvas)

	# Tent door — dark opening facing the fire
	var door := MeshInstance3D.new()
	var dm   := BoxMesh.new()
	dm.size       = Vector3(0.9, 1.2, 0.05)
	door.mesh     = dm
	door.position = TENT_POS + Vector3(-1.52, 0.6, -1.52)
	door.rotation.y = PI / 4.0
	add_child(door)
	_set_mat(door, _mat(Color(0.28, 0.18, 0.08)))

	# Tent guy-rope stakes (4 small pegs around tent)
	for angle in [0.0, PI/2.0, PI, 3.0*PI/2.0]:
		var stake := MeshInstance3D.new()
		var sm2   := CylinderMesh.new()
		sm2.top_radius = 0.03; sm2.bottom_radius = 0.04; sm2.height = 0.35
		stake.mesh     = sm2
		stake.position = TENT_POS + Vector3(sin(angle) * 2.6, 0.17, cos(angle) * 2.6)
		add_child(stake)
		_set_mat(stake, mat_pole)

	# Bedroll visible inside tent (log sitting near entrance)
	var bedroll := MeshInstance3D.new()
	var brm     := CylinderMesh.new()
	brm.top_radius = 0.18; brm.bottom_radius = 0.20; brm.height = 1.1
	bedroll.mesh     = brm
	bedroll.position = TENT_POS + Vector3(-0.3, 0.2, 0.3)
	bedroll.rotation.z = PI / 2.0
	bedroll.rotation.y = PI / 3.0
	add_child(bedroll)
	_set_mat(bedroll, _mat(Color(0.55, 0.40, 0.28)))

	# Tree stump seat near fire
	var stump := MeshInstance3D.new()
	var stm   := CylinderMesh.new()
	stm.top_radius = 0.28; stm.bottom_radius = 0.32; stm.height = 0.45; stm.radial_segments = 8
	stump.mesh     = stm
	stump.position = FIRE_POS + Vector3(1.6, 0.22, -0.8)
	add_child(stump)
	_set_mat(stump, _mat(Color(0.36, 0.24, 0.14)))
	# Stump top ring (lighter)
	var stump_top := MeshInstance3D.new()
	var stm2      := CylinderMesh.new()
	stm2.top_radius = 0.27; stm2.bottom_radius = 0.27; stm2.height = 0.03; stm2.radial_segments = 8
	stump_top.mesh     = stm2
	stump_top.position = FIRE_POS + Vector3(1.6, 0.46, -0.8)
	add_child(stump_top)
	_set_mat(stump_top, _mat(Color(0.58, 0.44, 0.28)))

	# ── Campfire
	var fire_pos := FIRE_POS

	# Log circle
	for i in range(4):
		var log := MeshInstance3D.new()
		var lm  := CylinderMesh.new()
		lm.top_radius    = 0.10
		lm.bottom_radius = 0.12
		lm.height        = 1.2
		log.mesh      = lm
		log.position  = fire_pos + Vector3(0, 0.1, 0)
		log.rotation.z = PI / 2.0
		log.rotation.y = i * (PI / 2.0)
		add_child(log)
		_set_mat(log, mat_log)

	# Coal base
	var coal := MeshInstance3D.new()
	var cm   := CylinderMesh.new()
	cm.top_radius    = 0.4
	cm.bottom_radius = 0.5
	cm.height        = 0.12
	coal.mesh     = cm
	coal.position = fire_pos + Vector3(0, 0.06, 0)
	add_child(coal)
	_set_mat(coal, mat_coal)

	# Flame — small emissive cone
	var flame := MeshInstance3D.new()
	var fm    := CylinderMesh.new()
	fm.top_radius      = 0.02
	fm.bottom_radius   = 0.28
	fm.height          = 0.9
	fm.radial_segments = 5
	flame.mesh     = fm
	flame.position = fire_pos + Vector3(0, 0.55, 0)
	add_child(flame)
	flame.set_surface_override_material(0, mat_fire)

	# Flame glow point light
	var light := OmniLight3D.new()
	light.position         = fire_pos + Vector3(0, 0.7, 0)
	light.light_color      = Color(1.0, 0.5, 0.1)
	light.light_energy     = 2.5
	light.omni_range       = 8.0
	add_child(light)

# ─── Clouds ───────────────────────────────────────────────────────────────────

func _spawn_clouds() -> void:
	# All clouds in front of mountains (z > -50), y=12-18 range
	# At these positions elevation from camera is ~10-18° — within the viewport
	var cloud_anchors = [
		Vector3(-22, 15, -40),
		Vector3( 18, 14, -42),
		Vector3(-40, 16, -35),
		Vector3( 38, 15, -38),
		Vector3(  2, 17, -48),
		Vector3(-15, 14, -32),
		Vector3( 28, 16, -45),
	]
	for pos in cloud_anchors:
		_place_cloud(pos)

func _place_cloud(base_pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = base_pos
	add_child(root)

	var puff_count := rng.randi_range(4, 7)
	for i in range(puff_count):
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var r := rng.randf_range(3.5, 7.0)
		mesh.radius = r
		mesh.height = r * 2.0
		puff.mesh     = mesh
		puff.position = Vector3(
			rng.randf_range(-7.0, 7.0),
			rng.randf_range(-0.5, 1.2),
			rng.randf_range(-3.0, 3.0)
		)
		puff.scale.y = rng.randf_range(0.28, 0.45)
		root.add_child(puff)
		_set_mat(puff, mat_cloud)

# ─── Mountains ────────────────────────────────────────────────────────────────

func _spawn_mountains() -> void:
	# Sierra Nevada character: asymmetric ridgelines, granite grey, clustered sub-peaks,
	# foreground hills for depth, snow only on upper ~20%

	# Sierra Nevada reference: asymmetric ridges, granite grey-brown, varied heights,
	# foreground hills for atmospheric depth, clustered tight sub-peaks that merge visually

	# Strategy: pack ALL peaks into a tight band x=-35 to +35, z=-43 to -52.
	# This puts the range squarely in the player's starting view.
	# One dominant spike at centre (h=70), flanked by progressively shorter peaks.
	# Mountains have NO collision — player is blocked by invisible wall at z=-41.

	# FAR BACKDROP — very wide, low silhouette behind main peaks (bluer, taller z)
	_mountain_peak(-38.0, -56.0, 32.0, 24.0, 8.0, 10, Color(0.33, 0.32, 0.38)) # blue-grey
	_mountain_peak( -8.0, -58.0, 35.0, 28.0, 9.0, 10, Color(0.31, 0.30, 0.36))
	_mountain_peak( 22.0, -54.0, 30.0, 22.0, 7.0, 10, Color(0.34, 0.33, 0.39))

	# MAIN RANGE — tightly packed, strong height contrast
	# Far left shoulder
	_mountain_peak(-35.0, -46.0, 16.0, 24.0, 3.0, 7, Color(0.40, 0.36, 0.29))
	_mountain_peak(-28.0, -47.0, 18.0, 38.0, 1.5, 7, Color(0.36, 0.33, 0.27))
	# Dominant western spike
	_mountain_peak(-20.0, -48.0, 15.0, 58.0, 0.3, 6, Color(0.30, 0.27, 0.22))
	_mountain_snow(-20.0, 58.0 * 0.80, -48.0, 5.0, 1.2, 6)
	# Saddle + central peak
	_mountain_peak(-13.0, -46.0, 14.0, 32.0, 2.0, 7, Color(0.38, 0.34, 0.27))
	# DOMINANT CENTRE SPIKE — tallest, draws the eye
	_mountain_peak( -4.0, -49.0, 14.0, 72.0, 0.2, 6, Color(0.28, 0.25, 0.21))
	_mountain_snow( -4.0, 72.0 * 0.82, -49.0, 5.5, 1.3, 6)
	# Right companion ridge
	_mountain_peak(  5.0, -48.0, 16.0, 50.0, 0.5, 7, Color(0.32, 0.29, 0.24))
	_mountain_snow(  5.0, 50.0 * 0.84, -48.0, 4.0, 1.0, 7)
	_mountain_peak( 13.0, -46.0, 15.0, 36.0, 1.5, 7, Color(0.37, 0.34, 0.28))
	_mountain_peak( 20.0, -45.0, 14.0, 26.0, 2.5, 7, Color(0.40, 0.37, 0.30))
	# East shoulder — lower, plateau-like
	_mountain_peak( 27.0, -44.0, 18.0, 20.0, 4.0, 8, Color(0.42, 0.39, 0.32))
	_mountain_peak( 33.0, -43.0, 16.0, 14.0, 5.0, 8, Color(0.44, 0.41, 0.34))

func _mountain_peak(px: float, pz: float, base_r: float, height: float,
		tip_r: float, segs: int, col: Color) -> void:
	var mt    := MeshInstance3D.new()
	var mesh  := CylinderMesh.new()
	mesh.top_radius      = tip_r
	mesh.bottom_radius   = base_r
	mesh.height          = height
	mesh.radial_segments = segs
	mesh.rings           = 2
	mt.mesh     = mesh
	mt.position = Vector3(px, height / 2.0, pz)
	mt.rotation.y = rng.randf_range(0.0, PI)
	add_child(mt)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mt.set_surface_override_material(0, mat)

func _mountain_snow(px: float, py: float, pz: float,
		bot_r: float, tip_r: float, segs: int) -> void:
	var snow  := MeshInstance3D.new()
	var smesh := CylinderMesh.new()
	smesh.top_radius      = tip_r
	smesh.bottom_radius   = bot_r
	smesh.height          = 8.0
	smesh.radial_segments = segs
	smesh.rings           = 1
	snow.mesh     = smesh
	snow.position = Vector3(px, py, pz)
	snow.rotation.y = rng.randf_range(0.0, PI)
	add_child(snow)
	_set_mat(snow, mat_mountain_snow)

# ─── Trees ────────────────────────────────────────────────────────────────────

func _spawn_trees(count: int) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 5:
		attempts += 1
		var pos := _rand_pos()
		if _near_river(pos.x) or _near_origin(pos.x, pos.z) or _near_store(pos.x, pos.z):
			continue
		_place_tree(pos)
		placed += 1

func _place_tree(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position  = pos
	root.rotation.y = rng.randf_range(0.0, TAU)
	add_child(root)

	var trunk_h  := rng.randf_range(2.2, 4.5)
	var canopy_r := rng.randf_range(0.9, 1.8)
	var leaf_mat := mat_leaves if rng.randf() > 0.3 else mat_leaves_dark

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius    = 0.10
	tm.bottom_radius = 0.18
	tm.height        = trunk_h
	trunk.mesh       = tm
	trunk.position.y = trunk_h / 2.0
	root.add_child(trunk)
	_set_mat(trunk, mat_trunk)

	for i in range(2):
		var canopy := MeshInstance3D.new()
		var cm := SphereMesh.new()
		var r := canopy_r * rng.randf_range(0.75, 1.0)
		cm.radius  = r
		cm.height  = r * 1.8
		canopy.mesh     = cm
		canopy.position = Vector3(
			rng.randf_range(-0.2, 0.2),
			trunk_h + r * 0.55 + i * (r * 0.4),
			rng.randf_range(-0.2, 0.2)
		)
		root.add_child(canopy)
		_set_mat(canopy, leaf_mat)

# ─── Timber Groves ────────────────────────────────────────────────────────────

var timber_zones: Array = []   # populated for Game.gd to wire signals
var cabin_zones: Array = []    # populated for Game.gd to wire signals

func _spawn_timber_groves() -> void:
	# 3 harvestable grove clusters placed in safe areas (away from river/origin)
	var grove_positions := [
		Vector3(18.0, 0.0, -18.0),   # NE grove
		Vector3(25.0, 0.0, 12.0),    # SE grove
		Vector3(-8.0, 0.0, -22.0),   # NW grove
	]
	var grove_names := ["Pine Grove", "Oak Stand", "Cedar Thicket"]

	for i in range(grove_positions.size()):
		var center: Vector3 = grove_positions[i]
		# Spawn a tight cluster of 5 trees
		for j in range(5):
			var offset := Vector3(
				rng.randf_range(-3.0, 3.0),
				0.0,
				rng.randf_range(-3.0, 3.0)
			)
			_place_tree(center + offset)

		# Place a TimberZone Area3D over the cluster
		var zone := Area3D.new()
		zone.name = "TimberZone_%d" % i
		var script := load("res://src/world/TimberZone.gd")
		zone.set_script(script)
		zone.zone_name = grove_names[i]
		zone.position = center

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(8.0, 4.0, 8.0)
		shape.shape = box
		zone.add_child(shape)

		add_child(zone)
		timber_zones.append(zone)

# ─── Rocks ────────────────────────────────────────────────────────────────────

func _spawn_rocks(count: int) -> void:
	for i in range(count):
		var pos := _rand_pos()
		if _near_origin(pos.x, pos.z) or _near_store(pos.x, pos.z):
			continue
		_place_rock(pos, rng.randf_range(0.3, 1.2))

func _place_rock(pos: Vector3, size: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size * rng.randf_range(0.55, 0.9)
	rock.mesh       = mesh
	rock.position   = Vector3(pos.x, size * 0.12, pos.z)
	rock.rotation.y = rng.randf_range(0.0, TAU)
	rock.scale      = Vector3(
		rng.randf_range(0.8, 1.4),
		rng.randf_range(0.6, 1.0),
		rng.randf_range(0.8, 1.4)
	)
	add_child(rock)
	_set_mat(rock, mat_rock)

# ─── River Banks ──────────────────────────────────────────────────────────────

func _spawn_river_banks() -> void:
	for side in [-1, 1]:
		var bank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size     = Vector3(5.5, 0.025, 60)
		bank.mesh     = mesh
		bank.position = Vector3(RIVER_X + side * 6.5, 0.012, 0)
		add_child(bank)
		_set_mat(bank, mat_dirt)

	for i in range(18):
		var z    := rng.randf_range(-28.0, 28.0)
		var side := 1 if rng.randf() > 0.5 else -1
		var x    := RIVER_X + side * rng.randf_range(4.0, 8.5)
		_place_rock(Vector3(x, 0, z), rng.randf_range(0.2, 0.65))

# ─── Store Building ───────────────────────────────────────────────────────────

func _spawn_store_building() -> void:
	# Historically accurate 1849 California gold rush general store:
	# False front, covered porch with posts, clapboard siding, barrels, crates

	# ── Materials ──────────────────────────────────────────────────────────
	var mat_wall    := _mat(Color(0.62, 0.48, 0.30))  # weathered clapboard
	var mat_dark    := _mat(Color(0.28, 0.18, 0.10))  # dark trim / posts
	var mat_roof_sh := _mat(Color(0.32, 0.22, 0.12))  # shingles
	var mat_false   := _mat(Color(0.67, 0.52, 0.33))  # false front (slightly lighter)
	var mat_sign    := _mat(Color(0.42, 0.12, 0.08))  # dark red sign board
	var mat_sign_bg := _mat(Color(0.88, 0.78, 0.52))  # cream sign lettering bg
	var mat_door    := _mat(Color(0.20, 0.13, 0.07))  # dark door
	var mat_window  := _mat(Color(0.25, 0.32, 0.42))  # blue-grey glass
	var mat_barrel  := _mat(Color(0.38, 0.24, 0.12))  # barrel wood
	var mat_crate   := _mat(Color(0.52, 0.40, 0.22))  # crate wood
	var mat_porch   := _mat(Color(0.50, 0.38, 0.20))  # porch planks

	var CX: float = -6.0   # building centre X  (NW of spawn, facing south)
	var CZ: float = 6.4    # building centre Z  (front face at ~3.9, body extends behind false front)

	# ── 1. Main building body ──────────────────────────────────────────────
	_store_box(Vector3(CX, 1.6, CZ), Vector3(6.0, 3.2, 5.0), mat_wall)

	# ── 2. False front ─────────────────────────────────────────────────────
	# Flat panel sitting flush with front face (z = CZ-2.5 = 4.0), extends ~2m above roofline
	_store_box(Vector3(CX, 2.85, 3.88), Vector3(6.0, 5.7, 0.22), mat_false)

	# Sign board on false front (upper section)
	_store_box(Vector3(CX, 4.75, 3.76), Vector3(5.2, 0.95, 0.12), mat_sign)
	# Cream lettering background strip
	_store_box(Vector3(CX, 4.75, 3.70), Vector3(4.6, 0.55, 0.06), mat_sign_bg)

	# Sign text
	var sign_label := Label3D.new()
	sign_label.text = "Wild West Depot"
	sign_label.font_size = 72
	sign_label.position = Vector3(CX, 4.75, 3.66)
	sign_label.rotation.y = PI
	sign_label.modulate = Color(0.18, 0.08, 0.04)
	sign_label.outline_modulate = Color(0.18, 0.08, 0.04)
	sign_label.pixel_size = 0.005
	add_child(sign_label)

	# False front cap (top trim)
	_store_box(Vector3(CX, 5.78, 3.88), Vector3(6.3, 0.22, 0.30), mat_dark)

	# ── 3. Rear roof (hidden behind false front) ───────────────────────────
	var rear_roof := MeshInstance3D.new()
	var rrm       := CylinderMesh.new()
	rrm.top_radius = 0.05; rrm.bottom_radius = 3.5; rrm.height = 1.4; rrm.radial_segments = 4
	rear_roof.mesh     = rrm
	rear_roof.position = Vector3(CX, 3.9, CZ)
	rear_roof.rotation.y = PI / 4.0
	add_child(rear_roof)
	_set_mat(rear_roof, mat_roof_sh)

	# ── 4. Porch floor (raised platform) ──────────────────────────────────
	_store_box(Vector3(CX, 0.12, 2.45), Vector3(6.2, 0.24, 2.9), mat_porch)

	# Porch floor planks lines (thin dark strips for plank detail)
	for i in range(-2, 3):
		_store_box(Vector3(CX + i * 1.1, 0.25, 2.45), Vector3(0.06, 0.01, 2.9), mat_dark)

	# ── 5. Porch awning ────────────────────────────────────────────────────
	_store_box(Vector3(CX, 2.82, 2.35), Vector3(6.4, 0.16, 3.1), mat_dark)

	# ── 6. Porch posts (3 posts) ───────────────────────────────────────────
	for px in [-2.2, 0.0, 2.2]:
		var post := MeshInstance3D.new()
		var pm   := CylinderMesh.new()
		pm.top_radius = 0.09; pm.bottom_radius = 0.11; pm.height = 2.58
		post.mesh     = pm
		post.position = Vector3(CX + px, 1.41, 0.92)
		add_child(post)
		_set_mat(post, mat_dark)

	# ── 7. Steps (2 steps up to porch) ────────────────────────────────────
	_store_box(Vector3(CX, 0.05, 0.78), Vector3(2.2, 0.10, 0.38), mat_porch)
	_store_box(Vector3(CX, 0.14, 1.16), Vector3(2.2, 0.10, 0.38), mat_porch)

	# ── 8. Door frame (dark recess on front face) ──────────────────────────
	_store_box(Vector3(CX, 1.15, 3.80), Vector3(1.05, 2.30, 0.18), mat_door)

	# ── 9. Windows ─────────────────────────────────────────────────────────
	# Front window (left of door)
	_store_box(Vector3(CX - 2.0, 1.85, 3.80), Vector3(0.95, 0.85, 0.12), mat_window)
	# Side window (left wall)
	_store_box(Vector3(CX - 3.02, 1.85, CZ - 0.5), Vector3(0.10, 0.75, 0.90), mat_window)

	# ── 10. Barrels on porch (3, near left post) ───────────────────────────
	var barrel_positions := [
		Vector3(CX - 2.4, 0.52, 1.6),
		Vector3(CX - 1.7, 0.52, 1.6),
		Vector3(CX - 2.0, 1.12, 1.6),  # stacked on top
	]
	for bpos in barrel_positions:
		var bar := MeshInstance3D.new()
		var bm2 := CylinderMesh.new()
		bm2.top_radius = 0.22; bm2.bottom_radius = 0.22; bm2.height = 0.50; bm2.radial_segments = 10
		bar.mesh     = bm2
		bar.position = bpos
		add_child(bar)
		_set_mat(bar, mat_barrel)
		# Barrel rings
		var ring := MeshInstance3D.new()
		var rm2  := CylinderMesh.new()
		rm2.top_radius = 0.235; rm2.bottom_radius = 0.235; rm2.height = 0.06; rm2.radial_segments = 10
		ring.mesh     = rm2
		ring.position = bpos
		add_child(ring)
		_set_mat(ring, mat_dark)

	# ── 11. Crates near right post ─────────────────────────────────────────
	_store_box(Vector3(CX + 2.0, 0.47, 1.5), Vector3(0.50, 0.50, 0.50), mat_crate)
	_store_box(Vector3(CX + 2.0, 0.97, 1.5), Vector3(0.50, 0.50, 0.50), mat_crate)

	# Crate cross-slat detail
	_store_box(Vector3(CX + 2.0, 0.47, 1.24), Vector3(0.48, 0.06, 0.04), mat_dark)
	_store_box(Vector3(CX + 2.0, 0.97, 1.24), Vector3(0.48, 0.06, 0.04), mat_dark)

func _store_box(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size   = size
	mi.mesh   = bm
	mi.position = pos
	add_child(mi)
	_set_mat(mi, mat)

# ─── Rock Face ────────────────────────────────────────────────────────────────

func _spawn_rock_face() -> void:
	var mat_rock_face := _mat(Color(0.50, 0.46, 0.40))
	var mat_rock_dark := _mat(Color(0.36, 0.32, 0.28))

	# Rock face cluster near river bank — new position (-14, ?, 8)
	var positions := [
		Vector3(-13, 1.2,  8.0),
		Vector3(-15, 0.8,  9.2),
		Vector3(-12, 0.6,  6.8),
		Vector3(-16, 1.4,  7.5),
		Vector3(-14, 2.0,  9.8),
	]
	var scales := [
		Vector3(2.2, 2.4, 1.8),
		Vector3(1.8, 1.6, 2.0),
		Vector3(1.5, 1.2, 1.6),
		Vector3(2.0, 2.8, 1.6),
		Vector3(1.6, 3.0, 1.4),
	]
	for i in range(positions.size()):
		var rock := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size     = Vector3(1.0, 1.0, 1.0)
		rock.mesh     = mesh
		rock.position = positions[i]
		rock.scale    = scales[i]
		rock.rotation.y = rng.randf_range(-0.3, 0.3)
		add_child(rock)
		_set_mat(rock, mat_rock_face if i % 2 == 0 else mat_rock_dark)

	# Ore vein hint — gold streak on main boulder
	var vein := MeshInstance3D.new()
	var vm   := BoxMesh.new()
	vm.size       = Vector3(0.18, 2.2, 0.25)
	vein.mesh     = vm
	vein.position = Vector3(-14, 1.8, 9.5)
	vein.rotation.z = 0.15
	add_child(vein)
	_set_mat(vein, _mat(Color(0.62, 0.55, 0.20)))

# ─── Loose Earth ──────────────────────────────────────────────────────────────

func _spawn_loose_earth() -> void:
	# Dark soil patch between camp and river — shovel zone at (-8, ?, 6)
	var patch := MeshInstance3D.new()
	var mesh  := BoxMesh.new()
	mesh.size     = Vector3(5.0, 0.03, 4.0)
	patch.mesh    = mesh
	patch.position = Vector3(-8, 0.015, 6)
	add_child(patch)
	_set_mat(patch, _mat(Color(0.38, 0.26, 0.14)))

	# Small mound hint
	var mound := MeshInstance3D.new()
	var mm    := SphereMesh.new()
	mm.radius = 0.5; mm.height = 0.4
	mound.mesh     = mm
	mound.position = Vector3(3, 0.2, 2)
	mound.scale    = Vector3(2.5, 0.4, 1.8)
	add_child(mound)
	_set_mat(mound, _mat(Color(0.42, 0.30, 0.16)))

# ─── Rich Vein Markers ────────────────────────────────────────────────────────

func _spawn_rich_vein_markers() -> void:
	# Glimmering spots at the two extra pan zones in game.tscn
	# Zone 2: quality 1.5 at (-18, 0, -12) — north river spot
	# Zone 3: quality 0.7 at (-18, 0, 15)  — south river spot (shallow)
	var rich_spots := [
		{ "pos": Vector3(-18, -0.3, -12), "quality": 1.5 },
		{ "pos": Vector3(-18, -0.3,  15), "quality": 0.7 },
	]
	for spot in rich_spots:
		var q: float = float(spot.get("quality", 1.0))
		var shimmer := MeshInstance3D.new()
		var mesh   := CylinderMesh.new()
		mesh.top_radius    = 1.8
		mesh.bottom_radius = 1.8
		mesh.height        = 0.02
		mesh.radial_segments = 16
		shimmer.mesh = mesh
		shimmer.position = spot.pos
		var mat := StandardMaterial3D.new()
		if q >= 1.2:
			mat.albedo_color               = Color(1.0, 0.85, 0.1, 0.55)
			mat.emission_enabled           = true
			mat.emission                   = Color(1.0, 0.75, 0.0)
			mat.emission_energy_multiplier = 0.8
		else:
			mat.albedo_color = Color(0.55, 0.52, 0.40, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shimmer.set_surface_override_material(0, mat)
		add_child(shimmer)

# ─── Campfire Particles ───────────────────────────────────────────────────────

func _spawn_campfire_particles() -> void:
	var fire_pos := Vector3(6.5, 0.7, 10.5)

	# Fire particles
	var fire := CPUParticles3D.new()
	fire.position             = fire_pos
	fire.amount               = 20
	fire.lifetime             = 0.7
	fire.one_shot             = false
	fire.explosiveness        = 0.1
	fire.randomness           = 0.5
	fire.direction            = Vector3(0, 1, 0)
	fire.spread               = 15.0
	fire.gravity              = Vector3(0, -0.5, 0)
	fire.initial_velocity_min = 0.8
	fire.initial_velocity_max = 1.8
	fire.scale_amount_min     = 0.06
	fire.scale_amount_max     = 0.18
	fire.color                = Color(1.0, 0.45, 0.05, 0.9)
	fire.color_ramp           = _fire_gradient()
	add_child(fire)

	# Spark particles
	var sparks := CPUParticles3D.new()
	sparks.position             = fire_pos
	sparks.amount               = 8
	sparks.lifetime             = 1.2
	sparks.one_shot             = false
	sparks.explosiveness        = 0.0
	sparks.randomness           = 0.9
	sparks.direction            = Vector3(0, 1, 0)
	sparks.spread               = 25.0
	sparks.gravity              = Vector3(0.2, -0.2, 0)
	sparks.initial_velocity_min = 1.5
	sparks.initial_velocity_max = 3.5
	sparks.scale_amount_min     = 0.03
	sparks.scale_amount_max     = 0.07
	sparks.color                = Color(1.0, 0.9, 0.3, 1.0)
	add_child(sparks)

func _fire_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.6, 0.1, 0.9))
	g.add_point(0.6, Color(0.8, 0.2, 0.0, 0.5))
	g.add_point(1.0, Color(0.3, 0.1, 0.0, 0.0))
	return g

# ─── Cabin Zones ─────────────────────────────────────────────────────────────

func _spawn_cabin_zones() -> void:
	var positions := [
		Vector3(10.0, 0.0, 5.0),
		Vector3(-5.0, 0.0, 15.0),
	]
	var names := ["Hilltop Clearing", "Riverside Flat"]

	var mat_marker := StandardMaterial3D.new()
	mat_marker.albedo_color = Color(0.95, 0.85, 0.2, 0.6)
	mat_marker.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for i in range(positions.size()):
		var center: Vector3 = positions[i]

		var zone := Area3D.new()
		zone.name = "CabinZone_%d" % i
		var script := load("res://src/world/CabinZone.gd")
		zone.set_script(script)
		zone.zone_name = names[i]
		zone.position = center

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6.0, 4.0, 6.0)
		shape.shape = box
		zone.add_child(shape)

		# Yellow cylinder marker
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 2.0
		mesh.bottom_radius = 2.0
		mesh.height = 0.05
		mesh.radial_segments = 16
		marker.mesh = mesh
		marker.position = Vector3(0, 0.03, 0)
		marker.set_surface_override_material(0, mat_marker)
		zone.add_child(marker)
		zone.marker = marker

		add_child(zone)
		cabin_zones.append(zone)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _rand_pos() -> Vector3:
	return Vector3(
		rng.randf_range(-FIELD_HALF, FIELD_HALF),
		0,
		rng.randf_range(-FIELD_HALF, FIELD_HALF)
	)

func _near_river(x: float) -> bool:
	return abs(x - RIVER_X) < (RIVER_WIDTH * 0.5 + 4.0)

func _near_origin(x: float, z: float) -> bool:
	return Vector2(x, z).length() < 5.0

func _near_store(x: float, z: float) -> bool:
	# Store building spans roughly x=-9..-3, z=0..10 — keep trees well clear
	return x > -11.0 and x < -1.0 and z > -1.0 and z < 11.0
