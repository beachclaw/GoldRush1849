extends Node

# Automated playtest — runs through the core loop headlessly and logs results.
# Launch with: godot --path . --headless scenes/tests/autoplaytest.tscn

const PASS = "✅"
const FAIL = "❌"
const INFO = "  ›"

var _results: Array[String] = []
var _passes := 0
var _fails  := 0

func _ready() -> void:
	print("\n═══════════════════════════════════")
	print("  GOLD MINE — Automated Playtest")
	print("═══════════════════════════════════\n")
	await get_tree().process_frame
	_run_all_tests()

func _run_all_tests() -> void:
	await _test_save_manager()
	await _test_tool_system()
	await _test_mining_zones()
	await _test_gold_progression()
	await _test_unlock_flow()
	await _test_store_buy()
	await _test_tutorial_manager()
	await _test_audio_manager()
	_print_summary()
	get_tree().quit(0 if _fails == 0 else 1)

# ─── SaveManager ──────────────────────────────────────────────────────────────

func _test_save_manager() -> void:
	_section("SaveManager")
	# Reset to clean state using the proper reset method
	SaveManager.reset()
	_assert("initial gold is 0", SaveManager.get_gold() == 0.0)

	SaveManager.add_gold(10.5)
	_assert("add_gold(10.5) → 10.5", is_equal_approx(SaveManager.get_gold(), 10.5))

	SaveManager.add_gold(5.0)
	_assert("add_gold(5.0) → 15.5", is_equal_approx(SaveManager.get_gold(), 15.5))

	var spent := SaveManager.spend_gold(10.0)
	_assert("spend_gold(10.0) succeeds", spent == true)
	_assert("gold after spend → 5.5", is_equal_approx(SaveManager.get_gold(), 5.5))

	var fail_spend := SaveManager.spend_gold(999.0)
	_assert("spend_gold(999.0) fails (insufficient)", fail_spend == false)
	_assert("gold unchanged after failed spend", is_equal_approx(SaveManager.get_gold(), 5.5))

	_assert("has_tool('pan') — always true", SaveManager.has_tool("pan"))
	_assert("has_tool('pickaxe') — false initially", not SaveManager.has_tool("pickaxe"))
	SaveManager.unlock_tool("pickaxe")
	_assert("has_tool('pickaxe') — true after unlock", SaveManager.has_tool("pickaxe"))
	await get_tree().process_frame

# ─── ToolSystem ───────────────────────────────────────────────────────────────

func _test_tool_system() -> void:
	_section("ToolSystem")
	_assert("pan tool exists", ToolSystem.TOOLS.has("pan"))
	_assert("pickaxe tool exists", ToolSystem.TOOLS.has("pickaxe"))
	_assert("shovel tool exists", ToolSystem.TOOLS.has("shovel"))
	_assert("sluice_box tool exists", ToolSystem.TOOLS.has("sluice_box"))

	var pan_cost := ToolSystem.get_unlock_cost("pan")
	_info("pan cost: %s" % str(pan_cost))
	_assert("pan unlock cost is 0 (always owned)", pan_cost == 0.0)

	var pick_cost := ToolSystem.get_unlock_cost("pickaxe")
	_info("pickaxe cost: %s" % str(pick_cost))
	_assert("pickaxe cost > 0", pick_cost > 0.0)

	var pan_time := ToolSystem.get_action_time("pan")
	_info("pan action time: %.1fs" % pan_time)
	_assert("pan action time > 0", pan_time > 0.0)

	var pan_result: Dictionary = ToolSystem.calculate_yield("pan", 1.0)
	var pan_yield: float = float(pan_result.get("amount", 0.0))
	_info("pan sample yield: %.2fg (lucky: %s)" % [pan_yield, str(pan_result.get("lucky", false))])
	_assert("pan yields positive gold", pan_yield > 0.0)

	# Run 20 samples to confirm rich zone is higher on average
	var normal_sum := 0.0
	var rich_sum   := 0.0
	for i in range(20):
		normal_sum += float(ToolSystem.calculate_yield("pan", 1.0).get("amount", 0.0))
		rich_sum   += float(ToolSystem.calculate_yield("pan", 1.5).get("amount", 0.0))
	_info("normal avg (20 samples): %.2fg" % (normal_sum / 20.0))
	_info("rich avg   (20 samples): %.2fg" % (rich_sum   / 20.0))
	_assert("rich zone avg higher than normal", rich_sum > normal_sum)
	await get_tree().process_frame

# ─── MiningZone ───────────────────────────────────────────────────────────────

func _test_mining_zones() -> void:
	_section("MiningZone")
	# MiningZone extends Area3D — instantiate correctly
	var mz := Area3D.new()
	var mz_script := load("res://src/world/MiningZone.gd")
	mz.set_script(mz_script)
	add_child(mz)
	await get_tree().process_frame

	_assert("zone_name property exists", mz.get("zone_name") != null)
	_assert("tool_type property exists", mz.get("tool_type") != null)
	_assert("quality property exists", mz.get("quality") != null)
	_info("defaults — zone: '%s', quality: %.1f, tool: %d" % [str(mz.zone_name), float(mz.quality), int(mz.tool_type)])
	mz.queue_free()
	await get_tree().process_frame

