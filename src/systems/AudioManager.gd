extends Node

# Central audio manager.
# - One-shot SFX: AudioStreamPlayer (non-positional), played via Audio.play()
# - Spatial ambient: AudioStreamPlayer3D nodes spawned at world positions,
#   looping continuously, managed via Audio.start_ambient() / stop_ambient()

# ── One-shot SFX ──────────────────────────────────────────────────────────────
const SOUNDS := {
	"gold_chime":    "res://assets/audio/gold_chime.wav",
	"gold_big":      "res://assets/audio/gold_chime_big.wav",
	"lucky_fanfare": "res://assets/audio/lucky_fanfare.wav",
	"ui_click":      "res://assets/audio/ui_click.wav",
	"mining_hit":    "res://assets/audio/mining_hit.wav",
	"pan_splash":    "res://assets/audio/pan_splash.wav",
	"footstep":      "res://assets/audio/footstep.wav",
	"wood_chop":     "res://assets/audio/wood_chop.wav",
	"wood_collect":  "res://assets/audio/wood_collect.wav",
}

# ── Ambient loops ─────────────────────────────────────────────────────────────
const AMBIENT := {
	"river":   "res://assets/audio/river_flow.wav",
	"fire":    "res://assets/audio/fire_crackle.wav",
}

var _players:  Dictionary = {}   # String → AudioStreamPlayer
var _ambients: Dictionary = {}   # String → AudioStreamPlayer3D

# Footstep timing
var _step_timer:    float = 0.0
var _step_interval: float = 0.42   # seconds between steps
var _player_moving: bool  = false

func _ready() -> void:
	# Load one-shot SFX players
	for key in SOUNDS:
		var stream = load(SOUNDS[key])
		if not stream:
			continue
		var p := AudioStreamPlayer.new()
		p.stream    = stream
		p.volume_db = -6.0
		add_child(p)
		_players[key] = p

func play(sound: String, volume_db: float = -6.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p:
		p.volume_db = volume_db
		p.play()

# ── Spatial ambient ───────────────────────────────────────────────────────────

## Spawn a looping spatial audio emitter at world_pos.
## Call once after game world is ready (e.g. from Game._ready).
func start_ambient(id: String, world_pos: Vector3,
		volume_db: float = -12.0,
		max_dist: float   = 30.0) -> void:
	if _ambients.has(id):
		return
	var stream = load(AMBIENT.get(id, ""))
	if not stream:
		push_warning("AudioManager: ambient '%s' not found" % id)
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var p3 := AudioStreamPlayer3D.new()
	p3.stream             = stream
	p3.volume_db          = volume_db
	p3.max_distance       = max_dist
	p3.attenuation_model  = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
	p3.position           = world_pos
	add_child(p3)
	p3.play()
	_ambients[id] = p3

func stop_ambient(id: String) -> void:
	if _ambients.has(id):
		_ambients[id].stop()
		_ambients[id].queue_free()
		_ambients.erase(id)

func set_ambient_volume(id: String, volume_db: float) -> void:
	if _ambients.has(id):
		_ambients[id].volume_db = volume_db

# ── Footsteps ─────────────────────────────────────────────────────────────────

## Call every frame from Game or Player with whether the player is walking.
func update_footsteps(moving: bool, delta: float) -> void:
	_player_moving = moving
	if not moving:
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = _step_interval
		play("footstep", randf_range(-18.0, -14.0))

# ── Master volume ─────────────────────────────────────────────────────────────
func set_master_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
