# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gold Rush 1849 — a low-poly 3D gold mining game built in **Godot 4.6** with **GDScript**. Set in California 1848, the player progresses from lone prospector to mining operation tycoon. Currently at v0.1.0 (demo: core loop complete, demo ends at 500g gold).

## Commands

### Run the game
```
godot --path .
```

### Run headless automated tests
```
godot --path . --headless scenes/tests/autoplaytest.tscn
```
Tests cover SaveManager, ToolSystem, MiningZone, gold progression, store buying, TutorialManager, and AudioManager. Output is pass/fail with exit codes.

### Export builds
```
godot --path . --headless --export-release "Web" builds/web/index.html
godot --path . --headless --export-release "macOS" builds/mac/GoldMine.dmg
```

## Architecture

### Autoload Singletons (registered in project.godot)

| Singleton | File | Role |
|-----------|------|------|
| `ToolSystem` | `src/systems/ToolSystem.gd` | Tool registry: yield ranges, lucky strike %, action times, costs. `calculate_yield(tool_id, quality)` is the core mining calculation. |
| `SaveManager` | `src/systems/SaveManager.gd` | Persistence to `user://save.json`. Tracks gold_dust, unlocked_tools, camp_level, playtime. Emits `gold_changed` and `tool_unlocked` signals. Auto-unlocks tools at gold thresholds (15g/20g/50g). |
| `Audio` | `src/systems/AudioManager.gd` | Centralized SFX (`play(sound)`) and spatial ambient loops (`start_ambient(id, pos)`). Manages footstep timer. |
| `Tutorial` | `src/systems/TutorialManager.gd` | One-time contextual hints, persisted via SaveManager. Must be initialized with `init(hud)` from Game._ready(). |

### Signal-Driven Communication

`Game.gd` is the central hub that wires everything together. Key signal flow:

```
MiningZone.player_entered → Game → HUD.set_tool() + HUD.set_prompt()
Player.mining_started     → Game → Audio.play() + HUD.show_mining()
Player.mining_finished    → Game → SaveManager.add_gold() → gold_changed → HUD update
                                 → Audio (chime/fanfare) + camera shake (if lucky)
SaveManager.gold_changed  → Game (progression checks: cabin at 100g, demo end at 500g)
SaveManager.tool_unlocked → HUD (notification display)
```

### Scene Flow

**Entry:** `scenes/main_menu.tscn` → LoadingScreen fade → `scenes/main.tscn` (instantiates `scenes/game.tscn`)

**Game scene hierarchy:** Game (Node3D) contains World (ground, river, mining zones, store zone, scenery), Player (CharacterBody3D), CameraPivot, and UI layers (HUD, Store, PauseMenu, Inventory, DemoEnd).

### Mining Zones

Mining zones (`src/world/MiningZone.gd`) are Area3D nodes with a `tool_type` enum and `quality` multiplier (0.7–1.5). The player auto-equips the zone's required tool on entry. Yield = base_yield × quality. Lucky strikes (1–8% per tool) multiply yield by 3–5×.

### Procedural World

`src/world/Scenery.gd` generates all world objects (trees, rocks, mountains, buildings, campfire, clouds) using seeded RNG (seed 1849). Nothing is manually placed — all geometry is built from MeshInstance3D primitives.

### Data-Driven Config

`data/eras/1848.json` defines era-specific tools, buildings, events, economy values. Currently loaded but not actively driving gameplay — designed for future era expansion.

### Rendering

Uses `gl_compatibility` renderer with ETC2/ASTC texture compression. 1920×1080 viewport with `canvas_items` stretch mode. Custom water shader on river mesh. Day/night cycle (`src/world/DayCycle.gd`) runs a 10-minute real-time loop interpolating sun angle, color, and intensity across 6 keyframes.

## Key Patterns

- **All UI is procedurally built** — Store items, inventory rows, and HUD elements are created in code, not in the scene editor.
- **Player movement locks during mining** — `is_mining` flag on Player prevents movement while action timer runs.
- **Camera uses spring arm** — `CameraController.gd` implements orbit camera with raycast collision avoidance. Mouse sensitivity saved to `user://settings.cfg`.
- **Save files:** game state in `user://save.json`, settings in `user://settings.cfg`.
- **GDExtension (`gdextension/src/`)** exists but is empty — C++ performance layer planned for v1.1+.

## Conventions

- GDScript files live in `src/` organized by role: `systems/`, `world/`, `entities/`, `ui/`, `tests/`.
- Scene files (.tscn) live in `scenes/` with UI scenes under `scenes/ui/`.
- Tools are identified by string IDs: `"pan"`, `"pickaxe"`, `"shovel"`, `"sluice_box"`, `"pan_upgraded"`, `"cabin_kit"`.
- Gold amounts are floats displayed to 1 decimal place (e.g., "2.3g").
