extends Node

# Cycles the sun through a ~10-minute arc: golden morning → warm noon → cool afternoon.
# Drives DirectionalLight3D colour + energy and sky ambient tint.

const CYCLE_SECONDS := 600.0   # one full day in real seconds

# Key-frame times (0.0 = dawn, 0.5 = noon, 1.0 = dusk)
const KEYFRAMES := [
	{ "t": 0.00, "angle_x": -0.60, "angle_y":  0.30,
	  "color": Color(1.00, 0.72, 0.38), "energy": 0.6 },   # dawn — low, orange
	{ "t": 0.20, "angle_x": -0.80, "angle_y":  0.20,
	  "color": Color(1.00, 0.90, 0.72), "energy": 1.2 },   # mid-morning
	{ "t": 0.45, "angle_x": -1.25, "angle_y":  0.05,
	  "color": Color(1.00, 0.96, 0.88), "energy": 1.6 },   # near-noon — bright white
	{ "t": 0.65, "angle_x": -0.90, "angle_y": -0.15,
	  "color": Color(0.95, 0.88, 0.78), "energy": 1.3 },   # afternoon — slight warm drop
	{ "t": 0.85, "angle_x": -0.55, "angle_y": -0.35,
	  "color": Color(1.00, 0.65, 0.30), "energy": 0.8 },   # late afternoon — golden hour
	{ "t": 1.00, "angle_x": -0.40, "angle_y": -0.50,
	  "color": Color(0.90, 0.45, 0.20), "energy": 0.4 },   # dusk — red-orange
]

var _day_time := 0.25          # start at mid-morning
var _sun: DirectionalLight3D = null

func _ready() -> void:
	# Find the DirectionalLight3D in the scene
	await get_tree().process_frame
	var hits := get_tree().get_nodes_in_group("sun")
	if hits.size() > 0:
		_sun = hits[0]
	else:
		# Fall back — search parent tree
		_sun = _find_sun(get_tree().root)

func _process(delta: float) -> void:
	if not _sun:
		return
	_day_time = fmod(_day_time + delta / CYCLE_SECONDS, 1.0)
	_apply_keyframe(_day_time)

func _apply_keyframe(t: float) -> void:
	# Find the two surrounding keyframes and lerp between them
	var a: Dictionary = KEYFRAMES[0]
	var b: Dictionary = KEYFRAMES[KEYFRAMES.size() - 1]
	for i in range(KEYFRAMES.size() - 1):
		if t >= float(KEYFRAMES[i].t) and t <= float(KEYFRAMES[i + 1].t):
			a = KEYFRAMES[i]
			b = KEYFRAMES[i + 1]
			break
	var span: float = float(b.t) - float(a.t)
	var local_t: float = 0.0 if span <= 0.0 else (t - float(a.t)) / span
	var f := smoothstep(0.0, 1.0, local_t)

	# Interpolate light direction angles
	var ax: float = lerpf(float(a.angle_x), float(b.angle_x), f)
	var ay: float = lerpf(float(a.angle_y), float(b.angle_y), f)
	_sun.rotation.x = ax
	_sun.rotation.y = ay

	# Interpolate light colour + energy
	_sun.light_color  = (a.color as Color).lerp(b.color, f)
	_sun.light_energy = lerpf(float(a.energy), float(b.energy), f)

func _find_sun(node: Node) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node as DirectionalLight3D
	for child in node.get_children():
		var found := _find_sun(child)
		if found:
			return found
	return null
