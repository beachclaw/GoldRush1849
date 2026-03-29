extends Area3D

# Generic mining zone — replaces PanZone
# tool_type determines what tool the player auto-equips on entry

enum ToolType { PAN, PICKAXE, SHOVEL, SLUICE }

@export var zone_name:   String   = "American River"
@export var tool_type:   ToolType = ToolType.PAN
@export var quality:     float    = 1.0   # yield multiplier

signal player_entered(zone)
signal player_exited(zone)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_tool_id() -> String:
	match tool_type:
		ToolType.PAN:     return "pan"
		ToolType.PICKAXE: return "pickaxe"
		ToolType.SHOVEL:  return "shovel"
		ToolType.SLUICE:  return "sluice_box"
	return "pan"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.enter_mining_zone(self)
		player_entered.emit(self)
	# Workers handle their own zone logic via commands, no signal needed

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.exit_mining_zone()
		player_exited.emit(self)