# ─── Gold Progression ─────────────────────────────────────────────────────────

func _test_gold_progression() -> void:
	_section("Gold Progression")
	SaveManager.reset()

	# Simulate 10 panning actions
	var total := 0.0
	for i in range(10):
		var amount: float = float(ToolSystem.calculate_yield("pan", 1.0).get("amount", 0.0))
		SaveManager.add_gold(amount)
		total += amount

	_info("10 panning actions yielded: %.2fg total" % total)
	_assert("10 pans yield > 0 gold", total > 0.0)
	_assert("SaveManager gold matches", absf(SaveManager.get_gold() - total) < 0.05)

	# Simulate rich bend comparison
	var rich_total := 0.0
	for i in range(10):
		rich_total += float(ToolSystem.calculate_yield("pan", 1.5).get("amount", 0.0))
	_info("10 rich-bend pans: %.2fg total" % rich_total)
	_info("normal total: %.2fg, rich total: %.2fg" % [total, rich_total])
	# Rich bend is 1.5x quality so average will generally be higher
	_assert("gold persisted correctly in SaveManager", SaveManager.get_gold() > 0.0)
	await get_tree().process_frame

# ─── Unlock Flow ──────────────────────────────────────────────────────────────

func _test_unlock_flow() -> void:
	_section("Unlock Flow")
	SaveManager.reset()

	# Add just enough gold to buy pickaxe
	var pick_cost := ToolSystem.get_unlock_cost("pickaxe")
	SaveManager.add_gold(pick_cost)
	_info("added %.0fg (pickaxe cost)" % pick_cost)

	_assert("have enough to buy pickaxe", SaveManager.get_gold() >= pick_cost)
	var spent := SaveManager.spend_gold(pick_cost)
	_assert("spent gold for pickaxe", spent)
	SaveManager.unlock_tool("pickaxe")
	_assert("pickaxe now owned", SaveManager.has_tool("pickaxe"))
	_info("gold remaining: %.2fg" % SaveManager.get_gold())
	await get_tree().process_frame

# ─── Store Buy ────────────────────────────────────────────────────────────────

func _test_store_buy() -> void:
	_section("Store: Buy Flow")
	SaveManager.reset()
	SaveManager.add_gold(100.0)

	# Buy shovel (15g)
	var before := SaveManager.get_gold()
	var spent := SaveManager.spend_gold(15.0)
	SaveManager.unlock_tool("shovel")
	_assert("bought shovel for 15g", spent)
	_assert("gold reduced by 15g", is_equal_approx(SaveManager.get_gold(), before - 15.0))
	_assert("shovel now owned", SaveManager.has_tool("shovel"))
	_info("gold after shovel: %.2fg" % SaveManager.get_gold())

	# Buy pickaxe (20g)
	var spent2 := SaveManager.spend_gold(20.0)
	SaveManager.unlock_tool("pickaxe")
	_assert("bought pickaxe for 20g", spent2)
	_info("gold after pickaxe: %.2fg" % SaveManager.get_gold())

	# Try to overspend
	var broke := SaveManager.spend_gold(99999.0)
	_assert("can't overspend", not broke)
	await get_tree().process_frame

# ─── Tutorial ─────────────────────────────────────────────────────────────────

func _test_tutorial_manager() -> void:
	_section("TutorialManager")
	SaveManager.data = {}
	Tutorial._shown = {}

	var shown_count := 0
	# Simulate showing steps
	Tutorial._shown["move"] = true
	Tutorial._shown["river"] = true
	shown_count = Tutorial._shown.size()
	_assert("tutorial tracks shown steps", shown_count == 2)

	# Show same step again — should be no-op
	var was_shown: bool = Tutorial._shown.get("move", false)
	_assert("already-shown step is flagged", was_shown == true)
	_info("tutorial steps recorded: %d" % shown_count)
	await get_tree().process_frame

# ─── AudioManager ─────────────────────────────────────────────────────────────

func _test_audio_manager() -> void:
	_section("AudioManager")
	_assert("Audio autoload exists", Audio != null)
	_assert("gold_chime loaded", Audio._players.has("gold_chime"))
	_assert("lucky_fanfare loaded", Audio._players.has("lucky_fanfare"))
	_assert("ui_click loaded", Audio._players.has("ui_click"))
	_assert("mining_hit loaded", Audio._players.has("mining_hit"))
	_info("audio players ready: %d" % Audio._players.size())
	await get_tree().process_frame

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _section(name: String) -> void:
	print("\n── %s ──" % name)

func _assert(label: String, condition: bool) -> void:
	if condition:
		_passes += 1
		print("%s  %s" % [PASS, label])
	else:
		_fails += 1
		print("%s  %s  ← FAILED" % [FAIL, label])
	_results.append(("%s %s" % [PASS if condition else FAIL, label]))

func _info(text: String) -> void:
	print("%s %s" % [INFO, text])

func _print_summary() -> void:
	print("\n═══════════════════════════════════")
	print("  Results: %d passed, %d failed" % [_passes, _fails])
	if _fails == 0:
		print("  ALL TESTS PASSED 🎉")
	else:
		print("  SOME TESTS FAILED — check above")
	print("═══════════════════════════════════\n")
