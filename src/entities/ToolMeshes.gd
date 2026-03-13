class_name ToolMeshes

# Builds tool meshes as self-contained Node3D objects that can be
# attached/detached from the player's hand.

static func create(tool_id: String) -> Node3D:
	match tool_id:
		"pan", "pan_upgraded":
			return _build_pan()
		"axe":
			return _build_axe()
		"shovel":
			return _build_shovel()
		"pickaxe":
			return _build_pickaxe()
		"sluice_box":
			return _build_sluice()
		_:
			return _build_pan()

# ─── Gold Pan ────────────────────────────────────────────────────────────────

static func _build_pan() -> Node3D:
	var root := Node3D.new()
	root.name = "Pan"

	var mat_tin := StandardMaterial3D.new()
	mat_tin.albedo_color = Color(0.48, 0.44, 0.40)
	mat_tin.metallic     = 0.55
	mat_tin.roughness    = 0.50

	var mat_inner := StandardMaterial3D.new()
	mat_inner.albedo_color = Color(0.38, 0.32, 0.26)
	mat_inner.metallic     = 0.4
	mat_inner.roughness    = 0.65

	var mat_rim := StandardMaterial3D.new()
	mat_rim.albedo_color = Color(0.42, 0.38, 0.34)
	mat_rim.metallic     = 0.6
	mat_rim.roughness    = 0.40

	# Outer bowl — wide shallow dish, sloped sides
	var bowl := MeshInstance3D.new()
	var bm   := CylinderMesh.new()
	bm.top_radius = 0.28; bm.bottom_radius = 0.15; bm.height = 0.09
	bm.radial_segments = 16
	bowl.mesh = bm
	root.add_child(bowl)
	bowl.set_surface_override_material(0, mat_tin)

	# Inner floor — flat dark bottom
	var floor_mi := MeshInstance3D.new()
	var fm       := CylinderMesh.new()
	fm.top_radius = 0.14; fm.bottom_radius = 0.14; fm.height = 0.015
	fm.radial_segments = 16
	floor_mi.mesh     = fm
	floor_mi.position = Vector3(0, 0.01, 0)
	root.add_child(floor_mi)
	floor_mi.set_surface_override_material(0, mat_inner)

	# Rolled rim — thin ring at the top lip
	var rim := MeshInstance3D.new()
	var rim_m := TorusMesh.new()
	rim_m.inner_radius = 0.27; rim_m.outer_radius = 0.29
	rim_m.rings = 12; rim_m.ring_segments = 8
	rim.mesh     = rim_m
	rim.position = Vector3(0, 0.04, 0)
	root.add_child(rim)
	rim.set_surface_override_material(0, mat_rim)

	return root

# ─── Axe ─────────────────────────────────────────────────────────────────────

static func _build_axe() -> Node3D:
	var root := Node3D.new()
	root.name = "Axe"

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.45, 0.42, 0.38)
	mat_metal.metallic     = 0.6
	mat_metal.roughness    = 0.40

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.45, 0.30, 0.15)
	mat_wood.roughness    = 0.75

	# Handle — wooden shaft
	var handle := MeshInstance3D.new()
	var hm     := CylinderMesh.new()
	hm.top_radius = 0.022; hm.bottom_radius = 0.028; hm.height = 0.6
	hm.radial_segments = 8
	handle.mesh = hm
	handle.position = Vector3(0, 0.1, 0)
	root.add_child(handle)
	handle.set_surface_override_material(0, mat_wood)

	# Axe head — wedge shape
	var head := MeshInstance3D.new()
	var hdm  := BoxMesh.new()
	hdm.size = Vector3(0.18, 0.12, 0.04)
	head.mesh = hdm
	head.position = Vector3(0.1, 0.40, 0)
	root.add_child(head)
	head.set_surface_override_material(0, mat_metal)

	# Blade edge — thin tapered piece
	var blade := MeshInstance3D.new()
	var blm   := BoxMesh.new()
	blm.size = Vector3(0.04, 0.14, 0.02)
	blade.mesh = blm
	blade.position = Vector3(0.20, 0.40, 0)
	root.add_child(blade)
	blade.set_surface_override_material(0, mat_metal)

	return root

