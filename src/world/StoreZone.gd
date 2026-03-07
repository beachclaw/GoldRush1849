extends Area3D

signal player_entered
signal player_exited

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_entered.emit()

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_exited.emit()
