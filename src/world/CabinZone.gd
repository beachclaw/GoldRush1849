extends Area3D

# Cabin placement zone — marks valid flat spots where the player can place a cabin.
# Player enters with cabin_kit in inventory, presses SPACE to place.

@export var zone_name: String = "Building Site"

signal player_entered(zone)
signal player_exited(zone)

var marker: MeshInstance3D = null   # yellow cylinder marker, swapped to cabin on place

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_cabin_zone(self)
		player_entered.emit(self)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_cabin_zone()
		player_exited.emit(self)