# ─── Shovel ──────────────────────────────────────────────────────────────────

static func _build_shovel() -> Node3D:
	var root := Node3D.new()
	root.name = "Shovel"

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.45, 0.42, 0.38)
	mat_metal.metallic     = 0.6
	mat_metal.roughness    = 0.45

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.45, 0.30, 0.15)
	mat_wood.roughness    = 0.75

	# Handle — long wooden shaft
	var handle := MeshInstance3D.new()
	var hm     := CylinderMesh.new()
	hm.top_radius = 0.025; hm.bottom_radius = 0.03; hm.height = 0.7
	hm.radial_segments = 8
	handle.mesh = hm
	handle.position = Vector3(0, 0.15, 0)
	root.add_child(handle)
	handle.set_surface_override_material(0, mat_wood)

	# Blade — flat rounded scoop
	var blade := MeshInstance3D.new()
	var blm   := CylinderMesh.new()
	blm.top_radius = 0.10; blm.bottom_radius = 0.08; blm.height = 0.02
	blm.radial_segments = 8
	blade.mesh = blm
	blade.position = Vector3(0, -0.21, 0)
	blade.rotation.x = 0.3
	root.add_child(blade)
	blade.set_surface_override_material(0, mat_metal)

	return root

# ─── Pickaxe ─────────────────────────────────────────────────────────────────

static func _build_pickaxe() -> Node3D:
	var root := Node3D.new()
	root.name = "Pickaxe"

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.40, 0.38, 0.35)
	mat_metal.metallic     = 0.65
	mat_metal.roughness    = 0.40

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.42, 0.28, 0.14)
	mat_wood.roughness    = 0.75

	# Handle
	var handle := MeshInstance3D.new()
	var hm     := CylinderMesh.new()
	hm.top_radius = 0.025; hm.bottom_radius = 0.03; hm.height = 0.65
	hm.radial_segments = 8
	handle.mesh = hm
	handle.position = Vector3(0, 0.1, 0)
	root.add_child(handle)
	handle.set_surface_override_material(0, mat_wood)

	# Head — horizontal cross-piece
	var head := MeshInstance3D.new()
	var hdm  := BoxMesh.new()
	hdm.size = Vector3(0.32, 0.04, 0.04)
	head.mesh = hdm
	head.position = Vector3(0, 0.43, 0)
	root.add_child(head)
	head.set_surface_override_material(0, mat_metal)

	# Pick point — tapered end
	var point := MeshInstance3D.new()
	var pm    := CylinderMesh.new()
	pm.top_radius = 0.005; pm.bottom_radius = 0.02; pm.height = 0.12
	pm.radial_segments = 6
	point.mesh = pm
	point.position = Vector3(0.22, 0.43, 0)
	point.rotation.z = PI / 2.0
	root.add_child(point)
	point.set_surface_override_material(0, mat_metal)

	return root

# ─── Sluice Box ──────────────────────────────────────────────────────────────

static func _build_sluice() -> Node3D:
	var root := Node3D.new()
	root.name = "SluiceBox"

	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.45, 0.32, 0.16)
	mat_wood.roughness    = 0.80

	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.50, 0.46, 0.40)
	mat_metal.metallic     = 0.4
	mat_metal.roughness    = 0.55

	# Trough — long narrow box
	var trough := MeshInstance3D.new()
	var tm     := BoxMesh.new()
	tm.size = Vector3(0.14, 0.06, 0.50)
	trough.mesh = tm
	trough.position = Vector3(0, 0.0, 0.05)
	trough.rotation.x = -0.2
	root.add_child(trough)
	trough.set_surface_override_material(0, mat_wood)

	# Riffle bars — small cross-pieces inside
	for i in range(4):
		var bar := MeshInstance3D.new()
		var barm := BoxMesh.new()
		barm.size = Vector3(0.12, 0.02, 0.015)
		bar.mesh = barm
		bar.position = Vector3(0, 0.035, -0.10 + i * 0.10)
		bar.rotation.x = -0.2
		root.add_child(bar)
		bar.set_surface_override_material(0, mat_metal)

	return root
