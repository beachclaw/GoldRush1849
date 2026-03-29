# Gold Rush 1849 — Roadmap

Prioritized by impact on game feel. Each item is a single PR.

## P0 — Feels Broken Without These

- [ ] **Tool-specific animations** — Pickaxe overhead swing, shovel dig, pan swish, axe chop. Each tool needs its own motion with weight and timing. Currently everything uses the same panning lean.
- [ ] **Proper character model** — Export a low-poly prospector .glb from Blender to replace the primitive-mesh assembly. Rigged skeleton for animation.
- [ ] **Mining feedback particles** — Dirt puffs when shoveling, rock chips when pickaxing, water splashes when panning, wood chips when chopping. No visual feedback currently.

## P1 — Makes the Game Feel Good

- [ ] **Toon/flat shader** — Unlit or cel-shaded material for the illustrated look. Applied to character + world objects.
- [ ] **Sound per tool** — Distinct SFX for each tool action (metal on rock, shovel in dirt, water slosh). Current audio may be generic.
- [ ] **Gold nugget pickup effect** — Visible gold nuggets appear after mining, float toward HUD. Currently gold just silently adds to counter.
- [ ] **Camera improvements** — Slight zoom during mining, follow-through on big strikes, better default angle.
- [ ] **Walking dust/footsteps** — Subtle dust puffs when walking on dirt, footstep sounds.

## P2 — Content & Polish

- [ ] **NPC characters** — Other prospectors in the world for life and atmosphere.
- [ ] **World detail pass** — More variety in trees/rocks, wildflowers, grass patches, fence posts, signs.
- [ ] **UI polish** — Better fonts, transitions, button hover states, inventory layout.
- [ ] **Music** — Background ambient music that shifts with time of day.
- [ ] **Weather** — Simple rain/fog system for atmosphere variety.
- [ ] **More mining zones** — Cave entrance, hillside dig site, deeper river spots.

## P3 — Future Features

- [ ] **Era progression** — Use data/eras/ system to advance through time periods.
- [ ] **Hiring workers** — NPC miners you can assign to zones.
- [ ] **Equipment upgrades** — Visual changes to tools as they upgrade.
- [ ] **Town building** — More structures beyond the cabin.
