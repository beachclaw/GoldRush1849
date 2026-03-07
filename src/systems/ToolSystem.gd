extends Node

# Central tool registry — stats, yields, unlock costs

const TOOLS: Dictionary = {
	"pan": {
		"name":         "Gold Pan",
		"icon":         "🪣",
		"yield_min":    0.3,
		"yield_max":    2.5,
		"lucky_chance": 0.05,
		"lucky_mult":   5.0,
		"action_time":  2.0,
		"unlock_cost":  0,
	},
	"pickaxe": {
		"name":         "Pickaxe",
		"icon":         "⛏️",
		"yield_min":    0.8,
		"yield_max":    4.0,
		"lucky_chance": 0.03,
		"lucky_mult":   4.0,
		"action_time":  3.0,
		"unlock_cost":  20,
	},
	"shovel": {
		"name":         "Shovel",
		"icon":         "🪏",
		"yield_min":    0.2,
		"yield_max":    1.5,
		"lucky_chance": 0.01,
		"lucky_mult":   3.0,
		"action_time":  1.5,
		"unlock_cost":  15,
	},
	"sluice_box": {
		"name":         "Sluice Box",
		"icon":         "🏗️",
		"yield_min":    1.5,
		"yield_max":    6.0,
		"lucky_chance": 0.08,
		"lucky_mult":   4.0,
		"action_time":  4.0,
		"unlock_cost":  50,
	},
}

func calculate_yield(tool_id: String, quality: float = 1.0) -> Dictionary:
	var tool: Dictionary = TOOLS.get(tool_id, TOOLS["pan"])
	var base: float      = randf_range(float(tool.get("yield_min", 0.3)), float(tool.get("yield_max", 2.5))) * quality
	var lucky: bool      = randf() < float(tool.get("lucky_chance", 0.05))
	if lucky:
		base *= float(tool.get("lucky_mult", 5.0))
	return { "amount": snappedf(base, 0.01), "lucky": lucky }

func get_action_time(tool_id: String) -> float:
	var tool: Dictionary = TOOLS.get(tool_id, TOOLS["pan"])
	return float(tool.get("action_time", 2.0))

func get_display(tool_id: String) -> String:
	var tool: Dictionary = TOOLS.get(tool_id, TOOLS["pan"])
	return str(tool.get("icon", "")) + "  " + str(tool.get("name", tool_id))

func get_unlock_cost(tool_id: String) -> float:
	var tool: Dictionary = TOOLS.get(tool_id, {})
	return float(tool.get("unlock_cost", 999))
