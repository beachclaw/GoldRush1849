# Gold Mine — Game Design Document

**Engine:** Godot 4  
**Visual Style:** Low-poly 3D  
**Setting:** California Gold Rush, 1848–1865 (v1.0)  
**Tone:** Lighthearted with grit  
**Infrastructure:** Cloudflare  

---

## Vision Statement

Gold Mine is a game about transformation — of land, of fortune, and of an era.  
You begin as a lone prospector with a pan and a dream on the banks of the American River.  
Through persistence, luck, and cunning, you build something that changes the landscape forever.  
The game captures the wildness of 1849 California and the relentless march of progress.

---

## The Arc

### Phase 1 — The Prospector (Solo Miner)
- Hand tools: pan, pick, shovel
- Work the river banks and exposed rock faces
- Close, intimate camera — you feel small against the wilderness
- Earn gold dust, trade at the general store
- Unlock: wooden sluice box

### Phase 2 — The Claim
- Establish and defend a claim
- Hire 1-2 workers
- Introduce basic automation
- Camp grows: tent → cabin → small camp
- Unlock: hydraulic equipment, deeper shafts

### Phase 3 — The Operation (v1.0 end state)
- Multiple claims, hired foremen
- Supply chain: lumber, dynamite, water rights
- Town relationships matter
- Camera pulls back — you see your footprint on the land
- Railroad deal on the table — hooks into v2

### Phase 4 — The Tycoon (v2.0)
- Industrial-scale mining
- Political influence, railroad connections
- The landscape is visibly transformed
- Moral choices: labor conditions, environmental impact, rivals
- God-view camera — you survey your empire

---

## Changing Times (Historical Layer)

The world changes around the player:
- **1848** — Gold discovered. Wild frontier, no law. Anything goes.
- **1850** — California becomes a state. Sheriff rides in. Laws arrive.
- **1851–52** — Competition intensifies. Water rights wars begin.
- **1853–55** — Industrial operations emerge. The lone prospector era fades.
- **1860–65** — Civil War era. Supply disruptions. Labor shifts.
- **1869+** — Transcontinental Railroad. Everything changes. (v1.2+)

Historical events surface as: newspaper headlines, traveling merchants, new arrivals.

---

## Core Loop

```
Mine → Earn Gold → Upgrade Equipment → Mine Faster/Deeper → Unlock New Areas → Repeat
```

Secondary: `Build Camp → Attract Workers → Manage Workers → Scale Operation`

---

## Tech Stack

- **Engine:** Godot 4
- **Scripting:** GDScript (game logic) + C++ GDExtension (performance systems)
- **Infrastructure:** Cloudflare (Workers, R2, D1)
- **Art:** Low-poly 3D, warm earthy palette evolving to industrial
- **Audio:** Ambient nature → industrial sounds as eras progress

---

## Architecture Principles

1. **Data-driven everything** — Eras, tech, buildings defined in JSON/resources
2. **Systems over content** — Generic systems fed by data; eras are content packs
3. **C++ for performance** — Terrain gen, mining simulation, ore distribution
4. **GDScript for logic** — UI, gameplay scripting, event handling

---

## Version Scope

| Version | Scope | Budget |
|---------|-------|--------|
| v1.0 "The Claim" | Solo campaign, phases 1-3, 1 map, 1848-1865 | $50 tokens |
| v1.1 "The Rush" | AI rivals, skirmish mode, 2nd map | ~$25 |
| v1.2 "The Industry" | Era to 1870s, workers, hydraulic | ~$25 |
| v2.0 "The Empire" | Multiplayer, tycoon, factions, moddability | new budget |
