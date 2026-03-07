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
