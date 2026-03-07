extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var pan_zone: Area3D = $World/River/PanZone

func _ready() -> void:
	# Wire up player signals to HUD
	player.gold_updated.connect(hud.update_gold)
	player.pan_started.connect(_on_pan_started)
	player.pan_finished.connect(_on_pan_finished)
	pan_zone.player_entered.connect(_on_enter_river)
	pan_zone.player_exited.connect(_on_exit_river)

func _on_enter_river(_zone) -> void:
	hud.set_prompt("Press SPACE to pan for gold")

func _on_exit_river(_zone) -> void:
	hud.set_prompt("")

func _on_pan_started() -> void:
	hud.set_prompt("Panning...")
	hud.show_panning()

func _on_pan_finished(found: float) -> void:
	hud.hide_panning()
	if found >= 5.0:
		hud.show_message("Lucky strike! Found %.2fg!" % found, 4.0)
	elif found >= 2.0:
		hud.show_message("Good find: %.2fg" % found)
	else:
		hud.show_message("Found %.2fg of gold dust" % found)
	hud.set_prompt("Press SPACE to pan for gold")
