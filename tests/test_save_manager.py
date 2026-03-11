"""
Comprehensive save/load tests for SaveManager.

Tests mirror the GDScript SaveManager (src/systems/SaveManager.gd) logic,
exercising JSON persistence round-trips for gold, timber, tools, and cabin state.
"""

import json
import os
import tempfile
import unittest


class SaveManagerSim:
    """Python simulation of SaveManager.gd for testing persistence logic."""

    DEFAULT_DATA = {
        "gold_dust": 0.0,
        "timber": 0,
        "unlocked_tools": ["pan"],
        "camp_level": 0,
        "playtime": 0.0,
    }

    def __init__(self, save_path: str):
        self.save_path = save_path
        self.data: dict = {}
        self.reset()

    # ── Gold ──────────────────────────────────────────────────────────────

    def add_gold(self, amount: float) -> None:
        self.data["gold_dust"] = round(self.data["gold_dust"] + amount, 2)
        self.save()

    def spend_gold(self, amount: float) -> bool:
        if self.data["gold_dust"] < amount:
            return False
        self.data["gold_dust"] = round(self.data["gold_dust"] - amount, 2)
        self.save()
        return True

    def get_gold(self) -> float:
        return self.data["gold_dust"]

    # ── Timber ────────────────────────────────────────────────────────────

    def add_timber(self, amount: int = 1) -> None:
        self.data["timber"] = int(self.data["timber"]) + amount
        self.save()

    def spend_timber(self, amount: int) -> bool:
        if int(self.data["timber"]) < amount:
            return False
        self.data["timber"] = int(self.data["timber"]) - amount
        self.save()
        return True

    def get_timber(self) -> int:
        return int(self.data["timber"])

    # ── Tools ─────────────────────────────────────────────────────────────

    def has_tool(self, tool_id: str) -> bool:
        return tool_id in self.data["unlocked_tools"]

    def unlock_tool(self, tool_id: str) -> None:
        if not self.has_tool(tool_id):
            self.data["unlocked_tools"].append(tool_id)
            self.save()

    # ── Camp ──────────────────────────────────────────────────────────────

    def set_camp_level(self, level: int) -> None:
        self.data["camp_level"] = level
        self.save()

    # ── Persistence ───────────────────────────────────────────────────────

    def save(self) -> None:
        with open(self.save_path, "w") as f:
            json.dump(self.data, f, indent="\t")

    def load_save(self) -> bool:
        if not os.path.exists(self.save_path):
            return False
        with open(self.save_path) as f:
            parsed = json.load(f)
        if isinstance(parsed, dict):
            for key in parsed:
                self.data[key] = parsed[key]
            return True
        return False

    def reset(self) -> None:
        self.data = {
            "gold_dust": 0.0,
            "timber": 0,
            "unlocked_tools": ["pan"],
            "camp_level": 0,
            "playtime": 0.0,
        }
        self.save()


# ═════════════════════════════════════════════════════════════════════════════
# Test Cases
# ═════════════════════════════════════════════════════════════════════════════


class SaveManagerTestBase(unittest.TestCase):
    """Base class that provides a fresh SaveManager with a temp file."""

    def setUp(self):
        self._tmp = tempfile.NamedTemporaryFile(
            suffix=".json", delete=False, prefix="save_test_"
        )
        self._tmp.close()
        self.sm = SaveManagerSim(self._tmp.name)

    def tearDown(self):
        if os.path.exists(self._tmp.name):
            os.unlink(self._tmp.name)

    def _reload(self) -> SaveManagerSim:
        """Create a fresh SaveManager that loads from the same file."""
        fresh = SaveManagerSim.__new__(SaveManagerSim)
        fresh.save_path = self._tmp.name
        fresh.data = dict(SaveManagerSim.DEFAULT_DATA)
        fresh.data["unlocked_tools"] = list(SaveManagerSim.DEFAULT_DATA["unlocked_tools"])
        fresh.load_save()
        return fresh


