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
	_spawn_rocks(30)
	_spawn_river_banks()

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

	# ── Tent — pyramid shape (radial_segments=4 = 4 triangular faces)
	var tent := MeshInstance3D.new()
	var tm   := CylinderMesh.new()
	tm.top_radius      = 0.08
	tm.bottom_radius   = 2.2
	tm.height          = 2.6
	tm.radial_segments = 4
	tm.rings           = 1
	tent.mesh     = tm
	tent.position = Vector3(6, 1.3, 5)
	tent.rotation.y = PI / 4.0
	add_child(tent)
	_set_mat(tent, mat_canvas)

	# Tent door — dark opening hint (small flat box)
	var door := MeshInstance3D.new()
	var dm   := BoxMesh.new()
	dm.size       = Vector3(0.9, 1.2, 0.05)
	door.mesh     = dm
	door.position = Vector3(6, 0.6, 3.02)
	add_child(door)
	_set_mat(door, _mat(Color(0.28, 0.18, 0.08)))

	# ── Campfire
	var fire_pos := Vector3(2.5, 0, 7)

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
	var peaks = [
		{ "pos": Vector3(-55, 0, -62), "w": 24.0, "h": 30.0 },
		{ "pos": Vector3(-22, 0, -68), "w": 28.0, "h": 38.0 },
		{ "pos": Vector3( 12, 0, -65), "w": 22.0, "h": 32.0 },
		{ "pos": Vector3( 44, 0, -60), "w": 20.0, "h": 26.0 },
		{ "pos": Vector3( 68, 0, -55), "w": 16.0, "h": 22.0 },
	]
	for p in peaks:
		var mt := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius      = 0.4
		mesh.bottom_radius   = p.w / 2.0
		mesh.height          = p.h
		mesh.radial_segments = 6
		mesh.rings           = 1
		mt.mesh     = mesh
		mt.position = p.pos + Vector3(0, p.h / 2.0, 0)
		add_child(mt)
		_set_mat(mt, mat_mountain)

		var snow := MeshInstance3D.new()
		var smesh := CylinderMesh.new()
		smesh.top_radius      = 0.2
		smesh.bottom_radius   = p.w * 0.18
		smesh.height          = p.h * 0.28
		smesh.radial_segments = 6
		smesh.rings           = 1
		snow.mesh     = smesh
		snow.position = p.pos + Vector3(0, p.h * 0.90, 0)
		add_child(snow)
		_set_mat(snow, mat_mountain_snow)

# ─── Trees ────────────────────────────────────────────────────────────────────

func _spawn_trees(count: int) -> void:
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 5:
		attempts += 1
		var pos := _rand_pos()
		if _near_river(pos.x) or _near_origin(pos.x, pos.z):
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

# ─── Rocks ────────────────────────────────────────────────────────────────────

func _spawn_rocks(count: int) -> void:
	for i in range(count):
		var pos := _rand_pos()
		if _near_origin(pos.x, pos.z):
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
	var mat_wall  := _mat(Color(0.55, 0.40, 0.22))   # weathered wood
	var mat_roof  := _mat(Color(0.30, 0.18, 0.10))   # dark shingles
	var mat_sign  := _mat(Color(0.75, 0.62, 0.35))   # sign board

	# Main body
	var body := MeshInstance3D.new()
	var bm   := BoxMesh.new()
	bm.size       = Vector3(4.0, 3.0, 3.5)
	body.mesh     = bm
	body.position = Vector3(-7, 1.5, 6)
	add_child(body)
	_set_mat(body, mat_wall)

	# Roof
	var roof := MeshInstance3D.new()
	var rm   := CylinderMesh.new()
	rm.top_radius = 0.1; rm.bottom_radius = 3.2; rm.height = 1.6; rm.radial_segments = 4
	roof.mesh     = rm
	roof.position = Vector3(-7, 3.8, 6)
	roof.rotation.y = PI / 4.0
	add_child(roof)
	_set_mat(roof, mat_roof)

	# Sign board above door
	var sign := MeshInstance3D.new()
	var sm   := BoxMesh.new()
	sm.size       = Vector3(2.2, 0.5, 0.12)
	sign.mesh     = sm
	sign.position = Vector3(-7, 2.9, 4.23)
	add_child(sign)
	_set_mat(sign, mat_sign)

	# Porch posts
	for side in [-1, 1]:
		var post := MeshInstance3D.new()
		var pm   := CylinderMesh.new()
		pm.top_radius = 0.08; pm.bottom_radius = 0.10; pm.height = 2.4
		post.mesh     = pm
		post.position = Vector3(-7 + side * 1.5, 1.2, 4.0)
		add_child(post)
		_set_mat(post, mat_roof)

# ─── Rock Face ────────────────────────────────────────────────────────────────

func _spawn_rock_face() -> void:
	var mat_rock_face := _mat(Color(0.50, 0.46, 0.40))
	var mat_rock_dark := _mat(Color(0.36, 0.32, 0.28))

	# Main cliff face — cluster of large boulders near river right side
	var positions := [
		Vector3(-10, 1.2, -8),
		Vector3(-12, 0.8, -6),
		Vector3(-9,  0.6, -10),
		Vector3(-13, 1.4, -9),
		Vector3(-11, 2.0, -7),
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

	# Ore vein hint — dark stripe on main boulder
	var vein := MeshInstance3D.new()
	var vm   := BoxMesh.new()
	vm.size       = Vector3(0.18, 2.2, 0.25)
	vein.mesh     = vm
	vein.position = Vector3(-11, 1.8, -6.8)
	vein.rotation.z = 0.15
	add_child(vein)
	_set_mat(vein, _mat(Color(0.62, 0.55, 0.20)))  # gold tint

# ─── Loose Earth ──────────────────────────────────────────────────────────────

func _spawn_loose_earth() -> void:
	# Dark soil patch between camp and river — shovel zone
	var patch := MeshInstance3D.new()
	var mesh  := BoxMesh.new()
	mesh.size     = Vector3(5.0, 0.03, 4.0)
	patch.mesh    = mesh
	patch.position = Vector3(3, 0.015, 2)
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
