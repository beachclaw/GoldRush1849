extends Control

const LOADING_SCENE := preload("res://scenes/ui/loading_screen.tscn")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RenderingServer.set_default_clear_color(Color(0.10, 0.08, 0.05))

func _on_play_pressed() -> void:
	# Spawn loading overlay, then change scene after one frame so overlay renders first
	var loading := LOADING_SCENE.instantiate()
	get_tree().root.add_child(loading)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
