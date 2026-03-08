extends Node

# Central audio manager — load once, play anywhere

var _players: Dictionary = {}

const SOUNDS := {
	"gold_chime":    "res://assets/audio/gold_chime.wav",
	"gold_big":      "res://assets/audio/gold_chime_big.wav",
	"lucky_fanfare": "res://assets/audio/lucky_fanfare.wav",
	"ui_click":      "res://assets/audio/ui_click.wav",
	"mining_hit":    "res://assets/audio/mining_hit.wav",
}

func _ready() -> void:
	for key in SOUNDS:
		var player := AudioStreamPlayer.new()
		var stream := load(SOUNDS[key])
		if stream:
			player.stream    = stream
			player.volume_db = -6.0
			add_child(player)
			_players[key] = player

func play(sound: String, volume_db: float = -6.0) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p:
		p.volume_db = volume_db
		p.play()

func set_master_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db)
