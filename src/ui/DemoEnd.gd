extends CanvasLayer

@onready var stats_label: Label = $Panel/VBox/Stats

func _ready() -> void:
	visible = false

func show_end(gold: float) -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	stats_label.text = "Gold collected: %.2fg\n\nYou've staked your claim on the\nAmerican River. The rush has only begun." % gold

func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
