# Dev Notes

## Session Log

### 2026-03-06 — Project Kickoff
- Concept locked: solo miner → tycoon arc, California 1848+
- Engine: Godot 4
- Style: Low-poly 3D
- Infrastructure: Cloudflare (Workers, R2, D1)
- Architecture: data-driven, systems over content, era packs
- Timeline: open-ended (starts 1848, no upper boundary)
- v1.0 scoped to $50 Claude token budget

## Architecture Decisions

### Engine: Godot 4
- Free, no royalties
- Strong 2D + 3D
- GDExtension supports C++ for performance systems
- Exports to PC, web, mobile

### Language Strategy
- GDScript → game logic, UI, event handling, rapid prototyping
- C++ GDExtension → mining simulation, terrain/ore generation, performance-critical loops

### Infrastructure: Cloudflare
- Workers → game backend logic
- R2 → asset storage
- D1 → leaderboards, player data (v2+)

### Data-Driven Design
- Eras, tech trees, buildings, events defined in JSON/Godot Resources
- New era = new data file, zero engine changes
- Enables future moddability

## Next Steps
- [ ] Install Godot 4 (confirm version)
- [ ] Init Godot project in this directory
- [ ] Set up git repo
- [ ] First milestone: player walks to river and pans for gold
- [ ] Prototype mining feel before building any systems

### 2026-03-07 — Scenery & Character Pass
- Replaced capsule player with segmented humanoid: head, torso, arms, legs + miner hat
- Added third-person orbit camera (CameraController.gd) — mouse to orbit, WASD camera-relative
- Added procedural scenery (Scenery.gd, seed 1849):
  - 50 trees (cylinder trunk + double sphere canopy)
  - 30 rocks scattered, 18 along river banks
  - 5 low-poly cone mountains with snow caps
  - Sandy river banks on both sides
- Added WorldEnvironment: ProceduralSky, warm ambient fill, subtle distance fog
- Softened shadows (PSSM split shadows, increased ambient energy)

### 2026-03-07 — Scenery Polish + Gameplay Pass
- Fixed sky gradient (deep blue zenith → bright horizon)
- Fixed sun position to sit in clear sky gap between mountains
- Added campsite near spawn: low-poly pyramid tent + campfire with OmniLight glow
- Added gold pan mesh to player's right hand (handle + bowl, procedurally built)
- Panning animation: character leans forward, both arms extend down while panning
- Movement locked during panning (no sliding around while working the river)
- Improved HUD: tool label, gold icon, cleaner layout

### 2026-03-07 — M1 Loop Complete
- Added ToolSystem autoload (pan, pickaxe, shovel, sluice_box stats + yield calc)
- Added SaveManager autoload (gold persistence, unlock thresholds, save/load to user://save.json)
- Replaced PanZone with generic MiningZone (tool_type enum, quality multiplier)
- Added RockZone (pickaxe, quality 1.2) near river right side
- Added EarthZone (shovel, quality 0.8) near camp
- Added StoreZone (Area3D) + General Store UI (buy tools with gold, owned state)
- Player now: auto-equips tool on zone entry, checks ownership before mining, locked tool shows buy hint
- HUD: unlock notifications at 15/20/50g thresholds, tool display, mining progress bar
- Scenery: rock face with ore vein hint, loose earth patch, store building with porch + sign
- Game.gd wires all zones, store open/close, mining signals to HUD

### 2026-03-07 — Full Loop Build-Out
- Main menu (GOLD RUSH 1849 title, California 1848, Start/Quit)
- Pause menu (ESC → Resume / Save / Quit to Menu)
- Inventory panel (TAB → gold + tools owned/cost)
- Demo end screen (⭐ The Claim is Yours! at 500g)
- Tutorial system (autoload, first-time contextual hints, persisted)
- Spring arm camera (raycasting prevents clipping through terrain/objects)
- Screen shake (lucky strikes trigger 0.35s shake via cam_pivot.shake())
- Gold particle burst (CPUParticles3D spawned on every yield)
- River water shader (animated waves + shimmer + flow stripes)
- Map boundaries (invisible StaticBody3D walls at field edges)
- Game icon (64px gold coin PNG)
- Cabin upgrade (100g → camp_level 1, cabin mesh replaces tent)
- Store: added Cabin Kit item
- project.godot now starts at main_menu.tscn
