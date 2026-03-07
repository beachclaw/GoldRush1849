extends Area3D

# A stretch of river where the player can pan for gold
# Later: different zones have different yield multipliers, rare finds, etc.

@export var zone_name: String = "American River"
@export var quality: float = 1.0  # yield multiplier — richer veins = higher value

signal player_entered(zone)
signal player_exited(zone)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_pan_zone(self)
		emit_signal("player_entered", self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_pan_zone()
		emit_signal("player_exited", self)
