"""
Tests for ToolSystem registry and tool equip/purchase behavior.

Validates tool definitions, axe for timber, store items, and
hotbar tool selection rules.
"""

import json
import os
import tempfile
import unittest


# ── Simulations matching GDScript logic ──────────────────────────────────────

TOOLS = {
    "pan": {
        "name": "Gold Pan",
        "yield_min": 0.3,
        "yield_max": 2.5,
        "lucky_chance": 0.05,
        "lucky_mult": 5.0,
        "action_time": 2.0,
        "unlock_cost": 0,
    },
    "pickaxe": {
        "name": "Pickaxe",
        "yield_min": 0.8,
        "yield_max": 4.0,
        "lucky_chance": 0.03,
        "lucky_mult": 4.0,
        "action_time": 3.0,
        "unlock_cost": 20,
    },
    "shovel": {
        "name": "Shovel",
        "yield_min": 0.2,
        "yield_max": 1.5,
        "lucky_chance": 0.01,
        "lucky_mult": 3.0,
        "action_time": 1.5,
        "unlock_cost": 15,
    },
    "sluice_box": {
        "name": "Sluice Box",
        "yield_min": 1.5,
        "yield_max": 6.0,
        "lucky_chance": 0.08,
        "lucky_mult": 4.0,
        "action_time": 4.0,
        "unlock_cost": 50,
    },
    "axe": {
        "name": "Axe",
        "yield_min": 0.0,
        "yield_max": 0.0,
        "lucky_chance": 0.0,
        "lucky_mult": 1.0,
        "action_time": 1.0,
        "unlock_cost": 10,
    },
}

STORE_ITEMS = [
    {"id": "axe",        "cost": 10},
    {"id": "shovel",     "cost": 15},
    {"id": "pickaxe",    "cost": 20},
    {"id": "better_pan", "cost": 30},
    {"id": "sluice_box", "cost": 50},
    {"id": "cabin_kit",  "cost": 100, "timber_cost": 5},
]

HOTBAR_TOOLS = ["pan", "axe", "shovel", "pickaxe", "sluice_box"]


class SaveManagerSim:
    """Minimal save manager sim for tool tests."""

    def __init__(self):
        self.data = {
            "gold_dust": 0.0,
            "timber": 0,
            "unlocked_tools": ["pan"],
        }

    def has_tool(self, tool_id: str) -> bool:
        return tool_id in self.data["unlocked_tools"]

    def unlock_tool(self, tool_id: str) -> None:
        if not self.has_tool(tool_id):
            self.data["unlocked_tools"].append(tool_id)

    def add_gold(self, amount: float) -> None:
        self.data["gold_dust"] += amount

    def get_gold(self) -> float:
        return self.data["gold_dust"]

    def spend_gold(self, amount: float) -> bool:
        if self.data["gold_dust"] < amount:
            return False
        self.data["gold_dust"] -= amount
        return True

    def get_timber(self) -> int:
        return int(self.data["timber"])

    def spend_timber(self, amount: int) -> bool:
        if int(self.data["timber"]) < amount:
            return False
        self.data["timber"] = int(self.data["timber"]) - amount
        return True


def can_select_tool(save: SaveManagerSim, tool_id: str) -> bool:
    """Mirrors HUD.select_tool guard: only pan or owned tools."""
    return tool_id == "pan" or save.has_tool(tool_id)


def can_chop(save: SaveManagerSim) -> bool:
    """Mirrors Player._start_chopping guard: requires axe."""
    return save.has_tool("axe")


def buy_store_item(save: SaveManagerSim, item_id: str) -> bool:
    """Simulate buying an item from the store."""
    for item in STORE_ITEMS:
        if item["id"] == item_id:
            cost = item["cost"]
            timber_cost = item.get("timber_cost", 0)
            if save.get_gold() < cost:
                return False
            if timber_cost > 0 and save.get_timber() < timber_cost:
                return False
            save.spend_gold(cost)
            if timber_cost > 0:
                save.spend_timber(timber_cost)
            if item_id == "cabin_kit":
                save.unlock_tool("cabin_kit")
            elif item_id == "better_pan":
                save.unlock_tool("pan_upgraded")
            else:
                save.unlock_tool(item_id)
            return True
    return False


# ═════════════════════════════════════════════════════════════════════════════
# Test Cases
# ═════════════════════════════════════════════════════════════════════════════