class TestTimberPersistence(SaveManagerTestBase):
    """1. Timber persistence — add, get, spend, and save/load round-trip."""

    def test_initial_timber_is_zero(self):
        self.assertEqual(self.sm.get_timber(), 0)

    def test_add_timber(self):
        self.sm.add_timber(5)
        self.assertEqual(self.sm.get_timber(), 5)

    def test_add_timber_default_amount(self):
        self.sm.add_timber()
        self.assertEqual(self.sm.get_timber(), 1)

    def test_add_timber_multiple(self):
        self.sm.add_timber(3)
        self.sm.add_timber(7)
        self.assertEqual(self.sm.get_timber(), 10)

    def test_spend_timber_success(self):
        self.sm.add_timber(10)
        result = self.sm.spend_timber(4)
        self.assertTrue(result)
        self.assertEqual(self.sm.get_timber(), 6)

    def test_spend_timber_exact_balance(self):
        self.sm.add_timber(5)
        result = self.sm.spend_timber(5)
        self.assertTrue(result)
        self.assertEqual(self.sm.get_timber(), 0)

    def test_timber_survives_save_load(self):
        self.sm.add_timber(42)
        reloaded = self._reload()
        self.assertEqual(reloaded.get_timber(), 42)

    def test_timber_survives_after_spend_and_reload(self):
        self.sm.add_timber(20)
        self.sm.spend_timber(7)
        reloaded = self._reload()
        self.assertEqual(reloaded.get_timber(), 13)


class TestGoldPersistence(SaveManagerTestBase):
    """2. Gold persistence — add, spend, round-trip."""

    def test_initial_gold_is_zero(self):
        self.assertAlmostEqual(self.sm.get_gold(), 0.0)

    def test_add_gold(self):
        self.sm.add_gold(10.5)
        self.assertAlmostEqual(self.sm.get_gold(), 10.5)

    def test_add_gold_accumulates(self):
        self.sm.add_gold(10.5)
        self.sm.add_gold(5.0)
        self.assertAlmostEqual(self.sm.get_gold(), 15.5)

    def test_spend_gold_success(self):
        self.sm.add_gold(20.0)
        result = self.sm.spend_gold(8.0)
        self.assertTrue(result)
        self.assertAlmostEqual(self.sm.get_gold(), 12.0)

    def test_gold_survives_save_load(self):
        self.sm.add_gold(99.9)
        reloaded = self._reload()
        self.assertAlmostEqual(reloaded.get_gold(), 99.9)

    def test_gold_spend_then_reload(self):
        self.sm.add_gold(50.0)
        self.sm.spend_gold(17.5)
        reloaded = self._reload()
        self.assertAlmostEqual(reloaded.get_gold(), 32.5)


class TestToolPersistence(SaveManagerTestBase):
    """3. Tool persistence — unlock and reload."""

    def test_pan_always_available(self):
        self.assertTrue(self.sm.has_tool("pan"))

    def test_pickaxe_not_initially_available(self):
        self.assertFalse(self.sm.has_tool("pickaxe"))

    def test_unlock_pickaxe(self):
        self.sm.unlock_tool("pickaxe")
        self.assertTrue(self.sm.has_tool("pickaxe"))

    def test_pickaxe_persists_after_reload(self):
        self.sm.unlock_tool("pickaxe")
        reloaded = self._reload()
        self.assertTrue(reloaded.has_tool("pickaxe"))

    def test_multiple_tools_persist(self):
        self.sm.unlock_tool("pickaxe")
        self.sm.unlock_tool("shovel")
        self.sm.unlock_tool("sluice_box")
        reloaded = self._reload()
        self.assertTrue(reloaded.has_tool("pan"))
        self.assertTrue(reloaded.has_tool("pickaxe"))
        self.assertTrue(reloaded.has_tool("shovel"))
        self.assertTrue(reloaded.has_tool("sluice_box"))

    def test_duplicate_unlock_is_noop(self):
        self.sm.unlock_tool("pickaxe")
        self.sm.unlock_tool("pickaxe")
        self.assertEqual(
            self.sm.data["unlocked_tools"].count("pickaxe"), 1
        )


