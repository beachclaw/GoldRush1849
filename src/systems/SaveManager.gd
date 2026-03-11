extends Node

const SAVE_PATH := "user://save.json"

var data: Dictionary = {
	"gold_dust":       0.0,
	"timber":          0,
	"unlocked_tools":  ["pan"],
	"camp_level":      0,      # 0 = tent, 1 = cabin
	"playtime":        0.0,
	"cabin_kit":       false,
	"cabin_placed":    false,
}

signal gold_changed(new_amount: float)
signal timber_changed(new_amount: int)
signal tool_unlocked(tool_id: String)
signal cabin_kit_changed(has_kit: bool)
signal cabin_placed_changed(placed: bool)

func _ready() -> void:
	load_save()

# ─── Gold ─────────────────────────────────────────────────────────────────────

func add_gold(amount: float) -> void:
	data.gold_dust = snappedf(data.gold_dust + amount, 0.01)
	gold_changed.emit(data.gold_dust)
	_check_unlocks()
	save()

func spend_gold(amount: float) -> bool:
	if data.gold_dust < amount:
		return false
	data.gold_dust = snappedf(data.gold_dust - amount, 0.01)
	gold_changed.emit(data.gold_dust)
	save()
	return true

func get_gold() -> float:
	return data.gold_dust

# ─── Timber ──────────────────────────────────────────────────────────────────

func add_timber(amount: int = 1) -> void:
	data.timber = int(data.timber) + amount
	timber_changed.emit(int(data.timber))
	save()

func spend_timber(amount: int) -> bool:
	if int(data.timber) < amount:
		return false
	data.timber = int(data.timber) - amount
	timber_changed.emit(int(data.timber))
	save()
	return true

func get_timber() -> int:
	return int(data.timber)

# ─── Tools ────────────────────────────────────────────────────────────────────

func has_tool(tool_id: String) -> bool:
	return tool_id in data.unlocked_tools

func unlock_tool(tool_id: String) -> void:
	if not has_tool(tool_id):
		data.unlocked_tools.append(tool_id)
		tool_unlocked.emit(tool_id)
		save()

# ─── Auto-unlocks at gold thresholds ──────────────────────────────────────────

var _unlock_thresholds: Dictionary = {
	15.0:  "shovel",
	20.0:  "pickaxe",
	50.0:  "sluice_box",
}
var _announced: Dictionary = {}

func _check_unlocks() -> void:
	for threshold in _unlock_thresholds:
		if data.gold_dust >= float(threshold) and not _announced.get(threshold, false):
			_announced[threshold] = true
			var tool_id: String = str(_unlock_thresholds[threshold])
			# Just signal availability — player still needs to buy from store
			tool_unlocked.emit(tool_id + "_available")

# ─── Cabin Kit ───────────────────────────────────────────────────────────────

func give_cabin_kit() -> void:
	data.cabin_kit = true
	cabin_kit_changed.emit(true)
	save()

func has_cabin_kit() -> bool:
	return bool(data.get("cabin_kit", false))

func place_cabin() -> void:
	data.cabin_kit = false
	data.cabin_placed = true
	data.camp_level = 1
	cabin_kit_changed.emit(false)
	cabin_placed_changed.emit(true)
	save()

func has_cabin() -> bool:
	return bool(data.get("cabin_placed", false))

# ─── Camp ─────────────────────────────────────────────────────────────────────

func set_camp_level(level: int) -> void:
	data.camp_level = level
	save()

# ─── Persistence ──────────────────────────────────────────────────────────────

func save() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		for key in parsed:
			data[key] = parsed[key]
		return true
	return false

func reset() -> void:
	data = {
		"gold_dust":      0.0,
		"timber":         0,
		"unlocked_tools": ["pan"],
		"camp_level":     0,
		"playtime":       0.0,
		"cabin_kit":      false,
		"cabin_placed":   false,
	}
	save()
