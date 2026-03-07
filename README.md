# Gold Mine 🏅

A low-poly 3D gold mining game set in California 1849.
Start as a lone prospector. Build an empire.

**Engine:** Godot 4  
**Language:** GDScript + C++ (GDExtension)  
**Infrastructure:** Cloudflare  

## Version Roadmap
- **v1.0 "The Claim"** — Solo miner, core loop, 1 map, 2-3hrs ($50 token budget)
- **v1.1 "The Rush"** — AI rivals, skirmish mode, 2nd map
- **v1.2 "The Industry"** — Era expands to 1870s, workers, hydraulic mining
- **v2.0 "The Empire"** — Multiplayer, tycoon phase, factions, moddability

## Project Structure
```
src/          Game logic (GDScript + C++ core systems)
assets/       Models, textures, audio
scenes/       Godot .tscn scene files
data/         Era configs, tech trees, events (JSON)
gdextension/  C++ GDExtension source
docs/         Design docs and dev notes
```

## First Milestone
A player that walks to a river and pans for gold. Nothing else.
Prove the feel before building systems around it.