class TestCabinState(SaveManagerTestBase):
    """4. Cabin state — camp_level persists (0=tent, 1=cabin)."""

    def test_initial_camp_level_is_zero(self):
        self.assertEqual(self.sm.data["camp_level"], 0)

    def test_set_camp_level_cabin(self):
        self.sm.set_camp_level(1)
        self.assertEqual(self.sm.data["camp_level"], 1)

    def test_camp_level_persists_after_reload(self):
        self.sm.set_camp_level(1)
        reloaded = self._reload()
        self.assertEqual(reloaded.data["camp_level"], 1)

    def test_cabin_kit_tool_persists(self):
        """cabin_kit as an unlocked tool persists through save/load."""
        self.sm.unlock_tool("cabin_kit")
        reloaded = self._reload()
        self.assertTrue(reloaded.has_tool("cabin_kit"))

    def test_cabin_placed_via_camp_level(self):
        """Cabin placement is tracked via camp_level = 1."""
        self.sm.unlock_tool("cabin_kit")
        self.sm.set_camp_level(1)  # cabin placed
        reloaded = self._reload()
        self.assertTrue(reloaded.has_tool("cabin_kit"))
        self.assertEqual(reloaded.data["camp_level"], 1)


class TestEdgeCases(SaveManagerTestBase):
    """5. Edge cases — overdraft, zero spend, negative prevention."""

    def test_spend_gold_more_than_balance_returns_false(self):
        self.sm.add_gold(5.0)
        result = self.sm.spend_gold(10.0)
        self.assertFalse(result)

    def test_gold_not_negative_after_failed_spend(self):
        self.sm.add_gold(5.0)
        self.sm.spend_gold(10.0)
        self.assertAlmostEqual(self.sm.get_gold(), 5.0)

    def test_spend_timber_more_than_balance_returns_false(self):
        self.sm.add_timber(3)
        result = self.sm.spend_timber(10)
        self.assertFalse(result)

    def test_timber_not_negative_after_failed_spend(self):
        self.sm.add_timber(3)
        self.sm.spend_timber(10)
        self.assertEqual(self.sm.get_timber(), 3)

    def test_spend_timber_zero_is_noop(self):
        self.sm.add_timber(5)
        result = self.sm.spend_timber(0)
        self.assertTrue(result)
        self.assertEqual(self.sm.get_timber(), 5)

    def test_spend_gold_zero_is_noop(self):
        self.sm.add_gold(10.0)
        result = self.sm.spend_gold(0.0)
        self.assertTrue(result)
        self.assertAlmostEqual(self.sm.get_gold(), 10.0)

    def test_spend_gold_on_zero_balance(self):
        result = self.sm.spend_gold(1.0)
        self.assertFalse(result)
        self.assertAlmostEqual(self.sm.get_gold(), 0.0)

    def test_spend_timber_on_zero_balance(self):
        result = self.sm.spend_timber(1)
        self.assertFalse(result)
        self.assertEqual(self.sm.get_timber(), 0)

    def test_reset_clears_all_state(self):
        self.sm.add_gold(100.0)
        self.sm.add_timber(50)
        self.sm.unlock_tool("pickaxe")
        self.sm.set_camp_level(1)
        self.sm.reset()
        self.assertAlmostEqual(self.sm.get_gold(), 0.0)
        self.assertEqual(self.sm.get_timber(), 0)
        self.assertFalse(self.sm.has_tool("pickaxe"))
        self.assertEqual(self.sm.data["camp_level"], 0)

    def test_full_round_trip_complex_state(self):
        """Build up complex state, save, reload, verify everything."""
        self.sm.add_gold(123.45)
        self.sm.add_timber(30)
        self.sm.spend_gold(23.45)
        self.sm.spend_timber(10)
        self.sm.unlock_tool("pickaxe")
        self.sm.unlock_tool("shovel")
        self.sm.set_camp_level(1)

        reloaded = self._reload()
        self.assertAlmostEqual(reloaded.get_gold(), 100.0)
        self.assertEqual(reloaded.get_timber(), 20)
        self.assertTrue(reloaded.has_tool("pan"))
        self.assertTrue(reloaded.has_tool("pickaxe"))
        self.assertTrue(reloaded.has_tool("shovel"))
        self.assertFalse(reloaded.has_tool("sluice_box"))
        self.assertEqual(reloaded.data["camp_level"], 1)


if __name__ == "__main__":
    unittest.main()
