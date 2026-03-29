extends CanvasLayer

const SETTINGS_SCENE := preload("res://scenes/ui/settings_menu.tscn")

signal resumed
signal quit_to_menu

func _ready() -> void:
	visible = false

func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close() -> void:
	visible = false
	get_tree().paused = false
	# Keep mouse visible for RTS mode; third-person mode recaptures via CameraController
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resumed.emit()

func _on_resume_pressed() -> void:
	close()

func _on_save_pressed() -> void:
	SaveManager.save()
	# brief visual feedback handled by button text change
	var btn := $Panel/VBox/SaveBtn as Button
	btn.text = "Saved!"
	await get_tree().create_timer(1.2).timeout
	btn.text = "Save Game"

func _on_settings_pressed() -> void:
	var s := SETTINGS_SCENE.instantiate()
	# Wire the Back button from inside the settings scene
	s.get_node("Panel/VBox/BackBtn").pressed.connect(s.queue_free)
	add_child(s)

func _on_restart_pressed() -> void:
	SaveManager.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/rts_main.tscn")

func _on_quit_pressed() -> void:
	SaveManager.save()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	quit_to_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
