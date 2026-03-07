extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Subtle background color
	RenderingServer.set_default_clear_color(Color(0.10, 0.08, 0.05))

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
