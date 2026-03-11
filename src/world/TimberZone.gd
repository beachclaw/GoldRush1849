extends Area3D

# Timber harvesting zone — placed around harvestable tree clusters.
# Player chops with pickaxe: 3 hits = 1 timber log.

@export var zone_name: String = "Forest"

signal player_entered(zone)
signal player_exited(zone)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_timber_zone(self)
		player_entered.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_timber_zone()
		player_exited.emit(self)