class TestToolRegistry(unittest.TestCase):
    """Verify ToolSystem TOOLS dictionary is consistent."""

    def test_all_tools_have_required_fields(self):
        required = ["name", "yield_min", "yield_max", "lucky_chance",
                     "lucky_mult", "action_time", "unlock_cost"]
        for tid, tool in TOOLS.items():
            for field in required:
                self.assertIn(field, tool, f"{tid} missing {field}")

    def test_pan_is_free(self):
        self.assertEqual(TOOLS["pan"]["unlock_cost"], 0)

    def test_axe_exists(self):
        self.assertIn("axe", TOOLS)

    def test_axe_cost_is_10(self):
        self.assertEqual(TOOLS["axe"]["unlock_cost"], 10)

    def test_axe_is_cheapest_purchasable(self):
        """Axe should be the cheapest tool so players can get timber early."""
        costs = {tid: t["unlock_cost"] for tid, t in TOOLS.items() if t["unlock_cost"] > 0}
        cheapest = min(costs, key=costs.get)
        self.assertEqual(cheapest, "axe")


class TestAxeForTimber(unittest.TestCase):
    """Chopping timber requires axe (not pickaxe)."""

    def setUp(self):
        self.save = SaveManagerSim()

    def test_cannot_chop_without_axe(self):
        self.assertFalse(can_chop(self.save))

    def test_cannot_chop_with_only_pickaxe(self):
        self.save.unlock_tool("pickaxe")
        self.assertFalse(can_chop(self.save))

    def test_can_chop_with_axe(self):
        self.save.unlock_tool("axe")
        self.assertTrue(can_chop(self.save))

    def test_buy_axe_then_chop(self):
        self.save.add_gold(10.0)
        self.assertTrue(buy_store_item(self.save, "axe"))
        self.assertTrue(can_chop(self.save))

    def test_cannot_buy_axe_without_gold(self):
        self.assertFalse(buy_store_item(self.save, "axe"))
        self.assertFalse(can_chop(self.save))


class TestHotbarSelection(unittest.TestCase):
    """Tool hotbar selection rules."""

    def setUp(self):
        self.save = SaveManagerSim()

    def test_pan_always_selectable(self):
        self.assertTrue(can_select_tool(self.save, "pan"))

    def test_cannot_select_unowned_tool(self):
        self.assertFalse(can_select_tool(self.save, "axe"))
        self.assertFalse(can_select_tool(self.save, "pickaxe"))
        self.assertFalse(can_select_tool(self.save, "shovel"))
        self.assertFalse(can_select_tool(self.save, "sluice_box"))

    def test_can_select_after_purchase(self):
        self.save.add_gold(100.0)
        buy_store_item(self.save, "axe")
        self.assertTrue(can_select_tool(self.save, "axe"))

    def test_all_hotbar_tools_are_valid(self):
        for tid in HOTBAR_TOOLS:
            self.assertIn(tid, TOOLS, f"Hotbar tool {tid} not in TOOLS registry")

    def test_hotbar_order_matches_cost(self):
        """Hotbar should be ordered by unlock cost (cheapest first)."""
        costs = [TOOLS[tid]["unlock_cost"] for tid in HOTBAR_TOOLS]
        self.assertEqual(costs, sorted(costs))


class TestStoreItems(unittest.TestCase):
    """Store item list is consistent with ToolSystem."""

    def test_axe_is_first_store_item(self):
        self.assertEqual(STORE_ITEMS[0]["id"], "axe")

    def test_store_costs_match_tool_registry(self):
        for item in STORE_ITEMS:
            iid = item["id"]
            if iid in TOOLS:
                self.assertEqual(item["cost"], TOOLS[iid]["unlock_cost"],
                                 f"Store cost for {iid} doesn't match ToolSystem")

    def test_cabin_kit_requires_timber(self):
        cabin = [i for i in STORE_ITEMS if i["id"] == "cabin_kit"][0]
        self.assertEqual(cabin.get("timber_cost", 0), 5)

    def test_buy_all_tools_in_order(self):
        """Simulate buying every tool in store order."""
        save = SaveManagerSim()
        save.add_gold(500.0)
        save.data["timber"] = 10
        for item in STORE_ITEMS:
            result = buy_store_item(save, item["id"])
            self.assertTrue(result, f"Failed to buy {item['id']}")


if __name__ == "__main__":
    unittest.main()
