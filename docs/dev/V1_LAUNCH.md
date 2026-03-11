# GoldRush1849 — v1.0 Demo Launch Plan

**Target:** A playable web demo on itch.io
**Scope:** Solo miner → first upgrade → cabin → 20-30 min core loop
**Platform:** Godot HTML5 export + downloadable Mac/Windows builds
**Status:** In development — last updated 2026-03-07

---

## ✅ Done

- [x] Godot 4 project initialized
- [x] Player with WASD movement + third-person orbit camera (mouse look)
- [x] River panning mechanic (walk to river → SPACE → 2s yield → gold dust)
- [x] Gold dust accumulation + HUD display
- [x] Walking animation, panning pose animation
- [x] Movement locked during panning
- [x] Gold pan mesh in player's hand
- [x] Procedural scenery (50 trees, 30 rocks, 5 mountains, clouds, sun)
- [x] WorldEnvironment (sky gradient, ambient light, fog)
- [x] Campsite near spawn (tent + campfire with point light)
- [x] HUD: gold counter, tool label, prompt, pan progress bar, message flash

---

## 🔴 Gameplay — Must Have

### Mining
- [x] **Pickaxe zone** — rock face Area3D near camp; different yield curve (medium, bursty)
- [x] **Shovel zone** — loose earth near camp; fast/low yield
- [x] **Tool switching** — WASD to zone auto-equips the right tool; HUD shows it
- [x] **Sluice box** — placeable at river after 50g unlock; higher passive yield while idle
- [x] **Vein quality variance** — pan zones have hidden `quality` multiplier (PanZone already has it, just needs wiring)
- [x] **Lucky strike feedback** — screen flash + brief camera shake + sound cue

### Progression
- [x] **Save/load** — persist gold, unlocks, camp state to `user://save.json`
- [x] **Unlock system** — trigger events at gold thresholds (50g, 100g, 250g, 500g)
- [ ] **Timber resource** — chop trees near camp (1-3 hits with pickaxe → timber log)
- [x] **Cabin upgrade** — spend 100g + 5 timber → replaces tent mesh with cabin

### General Store
- [x] **Store building** — low-poly building near camp, enter-to-open
- [x] **Store UI** — simple list: item name, description, cost, [Buy] button
- [x] **Store items (v1)**:
  - Sluice Box — 50g
  - Better Pan — 30g (1.5× yield multiplier)
  - Pickaxe — 20g (unlocks rock face)
  - Shovel — 15g (unlocks loose earth)
  - Cabin Kit — 100g + 5 timber

---

## 🟡 World & Environment

- [x] **Map boundary** — invisible walls or natural barriers (cliff edge) at field limits
- [x] **Rock face zone** — visible gray rock outcrop mesh + Area3D trigger near river bend
- [x] **Loose earth zone** — darker soil patch + Area3D trigger
- [ ] **Multiple pan zones** — 2-3 river spots with varying quality (visible shimmer on rich spots)
- [x] **Store building mesh** — low-poly wooden structure near tent
- [x] **Cabin mesh** — replaces tent when built (procedural, same style)
- [ ] **Day/night hint** — slowly shift sun color/intensity over time (optional but nice)
- [x] **River animation** — scroll river material UV to fake water flow

---

## 🟡 UI / UX

- [x] **Main menu** — title, Start, Settings, Quit
- [x] **Pause menu** — ESC opens pause (Resume, Save, Settings, Quit)
- [x] **Inventory panel** — TAB opens: gold dust, gold nuggets, timber count
- [x] **Unlock notification** — center screen pop when threshold reached ("Sluice Box Unlocked!")
- [x] **Tutorial prompts** — contextual hints that fade after first time:
  - On start: "Walk to the river with WASD"
  - On river entry: "Press SPACE to pan for gold"
  - On 50g: "Visit the General Store" (arrow marker)
- [ ] **Minimap** — optional but helps orientation (simple top-down quad)
- [ ] **Settings screen** — master volume, mouse sensitivity, resolution

---

## 🟡 Audio

- [ ] **River ambient** — looping water sound near river zones
- [ ] **Footstep sounds** — grass/dirt variants, triggered on walk cycle
- [ ] **Panning sound** — water swishing loop during pan action
- [ ] **Pick/shovel sounds** — impact + scrape
- [ ] **Gold find chime** — short ascending tone on yield
- [ ] **Lucky strike fanfare** — punchy sound + camera shake
- [ ] **Campfire crackle** — looping near camp
- [ ] **UI sounds** — click, buy, unlock
- [ ] **Background music** — wilderness_morning theme (acoustic/folk-ish, looping)

---

## 🟢 Game Feel & Polish

- [x] **Camera spring arm** — SpringArm3D to prevent clipping through rocks/trees
- [x] **Gold particle burst** — small yellow particles on yield (GPUParticles3D)
- [ ] **Campfire particle** — fire/spark particles on campfire node
- [x] **Screen shake** — lucky strike triggers 0.3s shake
- [ ] **Ambient wildlife** — occasional bird call audio (spatial, random timer)
- [ ] **Character shadow** — confirm shadow casting on all body parts
- [ ] **Hover prompt polish** — styled prompt box (not raw Label) with icon

---

## 🔵 Technical / Launch

- [x] **App icon** — create `assets/icon.png` (1024×1024, low-poly miner)
- [ ] **Git repo** — init + first commit with `.gitignore`
- [ ] **HTML5 export** — configure Godot export template for web
- [ ] **Mac export** — signed .app bundle
- [ ] **Windows export** — .exe with installer
- [ ] **Performance pass** — profile, check draw calls, LOD on trees if needed
- [ ] **Loading screen** — brief splash between main menu → game
- [ ] **Error handling** — graceful fallback if save file corrupted
- [ ] **Crash reporting** — optional: Cloudflare Worker to log errors

---

## 🟣 Demo-Specific (itch.io)

- [x] **End state hook** — at 500g show "The Claim is Yours" screen + "v1.1 coming soon"
- [ ] **itch.io page** — banner, description, screenshots, tags (gold rush, mining, casual, low-poly)
- [ ] **Trailer** — 60-90 sec screen capture: pan → lucky strike → store → cabin upgrade
- [ ] **Press kit** — 5-8 screenshots, logo, short description
- [ ] **Playtest** — 2-3 external players, note friction points
- [ ] **Demo build tag** — `v0.9-demo` on itch, separate from main

---

## Milestones

| Milestone | What's Needed | Est. Sessions |
|-----------|--------------|--------------|
| **M1 — Loop Complete** | Pickaxe zone, store, sluice box, save/load | 2-3 |
| **M2 — World Filled** | Rock face, loose earth, cabin, store building, river scroll | 1-2 |
| **M3 — UX Pass** | Main menu, pause, inventory, tutorial prompts, unlock notifications | 1-2 |
| **M4 — Audio** | All sounds, music, campfire particles | 1-2 |
| **M5 — Polish** | Spring arm, particles, screen shake, icon, performance | 1 |
| **M6 — Launch** | Exports, itch.io page, trailer, playtest | 1 |

**Total estimate: 7-12 sessions**

---

## Descoped from Demo (save for v1.1+)

- AI rival prospectors
- Workers / wages system
- Water rights
- Flooding / cave-in events
- Era progression (1848 → 1865 timeline events)
- Multiplayer
- C++ GDExtension performance systems
- Cloudflare leaderboards / player data
