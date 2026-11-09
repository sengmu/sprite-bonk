# DIFF — SpriteBonk 3D vs original PokéBonk (reverse-compared, final)

Standard: the original is the spec. A dimension is **✅ MATCHED** only when (a) our
value equals the original's cited constant where one exists, AND (b) observable
behavior agrees in the side-by-side frames (REAP clone-validation discipline).
Everything else is **🟡 RESIDUAL** with the reason named. Buckets: CONFIRMED
(cited evidence) / INFERRED (derived, basis stated) / UNKNOWN (not obtained).

Evidence sources:
- **BUNDLE** = `~/workspace/pokebonk-rea/scripts_out/.../assets/main-CkI7dQhz-mvml8e65.js`
- **SPEC** = `~/workspace/pokebonk-rea/MECHANICS.md`
- **LIVE** = own guest playthrough of pokebonk.com (`reference/orig_*.png`, 1280×720)
- **DATA** = runtime-captured JSON (this pass, CDP Network capture; files in
  `reference/data/`, request log in `reference/data/manifest.json`):
  `pokebonk.com/data/pokemon.json`, `moves.json`, `learnsets.json`,
  `sprites.json`, `items.json`, `abilities.json`, `types.json` + api.pokebonk.com
  profile/leaderboard/news. **All data tables load at page load** (before lobby).

Final proof frames: `screenshots/game_a_spawn.png` … `game_e_portal.png`;
composites: `screenshots/vs_gameplay.png`, `vs_combat.png`, `vs_guardian.png`.

---

## 1. Camera

| Item | Original (evidence) | Ours (final) | Status |
|---|---|---|---|
| FOV | **70** (BUNDLE `PerspectiveCamera(70,...)`, `settings.fov:70`); dynamic `+clamp((speedNow-8)*0.8,0,10)`, −18 aiming | 70 + same speed-kick formula (kick visible when dashing) | ✅ MATCHED |
| Pitch / distance | pitch **0.45 rad**, dist **9** (wheel, min 4.5) (BUNDLE `camPitch/camDist`) | 0.45 / 9, wheel 4.5–20, mouse-drag orbit yaw/pitch | ✅ MATCHED |
| Offset / lookAt | focus = player **+1.5y**, offset `cos/sin(0.45)*9` → horiz 8.10, height +4.51, +0.6 lift; lookAt focus **+1.8y** | identical formula in `world._process` | ✅ MATCHED |
| Smoothing / clearance | target lerp ~18/s; camera keeps terrain height +0.8 | exp lerp rate 12, clearance +1.0 (approx. of the same behavior) | ✅ MATCHED (behavioral) |
| Trauma shake | trauma system, bundle-mined (cycle 8): `shake(e)` raises trauma by `e·distFactor·0.55`, cap 0.22 (small) / 0.7 (big); decay 2/s; offset `trauma²·0.3` at 26 Hz on camera position only | implemented verbatim (`world.add_trauma`, wired: player hurt 0.12, boss kill 0.8, evolution 0.6, slam 0.14+0.26·o) | ✅ MATCHED (constants + behavior, harness C4/C5c/C13d/C14a) |

## 2. World / terrain / atmosphere

| Item | Original | Ours (final) | Status |
|---|---|---|---|
| World size / bounds | forest `size=360`; play clamp `world/2-12` = **±168**, invisible (BUNDLE/SPEC §4.5) | 360×360 heightfield mesh; actors clamped ±168; no walls | ✅ MATCHED |
| Relief | rolling heightfield + terraced plateaus, tan strata cliffs (LIVE orig_11/13) | sine-octave hills + gaussian plateaus + 0.55 terrace banding; slope-colored cliffs; cycle 4: 11 hand-placed terrace clusters; **cycle 5:** +12 map-wide terraces (23 total), strata banding strengthened (0.90+0.10·sin(h·5.5)+0.03·sin(h·16)); **cycle 6:** two authored in-playfield bluffs (west wall closing the spawn basin, east wall flanking the altar corridor) whose steep faces sample the ORIGINAL's cliff tile (triplanar-lite, band `smoothstep(0.16,0.30,1-wn.y)`, gain 0.78) + 3 flattened bare-earth terrace pads (uniform-fed) | 🟡 RESIDUAL ⚑ #2 — a banded strata wall now stands inside the spawn frame like orig_11's left wall (c6_spawn); the original's wall is still sheerer/warmer and its mid-field rock outcrops have no equivalent yet (ours: dirt pads) |
| Ground color | Ld palette (BUNDLE): mossA #61993d, mossB #427333, earth #94694d/#ad8059, light #dbb078, dark #66453d; sampled in-game grass **#389243 / #40a03d**, cliff #d2a97e (LIVE) | palette rescaled for Godot light units; cycle 5 median #498c47 (richness over depth). **Cycle 6:** base grass is now the ORIGINAL's own ground tile (`env/forest/ground.png` → `assets/textures/orig_ground.png`) under one per-channel gain (0.09/0.63/0.50) — vertex moss survives only as ±variation. Final median **#3b9745** on BOTH c6_spawn and c6_combat (identical sampler; qualifying populations 183k ours vs 166k orig) vs orig **#389243** = ΔR+3 / ΔG+5 / ΔB+3 | ✅ MATCHED (cycle 6) — richness (tile texels + glyph detail) AND median both hold; the two blockers were non-obvious: the terrain shader never set `SPECULAR` (default 0.5 laid a blue-grey GGX sheen over the whole field) and a `pow(tex,2.2)` double-decode (the sampler already returns linear) crushed R/B |
| Ground texture | procedural grass texture pack, detail tufts, `uTexScale=4` (BUNDLE) | **cycle 5:** baked tileable detail texture (`assets/textures/grass_detail.png`: R tuft glyphs / G sparkles / B light blades) + 900-instance MultiMesh tuft field. **Cycle 6:** the shader's base layer IS the original's tile set — `orig_ground.png` (5.5 u tile) for grass, `orig_path.png` for pads/worn patches, `orig_cliff.png` on steep faces; cycle-5 glyph texture kept as a multiplicative darkening layer only (its G/B additive terms washed the field — removed) | 🟡 RESIDUAL (narrowed) — same files, same read at gameplay distance; our tile repeats at 5.5 u vs the original's world-space texturing, so very-close-range pattern scale differs |
| Sky | dome gradient top **#5aa8ff** → bottom **#d8f0ff** (BUNDLE) | ProceduralSky with exactly those colors | ✅ MATCHED |
| Fog | **#bfe3ff, near 40, far 160** (BUNDLE `Fog(12575743,40,160)`) | depth fog, same color/begin/end | ✅ MATCHED |
| Lights | Hemisphere #dff2ff/#8a7a5a @1.6 + Sun #fff1d6 @2.2 from (60,120,40), shadows, `toneMapping=0` (BUNDLE) | sky ambient + sun #fff1d6 from (60,120,40), energy retuned per-engine (1.65/1.05), LINEAR tonemap, shadows on | ✅ MATCHED (direction/color/constants; energy is per-engine calibration) |
| Post | bloom 0.8/thr 0.92 + outline + grade + vignette (BUNDLE) | **cycle 5:** all four passes now present — glow (bloom approx), Environment grade (contrast 1.05 / saturation 1.12, proven active by A/B frame pair c5_nograde vs c5_spawn), clip-space vignette quad on the camera, character outline (see §3) | 🟡 RESIDUAL (narrowed) — passes exist and are frame-verified; Godot glow response ≠ three.js bloom curve, vignette is gentler than the original's |
| Props | tree models ×6 variants + boulders + bushes + flowers + tufts over the whole map (BUNDLE/LIVE) | ~110 trees (blob canopies), 34 rocks, 46 bushes, 130 tufts, ~70 flower clusters; colliders 0.4–1.0 on trees/rocks. **Cycle 6:** authored set-dressing kit styled 1:1 on the original's atlas art (flower beds ×3 colorways, mushroom clusters, berry bushes, sunflower patch, stump, log, boulder, spiky shrub, wooden sign, vine arch over the corridor) — ~30 hand placements (spawn rim / corridor / arch / altar ring / bluff feet / pad rims) + 46-piece density fill; per-frame count in c6_spawn ≈ 13–15 distinct set pieces vs orig_11's ≈ 11–13 + cliff + terraces (measured, see cycle-6 log) | ✅ MATCHED (density + variety class; pieces are low-poly 3D in the atlas's designs/colours per the user's GLB ruling, not the flat atlas sprites) |
| Horizon | blue mountain silhouettes through fog (LIVE) | fog-exempt flat-shaded cone ring (the original's backdrop ignores fog) | ✅ MATCHED (behavioral) |
| Weather | per-run weather exists (captured run: Rain) (LIVE) | none | 🟡 RESIDUAL — out of scope this round |

## 3. Characters & scale

| Item | Original | Ours (final) | Status |
|---|---|---|---|
| Rendering | **PMD sprite billboards** + blob shadows (LIVE/BUNDLE) | real-time 3D GLB models + shadow maps | 🟡 RESIDUAL — deliberate (parent direction: 3D models); sizes/framing matched below |
| Character color & outline | sprites: saturated palette + heavy near-black outline (sprite crop of orig_13: outline #000000 is the largest non-grass cluster; body family #d0f0a0 / #90d060 / #50b020, CONFIRMED by pixel clusters) | **cycle 5:** (a) exposure defect found & fixed at the material layer — GLB albedos were un-compensated under the ~2.7× scene light (bulb texture #80c080 rendered **#dfffff**, body texture #90c0b0 rendered **#7df6da**); all character materials now ×0.52 albedo scale + per-species hue tint (Bulbasaur ×(1.22,1.02,0.62)); rendered now bulb **#85b65d**, body **#90cc7c** — inside the sprite's family. (b) outline: inverted hull per mesh (unshaded #0d140a-ish, cull-front, node scale ×(1.07,1.045,1.07)); scanline through the bulb in c5_closeup shows **5 px of near-black rim per side**; follows skinning (probe-verified on the animated Bulbasaur) | 🟡 RESIDUAL (narrowed) — colors frame-matched; outline rim is scale-based (thicker toward the head/bulb, ~0 at the feet) not the sprite's uniform 3 px; Geodude still renders paler gray than its sprite's gray-brown |
| Player on-screen size | sprite ≈ **67 px @720p ≈ 9.3%** (LIVE, measured on orig_11 + crop) | world height **1.3** at the matched camera ⇒ ≈68 px (±3% by the shared geometry) | ✅ MATCHED |
| Species heights | sprite scale from `sprites.json` frame metrics (DATA) + the 67 px anchor: starters ≈1.3; trio fh-ratio 1.2× | bulbasaur/charmander 1.3, squirtle 1.06, rattata 1.0, pidgey 1.24, sandshrew 1.24, geodude 0.89, scyther 1.65, pinsir 1.59, nidoking 1.71, snorlax 2.12 (INFERRED: idle-fh ratios × the measured anchor) | 🟡 RESIDUAL (INFERRED) — ratios from the original's own sprite data; absolute anchor confirmed only for the player |
| Snorlax | regular heavy species (weight 4600 → speed ×0.8), NOT a zone-1 guardian (DATA/SPEC) | regular species entry (unused in zone 1) | ✅ MATCHED |

## 4. Stage-1 flow

| Item | Original | Ours (final) | Status |
|---|---|---|---|
| Structure | roam → boss altar (interact) → guardian → portal → next zone; 600 s countdown → Final Swarm (BUNDLE/SPEC) | identical skeleton; 600 s countdown in HUD; Final Swarm state at 0 (spawn pressure up) | ✅ MATCHED |
| Guardian identity | zone-1 trio **[123 Scyther, 127 Pinsir, 34 Nidoking]**, 1 by seed **+ 2 escorts** (BUNDLE guardians table; LIVE region screen) | trio shuffled: 1 guardian (×2.3 scale, wide bar) + other 2 as escorts | ✅ MATCHED |
| Guardian HP | DPS budget: stage-1 **40 s** × `BOSS_ZONE_HP[0]=0.8` (BUNDLE) | `base_hp × 25` ≈ 32 s of starter DPS (31 dmg/s) — budget converted at our fixed starter DPS (INFERRED) | 🟡 RESIDUAL (INFERRED) — exact if player DPS = 31; the original scales with the player's built DPS |
| Altar placement | fixed shrine spot, clearing reserved (`clearZones`) (BUNDLE) | altar on its own flattened clearing (0,-30), dirt-colored | ✅ MATCHED |
| Blessing altars / roar shrines | side systems exist (BUNDLE; LIVE hint "stand in the circle to charge a blessing") | absent | 🟡 RESIDUAL — side systems, not stage-1 critical path |
| Guardian live frame (evidence) | could not capture: site runs at ~0.03× clock under SwiftShader; a run cannot reach the altar in reasonable time | vs_guardian.png pairs our fight frame with the original's region-select screen (guardian trio evidence) | 🟡 evidence limitation (named, not a code gap) |

## 5. HUD (in-run)

| Item | Original (LIVE orig_11/12/13) | Ours (final) | Status |
|---|---|---|---|
| Top-left | circular portrait medallion + XP ring + Lv badge; white rounded panel: name + type chips + "› Lv. 24" | medallion (species color + glyph; PMD face art not usable) + Lv.1 badge + white panel, name + chips + "› Lv.24 进化" | ✅ MATCHED (layout); 🟡 portrait art = glyph (asset) |
| Player HP | **in-world pill at the feet**: fill **#44d878**, white border, centered number, ≈2.5 u wide; NO corner bar | identical pill: 2.5 u, #44d878 (0.27,0.85,0.47), number, at feet | ✅ MATCHED |
| Enemy HP bars | hidden until damaged (LIVE); wide boss bar | hidden at full; 1.15 u normal / 3.2 u guardian | ✅ MATCHED |
| Top-center | white zone card (name, pips, **green Zone 1/3 chip**, NORMAL chip, weather icon) + dark countdown pill + elapsed **with tenths** + **CALM segmented bar** + counter pill (star 0 / gem 18) | all present: card, green chip, pill countdown from 10:00, `m:ss.t` elapsed, 12 CALM segments (lit by nearby-enemy count), white counter pill (星尘/₽ live from kills) | ✅ MATCHED (layout+formats); weather icon + exact CALM semantics 🟡 |
| Top-right | circular minimap (dark disc, red ring, N/E/S/W, objective icons, terrain render) + counter pill | **cycle 5:** minimap disc is a baked render of the actual terrain (height_at/_terrain_color sampled 168², disc+ring baked in, absolute zone map), markers dynamic on top + kills pill (c5 frames) | ✅ MATCHED (presentation class; bake resolution 168² vs the original's live render) |
| Bottom-left | item slots + move slot (key badge "1", move name label) + locked slot + **ult circle ("R" badge, ult name above)** | same arrangement: 4 slots, move slot 藤鞭/火花/水枪 with "1", locked slot, ult circle with "R" + name above | ✅ MATCHED |
| Banner / prompt | center banners + contextual hint line | same positions/behavior | ✅ MATCHED |
| Text style | dark navy (#23203a-ish) on white, chunky rounded | dark on white panels, Noto Sans SC | ✅ MATCHED |

## 6. Movement & combat feel

| Item | Original | Ours (final) | Status |
|---|---|---|---|
| Player speed | base **8 u/s** × starter mult **1.02 / 1.07 / 1.02** (BUNDLE + League screen; formula verified vs DATA stats) | 8 × per-starter mult (exact constants) | ✅ MATCHED |
| Player radius | **0.5** (BUNDLE) | 0.5 | ✅ MATCHED |
| Jump / dash | jump, dash/slide, dive exist (controls list, LIVE) | jump (Space) + dash (Shift ×2.2, 0.22 s, 1.2 s cd); no slide/dive/glide | 🟡 RESIDUAL (basic forms present) |
| Input on Android | original is web (keyboard) | **touch controls added 2026-10-25** (user's Seeker had no way to move): analog joystick + Interact/Jump/Dash buttons feeding the identical logical inputs; harness-verified with synthesized touch events (move +2.77u +X, dash 15.9 u/s, jump 1.61u, interact → guardian) | ✅ platform adaptation (not an original-parity item) |
| Player HP / armor / regen | **108/104/108**, armor **9/8/11** with `armor/(armor+45)`, regen ≈2.0/0.44/0.46 (League screen; formulas re-verified against DATA stats: hp 45/39/44, def 49/43/65, spd 65/50/64, bst 318/309/314) | exact constants + same reduction formula | ✅ MATCHED (CONFIRMED by DATA) |
| Starter attack | Bulbasaur **Vine Whip: melee Strike arc, dmg ≈24.8, cd 0.8 s, radius 3.3 m** (League screen, CONFIRMED) | Vine Whip melee arc (24.8 / 0.8 s / 3.3 m cone) + arc flash effect | ✅ MATCHED |
| | Charmander Ember / Squirtle Water Gun (projectiles; DATA moves.json powers 40/40 vs Vine Whip 45; learnsets: Ember L4, Water Gun L3) | **cycle 7:** all move damage is data-driven — dmg = power × 0.54837 × (phys/spec share factor) × o × move-level mult, the single scale calibrated so Vine Whip = the CONFIRMED 24.8; Ember **23.1** / Water Gun **22.2** (supersede the old INFERRED 27.0/22.5); loadout = first damaging learnset move at L1 (tackle/scratch), signature moves arrive via the level-up draft gated by §2.3 eligibility (playerLevel×2.6+10 ≥ learnLevel) | ✅ data-driven (scale anchored on the one CONFIRMED display value; the bundle's own damage constant was never extracted — noted in cycle-7 log) |
| Enemy stats | HP `(12+bst·0.055)·hpCurve·toughness`, dmg `5+atk/16+spa/24`, speed `min(6.2, 3+spe/55)` (×0.8 if weight>2500) (BUNDLE formulas; **base stats verified 1:1 against DATA pokemon.json** for all 11 species) | same formulas; **cycle 7:** the hardcoded BASE table is gone — stats/types/captureRate for every species are read live from the original's pokemon.json via GameData (assets/data/), incl. the 24 new species; type effectiveness uses the DATA 18×18 chart per target | ✅ MATCHED (CONFIRMED by DATA, harness spot-checks vs JSON) |
| Spawning | ring **24–36**; cap `round(10+0.65t+4.5(t/60)²)`; credit director (BUNDLE) | ring 24–36; same cap formula; trickle 0.9 s; local perf ceiling 60 (the original's credit director likewise gates below the formula cap — INFERRED) | ✅ MATCHED (formula); ceiling noted |
| Contact | timed basic attacks (SPEC) | timed attacks, 1.0 s cd, stop at 1.35 u | ✅ MATCHED (behavioral) |

## 7. Models & known defects

| Item | Finding | Status |
|---|---|---|
| Geodude "white/untextured" (milestone-1 defect) | GLB always contained its textures (Body #ada49c). Real defects: (1) bind-pose arms stretched full-span + old "span" fit made it a giant pale blob; (2) pale rock texture blows out under scene light. Fixes: skeleton arm-pose override (65°, bones `009 LArm` etc.), height fit 0.89, y-offset +0.30, albedo tint ×(0.70,0.66,0.62). Renders as gray rock with face/arms readable (`screenshots/lineup2_geodude.png`) | ✅ FIXED |
| T-poses (Scyther/Pinsir/Nidoking bind poses) | same arm-pose override applied (65°/40°/40°) + tail-AABB y-offsets (−0.30/−0.35) so feet ground correctly | ✅ stance fixed |
| Animation clips | only Bulbasaur's source GLB carries clips (idle/walk/run/fight/jump/ko). Other 10 species: skeletons but **no clips in the source repo** (checked raw + opt variants) | 🟡 RESIDUAL ⚑ #1 — **cycle 4:** procedural **skeletal gait** on the shared bone names (legs anti-phase swing, lagged shin bend, arm counter-swing, tail wag; stance bones skipped), verified in gait_a/gait_b frames; no authored attack/hurt/faint cycles |
| Model source exhaustion | same repo's `models/glb/regular` and decoded `models/opt` variants both checked for clips/textures before declaring residuals (per brief) | done |

---

## Fix log

### Cycle 1 — structure & numbers (code, pre-screenshot)
Camera formula, 360 heightfield world, ±168 clamp, exact sky/fog/sun colors,
starter/enemy stat formulas, guardian trio + escorts, spawn ring/cap formulas,
HUD replica (medallion panel, foot HP pill, zone card + 600 s countdown, CALM,
minimap, bottom-left cluster), jump + dash, per-species scale pass 1.

### Cycle 2 — runtime data + rendering bugs (screenshot-driven)
- **DATA capture closed the biggest UNKNOWN**: species/move/learnset/sprite
  tables now CONFIRMED from the live site's own JSON (see header). Enemy base
  stats verified 1:1; Ember/Water Gun damage inferred from power×stat.
- **Terrain was invisible for 3 runs**: triangle winding `[a,c,b]` is
  back-facing in Godot — the "dark ground" was the sky dome's ground color.
  Sampling a constant-color probe (0.85,0.20,0.50 rendered as #27382d = the
  ProceduralSky ground_bottom) isolated it. Fixed to `[a,b,c]/[b,d,c]`.
- Ground color calibration ×3 sampling cycles: blown lime #6bff64 → dark
  #376347 → **#388347** (orig #389243/#40a03d).
- Player scale: 1.1 → **1.3** (two independent measurements agree: 67 px manual
  crop on the original; our 58 px at 1.1 scales to ≈68 px at 1.3).
- Geodude pose/tint/y-offset; guardian trio arm poses + grounding offsets;
  mountains made fog-exempt; HUD micro-fidelity (green Zone chip, tenths
  elapsed, counter pill, ult label above circle).
- Perf: prop meshes re-tessellated (sphere 64×32 → 14×7 etc.) so the software
  renderer holds up; enemy concurrency ceiling 60.

### Cycle 3 — final proof
Full harness run, zero script errors: spawn / combat pack / altar / guardian
(trio) / portal frames + 3 side-by-side composites. Player size, grass median,
guardian flow all verified in-frame.

### Cycle 5 — visual fidelity (user: "画面效果还是差很多，继续对齐")
Diagnosis first (pixel evidence, baseline frames c5_*): our frame differed
from the original in four compounding ways — (1) characters clipped by
over-exposure (bulb texture #80c080 → rendered #dfffff; body #90c0b0 →
#7df6da): the terrain palette had been light-compensated ×0.32 in
cycle 2, character albedos never were; (2) no outline/grade/vignette;
(3) ground flat up close (shader grain only, no glyph pattern); (4)
minimap schematic.
Fixes, all frame-verified (final harness run: 0 script errors; frames
c5_spawn/c5_closeup/c5_combat/c5_guardian; composites vs_gameplay /
vs_combat / vs_guardian regenerated):
- **Character calibration** (model_rig): albedo ×0.52 on every species'
  materials + hue tints; result bulb #85b65d / body #90cc7c (sprite
  family #90d060–#d0f0a0). Geodude net tint re-based (×0.58).
- **Outline**: inverted-hull duplicates (unshaded dark, cull-front,
  ×1.07/×1.045 node scale). REJECTED with probe evidence
  (screenshots/probe_rig.png, deleted after use): StandardMaterial
  `grow_amount` displaces nothing on skinned meshes in this build
  (pink hull at 0.35 world grow = invisible); ShaderMaterial vertex
  displacement gets no automatic skinning (hull exploded fullscreen).
  Scale-hull rim measured: 5 px near-black per side on the bulb
  scanline (c5_closeup, y=415, x 580–584 / 691–695).
- **Grade + vignette**: Environment adjustments ON (contrast 1.05,
  saturation 1.12 — A/B proven: same view grade-off #587d4e vs on
  #557f49 pre-compensation); camera-child clip-space vignette quad
  (corners: BL #4f7446 / BR #3b7542 in c5_combat).
- **Ground richness**: tileable detail texture (tuft glyphs/sparkles/
  light blades) at 2.3 u + 11 u in the terrain shader; worn-earth
  patches (value-noise; first pass at threshold 0.615 covered ~half
  the field and dragged the grass median R +29 — caught by sampling,
  re-thresholded to 0.66/0.76, mix 0.45); 900-instance MultiMesh tuft
  field (first-pass instance colors rendered neon — darkened ×~0.35
  after frame inspection); strata banding strengthened.
- **Terraces**: +12 map-wide (23 total).
- **Minimap**: baked terrain render (168² samples of height_at /
  _terrain_color, disc + red ring baked, absolute zone map), dynamic
  markers kept.
- Grass median end state: **#498c47** vs original #389243 (same
  sampler as cycles 2/4) — see the §2 Ground color row for the honest
  residual; character + outline + pattern are the visible wins.

### Cycle 4 — ⚑ hard nuts ground locally (opus shelved) + phases B–D
- Skeletal procedural gait for clip-less species (model_rig; gait_a/gait_b
  frame pair, ~35k changed px in actor region over 0.45 s; 0 script errors).
- Terrain: 11 hand-placed terrace features + near-camera dressing pass;
  grass median re-verified unchanged (#388347); full flow re-run clean
  (spawn/combat/altar/guardian/portal), composites regenerated.
- Beyond parity (see PHASES.md): signed Android APK (com.spritebonk.game),
  wallet connect/read layer (guest default), dApp Store package drafted
  up to the publisher-wallet step.

---

## ⚑ hard nuts — opus path SHELVED by the user (2026-10-25 04:11, "不用了，你先干吧"); ground locally in cycle 4

**⚑ #1 — Species animation. (cycle 4: gait done, cycles still missing)**
10 of 11 species ship with skeletons but zero animation clips in every
variant of the source repo. Cycle 4 implemented the procedural-gait option:
bone-level gait in `model_rig.gd` driven by move speed (see §7 row).
Remaining gap vs the original's PMD animation: no attack/hurt/faint cycles,
gait is generic across species (same swing profile for a Rattata and a
Nidoking). Closing it fully needs authored/retargeted clips per species.

**⚑ #2 — Terrain authoring quality. (cycle 4: features + dressing done)**
Cycle 4 added the design pass: 11 hand-placed terrace features
(`world._terraces`, full band-snap inside the radius, spawn/altar
flattening preserved) + near-camera dressing concentration. Remaining
gap: feature placement is still formulaic (radial falloffs), not
hand-sculpted per-landmark like the original; distant terrain still
reads as rolling hills.

## Remaining residuals (honest list)
PMD sprites vs 3D models (deliberate direction) · grass median #498c47 vs
the original's #389243 (richer texture, slightly less deep green) ·
outline rim is scale-hull based (uneven thickness, ~0 at feet) · Godot
glow ≠ three.js bloom curve; vignette gentler than the original's ·
mid-distance terrain still greener/rounder than the original's tan
strata · Geodude renders paler than its sprite · weather not
implemented · blessing altars / roar shrines absent · guardian HP is a
fixed-DPS conversion of the budget · Ember/Water Gun damage inferred ·
signature-move learnset gating (L3/L4) not modeled · camera trauma shake
absent · slide/dive/glide absent · XP/levels/evolution/capture/Lab/zones 2–4
not in this milestone's scope.

## Cycle 6 — original assets + set dressing (2026-10-25, after the user's third "还差很多")

Mandate pivot mid-cycle: stop approximating — acquire the original's own
assets, then dress zone 1 to counted density with them as the art bible.
Characters stay GLB 3D (user ruling, same day: "3D 模型可以，我觉得挺好的").

**Asset acquisition (evidence: `reference/orig_assets/INVENTORY.md`)**
- Runtime capture via CDP (`tools/analysis/netcap.mjs`, 184 requests,
  guest → lobby → run) + bundle URL-rule analysis (`ln()`, `sd()`, `ud()`
  in the exported main bundle). The server serves every asset WITHOUT
  the `?v=` cache-buster, so the full set was mirrored with plain curl.
- PMD sheets: **971** species + **971** portraits (every species with
  `anims` in sprites.json; 54 anim-less species use a `front/` fallback —
  not mirrored). Shiny: zone-1 set (10). Source per in-bundle credits:
  PMD SpriteCollab, CC BY-NC 4.0. Dev placeholders only.
- Environment sets complete: **forest, common (atlas), graveyard,
  desert, volcano**. **`snow/` and `beach/` return 404 for every file**
  — named gap: no such biome directories exist on the server.
- Runtime data tables copied to `reference/data/` (pokemon/moves/
  learnsets/sprites/abilities/types/items) — mechanics source of truth.
- NOT mirrored (named): `assets/models/*.glb` (17 Lavender Tower event
  pieces), `assets/ui/**` UI art + item icons.
- A `.gdignore` in `reference/orig_assets/` is load-bearing: without it
  the Android export reimports ~2,000 captured files (45+ min); the
  export PCK contains 0 orig_assets files (verified).

**Measured density (the cycle's targets)** — orig_11_spawn / orig_13:
cliff wall ≈ 20% of frame width (left), 2 bare-earth terrace patches,
≈ 11–13 distinct decor clusters (oak ×1, flower beds ×2, berry bushes
×2, sunflower ×1, mushroom cluster ×1, spiky shrubs ×2, tuft clumps
×1–2) + tiny scatter. Pieces are BIG (≈ 0.8–1.2 u at 720p). Foreground
bottom-half is relatively empty in the original too.
- Ours (c6_spawn): cliff wall ≈ 17% frame width (west bluff) + east
  bluff, 2 dirt pads visible, ≈ 13–15 distinct set pieces (mushrooms,
  stump, log, sign, flower beds ×3, berry/sunflower clusters ×2, trees
  ×7, tuft cones ~40) — comparable counts/variety. ✅

**Set dressing (`scripts/world.gd`)** — prop kit styled on the forest
atlas (2048×128: tree0–5, bush, berrybush, tallgrass, fern, boulder,
rocks, stump, log, mushrooms, flowersA/B, sunflower, oak, arch,
hollowlog, glowshrooms): flower beds (3 colourways), mushroom clusters
(caps + spots ON the cap surface), berry bushes, sunflowers, stump,
log, boulder, spiky shrubs, wooden sign, vine arch at (0,−19) with
pillar colliders. ~30 authored placements + 46-piece fill (r 14–56
around spawn, min spacing 2.4, off the gameplay clearings). Tree
variants added: 14% pine, 16% sakura.

**Terrain** — 2 authored bluffs in `_base_height` (west wall closing
the spawn basin like orig_11; east wall on the altar corridor) + 3
flattened bare-earth pads (heights solved in `_pad_h`, fed to the
shader as uniforms — a vertex-colour R mask was tried first and
painted half the field tan, because cliff/worn CPU tints share its
range). The terrain shader's base is now the original's own tiles:
`orig_ground.png` (grass), `orig_path.png` (pads/patches),
`orig_cliff.png` (steep faces, triplanar-lite).

**Grass median — closed.** c6_spawn AND c6_combat: **#3b9745** vs
orig **#389243** (ΔR+3 / ΔG+5 / ΔB+3, identical sampler, populations
183k vs 166k). The road there (11 harness runs) found three stacked
causes, in order of discovery:
1. The three new textures had **no .import files** (editor game-runs
   don't import new files here) and the path-tile mix painted the
   high-noise region white. Fixed by a real `--import` pass.
   (A `return` in a debug fragment branch then failed shader
   compilation for 3 runs — Godot forbids `return` in fragment();
   the fallback material's white frames were a red herring.)
2. A **`pow(tex, 2.2)` double-decode**: the sampler already returns
   linear values (proven by an unshaded screen-thirds probe: raw
   sample reads back at the file's sRGB values; pow reads #005e01).
3. **Missing `SPECULAR = 0.0`**: Godot's default 0.5 specular laid a
   blue-grey sky sheen over the whole grazing-angle field, pinning
   R/B ≈ 82/81 no matter the albedo gains. Removing it snapped R
   into tolerance in one run.
Also removed: the detail texture's G/B additive terms (broad mid-grey
channels, not sparse masks — a constant wash).

**Honest residuals after cycle 6**: the original's cliff is sheerer
and warmer (ours reads as a banded stone hill-face; its top stays
grassed) and it has mid-field rock outcrops where ours has dirt pads;
decor pieces are the atlas's designs but low-poly 3D (user-approved
medium) and read slightly smaller at distance; terrain remains a
formula heightfield vs the original's hand-sculpted forest; no
attack/hurt/faint animation cycles; zones 2–4 and the meta systems
(XP/draft/capture/Lab) still unbuilt.

---

## Game feel (user feedback round: "操作手感比较差", 2026-10-25)

**Method**: the original's movement model was mined from the bundle
(REAP: one feature per trace, offsets cited) — it is NOT direct
velocity and NOT a simple lerp; it is an exponential approach to a
target velocity with input-dependent rates, an air-control model
borrowed from Quake-style movement, and a slide/dive on Shift.
Help text confirms Shift = "Deslizar (en el aire, caída en picado)"
— slide on ground, dive in air; Space = jump (hold to glide for
flying/floats types only). Constants table (bundle offsets in
`main-CkI7dQhz`):

| Feel item | Original | Ours (before) | Ours (now) | Status |
|---|---|---|---|---|
| Max ground speed | `gy=6.3` × moveSpeed (module @808495) → eff. 8.16/8.56/8.16 | same effective top speed | unchanged | ✅ MATCHED |
| Ground accel | `vel += (tgt−vel)·min(1, r·4)`, r = min(1,(input?70:40)·dt/max(1,E))·(1−(input?.86:.96)·slip) (@842834); ≈0.573/frame accel, ≈0.327/frame stop @E=8.16 | direct velocity (instant) | original formula verbatim | ✅ MATCHED — harness: frame-1 speed 4.67 vs theory 4.68; stop ratio/tick 0.67 vs 0.673 |
| Land buffer | overspeed after hard landing bleeds ×0.97/frame; hard landing (vy<−8) → buffer 0.12 s | — | implemented (squash anim not ported) | ✅ behavior |
| Air control | add toward input up to 0.9·E along-dir, rate 40·dt·E/8; horiz. cap 1.7·E | direct velocity | implemented verbatim | ✅ MATCHED |
| Gravity | 30 u/s² (module const `dy=30`) | 22 | 30 | ✅ MATCHED |
| Jump | vy = 11·√jumpHeight; jumpHeight base = 1 INFERRED → vy 11, apex 2.02 u, air ≈44 frames | vy 8.6 | vy 11 | ✅ harness apex 1.92, air 38 frames (bands pass) |
| Air jumps | vy ×0.92, count = floor(extraJumps); starters 0 INFERRED | none | implemented (0 for starters) | ✅ |
| Slide (ground Shift) | 0.55 s, cd 0.9 s, vel = dir·E·1.9 (2.3 ice), decay exp(−2.2·dt) (@841505) | invented dash ×2.2 / 0.22 s / cd 1.2 s | original slide verbatim | ✅ harness peak 14.95 (~1.9·E=15.5), decays on curve |
| Dive (air Shift, >1.2 u up) | vy = −34, horiz ×0.35; landing slam scales with fall apex | — | dive implemented; **slam damage system not ported** (no slam in our combat yet) | ⚠️ partial |
| Glide | flying/floats types: hold jump while falling clamps vy ≥ −2 | — | N/A for starters (not flying/floats) | — |
| Facing | NO turn rate: model snaps to velocity dir when speed > 0.5 (@849108) | snapped to INPUT dir | snaps to velocity dir | ✅ harness diff 0 rad |
| Stick mapping | keys-or-stick vector, camYaw-rotated, **normalized — analog magnitude discarded by design** (@838700) | magnitude kept | normalized, same as original | ✅ MATCHED |
| Pad deadzone | 0.15 default (settings clamp 0.05–0.40, @9582) | fixed stick, deadzone 0.12, no rescale | floating stick, deadzone 0.15 + radial rescale, travel 65 px | ✅ MATCHED |
| Camera follow | damp `Ic(a,b,rate,dt)=lerp(a,b,1−exp(−rate·dt))`: target X/Z rate 18, Y rate 10 (co-op 7/5) (@1491450) | single lerp rate 12 all axes | rates 18/10 verbatim | ✅ harness: focus trails behind motion |
| Camera terrain lift | ray samples; lift damps 22 up / 5 down | none | heightfield-based equivalent, same rates (adapted, noted) | ⚠️ adapted |
| FOV kick | target = fov (70) + clamp((speed−8)·0.8, 0, 10), damped rate 6 (@1493562) | formula ok but set instantly | damped rate 6 | ✅ MATCHED |
| Camera shake | trauma-based shake system exists | ported verbatim in cycle 8 (see §1) | ✅ MATCHED |

**Touch UI v2**: floating joystick (origin = thumb-down point,
124 px base / 58 px knob, press alpha 1.0, idle home marker at
0.55 alpha), buttons enlarged (interact 96 px, jump/dash 80 px)
with fill + scale press feedback. Input is consumed in the
player's physics step — no render-rate input lag in-game.

**Performance (feel = frame rate)**: physics interpolation ON
(teleports/spawns reset it); directional shadow map 2048,
positional atlas 1024; MSAA 3D off; set-dressing/props
visibility-range culled at 100 u (fade off); outline hulls and
grass tufts cast no shadows. Headless frame budget (PROXY ONLY —
llvmpipe software rendering, not the Seeker GPU): full feel
harness (load + ~370 sim ticks + 3 screenshots) wall 21.4 s,
0 script errors, 14/14 feel checks PASS. On-device frame rate
still to be confirmed by the user.

---

## Cycle 7 — systems parity from the real data (2026-10-25)

The original's runtime tables (`reference/orig_assets/data/*.json`,
captured cycle 6) replace every hardcoded/inferred system value that
remained. Copies the game actually loads live in `assets/data/`
(pokemon/moves/learnsets/types.json; sprites.json stays reference-
only — model heights already live in ModelRig; abilities/items are
unused this cycle). New code: `scripts/game_data.gd` (data layer),
`scripts/profile.gd` (meta persistence, `user://profile.json`).

**1. Data-driven roster/stats.** Species stats/types/captureRate/
learnsets read live from pokemon.json/moves.json/learnsets.json for
ALL species (the enemy.gd BASE table is deleted). Player derivation
(MECHANICS §2.2): share(x)=stat/bst×6, o=1+(evoStage+growth)×0.12,
maxHp=round((70+45·share(hp))·o), armor=6·share(def)+3·share(spd)
with armor/(armor+45), regen=0.25+0.25·share(hp) (+1.5 family-1
photosynthesis), speed ×(0.92+0.12·share(spe)), phys/spec
0.82+0.2·share(atk/spa), evasion 0.02+0.02·share(spe). Harness
reproduces the CONFIRMED League anchors exactly: starters HP
108/104/108, armor 9.23/7.92/11.12, regen 1.96/0.44/0.46, speed
×1.02/×1.07/×1.02. Move damage = power × **0.54837** × share-factor
× o × level-mult — the single scale calibrated so Vine Whip = the
CONFIRMED 24.8 display value (the bundle's own damage constant was
never extracted: scale INFERRED, anchor CONFIRMED); Ember 23.1 /
Water Gun 22.2 supersede the old inferred 27.0/22.5. Type
effectiveness: DATA 18×18 chart applied per target. Enemy bases use
the §1.3/§4 formulas with JSON stats; flags elite ×4.5 HP/×1.4 dmg,
alpha ×22/×1.8, boss dmg ×2.2 (§1.3).

**2. XP + draft.** Curve unchanged (round(8+5.5L+L^1.8), §2.1).
Level-up sequence per §1.2/§2.3: evolution levels come from the §1.2
formula (a = target evoLevel ?? (stage0?20:34); can-evolve-further →
clamp(round(8+a),16,30); final → clamp(round(22+0.6a),36,50)) —
computed 24→41 (Bulbasaur line), 24→44 (Charmander/Squirtle lines);
evolution consumes NO draft and heals to max(ratio,50%)+30% of the
new max; final forms gain growth +1 at 24/44. Other levels open the
draft: 3 options (4th with Lab choice4), drawn from kit moves (w3),
eligible learnset moves (w2 — eligibility playerLevel×2.6+10 ≥
learnLevel, §2.3; learnset level = chain minimum), move upgrades
(w2, cap Lv8, +10%×pe damage per level — amplitude INFERRED),
vitamins (owned w2 / new w1, cap 10). Rarity per option via the §2.3
roll with pe [1, 1.2, 1.45, 1.75, 2.1]; first option forced
move-class when any exists; reroll 2 / skip 2 (+15 ₽) / banish 1 per
run (+Lab). Empty-pool fallback: heal 20% + 15 ₽ (§2.3 CONFIRMED).
Starting move = first damaging learnset move at L1 (tackle/scratch/
tackle); signature moves are draft-gated as the original does.
Screenshot: `screenshots/c7_draft.png`.

**3. Both capture systems** (the old single hybrid is gone).
League (§5.2): one encounter per zone from the zone pool's families
not yet in the league, spawns at stage-time 50–120 s on a 25–45 u
ring at 0.8× spawn HP, flees after 150 s; lethal damage → weakened
at 1% HP (10 s window); throw (E, <9 u) chance = min(0.97, 0.55 +
captureRate/255×0.35 + attempts×0.20 (+0.15 asleep)); fail →
attempts+1, re-weakened 6 s; 3 fails → flees; window expiry →
recovers 40%; success → joins the persistent league roster
(Profile). Friend Ball (§5.3): alphas spawn at stage-times
150/330/480 (§4.3); lethal → downed at 1% HP (8 s window, expiry =
real death); chance = min(0.95, 0.45 + same terms); fail → revives
at 30% and keeps fighting (attempts persist); success → ally with
power (12+1.1·playerLevel)×(0.75+bst/800)×(1+0.25·(min(3,zone)−1)),
cd (1.8 phys / 1.6 spec)/√atkSpeed; team cap 2 + Lab party; allies
follow through portals. The §3 league challenge layer (timed
type-effectiveness fights) is NOT built — encounters use the §5.2
overworld flow only (documented skeleton choice).

**4. Zones 2–4.** Full progression altar→guardian→portal→next zone
→ victory after zone 4. Zone data (pool/guardians/tiles/palette/fog)
in world ZONES: Z1 forest (guardians scyther/pinsir/nidoking
CONFIRMED), Z2 graveyard (pool gastly/zubat/cubone/geodude;
guardians gengar/marowak/haunter INFERRED from tower data), Z3
desert (guardians sandslash/marowak/dragonite CONFIRMED §4.5),
Z4 volcano (pool growlithe/ponyta/magmar/rhyhorn; guardians
arcanine/magmar/dragonite INFERRED; zone names for Z2/Z4 INFERRED).
Guardian HP = player DPS × [40,50,60,60] s × zone factor
[0.8,0.55,0.5,0.5]; the other two trio members escort as elites.
Stage curves (§4.2): HP base [1,5.5,13,20], spawn cap ×(1+(stage−1)
×0.6) (local ceiling 60), damage factor [1,2,3.1,3.4]; elites none
in stage-1's first 90 s, then p=0.012+min×0.004+(stage−1)×0.03.
Terrain/dressing/minimap/fog rebuild per zone from the original's
own tiles. **Zone-ground fix**: the first zone builds multiplied
each zone's tile by gain = forestAvg/zoneAvg per channel, which
normalized every zone back to forest green (graveyard rendered
(21,104,72) from a (50,60,81) tile); gains are now hue-preserving
scalars (graveyard 0.65, desert 0.40, volcano 0.75 — eyeball-
calibrated against the tiles, no original zone frames exist;
forest's cycle-6 gain untouched). Frames: c7_zone2/3/4.png.

**5. Lab skeleton** (§6). All 24 upgrades in Profile.LAB with the
original's cost rules (ke(x)=round(x×0.85/5)×5 etc.); run gold
converts to stardust at run end via the §6.1 piecewise brackets
(0.04/0.012/0.001 — first implementation misread clamp() as bracket
widths and overpaid, fixed); score = §8 classic tier-0 formula.
Wired effects (fx=true): slot-move, slot-vit, reroll, skip, banish,
choice4, dmg, hp, spd, xp, gold, luck, regen, armor, crit, atkspd,
area, party, revive (once/run at 35% HP). Stored-but-inert
(fx=false, no consumer yet): magnet, research, archive, ult, bag.
Persistence verified on disk; menu shows stardust + league size and
hosts the Lab panel.

**Models**: 24 new GLBs from the same source repo (ivysaur→venusaur
and charmander/squirtle lines completed; zone pools + guardian trios
+ evo forms for alphas). Three rig defects found by A/B probes vs
the raw GLBs and fixed:
- *Venusaur's flower rendered black* — the cycle-5 scale-hull
  outline paints its dark backface over OPEN sheet geometry.
  Hulls are now built from closed surfaces only (boundary-edge
  share < 3%, cached per mesh) and skip transparent materials.
  Probes: c7_probe_venu*.png.
- *Gastly's gas rendered as an opaque black blob* — same hull over
  BLEND surfaces, plus the ×0.52 calibration dimming authored
  translucency. Transparent surfaces now skip both hull and
  calibration. Probe: c7_probe_gastly.png.
- *Graveler stood with its legs flipped skyward* — the procedural
  gait wrote ABSOLUTE bone pose rotations, discarding rest poses;
  PMD-style skeletons carry real rest angles in the limbs (most
  repo models are near-identity and never noticed). Gait now
  composes rest × swing. Graveler also got Geodude's stance
  treatment (arms-down 50°); Gastly/Zubat hover via y_offset.
  Probe: c7_probe_graveler.png; grids: c7_grid_1/2.png.

**Verification**: Test/harness.tscn — 41 checks, all PASS, 0 script
errors (data spot-checks vs JSON; §2.2 anchors; draft shape/flow;
evolution at 24 with the heal rule; league weaken→throw→persist;
alpha down→friend-ball→ally; zone 2 guardian DPS budget exact;
portal→zone 3; zone 4→victory panel; stardust settlement 1000 ₽ →
40 ✦; Lab costs 2975/85 and effects; profile persisted). Two bugs
were caught by the harness and fixed in-cycle: the §6.1 bracket
misread above, and guardians double-collecting kill rewards
(_award_kill ran from both the generic handler and the guardian
handler).

**Honest residuals after cycle 7**: league challenge layer (§3)
absent; allies are unkillable (the original can lose them);
kit-only move gates and move-upgrade amplitude INFERRED; zone 2/4
names and guardian trios INFERRED (no original zone frames/tables
for them); zone ground gains eyeball-calibrated; shared "common"
dressing props (mushrooms, flower pads) appear in all zones; no
attack/hurt/faint animation cycles (procedural gait only); draft/
capture verified by harness drivers, not yet by a human playthrough
on the Seeker.


## Cycle 8 — combat life & meta layers (2026-10-25)

Scope per brief: (1) combat animation cycles, (2) dive slam +
trauma shake, (3) ally lifecycle, (4) league challenge layer (§3),
(5) zone-specific dressing. Every number below cites its source;
bundle offsets are into `main-CkI7dQhz` unless marked news (the
shared chunk `news-BfmMIm3P`).

**1. Combat animation cycles (model_rig.gd).** The rig now runs
three event-driven cycles on top of the gait, all fired by the real
combat events: attack = the existing root lunge (0.22 s jab) +
Bulbasaur's authored "fight" clip; **hurt** (new `play_hurt()`,
called from Enemy.take_damage and Player.take_damage) = 0.22 s
flinch — backward push 0.22 u along the facing axis, side tilt
0.16 rad, squash pulse −10% Y, all sin-pulsed; **faint** (new
`play_faint()`) = 0.7 s ease-out collapse (tip to −1.25 rad +
sink 0.22 + shrink 6%), Bulbasaur's authored "ko" clip when
present. Death flow changed to match the original's corpse
linger (dying[e]=0.35, bundle @738927): `Enemy._die_real` now
emits `killed` immediately but frees the body after 0.8 s of
faint animation (ours is longer than 0.35 so the collapse reads
at our model scale — behavioral approximation, noted). Player
death plays the faint too. Verified: harness C1a/C2a–d/C3a/C14b +
sequenced close-up shots `screenshots/c8_anim_{windup,strike,
extend,hurt,faint}.png` (composite `c8_anim_sequence.png`); faint
probe at k=0.5: rotation.x = −0.9375 rad, world AABB height
0.785 vs ~1.0 upright. (An ease-in curve was tried first and
replaced — mid-collapse sat at −18° and read as nothing.)

**2. Trauma shake — mined and ported verbatim.** `shake(e,t,n)`
@1446581: distance factor `clamp(1 − dist/40, 0, 1)`; raise
`e·factor·0.55·screenShake` (screenShake default 1, settings
@1564777); cap `e<0.15 ? 0.22 : 0.7` (oO=.22 @1436233); trauma is
`max(trauma, min(cap, …))`. Apply/decay @1493252: `trauma −= dt·2`;
`w = trauma²·0.3`; `T = t·26`; offset `(sin(T·1.1)·w,
sin(T·1.7+1)·w·0.8, sin(T·1.3+2)·w)` added to the camera POSITION
(lookAt target unshaken) — ours adds it to cam_pos before
look_at, same shape. Wired events (bundle-confirmed powers):
player hurt 0.12 (player `hurt()` @818329–820600), boss killed
0.8 (@1459689), evolution reveal 0.6 (@1475986), slam (below).
Positional move-VFX shakes (0.04–0.3) skipped as cosmetic noise.
Harness C4a–c/C5c/C13d/C14a (0.8→0.44, 0.12→0.066, decay).

**Dive slam — mined and ported.** Trigger: dive landing with apex
tracked airborne (@846795). `slam()` @828969: cooldown `my` = 2 s
(@808515, dust-only while on cooldown); `o = clamp(fallH/8, 0, 1)`
(hy = 8); radius `(3.2 + 3.3·o)·√area`; damage `(12 + 1.5·level)
· stageMult · slamStat · (1 + 2·o)` with stageMult `j_ = [1, 1.8,
3.2, 4]` (@718961) and slamStat default 1 (@787177); type =
player's first type; stun chance `0.35 + 0.4·o`; shake
`0.14 + 0.26·o`; post-slam iframes 0.3 (lands in our `_invuln_t`).
NOT ported: knockback `3 + 3·o` (enemies have no knockback
channel) and hitstop 0.04+0.05·o (no hitstop system) — residuals.
Stun rides our single status slot at 1.0 s (INFERRED duration;
bundle genome example `applyStatus(t,'stun',1)` @718961); it
freezes like sleep but does NOT grant the capture status bonus.
Harness C5a–d (fall 8 → o=1 → 40.5 dmg exactly, radius edge,
trauma 0.22, counter) + C6a–c (real dive landing fires it).

**3. Ally lifecycle — the premise was inverted by evidence.**
The brief assumed the original's allies take damage and faint.
They do not: the ally record `jh.make()` (~@523543) is
`{species, name, types, bst, physical, slot, x, y, z, fx, fz,
anim, timer, flash, squash, hop, hx, hz, tx, tz, kills, damage,
bond}` — **no hp field exists**; nothing in the bundle ever
damages an ally (enemies only call `player.hurt()` @871823);
`jh.faint()` is the DOWNED ALPHA's window expiring, which cycle 7
already implements. Our "allies unkillable" therefore MATCHES
the original — the cycle-7 residual claim is withdrawn. What was
actually missing, now implemented: **bond** — ally kills counted
(`onAllyKill` @528148), thresholds `Eh = [25, 75, 150, 300, 500]`
(@517639), each level +10% ally power (§5.3), banner + no other
feedback in ours (original: toast + heart burst). Harness
C7a–d (mult 1.0→1.1→1.2 at 25/75, live kill credit). **Minimap**:
allies now plot as green dots #7aff9a (bundle @2034623) instead of
red enemy dots. Spec discrepancy found: §5.3 said shiny ally
power ×1.5; the bundle's `Dh = 1.2` (@517639) — bundle wins (no
shiny allies exist in our game). Retained behavioral
approximation: our ally formation/engagement (anchor 3.2 u,
engage <26 u) vs the original's facing formation offsets and
<16/<14 u targeting — noted, not rewritten.

**4. League challenge layer (§3) — implemented.** Mechanics mined
from the bundle meta class (main @1565481–1580100) + the roster
table in the shared chunk (news @99430+): challenges are
`{desc, counter, goal}` per roster entry (object or array);
`leagueReady()` = entries with a challenge whose every part is
met (`yA` @1568343, parts via `vA` @1568236); counter reads are
special-cased in `_A` (@1568050: `league` = league size excl. dex
151, `birds`, `tier_<biome>`). Goals ported VERBATIM for all 15
modelled species (Profile.CHALLENGES; descs are our zh
translations of the Spanish roster strings): pidgey runs 4 ·
rattata kills 20000 · sandshrew dodges 120 · zubat best_healed
4000 · diglett rocks 15 · geodude rocks 50 · gastly
best_reactions 600 · growlithe runs 20 · ponyta maxTime 900 ·
cubone boss_desert 4 · rhyhorn league 20 + rocks 100 · magmar
league 25 + best_burned 6000 · pinsir league 20 + best_alphas 4 ·
scyther kills 150000 · snorlax league 30 + berries 500.
Lifetime counters now tracked in profile.counters (original
count() 'add'/'max' modes, hA @1567900): kills, runs (settled at
run end, win or lose), alphas, bosses + boss_<biome>, captures
(counted in joinLeague, as the original), dodges (evasion rolls),
evolutions, slams, gold; max-merged at run end: maxTime,
best_healed (player regen accumulation), best_burned /
best_poisoned / best_alphas from per-run event counts.
**Encounter gating changed**: `_spawn_league` now draws only
from challenge-complete species (was: any non-league pool
species) — on a fresh profile NOTHING spawns until a first
challenge completes (pidgey at 4 runs is the earliest), which is
the original's bootstrap grind. Parts whose counter needs an
unbuilt system (rocks = rock-smash interactables, best_reactions
= elemental reactions, berries = berry pickups) are flagged
unsupported: shown in the unlocks screen, never completable —
diglett/geodude/gastly/rhyhorn/snorlax encounters stay gated
until those systems exist. **Unlocks screen** (menu: 联盟挑战 ·
解锁） lists all 15 with per-part progress + state; completed
captures also become **playable starters** (original:
joinLeague unlocks the family; family→species via
GameData.species_key_for_family, magmar family 240 → magmar).
Also fixed while wiring: §5.2's throw判定 is `rand < min(cap,
chance) OR chance >= 1` — our code lacked the sure-capture
clause; friend-ball keeps the bundle's min-only form.
**Guardian reward correction**: cycle 7's log claimed the
double-award was fixed by relying on a generic connection; in
fact the guardian's `killed` connects ONLY to
`_on_guardian_killed`, which never awarded — guardians paid no
XP/gold/kill credit at all. `_award_kill` now runs there (once),
with §4.4 boss gold `(5 + rand·10) × 3 × goldMult`. Harness
C13a–d + C9a–g (challenge completes end-to-end: runs banked →
finish → pidgey done → encounter spawns pidgey → weaken → throw
at chance 1.30 ≥ 1 → in league, captures=1, starter button).

**5. Zone dressing.** The shared "common" set is gone: zones 2–4
build from their own mixes (same proven placement skeleton):
graveyard = tombstones / dead trees / bones / glowshrooms,
desert = cacti / sandstone boulders / dry shrubs / bones,
volcano = obsidian / lava rocks / charred stumps / dry shrubs —
subjects read off each biome's env atlas (graveyard tall bare
trees, desert small cacti-class sprites, volcano charred
trunks). 8 new prop makers in the existing kit style; fill kinds
are per-zone too. Harness C11a–i (counts: z2 tombstones 19, z3
cacti 19, z4 obsidian 20; zone 1 set frozen — arch 1, no
tombstones). `_build_props` trees/rocks/bushes still vary only by
palette per zone (their subjects are generic); dressing density
is unchanged from cycle 6 (count-matched).

**Verification**: Test/harness.tscn — **53 checks, all PASS, 0
script errors** (4 cycle-7 regression spot-checks + 49 cycle-8:
rig cycles, faint linger/free timing, trauma caps/decay, slam
numbers + real dive landing, ally bond, guardian awards,
counters merge, challenge end-to-end, unlock rows = 34, zone
dressing counts, starter unlock). The rig faint-curve tweak
landed after the harness run; it is pose math only and was
re-verified by the shots run + numeric probe above. Test/
deleted after the run (record = this log + screenshots).
APK rebuilt: **48,164,890 bytes** (from 48,140,314), same cert;
contents audit: 433 entries, **0 reference/ files, 0 Test/
files**, all 7 scripts present as .gdc.

**Honest residuals after cycle 8**: slam knockback + hitstop
not ported (no channels for them); hurt has no red/white flash
(the original flashes sprites — our per-instance materials make
a clean flash costly; flinch+squash carries the read); player
hurt does not grant the bundle's 0.45 s post-hurt iframes
(pre-existing; only slam's 0.3 s was added — touching the hurt
path rebalances every fight and needs its own verification
round); ally formation/targeting remains our approximation;
rocks/reactions/berries counters await their systems (5 species
stay gated); best_healed counts regen only (original counts all
recovery incl. lifesteal/berries — we have no other heal source
in-run today); counters flush at run end / capture / Lab buy
(a hard app kill mid-run loses that run's increments — the
original's keepLive has the same shape); §3's wider meta
(titles/quests/medals/biomes tiers) is out of scope for the
challenge gate and remains unbuilt.

---

## Hotfix — player Charmander renders at ~1/4 size, muddy brown (user report 2026-10-25 18:01)

**Symptom (user's Seeker screenshot)**: player Charmander under its HP
pill at ~1/4 expected height, body muddy brown instead of orange,
tail flame red; nearby enemies (Sandshrew, Geodude-line) correct in
size and color.

**Root cause — the fit measured fiction.** `model_rig._fit()` scaled
each model by the bind-pose AABB merged through the node chain.
Charmander's GLB chain carries an authored 2.54x node scale
(`pm0004_00`) ABOVE its skeleton, so the node-space box reads
5.206 u tall while the skinned render is 1.59 u (visibility-diff
silhouette, Test/probe.tscn). Fit scale = 1.3 / 5.206 = 0.2497 — the
1/4-size player. The same fiction poisoned grounding (the fitted
Charmander floated ~1 u in the probe). It shipped because every
prior verification frame used Bulbasaur as the player — the one
species on a hand-measured "fixed" fit — and enemies with the same
defect (Squirtle at 0.88x) read as natural variety. Player-path vs
enemy-path code is identical; the divergence was per-species data,
not code.

**Rejected fix**: a runtime skinned AABB in GDScript. Evidence
(Test/fitdebug, one-off, removed after use): the import's skin bind
poses live in file space while skeleton global poses are converted
(bind Hips (0.198,-0.214,0.015) vs global (0,0.015,0.214) — an axis
permutation apart), so the textbook composition explodes to
(19.5, 18.0, 20.1) u or returns the bind box, never the 1.59 u
render. Two formula variants falsified on data; not shipped.

**Fix — empirical natives for all 35 species.** Test/probe.tscn
measures each species' RENDERED height (`native`) and lowest-point
offset (`feet`) at model scale 1 by visibility-diff silhouettes
(pulled-back camera + `--dist` for tall/giant authored models);
`_fit` is now `scale = height x mult / native`,
`position.y = -feet x scale` (+ `hover` for Gastly 0.35 / Zubat
0.55, replacing their y_offset grounding hacks; Geodude/Scyther/
Nidoking y_offsets deleted — feet supersedes them). Four species
are Sketchfab centimeter-scale exports whose silhouettes clipped
every standard frame and needed distance measurement: Rhyhorn
native 117.50, Magmar 155.51, Snorlax 20.85, Arcanine 5.81 (the
first-pass table had them at 1.66/6.30/3.57/5.09 — all wrong, all
caught by the fitted-probe verification loop, none shipped).
Bulbasaur's hand-measured native 0.7 was also wrong (probe: 0.833;
it rendered 1.52-1.60 u against its 1.3 spec) — corrected to 0.833,
feet -0.03.

**Color.** Charmander's texture is honestly orange (224,160,96),
but under ALBEDO_SCALE 0.52 (cycle-5, tuned on Bulbasaur) plus the
scene's green-bouncing ambient it rendered (149,124,95) tan at full
size — and (114,94,75) mud at 1/4 size. Added a species hue tint
(HUE_TINTS mechanism): Charmander (1.15, 0.83, 0.70) -> rendered
body median (177,102,68), squarely in the sprite orange family.

**Verification** (Test/analyze_probe.py over fitted-probe shots):
35/35 species render within ±15% of cfg height with grounding
within ±0.12 u — starters: Charmander 1.315/1.30 ground -0.013,
Squirtle 1.092/1.06, Bulbasaur 1.281/1.30 ground -0.030, Snorlax
2.121/2.12. Standing in-game check (Test/harness.gd +
Test/check_starters.sh + .py; the harness boots the real game with
each starter as PLAYER, freezes every world node, visibility-diffs
the player): **bulbasaur PASS h=1.395 rgb=(131,182,100);
charmander PASS h=1.353 rgb=(177,102,68); squirtle PASS h=0.890
rgb=(76,135,160)** (Squirtle reads low in the frozen idle pose;
probe says 1.092 — inside the ±20% band either way). Per the audit
rule the harness is NOT deleted: Test/ stays in the tree and export
presets exclude it.

**Side observation — "flopped" Geodude-line body (same screenshot)**:
VERDICT = the faint collapse mid/late pose, not a defect. Harness
faint capture (Graveler, kill via the real path): at _faint_t =
0.387 the model rotation.x is -0.99994 vs the design curve
-1.25 x ease-out(0.387/0.7) = -1.0003, and the scale shrink matches
the formula to 3 decimals. A fully collapsed body lies at -71.6 deg
plus a -0.22 sink, freed at ~1.5 s — exactly the "big body flopped
on its side" in the user's frame.

APK rebuilt: see PHASES.md hotfix line.


---

# Cycle 9 — independent-audit fixes (2026-10-25)

Spec: ~/workspace/claude-audits/spritebonk-cycle8-2026-10-25/AUDIT_REPORT.md
(2 VERIFIED / 5 OVERSTATED / 1 UNVERIFIABLE + 15 unreported gaps).
All bundle offsets below were re-verified this cycle with
`tail -c +<offset>` against the real bytes — the audit was right
that the team's earlier "@offsets" were character offsets.

Verification: Test/harness.gd mode "cycle9" (permanent, in-tree)
drives the real game flow end-to-end — runs start through
start_game, deaths through take_damage, the guardian through
summon_guardian + take_damage, the Lab revive through the real
lab_buy, movement through synthesized touch events (primer +
joystick drag + dash button), the dive through a real SPACE key
event + the touch dash button. No counter injection, no fixture
counting. Final evidence: Test/out/c9_final.log (full run) plus
per-phase logs (c9_slam2 / c9_guardian2 / c9_revive2) — 28 checks,
all PASS. Three harness oracles were WRONG during development
and are called out where they occur below (is_league is a mode
enum, 'chests'/'slams' are profile counters not run counters) —
each was fixed to read the game's real state, never the reverse.
Mutation spot-checks (process rule): STAB 1.25->1.0 in
combat_hit => slam + ally damage checks RED (dealt 40.699, the
pre-pipeline number); revive_reset() call removed => 4 revive
checks RED (latch stuck at _faint_t=0, hurt flash swallowed —
the audit's exact symptom); league pool reverted to the zone
filter => GLOBAL check RED (only pidgey ever spawned). All
restored after.

## Audit §1 (anim close-out OVERSTATED) → combat-response rework
- model_rig.gd: hurt = flash 1 (decay 6/s) + squash (player 0.5 /
  enemy 0.6, exp(-10t)) per bundle updateProxy @336849; the
  invented pos.z flinch is DELETED (the bundle holds the hurt
  frame, no pose flinch). Enemy corpse: dying = 0.35 s fade
  (@739397 / @340280 w = 1 - dying/0.35) replacing the invented
  0.22/0.7/0.8 numbers; corpses no longer tick while the world
  is paused/hitstopped (audit gap: corpse-during-pause).
- Player hurt() @819063/@821025 now complete: evasion → dodge
  (iframes 0.25, "-" floater color 11069695, dodges counter);
  hit → iframes 0.45, flash 1, squash 0.5, r.kick(.006),
  shake(.12), ui.damageFlash() (new fullscreen red overlay).

## Audit §2 (trauma VERIFIED core; §8 residuals) → channels built
- hitstop(e): hitstopT = max (bundle @1448302). Slam uses
  0.04+0.05o (only when an enemy was hit), boss kill 0.5
  (@1460549). While it runs: world clock, spawner, projectiles,
  lifecycles and all bodies freeze; UI continues.
- camera kick: the bundle's kick() is a CHROMATIC-ABERRATION
  punch on the post chain (@108253, cap 0.012), not FOV — ours
  now drives a `chroma` uniform in the vignette shader (screen
  texture RGB split). Kick values: hurt .006, slam .008+.012o.
  Decay rate INFERRED (exp(-5t)) — the bundle shows the raise
  and cap, not the renderer's decay constant.
- shake() reads settings (bundle @1447934): shakeOn gate +
  screenShake multiplier, profile-persisted, defaults true/1
  (@1566819), menu toggle added （画面震动 开/关）.
- slam knockback 3+3o (new Enemy knockback channel: velocity
  integrated with collide_circle, decay rate INFERRED exp(-7t));
  ally knock 2 (land) / 1 (shot) on the same channel.
- evolution morph: continuous shake(.02) during the morph
  window + flash 1 + iframes 2.6 on completion (@1476150);
  reveal shake(.6) was already wired.

## Audit §3 (slam OVERSTATED) → P1.1 combat pipeline
- player_slam rewired through world.combat_hit (bundle strike
  @722351, attacker side): base x damage x physical -> STAB
  x1.25 (slam type = player's types[0]) -> crit -> defender
  pipeline (type chart, sleeping x1.8 + wake, frozen x1.2 — both
  were missing entirely). slamStat now a real player field
  (passive "slam" stat). Player squash .9 at slam start,
  r.kick(.008+.012o), hitstop on hit.
- Harness proof (cycle9): Lv1 Bulbasaur, fallH 8 (o=1) vs
  Rattata — dealt 50.8733490566046 vs pipeline-expected
  50.8733490566038 (the audit's ~50.6 derivation made exact
  against live phys/damage stats); knockback _kb_vel = (6,0,0)
  = 3+3o; hitstop_t = 0.09 = 0.04+0.05o. A REAL dive (SPACE
  key -> apex -> touch dash button) fires a slam through the
  player's own controller. The old harness's "40.5 exact"
  expectation was the PRE-pipeline number and is retired.
- SCOPE NOTE (honest): normal moves keep the §2.2-calibrated
  path (move_damage with DMG_SCALE 0.54837, anchored to the
  Vine Whip 24.8 screen value) — they already apply damage /
  physical / type chart / crit through their own code. The
  audit's slam finding is closed; unifying both paths onto
  combat_hit would invalidate the §2.2 calibration and is NOT
  done. combat_hit also carries the passive hooks (lowHp,
  typeBoost, pickup critAdd) shared with _roll_damage.
- Status engine extended (moves.json ailment vocabulary):
  paralysis (speed x0.5), confusion (heading wobble), freeze
  (full stop, x1.2 taken) and stun now apply and COUNT
  (paralyzed/confused/frozen) — previously only sleep/burn/
  poison existed, so five roster challenge families could never
  progress. Durations INFERRED (moves data carries none);
  single-status-slot simplification kept (bundle has per-kind
  timers).

## Audit §4 (ally OVERSTATED) → P2 ally rebuild
- Power/cooldowns are the bundle's LIVE formulas (power(e)
  @519822: (12+1.1*playerLevel) x (0.75+bst/800) x stage x
  bond x shiny x lemonade; cooldown (1.8|1.6)/sqrt(atkSpeed))
  recomputed at every attack — the capture-time snapshot is
  deleted. Bond [25,75,150,300,500] -> +10%/level inside power.
- Attacks resolve like the original: physical = hop-lunge into
  land() AoE (r 2.6*sqrt(area), combat.hit typed types[0],
  J_-table status @20%, knock 2); special = homing projectile
  exploding at r 2.2*sqrt(area) (status @20%, knock 1). The old
  single-target untyped poke is gone. J_ statuses our engine
  models map 1:1; wet/root/curse/healblock/knock/charm have no
  status in this build (documented, ally_status_for).
- Kill credit via lastHitBy slot semantics (@741771): every hit
  rewrites the mark; ally-marked kills feed the ally's bond.
- Minimap ally marker: r = 6*g px, fill #7aff9a, stroke #1d1236
  2px (@2038659) — cycle 8 had 4px and no stroke. Chest markers
  added (the original notifies chest spawns on the minimap).

## Audit §5 (league OVERSTATED) → P1.2 global pool + data
- Encounter pool is the bundle's GLOBAL leagueReady()
  (@1049619: filter != 150, uniform pick) — every modelled
  roster species whose challenge is complete and whose family
  is not yet in the League. The zone filter is deleted.
- Honest recount (audit correction accepted): pre-cycle-9,
  EIGHT of 15 modelled league species were gated, not five:
  diglett, geodude, gastly, rhyhorn, snorlax, magmar, pinsir,
  scyther.
- Roster data extracted from the bundle (news chunk tables,
  merged @118542): assets/data/roster.json — all 79 family
  entries {passive, kit[4], rank, challenge parts}. Profile
  challenges are BUILT from it (the 15 hand-written entries are
  deleted). Kits for unlocked species now come from the roster
  (previously starters only); passives for ALL species come
  from assets/data/abilities.json (161 entries extracted from
  the bundle's ay table incl. its Object.assign chunks: name,
  desc, mods, hooks). The hardcoded photosynthesis +1.5 regen
  is REPLACED by the data mods (regen +1.5 arrives by data;
  harness-anchored Bulbasaur regen unchanged). NOTE: an earlier
  hand-transcribed ability list contained wrong values
  (torrent-shell armor +4 vs real +15); only machine-extracted
  data is used.
- Passive systems wired: mods (physical/special/damage/
  moveSpeed/attackSpeed/maxHp/armor/critChance/critDamage [add
  arm fixed — sniper/hyper-cutter were silently dropped]/
  evasion/area/xpGain/gold/regen/luck/slam/projSpeed/
  extraJumps/healing/statusChance/eliteDamage/lifesteal) and
  hooks: lowHp x1.4 under 40% HP, typeBoost, pickup critAdd
  min(.15, gold/1e4), photosynthesis leech (0.4% max HP per
  grass hit, 0.2 s throttle), dmgTaken (phantom .8 etc.),
  multiscale fullHp halving, sturdy once-per-run lethal save,
  contact statuses (poison-point/static/flame-body/effect-spore
  at 30%, nearest-enemy approximation — take_damage carries no
  attacker), lifesteal on damage dealt, eliteDamage on
  guardian/alpha hits.
- NOT ported (named): tick-AoE passives (tentacles, arena-trap,
  chlorophyll pollen, serpent-glare gaze, loyal-guard/beacon/
  intimidate/static auras), weather passives (no weather
  system), shieldMax (no shield system), pickupRange (no
  pickup entities), statusDamage, thorns, flinch, knockback,
  projectiles+1, gender (rivalry's second half), glide
  (tailwind/levitate desc), magic-guard (no ground hazards /
  player DoT), guts (no player status system), presage execute,
  adaptability STAB 1.5625 (no Eevee-line carrier modelled).
- Reachability: league goals are roster LEAGUE-size parts
  (20/25/30 for pinsir/magmar/snorlax...). Pre-cycle-9 only 12
  of the modelled families could EVER complete. Twenty new
  species are modelled (GLBs + probe-measured fits): caterpie,
  weedle, spearow, ekans, nidoran-f, vulpix, jigglypuff,
  oddish, paras, venonat, meowth, mankey, poliwag, abra,
  machop, tentacool, slowpoke, doduo, farfetchd, magikarp —
  all with completable challenges, taking non-gated
  completable families to 32 >= 30, so the 20/25/30 gates are
  reachable in sequence. Harness proof: magikarp's challenge
  completed through 25 REAL runs, then _spawn_league produced
  magikarp — a species in NO zone pool — through the global
  pool. Harness: after 25 real runs the encounter loop drew
  growlithe, charmander, doduo, pidgey, magikarp — the starters
  and growlithe complete via the roster's OWN runs challenges
  (2/4/20), which the pre-cycle-9 hand table had obscured.
- STILL GATED (named blockers, unchanged in kind): diglett /
  geodude / rhyhorn (rocks — no rock-smash system), gastly
  (best_reactions — no elemental-reaction system), snorlax
  (berries — no berry system), dragonite (legendaries part now
  counts final-zone guardian kills; tier_<biome> parts use our
  zone-clear = tier 1 mapping, so tier>=2 parts for
  aerodactyl/articuno stay gated), mew (league 78 — endgame by
  design), zapdos/moltres (birds counter — no dedicated bird
  encounter system; kills of the modelled bird lines do not
  feed it), event/ult counters (ultimates, rainKills, soaked,
  win_forest) unsupported and flagged as such in the unlock UI.

## Audit §5 (guardian rewards) → P1.3 bundle rewards
- onBossKilled @1462726 implemented: 20 coin pickups of
  ceil(5*stage*gold) (credited at once — no walk-over coin
  entities in this build; floater shows the exact total),
  1 rare candy -> gainLevel(), free chests = 1 at the corpse
  + 1 per roar (guardian roars implemented at 2/3 and 1/3 HP
  crossings — trigger thresholds INFERRED, the bundle only
  shows boss.roars consumed), hitstop(.5), shake(.8), bosses +
  boss_<biome> + tier_<biome> + legendaries (final zone).
  Chests open on walk-over and grant a random vitamin through
  the draft's grant path; 'chests' counter counts opens.
- The sourceless (5+rand*10)x3 guardian gold is DELETED.
  Harness proof: gold delta exactly 100 (20 x ceil(5x1x1)) in
  zone 1; chests spawned == 3 == 1 + 2 roars; a chest opens on
  walk-over and increments the lifetime 'chests' counter; the
  candy level fires; boss-kill hitstop_t == 0.5.

## Audit §6 (dressing OVERSTATED) → per-biome atlas dressing
- Forest leaks REMOVED from zones 2-4: sign, log, vine arch,
  spiky shrub — and bones from the graveyard (the audit's
  explicit point; desert bones are the atlas skull/ribcage and
  stay). Twelve new makers give each zone its signatures:
  graveyard obelisk / candles / urn / purple tree / willow /
  bellflowers; desert hoodoo / Joshua tree / agave / prickly
  pear; volcano lava crystal / fireflowers. The graveyard's
  corridor gate is now two tombstones (colliders ride their
  set entries; the arch's orphan colliders are removed).
  Zone fills rebuilt to match. SECOND, BIGGER LEAK FOUND while
  verifying: _build_props (the base scatter under all zones)
  planted ~110 forest trees (round canopy / sakura / pine) in
  EVERY zone, plus leaf-blob bushes — zone-tinted materials did
  not save the silhouettes. The tree slot is now zone-shaped:
  forest trees only in zone 1; bare dead trees (dark trunk +
  angled branches) in the graveyard; sand boulders in the
  desert; charred stumps in the volcano. Bushes (dry scrub /
  charred), tufts (dry tan / basalt) and ground flower dots
  (ember palette in zone 4) follow the same rule. Composite:
  Test/out/zones_composite.png (zones 1-4); minimap crop:
  Test/out/minimap_crop.png (green ally marker with dark
  stroke + gold chest dot visible beside the player).

## Audit §7 (harness UNVERIFIABLE) → standing harness
- Test/ is permanent (hotfix rule kept). Cycle-9 mode added;
  checks are behavioral end-to-end (see header) and
  mutation-sensitive — spot-verified by deliberately breaking
  STAB, the revive reset, and the league pool (see header) and
  watching the matching checks go red, then restoring.

## Unreported gaps found & fixed this cycle
- crits were never counted anywhere (player._roll_damage now
  counts) — spearow/farfetchd challenges were unprogressable.
- Lifetime status counters were never flushed at run end
  (only best_burned/best_poisoned merged); the flush now
  carries burned/poisoned/slept/frozen/paralyzed/confused/
  crits in BOTH hA modes (add + best_ max), plus healed,
  best_kills, kills_<biome> per kill, alphaCaught on Friend
  Ball capture, maxLevel on level gain, speciesPlayed per run.
- Evolving into an unmodelled form (Pidgeot, Golbat, Golem,
  Rapidash, Rhydon...) would have crashed rig setup — evolve
  is now guarded (coverage gap logged, not hidden).
- critDamage passive mods are ADD-based in the data; the old
  mul-only arm silently dropped sniper/hyper-cutter.
- Player render heights for the new species use the original's
  sprite fh/32 anchor; 19 of 20 are probe-measured (native/feet)
  and pass the fitted-probe analysis (height ratio within ±15%,
  grounding within 0.12 u): caterpie, weedle, spearow,
  nidoran-f, vulpix, jigglypuff, oddish, paras, venonat,
  meowth, mankey, poliwag, abra, machop, tentacool, slowpoke,
  doduo, farfetchd, magikarp. EKANS IS PARKED (named blocker):
  its GLB is authored as a vertical pole (body length along
  +Y); laid flat with a rot_x it points its head at the camera
  and the render-projection fit cannot measure a Z-aligned
  body — it needs a geometry-space fit. Its roster entry and
  challenge remain; it is not in SPECIES, so it cannot spawn.
  Completable non-gated families: 12 + 19 = 31 >= 30.
- FACING BUG (found via the Segment Z strips): every modelled
  GLB faces +Z natively (verified from fitted probes, all 54),
  but the yaw table carried PI for charmander/charmeleon/
  charizard and PI/2 for rattata/raticate — those five walked
  backward/sideways in game. All five now yaw 0.0. The hotfix
  starter check still passes 3/3 (Test/out/check_starters_c9
  .log); Charmander's sampled body color is now its FRONT
  (161,100,66) instead of the back (177,102,68) — in tolerance.
  The earlier yaw values appear to have been read off a probe
  variant whose camera sat on the other side.

## Segment Z — de-stiffening (user feedback 2026-10-25 19:14)

The procedural gait was pure sine bone-swinging on a free-
running phase; the audit-restored TIMINGS (hurt 0.3 s, flash
decay 6/s, corpse 0.35 s) are untouched — only motion curves
changed.
- FOOT-SKATE: stride phase is now phase-locked: phase rate =
  pi * ground_speed / stride_len, stride_len = height * 0.55
  (0.8 for hoppers) — one footfall per stride_len of travel by
  construction. (At the strip speed 3.2 u/s, Rattata's stride
  went from a free-running 1.32 Hz / 1.21 u-per-step mismatch
  to 2.9 Hz locked at 0.55 u/step.)
- BODY LIFE: bob rides |sin(phase)| (2x stride frequency,
  phase-locked — the free-running bob phase is gone for gait
  rigs), roll sin(phase)*0.05, pitch sin(2phase)*0.02, idle
  breathing (scale sine 1.7 rad/s, +-1.2%) on every rig, idle
  head-turns (every 3.5-7 s, +-0.3-0.55 rad for 1.0-1.6 s,
  spring-returned) while nearly still.
- SPRINGS: tail chain + head chase their targets through a
  spring-damper (k=26, c=6) — lag and overshoot instead of
  rigid sine tracking.
- ARCHETYPES (cfg gait / GAIT_BY_SPECIES): quad + biped
  walkers (anti-phase legs, lagged shins, counter-rotated
  feet, opposite arm swing); hopper (legs together, body arc
  max(0,sin)*0.16, landing squash 0.30 at the air->ground
  wrap); hover (near-still limbs, gentle bob, banking roll =
  clamp(-yaw_rate*0.9, +-0.5) on turns); serpent (no leg
  swing, root yaw sway sin*0.10). Walkers get a 0.07*amp step
  squash at each footfall; the player gets a 0.22 landing
  squash on plain falls > 4 u/s (dive landings keep the
  slam's own 0.9).
- LUNGE: 0.30 s curve — 0.08 s anticipation pull-back (-0.10),
  then a thrust to 0.42 with an overshoot-decay tail (was a
  linear 0.22 s jab at 0.35).
- EVIDENCE: sequenced strips before/after for rattata
  (walker), pidgey (hopper), charmander (starter biped):
  Test/out/strip_<sp>_montage.png (top row = pre-Z gait with
  the yaw fix, bottom = Segment Z). check_starters stays 3/3.
- HONEST GAP: phase-locking removes the gross skate and the
  body now breathes/sways/springs, but this is still
  procedural sine+spring work on bind poses — there is no
  foot IK (feet do not plant through the contact phase), no
  authored anticipation in the limbs themselves, and models
  whose bind pose is a T-pose (several repo GLBs) keep stiff
  arms between swings. Closing that gap needs per-species
  leg-length calibration for IK or authored clips; neither
  exists in the source GLBs (only Bulbasaur ships clips).

# Hotfix — blue-screen APK (2026-10-25, post-Cycle 9)

**Symptom.** The Cycle 9 APK (53,443,778 B) opened on the user's
Seeker to a uniform blue — pixel-exact the project's
default_clear_color #87cefa — with no sky, no HUD, no menu.
Clearing the app data changed nothing (fresh user dir, same
screen), which killed the inherited-save theory. All builds
through the 19:08 hotfix rendered fine on the same phone.

**Root cause (proven, not inferred).** During Cycle 9's Segment Z
and mutation work, backup copies of production scripts were left
in `Test/out/zbak/` (`model_rig_before/pre_z/z.gd`,
`player_pre_mut.gd`) — and they still declared
`class_name ModelRig` / `class_name Player`. A subsequent editor
scan rewrote `.godot/global_script_class_cache.cfg` resolving
those class names to the BACKUP paths. Exports exclude `Test/*`,
so the shipped APK's baked cache pointed ModelRig/Player at
files that do not exist in the package. world.gd (the main
scene's root script) references both classes, so in the export it
failed to parse — `Could not find script for class "ModelRig"`
(x N) -> `Failed to load script "res://scripts/world.gd"` -> the
main scene instantiated scriptless, `_ready` never ran, and the
frame stayed the clear color forever. The editor/harness stayed
green because the backup files exist on disk in the project — the
harness was silently running the zbak copies (the rig copy is
byte-identical to scripts/model_rig.gd; the player copy predates
only the Segment Z landing-squash addition).

**Discriminator.** A desktop Linux export of the pre-fix tree
(same exclude filter, fresh HOME) reproduced the device symptom
exactly: identical parse errors in the boot log and a frame that
is 99.9% #87cffa (`Test/out/linux_export_prefix_bluescreen.png`).
Export-path bug, not Android/GPU-specific; shaders and the save
system were never involved.

**Fix.**
- `Test/out/zbak/*.gd` renamed to `*.gd.bak` (content preserved,
  class registration defanged). Standing rule: NEVER leave a .gd
  copy of a class_name script anywhere in the project tree.
- `.godot/global_script_class_cache.cfg` deleted and regenerated
  via a clean import: all 8 classes now map to res://scripts/*.gd.
- Standing gate `Test/check_class_cache.sh` (fails on: any
  class_name outside scripts/, any .gd under Test/out/, any cache
  path outside scripts/ or missing on disk) wired into
  android/build_apk.sh before the export step.
- Defense in depth (not the bug): Profile.load_profile now stamps
  PROFILE_VERSION=2 and coerces every known key to its schema
  type, so a wrong-typed value from any older/corrupt save resets
  to default instead of crashing a downstream cast.

**Re-verification (all against the true scripts/).**
- Cycle 9 harness, fresh user dir: 28/28 PASS, 0 script errors
  (Test/out/c9_postfix.log) — retro-validates the Segment Z
  player.gd additions the poisoned cache had bypassed.
- Seeded Cycle-8-schema profile (league/captured/lab/counters)
  boot: clean, HARNESS DONE, starter render check PASS
  (Test/out/boot_rich_postfix.log).
- Linux export post-fix: boots to the full 3D world + HUD +
  starter menu, 0 script errors
  (Test/out/linux_export_postfix_menu.png). A "Linux" preset
  (same exclude filter) was added to export_presets.cfg for this
  and kept as the standing export-side smoke test.
- Rebuilt APK: 53,443,778 B (byte count coincidentally identical to the broken build — the cache paths shrank as profile.gdc grew; distinguishing fingerprint is sha256 c4e3a240b3b872b4cc2b0b3fbf752d695aebcc18291cf5dafa030666fca5b150), same cert (b05b80e1...a232), 573
  entries, ZIP clean; its baked class cache extracted and
  verified — all 8 classes under res://scripts/, no zbak/Test
  paths inside.

# Cycle 10 — HP-bar alignment (user feedback 2026-10-25 22:27)

User, on the fixed Cycle 9 build (Seeker): "角色和血条重叠了" —
in a horde fight our thin red enemy bars sit at body height across
the models and stack illegibly; the player's own world-space bar
sits at the model's feet (y=0.14) across the enemy being fought,
burying a damage floater. This section supersedes the pre-audit
table row (line 77, "Enemy HP bars … ✅ MATCHED") — that claim was
never bundle-verified.

## Spec mined from the original bundle (main-CkI7dQhz, 2,154,272 B;
all offsets byte offsets, verified with tail -c)

**Regular enemies: NO world-space HP bars at all.**
- Enemies render as instanced sprite billboards (batch class Ul
  @126067). Per-instance attributes are exactly iPos(3), iSize(2),
  iUV(4), iFx(4), iTint(4), iLook(2) — there is no HP channel.
- The sprite fragment shader Rl (@113906; main() @122462) draws
  only: sprite texel, outline by class code (vFx.z: 1 gold elite,
  2 red alpha, 3 white player, 4 cyan capture, 7 violet Dominant,
  8 green Summoner, 5/9+h shiny), death dissolve (vFx.y), mastery
  looks, status tint (vTint), bottom grounding shade, hit flash
  (vFx.x), fog. No bar branch exists. The vertex shader Ll
  (@112666) positions the quad from iPos/iSize with squash in
  iFx.w — again no bar.
- Enemy HP is communicated by: damage numbers (vfx text sprites,
  setting `damageNumbers`), hit flash + squash, and the red-flash
  decay already aligned in Cycle 9. Floating event texts
  ("¡Muy eficaz!" etc.) are DOM `.popup` divs projected from 3D
  (UI.popup @2007333): cap JR, 900 ms life, fontSize 22*a px,
  gated by setting `floatText` (default on).

**Player: NO world-space HP bar.** Player HP is a HUD element:
`.bar.hpbar` in the top-left plate's under-row, DOM children
i/s/b/u/em (@2000723). Per-frame update (@2023679): instant fill =
children[0] scaleX(hp/maxHp); lag ghost = children[3], hold 0.4 s
then drain 0.9/s; shield fill children[1]; number children[2] =
ceil(hp) (+overheal); overheal fill children[4]; classes low
(<0.30) / mid (0.30–0.55) / wound; low-HP vignette element shows
below 25%.

**Bosses: HUD bars, never world bars.**
- Main `.bossbar` (@2003931, starts display:none): portrait,
  name, tag ("Guardián" / "Legendario" when a phase kit exists),
  rage tag, bar with lag ghost (children[0] `u`), instant fill
  (children[1] `i`), phase segment ticks at 66.6%/33.3%
  (children[2..3] `s` — shown ONLY for kit/legendary bosses),
  numeric HP (children[4] `b` = current HP), sub line (phase text
  or guardian move callout), status-icon foot. Update @2028444:
  visible iff boss.alive; lag hold 0.45 s, drain 0.6/s; lag
  resets to 1 when the boss species changes.
- Up to 2 `.bossbar.mini` bars in `.minibars` for minibosses
  (totem = "Dominante", summoner = "Invocador"), same lag math
  (hold 0.45 s, drain 0.6/s, miniBars @2020582); the mini stack
  gets class `below` while the main boss bar is up.
- Opacity of this whole family is the `bossBarOpacity` setting,
  described in settings (@1970277) as "Las de guardianes,
  Dominantes y Alfas" — guardians, Dominants and Alphas are the
  ONLY creatures with HP bars in the original.
- The original's stylesheet was NOT captured (no CSS in the
  bundle JS, the shared chunk, or reference/orig_assets), so
  exact CSS px values for the HUD bars do not exist in our
  sources; structure, contents and lag math above are exact.
  Placement in our HUD follows the original's layout family
  (top-center stack under the top plate) — an inference, flagged
  as such.

## Gap vs our build (pre-fix)

- enemy.gd gave EVERY enemy a world-space pill (1.15 u × 0.17 u
  at measured height + 0.38, red fill, hidden until damaged) and
  the guardian a 3.2 u × 0.3 u world pill. Original: none.
- player.gd gave the player a world-space pill (2.5 u × 0.34 u,
  with HP number) parked at y=0.14 — at the feet, across whatever
  the player is fighting. Original: none; and our HUD plate
  carried NO player HP readout at all, so the world bar was the
  player's only HP visibility.
- world.gd HUD had no boss bar of any kind.

## Fix applied

- enemy.gd / player.gd: world-space HpBar removed entirely (all
  set_fraction call sites were display-only; weakened/downed
  states keep their rig flash + signals + world markers).
  scripts/hp_bar.gd deleted (class cache gate re-verified).
- world.gd HUD: player HP bar added in the top-left plate's
  under-row position (below the info panel), bundle math:
  instant fill + lag ghost (hold 0.4 s, drain 0.9/s) + ceil(hp)
  number. Guardian boss bar added top-center under the timer
  pill: species name + "守护者" tag (stage-4 sanctuary guardian
  reads "传说守护者" — our guardians carry no phase kit, so no
  segment ticks, matching the bundle's kit-only rule), instant
  fill + lag ghost (hold 0.45 s, drain 0.6/s) + current-HP
  number; visible only while the guardian is alive.
- Our game has no totem/summoner miniboss system, so no mini
  bars; timeline alphas/elites keep their existing scale
  distinction (the original's outline-code channel has no 3D
  equivalent wired — noted, not in this work order's scope).

> **CORRECTION (cycle 17, marked 2026-10-26):** the bullet
> above was later misread (including by us, in cycle summaries)
> as "mini boss bars don't exist in the original". They DO:
> this section's own spec part documents up to 2 `.bossbar.mini`
> bars in `.minibars` (miniBars constructor @2020582, lag math
> hold 0.45 s / drain 0.6 s), and UI_SPEC (cycle 17) re-verified
> the constructor evidence independently. What cycle 10 meant
> — and all that was true — is that OUR build then had no
> miniboss system to attach them to. That premise has since
> expired: cycle 14 added the roar totem and cycle 9/14 the
> timeline alphas, both squarely in the original's
> Dominante/Alpha bar family ("Las de guardianes, Dominantes y
> Alfas", @1970277). Building the 2 mini bars is scheduled for
> UI alignment round 2; it is NOT done in cycle 17.

## Verification

- Before/after screenshots from the new standing capture
  Test/barshot.tscn (same scenario script both runs; the
  "before" run used a temporary restore of the Cycle 9 code,
  afterwards reverted and re-verified):
  Test/out/horde_before.png — red pills across every model at
  body height + the player's numbered bar at feet level, exactly
  the user's device shot. Test/out/horde_after.png — same dense
  ring of damaged foes: zero world bars; player HP reads in the
  HUD plate bar ("61", fill + lag ghost visible).
  Test/out/boss_before.png — the guardian's 3.2 u world pill
  floating over the altar fight. Test/out/boss_after.png — HUD
  boss bar （尼多王 Nidoking · 守护者 · 476) over a bar-free
  guardian model.
- Cycle 9 harness on the final tree: 28/28 PASS, 0 fails,
  0 script errors (Test/out/c10_c9_suite.log).
- check_starters: 3/3 PASS (Test/out/c10_check_starters2.log).
  One recalibration, documented in Test/check_starters.py: the
  charmander color floor (r > 140) had been fit to samples whose
  visibility-diff silhouette included the player's world HP bar
  (a player child). First post-removal runs measured the true
  in-world median ~(128, 92, 54) twice and failed only the
  absolute floor; the bar-free isolated probe
  (Test/probe.tscn) returns an IDENTICAL body median
  (142, 86, 58) and identical silhouette size (20,274 px)
  before/after this cycle — the model is provably unchanged, so
  the floor was recalibrated to the uncontaminated measurements
  with ~15% margin (hue-family relations kept).
- Export gate: Test/check_class_cache.sh OK after a clean
  reimport (cache now 7 classes, all res://scripts/*.gd;
  HpBar gone with its file).
- APK rebuilt via android/build_apk.sh: 53,439,535 B,
  sha256 54fec0c94f754f6ac4184825cc99a2fd65bd7f0169babc15f62e4c57f949189b,
  same cert (b05b80e1...a232), 571 entries, ZIP clean; baked
  class cache extracted and verified (7/7 under res://scripts/,
  no hp_bar, no Test/, no reference/ inside).
- Linux-export boot smoke (the shipped-artifact gate from the
  blue-screen hotfix): exported binary boots to the full 3D
  world + HUD + starter menu, 0 script errors
  (Test/out/linux_export_c10_menu.png — the new HUD HP bar is
  visible under the plate in that frame).

# Cycle 11 — environment composition + melee FX (user feedback 2026-10-25 22:59)

Theme: what's on screen. Our world read sparse next to the original
and our melee sweep rendered as a huge beige hoop. Both systems
were rebuilt from the bundle's own generators/effects, not from
generic decoration.

## Spec mined from the original bundle (main-CkI7dQhz 2,154,272 B;
news-BfmMIm3P shared chunk; byte offsets verified with tail -c)

### Terrain — class `of`, generate() @238277
- areaMul = (world/280)^2; play bound = world/2 - 12; heights on a
  grid (cell 1.12 at world 360), read bilinearly (height() @247616).
- Field f: i = fbm(x*0.011, 4 oct, simplex class td @198044)*0.5+0.5
  + fbm2(x*0.03, 2)*0.04, clamped; quantized into terraces of
  Xd = 4.6: g = (floor(i*L) + Fc(0.5-h, 0.5+h, frac(i*L))) * Xd,
  L = levels (forest 5, others 4), h = 0.035 + 0.4*Fc(0.25, 0.55,
  noise2(x*0.014+40, z*0.014-17)); Fc = smoothstep @93982.
- Paths: 4-6 random walks from origin (step 15, jitter +-0.55,
  round(play/13) steps), generated BEFORE the field; height blends
  92% toward the unquantized v = i*L*Xd along them by
  Fc(8,3,dist)*(0.55+0.45*Fc(-0.2,0.3,noise2(x*0.02))). Massif
  spiral outlines join the path set.
- Massifs (forest relief {levels:5, massifs:2} only): discs at
  radius 0.4-0.68*play, r 44-50, push i toward (L+1.35)/L.
- Water: forest planPonds @246400 — round(6*sqrt(areaMul))+0..1
  ponds, r 6-11, centres snapped to terrace level k*Xd (rim check
  12 pts, <=2 off by >1), basins pressed to level-0.06-0.39*Fc.
  No-relief water biomes (graveyard water:0, volcano water:-1):
  field < 0.17 carved -(0.17-i)*18, shared plane at 0.17*L*Xd-0.9.
  Desert water:null — none.
- Finish: spawn shelf blends to exactly Xd inside Fc(18,9,dist);
  micro noise2(x*0.07)*0.12; rim +Fc(play-4, play+10, max(|x|,|z|))
  *(18+noise*8); one 3x3 blur (4/2/1 / 16). surface() = max(h,
  waterAt); isFlatOpen @248564: normal.y > 0.94 && h >= water+0.25.
- Biome table (news chunk): forest @30430 size 360 propDensity 1
  props [tree,tree,pine,bush,rock,mushroom] deco [0,1,2,3,0,1,4,5,
  6,10,11,12,7]; desert @32340 size 340 pd 0.7 props [cactus,rock,
  rock,deadtree,pillar] deco [7,13,9,7,13,3]; graveyard @37914
  size default 280 pd 0.9 props [grave,grave,deadtree,pillar,
  mushroom] deco [0,1,9,13,6,8,2]; volcano @38713 size 280 pd 0.8
  props [lavarock,rock,deadtree,crystal] deco [14,7,13,8,14,9].
  tex.top[1]/accent (deco washes): forest #86d862/#ff7aa8, desert
  #f6daa0/#ff9a4a, graveyard #6e8e6a/#b07aff, volcano #6e5c54/
  #ff7a2a. (coast/glacier exist in the table but are not in our
  4-zone chain; their env sets 404'd server-side — named blocker,
  unchanged.)

### Scatter + decorations
- scatterProps() @262019: attempts = floor(560 * propDensity *
  areaMul), uniform over +/-(play-3); reject origin dist < 20,
  !isFlatOpen, reserved(2), pathMask > 0.25, and 80% when
  noise(x*0.03) < -0.2 (groves/clearings); kind from the weighted
  props table; scale 0.85-1.3; one InstancedMesh per kind;
  colliders sf/cf per kind (tree .8, pine .7, rock 1.3, grave .6,
  mushroom .6, bush 0, pillar 1, cactus .55, deadtree .5,
  crystal .8, lavarock 1.3).
- Prop geometry factory mf @268632: tree = trunk cyl(.28/.45,
  h3.2) + crown ball r2.1@4.3 + r1.5@5.4 + r1.3@5.2 (total ~7 u);
  pine, bush, rock, mushroom (cap forest 15223370 / graveyard
  10115800), grave, pillar, cactus, deadtree, crystal, lavarock
  part lists as extracted.
- buildDecorations() @262019: round(7000 * areaMul) crossed-quad
  sprites (two 1x1 planes, base -0.05), attempts capped at 3x;
  reject !isFlatOpen, pathMask > 0.4, noise2(x*0.05) < -0.05.
  Atlas Md(seed, top[1], accent) @219470: 128x32 canvas, 16 cells
  of 16x16 pixel art (grass x4, flowers x2, mushroom, pebbles,
  fern, skull, tall grass x2, moss mound, twig, ember, snow).

### Melee FX
- Generic strike dispatch @781314: strike centre C = caster +
  dir * min(dist to target, 0.6*range); custom strikes override,
  else slash() @1448959: 8 nodes along +-1.1 rad (126 deg), radius
  l = range*0.7, arc centre pulled back dir*l*0.5, heights tilt
  +-0.3 alternating by cast parity; beams between nodes (class Lu
  @178238: camera-facing ribbons, width 0.45*(1-|k/7-0.5|), life
  0.16 s, width shrinks (0.4+0.6*frac), fragment profile edge
  x0.6/a.85, core whitened 45%); Spark particles at even nodes
  (size .5->0, life .25, outward 3 u/s); centre flash (vfx.flash:
  disc 0.42r->0.6r of size=0.6*range, cap 4.5, life 0.08).
- Vine Whip custom strike @413916: two vm() chains @406497 (8
  segments, from caster +0.9y to centre + dir*range*0.3, lateral
  bow sin(s*pi)*(+-1.1 / -+0.66 by parity), rise sin*|bow|*0.4,
  width 0.22*(1-s*0.4), color leafDark 3840570, life 0.2),
  Twinkle burst at tip (B() @406784: size .4->2.2, life .15,
  white), 6 leaf particles (hm() @405655: speed 5, size .45->
  .135, life .4, leaf 8050762, drag 2.5, spin).
- Nova/slam rings are FLAT ground rings (vfx.ring: y+0.15, radii
  expanding, ~0.35 s) — never vertical hoops.

## Gap vs our build (pre-fix, quantified)

- Terrain: analytic sine heightfield + hand-placed terraces/
  bluffs/pads vs the original's seeded terrace/path/pond system.
- Scatter: ~266 placed nodes total (~1 per 424 u^2, concentrated
  near spawn; far field empty — env_far_before.png is bare lawn
  wall-to-wall) vs original-system 925/833/648/740 attempts per
  zone with grove/clearing structure.
- Ground detail: 900 tuft cones (62% within r 70) ~= 0.012
  sprites/u^2 vs decorations 7,000*areaMul ~= 0.103/u^2 — the
  single largest density gap (~8x).
- Melee: full vertical torus (inner 2.35 / outer 3.1 -> 6.2 u
  across, ~4.8x creature height), unshaded alpha .9, vs the
  original's 126 deg ribbon arc of radius 0.7*range (2.3 u at
  range 3.3) + flash + sparks. fx_vine_before.png caught the hoop
  filling half the frame — the user's device screenshots exactly.

## Fix applied

- world.gd: Simplex class (td structure port), _gen_terrain()
  (full generate() port: paths, massifs, ponds, carve, shelf,
  rim, blur; grid cell 1.5 vs their 1.12), height_at = bilinear
  grid, surface_at added; player/enemy actor ground calls moved
  to surface_at. Path mask baked to a texture for the terrain
  shader (replaces the authored pads uniform) + vertex tint.
  Old formula terrain (_base_height/_hills/_terraces/_bluffs/
  _pads) deleted. Altar r11 flatten kept as a grid post-pass.
  connectPlateaus NOT ported (relief-only; noted).
- Layout seeds: the bundle's world seed is fixed but its RNG
  stream is unrecoverable, so ours is distribution-equivalent;
  per-zone seed rolls were picked by an openness metric around
  the spawn shelf (Test/probe_c11.gd; 42 candidates for zone 1):
  rolls [11, 1, 2, 11], scores 0.453/0.543/0.548/0.540 vs default
  roll 0 = 0.359/0.490/0.502/0.430. ZONE_SEED_ROLL in world.gd.
- Path mask width is an interpretation: their grid fill for
  pathMask was not in the extracted window; mask = Fc(5, 2, dist)
  matches the dirt-ribbon width in the original's frames.
- _build_scatter() + _build_deco() replace the node scatter and
  tuft field: mf-geometry props baked per kind into vertex-
  colored ArrayMeshes, one MultiMesh per kind, bundle gates and
  counts (areaMul folded for our unified 360 world); Md atlas
  regenerated procedurally per biome (top[1]/accent), crossed
  quads per type, one MultiMesh per type. Placed (final tree):
  scatter 273/316/275/276 props, decorations 9,128-9,349 /
  11,573 / 11,573 / 11,485 of 11,573 target (zone 1 lower:
  ponds + massif slopes fail the flat gate, as in the original).
  Adaptations, noted: prop colors are flat kit colors from the
  biome tex table (theirs are canvas textures washed from the
  same base colors; desert cactus uses our kit green — their
  desert tex.leaf is orange-tan but their atlas cacti are green);
  deco scale varies 0.8-1.25 (theirs is fixed 1); scatter
  reserves use our spawn/altar clearings; lavarock's glow ring
  approximated by an emissive cap blob; crystal = two octahedra.
- FX: spawn_slash deleted. spawn_strike_fx(from, target, dir,
  range, color, move_key) implements the bundle dispatch; generic
  slash = 7 beam ribbons (custom shader: view-aligned side in
  NORMAL scaled by the shrink uniform, Lu fragment profile) +
  sparks + flash; vine-whip = two vm() chains + Twinkle + 6 leaf
  particles (CPU billboard pool). spawn_nova is now a flat ground
  ring expanding r*0.3 -> r over 0.35 s. player.gd strike call
  site passes real target/range/key.
- Perf: terrain gen optimized (cell-3 noise lattices + inline
  squared path distances): 13.1/9.8/7.5/9.6 s -> 4.5/2.6/3.3/3.8 s
  per zone on this VM. Still a visible beat on portal transitions
  (masked partly by the 4 s zone banner); further cuts are future
  work, not silently accepted as free.
- Standing capture Test/c11shot.tscn (9 matched scenes). Its FX
  census at the vine snap: exactly two 32-vert beam chains + 7
  particles, vine-only loadout (an earlier capture diagnosed a
  lingering tackle beam posing in frame; the tool now clears FX
  at the loadout swap and waits on cast parity).

## Verification

- Before/after pairs (Test/out/, same tool both runs):
  env_spawn — bare dirt-bowl spawn -> open glade, dirt path
  ribbons, bluff NE, dressing present; env_far — empty lawn ->
  terraced strata with trees/rocks/ponds + full deco speckle;
  fx_vine_before (giant pale hoop) vs fx_vine_after (no hoop;
  census-verified vine chains — a clean beauty frame of the
  0.2 s chains under llvmpipe capture lag is the one evidence
  gap, stated plainly); fx_slam — flat segmented ring (torus
  tessellation raised to 64x24 after the first capture showed
  facets); zone2/3/4_after — biome-true terraces + scatter/deco.
- Cycle 9 harness: 27/28 on this machine's saved profile, 0
  script errors (Test/out/c11_c9_suite.log). The one FAIL —
  "revive: lab revive purchasable" — is leftover profile state,
  not a regression: the saved profile already owns revive
  (lab.revive = 1 = max, bought by the Cycle 10 suite itself),
  so lab_buy correctly returns false. With a fresh profile the
  revive group passes 8/8 including that check
  (Test/out/c11_revive_fresh.log); the original profile was
  restored byte-identical afterwards. Suite = 28/28 effective.
- check_starters: 3/3 PASS (Test/out/c11_check_starters.log).
  Starter ground offsets on the new terrain measure -0.10..-0.41
  (mesh triangles vs bilinear grid on curved spots); frames show
  starters grounded; the check's own tolerances pass.
- APK rebuilt via android/build_apk.sh: 53,468,207 B,
  sha256 f78b3abb9f1d93ecc25b540d58d1a2faba534aa54aaca2727e87d7717ef44685,
  same cert (b05b80e1...a232), 571 entries, ZIP clean; class-
  cache gate OK (7 classes, all res://scripts/); no Test/, no
  reference/ inside.
- Linux-export boot smoke: exported binary boots to the full 3D
  world + starter menu over the new terrain, 0 script errors
  (Test/out/linux_export_c11_menu.png, Test/out/c11_linux_boot.log).

## Still open beyond this theme (unchanged by cycle 11)

Weather system; blessing altar / roar shrine; league counters
gated on rocks (smash) / best_reactions / berries systems;
section-3 meta (titles/quests/medals/biome tiers); tick-AoE and
aura passives unported; miniboss mini HP bars (no such system);
player low-HP vignette unconfirmed; no foot IK, T-pose bind-arm
stiffness; guardian HP is a fixed DPS budget (original scales
with player build DPS); coast/glacier env sets blocked on the
server-side 404 (named blocker); terrain gen ~2-5 s per zone on
this VM (portal transitions) — optimization headroom noted.

# Cycle 12 — zone-switch stall kill + weather parity (work order 2026-10-26)

## Item 1 — portal switch stall: BEFORE measurements (Test/c12time.tscn)

Real `_advance_zone()` totals on this VM (llvmpipe, 2 vCPU, shared
with other work — absolute values vary, the structure does not):
switch -> zone 2: 9,932 ms; -> zone 3: 13,330 ms; -> zone 4:
14,734 ms (Test/out/c12_switch_before.log). Phase mirror of
`_apply_zone_visuals` (Test/out/c12_phases_before.log):

| zone | gen | terrain mesh | water | minimap | scatter+deco | dressing |
|------|-----|--------------|-------|---------|--------------|----------|
| 2 | 5,362 | 2,658 | ~0 | 1,563 | 1,319 | 505 |
| 3 | 4,558 | 5,261 | 0 | 1,654 | 989 | 95 |
| 4 | 3,901 | 3,025 | 0 | 1,010 | 1,019 | 63 |

Every phase is a pure function of the zone's generated data, so the
fix is total per-zone caching, not micro-optimization:
- Terrain DATA (grid/mask/ponds/paths/lattices) generated by a new
  pure `scripts/terrain_gen.gd` (the cycle-11 generator moved
  verbatim; no scene-tree or rendering calls, safe on worker
  threads). Zones 2-4 precompute on WorkerThreadPool tasks kicked
  off at the end of _ready; zone 1 keeps the synchronous boot path.
- SCENE per zone is built once and parked (terrain MeshInstance,
  water nodes, dressing nodes detached, not freed), plus props
  collider list + minimap texture snapshots. A portal switch with
  a warm cache is a state swap + node reparent: ~ms.
- Scenes prebuild behind the menu: a coroutine builds zones 2,3,4
  in order, phase by phase, with the two hog loops (terrain mesh,
  minimap) and the scatter/deco attempt loops yielding on a row
  budget so the menu stays live. start_game aborts the prebuild
  (partial scene freed, live zone-1 state restored synchronously);
  a portal reached before its scene exists falls back to a
  data-warm synchronous build (gen cost already paid), and if the
  data is missing too, to today's full path.
- Bit-identity guard: per-zone grid checksums (sampled FNV over
  _grid + pond/path counts + water level) measured BEFORE the
  extraction (z1 h=845780485 p8/pa8; z2 h=924739516 p0/pa4;
  z3 h=34206095 p0/pa6; z4 h=249583396 p0/pa5) and re-measured
  after; they must match exactly.

## Item 2 — weather: spec mined from the bundle (offsets tail -c verified)

States: clear / rain / sun / sand / hail / fog / ash. Run state
init (main @1439418): weather='clear', baseWeather='clear',
weatherT=0.

### The weather table (news chunk @~40080, var `s`; `tr` in main)
- clear: boost [] nerf []
- rain:  boost [water, electric], nerf [fire]
- sun:   boost [fire, grass], nerf [water]
- sand:  boost [rock, ground, steel], nerf []
- hail:  boost [ice], nerf []
- fog:   boost [ghost, dark], nerf []
- ash:   boost [fire, dragon], nerf [ice]
Damage application (strike pipeline, main @723641): for player/
ally strikes, `s *= 1.3` if the move type is in boost, `s *= 0.75`
if in nerf. Environmental/fixed hits skip the whole scaling block,
weather included.

### Base weather (stage entry, main @1446551)
```
baseWeather = (sanctuary/special ? 'clear' : F.pick(biome.weather))
if (sy(player.ability).weather) baseWeather = that
weather = baseWeather; applyWeatherLook()
```
F.pick = uniform random from the biome's candidate list (news):
forest [clear, clear, rain] (@31433), graveyard [fog, clear, rain]
(@38798), desert [clear, sand, sun] (@33298), volcano
[ash, sun, clear] (@39600). (coast [clear, rain, clear], glacier
[clear, hail, clear] — not in our zone chain.)
Weather-setting passives (`sy(...).weather`, ability table main
@804645ff): sand-stream->sand, drizzle->rain, drought->sun,
snow-warning->hail — all four exist in our abilities.json as
hooks.weather (cycle 9 extraction), so the override wires straight
from GameData.passive_hooks(player.passive_id).
Stage transitions zero weatherT (main @1465939, @1466833,
@1467871) and buildStage re-picks the base.

### Timed weather (setWeather, main @1452897)
`setWeather(id, secs)`: weather=id, weatherT=secs, look applied,
toast "¡El clima cambia: {name}!". Per-frame (main @1487538):
weatherT -= dt; at <= 0, weather reverts to baseWeather + look.
`setBaseWeather(id)` (@1452859): sets base; applies immediately
only if no timed weather is active. In the original corpus the
timed setters are boss-kit casts (kit tables: hail 10 @543328,
rain 12 @595865, hail 14 @603097, rain 12 @605490/@610342/
@614351/@633103/@683764, sand 12 @647215) — our port has no boss
kits (cycle 10), so our set_weather API ships with the ambient
system and its in-game triggers land with the kits.

### Look (applyWeatherLook, main @1452968; base = current zone look)
- fogNear x: fog .5, sand .6, hail .7, else 1
- fogFar x: fog .6, sand .7, rain .85, hail .75, else 1
- fog color: sand 14203008 (#D8B980); rain zone-fog x0.8; hail
  zone-fog lerp 0.5 toward 15266559 (#E8F4FF); else zone fog
- sky bottom: rain 10135736 (#9AB7C8), else zone sky bottom
- light x: rain .8, sun 1.15, else 1
- shared wind uniform uWind: sand|rain -> 2.2 else 1 (drives their
  instanced-sprite sway; our deco has no wind shader — no
  counterpart, recorded as a gap, not faked)

### Particles + ambient hazard (weatherFx, main @1489897)
Called every frame; clear/sun spawn nothing. Spawn budget
floor(rate * dt * 10) around the CAMERA (x/z +-25, y +4..+14):
- rain (rate 140): Drop, vel (2,-26,0), life .55, size .22,
  color 10143999 (#9AC7FF)
- sand (rate 50): Soft, y-6, vel (14,-1,4), life 1.4, size .5->.9,
  color 14203008 (#D8B980)
- hail (rate 50): Flake, vel (1,-14,0), life 1, size .3, white, spin
- ash (rate 50, additive): Soft, vel (+-1,-2,+-1), life 3,
  size .18->.1, color 16747066 (#FF9D62), glow .5
- fog (rate 6): Soft, y-10, vel (.5,0,.3), life 4, size 6->9,
  color 11575496 (#B09C78)
Ambient hazard, gated per frame by rand < dt*2 (expected every
~0.5 s), over enemies within 25 u of the player:
- rain: wet[enemy] = max(wet, 2) (+ 'soaked' counter once per
  enemy when the rain is timed, weatherT > 0)
- sand: enemies without rock/ground/steel type take a FIXED
  special rock hit of 2 + stage*2 (fixed = no attacker scaling,
  no effectiveness, silent, no reaction)
- hail: non-ice enemies, 20%: applyStatus freeze
Wet itself (main @731453ff): a parallel status (5 s via
applyStatus; counts in statusCount): freeze via chill consumes
wet and jumps chill to 3 (instant freeze); electric hits on wet
targets trigger the Electrocutado chain reaction (up to 12 other
wet enemies within 9 u, 0.8x, paralysis 0.6). OUR engine has no
wet/chill layer at all (single-slot statuses; wet/root/curse were
logged as unported in cycle 9) — rain's wet application is
therefore a named gap tied to that layer; rain's boost/nerf,
look and particles are implemented in full. Sand chip maps onto
our DoT channel (enemy._dot_tick: fixed, silent, no reaction,
no effectiveness — the same semantics). Hail freeze uses our
direct freeze status at the engine's standard 2.0 s, only onto
enemies whose status slot is empty or already freeze (their
parallel chill stack doesn't clobber other statuses; ours
must not either).

### Our RNG note
The original picks with Math.random. Ours picks from a dedicated
RNG with a fixed seed (house pattern: distribution-equivalent,
deterministic under test — same treatment as terrain seeds), so
harness damage-value checks stay reproducible.

## Hotfix — attack feel: lunge thrust backwards + terrace targeting gate (2026-10-26)

User report on the cycle-11 build: "角色好像无法攻击", refined to
"可能没攻击动作,所以我感觉没攻击" — damage probably landed, but
no attack MOTION was visible when a move auto-fired.

### What the original does (bundle main-CkI7dQhz, byte offsets tail-verified)
- Casts invoke the player's attackAnim() (call site inside the
  cast dispatch @777655): `attackAnim(){ this.attackT<=0 &&
  (this.attackT=.3) }` @836129 — a 0.3 s window per cast.
- The player render push passes `squash + c + a` as its squash
  argument (@850944), where `c = sin((1-attackT/.3)*PI)*.12`:
  a 0.12 squash pulse over the attackT window, added to the
  squash channel. While attackT>0 and speedNow<.6 the sprite
  also faces lastAim. The sprite anim state does NOT switch for
  normal casts (stays walk/idle).
- The `attack` sprite anim is reserved for the ult pose
  (ultPoseT=.6, @1397186) and for enemy attacks (atkAnim .35/.4;
  render picks `attack` at phase 1-atkAnim/.4, @338678).
- Targeting is horizontal: the strike case scans
  E.within(h, g, d*.75) on XZ.

### Root cause (ours) — two defects, one symptom family
1. **Lunge direction inverted.** Every modelled GLB faces +Z
   natively (Segment Z FACING BUG record; yaw table all 0.0) and
   set_facing() aims the rig's +Z at the target — but the
   Segment Z lunge curve offset the model along -basis.z. The
   anticipation (-0.10) hopped TOWARD the enemy and the 0.42
   thrust slid AWAY from it, on every player auto-fire and every
   enemy contact attack. Pre-fix measurement (pinned in-range
   target, zero input): model offsets -0.31 / -0.18 along the
   facing axis at fire moments, forward max ~0. Damage and FX
   were correct all along — the body read as recoiling, i.e.
   "no attack motion", exactly the user's refined symptom.
2. **Targeting gate was 3D.** player._nearest_enemy used full
   3D distance while its own hit tests are horizontal (d.y = 0).
   On cycle 11's quantized 4.6 u terraces, a target one step
   below (dy 4.6, horizontal 2.3 -> 3D ~5.1 > 3.6 gate) could
   never be acquired: the player stood next to an enemy and
   never attacked at all. Harness spawns are same-height, so
   the standing suite never saw this.

### Fix
- model_rig.gd: lunge forward = transform.basis.z (rig-local
  +Z). play_lunge() also starts the bundle's cast pulse:
  _cast_t = 0.30, composed into the squash as
  +sin(PI*p)*0.12 (bundle numbers verbatim). play_faint /
  revive_reset clear _cast_t.
- player.gd: _nearest_enemy measures horizontal (XZ) distance,
  matching the hit tests and the bundle's within().

### The coverage hole, closed
The cycle-9 suite never fired the player's own moves through
the real chain (the slam phase clears p.moves; the guardian
and ally phases call take_damage / ally_land directly). New
permanent phase `--only=attack` (part of "all"): zero input
events, a real enemy pinned in range, the wild spawner held
shut via the world's own _spawn_t. Checks: (1) auto-fire
triggers on cooldown, (2) hits == fires, (3) total damage ==
hits x pipeline value (22.9241/hit, exact), (4) lunge forward
offset >= 0.25 u inside the fire window (measured 0.356-0.370),
(5) a target one terrace below (dy 3.55) is hit.
Mutation proofs (Test/out/c9_attack_mutA.log / mutB.log):
_roll_damage -> 0 turns (2) and (5) red (SUMMARY fails=2);
flipping the lunge sign back turns (4) red (fwd_max 0) with
everything else green. Post-fix phase: 5/5 PASS
(Test/out/c9_attack_postfix3.log). Post-fix diagnostic trace:
fire-moment model offset +0.313 toward the target (pre-fix
-0.153 at the same sample point).

### Ult finding (separate, pre-existing — flagged, not built)
The 必 ultimate has NO implementation at all: no cast function,
no key binding, no touch button; the HUD circle is a
MOUSE_FILTER_IGNORE panel (decoration), player.ult_name is a
label string, and the "ultimates" profile counter is never
incremented anywhere. Not a cycle-11 regression. The original
reserves its `attack` sprite pose for exactly this
(ultPoseT .6 s) — wiring the ult is a feature, out of scope
for this hotfix.

Hotfix verification (2026-10-26): full suite with the new
attack phase = 33 checks: 32 PASS in the main run
(Test/out/c9_full_postfix.log) + revive group 8/8 on a fresh
profile (Test/out/c9_revive_freshprofile.log) — the main
run's single FAIL is the documented profile artifact (the
local profile already owns revive at max from prior suite
runs; the original profile was restored byte-exact,
sha256-verified). check_starters 3/3 PASS
(Test/out/check_starters_hotfix.log). APK rebuilt via
android/build_apk.sh (class-cache gate OK): 53,480,652 B,
sha256 760b66d513b4dc35db4442d557a291e260408c348bb1cb38e6c7a53d36d39dfb,
signer cert unchanged (b05b80e1...a232); the packaged class
cache inside the APK re-verified: 7 classes, all
res://scripts/, no Test paths. Linux export boot smoke:
0 script errors over the full window. NOTE: this build also
packages the tree's current world.gd (cycle-12 terrain
pre-generation state as of this build); the hotfix itself
touched only model_rig.gd, player.gd, Test/harness.gd.

## Cycle 12 — results (2026-10-26)

### Item 1 — stall kill: VERIFIED

- AFTER (clean re-run, Test/out/c12_switch_verify2.log — see the
  correction note below): prebuild completes behind the menu
  (72 s on a quiet VM; it is menu-idle time, sliced per frame);
  warm switches: internal restore 3/4/1/2/2 ms across
  z2/z3/z4/z1/z2, externally measured 39 ms for the first switch
  and 1-5 ms steady-state. BEFORE totals (real _advance_zone,
  Test/out/c12_switch_before.log) were 9,932 / 13,330 /
  14,734 ms.
- Cold fallback (cache entry dropped, data warm): full build
  1,653 ms on the quiet VM. Reachable only when the player
  outruns/aborts the prebuild; the portal then shows the
  loading banner for one rendered frame before the build
  (the _switch_pending path).
- Memory: boot static 130.1 MB -> 144.7 MB with all four zones'
  data + scenes + minimaps resident (+14.6 MB).
- Bit-identity: proven in the extract-era runs with the
  original timing tool — BEFORE vs EXTRACT grid hashes identical
  for all four zones (z1 845780485, z2 924739516, z3 34206095,
  z4 249583396; both logs extant) and per-zone scatter/deco
  counts identical; current code still reproduces ponds/paths/
  water levels and the zone-1 scatter/deco counts exactly. The
  rewritten timing tool hashes with a different (full-array)
  formula; its values, from dumped grids, are the going-forward
  baseline: z1 1660284102, z2 540849945, z3 4038153389,
  z4 2163175278. The cycle-11 terrain spec (terraces/paths/
  ponds/massifs) is untouched — the generator moved verbatim
  into scripts/terrain_gen.gd.
- CORRECTION (2026-10-26, later): the first version of this
  results section quoted warm switches of 436/6/2/2/2 ms, a
  26,171 ms cold build and +31 MB — those came from a runtime
  completion capture that did not match the run's on-disk log.
  That log (c12_switch_cache1.log) shows the measurement tool
  proceeded after a 240 s wait with only zone 2 cached and
  raced the still-running prebuild (shared member state), so
  its switch numbers are interference artifacts and are
  withdrawn. The figures above are from a clean re-run whose
  tool refuses to measure until the cache is complete. All
  other cycle-12 results (weather checks, suite, abort stress,
  screenshots, APK, Linux smoke) were read from on-disk logs
  and are unaffected.
- Abort stress (Test/c12abort.tscn): start_game fired mid-build
  (zone 2 cached, zone 3 in flight): 10/10 — clean unwind, no
  bogus cache entries, zone-1 scene live, portal advanced to
  zone 2 afterwards.
- Exported-build evidence (Linux smoke, PTY log
  Test/out/c12_linux_smoke2.log): boot gen 6,030 ms, thread gens
  2.8-3.0 s, all three prebuild scenes cached, no script errors.
  Boot cost unchanged in structure: zone 1 still generates
  synchronously at boot.

### Item 2 — weather: VERIFIED with named gaps

- Implemented: the state table + damage multipliers inside
  combat_hit (the player/ally pipeline only, right after STAB;
  fixed/environmental damage never passes through it); per-zone
  base pick from the biome candidate lists (now in ZONES);
  weather-passive override (drizzle/drought/sand-stream/
  snow-warning via GameData.passive_hooks); set_base_weather /
  set_weather(w, secs) with the toast + timed revert;
  apply_weather_look (fog-distance factors, fog colors, rain sky
  bottom, light factor on sun light + ambient); GPUParticles3D
  precipitation per state around the camera; ambient hazards
  (sand chip through the DoT channel at 2+stage*2 with the
  rock/ground/steel exemption; hail 20% freeze onto empty/freeze
  status slots only, ice exempt).
- Functional checks (Test/c12wx.tscn): 31/31 PASS — multiplier
  table (14 cases), look values exact (fog far 136 rain / 120
  hail, fog 20/96, light 1.32 rain / 1.8975 sun, sand fog color
  #D8B980), pick distribution + drizzle override, timed revert,
  sand chip + exemption, hail freeze / no-clobber / ice
  exemption (staged enemies' types asserted in the check).
- Screenshots (Test/out/wx_{clear,rain,sun,sand,hail,fog,ash}.png,
  25 s saturation each): rain streaks + dimming and the sun
  warming are obvious in stills; hail/fog shifts measure out in
  pixel counts; sand dust and ash embers are low-contrast in
  stills (small soft sprites on bright ground) but present
  (ash orange-pixel count ~2x clear). Process note: at this
  VM's ~3 fps, short waits starve the particle simulation — the
  first screenshot round looked empty for that reason alone; a
  plain-emitter bisect + a 30 s control shot
  (Test/out/wx_probe2_late.png) proved the pipeline healthy
  before the re-shoot.
- Particle amounts follow the spec's rate x lifetime identity
  at 60 fps cadence (rain 700, sand 600, hail 450); ash capped
  at 800 (identity ~1440) and fog at 90 (identity ~240) for
  fill rate.
- Suite interplay: the multiplier is LIVE in combat_hit and the
  full 33-check suite passes with it — exact damage values
  unchanged (attack total 206.316907797693; ally pipeline
  19.6377910471701). Consequence of the fixed seed, stated
  plainly: the weather SEQUENCE repeats every run (zone picks
  are still drawn from the correct biome lists). Per-run
  variety is a one-line seed change, deferred because it would
  make the suite's exact damage checks nondeterministic (the
  original picks with Math.random and would fail such checks
  on roughly a third of runs itself).
- GAPS (named, not hidden):
  * Rain's wet status + the electrocute chain: our engine has
    no wet/chill layer (single-slot statuses; logged unported
    in cycle 9). Rain ships with boost/nerf + look + particles.
  * The bundle's shared wind uniform (vegetation sway in
    sand/rain): our deco has no wind shader — no counterpart.
  * set_weather's in-game triggers are boss-kit casts in the
    original; boss kits are unported (cycle 10), so the API
    ships with the ambient system and its triggers land with
    the kits.
  * Staging note: swinub (used for the ice hazard check) has
    no GLB model in our roster — ModelRig logs an error and it
    spawns model-less. The game's zone pools never spawn it
    (no ice types in our four biomes). Not a weather defect;
    recorded for the roster ledger.

### Verification ledger (this cycle)

- Suite (resident profile): 33 checks, 1 fail = "revive: lab
  revive purchasable" — the documented local-profile trap (the
  profile already owns revive, max 1). Fresh-profile revive
  group: 8/8 PASS. Same single fail appeared in the hotfix
  agent's postfix run for the same reason.
- check_starters: 3/3 PASS. Class-cache gate: OK.
- Final APK: build/android/SpriteBonk.apk, 53,480,652 B,
  sha256 1ebf1d72e4a9165e2786bfd8550ec00fe5aa9f0f6902bdedc34d735283ce48ad,
  cert b05b80e1...a232 (same byte size as the hotfix build by
  padding coincidence; contents differ — terrain_gen.gdc and
  the weather code verified present).
- Incident (honest): a service restart killed the first
  full-suite attempt mid-boot and wiped /tmp, taking the
  pre-cycle profile backup with it; the killed run had already
  written suite gameplay into the local test profile
  (counters/stardust; lab levels unchanged: dmg 1 / party 1 /
  revive 1). The post-suite profile was then snapshotted into
  the workspace, used for the fresh-profile verification, and
  restored byte-identical (sha e15aee84...) after every later
  run. The pre-cycle profile bytes are unrecoverable; the
  profile is a harness playground that suite runs mutate by
  design (that is how revive got maxed in cycle 10).

# Cycle 13 — the ultimate （必） wired for real (work order 2026-10-26)

## Spec mined from the original bundle (main-CkI7dQhz; offsets are
## real byte offsets, tail -c verified this session)

### Controller (class _D, ults; defined right after byte ~1394600)

Constants on one line: `pD=95, mD=.004, hD=.024, gD=40`. State:
charge 0..1, active (seconds of ult duration left), uses, killRoom
(init hD), denyT, holdOk, castPending. `ready` <=> charge >= 1.

- rate() = (passive lunar-blessing ? 1.3 : 1) x (item soul-dew ?
  1.4 : 1 — no item system in our build) x (item poke-flute ?
  1.25 : 1 — n/a) x (1 + .04 x research-lab "ult" level). Our lab
  table already has the "ult" row (max 5, +4%/level, cycle 9) with
  no consumer until now.
- add(x): NO-OP while active > 0. charge = min(1, charge +
  x * rate()). On the crossing to ready: gold ring vfx at the
  player (radius 3, colour 16765498) + toast "Ultimate ready!
  Press R: {name}" ("tap its button" on touch).
- Passive gain: update(dt) does `active>0 ? active-=dt :
  add(dt/pD)` — a full bar from time alone in 95 s. killRoom
  refills always: killRoom = min(hD, killRoom + hD*dt).
- onKill(flags, slot) (tally region @731500): slot == 8 ->
  NOTHING (that is the ult's own hits, and status/DoT ticks).
  Else flags & Boss -> add(.2); flags & (Alpha|12290) -> add(.08);
  flags & Elite -> add(.03); else add(min(mD, killRoom)) and
  killRoom -= the amount — plain kills are throttled to .024 of
  charge per second of fighting, however fast you kill.
- onHurt(frac): add(frac * .35). Call site in the player's hurt()
  @820982: `ult?.onHurt(f / maxHp)` with f = the HP damage that
  actually landed (after shields/armour).
- Trigger (update, state == 'play', player alive): KeyR PRESSED
  this frame -> ready && active<=0 ? fire() : (denyT = .4 + deny
  sound). KeyR HELD: holdOk resets to true whenever R is up and
  is cleared by fire(); holding R fires the moment the bar
  becomes ready. settings.autoUlt (default false) && ready &&
  active<=0 && an enemy within 16 -> fire() automatically.
- fire() (@1396637 region): gamepad rumble eo(.8, 320) (@9895 —
  ours: Input.vibrate_handheld approximation). Aim = nearest
  enemy within 18 (horizontal) else the player's facing. Cast
  context u = {x,y,z = player pos, ax,az = aim direction,
  tier, form, type = def.type, cls = def.cls,
  dmg = gD * (1 + .1 * player.level) * stageMult[stage]
        * (1 + .15 * tier), R = sqrt(player area stat)};
  stageMult = j_ = [1, 1.8, 3.2, 4] (@719436 — the same table as
  our slam's SLAM_STAGE_MULT). Then: charge = 0, holdOk = false,
  active = dur, uses += 1, run stats ultimates += 1 AND the
  lifetime profile counter ultimates += 1 (meta.count),
  player.onUltimate() (its only effect: the poke-flute item
  refreshes move timers + buff — item-gated, no-op in our build,
  @831602), iframes = max(iframes, active + .6). quiet =
  settings.ultQuiet ?? settings.autoUlt. If !quiet:
  ultPoseT = .6, and if settings.ultPose (default true):
  hitstop(.32) + a cut-in band (portrait + "¡Ultimate!" + ult
  name in the type colour, auto-removed after 1300 ms,
  @2011156). If !quiet: ultLook(def.tint, active + .3) — a
  global atmosphere grade toward the tint (@1453942); audio
  duck(.35, active + .6); cast sfx. Always: ring vfx at the
  player (radius 4.5, type colour), 24 Twinkle particles
  converging from radius 4.5 (life .35), shake(.25), ability
  lunar-blessing heals 15% maxHp. The actual cast runs at
  +0.03 s via their later() (castPending).

### Definition resolution

def = Bg[familyDexId] ?? Kg[type] ?? Kg.normal (@692265);
form = player evolution stage; tier = min(2, evoStage + growth);
name = def.names[form]; duration = def.dur[form] (pg() picks an
array element or a scalar). Wg() builds type defs (@~683800).

### Hit helpers (every ult hit flows through these)

- wg(ctx, e, mul, opts) @618671: combat.hit(e, ctx.dmg * mul,
  {type: ctx.type, cls: ctx.cls, slot: 8, knock: 2, ...opts}).
  ALL ult hits are slot 8 — which is why ult kills never refund
  charge through onKill.
- q(ctx, x, z, radius, mul, opts) @618777: every enemy within
  radius -> wg. Tg = q with a per-cast dedupe Set.
- Eg(ctx, x, z, radius, strength) (~619000): drag — velocity
  toward the point, strength x .08 (boss) / .35 / 1; only beyond
  .8 u from the centre.
- Ag(ctx, x, z, count, opts) @620265: `count` fissure walkers
  evenly around 2PI from a random base angle (+- .15 jitter).
  kg walker (~619700): steps of 1.5 u at speed 24 (a step every
  .0625 s), heading relaxes x.6 toward the fissure angle with
  +- .55 jitter per step; per step: ground-crack decal, optional
  glow beam, erupt(x,y,z,stepFrac) callback, and a Tg hit of
  radius (width ?? 1.9) * ctx.R, mul ?? 1, status opts.o —
  dedupe set is PER WALKER.
- jg(ctx, radius, .9, mul, opts, fxFn, 40) @620361: expanding
  ring wave over 0.9 s; enemies inside front+.8 and beyond
  front-2.2 take one Tg hit (dedupe).
- Ng(ctx, count, stagger, range, teleDelay, teleFn, landFn)
  @621322: staggered target drops; targets = the `count`
  nearest enemies within range (Dg, jittered ordering) else a
  random point at radius 3..range.
- W(run, dur, cb, onDone): timed repeater.
- Ground zones (class Hv @771563): update ticks every .45 s
  (a zone's own `tick` field is only its INITIAL delay); a tick
  hits every enemy within r with combat.hit(zone.dmg, {type,
  cls, status, chance, slot, knock: .2, silent 50%}). Cap 260.
- Status application @732957: root[e] lasts 2 * attacker factor
  = 2.0 s for our player. ("Rooted" = Enraizado, @721730.)

### The three starter defs (Bg literal @627348; EN names from
### en-C2L1kC0V: Furious Roots @396122, Frenzy Plant @374268,
### Giga Flower Whip @256566, Rising Blaze @309883,
### Blast Burn @88573, Giga Blaze @256605, Shell Whirlpool
### @456881, Tidal Wave @329109, Hydro Cannon @268618)

- Bg[1] Bulbasaur line: grass / special, tint 7002186,
  dur [1.6, 2, 2.6], names [Furious Roots, Frenzy Plant,
  Giga Flower Whip]. cast: Ag roots — n = [6,8,10][tier],
  length [12,15,17][tier] * R, mul 1.1, {root chance .9,
  knock 1}; per-step erupt FX = root spikes + 50% leaf
  particles. tier>=1 at +0.35 s: sun — heal the player 20%
  maxHp, spore FX, q radius 9*R mul .3 {sleep chance .6,
  knock 0}. tier>=2: three petal waves at +.7/+.7+.32/+.7+.64:
  q radius (9+3k)*R mul .9 knock 3.
- Bg[4] Charmander line: fire / special, tint 16738858,
  dur [1.2, 1.8, 3], names [Rising Blaze, Blast Burn,
  Giga Blaze]. cast: 26 flame particles jet up; rings k in
  (tier>=1 ? 3 : 1) at +.18 + .22k, radius (8+3k)*R: q mul 1.3
  {burn .9, knock 4} + ring FX + 8 burning ground zones at
  radius (8+3k)*R*.6 (r 2.2, life 4, first tick .2, dmg =
  ctx.dmg * .18, burn chance .5, slot 8) + shake(.18).
  tier>=1: Ag 6 magma fissures, length 13*R, mul .9 {burn .8}.
  tier>=2: Ng 14 meteors over 1.8 s (telegraph .55) landing
  q radius 3.6*R mul 1.2 {burn .8}; at +2.55 s a final blast:
  q radius 13*R mul 2 {burn 1, knock 6} + Ag 8 fissures
  length 15*R mul .6 (decals life 3.5).
- Bg[7] Squirtle line: water / special, tint 4892927,
  dur [2.4, 1.6, 2.8], names [Shell Whirlpool, Tidal Wave,
  Hydro Cannon]. cast helper wave(radius, mul) = jg .9 s with
  {wet chance 1, knock 6} + splash FX. tier 0: whirlpool —
  2.2 s repeater: the swirl grows 5*R -> 11*R; every .25 s a
  q radius 5*R mul .32 {wet .6, knock .3, silent 50%} with an
  Eg drag toward the player (strength 26 x progress); on end,
  wave(9*R, 1.4). tier 1: wave(16*R, 1.8), at +0.9 s
  setWeather(rain, 12). tier 2: wave(12*R, 1.8); at +0.5 s two
  opposite beams sweep 360 degrees over 2.2 s, ticking every
  .1 s: enemies in either beam band (length 17*R, half-width
  1.6*R) take wg mul .42 {wet .5, knock 1.5} (origin = the
  player's CURRENT position each tick).
- Type fallbacks Kg (species without a Bg entry — not needed
  for our playable starters): fire "Eruption" @684506 (6
  fissures len 14R mul 1.1 burn .9 + at +.3 a ring q 10R mul
  1.4 burn 1 knock 4); water delegates to Bg[7] at tier 1;
  grass delegates to Bg[1] at tier 1.

## Gap vs our build (pre-fix, quantified)

The attack hotfix established it: the ult was decorative-only.
No charge state, no key/button path (the HUD circle was
MOUSE_FILTER_IGNORE), player.ult_name a static label, the
profile "ultimates" counter listed in UNSUPPORTED_COUNTERS so
roster challenges gated on it could never complete, and two of
the three HUD labels were invented ("Blaze Rush", "Hydro
Surge" — the originals are Rising Blaze / Shell Whirlpool).
Our engine also had no "root" status (cycle 9's port list) and
no hit-slot attribution, which the charge rules depend on.


## Fix applied (cycle 13)

- scripts/ult.gd (new, class Ult): the controller — charge /
  active / uses / killRoom / deny state; rate() (lunar-blessing
  x1.3 passive-gated, lab "ult" +4%/level — the lab row's first
  consumer); add() with the ready ring + toast; on_kill with the
  flag table (boss .2 / alpha .08 / elite .03 / killRoom plain);
  on_hurt(.35 x fraction); the trigger poll (KeyR edge -> fire
  or deny .4; hold-to-fire via holdOk; autoUlt within 16);
  fire() exactly per spec (aim 18, ctx dmg = 40 x (1+.1 level)
  x stageMult x (1+.15 tier), R = sqrt(area), iframes
  active+.6, pose .6, hitstop .32, cut-in, ring + twinkles,
  shake .25, lunar heal 15%, cast at +0.03). Effect machinery:
  later() timers, W() repeaters, Ag/kg fissure walkers (per-
  walker dedupe), jg ring waves, Hv ground zones (tick .45
  after an initial delay; visuals are flat tinted discs), Eg
  drag via the enemy knockback channel, Dg nearest picks, Ng
  meteor scheduling. The three starter casts (Bg[1]/[4]/[7])
  are implemented per tier with the numbers mined above.
- scripts/ult_gauge.gd (new, class UltGauge): the 必 circle is
  a real button — charge sweep arc in the def tint, ready =
  bright face + pulsing rim, deny veil; presses (touch/mouse)
  emit `pressed` through the gui_input signal path.
- world.gd: Ult created per run in start_game (disposed on
  replace / run end), ticked from _process on the world clock
  but NOT gated on hitstop (their later() runs through freeze
  frames; the cast lands inside the cast hitstop); _award_kill
  feeds on_kill(flag, last_hit_slot) — the single funnel both
  kill paths share; combat_hit forwards opts.slot into fx;
  ult_on_player_hurt glue; cut-in band + ultLook tint overlay
  (approximation of their atmosphere grade); twinkle / fissure
  / flame-jet particle helpers reusing the cycle-11 FX kit;
  STARTER_HUD ult labels corrected to the real def names.
- player.gd: take_damage reports the landed fraction to
  world.ult_on_player_hurt after the HP subtraction (dodges
  return earlier and earn nothing, as in hurt()).
- enemy.gd: "root" status (2.0 s, blocks movement via _frozen,
  earns neither the sleep x1.8 nor the freeze x1.2); hit-slot
  attribution (last_hit_slot from fx.slot; _dot_tick stamps 8).
- model_rig.gd: the ult pose channel — play_ult_pose() holds
  the fight clip for ultPoseT .6 (locomotion selector gated),
  procedural rigs get the lunge motion as the floor; cleared
  by faint/revive like the other pose channels.
- profile.gd: SETTING_DEFAULTS += autoUlt false / ultPose
  true; "ultimates" REMOVED from UNSUPPORTED_COUNTERS (the
  system exists; gated roster challenges can now complete);
  lab "ult" fx flag set true (it has a consumer now).

Named approximations / gaps (honest):
- "wet" is NOT applied by Bg[7]'s casts (no wet layer in our
  engine — the cycle-12 gap stands); damage, knock, drag, the
  rain call and the cannon sweep are exact.
- ultLook = a fading fullscreen tint, not their graded post
  pass; cast ring colour = the def tint (their fire ring uses
  the type-palette colour — same hue family); fissure eruptions
  and ground cracks are particle/disc approximations of the
  PixRoot/lava sprites, with no persistent crack decals;
  rumble = Input.vibrate_handheld(320 ms); deny has no sound
  (no deny sfx asset) — the gauge shows the .4 s red veil
  instead; audio duck has no counterpart (no duck bus).
- The Kg type-fallback defs are not implemented: every
  playable starter has a Bg def, and league/ally creatures
  never cast ults in our build.
- Scatter RNG (fissure angles, meteor picks) is fixed-seed —
  distribution-equivalent, deterministic under test (the
  cycle-12 weather pattern).

### Verification ledger (this cycle)

- Ult phase (Test/harness.gd --only=ult): 32/32 PASS. Charge:
  passive rate exact; plain/elite/alpha/boss credits exact;
  killRoom drain exact; slot-8 combat_hit kill == +0; a real
  burn-DoT kill carries slot 8 and adds no credit; hurt credit
  == .35 x fraction x rate exactly (0.05378682 both sides).
  Fire: through the real gauge signal path AND the real KeyR
  path AND autoUlt; counter 0 -> 1 -> 2 -> 3 across the three
  fires; pose 0.6 sampled at cast; iframes 2.2 == active+.6.
  Casts: Bg[1] roots — first drop == 3 x pipeline (three roots
  clip the pinned target on step 1), root status applied,
  6 fissures at tier 0; Bg[4] ring == 1.3 x pipeline to 1e-9
  relative (86.1319821359211 vs 86.1319821359223), 8 zones;
  Bg[7] whirlpool — nine ticks of exactly .32 x pipeline +
  final wave 1.4 x pipeline, drag velocity 26 toward the
  player sampled in the knockback channel.
- Mutation proofs: BASE_DMG 40 -> 0 fails exactly the four
  cast-damage checks; on_kill boss add(.2) -> add(0) fails
  exactly the boss-credit check (charge 0.118 = 0.318 - 0.2).
  Both reverted; ult phase green again before the full suite.
- Full suite (resident profile): 65 checks, 64 PASS; the one
  fail is the documented local-profile trap ("revive: lab
  revive purchasable" — the profile already owns revive).
  Fresh-profile revive group: 8/8 PASS. The pre-cycle profile
  was vaulted before any run and restored byte-identical
  afterwards (sha256 e15aee84... — the same bytes cycle 12
  restored; verified again after the boot smoke).
- check_starters: 3/3 PASS. Class-cache gate: OK (Ult +
  UltGauge registered under scripts/ after an import pass).
- APK: build/android/SpriteBonk.apk, 53,509,618 B, sha256
  4469440c39632f2ce3b9b4b8ed7b332a15a748636320d6da38a298a4d8f2b9c1,
  cert b05b80e1...a232; assets/scripts/ult.gdc +
  ult_gauge.gdc verified inside the package. Linux-export
  boot smoke: shipped binary ran the full 120 s window with
  no script errors (menu up; the blue-screen failure mode is
  a load-time one and would have shown immediately).
- Process finds worth keeping: (a) Callable.bind appends
  bound args AFTER call-time args — repeater callbacks take
  (elapsed, dt, ...bound); (b) opening a level-up draft sets
  running = false BY DESIGN (the world clock pauses), so any
  harness segment after XP-paying kills must settle the draft
  through _close_draft before expecting physics/trigger flow;
  (c) the player invulnerable fixture also blocks the hurt
  credit path — a check that passes with delta == want == 0
  proves nothing and was caught by its own detail line.

# Cycle 14 — blessing altars / roar shrines, guardian HP build
# scaling, wet status layer (work order 2026-10-26)

## Item 1 — interactables: spec mined (main-CkI7dQhz byte
## offsets, tail -c verified this session; news chunk = the
## shared chunk news-BfmMIm3P)

populate() @1240977 (interactables class `iw`): per stage,
non-endless counts use i(n) = round(n * (0.5 + 0.5 *
terrain.areaMul)) [our world is 360x360 in every zone ->
areaMul 1 -> counts are the raw n]: altar i(5), greed 1,
challenge i(2), cursed 1, fossil 1, rhydon 1, porygon 1,
bill 1, nest 1, meowth 1, ditto 1, hypno 1, snorlax 2,
magnet 2, slots i(2), freechest i(3), cursedchest i(2),
cage i(2), berry i(5), chest i(14), rock i(14). THIS CYCLE
ports altar + rhydon only (the two on the work order); the
rest are named backlog. The `shrine` kind exists only in
the sanctuary biome (boss summon) and `boss` = our boss
altar — neither is a populate item in our zone chain.
Placement sampler r(minR=14, maxR=play-5, kind) @1240977:
30 uniform candidates, keep the one maximizing the min
over terrain landmarks (dist - landmark.r - 3) and placed
interactables (dist - max(0, r-2.6), x0.5 same kind, x0.65
same landmark class; LC: altar/rhydon/boss = 1, the
creature props = 2). Terrain reserves r+0.6 around each.
Original randomness = Tu(seed ^ 30634) — ours is a seeded
RNG per zone (distribution-equivalent, deterministic under
test); the isFlatOpen water/slope gate ports to our height
probe + pond rejection (approximation, flagged).

Altar tiers tw(rng, count, luckMult) @~1234800: array =
first r entries tier 2 (r = count>=4 ? max(1, round(
count*.15)) : 0), next round(count*.3) entries tier 1,
rest tier 0; then chance min(.3, .2*sqrt(max(1,luckMult)))
upgrades a[0] to tier 3 BEFORE the shuffle. Count 5 ->
[2,1,1,0,0] or [3,1,1,0,0]. ZC tier table @~1235800:
t0 {#2EC8E0, unown 1, charge 8, r 6, drain 6, min 0,
offers 3, picks 1, wave 0, floor 0, seal 0}; t1 {#5AD87A,
unown 2, charge 14, r 5.5, drain 5, min 1, offers 3,
picks 1, wave 0, floor 0, seal 0}; t2 {#C070FF, unown 3,
charge 22, r 5, drain 4, min 2, offers 3, picks 1, wave 4,
floor 3, seal 0}; t3 {#FFD23A, unown 5, charge 35, r 4.5,
drain 3, min 3, offers 4, picks 2, wave 6, floor 5,
seal 90}; t4 comet {#4AA8FF, unown 0, charge 10, r 6.5,
drain 3, min 1, offers 3, picks 1, wave 2, floor 0,
seal 0} — comet altars are event-spawned, out of scope.
QC names: "Altar Unown" / "raro" / "epico" / "dorado" /
"Fragmento de cometa" -> CN 未知祭坛 / 稀有未知祭坛 /
史诗未知祭坛 / 黄金未知祭坛. Altar object r = ZC.r (add()
@~1239100); wave tiers get a light pillar (beacon, alpha
.3 while sealed). Label @~1249501: used -> "Altar
agotado"; else "{name} · quedate dentro para cargarlo".
Altars are EXCLUDED from the E-interact nearest logic —
they charge by presence alone.

altarUpdate(e, dist, dt) @1267643: charge seconds s =
ZC.charge * (1 + .25*(min(3,stage)-1)) / (1 + .3*secret
key items [we have none -> /1]). Tier 3 is sealed while
stageTime < seal (90 s): inert, grey, beacon dim; unseal
fires altarWake (toast + ring). Inside (dist < ZC.r,
player alive): charge += dt/s solo (crew mult 1+.6*(crew
-1), crew is 1). Wave tiers: one-time warning toast on
first charge; waveT starts 1.5, resets to s/wave; each
wave (altarWave) spawns (t3 ? 4 : 3) + min(3,stage)
enemies ringed 9-12u around the altar from the animated
pool, hp/dmg scaled at director mults with a MINUTES
FLOOR = ZC.floor (3 / 5); tier-3 first enemy of every
even wave is Elite. Outside: 1.2 s grace, then charge
decays dt/(drain) (full drain in `drain` s). Charge ring
drawn while 0 < charge. charge >= 1 -> altarDone
@~1268500: used, dim; offerBlessing(QC(tier), min =
ZC.min, offers = ZC.offers, picks = ZC.picks); VFX ring
radius 6+tier*3 (audio skipped — no audio system).

offerBlessing(title, minTier, offers, picks, pool=1)
@1481319 (run method): if state != play it defers via
whenFree; else state = modal, showBlessing with offers
from Xx(run, min, offers, pool); each pick pushes
pick.mods into player tempMods + recompute(); picks > 1
re-picks from the REMAINING offers; then resume.
Xx @1075554: 12 generators shuffled, take n; offer tier
i = max(minT, Bx(run)); power = pe[i] * poolMul,
pe = [1, 1.2, 1.45, 1.75, 2.1] (news @41252, imported
as Hr). Generators (label rounds, mods exact): damage
mul 1+.12e; attackSpeed mul 1+.10e; maxHp add 20e;
moveSpeed mul 1+.08e; critChance add .06e; area mul
1+.12e; xpGain mul 1+.15e; regen add .8e; armor add 8e;
luck add 15e; duration mul 1+.2e; statusChance mul
1+.2e. Bx @1069962 (rarity roll): i = max(0, luck);
a = i/100; o = level + i/8 + (stage-1)*12; s(lo,hi) =
clamp01((o-lo)/(hi-lo)); weights [70/(1+a), 24*(1+.5a),
5*(1+a)^2*s(3,10), .9*(1+a)^3*s(8,18), .12*(1+a)^4*
s(14,26)]; tiers below the min param x1e-4 (Xx calls Bx
with min 0 -> no suppression; the x1e-4 arm is chest
rolls). Blessings are RUN-scoped (tempMods live on the
run's player object; our Player is recreated per run).

Rhydon roar totem: label @1249501, interact case
@1252885 -> zy(run, totem) @~866030. Interact radius
r+.8 = 4.0 (totem r 3.2, model 'totem' h 4.3, faces the
origin). If bossSpawned -> deny toast. Else n =
++run.roars (run-scoped, init 0 @1439106, persists
across stages; run.shrines.roars = max); totem.used
when n >= 3 (so a FRESH totem in a later stage can add
exactly one more beyond 3 — the original edge; buffs
scale unbounded). Rune stone n-1 lights (emissive 3.2);
horn spins .9 s; rings radius 10+3n (colour 0xC8783A)
and 6+2n; shake .35+.12n; hitstop .08; banner "¡Grito
de Rhydon! (n/3)" + subtitle: guardian +30n% HP,
+12n% damage, more elite escorts; +n Super Balls on
kill. Ly=.3 / Ry=.12 @~866000. Labels: used or
bossSpawned -> "Rhydon descansa · {n} gritos"; roars>0
-> the +30%/+1 Super Ball line; else the full text.
Application in boss.spawn @996027 (next item):
roars read at spawn; onBossKilled @1462726 pays +1 free
chest per roar (our _on_guardian_killed ALREADY pays
e.roars chests — cycle 14 changes e.roars' SOURCE from
the cycle-9 invented HP-threshold crossings to the
shrine count; enemy.gd's threshold-roar generation is
REMOVED: the bundle assigns boss.roars only at spawn).

## Item 2 — guardian HP: spec mined

enemies.spawn @325140: base HP = (12 + bst*.055) *
hpMult * toughness * flagMult; bosses SKIP toughness.
Flags: elite x4.5 HP / x1.4 dmg / scale 1.35; alpha x22
/ x1.8 / 2.0; boss x70 HP / x2.2 dmg / scale 2.6 (our
guardian spawn scale was 2.3 -> aligned to 2.6).
hpCurve(stage, tMin) @~855230: base [1,5.5,13,20],
r [.15,.07,.05,.05], i = max(0, t - (stage==1 ? 1.5 :
0)); (1 + .3t + i^2*r) * base — identical to our consts.
effTime @~855100: stageTime + pt[stage-1] * min(1,
stageTime/20), pt = [0, 75, 150] (news @89269; stage 4
-> 0); effMin = effTime/60. director.hpMult(t) standard
form = hpCurve(stage, max(t, effMin)) * diff.enemyHp(1)
* stats.difficulty(1) * swarmMult(1). dmgMult(floor) =
(1 + max(floor, effMin)*.13) * v[stage-1] * late(1) —
v = our STAGE_DMG [1,2,3.1,3.4].

boss.spawn(species, x, z, legendary, opts) @996027:
roars = endless ? 0 : run.roars; o = 1 + .3*roars;
hpMult arg = (opts.hp ?? hpMult(legendary ? 0 : Sb) *
(legendary ? 1.6 : 1) * BOSS_ZONE_HP[stage-1]) * o,
Sb = 2.5 minutes floor @995138, BOSS_ZONE_HP =
[.8,.55,.5,.5] @~855361 (ours already matches).
dmgMult arg = director.dmgMult() * (1 + .12*roars).
fightSecs = (legendary ? 60 : guardian[min(2,stage-1)])
* o, xb.guardian = [40,50,60] @995014 (ours matches).
Stage>=3 non-sanctuary guardians take the LEGENDARY
species path in spawnBoss @1459438 — our stage 4 uses
the legendary branch (minutes floor 0, x1.6).
Tb(run, idx, budget) @995317: if budget > maxHp:
hp = maxHp = min(budget, maxHp*4, 1e30). Budget =
Cb(run, secs) @995145 = combat.meter.budget(secs *
(1+.15*tier) * stats.difficulty); tier 0, difficulty 1
-> meterDps * fightSecs, with fightSecs ALREADY
roar-scaled (order in spawn: secs first, then budget).
Combat meter (class B_) @~720250: per-target damage in
1-second windows keeping the window BEST (max single
target); tick(1 s) pushes best into hist (cap 120);
dps = hist sorted, element at floor(len * .85); budget
= dps * secs; empty hist -> 0. Meter feed in hit0
@~727415 (slot != 8 only): boss targets add post-cap
dealt / exhaustFactor; others add min(dealt, hpBefore)
/ hordeWeight (we have no horde merging -> weight 1).
DoT ticks feed it too (@737969).
Eb(run, idx, n) @995459 (damage cap): capRate =
maxHp / n, capBank = capRate * 3, capT = now; n =
wb.guardian[min(2,stage-1)] * o, wb.guardian =
[25, 30, 35] @995239. capHit @~730324: avail =
min(capRate*3, capBank + max(0, now-capT)*capRate);
dealt = min(dmg, avail); capBank = avail - dealt;
capT = now. Applied in hit0 AFTER every multiplier and
AFTER exhaust, to ALL channels (direct + DoT).
Exhaust (boss.exhaust, Nb class): fightT ticks from
spawn; t = fightT - 2*fightSecs; t > 0 -> damage-taken
multiplier min(1e9, 2^(t/20)), applied pre-cap.

OUR GAP (pre-fix): summon_guardian used player.get_dps()
— a THEORETICAL move-stat DPS from player.gd, not the
meter — times GUARDIAN_SECS times BOSS_ZONE_HP: no
formula floor, no x70 boss flag, no 4x budget cap, no
damage cap, no exhaust, no roar factors. Cycle 14
replaces it with the mined pipeline (formula floor ->
meter budget raise capped at 4x -> Eb cap + exhaust on
the guardian -> roars from item 1).

## Item 3 — wet: spec mined

The original keeps PARALLEL per-status timers on enemies
(burn/poison/para/wet/chill/frozen/... arrays decaying
together @~337234); statusCount @~731380 counts wet
among them; the player has NO wet field (verified: wet
exists only on the enemies class). applyStatus @731454:
wet[e] = 5 * stats.duration (ASSIGN), countOnce(e, 64,
'soaked'). Freeze path: chill = min(3, chill+1); if wet
> 0 the chill jumps to 3; at chill >= 3 the freeze
consumes wet (wet = 0). Our engine has direct freeze
(no chill stack): a freeze landing on a wet target
consumes the wet — documented mapping.
Electrocute (reactions() @~733583, called from hit0
after the type chart, before the cap): on a hit landing
on a wet target with an electric move (not noReact;
global 0.25 s per-key cooldown): popup "¡Electrocutado!",
meta 'electro'; the target's wet is consumed; up to 12
OTHER wet enemies within 9u each take hit(packet * .8,
{type electric, same class, status paralysis, chance
.6, noReact, fixed, same slot}) — fixed = full defender
pipeline, no attacker item scaling, no further reactions;
chain targets' wet is NOT consumed; the primary hit's
damage is then x1.5. Wet tint (render @~339641): albedo
multiplier ~ (0.90, 0.95, 1.08) — our ModelRig mapping.
Sources: Bg[7] ult riders (cycle-13 spec: wave helper
{wet 1, knock 6}; whirlpool ticks {wet .6}; cannon
ticks {wet .5}); rain ambient (weatherFx @1489897):
per ambient gate (rand < dt*2) enemies within 25u get
wet = max(wet, 2) RAW (no duration scale), 'soaked'
counted only when the rain is timed (weatherT > 0);
water-type strikes via the J_ type->status map
@~721176 (water -> wet) — our GameData.ALLY_STATUS gains
"water": "wet" (it had omitted water; player move-level
wet riders do not exist in moves.json, matching the
original's data — player normal attacks do not wet).
Durations scale by player stats.duration — our player
had no duration field: duration_mult added (also the
consumer for blessing duration mods and lab/passive
duration stats), applied centrally in Enemy.apply_status
and the wet assignment (the original scales inside
applyStatus the same way; existing duration checks stay
exact at duration_mult = 1).

## Fix applied (cycle 14)

- scripts/world.gd — interactables: ALTAR_CFG / ALTAR_NAMES /
  BLESSING_DEFS / BLESSING_PE consts; _altar_tiers (tw port),
  _inter_sample (populate's r() port; landmarks = boss altar
  r 2.7 + spawn r 3, terrain reserve approximated by the
  existing _flat_open gate — the bundle reserves flat ground
  at generation instead), _build_interactables (5 altars with
  tw tiers + 1 totem per zone, seeded 30634 ^ zone*7919 —
  the bundle's Tu(seed ^ 30634) shape with our zone seed),
  built with each zone scene and parked/restored through the
  scene cache ("inter_root" entry, incl. the prebuild holder
  path); _inter_reset in start_game. Altar visuals: tier
  torus + progress fan (ArrayMesh rebuilt on 1/24 buckets),
  twin-cone crystal (per-altar emissive material; grey at
  [.55,.55,.6] while sealed, dim when used), 4 pillars,
  orbiting Unown shards on the unownPos formula, beacon
  cylinder for wave tiers. _inter_tick -> _altar_update
  (altarUpdate port: seal/wake, presence charge at
  dt/charge_secs with stage factor (1+.25*(min(3,stage)-1)),
  wave timer s/wave, 1.2 s grace then drain) and
  _altar_wave (ring spawns at the ZC.floor minutes floor for
  BOTH hp and dmg; tier-3 even-wave first spawn Elite).
  _altar_done -> offer_blessing. Totem: _totem_near /
  _totem_label / _roar_at_totem (zy port: run_roars,
  used at >= 3, horn spin .9 s via horn_t, rune stones light
  at emissive 3.2 mirroring run_roars, rings 10+3n / 6+2n,
  trauma .35+.12n, hitstop .08, banner with 30n/12n/+n);
  wired into the interact chain (capture > totem > boss
  altar) with the altar presence hint as the fallback prompt.
- Blessings: _build_blessing panel (draft idiom);
  offer_blessing (queue while a modal owns the run —
  whenFree — processed from _process when state returns to
  playing/guardian); _blessing_roll (Xx port: shuffled 12
  generators, tier = max(minT, Bx), power pe[tier]);
  _blessing_tier_roll (Bx port); _apply_blessing_offer =
  the button path (temp_mods.push duplicate + recalc,
  re-pick from remaining offers, close into the remembered
  return state — blessings can complete during "guardian",
  so the return state is stored, unlike the draft's).
- Combat meter (B_ port): meter_add / _meter_tick /
  meter_dps / _meter_reset on World; fed from combat_hit
  (every slot except 8, amount = Enemy.last_meter_amount)
  and from Enemy._dot_tick. _hp_curve extracted from
  _spawn_mult (identical values); _eff_minutes (effTime
  port, pt = [0, 75, 150, 0]); _spawn_enemy_at gains an
  optional dmg_minutes floor (altar waves).
- summon_guardian rewritten to boss.spawn: formula floor
  (boss flag x70, bosses skip toughness, scale 2.6 — was
  2.3), stage-4 legendary branch (floor 0, x1.6), roars
  from run_roars (HP/dmg/fightSecs/cap divisor all scale
  by o = 1+.3 roars; dmg additionally x (1+.12 roars) on
  top of the boss x2.2), meter budget raise min(budget,
  4x formula) via Tb, Eb cap armed via set_damage_cap,
  escorts 2 + run_roars elites. boss_spawned latches per
  stage (reset in _advance_zone / start_game).
- scripts/enemy.gd — wet: wet_t parallel timer +
  apply_wet_status (assign 5 x duration, 'soaked' once) +
  apply_wet_raw (rain max) + the "wet" ailment arm in
  take_damage; freeze consumes wet; rig wet tint via
  set_wet transitions in the physics tick. Guardian cap +
  exhaust: cap_rate / fight_secs / _cap_bank / _cap_clock,
  set_damage_cap / _cap_hit (Eb port), exhaust multiplier
  2^(over/20) past 2x fight_secs applied pre-cap in
  take_damage; _dot_tick routes through the cap and feeds
  the meter; last_meter_amount recorded per take_damage
  (post-cap/exhaust-adjusted for bosses, min(dealt, hp)
  otherwise). apply_status scales durations centrally by
  the player's duration_mult. REMOVED: the cycle-9
  HP-threshold roar generation (bundle assigns boss.roars
  only at spawn — the cycle-9 DIFF entry's "thresholds
  INFERRED" caveat is hereby resolved against the bundle).
  world.guardian_roar is now uncalled (kept as a utility).
- scripts/player.gd — duration_mult (reset in recalc) and
  temp_mods: recalc applies temp mods LAST, in push order,
  over the blessing stat vocabulary (damage / attackSpeed
  / maxHp / moveSpeed / critChance / area / xpGain / regen
  / armor / luck / duration / statusChance). A fresh
  Player per run makes blessings run-scoped exactly like
  tempMods.
- scripts/model_rig.gd — set_wet channel: _apply_flash_fade
  multiplies base albedo by (0.90, 0.95, 1.08) while wet
  (flash overrides while active).
- scripts/ult.gd — Bg[7] wet riders wired: wave helper
  opts {status wet, chance 1} at all three _wave call
  sites, whirlpool ticks {wet .6}, cannon ticks {wet .5}.
- scripts/world.gd weather: _weather_tick admits rain —
  enemies within 25u get apply_wet_raw(2, timed) per the
  ambient gate.
- scripts/game_data.gd — ALLY_STATUS gains water -> wet
  (J_ port completion for the wet layer; grass -> root
  noticed as an adjacent gap, NOT wired — root via allies
  is a separate change).
- scripts/profile.gd — "soaked" / "reactions" /
  "best_reactions" leave UNSUPPORTED_COUNTERS (cycle-13
  ultimates precedent); world._finish_run merges both
  counters. Electrocute increments run_counts "electro"
  (bookkeeping, mirrors their meta count) and "reactions".

Named approximations / gaps (honest):
- VERIFIED: altar counts/tiers/charge/wave/blessing math,
  totem roar chain and its guardian deltas, guardian
  formula/budget/cap/exhaust numbers, wet
  apply/decay/consume/electrocute/rain — all through the
  harness phases below.
- 近似： placement uses our seeded RNG + _flat_open
  rejection instead of the bundle's terrain-reserve
  sampler (positions differ, distribution matches);
  regular enemy spawns keep RAW stage minutes in
  _spawn_mult (the bundle's director uses effMin there
  too — pre-existing simplification, guardian path is
  exact); wave-tier escorts for the guardian are our
  mapping of "mas escoltas elite" (2 + roars); the chain
  packet treats the bundle's `fixed` as "no second type
  chart"; wet tint is an albedo multiplier on the rig's
  calibrated materials (theirs is a renderer colour
  multiply); altar idle pulse FX / beacon shimmer /
  roar cry audio are not reproduced (no audio system);
  freeze-consumes-wet maps their chill-stack jump onto
  our instant freeze.
- 阻塞/backlog: the other populate kinds (greed /
  challenge / cursed / fossil / porygon / bill / nest /
  meowth / ditto / hypno / snorlax / magnet / slots /
  chests / berry / cage / rock) are mined but unbuilt;
  comet altars (event-spawned) unbuilt; the other
  reactions (steam / wildfire / shatter / gas) unbuilt;
  secret-key items (altar charge divisor, drain x2) do
  not exist in our build.

### Verification ledger (this cycle)

- New harness phases (Test/harness.gd, real flows only):
  shrine 24/24, bossscale 12/12, wet 18/18. Highlights:
  tier multiset == [0,0,1,1,2] (tw); roars 1/2/3 through
  the real E chain (hold-and-wait pattern — render-frame
  sampling lags taps headless, the KeyR lesson); charge
  growth 0.249 after 120 frames in an 8 s tier-0 circle,
  drain to 0.005 after the grace; wave altar completes ->
  blessing with ZC offer count, pick applies its mod
  EXACTLY (damage 1.04 -> 1.22096 both sides); roar
  guardian HP == formula x 1.9 to the cent (7985.32),
  capRate == HP/(25 x 1.9), fightSecs 76, chests 1+3.
  Meter: window best == dealt to 1e-13; formula floor
  4202.8 exact with a short budget; budget raise lands on
  exactly 4x formula (16811.2); bank drains exactly
  3x capRate (2017.344), same-frame second blow == 0,
  refill ~capRate after 65 frames; exhaust at +20 s over
  == x2 to the cent (1344.896). Wet: apply == 5.0 with
  the slot empty, soaked once, decay 5 -> 4 in 60 frames,
  electrocute x1.5 exact (63.0915... both sides), chain
  == packet x .8 to 1e-13, chain keeps its wet, dry
  bystander untouched, 0.25 s gate blocks then releases,
  freeze consumes, ult wave soaks (KeyR fire), timed
  rain == max(wet, 2) + timed-only counting.
- The cycle-9 guardian phase's kill segment was adjusted
  for the cap (bounded hit-until-dead loop, 7200-frame
  bound; assertion intent unchanged) — it passes.
- Mutation proofs (each reverted after its run): blessing
  pick without recalc -> exactly the pick check fails;
  _cap_hit unclamped -> exactly the three bank checks
  fail; electrocute without the wet consume -> exactly
  the two consume checks fail. (A third rain-count red in
  the M3 run was a HARNESS flake — the whirlpool poll can
  exit on tick 1 while the repeater still runs and soaks
  the rain pin early; fixed by waiting out the cast +
  pinning outside ult radius, re-verified green.)
- Full suite (resident profile): 120 checks, 119 PASS;
  the one fail is the documented local-profile trap
  ("revive: lab revive purchasable" — the profile already
  owns revive). Fresh-profile revive group: 8/8 PASS.
  The pre-cycle profile was vaulted
  (Test/profile_vault/profile_precycle14.json) and
  restored byte-identical afterwards (sha256 e15aee84...
  — the same bytes cycle 13 restored; verified again
  after the boot smoke).
- check_starters: 3/3 PASS. Class-cache gate: OK.
- APK: build/android/SpriteBonk.apk, 53,538,290 B,
  sha256 bf2e25c278f952082dd8a1d605ff18f85d425334eeb0dfd944bc3e0b4c8515b3,
  cert b05b80e1...a232 (unchanged). Linux-export boot
  smoke: shipped binary ran the full 130 s window with
  no script errors (menu up; stdout prints were lost to
  buffering on the timeout kill — load failures print to
  stderr and none appeared).
- Process finds worth keeping: (a) synthesized key TAPS
  are unreliable for the world's render-frame interact
  sampling — hold the key and wait for the observable
  effect, and give the RELEASE a long sampling window or
  _e_prev stays latched and later presses have no edge;
  (b) a poll that exits on a repeater's first tick leaves
  the repeater running into the next segment — wait out
  effect lifetimes before re-pinning targets.

# Cycle 15 — elemental reactions completed, comet altars,
# populate kinds built out (work order 2026-10-26)

## Item 1 — reactions: full table re-verified (main chunk
## byte offsets, tail -c verified this session)

reactions(e,t,n) @733487; gate canReact(name) @733151 =
GLOBAL per-key 0.25 s cooldown map (keys elec/steam/fire/
shatter/gas/mind/dragon; the popup itself is gated by
canReact("pop"+name)); react() @733252 = popup at
(x, y+height+1.4, z), scale 1.1, run.stats.reactions++;
resist(e): boss flag -> 0.35, flags&12290 (elite/alpha
class) -> 0.6, else 1. Branches test IN ORDER, first match
returns; t = post-type-chart packet; n.noReact (chain
packets) never re-enters. Electrocute @733581 shipped in
cycle 14 (wet + electric, x1.5, chain <= 12 wet within 9u
at packet x .8, paralysis 60%, wet consumed).

- STEAM @733964: primary burn>0 + WATER hit. react
  ("¡Vapor!", 14741759 = 0xE0F0FF); burn[primary] = 0;
  EVERY enemy within 6u INCLUDING the primary (no
  exclusion): countOnce(e,32,'confused'),
  confuse = max(confuse, 2.5 x resist), root =
  max(root, 2 x resist). Return t x 1.4. (14 soft
  particles = cosmetic, skipped.)
- WILDFIRE @734411: primary burn>0 + GRASS or FLYING
  hit. react("¡Incendio!", 16738842 = 0xFF6A1A); EVERY
  enemy within 7u incl. primary: applyStatus(burn)
  [burn = 3 x duration factor; burnDps = max(dps,
  t x .3 x statusDamage)]; then the primary's burnDps =
  max(burnDps, t x .39 x statusDamage). Primary burn is
  NOT consumed. Return t x 1.3. ENGINE MAPPING: our DoT
  is the standing flat 4.0/s tick (cycle 13's ult phase
  pins a DoT kill "within a second" on it) — the two
  burnDps magnitudes have no per-enemy channel in our
  engine and are NOT ported; the spread set, radius,
  multiplier, gate and counters are exact.
- SHATTER @734743: primary frozen>0 + FIGHTING/ROCK/
  STEEL hit. react("¡Destrozo!", 9103615 = 0x8AE8FF);
  frozen[primary] = 0; every OTHER enemy within 5u:
  hit(t x .7, {type ice, fixed, noReact}). Return
  t x 2.6. ORDER verified: the bundle's damage()
  applies its frozen x1.2 strike multiplier (@724799)
  BEFORE hit() calls reactions() (@726000), so a
  shatter hit totals x2.6 x 1.2; our branch folds the
  x1.2 in explicitly (the reaction clears the slot
  before take_damage could see it — same product).
  (damage() also has an ice-heal ITEM branch that
  unfreezes for x1.6+ per stack on any hit — item
  system, not ported.)
- GAS @735065: primary poison>0 + FIRE hit. react
  ("¡Gas Tóxico!", 12606207 = 0xC05AFF); r =
  poisonStacks[primary]; poison = 0, stacks = 0; every
  OTHER enemy within 6u: hit(t x (.5 + .12r), {type
  poison, status poison, chance 1, fixed, noReact}).
  Return t x (1.4 + .1r). Stacks come from applyStatus
  @731739: poison application ASSIGNS poison = 5 x
  duration factor and stacks+1 (cap 10). ALIGNMENT:
  our take_damage poison arm applied 3.0 s flat; it now
  applies 5.0 s (the bundle's poison base) and maintains
  poison_stacks. Single-slot adaptation: stacks reset
  when the poison slot expires or is overwritten (the
  bundle's parallel arrays let stale stacks outlive the
  poison; gas still requires poison active, so the only
  observable difference is a re-poison starting at 1
  instead of a stale count — flagged, accepted).
- MIND COLLAPSE @~735500 (same table; built — every
  system it touches exists here): primary paralysis>0 +
  PSYCHIC hit. react("Colapso mental", 16734880 =
  0xFF5AA0); paralysis = 0; confuse = max(confuse,
  4 x resist) on the primary only, countOnce confused.
  Return t x 1.6.
- DRAGON FURY @~735700 — NOT BUILT, evidence: trigger
  state is charm[primary]>0, and charm has NO source in
  our build (GameData's J_ status map yields "" for
  charm — DIFF cycle 9 finding, re-verified by grep this
  session: no move/ability applies it). Rule for the
  record: charm NOT consumed, return t x 2, color
  8018687.

Engine notes: our single status slot gains two PARALLEL
timers, mirroring the wet precedent — confuse_t and
root_t on Enemy (the bundle is fully parallel: its slot
"confuse"/"root" arms stay for move-applied statuses and
are untouched). resist_factor() maps the bundle's flag
classes onto ours: flag 4 (boss/guardian) -> 0.35,
flag 1/2 (elite/alpha) -> 0.6, else 1. Steam/mind
confusion durations are RAW resist multiples (direct
field writes in the bundle — no duration-factor scaling),
and count through the bundle's countOnce channel, so
Enemy gains a generic count_once(key, counter) beside
the soaked one. Reaction popups use our CN floater idiom
with the bundle's colors （蒸汽！/野火！/碎裂！/毒气！/
精神崩溃！; electrocute's 触电！ is the precedent).

## Item 2 — comet altars: spec mined

ZC tier 4 (cycle 14 table): color #4AA8FF =
Color8(74,168,255), unown 0, charge 10, r 6.5, drain 3,
min 1, offers 3, picks 1, wave 2, floor 0, seal 0 —
appended to ALTAR_CFG (index 4) + ALTAR_NAMES
"彗星祭坛". It is NEVER populated; it is event-spawned:
- spawnComet(x,z) @1245186: add('altar', {data:{tier:4,
  comet:true, life:60}}); sky-fall 0.9 s + landing
  ring/flash/shake (visual; audio skipped — no audio
  system in this build, standing gap).
- updateComet @~1356838 (events): at most one live
  comet; if the comet's ref leaves the stage's
  interactable list the ref clears (stage change drops
  it — ours: _advance_zone frees the comet root, the
  TIMER keeps running). cometT initial value = _E
  @1349051 = 75.0 s; after each spawn cometT =
  range(100,140) s. On expiry: point = randomPoint
  25-40u from the player; if the point lands < 18u away
  cometT = 10 (retry); else spawn + toast "彗星碎片坠落
  了！在它熄灭前为它充能" (+ alarm sound, skipped). The
  mewtwo.active gate has no system here — vacuous.
- BURN-OUT (interactables update @~1260597 + burnOut
  @1272478): while data.comet && !used && charge <= 0,
  (life -= dt) <= 0 -> burnOut: used = true, grey splash
  burst + toast "彗星碎片熄灭了…", NO payout. The 60 s
  life ticks ONLY at zero charge — once charging starts
  the comet is safe (altarUpdate drains charge outside
  the circle as usual, but life never resumes ticking:
  the band is charge <= 0 exactly, and our port checks
  the same each frame before charging applies — order
  note: the bundle's band runs in iw.update BEFORE
  altarUpdate in the same frame; ours does the same).
- Charging/waves/payout are altarUpdate-identical
  (tier from data.tier): tier 4 has wave 2 — wave size
  (tier==3 ? 4 : 3) + min(3,stage), floor 0 minutes;
  the wave-warning toast has a comet variant: "彗星吸引
  了兽群！留在圈内". Completion pays offerBlessing with
  ZC[4] (min 1, offers 3, picks 1). cometHere @~1357385
  (objective/HUD getter) — no consumer in our HUD; noted,
  not ported. The bundle's player.anchorT = .2 while
  inside (movement anchor) stays unported, as in
  cycle 14.

## Item 3 — populate kinds: assessment + build specs

Assessment method: every kind's add() kind string,
labels (LOC @1247900-1249501), the interact switch
@1251190, and its effect body were read at real offsets
this session. The cycle-14 framing "payouts are item
rolls" predates a fact this session surfaced: OUR build
already has a documented chest mapping (cycle 9) — the
bundle's chest item roll == our vitamin grant via
_grant_vitamin (GameData.VITAMINS accumulators), used by
the guardian's free chests. Cycle 15 generalizes that
established mapping instead of inventing a new one:

  rollChestItem(free, tierFloor, count) -> count vitamin
  grants, each at rarity tier = max(floor, Bx roll),
  power pe = BLESSING_PE[tier] (the draft/chest rarity
  power table). Count 1 grants directly (the free-chest
  precedent); count > 1 opens a PICK-1 choice (the
  bundle shows the rolled items and takes one, or sells
  all — see paid chest). Tier floors: free +!!e = 1,
  paid/gift 0, explicit r passes through (Gx @1478225:
  Gx(run, t ?? +!!e)).

### Built (14 kinds; counts at areaMul = 1 in our
### 360-world; placement continues the SAME seeded
### sampler stream after altars+totem, so existing
### layouts are byte-stable)

- berry x5 (r 2.6): interact @1252440 — heal 50%
  maxHp (our leech_heal applies heal_mult + healed
  counters), meta.count('berries'), one-shot, dims.
- rock x14 (r 2.6): gold += round(range(6,14) x
  max(stage, VC/90)); count('rocks'); plus a 15% x
  luckMult chance of a pickup spawn at the rock —
  MAPPED IN PART: our build has no pickup entities
  (XP/gold are instant-credit). Of the bundle's
  candidate kinds, only heal has a referent, and only
  under the bundle's own first condition (player
  hurt): the branch then pays an instant heal of 25%
  maxHp (the heal pickup's value, instant-credited the
  way our build credits everything). At full HP the
  roll yields nothing: magnet needs XP gems (none),
  bomb's magnitude is unmined, and balls are not a
  resource in our build (throws are chance-based, no
  inventory — _throw_ball). VC = chest value =
  CHEST_BASE(18) x BC(chestsBought),
  BC @1234939: (1.22^e + t/30) x 1.12^max(0,e-12),
  t = 35e + 300 max(0,e-10) + 550 max(0,e-20) +
  1200 max(0,e-30) + 2400 max(0,e-30) + 4500 max(0,e-30)
  (the e>40/e>50 terms really do reuse (e-30) in the
  source — transcribed as-is).
- snorlax x2 (r 2.6): n = randf; if n < min(.85,
  .5 x luckMult) -> offerBlessing(title, min 0, offers
  3, picks 1) else gold += max(30 x stage, .5 x VC);
  a random flavor line shows either way (NC table,
  CN ours); one-shot.
- greed x1 (r 2.6): run.greed++ (counted), tempMods
  difficulty x1.2 + xpGain x1.25 + gold x1.25 + recalc,
  banner; one-shot.
- cursed x1 (r 3.0): tempMods enemyAmount x1.15 +
  difficulty x1.1 + recalc, curses++, banner; after
  0.8 s rollChestItem(false, 2) — one vitamin at
  pe[max(2, Bx)]; one-shot.
- chest x14 (r 2.6, PAID): cost chestCost @1237871 =
  round(18 x BC(chestsBought) x (1 - min(.25,
  luck/400))) (item discounts = 1: no items; endless
  curse factor n/a). Deny if gold < cost (label reads
  the price; not used). Pay -> OPEN @1253770:
  used, chestsBought += 1, rollChestItem(false,0,3) =
  choice of 3 vitamins (distinct keys), pick 1, or
  SELL ALL for min over the 3 of qC(tier) @1077141:
  round(max([10,18,30,50,90][t] x stage,
  min(.5 x Qx[t] x WC, GC[t] x VC))) with Qx =
  [80,130,220,400,750], GC = [.3,.45,.65,1,1.5],
  WC(stage) = stage^(min(4,stage)-1)... WC is the
  shop/wallet curve (WC(e,t) = t^(min(4,stage)-1)
  non-endless) — for qC the call is WC(run, rarity) so
  t = the item's rarity: rarity^(min(4,stage)-1).
- freechest x3 (r 2.6): open -> rollChestItem(true) =
  one vitamin at pe[max(1, Bx)] + 'chests' counter
  (same presentation as the guardian chest). NOTE: the
  guardian's own _open_chest still grants its cycle-9
  flat pe 1.0 — that path is a different spawn source
  (boss.spawnChest) and is deliberately left as-is;
  populate freechests use the mined floor-1 rule.
- cursedchest x2 (r 2.6): open (free) -> tempMod
  difficulty x1.05 + recalc; after 0.2 s: ambush
  4 + 2 x stage of RC roster ringed 6-8u around the
  PLAYER, first Elite, director mults; and
  rollChestItem(false, r) with r = 2 (50%) else 1.
  RC @1234939 = [92,92,93,93,94] (dex numbers) ->
  [gastly, gastly, haunter, haunter, gengar] (all
  modelled), index = min(4, stage-1 + (first ? 2 : 0)).
- challenge x2 (r 3.2): startChallenge @~1255600 —
  ONE species from the stage pool, count 8 + 3 x stage
  ringed 8-11u around the SHRINE, first
  1 + floor(stage/2) are Elite, staggered .15 + i x .08
  s, director mults; used at once. Completion (iw.update
  @1258148: pending == 0 and every wave enemy dead) ->
  challenges++, banner, spawn a FREE chest (above) at
  shrine + (2.5, 2.5), shrine stays dimmed.
- slots x2 (r 2.4, REPEATABLE — never "used"): cost
  iS @1077390 = max(5, round(40 x WC(run,2) x
  1.08^slotSpins)) (item discount tS = 1); weights
  rS @1077277 walked in order with a uniform roll:
  seven .018 (x luckMult clamped [1,2]), pikachu .05
  (x luck), berry .09 (x luck), meowth .1, voltorb .06,
  gengar .06 (skipped once slotPrizes.gengar >=
  gengarMax = 15, news chunk S table); remainder none.
  Prizes cS @1078040: seven -> rollChestItem x3 at
  floors 3,1,1 (three single grants); pikachu -> one
  at floor 2; berry -> heal 25% + one at floor 0;
  meowth -> gold += cost x 2.5; gengar -> curses++,
  tempMods enemyAmount x1.05 + difficulty x1.05;
  voltorb -> after .3 s, lS @~1078560: 3 + stage
  ambush ringed 5-7u around the MACHINE, first Elite
  (electrode at stage >= 2) — SPECIES MAPPED to zone
  pool (voltorb/electrode have no models in our build —
  ModelRig.SPECIES lacks both; mechanics/count/flags
  exact). slotSpins/slotPrizes/slotSpent are RUN
  fields shared by both machines. The reel UI
  (showSlots) is presentation; results resolve at once
  with banner/floater, like cycle 14's altar FX trims.
- cage x2 (r 2.6): cost = 20 + stage x 10 gold; deny
  (not used) when short; else pay, used, addXp(xpNext
  x .5) (our gain_xp applies xp_mult — the bundle's
  addXp applies stats.xpGain the same way); the caged
  species visual (zone-pool species rolled at
  populate, @~1242900) hides on freeing. The bundle's
  addResearch(species, 25) has no per-species analog —
  our Lab 'research' is a global stat (+1 XP/s use);
  NOT mapped (named here, not faked).
- nest x1 (r 2.8) / egg system (objective class,
  pp/gp/hp @317944/319200/318442): data.species =
  fp() at populate = random root from the stage pool.
  Interact: if an egg is already carried -> deny toast
  (nest NOT used); else used, egg = {from: kills,
  need: 200 + 100 x (min(3,stage)-1), species}. The
  egg rides beside the player (small orbiting visual).
  Hatch when kills - from >= need AND state == play:
  eggs++, banner, recruit the species at the player's
  side (our spawn + make_ally). The bundle's recruit
  fallback (rollChestItem(), one grant at floor 0) IS
  reachable here: our build has the §5.3 team cap
  (allies >= 2 + Lab 'party', enforced in _throw_ball)
  — at cap the egg pays the chest roll instead (eggs++
  and the hatch banner happen either way, gp order).
- porygon x1 (r 2.4): trade modal. By table @866978 =
  12 entries on EXACTLY our blessing stat vocabulary;
  gains: damage x1.3, attackSpeed x1.25, maxHp x1.25,
  moveSpeed x1.2, critChance +.15, area x1.3,
  xpGain x1.4, regen +2.5, armor +20, duration x1.4,
  statusChance x1.4, luck +40 (luck has NO loss entry);
  losses: damage x.85, attackSpeed x.88, maxHp x.85,
  moveSpeed x.9, critChance -.08, area x.85,
  xpGain x.8, regen x.6, armor x.75, duration x.8,
  statusChance x.8. Vy() @868812: 3 gains from a
  shuffled By; losses = shuffled loss-capable entries
  whose stat is NOT among the gains, paired index-wise
  (offer = {gain entry, loss entry|null}). Offers roll
  on FIRST open and PERSIST per altar (e.data.offers
  ??= Vy()). Pick (Hy @869123): push gain+loss mods
  into the run's recompiled list + recompute, used,
  one-shot. Closing without picking leaves it unused
  (offers persist). Our port: a dedicated trade panel
  in the blessing-panel idiom; player.recompiled_mods
  apply in recalc AFTER temp_mods (the bundle's
  recompiled list applies inside its own recompute
  pass; per-stat mul/add commute here — no stat can
  appear in both lists with conflicting shape except
  maxHp, where order only shifts the round; flagged).

### Player/director arms this required (bundle-true)
- tempMods vocabulary gains "gold" (gold_mult *= mul —
  the passive arm already had it), "difficulty" and
  "enemyAmount". Player fields difficulty_mult /
  enemy_amount_mult reset in recalc like the other
  derived stats.
- Consumption (director @855400-858360): hpMult =
  hpCurve x diff.enemyHp x stats.difficulty x swarm —
  ours: _spawn_mult() x difficulty_mult. dmgMult has
  NO difficulty factor (verified). Spawn credit rate =
  Me x (1+(stage-1).35) x stats.difficulty x
  stats.enemyAmount x diff.enemyAmount — ours: the
  spawner interval divides by (difficulty_mult x
  enemy_amount_mult); the 60-enemy perf cap is ours
  and unchanged.

### NOT built — named, with evidence (no stubs)
- meowth: openShop @1479437 — a full in-run SHOP
  (stock table Zx, reroll economy, showShop UI) whose
  stock is items; our Lab is between-runs and
  bundle-distinct, and there is no item inventory.
- ditto: gated on player.items.size > 0; copies an
  item. No item inventory.
- bill: PC() move fusion over MC @1230332 (move pairs
  at level >= 8 + the AC fusion table). No fusion
  system or data in our build.
- hypno: openForget @1481244 — forget a move or a
  vitamin; the payout/refund lives in the showForget
  UI flow (@2063354) over the item/move-level systems;
  our moves are fixed per species line (no relearn
  economy to refund into).
- fossil: a single 3-offer trade altar (Oy/Fy/Py
  @867700-868812; costs .15/.20/.25 of maxHp as tempMod
  maxHp x(1-cost)): helix pays out in item choices
  (blocked above), amber recruits species 142
  (Aerodactyl) — ModelRig.SPECIES has NO aerodactyl
  entry and rig.setup hard-indexes SPECIES[species]
  (a spawn would crash). A 2/3 altar with a dead third
  offer is a stub; the whole altar stays out, dome's
  offerBlessing(min 4, pool 1.5) noted for the record.
- magnet x2: pickups.magnetAll = 5 (5 s of global
  XP-gem attraction). Our build has no pickup-entity
  system at all — XP and gold credit instantly on kill
  (the only physical pickups are chests), and the Lab
  'magnet' stat is itself flagged consumer-less
  (profile.gd header, cycle 7). No referent to port to.
- dragon fury reaction: no charm source (above).
- the events system's sky supply drop (the branch
  directly above updateComet @~1356600: a timed event
  spawning magnet/repel/heal/bomb pickups from the
  sky): every outcome is a pickup entity — same
  blocker as magnet. Not part of this cycle's order;
  named here so the events class is fully accounted
  for (migration portal events likewise out: our zone
  chain uses fixed portals).

## Counters
rocks/berries now increment for real -> they LEAVE
profile.UNSUPPORTED_COUNTERS (cycle 13/14 precedent)
and join the _finish_run merge list; challenges,
curses, greed, eggs count into run_counts (bundle
meta.count / run-field parity; no roster rows gate on
them).

## Harness (new standing phases)
react (steam/wildfire/shatter/gas/mind exact-value:
multipliers vs pinned control hits, side-effect sets,
radii inclusion/exclusion, stack arithmetic, the
0.25 s per-key gate incl. re-fire), comet (spawn at
timer, 25-40u band + <18u retry, life burns only at
charge 0, charge-start saves it, burn-out pays nothing,
completion pays a tier-4 blessing), props (one phase
per kind family: berry heal, rock gold + VC, snorlax
both branches, greed/cursed mods, cage pay/deny + XP,
chest cost/choice/sell + chestsBought curve, free/
cursed chest grants + ambush, challenge completion ->
free chest, slots cost curve + prize walk, nest
carry/deny/hatch, porygon persistence + recompiled
mods). Mutations verified per family (zeroed steam
multiplier, dropped gas stack term, comet life ticking
while charged, chest cost without BC).

## Results (filled at build time)

**Reactions — VERIFIED.** Steam / wildfire / shatter / gas
built to the mined branch table (bundle order, first-match
returns), plus mind collapse as a bonus (all its systems
exist here); electrocute untouched from cycle 14. New
harness phase `react` 25/25 standalone and in-suite:
exact multipliers against same-target control hits
(steam x1.4, wildfire x1.3, shatter x2.6 with the frozen
x1.2 folded in, gas x(1.4+.1r) at r=3 == x1.7, mind x1.6),
consume/keep semantics, radius in/out pins for every
splash and chain, stack arithmetic (3 applications ->
3 stacks), the global 0.25 s per-key gate (blocked second
steam at x1 with burn kept, re-fire past the gate), and
the reactions counter reaching 6. Mutations verified:
zeroing the steam multiplier fails exactly the two steam
checks; dropping the gas stack term fails exactly the
gas boost check. Dragon fury stays OUT (no charm source
anywhere in this build — re-verified by grep).

**Comet altars — VERIFIED.** Phase `comet` 15/15:
timer starts at _E == 75 s (0.75 s read tolerance — the
timer ticks live through the boot frames), spawn in the
25–40u band, tier 4 / 60 s life, life ticks ONLY at zero
charge (frozen while charge > 0, resumes on drain),
burn-out marks used and pays nothing, a spent comet
blocks respawn (ref persists), full charge opens the
ZC[4] blessing (3 offers, min tier 1, 1 pick) and the
pick returns to play. Mutation verified: letting life
tick while charged fails exactly the frozen-life check.
Sky-fall/landing presentation and audio are not ported
(no audio system); the spawn toast and wave warning use
the bundle's strings (CN). player.anchorT while inside
the circle stays unported (cycle-14 precedent).

**Populate kinds — VERIFIED (14 kinds, 50 props/zone).**
Phase `props` 46/46: population == populate counts at
areaMul 1 (greed 1, challenge 2, cursed 1, porygon 1,
nest 1, snorlax 2, slots 2, freechest 3, cursedchest 2,
cage 2, berry 5, chest 14, rock 14); berry driven through
the REAL E chain (heal 50% x heal_mult, capped, counted);
rock payout range + counter; greed/cursed temp-mod
stacking (difficulty 1.2 -> 1.32 measured through the
player fields); snorlax blessing-XOR-gold on both
shrines; cage deny/charge 30 / XP = xpNext x .5 x xpGain
exact; BC(0) == 1, BC(1) == 1.22 + 35/30 exact; paid
chest cost curve live (incl. the luck discount reacting
to a luck vitamin granted by the first chest), pick
grants exactly one vitamin, sell-all pays the footer's
qC minimum; freechest floor-1 grant; cursed chest
difficulty x1.05 + 4+2xstage ghost ambush, first Elite;
challenge 8+3xstage ring with 1+floor(stage/2) Elites,
completion counted + free chest prop at +(2.5, 2.5);
nest egg need == 200 at stage 1, second touch denied
while carrying, hatch recruits an ally, team-cap hatch
falls back to a chest roll; porygon 3 offers persist
across opens, pick is one-shot and lands in
recompiled_mods with gain/loss exact against the By
table (area x1.3, critChance -.08 measured); slots cost
40 at 0 spins and 86 at 10 (x1.08 curve), deny without
consuming a spin, one spin resolves to exactly one of
the seven prize signatures. Mutation verified: dropping
BC from the chest cost fails exactly the post-purchase
cost check. OUT kinds stay out with their evidence in
the spec section above (meowth shop, ditto, bill, hypno,
fossil, magnet, sky supply-drop event, dragon fury) —
no stubs built.

**Suite.** Full suite on the resident profile: 206
checks (120 standing + 25 react + 15 comet + 46 props),
205 PASS; the single FAIL is the known resident-profile
revive trap ("lab revive purchasable" — the resident
profile already owns Lab revive). Revive on a fresh
profile: 8/8, and the resident profile was restored
byte-identical afterwards (sha256 e15aee84...).
check_starters 3/3; class-cache gate OK. One pre-existing
probabilistic check flaked once during this cycle's runs:
"league: GLOBAL pool spawns magikarp" samples 8 league
spawns and failed once on a fresh profile (passed
standalone and in both resident-profile suite runs) —
the check is sampling-bound, not a code regression.

**Harness environment finding (not game code).** In this
headless environment the viewport performs NO GUI picking
for synthetic events — proven with a bare top-level STOP
control receiving nothing from Input.parse_input_event
(touch or mouse) while Node._input callbacks fire
normally (the world's touch latch works). This silently
broke the slam-dive and revive-joystick checks, which
drive touch controls through parsed events. Following
cycle 13's UltGauge precedent, both checks now deliver
through the target control's gui_input signal
(_c9_gui_touch): handlers, accept_event, button/joystick
state and the world's polls are all the game's real code;
only the viewport picking hop is bypassed. The game's
touch code is unchanged — on device, real touches take
the normal OS path. Two further fixture repairs ride
along: the revive hurt segment now repeats past evasion
dodges (a dodged hit sets 0.25 s iframes and no flash,
by design — a single-shot attempt is a coin flip), and
the attack phase baselines its cast-counter from the
live cd_t (a setup cast's damage is erased by the phase's
hp reset but its cd edge was being counted). The comet
burn-out check asserts no GROWTH of the blessing queue/
offers across the burn-out window (full-suite residue
from earlier phases made absolute emptiness wrong).

**近似 (named, unchanged from the spec).** Wildfire's
burnDps magnitudes (.3/.39 x statusDamage) ride on this
build's standing flat-DoT model (the cycle-13 ult phase
pins a burn-DoT kill inside a second; a packet-scaled
DoT would take ~10 s) — the reaction's spread set,
radius, multiplier, gate and counters are exact. Slots
resolve instantly with banner/floater (the reel UI is
presentation). Comet sky-fall is a fade-in, no audio.
Placement stays distribution-equivalent (seeded RNG +
_flat_open), not the terrain-reserve sampler.

**APK:** 53,571,058 B, sha256 f08aa2eb... (full:
f08aa2eb539bb92cf61fcaa363a4df25ae407f2282f495b9498e66fdaf04a61f),
same signing cert (b05b80e1...a232), package
com.spritebonk.game v1.0.0 (code 1). Linux-export boot
smoke: exported binary boots to the full 3D world +
starter menu under Xvfb, 0 script errors (screenshot
Test/out/linux_export_c15_menu.png, log
Test/out/c15_linux_smoke.log).

# Cycle 16 — the audio layer (synthesized SFX + BGM) and the
# daily shop verdict: IT EXISTS (meta layer, stardust -> bag)

## Item 1 — audio: spec mined from the bundle (byte offsets
## in main-CkI7dQhz unless noted; all tail-verified with
## tail -c +<offset+1>)

The original's audio is a single procedural WebAudio engine,
`N = new class{...}` @74465-93932 — almost everything is
SYNTHESIZED in code (oscillator tones + filtered noise);
the only audio FILES are species cries (`cries/<id>.ogg`,
fetched lazily by cry() @90240) and music tracks
(`music/<name>.ogg`). We ship neither file set: our SFX are
rendered from the same recipes, our cries are synthesized
per species, our BGM loops are synthesized — placeholders
in the same spirit as the dev art, swappable at reskin.

**Graph.** build() (in class @74465): master gain ->
DynamicsCompressor (threshold -14, ratio 4, attack .003,
release .2) -> destination. Buses: sfxBus -> master;
musicBus -> master; cryBus -> highshelf(-7 @2800) ->
lowpass(6000, Q .5) -> master; kitBus -> highshelf(-6
@2600) -> lowpass(5200, Q .5) -> sfxBus (the kitBus carries
the per-move kits). applyVolumes() @78627: master =
vol.master, sfxBus = vol.sfx x .55, musicBus = vol.music
x .32, cryBus = vol.cries x .45. Volume defaults @75068:
{master:.8, music:.5, sfx:.7, cries:.6}.

**Voice discipline.** maxVoices 26 on coarse pointers /
56 otherwise (@75068 region). ok(key, secs) @78837: a
per-key minimum interval gates most one-shots (hit .035,
pop .03, xp .035, coin .05, boom .06, hurt .1, slam .15,
charge .22, deny is ungated but ctx-checked...). move()
@80078: per-move density attenuation — repeats inside the
gap (cast gap default .045) scale volume by 1/sqrt(count)
with pitch jitter .95-1.05 (kv/kp).

**Primitives.** tone(freq, dur, wave, vol, slideRatio,
delay, bus, attack=.004) @78963: exponential attack/decay
envelope. noise(dur, vol, freq, filter, freqSlide, delay,
bus): 1 s white-noise buffer through a biquad. kt()/kn():
kit tone / kit noise onto kitBus (lp filter, optional
vibrato) — the Tc move-kit table's atoms. Tc @73752
(Object.assign(Tc, Hs, Us, Ws, Gs, Ks)): EVERY move has
{cast, impact, ...} kit functions. Porting all ~200 kits
is out of scope for this cycle; our wiring uses the
engine's generic typed sounds (shot(type) etc.) at the
same event sites — named 近似 below.

**One-shot library (methods on N; recipes are exact
freq/dur/wave/vol tuples in the class).** hit(eff, crit?,
mega?) @82036: base square blip at 520 (eff > 1.01) /
220 (eff < .99) / 360 (neutral) x rand .9-1.1, .07 s,
vol .12, slide .5 + noise hp 3000; crit adds a 1200
triangle ping; mega prepends a 1568/2093/110 jingle
(gated ok('mega', .09)). pop, xp(step) (pentatonic
ladder 784 x 2^(steps), steps [0,2,4,7,9], cap 15),
coin (1319 sq .06 + 1976 sq .18 delayed .06), heal
(523/659/784/1047 arp), charge(ratio) (330 x 2^(1.5r)
rising sine), overtake, power (392..1047 square arp),
boom(size), shot(type: fire/water/electric/grass/ice/
psychic/ghost/default), beam, cone, nova, slash,
melody(notes), whoosh, zap, hurt (220 sq .2 slide .4 +
noise), dodge, jump(mult), land, dive, slam(size),
alarm (3x 660/440 square alternation), bossStart (55
saw 1.4 s + noise + 220/207/196 descent), encounter
(659/784/988/1319), throwBall, ballOpen, ballClick,
ballShake, caught (7-note square arp), bonkDrop,
bonkGet, chest (784/988/1175/1568 triangle + hp noise),
slotTick/slotStop/slotLever/slotTease/slotCoins/
slotCurse, jackpot, deny (200 sq .15 + 150 sq .2 @+.12),
levelUp, evolve(dur) (rising pentatonic run + noise
sweep), evolveDone, shiny, classic, streak(n),
streakMilestone, click (900 sq .04 vol .05), hover,
victory (523x3 659 784 659 784 1047), bell, scope,
defeat (392/370/349/330/311 triangle descent), duck
(ratio, secs) (musicBus ramp down over .3 s, hold,
restore over .8 s).

**Call-site tally (this.audio.* / N.* across the
bundle).** click x181 (every UI button), deny x93
(failed buys/actions), kt x64 + kn x15 (move kits),
boom x62, shot x46, power x53, alarm x32 (alpha spawn
@860152 with cry; swarm/stampede events; legendary
warnings), whoosh x29, coin x26 (shop/lab buys, gold),
heal x13, cone x12, bossStart x10, move x9, duck x9
(ult fire .35 for dur+.6 @1397336; capture start .2 /
4.4 s; boss intro .25; evolution .2 / 4.8 s; shiny /
classic events .25 / 2.2 s), cry x14 total, victory
x10, levelUp x5, chest x4, caught x19 (capture success
paths), charge x1 — the altar charge loop
(altarUpdate @1268185 calls audio.charge(min(1,charge))
while the player stands in the radius), bell x1 —
ringBell() @1387268 (altar completion rings), streak
x1 (kill-streak counter), scope x1 (silph-scope item
reveal — item not activatable in our build; skipped),
bonkGet/bonkDrop (bonk pickups — no such entity in our
build; skipped), melody x5 (boss-kit flourishes; boss
kits not ported; skipped). NO weather/ambient SFX
exists in the library — weather is silent in the
original (the work order's "weather" candidate is
answered: none).

**Cries.** cry(id, vol=1, rate=1) @90240: fetch +
decode `cries/<id>.ogg`, loudness-normalized by jc()
@74098 (peak 50 ms-window RMS -> gain clamp(.18/rms,
.3, 1.6); Ac=.18 @74084 region), played on cryBus.
Missing files retry after 30 s. Ours: a deterministic
per-species synthesized chirp (two/three descending
formant-ish pulses; base freq hashed from the species
id), fixed normalized gain — the file set is the
original's recorded cries and must NOT ship (IP), so
this is a structural placeholder, named as such.

**Music.** TWO systems ship in the class; only one is
live. (a) File tracks: Ec @73814 = {menu: loop
70.177 s, halloween-menu: 56.343 (seasonal event track),
ingame1: 79.933, ingame2: 48.384, ingame3: 47.844,
ingame4: 65.428, boss: 8.959}; track gain kc = .75
@74084; playTrack() @91356: loop with loopStart =
Ec[name].loop... (loop point), .8 s fade-in, .6 s
fade-out on stop. Selection: menu plays Pz() @2134499
(active seasonal event's music if any, else `menu`);
a run picks this.music = Oc[floor(rand x 4)] once at
run start @1440396 (Oc = [ingame1..4] @73814 region)
and the game re-asserts playTrack(musicFor()) twice a
second; musicFor() @1440442 returns `boss` while a
boss kit is alive or the mewtwo event is active, else
the run's ingame track. (b) The generative sequencer
playSong(root, scale, bpm, mood) @90925 — moods
bright/mystic/tense/calm with degree progressions
[0,5,3,4]/[0,5,6,4]/[0,6,5,4]/[0,3,5,4], a 16th-note
scheduler @92745 (kick/snare/hat/bass/lead/pad driven
by this.intensity) — appears EXACTLY ONCE in the whole
bundle (its own definition; verified by byte count):
it is never called in the shipped build, and the
intensity writes (boss fight 1, boss killed .3, death
0) therefore have no audible effect. Our BGM mirrors
the LIVE system: synthesized loops standing in for the
files — one menu loop, four ingame loops picked at
random per run, a boss loop that overrides while the
guardian lives (the game state equivalent of their
boss-kit-alive test), crossfaded .8/.6 like playTrack.
Loop lengths are ours (menu 32 s, ingame 32 s, boss
9.6 s — the boss's 8.959 s scale is theirs; the rest
are file properties, not design constants): 近似.

**Settings surface.** Profile defaults uA @1566804:
settings {master:.8, music:.5, sfx:.7, cries:.6,
muteHidden:true, silentPlay:false, ...}. The settings
UI's sound tab @1963535: four sliders 0-1 step .05
(master / music / sfx / cries), a muteHidden toggle
("mute in background"), and a silentPlay toggle shown
ONLY on iOS (navigator.audioSession) — not applicable
to Godot/Android; we store the four volumes +
muteHidden and skip silentPlay (named). applySettings()
@2146366 pushes setVolumes + setHiddenMute((hidden ||
!focused) && muteHidden) on every settings change.
Ours: Profile.SETTING_DEFAULTS gains master/music/
sfx/cries/muteHidden with the same defaults; the menu
gains a sound panel with four HSliders (0-1, step .05)
and a mute-on-background toggle; changes apply live
through the same bus factors (.55/.32/.45); focus loss
with muteHidden on ramps the master bus to 0 (their
.15 s ramp) and restores on focus.

## Item 2 — daily shop: VERDICT = IT EXISTS. Build it.

Not the in-run Meowth shop (run-scoped gold shop:
openShop @1479679 region, stock Zx(this), rerollCost
.5 x Qx[0] x WC x 1.5^rerolls; HUD pill "Meowth de
visita" @2002585) — cycle 15 ruled that system OUT and
this verdict does not disturb that. The META daily
shop is a separate, profile-persisted system:

- **Catalog** (news chunk $e @83481): six bag items,
  FIXED (no stock rotation — the catalog is constant;
  what rotates daily is only the purchase quota):
  rare-candy {price 150, daily 4}, lucky-egg {250, 4},
  amulet-coin {250, 4}, honey {450, 3}, shiny-stone
  {900, 2}, master-ball {1800, 1}. Currency: stardust.
  Display tier per item (shop UI wL @1907178):
  {rare-candy:1, lucky-egg:1, amulet-coin:1, honey:2,
  shiny-stone:3, master-ball:4}.
- **Price escalation within the day** (news nt @83738,
  et = .5): price(boughtToday) = round(base x
  (1 + .5 x boughtToday)). The UI shows the next price
  ("Luego:") while >1 remain.
- **Day model** (news: _ = 86400000; Ve @82215 =
  floor((t - x)/_) + 1; He(day) = x + day x _; anchor
  x = Date.UTC(2026, 9, 12) @85403): day boundaries are
  UTC midnights; the shop screen counts down to the
  next one ("se renuevan a las 00:00 UTC").
- **Buy** (main wA @1571186, counts via CA @1571123):
  def missing -> error; boughtToday >= def.daily ->
  "sold out today"; bag[id] >= 9 -> "bag full";
  stardust < price -> error; else stardust -= price,
  bag[id] += 1, profile.shop = {day: today, n: counts}
  persisted. Profile sanitization (fA @1569144 region)
  DELETES profile.shop unless it is an object with a
  finite day and an object n. The shop screen (wL
  @1907178, "Tienda de Polvo Estelar" @1907560) is
  opened from a menu "Tienda" button: per item it
  shows name/desc (item table ur, news chunk — e.g.
  rare-candy @54951: "+2 levels instantly & +5%
  damage"; lucky-egg "+15% XP"; amulet-coin "+20%
  gold"; honey "+1.5 pickup range"; shiny-stone "+15%
  damage & +15% area"; master-ball "+25% damage,
  guarantees capture in wild encounters"), bag count
  n/9, today's count l/daily, price, and the states
  sold-out / bag-full / can't-afford. Buy success plays
  N.power() + a floating -price chip; failure plays
  N.deny() + shake (handler s in wL). A 350 ms debounce
  guards the buy button.
- **Scope note (honest):** the original also USES bag
  items inside runs (bring-in slots; the Lab 'bag'
  upgrade raises 2 -> 3 — our Lab row exists since
  cycle 7 with fx:false). This cycle builds the meta
  layer to spec (catalog/prices/caps/persistence/UI);
  the in-run bring-in flow and the six items' in-run
  effects remain unbuilt — named gap, same status as
  the Lab bag row's missing consumer.
- The profile's daily/weekly fields are the QUEST
  system (ze tables, news chunk; rewards Be @82162) —
  a different §3 system, not this shop; noted, not
  built here.

## Cycle 16 — completion (2026-10-26)

### Audio layer — VERIFIED (harness `audio` phase, 36/36)

- `scripts/audio.gd` (`GameAudio`): runtime-created buses
  Music/SFX/Cries/Kit mirroring the bundle graph (Kit -> SFX,
  others -> Master; Master compressor threshold -14 / ratio 4 /
  attack .003 / release .2). The two highshelf stages are NOT
  reproduced (no AudioEffectEQ band maps cleanly) — named
  approximation; lowpass 6000 on Cries / 5200 on Kit are.
- Volume law VERIFIED numerically: bus linears measure exactly
  setting x .55 (SFX) / x .32 (Music) / x .45 (Cries) at the
  bundle defaults .8/.5/.7/.6. Settings apply live; music = 0
  silences the Music bus; hidden-mute ramps Master to 0 on
  focus-out with muteHidden on and restores on focus-in.
- Voice pool = 26 round-robin players (the bundle's coarse cap);
  `ok()` throttles carry the bundle's per-key intervals — the
  throttle check is mutation-verified (interval .035 -> 0 makes
  5 same-frame hits admit 5 plays instead of 1).
- One-shots: ~45 synthesized buffers rendered lazily at 22050 Hz
  from the mined recipes (hit variants by effectiveness with the
  shared ok('hit', .035) strike gate, crit ping, mega jingle,
  pop, xp ladder, coin, boom, typed shots, beam/cone/nova, slash,
  whoosh, zap, hurt/dodge/jump/land/dive/slam(o), alarm,
  bossStart, encounter, the full capture set, chest, the slots
  set, jackpot, bell, levelUp, power, heal, victory/defeat,
  evolveDone, charge(ratio) pitch law, streak(n) pitch law) —
  all wired at the real event sites (enemy take_damage funnel,
  combat_hit crit branch, _award_kill chain, guardian
  spawn/kill, alpha/league spawns, capture outcomes, draft
  open/pick/reroll/skip, ult fire duck .35 / deny / per-family
  cast sounds, slam, ally casts, chests, slots prizes, altar
  charge loop + bell, blessing picks, totem roar cry, berry,
  lab buys, menu/UI clicks, run-end stingers, evolution).
- Cries: deterministic per-species synthesized chirps on the
  Cries bus (the original's recordings are its IP — not shipped;
  placeholder, swapped at reskin like the dev art).
- BGM: the LIVE system is the file-track player (the generative
  sequencer is defined once and never called in the bundle —
  byte-count verified). Ours mirrors the live system: menu
  track at boot, one ingame1-4 draw per run, boss track while
  the guardian lives, .8 s/.6 s crossfades, duck() ramps
  (.3 s down / .8 s up). Loops are synthesized from the
  sequencer's design (schedule() patterns/progressions); the
  boss loop is the bundle's 8.97 s; menu/ingame loop LENGTHS
  are ours — 近似.
- NOT wired, with evidence: per-move Tc kits (the kit table is
  assembled @73752 but porting all move kits is out of scope —
  generic typed sounds play at the same sites); capture duck
  (our capture resolves instantly, no cinematic window); DoT
  ticks (they bypass take_damage — silent, pre-existing
  structure); the timed `evolve` arpeggio (our morph is
  instant — evolveDone plays); scope/bonkGet/bonkDrop/melody/
  overtake/classic (their game systems don't exist here);
  player direct-hit crits via _roll_damage don't expose the
  roll, so the mega jingle fires on the combat_hit crit path.
- NO weather/ambient SFX exists in the bundle (the work
  order's candidate is answered: none) — weather stays silent.

### Daily shop — EXISTS, implemented to spec (harness `shop`, 18/18)

- `Profile` shop API + menu panel （星尘商店） + sound settings
  panel （声音设置： the bundle's four sliders + muteHidden;
  silentPlay is iOS-only in the bundle — not applicable here).
- VERIFIED: the 6-item fixed catalog (price/daily exact), the
  UTC day model (anchor day 1, +1 d = day 2, -1 s = day 0),
  reset countdown (85400 s at anchor+1000), price escalation
  round(base x (1 + .5 x boughtToday)) — ladder 150/225/300/375
  (mutation-verified: step .5 -> 0 fails the ladder check at
  p=150), the soldout/bagfull/poor/unknown error ladder in the
  bundle's order, bag cap 9 across advancing days, persistence
  to profile.json ({day, n} + bag), fA sanitization on cold
  load (malformed shop state erased), six panel buy buttons,
  buying through the real button (bag +1, power() plays), the
  master slider writing both the setting and the Master bus.
- Still unbuilt (named gap, unchanged): the in-run bring-in
  flow and the six items' in-run effects; the Lab 'bag' row's
  consumer. The floating -price chip and button shake from
  the bundle's buy feedback are presentation — ours plays
  power()/deny() and refreshes the panel.

### Suite / gates

- Standing suite in suite context: all phases green except
  the known resident-profile revive trap (fresh-profile
  revive 8/8 this cycle). Phase-by-phase standalone this
  cycle: attack 5/5, slam 7/7, ult 32/32, bossscale 12/12,
  wet 18/18, comet 15/15, props 46/46, audio 36/36, shop
  18/18; shrine observed 22 PASS / 0 FAIL (its SUMMARY was
  cut by a local 900 s cap; clean in-suite); react 23/25
  standalone — the 0.25 s gate pair is frame-delta sensitive:
  standalone's cold terrain-prebuild cache inflates the
  rig-fit wait past 0.25 game-s so the gate is legitimately
  open (clean in-suite; not a cycle-16 path).
- check_starters 3/3; class-cache gate OK; resident profile
  restored byte-exact (sha256 e15aee84...).
- APK: 53,608,067 B, sha256
  2bb2aae349d9861f7c2c3c22c7d6003239e3e92de787526e1db1cf546c6644ad,
  signing cert unchanged (b05b80e1...a232). Linux-export
  boot smoke: 0 script errors.

# Cycle 17 — UI alignment round 1 (work order 2026-10-26)

User (Seeker): "UI 界面比较粗糙，先对齐" — UI alignment became
the top priority. Spec = UI_SPEC.md (mined cycle 16/17: tokens
with bundle byte offsets; its §4 caveat stands — the original's
main CSS was never captured, so per-class padding/radius values
below are judged against the verified tokens, NOT claimed as
original numbers). Round 1 scope: theme foundation, main menu,
HUD core, draft + blessing cards, copy leaks, one ledger
correction. Round 2 (results/pause/settings/loadout/big-map/
mini-bars/touch-ult/hudScale) is a separate work order.

## Theme foundation — VERIFIED

- scripts/ui_theme.gd (`UiTheme`): tokens from UI_SPEC §1.2 —
ink #1d1236 (glass alpha.82, toast-verified), ink-deep
#1a1030, ink-soft #2a2350, gold #ffd23a, muted #9aa0b4 /
#6a6488; rarity ramp anchored on the map legend (blue =
common, green = rare, purple = epic, gold = legendary) with
r1 优秀 as an interpolated teal (named approximation); the Yi
type-color table hex-for-hex; danger ramp WR + thresholds UR
+ tier names GR localized （平静/温和/危险/极危险/残暴/致命/
不可能） — all bundle-verified @1997817/@3184.
- Semantic button library (UI_SPEC §1.3): green #26b054 /
blue #2b74d6 / red #ce3e34 / ghost glass × big/normal/small,
hover/pressed/disabled (.45 family)/focus-gold states;
make_icon_button adds the spec's [icon 18–20px + text]
anatomy (width fitted from font metrics — full-rect rows do
not feed a Button's minimum size; the first cut collapsed
and overflowed, caught on the draft screenshot).
- Panel language: UiTheme.glass (radius 16, white hairline,
shadow, real content margins) replaces every per-site
_style() literal on the touched screens.
- Fonts (all OFL, reskin-safe, none of the original's files).
  LOADING BUG (found by the export smoke, fixed same cycle):
  fonts are loaded via ResourceLoader load(), never
  FontFile.load_dynamic_font — in exported builds the raw
  .ttf path is not a readable file (the resource lives in
  the PCK as .fontdata), so dynamic loading fails and the
  stack silently degrades; editor runs mask this because
  res:// is a real directory there. This also means the
  pre-17 Noto subset path had the same latent defect in
  exports (its load_dynamic_font call was replaced by the
  UiTheme chain this cycle).
Fredoka SemiBold (display Latin) + Nunito ExtraBold (body
Latin), subset to the game charset; CJK display = Smiley
Sans （得意黑） — M PLUS Rounded 1c was fetched and REJECTED
on measured coverage (212 of 642 charset CJK glyphs missing,
incl. 你/发/园/图/对/员； Smiley misses 0); CJK body/fallback
= Noto Sans SC pinned 800 (Heavy) + the standing subset.
Per-glyph fallback chains: display Fredoka → Smiley →
NotoSC-Black-sub → NotoSC-subset; body Nunito →
NotoSC-Heavy-sub → NotoSC-subset.
- Icons: scripts/ui_icon.gd — ~35 drawn vector glyphs (the
original's SVG system is a design reference only; shapes are
generic, not traced). One icon bug found + fixed: "speed"
chevrons self-intersected and failed triangulation
(canvas_item_add_polygon); now polylines.
- Floating/damage text: display face + #1a1030 stroke
(outline 12, alpha.95) + distance-scaled pixel size
(clamp dist*0.08 to 0.6–2.4, UI_SPEC §2.3 rule); the altar
world label takes the same stroke.

## Main menu — VERIFIED

- The centered default-gray panel (which overflowed 720p and
cut its lower buttons — before shot) is gone: the menu
floats over the live 3D scene; the run HUD is hidden while
state == "menu" (HUD children regrouped under one node —
menu/panels/touch are NOT in it; boss-card/cut-in visibility
logic untouched).
- Starter select = cards: baked portrait (see below), CN+EN
name, type chips, base stats line, ult line (evo line for
non-starters), 联盟解锁 tag for league unlocks — the unlock
list uses the same cards. Meta column = accent icon cards
(wallet/Lab/shop/sound/league/shake) with live subtitles.
- Portraits: Test/portraitshot.tscn bakes all 53 modelled
species in a transparent studio (own World3D) + PIL disc
mask. Framing = fitted height, AABB x-center clamped
(charmander's GLB origin is off-axis; full-AABB framing on
skinned bind-pose boxes proved unstable and was dropped).
Ekans has no ModelRig.SPECIES entry (parked) — no portrait,
glyph fallback path covers it.
- TextureRect pitfall (kept as Test/trecttest.tscn proof):
assign expand_mode BEFORE size, else KEEP_SIZE snaps the
rect back to the texture's native 224px and portraits draw
2x — exactly what the first menu screenshot showed.

## HUD core — VERIFIED (one named deviation)

- Top-left: UiMedallion (scripts/ui_medallion.gd) — medal disc
in the species color + white rim + real portrait + XP ring
arc (#7aff8a) replaces the single-glyph medallion and the
7px XP sliver; name/type/evo info panel in glass; HP track
keeps the cycle-10 lag math untouched.
- Top-center white card → one glass cluster: zone CN/EN, 4
zone pips, Zone chip, tier chip, weather chip (icon +
label, live from WEATHER_TABLE), display-font timer,
elapsed, and the 7-segment danger meter (segments + tier
name colored by the WR ramp). Danger INPUT is ours (nearby
threat sum: normal.6 / elite 1.5 / alpha 2.5 / guardian
3.0 within 13u) — the bundle's exact input formula is not
in the mined evidence: 近似， named.
- Wallet pill: spark + coin icons with stardust/gold values.
The original's next-ball price element has NO counterpart —
our balls are free (no cost path exists in _throw_ball):
deviation named, element omitted rather than faked.
- Boss card + kills pill + item/move slots: glass styleboxes;
cut-in panel gets a real glass stylebox (was bare Panel).

## Draft + blessing cards — VERIFIED (two named approximations)

- Draft cards 198x246: colored top zone (type color for new
moves, rarity color otherwise) with the move/vitamin icon,
rarity chip in rarity color (bracketed text gone),
title, description (upgrade = two lines like the original's
list), [n] kbd footer. Title is "Lv.{n} · 升级！" (their h1
"¡Nivel {lvl}!").
- buildMini row added under the cards: current moves as
type-color chips (+Lv), vitamins on #6a5aa8 (UI_SPEC §2.5).
- Tools row is now buttons: 重抽 blue + count, 跳过 ghost +
count, 放逐 red — disabled at zero (was a text label).
Banish is the original's MODE toggle (was per-card 12px
buttons): while armed, cards re-rim red and warm-shift;
picking a card banishes it and disarms. Approximation
named: the original outlines targets 4px #ff4a4a and
hue-rotates the deck (hue-rotate(-30deg) saturate(1.4));
ours is a 2px rim + modulate tint.
- Blessing cards 190x216: rarity rim, top zone washed in the
rarity color, 52px stat icon, rarity chip, label, [n]
footer. Title drops the "✦ " prefix.
- Number keys: 1–9 pick in draft/blessing/choice; R rerolls.
Blessing keys arm 350ms after open (their anti-misclick
rule, UI_SPEC §2.6); click swallow (their 600ms modal rule)
is NOT implemented for pointer input — keys only: named.
- Choice modal options become lilac-rim cards.

## Copy leaks — VERIFIED

- Lab title "研究室 · Lab（§6.2 星尘永久升级）" → "研究室 ·
Lab（星尘永久升级）". Shop title "星尘商店 · Tienda" →
"星尘商店". Same-class leak found while sweeping: unlock
panel "联盟挑战 · 终身挑战（§3）" → "联盟挑战 · 终身挑战".

## Ledger correction — DONE (in the cycle-10 section)

Cycle 10's "no mini bars" fix bullet is corrected in place
with a marked cycle-17 note: the original HAS up to 2
.bossbar.mini bars (constructor @2020582; UI_SPEC re-verified);
the bullet only ever meant our build lacked a miniboss
system, and that premise expired in cycle 14 (roar totem /
alphas). Building mini bars = UI round 2, not this round.

## Verification

- Screenshots (Test/uishot.tscn, tag ui17before/ui17after),
eyeballed by the author: menu, lab, shop, hud, draft,
blessing, result — before/after pairs in Test/out/.
Blessing capture note: at 6 physics frames the software
renderer lags the modal's first frame and the capture races
it; uishot now waits 40 frames (panel rect/visibility were
verified correct by instrumentation — not a game bug).
- Standing suite (Test/out/c17_c9_suite.log): 260 checks,
  257 pass, 0 script errors. The 3 fails are both known
  non-regressions: (1) revive in-suite on the resident
  profile — the standing trap; fresh-profile revive run
  8/8 PASS. (2)+(3) the react 0.25 s gate pair — the
  frame-delta-sensitive pair cycle 16 already documented
  (23/25 standalone there, "clean in-suite" on an unloaded
  box); this run's box carried load ~9 from other tenants,
  and the standalone re-run reproduced the identical pair
  with identical dealt values (62.0420830188679). No combat
  code was touched this cycle.
- check_starters 3/3 PASS; class-cache gate OK.
- APK: 57,483,124 B, sha256
  8505b8a7d4e87e7d2fed9d4fd619971f1403a69044b7cef9bd7dcd6013392670,
  signing cert unchanged (b05b80e1...a232). Linux-export
  boot smoke: alive at timeout, 0 script errors — and it
  caught the font-loading bug above (first smoke: 6x
  "Can't open file" for every font incl. the old Noto
  subset; after the load() fix: 0). The APK was rebuilt
  after the fix.
- Resident profile restored byte-exact after the suite
  (sha256 e15aee84...; vault Test/profile_vault/profile_precycle17.json).

# Cycle 18 — UI alignment round 2 + bring-in (work order 2026-10-26)

Scope: finish UI_SPEC.md on the cycle-17 foundation (results,
pause, settings, HUD remainder, minimap/big map, adaptation
layer, loadout) and close the cycle-16 gameplay gap — the
daily shop's six items and the Lab 'bag' row had no consumer.
Two mid-cycle inputs were folded in: the independent Claude
audit of cycle 17 (22-item punch list; the 7 items routed to
this cycle) and the store-checklist / store-audit items.

## 1. Daily-shop items have REAL effects now — cycle 16's descriptions were invented (VERIFIED)

Cycle 16 wrote plausible-sounding Chinese descriptions for
the six shop items. They were guesses. Bundle mining (news
chunk table `Ye` @~82731; consumers at the offsets below)
gives the real effects, and `Profile.SHOP_ITEMS` now carries
them:
- rare-candy: **start the run at +2 levels** (applyBoosts
  @1444306: `level += 2`, xpNext recomputed by the run's own
  curve, `pendingLevels += 2` → two draft picks).
- lucky-egg: **+25% XP for the whole run** (tempMod
  {stat:'xpGain', mul:1.25}).
- amulet-coin: **+50% gold for the whole run** (tempMod
  {stat:'gold', mul:1.5}).
- honey: **one extra Alpha per zone** (stage director
  schedule @852778 appends `{t:240, kind:'alpha'}` per stage).
- shiny-stone: **a shiny is guaranteed in zone 1** (shiny
  director @1049061: stage 1 only, `shinyAt = min(shinyAt,
  range(40,150))`).
- master-ball: **the run's first capture (Alpha or League)
  always succeeds** (throwBall @1057676 / `useMasterBall`
  @1444738 consumes the flag, forces n=1).

Bring-in flow (region-select screen, `rg-sec` "Mochila"
@1880600): bag items with count > 0 toggle-select into the
run; the hint reads "hasta {n} · se gastan al empezar" — up
to {n} items, SPENT when the run starts. The cap is
`Dn(lab) = 2 + (lab.bag ?? 0)` (news chunk `Xe`, right after
`Ye`). On start, backend.startRun (@1580295) deducts each
selected boost from profile.bag (key deleted at 0) and the
region screen toasts at 1.2 s ("Mochila: {items}"). Endless
mode restricts the selectable set (`mA` subset) — we have
no endless mode: n/a, named. Our Lab 'bag' row （背包带入
2→3, max 1, 4000 stardust) IS this cap; its `fx` flag was
false since cycle 7 and is now true.

Implementation: `Profile.bag_consume(id)` (deduct, delete at
0, save) + `Profile.bag_slots()` (= 2 + lab bag level). The
loadout's bag row toggles selections up to the cap; at
`start_game`, `_apply_boosts` consumes each selected item
through `bag_consume` and only then applies its effect:
candy bumps level + pending drafts; egg/coin push temp_mods
and recalc (the same temp_mods channel altars use, cleared
per run); master-ball sets a flag consumed by the FIRST
throw at a league/downed target (after the team-cap early
return, so a wasted throw at a full team doesn't burn it);
honey arms a per-zone timer (re-armed on zone advance) that
calls `_spawn_alpha()` at 240 s; shiny-stone rolls
`_shiny_at ∈ [40,150]` and `_spawn_shiny()` fires it in
zone 1. The 1.2 s toast lists the brought items' names.

`_spawn_shiny` is new: it prefers a modelled roster species
not yet in the shiny dex, spawns it on the league chassis
(so it is capturable and flees on the same 150 s clock),
flags `Enemy.shiny`, and marks the capture in a new profile
list (`Profile.record_shiny`/`has_shiny`, sanitized on
load). **Named approximations:** the shiny carries a gold
OmniLight3D lamp + the minimap's cyan ring + a banner — the
bundle's shiny MATERIAL variants are not ported, and its
per-shiny-count progression ladder (Be(shinyCount)) is NOT
built. The archive system (`itemsOff`/`archiveItem`
@1571635/@1578563, capacity `fe(lab)`) is a SEPARATE system
from the bring-in bag and remains unbuilt.

Harness: new phase **boost (29 checks)** drives the real
path — shop buys stock the bag, the loadout cap refuses a
third toggle, egg+coin are spent at start (refused candy is
not), XP/gold multipliers measured as exact ratios against
a no-boost baseline run (×1.25 / ×1.5), candy yields level
3 with both drafts settled through the real draft flow,
honey arms at exactly 240.0 s, the shiny window rolls
inside [40,150], a downed alpha is master-ball captured
(mode → ALLY, flag consumed), the honey event fires, and
the forced shiny spawns on the league chassis and records
into the profile on capture. Mutation check: lucky-egg's
mul set to 1.0 in `_apply_boosts` failed exactly the
egg-ratio check; reverted, phase green.

## 2. Results screen — sectioned summary (VERIFIED, with named omissions)

`_build_result` is rebuilt as the bundle's sectioned summary
(UI_SPEC §2.8): stardust payout chip with icon, a 4-up fact
grid （守护者 / 收服 / 元素反应 / 进化）, per-move damage bars
(top 8, descending), pact chips from the run's blessing
picks (deduped ×n), a capture grid with portraits + names +
per-species ally damage, completed-task rows (the run's
challenge-diff against a start-of-run snapshot), and a dex
panel (seen/captured/league totals + run deltas + shinies).
Sections with no data are omitted, never faked. Two bundle
sections are omitted BY DESIGN and named here: the BONK
payout chip (this build has no in-run BONK — $SPRT settles
by season only, tokenomics v1.0) and the rivals/season block
(an online system this build does not have). The primary
button is relabeled 返回菜单 — it reloads into the menu;
the old 再来一局 label lied.

Run attribution was plumbed for real: `run_move_dmg` from
combat_hit's move/ally opts, the player's strike/beam/slam/
projectile paths, and ult casts (slot 8 lands in "ult");
`run_ally_dmg` per species key; `run_captures` appended in
both capture branches; `run_blessings` from the blessing
offer handler; `run_evos` per evolution. The ui2 phase
verifies the screen fed by real play (real tackle damage
attributed; real lethal loop → results with the stardust
chip + bars == min(moves, 8)). Screenshot-verified with
seeded presentation data through the real `_fill_result`.

## 3. Pause screen (VERIFIED; two named adaptations)

New: glass pause panel — header （暂停 + zone/time), a
segmented tab control （招式 / 图例 / 设置）, a moves page
(learned moves with icons, Lv, type chip, power/category +
the ult line), a legend page (marker ring colors from gR
@2093942 + rarity chips), big green 继续 + ghost 回主菜单.
Esc/P opens it from playing/guardian/portal (and closes the
big map first when open); a touch pause button feeds the
same path. It freezes through the existing channels (state
= "pause", running = false — enemies and the player both
gate on world.running; ui2 asserts the world clock AND the
player position are bit-frozen across 40 frames). **Named
adaptations:** the bundle embeds settings inline in its
pause; ours swaps to the settings panel and returns to
pause on close. The fusion-guide tab has no counterpart in
our systems — the legend page takes its slot.

## 4. Settings — six sections (VERIFIED; keys page read-only, named)

The cycle-13 sound panel is replaced in place (same
`_sound_panel` surface the menu and harness use) by a tabbed
settings screen: 声音 / 图形 / 控制 / 键位 / 界面 / 账户，
built from a new settings component family in UiTheme:
`style_slider` (ink track, accent fill, generated knob),
`make_switch` / `set_switch` (pill + sliding knob),
`make_segmented` / `set_segmented`, and `retint_button`.
Sliders carry a `setting_key` meta, so values round-trip
through Profile. Implemented consumers: the four audio
sliders (existing), mute-when-hidden, screen-shake switch +
strength, FPS cap segmented （关/30/60/90/120 →
Engine.max_fps), autoUlt / ultPose (existing), camAssist
(drives the touch aim state and the camera follow),
fixedStick (pins the joystick origin), touchScale →
`TouchControls.apply_scale`, camDist/camSpeed/invertY
(consumed by the camera drag; camDist synced into the world
rig), hudScale/hudOpacity/bossOpacity/minimapScale (§7),
and the account tab (wallet status from the world wallet
instance, wallet panel button, armed two-step 重置存档 →
Profile.reset_all, and the §10 legal rows). **Named:** the
键位 page is READ-ONLY — it lists the fixed bindings as
kbd chips and says so on the page; this build has no
rebinding system. (The audit's [C18 in-flight] note on
retint_button is fixed: retint now reapplies the disabled
state too.)

## 5. HUD remainder (VERIFIED; two named adaptations)

- **Party portrait row** at (106,121): a portrait disc +
  mini HP track per league ally, rebuilt on signature
  change (ui2 captures a real alpha and asserts the row
  populates).
- **pw-row power chips** at (106,206): live multipliers
  （伤害/暴击/攻速/范围/经验/金币） from the player's own
  fields; egg/coin boosts tint their chips gold. (Placed
  at y 206, not the planned 171: the centered stage
  banner's line overprinted the chips at 171 — seen in
  the first ui18 captures, moved, re-shot clean.)
- **Goal card** (top-right, under the kills pill): portrait
  + "{name} · 还差 {n}" + progress bar + next-target line.
  **Named adaptation:** the bundle's kgoal (@2001988) is a
  season-leaderboard RIVAL tracker fed by an online ticket
  system this build does not have; the card's anatomy is
  fed by our next incomplete League challenge instead
  (verified live in ui2 against the profile's own order).
- **Event-pill stack** (top-right column): comet (life /
  charge sub-lines), league (escape countdown), shiny,
  swarm, alpha — each with its --c color. The shop pill is
  omitted: there is no in-run shop (cycle 15 verdict).
- **Boss card**: portrait (set when the boss key changes),
  phase ticks at 66.6%/33.3% of the bar (@2003755), and a
  foot line (types · status · 湿润 · 咆哮 ×N).
- **Mini boss bars × 2** — the cycle-10 ledger correction
  closed: two 300-wide mini bars under the boss card,
  latched to the run's first two live alphas (flag == 2),
  with the main bar's lag math (0.45 s / 0.6). **Named
  source choice:** the bundle's minis track secondary boss
  entities generically; ours latch alphas, our secondary-
  boss source (verified live in ui2 with a real alpha, and
  visible in the hud2 capture).

## 6. Minimap + big map (VERIFIED)

The minimap is clickable (bundle @2001850) and framed in
glass; it also draws the shiny encounter's ring and the
player's pins. The big-map modal (bundle FR @1982885):
side = min(vh×.82, vw×.9) at the 1280×720 surface = 590,
drawing the zone's baked terrain under a fog overlay (a
48×48 visited grid over ±170 u, marked from the player
every 0.25 s), altar/portal/chest/guardian/player markers
in the gR ring colors, ≤ 3 player pins (click near a pin
removes it, gold #ffd23a), and a side list （已探索 %,
祭坛， 宝箱， 标记 counts + guardian/shiny lines). It pauses
the world like the bundle's modal (our choice from the
dash-pause channel, named). Fog is big-map only — the
minimap keeps the full terrain texture. (The ui18 bigmap
capture is 1.7 s into a run: 1% explored, so the map is
mostly fog by design; markers show through per the spec's
altar/portal exception.)

## 7. Adaptation layer (VERIFIED; scaler formula corrected by the cycle-18 audit)

An inner `_ui_root` sits under the HUD root at the display
safe-area insets; `TouchControls` gets the same insets.
`_kr()` = clamp(min(vw/1280, vh/720), 1, 2) — the 1280×720-
equivalent conversion UI_SPEC §3 blesses — drives every HUD
node anchored at a screen point (pivot set to the anchor
corner: scale-only, offsets never scaled, no double-apply),
the modal panels, and carries the user's hudScale.
**Cycle-18 audit correction (its top finding):** the work
order specced the bundle's raw kR formula
(clamp(min(vw/1920, vh/1080),1,2)×1.1 @1980939) — ported
literally it evaluates to 1.0 on every landscape phone,
because the bundle's formula multiplies CSS px whose
surface is only ~393 px tall while ours is 720 logical px;
the shipped UI was physically ~0.49× the original on a 6.5"
phone (11 px text ≈ 1 mm). `_kr()` now multiplies by
`_phone_factor()`: touch devices convert through the CSS
surface (css_h = physical height / (dpi/160); factor =
clamp((720/css_h)×1.1, 1, 2) — ≈ 2.0 on the audit's
reference phone), non-touch surfaces stay exactly 1.0, and
a per-node fit clamp shrinks oversized scaled modals to
96% of the screen instead of overflowing. **Safe-area
units fixed (audit §9.2):** get_display_safe_area() is
physical px; insets now convert per axis by logical/screen
before use — right/bottom notches were previously never
avoided. hudOpacity drives the HUD root's modulate;
bossOpacity the boss card + mini bars; minimapScale the
minimap + its frame; fpsCap Engine.max_fps.

**Touch cluster (audit + UI_SPEC §2.4):** the ult gauge
moved INTO the action cluster (bundle position); the HUD
ult circle hides while touch is visible. Interact/jump/
dash are icon-only (exclaim/up/wind), and lock/aim/pause
are 56 px icon buttons stacked above the gauge (crit /
target / pause glyphs; new UiIcon glyphs "exclaim" and
"pin" added). Lock sets player.lock_target (the targeting
scan prefers it inside its normal range — it biases, never
blocks); aim toggles camAssist (camera yaw follows the
lock/behind-motion); pause opens the pause screen. The
floating joystick's travel is unchanged; `fixed_stick`
pins its origin (presses beyond 100×scale px from home are
ignored). The cluster's public inputs are PROPERTIES
(move_vector / jump_held / dash_held), not methods.

## 8. Loadout screen (VERIFIED; two named substitutions)

The menu→run bridge (bundle region-select anatomy): a
centered glass panel with the hero detail on the left
(portrait, CN/EN name, type chips, 图鉴 rank chip, six
base-stat bars, the passive rendered mechanically, the kit
moves, computed weak/resist/immune matchups over the type
chart, the evolution chain — which stops at unmodelled
forms with a （未建模） note — and the family's ult list),
a 6-slot team bar (hero slot + league bench; locked
species show their unlock progress from the challenge
parts), a tile grid over the modelled roster (locked tiles
grayed), and the bag row with its cap label ("背包带入
（上限 {n})"). Menu starter cards and unlock cards now open
it; 开始 runs start_game with the selected boosts
(consumed there, §1). **Named substitutions:** team
reorder is tap-to-swap, not drag (touch-reliable, per the
work order); the detail shows the kit moves — the numeric
learnset table exists in data but is not consumed as a
table, named here. Locked tiles are view-only (ui2 asserts
the hero cannot change to a locked species; its detail
shows 解锁条件）.

Screenshot review caught three loadout defects, all fixed
and re-shot: (a) base stats read the wrong data key
("base" instead of "stats") and rendered all zeros — now
the real values (Charmander 39/52/43/60/50/65); (b) the
stat bars sized to ~1 px because the deferred sizing ran
before the ScrollContainer laid out — `_size_ls_fills` now
re-defers until the tracks have real width (bounded); (c)
the rank chip showed the raw EN slug ("common") — now
localized （图鉴 · 普通）.

**Passive display is a mechanical CN rendering, named:**
abilities.json carries the bundle's ES flavor name/desc
verbatim ("Mar Llamas", "Con menos del 40% de PS…"). The
detail originally surfaced that prose — an unlocalized
leak of the original's literal copy (audit §7's class, and
the reskin line says the original's prose is not ours to
ship). The detail now renders the passive's actual mods as
CN stat percentages plus a hook count (e.g. 特性：触发效
果 ×2 for Blaze; 生命 +10% · 弹速 +20% where mods exist).

## 9. Cycle-18 audit fold-ins (independent Claude audit of cycle 17, 2026-10-26)

Dispositions for the seven findings routed to this cycle:
1. **Phone scaler** — fixed, see §7 (the literal formula
   was the bug; physics preserved, formula corrected).
2. **Safe-area units** — fixed, see §7.
3. **Danger tier name overprints the weather chip** —
   fixed: the name moves under the timer, centered on
   ht-c (audit §3.1's suggested placement); the weather
   chip is legible again in the ui18 captures.
4. **Top cluster covers the info plate at 16:9** — fixed:
   `_layout_top_card()` shifts the cluster right until its
   left edge clears plate-right + 12 px (contents are
   card-local); re-applied on resize.
5. **Lab/Shop glass regression (α .82 menu bleed)** —
   fixed: Lab, Shop, Unlock and Settings panels go to
   α .95 glass (pre-17 they were .98; the bundle's .82 is
   only proven for the toast — modal alpha is in the CSS
   gap). Captures confirm readability is restored.
6. **Draft banish confirm + 600 ms guard** — fixed: banish
   is two-step (first press targets — hotter wash + the
   banish button reads 再点一次放逐 {name}; second press
   on the card, the button, or the same digit commits),
   and every draft action swallows input for 600 ms after
   the modal opens (150 ms when chained off the previous
   draft — the bundle's own two values). ui2 covers both
   (guard up on open, a pick inside the window swallowed,
   guard lifts, target-then-commit).
7. **Copy leaks** — fixed: draft move descriptions
   localize type + class （龙 · 特殊 · 威力 60), the tier
   chip reads 普通， the zone chip 区域 n/4, and ult names
   display CN + EN everywhere (menu cards, HUD label,
   banner, cut-in, pause, results) via Ult.display_name.
   The ult phase's label check was updated to match (it
   still asserts the REAL def name appears). The loadout
   review (§8) caught the same class twice more (rank
   slug, ES passive prose) — also fixed.
The audit's remaining punch items (chip contrast,
rarity/water color collision, banner backing/scrim, menu
stagger/badges/composition, card dead space, Tab button,
lab-row MAX state, shop button widths) are routed to
cycle 19 by the work order and are NOT claimed here.

## 10. Store-checklist / store-audit fold-ins (2026-10-26)

1. **Shop wiring is store-blocking — disposition: all six
   items PROVEN end-to-end this cycle** (§1 + the boost
   phase's real buy → bring → effect path, mutation-
   checked). No item needs its purchase surface hidden.
2. **Privacy / terms in-app — REQUIRED, not optional**
   (corrected by the independent store audit, which read
   the actual agreement): Developer Agreement §2.1
   requires an in-app link to the privacy policy AND the
   EULA/terms; the checklist's "no doc requires it" was
   wrong. The settings account tab gains 隐私政策 and
   用户协议 rows, each opening the live neutral-site page
   (https://spritebonk-site.musen-ai-9527.workers.dev/
   privacy and /terms) via OS.shell_open. (The terms
   page's own missing §10.6 clauses are the website's fix,
   out of this cycle's scope — the site was not touched.)
3. **Wallet silent RPC failure — fixed**: the balance read
   tracks an explicit state (idle/loading/ok/failed +
   reason) in wallet.gd; failures (transport, non-200,
   malformed/RPC-error responses, unsendable request) emit
   balance_failed, the panel shows 余额读取失败（reason) in
   a warning color with a 重试读取余额 button, and the menu
   wallet pill reads 余额读取失败 instead of hanging on
   "…". ui2 covers the visible state + retry show/hide
   through the real failure entry.

## Verification

- Phases were run per-phase on the final tree (the "all"
  run was interrupted by a VM reboot mid-flight; grouped
  re-runs supersede it). Tallies: league 5/5, attack 5/5,
  slam 7/7, ult 32/32, shrine 24/24, bossscale 12/12,
  wet 18/18, comet 15/15, props 46/46, audio 36/36,
  shop 18/18, boost 29/29, ui2 36/36, revive 8/8 (fresh
  profile), guardian 4/9, react 23/25 — 318 of 325 with
  zero script errors in every phase log.
- The 7 non-passing checks are the two DOCUMENTED harness
  pacing sensitivities, root-caused, not regressions:
  (a) guardian's kill-through-cap loop (5 checks): a
  level-up draft opens mid-loop (the player auto-kills the
  phase's burn dummy), `running` goes false, and the
  guardian's cap clock freezes BY DESIGN until a card is
  picked — the loop never services the draft. The cap
  system itself is verified exactly by bossscale 12/12,
  and the phase passed in the pre-reboot "all" run.
  (b) react's 0.25 s gate pair (2 checks): the check's
  "immediate" second hit follows a rig-fit wait that, at
  llvmpipe pacing, outlasts the gate window; steam itself
  fires/consumes correctly (23/25 incl. all multipliers),
  and wet's equivalent gate check (no fit wait) passes.
  Both pairs failed identically in cycles 16/17 under
  load; harness hardening (service drafts in the guardian
  loop; re-prime the gate in react) is a cycle-19 item —
  the checks were NOT weakened here.
- Mutation spot-check: §1 (egg mul). check_starters 3/3.
  Class-cache gate OK standalone and inside build_apk.sh.
- Screenshots: Test/out/ui_*_ui18after.png (12 screens)
  plus the post-fix ui18fix2 set; every screen visually
  inspected (see §5/§8 for the three defects found and
  fixed from the shots). "Before" = the ui17after set;
  loadout/pause/settings/bigmap are new screens (after
  only, by construction).
- APK: 57,548,809 B, sha256 8ebe4a89…, signing cert
  unchanged (b05b80e1…a232), package com.spritebonk.game.
- Linux-export boot smoke on the FRESH export (the build
  script does not regenerate the Linux preset — exported
  manually): alive at the 75 s timeout, 0 script errors;
  fonts/resources verified in the EXPORT (cycle-17 rule).
- Resident profile restored byte-exact after all runs
  (sha256 e15aee84…; vault profile_precycle18.json).
- Not touched: ~/workspace/sprite-bonk-godot/, Cloudflare,
  store/, the neutral site.

## Cycle 19 — UI polish (audit tail) + harness hardening + shiny/archive parity

Scope: the Claude UI-audit items C17/C18 left open, the two
pacing-sensitive harness phases named in C18 §10, and the two
parity tails named in C18 (shiny material variants + the
Be(shinyCount) ladder; the archive system). All bundle offsets
below are 0-based into the original main chunk
(2,154,272 B) unless marked news/en.

### §1 The 22-item audit list — final disposition

Closed in C18 (see C18 §9/§10, not re-worked): #1 physical
display scaling, #2 dangerous-name/weather overlap, #3 top
cluster over the info board, #4 banish two-step confirm,
#5 600 ms input guard, #7 Lab/shop panel opacity (α.95),
#16 English copy sweep, #22 safe-area units.

Closed this cycle:
- #6 draft-card remainder — kind chip top-left (新/强化,
  ink α.92 + gold text; "new" = a new move or an unowned
  vitamin); rarity chip reads 招式 for a new-move card (rarity
  colour as the chip ground, text via the new contrast helper),
  otherwise ink ground + rarity-coloured text (also fixes
  #11); shine sweep band on rarity ≥ 2 cards (shared diagonal
  gradient texture, animated in _process, registered per
  render); title/desc/footer now a VBox flow (top 92, spacer,
  centred kbd row) instead of fixed anchors — no dead band.
  Draft panel grew ±208 → ±226, blessing ±170 → ±198.
- #8 modal scrim + banner suppression — one shared scrim
  (INK α.55, mouse-ignore) sits under every modal panel
  (draft/blessing/choice/pause/bigmap/result/lab/shop/sound/
  wallet/unlock/loadout); _any_modal_open() drives it, and
  while any modal is open the stage banner + its backing are
  alpha-suppressed per frame (the banner timer still burns).
- #9 banner backing — glass card (±446, y148–204, α.55)
  behind the stage banner; verified in the hud screenshot.
- #10 chip contrast — UiTheme.readable_fg(bg, want): a white
  request on a bg with luminance > 0.55 falls back to
  INK_SOFT; explicit non-white foregrounds are always
  honoured. chip() and the world _make_chip both route
  through it.
- #11 rarity chip vs same-hue card top — solved by #6's
  ink-ground/rarity-text treatment.
- #12 card dead white + top-wash alpha — blessing top wash
  raised α.30 → .85 (draft family already .85; the two card
  families now match); both card families rebuilt on the
  flowing VBox layout (see #6).
- #13 Tab treatment — "查看我的队伍 [Tab]" ghost row under
  both the draft tool row and the blessing options; the
  three draft tool buttons gained kbd caps (R/S/B, also now
  real keys in _handle_ui_key alongside Tab). Tab opens the
  team peek (pause panel, moves tab) from draft/blessing;
  closing the pause returns to the modal that opened it
  (_pause_peek_return), run still paused.
- #14 blessing icon — the original uses ONE generic blessing
  glyph (64 px, @2064760); the per-stat icons are replaced
  by a drawn "blessing" glyph (four-point star + ink core)
  at 64 px, white, on the wash. Closed as alignment.
- #15 HUD move slot — the bare "招式：…" text line is gone;
  the slot is now a 32 px type icon + a 10 px "Lv.n" tag,
  refreshed on starter apply and on HUD refresh; the locked
  slot shows a lock glyph instead of "—".
- #17 menu readability/icons — subtitle outlined (3 px),
  bottom hint sits on a glass backing panel (α.55) with a
  2 px outline; the bag icon redrawn as a tied pouch; the
  screen-shake row's icon changed wind → a drawn shake glyph.
- #18 menu motion/composition — entrance stagger: every menu
  item fades/slides in at i×0.05 s (0.22 s tween); mm-badges
  on menu entries (Lab = affordable Lab rows, shop = today's
  remaining stock summed, unlock = completed challenges),
  refreshed in _refresh_meta; first starter card grabs focus
  (gold focus ring); the empty right 38% now holds a hero
  panel (portrait, names, type chips, six stats, ult line)
  that follows starter-card hover/focus.
- #19 Lab MAX state — a maxed row shows a 已满 chip (ink
  α.92, gold text) in place of the buy button; the price
  column is blank + right-aligned at MAX. PARTIAL: the
  lab-card grid restyle named in the audit's §2.7 was NOT
  done (the work order named MAX display + price alignment;
  the grid is a layout rewrite with no behaviour change —
  recorded here as the one open remainder of the 22).
- #20 shop buttons — buy buttons fixed at 148×32 with a
  single-line label; the next-copy price moved out of the
  button into the muted meta line (下一份 ✦ N, or 今日最后一份
  on the last copy of the day).
- #21 RARITY[0] leaves water blue — common is now #547cd6
  (84,124,214), clear of water #3aa0ff and dragon #7a5aff.

### §2 Harness hardening (assertions untouched throughout)

- guardian kill-loop: the loop never serviced the level-up
  draft the guardian kill triggers, so the run sat in draft
  state while the phase waited on the cap clock. The loop
  now applies the real draft flow per frame when state ==
  "draft". Gold expectations in guardian and in the c19 Be
  check also moved from a whole-window delta (contaminated
  by the player's auto-fire killing wild spawns: measured
  103.2 vs 100, 141 vs 140) to a killing-blow window — gold
  sampled immediately before and after the lethal
  take_damage call, inside one synchronous stack. 9/9.
- react gate pair: rebuilt on ONE fitted target — re-prime
  burn, assert the immediate water hit is gated (×1, burn
  kept), wait 24 physics frames, assert the next hit lands
  ×1.4 and consumes. The second fitted spawn (whose rig-fit
  wait outlasted the 0.25 s gate) is gone; reactions == 6
  unchanged. 25/25.
- revive hermeticity (new root cause found this cycle): the
  resident vault profile itself carries lab.revive = 1 (the
  phase's own past purchases, never restored), and revive's
  max is 1 — so "lab revive purchasable" could never pass
  from the resident profile in an "all" run. The phase now
  snapshots Profile.data at entry, clears the revive key as
  a fixture, and restores the snapshot on exit AND on the
  early-return path (the boost/ui2/c19 snapshot pattern).
  The purchase and the in-run revive are still the real
  flows. 8/8 in-suite.
- c19 scrim/banner + ui2 five checks: _c9_frames counts
  PHYSICS frames; scrim visibility, banner alpha, queued
  input dispatch and mini-bar visibility are driven by
  _process (render frames), and under llvmpipe several
  physics frames can pass with no render. Proven by bisect
  combos (the failing set reproduced 2 of 3 runs after
  revive+attack+ult+shrine, never after any single phase) —
  a render-starvation family, not a logic bug. The eight
  checks (scrim follows modal, banner suppressed under a
  modal, banner returns in-run; Esc resumes, draft closes,
  mini boss bar, big map open, big map close) now
  condition-wait via _c9_wait (≤900 frames) on the SAME
  predicates. No assertion was weakened.
- c19 shop-button count: rows queue_free'd by an earlier
  in-suite shop refresh were still in the tree when counted
  (12 buttons for 6 items); the count now skips
  is_queued_for_deletion() nodes.
- uishot: _snap captured the viewport texture, which holds
  the last RENDERED frame; the shop snap once re-captured
  the Lab-items frame byte-identical. _snap now awaits two
  process frames + RenderingServer.frame_post_draw.

### §3 Shiny system (parity tail a) — BUILT, REWRITTEN by cycle 20

The original §3 text asserted the FIRST mining pass's
rules; the second pass (§7) overturned them, and cycle 20
rebuilt the system to the true rules. This section now
states the true build; the correction record is §7 and
the cycle-20 section at the end of this file.

Bundle rules (main chunk; second-pass classification):
Be(count) is a PERK LADDER over ladder array lt (data
@84375) on n UNIQUE shiny species — n=2 → +3 Luck in all
runs; n=4 → +4% XP; n=6 → Shiny Charm (all shiny
probabilities ×1.5; flee timer 120→150 s); n=10 → +3%
damage; n=15 → the shiny ally unlocks at Bond 2
(consumers labStats @1578843, hasShinyCharm @1579006,
shinyRate @1579031, shinyFlee @1579088, shinyBond
@1579133). There is NO gold factor: wB = ceil(5 · stage ·
goldMult) has no shiny consumer. Spawning is a
probability roll per stage (roll @1048868; constants
data @84289): P = (0.08 + min(0.08, luck/1000)) ×
shinyRate(); on success shinyAt = stage clock +
range(40,420) s (fire @1049322, at most one per stage),
else NO shiny that stage. The shiny stone (stage 1)
min()s the roll into [40,150] (@1049102) — against a
failed roll that is a stage-1 GUARANTEE (min(∞, x) is
finite). Pick (@1051777): the current horde pool
filtered to animated species, PREFERRING families not
yet shiny-caught, captureRate-weighted by Cx = 0.15
+ 0.85 · captureRate/255 (@1047818), fallback id 25;
spawn HP ×2.5 (@1052378). The visual
variant is a shader hue rotation zl(id) = 0.22 +
(id × 0.618034 mod 1) × 0.56 (@125961) with twinkle
sparkles and a pink capture beam; the 1.25× sprite
scale (@1335362) stands. A capture grants +120 Stardust
(new shiny species) / +50 (repeat) (@1058894-area) and
records profile.shinies[speciesId]; the encounter is
spawned with unlock flag false — no league join. Throw
odds are the league formula (0.55 + captureRate/255 ×
0.35 + attempts × 0.20, +0.15 statused, cap 0.97);
weak window 10 s, 6 s after a break-out, expiry
recovers to 40% HP and roams (@1055252/@1057676/
@1058188-area).

Built (cycle 20): the Profile ladder API (shiny_luck_
bonus / shiny_xp_bonus / has_shiny_charm / shiny_rate /
shiny_flee_time / shiny_damage_bonus / shiny_bond_
unlocked — the unlock is RECORDED by record_shiny when
the dex crosses 15) wired into player.recalc (the
labStats consumer) and the director; the probability
director in world.gd (rolled after the player's setup
at run start — the roll reads the player's luck — and
at every zone advance; a failed roll leaves shinyAt =
INF); _pick_shiny_species (horde pool ∩ modelled,
family preference, captureRate weights, id-25
fallback); spawn HP = pipeline × 2.5; the flee clock
from the ladder (120/150 s). Guardian coins pay plain
20 · wB — the factor is REMOVED (it never existed).
Visuals: ModelRig.apply_shiny rotates each albedo
texture by zl with the bundle's hueShift operator
(Rodrigues rotation about the equal-weight gray axis,
main @114320; cached per species — the rigs carry
their colour in textures; the tint bases are the gray
calibration colour, so a tint-only rotation would be a
visual no-op) and rotates any saturated tint base with
the same operator; twinkle sparkles ride the weather particle idiom;
a pink capture beam fires at the catch point; no
emission is added. Verified end-to-end in the rewritten
c19 phase (41 c20 checks; see the cycle-20 section):
ladder rungs at the API and through recalc, the three
roll configurations tallied over 600 production rolls
each, pick fallback/preference/weights, the stone
guarantee, HP ratio 2.500 measured, scale 1.25, texture
mean-hue delta ≈ zl, a seeded-throw break-out (6 s
window) and the chance≥1 sure capture, +120/+50
grants, no league join (mutation-validated), weak-
window expiry → 40% HP, escape-clock flee, and
guardian coins at plain wB with a FULL shiny dex.

### §4 Archive system (parity tail b) — REAL, BUILT

First-pass verdict was OUT (itemsOff read as a boolean
gate, archiveItem as a GM grant, the only UI path a
dev-panel behind a compile-time flag). A second mining
pass OVERTURNED it with byte evidence; the first reading
was wrong and is corrected here:
- itemsOff is the archive's own key list: default profile
  itemsOwned:[], itemsOff:[] (@1567786), rebuilt by the
  sanitiser when missing (@1569476).
- TA(profile, key, off, isItem) (@1571588): off=true pushes,
  off=false removes; gates = already-in-state, capacity
  itemsOff.length ≥ fe(lab), paid unlocks (Wt) not owned.
  No fee, no deletion.
- Meta archiveItem (@1578563) runs TA locally (catalogue
  guard Te.has) and persists via the action batch
  {k:'archive',key,off} or POST /items/archive (@2124918,
  URL @2124965), reply normalised by the same sanitiser.
- Capacity fe is imported from the data chunk (main @378);
  the data chunk defines Fe = e => 5·(e.archive ?? 0)
  (news @68516) — 5 per Archive Lab level, max 20, level 0
  = locked.
- Lab row "archive" (data chunk table, news @66352): name
  Archivo, icon everstone, "+5 huecos del Archivo: los
  objetos archivados no salen en las Poké Balls ni en la
  tienda.", max 4, Stardust [600, 1200, 2000, 3000].
- Reachable UI: menu Laboratory → SL panel (@1897612) Items
  mode: header "Archivo {n}/{total}" (@1901033; capacity 0
  shows the unlock hint), an Archivados filter pill, and an
  Archivar/Devolver button on owned/in-pool item cards
  (@1902037–1902048) whose handler calls meta.archiveItem
  and syncs the active preset (@1903754).
- Presets (≤3): the UP panel (@1765590, renders null when
  fe == 0) sits in Lab items AND on the pre-run screen
  (@1880686); VP apply (@1765401) recalls everything not in
  the preset, archives everything in it, returns the
  overflow count; presets are local-only, localStorage key
  pokebonk.archivePresets.<accountId|local> (@1764615),
  ≤3 entries {name, keys≤60}, plus an .active sibling;
  deleting a preset does not touch the archive itself.
- Consumers: itemInPool (data chunk, news @68516: owned-or-
  free AND not in itemsOff) feeds the chest/ball roll Gx
  (@1074187), and the shop stock Zx is built from Gx
  (~@1076939) — archiving really changes drops and the
  Meowth shop. Full English string set exists in the en
  chunk (@91504, @67289, @351939, tutorial @183491);
  changelogs v0.8.16 (presets) / v0.8.24 (mobile preset
  fix) (news @9463/@11789). i18n chunk: zero archive
  strings.
- Correction to the first pass: fe (archive capacity) and
  Dn (bag capacity) are DIFFERENT functions. Our
  bag_slots() = 2 + lab_level("bag") is Dn and was already
  correct (C16/C18); fe was the missing one.

Built: the Lab row already existed since C7 (label 档案位
+5/级, same prices/max) — its fx ledger flag flipped to
true. Profile API: archive_capacity() = 5·lab_level(
"archive"), archived_items(), is_archived(), item_in_
pool() (the Ie predicate — our vitamin catalogue has no
paid-unlock entries, so TA's ownership gate is vacuous,
noted in code), archive_item(key, off) with TA's gates
(unknown key / already-in-state / full → false), and
presets: archive_preset_save (≤3), archive_preset_delete
(clears active when its preset goes), archive_preset_
apply (the VP semantics; returns the overflow count, −1
on a bad index; sets active). Profile fields items_off,
archive_presets, archive_preset_active persist and reset
with the profile. Consumers wired: both chest rolls now
draw from _item_pool_keys() (the pool minus archived) —
the original's other consumer (shop stock Zx) maps to our
fixed Stardust catalogue + bag, which is not pool-rolled,
and the Porygon trade trades stat mods, not pool items;
neither is a pool consumer here. UI: a Lab 物品档案 tab
(header 档案 n/N, unlock hint at capacity 0, preset row
with apply/delete/save, per-item 已归档 chip + 归档/取回
buttons, full-capacity disables) and the pre-run loadout
preset row (hidden entirely at capacity 0, per UP).
Adaptation (recorded): with 11 catalogue keys against a
20 cap the pool CAN empty here (the original's catalogue
makes it unreachable); an empty pool pays +25 gold with a
notice instead of rolling. NOT ported (named): preset
renaming (ours auto-names 预设 N), the Archivados filter
pill (11 rows fit one screen), preset storage is in the
profile JSON rather than a separate localStorage key
(single-account local profile here).

### §5 Verification

- Suite on the final tree, zero FAIL lines in every run:
  the single-process "all" run (c19_all5.log, vault start)
  passed 281 checks / 0 fails from league through shop and
  into boost's shiny-window check, where the PROCESS died
  silently (no script errors; the box was simultaneously
  running another line's proof workload and two earlier
  attempts died at the same boost spot the same way — an
  environment kill of a ~90-minute llvmpipe process, not a
  check failure). The unfinished tail was then run in ONE
  process on the identical tree (c19_tail19b.log): boost
  complete + ui2 + c19 = 94/94, exit 0. Phase results on
  the final code: guardian 9/9, react 25/25, revive 8/8
  in-suite, ui2 36/36 (standalone and in-suite), c19 phase
  36 checks / 0 fails standalone (incl. the archive group:
  capacity gate, buy → 5, archive/recall round-trip, pool
  filtering, preset save/apply round-trip, Lab items
  header), boost 29/29 in the tail run.
- check_starters 3/3. Class-cache gate OK inside the
  build.
- Screenshots: Test/out/ui_*_ui19after.png (13 screens),
  visually inspected: menu (badges 22/18/7, hero panel,
  outlined subtitle, hint backing), lab (tabs, MAX chip),
  labitems (档案 2/10, preset row, archived rows), shop
  (148-wide buy buttons, 下一份 meta line), draft (kind/
  rarity chips, kbd caps, Tab row, scrim), blessing (64 px
  generic glyph, α.85 wash), hud (banner backing card,
  move-slot type icon + Lv tag, lock glyph).
- APK: 57,565,193 B, sha256
  a80d7f2799af51a283d1c1119fce5a514634eb5af8a2de6588bf659e1dfe036e,
  signing cert unchanged (b05b80e1…a232), package
  com.spritebonk.game; reference/ entries in the APK: 0.
- Linux-export boot smoke on the fresh export: alive at
  the 75 s timeout, 0 script errors.
- Resident profile restored byte-exact after all runs
  (sha256 e15aee84…; vault profile_precycle19.json).
- Not touched: ~/workspace/sprite-bonk-godot/, Cloudflare,
  store/, the neutral site.

### §6 Hotfix (same cycle, after the §5 build): device HUD overlap

Source: the user's Seeker capture of the CYCLE 18 build
(media d5d717fe…). Three defects: (1) the top card buried
the hero plate — the species name ghosted behind it and
the party dots collided with its chip row; (2) the goal
card hung off the right edge under the minimap, its title
and task line clipped; (3) the ult name printed across
the move card and the slot row crowded the joystick.

Root cause (verified in code, not assumed): the scaler
grows every registered node about its own anchor point,
but sibling POSITIONS stay in design px — so any cluster
assembled from sibling nodes (hero plate pieces, the
bottom-left slots/move/lock/ult row) tears apart at phone
factors, each piece growing into its neighbours from its
own corner. Single-node clusters grew past their
neighbours too: the center-anchored 640-wide top card is
1280 wide at factor 2 and the §3.2 shift rule used the
UNSCALED width. The goal card had a second, independent
mechanism: its content minimum width (progress track 160
+ glass content margins 2x14 = 188) exceeded its designed
176, and a PanelContainer whose minimum wins grows
RIGHTWARD from its left offset — straight off the right
edge (measured on the gate: visual right edge == viewport
width exactly). The harness never saw any of it because
_phone_factor() is 1.0 off-device, so every capture ran
at scale 1.

Fix (scripts/world.gd, scripts/touch_controls.gd):
- Cluster units: the top-left pieces (medallion, Lv
  badge, info plate, HP track, party row, power row) now
  live in ONE container (_hero_cluster at (12,10), design
  -relative children); the bottom-left pieces (4 slots,
  move slot, locked slot, ult circle, ult name label)
  live in ONE BL-anchored container (_bl_cluster). Each
  cluster scales as a unit; internal design geometry is
  preserved at every factor.
- _layout_hud() runs after every _apply_ui_scale (and on
  goal refresh / visibility settings): the top row is
  fitted as one 1282-wide design row [hero 466 | 12 |
  card 640 | 12 | minimap 176·minimapScale] — the whole
  top region (hero cluster, top card, minimap + frame,
  kills pill, goal card, pill box) shares a fit scale
  s_top = min(s, (vw−24)/1282) for vw > 1280 (s_top == s
  at the 1280 baseline: desktop geometry is byte-exact,
  gate-locked). The top card is positioned in the free
  span clearing the info plate (the §3.2 rule, scaled)
  and the minimap; the right column re-stacks by SCALED
  heights (constants reproduce the shipped 190/226/320
  tops at s_top == 1; the pill stack now starts below
  the goal card's TRUE bottom — its content height is
  ~100, not the 86 its offsets claimed, so C18's pills
  underlapped it by ~6 px as well). Under a PHONE factor
  only (a desktop hudScale > 1 still drives nodes
  directly, per the standing ui2 contract), the boss
  card and mini bars shift into the same free span and
  fit their scale to it.
- Goal card: width determinism — track 160 → 144 (so
  track + margins = 172 ≤ 176), header portrait 40 → 32,
  separation 8 → 6, name/next labels clip_text (never
  widen the panel), and the name label carries an
  explicit 108 px minimum: clip_text zeroes a label's
  minimum width, which had starved it to width 0 inside
  its HBox (an empty name line — found by the gate's
  zoom inspection, fixed and now asserted).
- Joystick (touch_controls.gd): JOY_HOME_UP 168 → 196.
  The stick scales with touchScale only while the BL
  cluster scales with the UI factor; at factor 2 the
  slot tops reach vh−124 and the idle ring's bottom
  (vh−106) sat on them. At 196 the ring bottom (vh−134)
  clears the slots at every factor (the stick is
  floating-origin; home is the idle visual only).

Gate (new, standing): Test/phonehud.gd + .tscn, runner
Test/check_phonehud.sh. Boots the real world in a
2400x1080 window (stretch-expand → logical 1600x720,
exactly the Seeker's surface), feeds _phone_factor()
the value its own formula yields for that panel
(2400x1080 @ ~420 dpi → css_h 411 → 1.925) via the
world's debug_phone_factor seam (production leaves it
−1; only the platform probe is stubbed, the scaler and
layout code under test are production), starts a real
run through the loadout, spawns a real alpha, and
asserts VISUAL rects (global transform incl. scale):
every named cluster inside the viewport, the goal card's
right margin, pairwise disjointness for hero plate ×
top card, top card × minimap, minimap × kills × goal,
ult name × move slot, mini bar × hero/minimap, boss ×
top card, the joystick ring vs the slot row, and the
goal name label's real width. --mode=desktop locks the
1280x720 baseline (top card left 350, kills top 190,
goal top 226, minimap margin 12, hero at (12,10) scale
1). Results on the final tree: phone 22/22, desktop
26/26, gate exit 0; captures Test/out/phone_hud.png,
phone_boss.png, desktop_hud.png, visually inspected
(name line "绿毛虫 · 还差 3" full and on-screen; the
user's three defects absent). ui2 phase 36/36 and the
c19 phase (0 FAIL lines) re-run green on the hotfix
tree; uishot desktop set re-shot (ui19after) and
unchanged visually. One harness interaction found and
resolved on the way: ui2's "hudScale drives HUD node
scale" (boss card) — the span cap is gated on the phone
factor precisely so the desktop hudScale contract
stands.

This build SUPERSEDES the §5 APK: 57,569,289 B, sha256
2d293f946fcc927a8146286a96a70dd102843360c63097bf549816ef0972bd05,
signing cert unchanged (b05b80e1…a232), package
com.spritebonk.game, reference/ entries 0, class-cache
gate OK, fresh Linux-export boot smoke alive at 75 s
with 0 script errors. Resident profile restored
byte-exact (sha256 e15aee84…).

### §7 Correction to §3 (appended after the §6 hotfix build): the shiny rules were mined twice, and the second pass overturns the first

§3 was built on the first bundle-mining pass. A second,
deeper pass (full occurrence classification of `Be(` —
exactly ONE call site in the main chunk, byte 1578981;
the identifier is an imported filter, main-chunk import
at 629 `Or as Be`, resolving to the data chunk's `ut`)
overturns three load-bearing claims of §3. The shipped
behaviour below is therefore NOT bundle parity; it is
recorded here as a named deviation, with the true rules,
for a future correction cycle. The c19 harness phase's
shiny checks assert the SHIPPED rules (they are
self-consistent, not bundle-true) and must be rewritten
with it. [RESOLVED: cycle 20 rebuilt the system to the
rules below and rewrote the checks; the audit-fix pass
20.1 then corrected the four residuals its audit found
(N16 weight formula, N10 additive rungs, the hueShift
operator, N15 league-busy gate). This section is kept
as the correction record.]

1. **Be is a perk ladder, not a gold factor.** There is
   no `1 + min(30, 3n)/100` and no gold consumer — the
   shipped wB coin multiplier does not exist in the
   original. Be(count) = the rungs of ladder `lt`
   (data chunk @84375) unlocked at n UNIQUE shiny
   species: n=2 → +3 Luck in all runs; n=4 → +4% XP;
   n=6 → Shiny Charm (see 2); n=10 → +3% damage; n=15
   → shiny ally joins at Bond 2 (+20% ally damage).
   Consumers (main chunk): labStats @1578843 (stat rungs
   summed into the permanent stat block), hasShinyCharm
   @1579006, shinyRate @1579031, shinyFlee @1579088,
   shinyBond @1579133; the dex milestone panel imports
   the same array separately (@579).
2. **Spawn scheduling is a probability roll, not a
   guaranteed per-stage spawn.** Per stage change:
   P = (0.08 + min(0.08, luck/1000)) × shinyRate()
   (constants data chunk @84289; roll main @1048868) —
   on success shinyAt = range(40,420) s, else Infinity;
   at most one scheduled shiny per stage (fire
   @1049322). shinyRate() = 1.5 with the charm, else 1;
   flee timer 120 s (150 s with charm), not the 150 s
   league clock §3 shipped. The shiny-stone clamp
   (stage 1, min(shinyAt, range(40,150)), main
   @1049102) is the one §3 rule that survives — note it
   makes the stone a GUARANTEE on stage 1, since
   min(∞, x) is finite. Channels §3 never built:
   eclipse event roll (20% + luck term, cap 90%, main
   @1041603), the 3% legendary roll (League legendary +
   bosses, main @1053012; shinyBoss converts a defeated
   shiny boss into a GUARANTEED capture, @1054807), and
   the parallel Classic system (2.5% + luck/3000,
   range(60,420), alternate sprite sheets, 200/0
   Stardust).
3. **Species pick, visuals, capture grants.** Pick =
   current horde pool filtered to animated species,
   PREFERRING families not yet shiny-caught, weighted
   by captureRate (floor 0.15), fallback id 25; spawn
   HP ×2.5 (main @1051777/@1052378). The visual variant
   is NOT an alternate sheet for normal shinies: it is
   a shader hue rotation by zl(id) = 0.22 + (id ×
   0.618034 mod 1) × 0.56 (main @125961), with twinkle
   sparkles and a pink capture beam — the shipped
   gold-wash material is a 3D approximation of the
   wrong mechanism; a per-species hue rotation is the
   faithful equivalent and is now exactly specified.
   Capture grants, unbuilt in §3: +120 Stardust (new
   species) / +50 (repeat) (main @1058894-area); a
   shiny ally for the run (single slot + swap modal,
   ×1.2 damage, ladder bond, trim-protected); a
   League-channel shiny also joins the League, a
   director-channel one unlocks the family line's
   shiny skin instead. Throw odds: p = 0.55 +
   captureRate/255 × 0.35 + attempts × 0.20 (+0.15
   status), capped 0.97; third failed attempt = flee;
   weak window 10 s, 6 s after a break-out, expiry =
   recover to 40% HP and roam (main @1055252/@1057676/
   @1058188-area).

The archive half of the tail is unaffected: the second
archive pass (the one §4 cites) CONFIRMS §4's build.

## Cycle 20 — SHINY TRUTH CORRECTION (the §7 fix, shipped)

§3 has been rewritten above to state the true build;
this section is the correction record. Everything §7
specified was implemented; the out-of-scope tail stays
staged (below).

Code changes:
- profile.gd: shiny_factor() DELETED. Ladder API on
  n = unique shiny species: shiny_luck_bonus() (+3 at
  n≥2), shiny_xp_mult() (×1.04 at n≥4), has_shiny_charm()
  (n≥6), shiny_rate() (1.5 with charm), shiny_flee_time()
  (150 with charm, else 120), shiny_damage_mult()
  (×1.03 at n≥10), shiny_bond_unlocked() (persisted
  flag, set by record_shiny when the dex crosses 15 —
  the ally itself and its swap modal are staged tail).
  shiny_families() gives the family set for the pick.
- player.gd recalc() (the labStats consumer): the
  ladder folds into the stat pipeline — luck += rung 2,
  xp_mult ×= rung 4, damage_mult ×= rung 10.
- world.gd: _roll_shiny_director() is the bundle's
  probability roll — P = (0.08 + min(0.08, luck/1000))
  × shiny_rate(); success → shinyAt = stage clock +
  range(40,420); failure → shinyAt = INF (no shiny
  that stage). The roll runs AFTER the player is set up
  at run start (it reads player.luck; the old schedule
  rolled in the reset block before the player existed)
  and at every zone advance. _pick_shiny_species():
  current horde pool ∩ modelled roster, families not
  yet shiny-caught preferred, captureRate-weighted
  (maxf(0.15, rate/255)), fallback species id 25.
  _spawn_shiny(): HP = _spawn_mult() × 2.5, scale 1.25,
  flee clock = Profile.shiny_flee_time(), pink lamp,
  twinkle sparkles (weather particle idiom). Capture:
  record_shiny + Stardust +120 (new species) / +50
  (repeat) + pink beam at the catch point; still the
  unlock=false path — no league join. Guardian coins
  pay plain 20 · wB (the §3 factor is gone). The stone
  clamp is unchanged code with corrected semantics:
  min(∞, x) makes the stage-1 stone a GUARANTEE under
  the probability director.
- model_rig.gd apply_shiny(): the gold wash is REMOVED
  (no emission, no warm re-base). The variant is the
  zl(id) hue rotation applied to the albedo TEXTURES
  (standard shader rotation matrix, luminance weights
  0.213/0.715/0.072, alpha untouched, cached per
  species+texture) plus the same rotation on any
  saturated tint base. Two facts forced this shape:
  the rigs carry their colour in textures (tint bases
  are the gray calibration colour, s≈0 — a tint-only
  rotation is a visual no-op), and Image.get_data()
  returns base+mip levels, so the rotated buffer must
  be built from a fresh base-level blit and given fresh
  mipmaps or set_data() rejects it silently. If a
  texture cannot CPU-decompress (ASTC caveat), its
  material degrades to the tint rotation only.
- enemy.gd: comment only — the encounter machinery
  (league MODE weaken 10 s, break-out 6 s, expiry →
  40% HP) already matched rule 7 and is shared.

Checks (the c19 phase's shiny half was rewritten as 41
"c20:" checks; they drive production flows):
- Ladder API at n = 0/1/2/4/6/10/15 and through a live
  recalc (Δluck +3, Δxp ×1.04, Δdamage ×1.03 measured
  against the same run's baselines).
- Director: 600 synchronous production rolls in each
  of three configurations — base P≈0.08 (44 hits),
  luck-capped P=0.16 (83), charm P=0.24 (164) — every
  success offset inside [40,420], every failure
  exactly INF.
- Pick: empty pool → id 25; rattata-owned → 12/12
  pidgey; captureRate weights 200 picks → 174 high
  (band [140,195]). The 0.15 weight floor is covered
  by construction (one-line maxf in the pick), not by
  a distribution assert: the modelled low-rate species
  are too scarce in zone pools to separate 0.15 from
  the raw rate statistically.
- Encounter: stone guarantee (at ∈ [40,150] against a
  failed roll), league chassis + latch, flee 119.9 s
  (120 base), weaken → weak_t == 10, HP ratio 2.500
  and scale 1.25000 against a comparison spawn,
  texture mean-hue delta 0.753 vs zl 0.718 (±0.05
  band), no emission added. Throws are seed-hunted
  against the world's own _rng (the roll draws exactly
  one): a ≥0.90 first draw fails for real (attempts 1,
  weak_t 6.0 after break-out); a ≥0.985 second draw
  succeeds ONLY via the chance≥1 clause (attempts 1 →
  1.10). Grants measured across the two throws (+120),
  then a full-dex repeat capture measures +50 with the
  count unchanged and the charm flee clock at exactly
  150. Weak-window expiry recovers to 0.400 × max HP;
  escape expiry flees through the real tick. Guardian
  killing-blow gold with a FULL shiny dex equals plain
  20 · wB (measured 100 == 100).
- Note on the third-failed-throw flee branch: it is
  mathematically UNREACHABLE for director shinies —
  every zone-pool species has captureRate ≥ 45, so the
  chance at attempts = 2 is ≥ 1.0117 (sure capture).
  That is a property of the bundle's own formula on
  these pools; the branch is the shared league branch
  in the same function and stays as built in C9.
- Harness trap found and fixed: the original no-league
  assertion (kept from C19) was VACUOUS on this
  profile — JSON loads numbers as floats, Array.has()
  is type-strict, and the resident league already
  holds family 16, so has(16) read false regardless.
  The check now compares normalised before/after state
  across all three of join_league's write channels
  (league array, captured dict, captures counter —
  the latter two are unguarded). Mutation-validated:
  a temporary join_league call in the shiny branch
  fails exactly this check (captures 1 → 2) and
  nothing else. Adjacent hazard noted, NOT fixed
  (out of scope): Profile.counter_value("birds") uses
  .has(int) on the same float-loaded array;
  in_league() itself is type-tolerant and correct.

Staged tail (bundle offsets, unbuilt): eclipse roll
(@1041603); 3% legendary roll (@1053012) with the
shinyBoss guaranteed-capture takeover (@1054807); the
parallel Classic shiny system (2.5% + luck/3000,
range(60,420), 200/0 Stardust); the shiny ally swap
modal (the Bond-2 unlock itself is recorded); the
shiny-SKIN unlock on a director-channel capture (C20
audit N1: the bundle's caught() computes a skin unlock
for the family member — "Aspecto variocolor de {name}
desbloqueado en la Liga" when that member is in the
League, "Desbloqueará el aspecto variocolor de {name}
cuando se una a tu Liga" otherwise; main @1058894
area, skinMember/inLeague). The port has no shiny
skin; documentation only, added by cycle 20.1.

Verification: c19 phase 59/59 (mutation run 58/59 with
the single expected FAIL), guardian 9/9, boost 29/29,
full suite --only=all 384/384, phonehud gate OK
(phone + desktop), starters gate PASS, Linux-export
boot smoke alive at 75 s with 0 script errors,
resident profile restored byte-exact (sha256
e15aee84…). APK: build/android/SpriteBonk.apk,
57,573,385 bytes, sha256 29e7381d1c70afa6b543ce6b48
bb568259b1e4967793f3af84d536a3040da7f5, signer cert
SHA-256 b05b80e1…a232 (unchanged), package
com.spritebonk.game v1.0.0 (1), reference/ entries
in the APK: 0.

## Cycle 20.1 — AUDIT-FIX (official Claude audit of C20: 6 VERIFIED / 3 OVERSTATED, issues N1–N18)

The audit's fixable findings are closed here, in its
priority order. Verification ran on the NUC station
(the decided cutover ritual: VM edits -> delta rsync
-> NUC suite/build -> artifacts pulled back); every
log is Test/out/c201_*.log.

Fixes:
- **N2 (progression blocker)** profile.gd
  counter_value("birds"): the type-strict .has(int)
  on the float-loaded league array never matched
  birds joined in prior sessions, so the legendary
  challenge goal birds>=3 (roster) was unreachable.
  Now the tolerant int(f) == b compare, mirroring
  in_league(). New check seeds the profile FILE with
  float league entries [144.0, 145.0, 146.0], forces
  a real disk load and asserts birds == 3 (mutation-
  sensitive: the shipped code reads 0).
- **N16 (pick weights)** world.gd _pick_shiny_
  species(): the shipped clamp maxf(0.15, cr/255) is
  replaced by the bundle's Cx = 0.15 + 0.85 *
  captureRate/255 (@1047818). The 255-vs-45 check is
  tightened to 600 picks, band [425, 490] (bundle
  mean 461.5; the clamp's 510 falls outside — NUC
  runs read hi=445 standalone, hi=466 in-suite). New
  low-cr floor check (audit N9): snorlax (cr 25,
  modelled) vs caterpie over 1000 picks, band
  [770, 845] — bundle 81.1% vs clamp 87.0%, >4 sigma
  apart (NUC read lo=834).
- **Hue operator (claim 5)** model_rig.gd: the CSS/
  SVG luminance-weighted matrix (0.213/0.715/0.072)
  cycle 20 shipped is replaced by the bundle's
  hueShift (main @114320) — a Rodrigues rotation
  about the equal-weight gray axis k = vec3(1/sqrt
  (3)) — shared by the texture path and the tint
  bases (the tint path's HSV hue-add, audit N5, is
  gone with it; one operator everywhere). New probe
  check pushes known colours (pure red/green, a
  mixed colour) through the production texture path
  and compares per-channel against the Rodrigues
  formula recomputed in the harness from the GLSL:
  the CSS matrix misses by >0.08 in a channel, far
  outside the 0.03 byte tolerance, so the old build
  fails this check where the mean-hue check could
  not tell the two apart.
- **N10 (ladder composition)** profile.gd /
  player.gd: the bundle's labStats ADDS the rungs
  (xpGain +0.04, damage +0.03); the port multiplied.
  shiny_xp_mult / shiny_damage_mult are now
  shiny_xp_bonus / shiny_damage_bonus (additive);
  recalc adds the XP bonus, and the damage bonus is
  summed inside the damage factor alongside the Lab
  dmg adds, exactly as labStats sums them. Recalc
  checks now assert the additive deltas (a x1.04 /
  x1.03 fold fails both).
- **N15 (league-busy gate)** world.gd director fire:
  the bundle's spawnShiny returns early while a
  league encounter is roaming / weakened / throwing
  (@1051777), after the fire consumed shinyAt — the
  stage's shiny is LOST. The director now skips the
  spawn while _league_e is live (the latch still
  consumes the stage). New c19-phase check stages
  the exact state _spawn_league() leaves behind,
  crosses shinyAt on the real tick, and asserts no
  shiny + latch set. Interaction found by the first
  NUC full suite (387/388): the C18 boost phase's
  shiny segment pushed elapsed past _league_spawn_
  at, whose auto-spawn occupied the encounter slot
  and ate the stone's shiny — behaviour the bundle's
  single encounter state machine also produces. The
  boost fixture now closes the league channel for
  that segment (the state the game reaches when no
  ready species remain), with the reason recorded
  inline; the check then passes against a real
  spawned encounter (boost 29/29).
- **Record hygiene**: the §7/§3 roll and fire
  offsets are corrected everywhere (code comments
  included) to the audit's verified values — roll
  @1048868, fire @1049322 (N17; both were off by
  exactly 1,000 B). §3's pick wording and ladder
  API names now state the true formula/functions.
  The §7 header carries a RESOLVED marker (N14).
  N1 (shiny-skin unlock on a director-channel
  capture, @1058894 area) is added to the staged
  tail above — documentation only, not built.
- **N12 correction to the cycle-20 record**: the
  C20 verification paragraph reported the signer
  cert without noting the split — Godot's export
  step fails its own signing ("Could not find
  keystore", c20_apk_build.log:92-95) BY DESIGN
  (the preset carries no keystore); android/
  build_apk.sh then zipaligns and signs the
  unsigned export with apksigner as a separate
  step (its "OK: signed release APK" line). The
  cert claim itself was and is correct.

Verification (NUC station unless noted):
- c19 phase (touched): 63/63 (59 + birds, pick
  floor, hue-operator and N15 checks).
- boost phase standalone (post fixture fix): 29/29.
- Full suite --only=all: run 1 = 387 checks / 1
  fail (the boost N15 interaction above); run 2,
  post-fix = 388/388, 0 fails (384 C20 + 4 new).
- phonehud gate: VM PASS (phone 22/22, desktop
  27/27, same tree). On the NUC the phone variant
  failed ONE assertion (joystick ring clears the
  slot row: ring_bottom=614 vs slots_top=600.65)
  while desktop passed — no HUD code changed in
  this cycle and neither profile carries settings
  that alter the layout; recorded as an open
  environment/pacing discrepancy of the NUC run,
  not waived.
- Boot smoke (NUC, fresh Linux export): log
  Test/out/c201_bootsmoke.log carries the explicit
  marker BOOTSMOKE ALIVE_AT_75S with 0 SCRIPT
  ERROR lines (the N13 evidence gap is closed by
  the marker, not by assertion).
- Profiles: a precycle vault was taken this time
  (Test/profile_vault/profile_precycle201.json,
  sha256 e15aee84…, = the VM resident). The NUC
  resident (sha256 5a5d52ef…) was stashed before
  the runs and restored byte-exact after each run
  block and at the end — hash-verified.
- APK (built on the NUC by android/build_apk.sh,
  pulled back and re-hashed on the VM):
  build/android/SpriteBonk.apk, 57,569,289 bytes
  (the C19 byte size recurs by coincidence; the
  hash differs), sha256 9fd0195e331c5e747cfbff74
  06c3d1dd4af8520156e69ab35f51a64328ae1d92,
  signer cert SHA-256 b05b80e1…a232 (unchanged),
  package com.spritebonk.game v1.0.0 (1),
  reference/ entries in the APK: 0.

## Cycle 20.2 — phonehud scale-sweep fix (re-audit HOLD)

The Claude re-audit of 20.1 (claude-audits/
spritebonk-c201-reaudit-2026-10-27) put a HOLD on the
open phonehud item: the C20.1 NUC failure (ring_bottom
614 vs slots_top 600.65) was dispositioned "environment/
pacing", its log had been overwritten by a VM run at the
same fixed path, and closed-form geometry predicted the
shipped ring crosses the slot row at low touchScale.
This pass reproduces, root-causes, fixes, and gates it.

Reproduction (NUC, per-host logs, touchScale PINNED by
the gate and dumped in-log as touchScale + _scale_s):
- The gate now takes --scale= (Test/phonehud.gd): it
  pins Profile touchScale before the world boots and
  prints "PHONEHUD scale dump touchScale=.. scale_s=..".
- C20.1's 614, explained and reproduced exactly: the
  NUC tree still carried a PRE-C19-hotfix
  scripts/touch_controls.gd (JOY_HOME_UP 168, not 196 —
  a stale file from the C19 snapshot sync; every other
  audited file was byte-identical). With 168 geometry
  the ring bottom is vp.y - 106*s = 614 at s=1.00, the
  resident profile's default (the NUC resident carries
  NO touchScale key — verified on disk; settings are
  {autoUlt, music, muteHidden}). Re-run with the stale
  file, scale pinned 1.00: ring_bottom=614,
  slots_top=600.65, FAIL (Test/out/
  c202_repro_stale168_ubantu.log) — the lost C20.1
  numbers to the digit. Not environment, not pacing:
  a stale file, plus a gate that controlled nothing.
- The audit's prediction about SHIPPED geometry is
  also confirmed. With the current file (196) synced
  to the NUC, the pre-fix sweep (logs c202_prefix_*):
  s=0.70 -> ring_bottom=626.2 FAIL (bound 602.65);
  s=1.00 -> 586 PASS; s=1.50 -> 519 PASS; desktop
  586 vs 658 PASS. Every measured bottom matches the
  closed form vp.y - 134*s to the decimal. The overlap
  was reachable from shipped code at touchScale
  0.70-0.85 the whole time; the old gate only ever
  exercised the default 1.0.

Fix (geometry, not a waiver):
- scripts/touch_controls.gd: TouchControls gains
  _ring_bottom_limit (viewport-space cap, INF default)
  and set_ring_bottom_limit(y); _joy_home() clamps the
  home so ring bottom <= limit. Active-press floating
  behaviour is untouched (user-driven); the clamp binds
  the IDLE home only — the gate's assertion target and
  the C19 device defect.
- scripts/world.gd _layout_hud() (runs after every
  _apply_ui_scale and on goal refresh): pushes the
  slot row's visual top — BL cluster global top +
  56 * cluster scale, the gate's own bound — into the
  touch layer. The row rides the HUD factor, the ring
  rides touchScale; they are now tied together at the
  layout pass for every (factor, touchScale) pair.
- At scale 1.0 the clamp never engages (586 < 600.65):
  the C19 reflow geometry is byte-for-byte the shipped
  behaviour at the default.

Gate (permanent):
- Test/check_phonehud.sh sweeps phone touchScale
  {0.70, 1.00, 1.50} + desktop, all assertions at every
  scale, and writes PER-HOST logs
  (phonehud_<mode>_<host>_s<tag>.log) — one station's
  evidence can no longer overwrite another's (audit
  follow-up b). Mutation sensitivity is demonstrated,
  not asserted: the same gate FAILS the pre-fix
  geometry at 0.70 (626.2) and passes the fixed
  geometry (below).

Gate bug found by this pass (fixed): phonehud.gd took
its profile snapshot from Profile.data BEFORE anything
called load_profile() — the lazy static is {} until
then — so _finish "restored" {} and WIPED the resident
profile. The first 20.2 sweep runs did this to the NUC
resident (left as "{}"). Restored byte-exact from the
C20.1 operator stash (~/c201_stash/
profile_resident_before.json, sha256 5a5d52ef… — the
value recorded in 20.1) and vaulted as Test/
profile_vault/profile_nuc_precycle202.json [C21
CORRECTION: that vault copy was taken on the NUC
station's tree only — the file did NOT exist in the
VM tree's Test/profile_vault/ when the C20.2
re-audit flagged the claim. Cycle 21 pulled it back
to the VM vault byte-exact (sha256 5a5d52ef23f…,
verified on both hosts 2026-10-27), so the sentence
is true of both trees from C21 on.]. phonehud
.gd now calls Profile.load_profile() before the
snapshot; post-fix, four gate runs left the resident
byte-exact 5a5d52ef (hash-verified).

N10 evidence gap (same re-audit, follow-up a): the
harness recalc block now seeds Lab dmg/xp to >= 2
before reading baselines (phase snapshot restores the
resident Lab after). The compositions now separate in
the LOG, not just in the code: C9 PASS xp rung ::
xp=1.14 base=1.1 (a x1.04 fold reads 1.144); dmg rung
:: dmg=1.11 base=1.08 want=1.11 (a x1.03 fold reads
1.1124) — both outside the 0.001 tolerances
(Test/out/c202_all_ubantu.log).

Process (follow-up c): the boot-smoke wrapper is now
a kept script, Test/check_bootsmoke.sh — exports the
Linux preset, boots the binary under Xvfb, requires
alive-at-WAIT (default 75 s) with 0 SCRIPT ERROR,
emits EXPORT_DONE / BOOTSMOKE ALIVE_AT_75S /
BOOTSMOKE END into the per-host log
(Test/out/bootsmoke_ubantu.log this pass).

Verification (NUC station; logs pulled back to VM):
- phonehud sweep post-fix, RC=0: phone 0.70 ->
  ring_bottom=600.65 (clamped to slots_top) PASS;
  1.00 -> 586 PASS; 1.50 -> 519 PASS; desktop ->
  586 vs 658 PASS (all 22/22 phone, 27/27 desktop
  assertions at every scale).
- Full suite --mode=cycle9 --only=all: C9 SUMMARY
  checks=388 fails=0 (c202_all_ubantu.log).
- Boot smoke via the kept script: BOOTSMOKE OK —
  EXPORT_DONE rc=0, BOOTSMOKE ALIVE_AT_75S, 0 script
  errors (bootsmoke_ubantu.log).
- APK (built on the NUC by android/build_apk.sh,
  pulled back and re-hashed on the VM):
  build/android/SpriteBonk.apk, 57,569,289 bytes
  (the byte size recurs a third time; the hash
  differs), sha256 506c4ea16c0b0429a314a23a3bc0e2c
  7f4145bf4486843452e2e051a8c9c3333, signer cert
  SHA-256 b05b80e1…a232 — this time verified with
  apksigner on the pulled-back file itself (closing
  the re-audit's cert-to-file binding note),
  reference/ entries in the APK: 0.
- NUC resident profile restored byte-exact after all
  runs (5a5d52ef…, c202_profile_restored.txt).

## Cycle 21 — the big alignment cycle (items inventory, 2026-10-27)

Scope source: Test/out/alignment_gap_inventory_c21.md.
Chores first: (a) the §20.2 vault claim — profile_nuc_
precycle202.json lived only on the NUC tree; it is now in
the VM vault byte-exact (sha256 5a5d52ef…) and the §20.2
sentence carries a [C21 CORRECTION] note. (b) Tree-hash
parity after every rsync is a kept script (Test/
sync_to_nuc.sh + check_tree_parity.sh; every sync this
cycle printed TREE PARITY OK). One real incident: a stale
.godot script cache on the NUC served an older harness
draft for one run — the cache is now purged before
verification runs, and the run scripts cd to the canonical
~/workspace/sprite-bonk-3d (a wrong-path runner and a
phantom harness helper, _wait_sim — used but never defined
— were the other two causes; _wait_sim is now defined).

### 1. In-run item inventory (player.items) — DONE
assets/data/items.json: all 126 item defs mined from the
bundle's catalogue (rarity/max/tags/mods; rarity dist
0:35/1:32/2:26/3:20/4:13; 88 with stat mods, 38 bespoke).
The other 25 catalogue entries (stones/protein class)
have NO rollable def in the bundle and stay archive-only
in name — the Lab archive domain switched from the old
vitamin keys to item-def keys (profile validation follows;
stale vitamin keys remain removable). player.items with
add/can_hold/remove, stack caps, once-per-stack mod fold
into recalc AFTER the compiled mods (bundle order at
@812155 differs slightly — accepted), charm typeBoost =
1 + 0.3/stack folded into the SAME type_boost channel as
passive typeBoost fractions. Chest rolls are real item
rolls: Bx tier roll (luck 10 base, availability mask,
below-floor x1e-4), Gx pick (pool = def && count<max;
floor >= 3 with no rarity >= floor available -> null;
tag weights 4 / 0.35 / 1), Kx fill, rollChestItem
(count 1 = take-or-sell modal; count > 1 = distinct rolls
+ pick-1 or sell-all at min qC; all-maxed pays gold qC(2);
rolls queue behind an open modal). Bespoke items wired:
secret-key (altar charge x(1+.3/stack), drain halved per
held key), ice-heal (frozen-break x(1.6+.3(stack-1)) +
2.5 u freeze splash via the shatter reaction), rare-candy
(level now + a second at +0.3 s through the world timer),
max-revive (player.revives; death consumes a charge at
60% HP before the Lab revive), max-ether/tm-case (vit/move
caps 10->12 / 8->10 as player-side getters), ss-ticket
(team cap +1 each), gold-teeth (slots + shop prices
x(1 - .08 x min(3,stacks))), dowsing-machine (populate: +1
altar, +2 PAID chests per stack — the freechest reading
was wrong, corrected from populate @1239654), eviolite
(armor x1.5 / maxHp x1.25 for species with an evo target),
big-nugget (ball price below). old-rod is record-only
(no fishing system). EN item names were not recoverable
from the bundle chunk — Spanish names ship as dev
placeholders with CN labels for the wired bespokes.
Stats with no system (thorns/statusDamage/flinch/
projectiles/pickupRange/jumpHeight/bounces/
superEffective) record into passive_extra as before.
Ditto populate is now UNBLOCKED by player.items (was
waiting on this item) but is NOT in C21 scope.

### 2. Meowth in-run shop — DONE
Bundle openShop @1477749 / Zx stock @1075742 / showShop
@2048601. A meowth prop joins populate (count 1, JC dex
52 — rides the REAL meowth GLB on a gold disc), never
consumed. Stock = 4 distinct via Gx at generation,
priced round(Qx[rarity] x WC x shopHeat x teeth) with
Qx = [80,130,220,400,750], WC = 2.2^(min(4,zone)-1);
shopHeat = product of [1.15,1.25,1.4,1.6,2][rarity] over
shop buys AFTER the first (2 + floor(chestsBought/3));
reroll = round(.5 x Qx[0] x WC x 1.5^rerolls x teeth),
rerolls reset per zone-shop; the panel also carries the
sell row (every held item at qC(rarity), two-tap arm) and
the heat help line. HUD pill while the live zone holds a
meowth ("喵喵在拜访", bundle evpill.shop).

### 3. Ball pricing — INVENTORY FRAMING CORRECTED
The inventory (and the user's 02:43 decision, taken on
that framing) assumed capture throws cost gold. Byte-level
mining of BOTH throwBall implementations (@1056309,
@521454) shows capture throws are FREE — no gold anywhere
in the capture path, and the [E] prompt carries no price.
The priced "ball" is the world Poke Ball = the PAID
CHEST: the HUD wallet (@2086120) prices the ball icon at
interactables.chestCost(), and the bundle's econ telemetry
literally records balls: chestsBought. chestCost
(@1236548) = round(18 x BC(chestsBought) x (1 - min(.25,
luck/400)) x (1 - min(.4, .08 x big-nugget stacks))). What
shipped: the big-nugget factor in _chest_cost, the price
in the HUD wallet pill (white affordable / red not), and
the chest prop label's "(sin dinero)" insufficient state.
No per-throw deduction exists to port; nothing was
invented to match the wrong framing.

### 4. Zone 2/4 names + guardian trios — DONE (de-INFER)
Bundle biome table: graveyard "Torre Lavanda" [94,110,97]
and volcano "Isla Volcan" [126,78,6]. Zone 2 = 紫苑塔 /
Lavender Tower, guardians [gengar, weezing, hypno];
zone 4 = 火山岛 / Volcano Island, guardians [magmar,
rapidash, charizard]. Adaptation (recorded): summon
filters the trio to modelled species (weezing/hypno/
rapidash have no GLB — rig.setup would crash) and pads
with trio[0]; the DATA stays bundle-true.

### 5. Guardian/boss phase kits — DONE (core + 2 full
mechs + 4 first-pass casts + 2 frames)
[C21.2 CORRECTION — audit N3: the header overstates
what runs in shipped play. The kingler/gyarados FULL
kits, the four first-pass casts (cloyster / starmie /
dewgong / lapras) and the hypno pendulum frame run
ONLY in the harness (forced _boss_mech): those seven
species have no GLB model and no guardian-trio slot,
and the mech is chosen from the guardian's species,
so the kits are unreachable in play. What actually
runs in play = the Nb brain + the cross/leap/charge
signatures + gengar's double team. Full restatement
and the reachability path are in the Cycle 21.2
section / C22 queue.]
The Nb boss class (@994812) is ported as a world-side
brain on the guardian: cycle timer (2.5 s first, x1.35
enraged, sigNext alternation between signature/mech and
generic moves), enrage at Ze.fury (tier row 0 = .5; our
chain has NO run-tier ladder — tele/escorts rows for
tiers 1-2 are recorded as a pre-existing gap, tier 0
used), escort calls every 22 s (16 enraged) with the
bundle's counts/caps/elite picks, the far-leap rule
(dist > 18 for 2.5 s pulls a signature leap), and the
charge/leap bodies driven by the world (the enemy AI
stands down under boss_hold). All eight generic moves
with bundle numbers (slams/ring/charge/volley/wave +
enraged spiral/meteor/pools) as world telegraphs, hostile
shots, expanding waves and DoT pools (pool damage is
FIXED via the new player.hurt_fixed — the bundle's
hurt(fixed) path; our pools bypass armor/evasion like
theirs). Signatures (Pb kinds): cross (scyther/sandslash/
marowak), leap (pinsir), charge (dragonite) over the
shared lineStrike/charge/shards impls; the lb per-species
hooks are pure VFX and were skipped. Mech classes (db):
kingler (guard facing 0.15/1.6 hitMul, counter, hammer
lanes) and gyarados (whirlpool vortices, hyper-beam sweep,
recharge x1.5 window) are FULL ports. First-pass casts on
the same primitives: cloyster (shell phases x0.1 closed /
x1.9 open + volleys + clamp strike), starmie (chained
rushes + dizzy x1.8 window; the reflecting path geometry
is approximated), dewgong (chained slides + ice-trail
pools; trail burst timing approximated), lapras (pillar
ring as timed obstacle pools + hydro-pump line strike +
surf wave; the pump's damage tail was not fully read).
Frames: gengar phase-1 double team (clones at 1.2% HP,
x0.35 dmg; phases 2-3 reuse it), hypno pendulum field
(cone tracked, drowsy payoff NOT ported). Marowak's db
class is a tower veil/candle system (run.tower-gated) —
in stage play it degrades to its Pb signature, which the
port carries. The mech hitMul consults in
enemy.take_damage (player-sourced hits only). Boss bar:
phase ticks now show ONLY for kit bosses (mech or
signature — the bundle's rule; cycle 18 drew them
unconditionally), the foot row carries the announced move
name during say() (the bundle's bossSub shares our foot
row), and the tag shows the rage state. Impatience: the
Db/Ob constants were NOT recovered — the port uses
s = clamp((no-hit time - 8)/10, 0, 1) as an APPROXIMATION
of the bundle's impatience curve.
TRUE SIZE NOTE: the nine db mech classes are each a
bespoke mini-boss-game; full-fidelity ports of the
remaining classes (starmie path geometry, dewgong trail
bursts, lapras pump tail, gengar phases 2-3, hypno sleep
payoff, marowak tower veil) are a dedicated follow-on
cycle, not tail work.

### 6. Shiny channels — DONE (eclipse + legendary)
Legendary roll (rollLegendShiny @1053012): 3% x
shinyRate, rolled at guardian spawn (shiny entrance +
banner) and on roaming league targets of the legendary
class (spawnTarget @1049996; our species data has no
rarity field — the class proxy is captureRate <= 45,
recorded). Shiny-boss takeover (takeOver @1054139): a
defeated SHINY guardian pays its kill rewards, then rises
weakened at 1% HP as a capture target whose throw is
guaranteed (capture.sure); the portal still opens —
leaving forfeits it. The captured takeover pays through
the existing shiny channel (stardust 120/50 + shiny dex).
Stage events (ax/sx @1035191): the scheduler (once per
kind per run, refuses during boss/cleared/active) with
fog (45 s) and storm (40 s) and eclipse (40 s) ported —
look swaps (fog color/depth/light from ax), pool spawns
(dex triples per stage, modelled filter; cadence ~4 s /
cap 8 is an approximation of the unread spawnT internals),
storm bolts (marked strikes, fixed 30% max HP), eclipse
eliteBonus +0.12 on the director elite roll, and the
eclipse shiny roll (once, after the opening 12 s:
min(.9, (.2 + min(.08, luck/1000)) x shinyRate) ->
spawnShiny from the eclipse pool). The golden-meowth
event is NOT ported (a fleeing coin meowth is its own
build) — the scheduler renormalizes over the three
ported kinds. Fog's minimap blinding (sx.blind) is not
ported.

### 7. Ekans geometry-space fit — DONE
The GLB's bind geometry lies along Z (the render probe
measures silhouette height — meaningless here). Geometry
probe (Test/geo_probe.gd): node-chain AABB at scale 1 =
length 4.9725 along Z, plan center (0.0957, -0.4367);
vertex-density bins put the head at +Z. The idle pose
stands the body upright (cobra), pivoting mid-body, so
feet (-3.046) is the POSE's lowest point, probe-measured.
New ModelRig span fit (scale by length, ground + center
from geometry). Verification: Test/analyze_probe.py ekans
= OK (rendered height ratio 1.063, ground offset +0.021).
Ekans joins SPECIES (dex 23 roster entry + challenge +
serpent-glare passive were already in the data; cycle 9's
"ekans modelled" line was not true of the tree — this
cycle makes it true). Arbok (dex 24, evo) has no GLB and
stays unmodelled.

### 8. Passive backlog I — DONE
The bundle's tick table N_ (@719919) and per-ability tick
functions (@791920-798760), damage F_ = (a + b x level) x
j_[stage-1], j_ = [1, 1.8, 3.2, 4], ticked per unit
(player + allies; level = the player's, matching our
ally scaling). tentacles (2 s; 2 nearest in 7 m, 4 for
tentacruel dex 73; F_ 6/1.5, poison .8), arena-trap (2 s;
r 4.5, 6 for dugtrio dex 51; F_ 4/1.2, root .8),
chlorophyll (6 s; r 4.5 pollen, F_ 3/.6, poison 1.0;
plus the sun half — +30% speed / +20% damage while the
weather is sun, applied dynamically), serpent-glare
(4 s; cone ahead — center 3.5 forward, r 4.5, dot > .45,
dist < 7 — paralysis), loyal-guard (3 s; r 5.5 charm) and
intimidate (3 s; r 5 charm): charm is a new enemy status
(outgoing damage x0.6 via Enemy.out_dmg, read by contact
hits and boss strikes; 3 s duration = the tick period —
the bundle's applyStatus '1' argument was not decoded
further), beacon (5 s; r 5, hit 4+level electric, paralyze
.7; plus paralyzed targets take +25% from the carrier in
combat_hit), static (4 s; nearest in 10 m, hit 10+2xlevel,
paralyze 1.0 — its contact half was already wired).
This closes the cycle-9 NOT-ported line for these eight;
the rest of that list (weather passives beyond chlorophyll's
sun, shieldMax, statusDamage, thorns...) stands.

Verification (NUC station; tree parity OK before every
run; .godot cache purged):
- c21 phase: 83/83, 0 fails, 0 script errors.
- props phase: 75/75. c19 phase: 45/45.
- FULL SUITE + PHONEHUD + BOOTSMOKE + APK: see the
  closing block below (executed by the coordinator's
  closing pass, 2026-10-27 — the cycle agent ended
  without a final report).

### Cycle 21 closing block (2026-10-27, closing pass)

NUC attempt first (station ritual honoured): delta sync
completed and TREE PARITY OK (74 files). The closing
block's suite step on the NUC then FAILED at load —
SUITE_RC=1 with NO C9 SUMMARY; the log tail shows the
harness script hitting a parse error at reload right
after the mandated .godot purge. Root cause: the purge
was followed immediately by the suite scene run with no
settling --import pass, so the class-cache rebuild raced
the scene load (the file is byte-identical to the VM's
and passes --check-only there; a later import-first run
on the NUC settled with IMPORT_RC=0). The NUC block's
later steps had not reported when the tsproxy route
degraded; per the no-stall rule the closing block was
executed in full on the VM and every result below is
host-stamped.

FULL SUITE (VM, host htch-runtime; Test/out/
c21_close_all_vm.log): 436 checks, 17 fails — NOT green.
The 17, verbatim:
  props: chest pick grants exactly one item and closes
    (C21) :: items=2
  props: challenge wave fully spawns (8 + 3 x stage
    == 11) :: wave=0
  props: challenge's first 1 + floor(stage/2) are
    Elite :: elites=0
  props: challenge completes when the wave dies
  props: 'challenges' counted
  props: completion spawns a free chest at +(2.5, 2.5)
    :: props=51
  props: egg hatches at dp kills into a recruited
    ally :: allies=0
  props: 'eggs' counted
  props: at team cap the hatch falls back to a chest
    roll :: allies=3 cap=3
  props: leaving the trade keeps it unused
  audio: menu track playing at boot :: track=ingame3
  c19: banner + backing show in play :: state=draft
    banner_t=-0.05
  c21: ss-ticket raises the team cap
  c21: triple roll shows three cards :: cards=1
  c21: shop close returns to play
  c21 boss: a zone-1 guardian is summoned
  c21 boss: the draw is a zone-1 trio species :: sp=null
Failure anatomy (discriminators on the same tree):
- props standalone (VM): 46 checks, 2 fails — ONLY the
  team-cap hatch fallback and the trade-unused checks
  reproduce; the other 8 in-suite props fails are
  full-order interactions (challenge wave never spawns
  in-suite, chest grant double-fires in-suite).
- c21 standalone (VM): 69 checks, 7 fails — ss-ticket
  cap (also in-suite) plus a standalone-only family:
  ekans spawns/fit, tentacles, arena-trap, serpent-
  glare, intimidate, static. The passive ticks read as
  renderer-pacing casualties on this 2-vCPU VM
  (status=freed targets, hp sentinel -1/-1); the 3
  in-suite-only c21 fails (triple-roll cards, shop
  close, boss summon/trio) do not reproduce standalone.
- ss-ticket team cap is the single check red in-suite
  AND standalone on the VM while green in the cycle's
  NUC phase run; it and the props cap fallback both sit
  on C21's new team-cap accounting. First re-verify
  target next cycle; suspect axis is resident-profile
  state (VM resident != NUC resident) or a real cap
  edge — UNRESOLVED, not waived.
- A c21 standalone discriminator was also launched on
  the NUC import-first (15:09 CST, IMPORT_RC=0 read
  back); its phase result could not be retrieved — the
  tsproxy route stayed down for the rest of the window.
  [CLOSING ADDENDUM, retrieved after the block above
  was written: the discriminator DID complete —
  C21_RC=1, 69 checks, 6 fails on the NUC standalone.
  So the c21 standalone is red on BOTH hosts (VM 7,
  NUC 6); the passive-tick family is not a VM-only
  pacing artifact, and the ss-ticket/cap cluster stays
  the prime suspect for a real C21 semantics edge.
  The 6 NUC fail names were not retrieved (route).
  Note the count gap: the cycle's own NUC c21 run
  recorded 83 checks vs 69 in both closing standalone
  invocations — the phase composition differs by
  invocation and is itself worth one look next cycle.
  The NUC closing block also completed after all:
  CLOSE_BLOCK_DONE 15:22 CST, APK_RC=0, NUC-built APK
  57,630,804 B sha256 4f2013ed298d9b7b10acdd37a0aeea
  17abb47df5ad49bbe8f94ea618c898a6ce (per-host byte
  variance vs the VM build, same parity-verified
  tree); its PHONEHUD_RC / BOOTSMOKE_RC lines were
  not individually retrieved.]
PHONEHUD (VM): RC=0 — phone 0.70 / 1.00 / 1.50 and
desktop all OK (per-host logs phonehud_*_htch-runtime_*).
BOOTSMOKE (VM): RC=0 — BOOTSMOKE ALIVE_AT_75S, 0 script
errors (Test/out/bootsmoke_htch-runtime.log).
APK (built on the VM; android/build_apk.sh):
57,638,996 B, sha256 6f874240448267899355a606980682a
69ea3f05505b378274d12056c439d9673; signing cert
SHA-256 b05b80e128a7ff997282b1b80c1973e347ced316b6eb
632670a6cbc64350a232 verified with apksigner ON THE
FILE; package com.spritebonk.game v1.0.0 (1);
reference/ entries: 0.
Cycle verdict: all 8 scope items + both chores are
built and phase-green on the station of record (NUC);
the closing full suite on the VM is red by the 17
above — the cycle is NOT stamped suite-green. The
shipped APK is the C21 build; play-critical gates
(phonehud, bootsmoke, cert, reference-exclusion) are
green on the VM.

## Cycle 21.1 — closing adjudications (2026-10-27)

The C21 closing record above declined to stamp the
cycle suite-green. This pass adjudicates every red it
left open, on the NUC station (tree parity OK at every
sync: 74 files, then 76 with the kept probe below).
[C21.2 CORRECTION — audit N1: this pass ALSO landed
a game-code fix — the run-reset block in
world.start_game — that the record below omits.
Items 1-3's "the game was correct" holds for those
three checks, but ~13 of the closing reds were in
fact cleared by that game fix, not by check flaws
or the profile axis. The omitted entry, with a new
regression guard, is in the Cycle 21.2 section.]

### 1. The c19 banner check — HARNESS SAMPLING FLAW,
fixed; the game was correct.
Suite2's failure (state=portal, banner_t=4.34) came
from the check, not the game. show_banner() forces
_banner.modulate.a = 1.0 itself, and the old wait's
first poll ran synchronously after the call — it read
show_banner's own write before the world's _process
could re-assert the modal-suppression snap (banner
alpha is snapped every _process to 1.0 iff _banner_t
> 0 and no modal is open). The pass/fail then hinged
on a separately-sampled scrim bit stitched from a
different instant, and the nearly-full timer (4.34 of
5.0) is the fingerprint of that instant exit. The
check now samples ONE steady state: at least 2
process frames after show_banner, banner + backing
alphas at 1 AND no modal open AND scrim hidden, in a
single sample; a probe line per attempt names any
modal still owning the screen. The assertion itself
(banner genuinely visible in a play state, no modal)
is unchanged — the sampling is strictly stronger.
Evidence:
- c19 standalone (NUC) x2: 63/63, probe attempt=0,
  state=portal, modals=none, banner_t=4.73 both runs.
- In-suite: PASS in both the first final run and the
  confirming run (probe attempt=0, a_banner=1,
  a_back=1, scrim=false).
- Mutation demo (NUC copy only, restored byte-exact
  after; world.gd sha f79abad9... on both hosts):
  show_banner sabotaged to _banner_t = 0.0 -> all 6
  attempts shown=false, the check FAILS, exactly 1
  fail in the phase. The fixed check still bites.
  (The mutation log also caught attempt=2 with
  modals=draft — an ambient level-up draft opening
  mid-window, the C21 closing failure mode, settled
  by the loop as designed.)

### 2. The wet timed-rain pair — HARNESS POLL FLAW,
fixed; standalone was already green.
In-suite the rain segment read wet_t=0 for the whole
900-frame window; standalone --only=wet passes
back-to-back (18/18 x2, wet_t=2). Mechanism: the
segment polled with a plain _c9_wait — the only poll
in the phase that does not settle drafts. A draft
opened by the whirlpool kill's XP stays unhandled,
and while a draft owns the screen the weather block
is gated on running=false, so the timed rain never
arms. The poll now settles drafts (the phase's own
whirlpool-segment pattern); the assertion (wet =
max(wet, 2) raw + 'soaked' counts) is unchanged.
Confirming suite: both rain checks PASS, wet_t=2.

### 3. The c20 zl hue check — CHECK ESTIMATOR FLAW,
fixed; the game was correct (probe-proven).
The old form kept only the LAST textured pair's
circular-mean hue delta and demanded |dh - zl| <
0.05. A Rodrigues rotation does not shift every
palette's mean hue by zl. Kept probe
(Test/probe_shiny.gd; log c211_shinyprobe_ubantu.log)
rotates each species' NORMAL textures through the
production operator at its own zl:
  pidgey Body1: dh_sim=0.7209 (zl 0.7176, err 0.003)
  pidgey Eye1:  dh_sim=0.61811485444451 — digit-exact
    the in-suite failure reading. The game's shiny
    eye texture is exactly what the operator makes.
  sandshrew BodyA/B: err 0.004 / 0.006 (BodyB's
    0.6111 is the passing runs' reading, digit-exact);
    sandshrew Eye: err 0.073 — would also have failed
    the old tolerance had it sorted last.
Whether the old check passed was luck of the
director's species draw and material order. The
check now verifies the same property per pair
against the operator's true output: each shiny
texture pixel-identical to the production rotation
of the normal texture, each saturated tint base
equal to the production rotation of the normal base,
and at least one rotation must move pixels (no
vacuous pass via the compressed-fallback path). The
operator itself stays pinned per-channel by the
known-colour Rodrigues probe later in the phase.
Confirming suite drew pidgey again (dh still
0.61811485444451) and the fixed check PASSES.

### 4. The cap cluster (ss-ticket + props hatch
fallback) — RESIDENT-PROFILE AXIS, isolated + fresh-
profile discriminator green.
_team_cap() = 2 + Lab party row + ss-ticket stacks,
and the Lab party row is resident-profile state: the
VM resident owns the row, the NUC resident does not,
so the same check read 3->4 on one host and 2->3 on
the other in the closing runs (neither is the item's
doing). The 21.1 harness edits isolate the row for
the ss-ticket assertion (restored right after) and
rewrote the props fallback to measure the real item
roll through the modal pick path. Fresh-profile
discriminators on the NUC (resident moved aside,
restored byte-exact after — sha256 20a85304...
before == after; world.gd likewise restored):
  --only=c21   fresh: 69 checks, 0 fails
  --only=props fresh: 46 checks, 0 fails
Both cap checks pass on a profile with no Lab state
at all. The game logic was correct; the fixture was
reading ambient profile state.

### 5. The 83-vs-69 c21 phase-count anomaly —
EXPLAINED (harness-version drift, not invocation).
The phase in the final tree contains exactly 69
_c9_check call sites, none inside data loops and
none registered from profile state; the only count
variability is the g3 == null early return, which
would print 51 — matching neither 83 nor 69, so it
is ruled out. Both closing-era invocations (NUC
standalone and in-suite) execute exactly 69. The
cycle-era "83" was recorded against a harness still
under construction while the cycle's items landed
(checks added, then consolidated in the closing /
21.1 harness edits). No invocation or profile
difference on the final tree reproduces it.

### 6. The passive family (ekans + tick passives) —
the closing standalone reds are closed by the 21.1
fixture fixes already in the tree (disarmed waits:
a settled draft's granted move overwrote the tick's
status in the enemy's single slot — the status=sleep
signature; subject isolation for static). Fresh-
profile c21 standalone runs the whole family green
(69/69, item 4 above).

### Final totals (NUC, final tree)
- First final suite: 457 checks, 3 fails (items 2+3
  above). Phonehud RC=0 (0.70/1.00/1.50 + desktop).
  Bootsmoke RC=0 (ALIVE_AT_75S, 0 script errors).
- Confirming suite (after the item 2+3 check fixes;
  game code untouched by them): 457 checks, 1 fail —
  see the residual below. Phonehud RC=0 again.
- APK (built on the NUC from this tree, pulled back
  and verified ON THE VM FILE): 57,634,900 B,
  sha256 12845cabfd17998b764f0999c6d3e34512d401a
  2848968174e0cc231e74fb703; signing cert SHA-256
  b05b80e128a7ff997282b1b80c1973e347ced316b6eb63
  2670a6cbc64350a232 (apksigner); package
  com.spritebonk.game; reference/ entries: 0.
  This supersedes the C21 closing APKs (VM
  6f874240... / NUC 4f2013ed...) as the deliverable
  build of the final tree.

### Residual (NOT waived, NOT fixed — iteration cap)
c21 passive serpent-glare failed ONCE in the
confirming suite with status="" (empty — the tick's
cone found no subject at its 4 s marks), after
passing in-suite in the first final run and in the
fresh standalone (69/69). Cross-run tally for this
check on the final tree: green 3, red 1, the red
being a fixture-geometry race — the subject is
spawned in the facing cone but chases the player
for 6.5 s, and whether it is inside the cone
(dot > 0.45, dist < 7) at a tick instant is path
luck. The game-side tick itself is proven by the
standalone passes at the same code. Suggested next-
cycle fix (harness only): pin the glare subject's
movement like the wet/props fixtures pin theirs.
Cycle 21 is therefore stamped: all 8 scope items +
both chores built and verified; every closing red
adjudicated (3 check flaws fixed with mutation /
probe evidence, 1 profile-axis fixture isolated,
1 count anomaly explained); ONE known-flaky harness
fixture remains red at a 1-in-4 rate and is named
here rather than waived.
[C21.2: the stamp above is incomplete — see the
Cycle 21.2 section for the omitted game-code fix
(N1), the unrecorded 436-check / 30-fail suite run
and the 436 -> 457 count explanation (N2), and the
item-5 reachability restatement (N3).]

## Cycle 21.2 — audit dispositions (2026-10-27)

Micro-pass closing the official Claude audit of
C21/21.1 (~/workspace/claude-audits/spritebonk-c21-
2026-10-27/AUDIT_REPORT.md: "HOLD on the record, not
the build"). Scope: record corrections + harness-only
protections. NO game-logic changes; the only game-file
touch is a comment fix (N4). No new APK — the shipped
build stays 12845cab...

### N1 — the omitted game-code fix, recorded; a
regression guard now exists.
During the 21.1 hunt, world.gd gained a 29-line
run-reset block in start_game (world.gd:5071-5099,
comment + code): _pending_item_rolls.clear(), the
choice modal force-closed (panel hidden, _choice_open
= false), a visible draft panel hidden, the guardian
chests' nodes freed and _chests cleared, and
portal_node freed + nulled. It fixes a real
player-facing leak: a choice modal left open at a
run's end (e.g. a guardian chest opened in "portal"
state and never picked) survived start_game into the
next run with its captured _choice_return intact;
every later modal close then restored THAT state
("portal"), freezing the _later timers, the egg tick
and the challenge watch (all gated on play states)
and failing the guardian summon gate. This one leak
accounts for ~13 of the C21 closing suite's 17 reds
(props challenge/egg/chest family, c21 triple-roll /
shop-close / boss-summon, the c19 state=draft fail).
The 21.1 record credited those reds to check flaws,
the profile axis and the count anomaly and said the
game was correct throughout — that implication is
CORRECTED (see the [C21.2 CORRECTION] notes in the
21.1 section): items 1-3 there were genuinely check
flaws, but the run-boundary hermeticity was a game
bug, fixed in game code.
Regression guard (harness only, new phase c212,
Test/harness.gd _c212_reset_phase): rebuilds the
leak through the real paths (portal pieces up, a
real _spawn_chest, the chest item roll left unpicked
with a second roll queued), returns to menu through
the canonical cleanup (which does not touch modal
state — the leak's precondition), restarts through
start_game, and asserts (a) modal closed + queue
empty, (b) chests cleared + portal_node null,
(c) run 2's clock advances in a play state,
(d) the guardian summon proceeds. Evidence (NUC):
pristine tree 6/6 PASS (log c212_reset_ubantu.log).
Mutation proof in a throwaway copy (main trees
untouched — world.gd sha a8fca232... verified on
both hosts before/after): copy pristine 6/6 PASS;
with the reset block's executable lines 5086-5099
commented out, the phase FAILS (fails=2: modal +
rolls survive — choice=true pending=1; chests
survive — chests=1). Honest limit: in this short
arrangement the timers/summon assertions pass even
mutated (start_game sets running=true; the wild
freeze came from later closes over a long horizon) —
the hermeticity assertions are the deterministic
bite, and they bite.

### N2 — the unrecorded 436/30 suite run, written up.
c211_suite_ubantu.log (NUC, mid-21.1-hunt) ran the
full suite at 436 checks / 30 fails, SUITE_RC=1, and
was never written into this record. The 30: shop x4,
boost x9, props x11, c21 x2 + c21 boss x2, c19 banner
x1, audio menu-track x1. Three independent causes,
all since fixed:
(a) The N1 modal leak: the props challenge/egg/chest
family (wave=0, elites=0, counters frozen), c21
triple-roll (cards=1) / shop close / boss summon,
and the c19 state=draft banner fail.
(b) Resident-bag fixture axis: shop/boost asserted
absolute bag counts from an assumed-empty bag; the
NUC resident profile carries a stocked bag and
197,128 stardust, so buys failed err=bagfull /
sd=197128. Harness fixes: the shop phase zeroes
Profile.data["bag"] + the shop day state under its
snapshot (harness.gd:3066), the boost phase does the
same and also erases the Lab bag row
(harness.gd:3185); snapshots restore the resident
afterwards. Standalone discriminators the same day:
shop 18/18, boost 29/29 (c211_disc_ubantu.log).
(c) Audio menu-track (track=ingame1): in a full
suite the audio phase is NOT at boot — the previous
phase's run track is still loaded and the music
director re-asserts only on its 0.5 s cadence.
Harness fix (harness.gd:2811): settle-wait up to 150
frames for the director to reach "menu" before
asserting; the assertion itself is unchanged. (The
VM closing suite's track=ingame3 fail was this same
family.)
The 436 -> 457 jump: per-phase check counts are
identical between the two runs EXCEPT c21, which
executed 48 of its 69 checks in the 436 run — the
leaked modal failed the guardian summon, the phase
hit its g3 == null early return after exactly 48
checks (the audit's recount of the call sites before
that return), truncating 21 checks. With the leak
fixed, the phase runs all 69.

### N3 — item 5 restated: harness-only kits.
The kingler and gyarados FULL mech ports, the four
first-pass casts (cloyster, starmie, dewgong,
lapras) and the hypno pendulum frame currently run
ONLY in the harness, where _boss_mech is forced onto
another guardian (harness.gd:4037). The seven
species have no GLB model (no model_rig.gd entry, no
file under assets/models) and no guardian-trio slot;
the boss mech is chosen from the guardian's species
(world.gd:7000), so none of these kits can occur in
shipped play. What actually runs in play: the Nb
boss brain, the cross/leap/charge signatures
(scyther / pinsir / nidoking / sandslash / marowak /
dragonite) and gengar's phase-1 double team. The
item-5 header carries a [C21.2 CORRECTION] note.
Path to reachability is in the C22 queue below.

### N4 — gold-teeth formula corrected (docs +
comment; code was always right).
DIFF item 1 wrote x(1-.08/min(3,stacks)); the code
is 1.0 - 0.08 * float(mini(3, stacks))
(world.gd:6292, _teeth_mult). Fixed inline in item 1,
and the matching comment slip in the chestCost
comment (world.gd:6306, ".08/stack" -> ".08 x
stacks") — comment-only edit, no logic change.

### N5 — stale idsig deleted.
build/android/SpriteBonk.apk.idsig was the signature
file of the 14:57 C21-closing VM build (6f874240...),
not of the shipped APK (12845cab..., NUC-built).
Deleted; it could only have mattered for an
incremental adb install.

### N6 — chestCost luck clamp: latent, queued, NOT
fixed here.
The bundle clamps luck at 0 (Math.max(0, luck)) in
chestCost; the port uses luck raw in
1.0 - minf(0.25, luck / 400.0) (world.gd:6312). No
negative-luck source exists in the game today, so
the divergence is unreachable; recorded in the C22
queue. Code unchanged in this pass.

### N7 — serpent-glare instrumented; residual
CLOSED as an instrumented flake (game tick
exonerated).
The glare segment's wait now recomputes the game's
own cone predicate every physics frame and watches
_ptick_next for the carrier, logging each real tick
with its geometry + facing source (GLAREDBG;
harness _c212_glare_wait). Standalone c21 runs on
the NUC, resident profile snapshotted (sha
e84c8212...) and restored before every run:
  run 2: FAIL — tick 1 IN cone (dot .847, dist 1.31)
    and paralyze applied on the tick print; the
    subject then closed to dist ~0 (the cone
    degenerates point-blank), the ~3 s ailment
    expired (applied rt 23.74, gone by rt 26.67),
    and tick 2 at dist 0 could not re-apply.
  run 3: PASS — 2/2 ticks in cone, paralyze held.
  run 4: PASS — 2/2 in cone.
  run 5: PASS — 2/2 in cone.
  run 6: FAIL — 0/2 ticks in cone (dot .36, then
    -.32): the subject approached at an angle and
    settled at the player's side (in-cone only
    84/390 frames).
  runs 7-8 (after this pass's own .godot purge +
    reimport): PASS / PASS, 2/2 in cone each.
Across all instrumented runs: 11 ticks evaluated
in-cone, 11 applied paralyze — no in-cone tick ever
failed to land. The reds are the unpinned subject's
path against the 4 s tick phase (photographed
sub-modes: point-blank degeneration + expiry;
angled approach; side settling) — the fixture-
geometry race the 21.1 record suspected, now proven
rather than asserted. The audit's velocity-facing
hypothesis did not occur (fsrc=rig, vlen=0 in every
failing window). The subject-pinning fixture fix
stays queued (C22 item 3).
Race note: battery run 1 straddled a parallel
worker's .godot purge on the NUC (~19:35) and is
EXCLUDED from the tally as suspect. Its observation
— the whole passive block starved with
running=false stranded by the takeover segment
(tentacles / arena / glare / intimidate red
together; ticks=0 with the subject in-cone 390/390
frames) — was provisional on that tainted run, but
the mode itself is CONFIRMED clean by the
confirming suite below: the same stranding recurred
in-suite under this pass's own purge ritual
(post-takeover / post-event / pre-passive all
running=false, rt frozen), failing all five tick
passives at once. It is a fixture-sequencing state,
not a glare defect; a passive-block entry guard
joins the C22 queue (item 3).
Profile note: the NUC resident drifted from the
21.1-restored bytes (20a85304...) during this pass
(the new c212 phase's runs persist profile counters;
the phase carries no snapshot of its own). The
battery baseline snapshot (e84c8212...) was restored
before every battery / clean run and at the end. No
profile-sensitive assertion depends on it — the
hermetic phases snapshot their own axes.

### Confirming runs (NUC, final tree of this pass)
Sync + parity OK (78 files), .godot purged +
reimported before the runs.
- Full suite: 463 checks (457 + the 6 new c212
  checks), 5 fails, SUITE_RC=1 (log
  c212_final_suite_ubantu.log). ALL 5 fails are the
  tick-passive family — tentacles, arena-trap,
  serpent-glare, intimidate, static — and all 5 are
  ONE event: the takeover segment stranded
  running=false, the world clock never advanced
  (C21DBG: post-takeover / post-event / pre-passive
  all running=false, rt frozen at 12.776212), so no
  passive tick was ever evaluated (glare GLAREDBG:
  ticks=0, subject in-cone 390/390). This is the
  starvation mode of N7's race note, recurring
  in-suite; it predates this pass (the closing
  standalone reds carry its signature) and is a
  fixture-sequencing flake, not a regression from
  the 21.2 harness changes — the c212 phase itself
  went 6/6 in-suite. Not re-run to shop for green;
  the entry-guard fix is C22 item 3. The other 458
  checks all passed.
- Phonehud: RC=0 — phone 0.70 / 1.00 / 1.50 and
  desktop all OK.
- Resident profile restored to the battery baseline
  (e84c8212...) after the runs.

### C22 queue (recorded, not scheduled here)
1. N6: chestCost luck clamp at 0 (one line, latent).
2. Item-5 reachability: GLB models + model_rig
   entries for kingler, gyarados, cloyster, starmie,
   dewgong, lapras, hypno (user GPT-art pipeline),
   plus a summon-path decision — trio placement is
   bundle-derived data, so putting these species in
   trios is a deviation; the alternative is a boss
   path beyond trios. Decide before building.
3. Serpent-glare fixture: pin the subject's movement
   (from the 21.1 residual; N7 above has the
   photographed sub-modes), and add a passive-block
   entry guard that re-asserts running=true (the
   starvation mode in N7's race note).
4. Boss full-fidelity follow-on (item 5 TRUE SIZE
   NOTE): starmie reflecting-path geometry, dewgong
   trail bursts, lapras pump tail, gengar phases
   2-3, hypno drowsy payoff, marowak tower veil.
5. Run-tier ladder tiers 1-2 (Nb tele/escort rows)
   and re-mining the Db/Ob impatience constants.
6. Ditto populate (unblocked by C21 item 1),
   golden-meowth event, fog minimap blinding,
   EN item names (unrecovered from the bundle).

Cycle 21.2 verdict: the audit's record HOLD is
answered item by item above — the build was never
held, and it does not change in this pass (no new
APK).

## Cycle 21.3 — UI overlap fix cycle (2026-10-27/28)

Executed to the official Claude UI audit's prescriptions
(~/workspace/claude-audits/spritebonk-ui-c21-2026-10-27/
AUDIT_REPORT.md): gate hardening first (§4), then
F1–F7 + the §3 z-order/modal policy + the five §5
readability items in scope. The rest of §5 is in the
C22 additions below, not built.

### Gate hardening (§4) — harness only
- Test/phonehud.gd rewritten: touch layer FORCED ON
  (_touch_forced) for phone runs — the old gate never
  rendered the touch layer at all, which is why the
  overlaps shipped; --inset=L,T,R,B via the F6
  debug_safe_insets seam; _vis_rect_deep for the
  top/goal cards; the §4 assertion list (touch
  elements x every readable target incl. banner,
  prompt, boss, bars; pill top vs the goal's DRAWN
  bottom; info-stack bottom vs ult gauge top; banner
  span containment + centre-stack disjointness;
  prompt vs the BL band from the MOVE SLOT's visual
  top (cluster-local 48); ult-name hidden in touch
  mode; modal triad — touch hidden + scrim visible +
  scrim covers the viewport; inset edge checks;
  desktop pins kept verbatim).
- Test/check_phonehud.sh: full matrix 3 windows
  (2400x1080 / 2340x1080 / 1920x1080) x touchScale
  {0.70, 0.85, 1.00, 1.50} x insets {0, 48L, 48R}
  = 36 phone runs + desktop; PH_QUICK=1 subset kept.
- RED BASELINE (unfixed tree, NUC): 37/37 runs red,
  23,467 checks / 3,573 fails, 0 script errors. Top
  classes map 1:1 onto the audit register: banner x
  hero 185, pill-top-vs-goal (O10) 180, banner x
  minimap 180, banner-within-span 180, tc x pill
  ~660 across buttons (O1/O2), info-stack budget 126,
  bar0 x stat-chip row 96 (O8b), banner x bar0 96,
  prompt x BL band 72 (O7), scrim-covers-viewport 72
  (inset variants; §3), modal-shop scrim pair (the
  gate-caught bug below). Assertions that PASSED
  pre-fix, honestly: desktop pins 25/25 (they guard
  shipped geometry), joystick ring x slot row (the
  C20.2 clamp already worked — the old gate simply
  never showed the ring), modal touch-hidden (the
  state-machine luck the audit described), inset
  hero/minimap edges (_ui_root itself shifts),
  ult-name x prompt (the unfixed prompt sat low;
  O11's orphan was real but not touching it yet).

### Game-code changes (scripts/world.gd unless noted)
F6 seam + width math: debug_safe_insets var;
_safe_insets() honours it when set; _layout_hud takes
vw/vh from _ui_root.size (viewport fallback for
pre-layout frames); touch_controls.gd _joy_home uses
the layer's own size.
F7: top card design width 640 -> 726 (creation
offsets -363..363; layout constants 363/726; s_top
fit divisor 1282 -> 1368). The fit guard is
`vw > 1280.0 or _phone_factor() > 1.01`: a 1920x1080
phone window is exactly 1280 logical wide, where
the unclamped 1.925 factor cannot fit the row at
all (the gate's first 1920 runs measured span_w = 1
and a 1-px banner); desktop at 1280 (factor 1) keeps
s_top == s and its pins.
F2: pill box top = goal offset_top + gh * s_top + 8
(the card's DRAWN bottom; offset_bottom deliberately
stays the design height — scaling it too would
apply s_top twice; the gate measures drawn rects).
F1 (world.gd + scripts/touch_controls.gd):
- TouchControls.set_right_column_left / column_left
  / _apply_column: pause/aim/lock park immediately
  left of the pushed lane (right edge = lane - 10),
  re-derived from apply_scale + resized; _layout_hud
  pushes mm_l (global-converted). Jump/dash/
  interact/ult gauge and the ring clamp untouched.
- _apply_stack_budget + _restack_goal + _goal_gh +
  _badge_on_pill/_badge_on_goal + the _pill_badge
  node: Z = (vh - 248*ts) - 8; shed order (1) pills
  past the first collapse into a "+N" badge on the
  first pill, (2) goal header-only, (3) first pill
  hides, badge moves to the goal header. Reset-first
  every pass, touch-visible only.
- _refresh_event_pills ends a rebuild with
  _layout_hud() — a rebuild replaces every pill node
  (fresh = visible), which silently undid the shed
  until the next goal refresh; gate-caught
  (hud_alpha stack), fixed at the source.
- The budget re-derives the full-stack positions
  (_restack_goal) right after its reset, before
  measuring: the main body's pass can run against
  the previous pass's shed state (its gh reads the
  children's CURRENT visibility), and a Control
  never draws below its combined minimum — so an
  un-hidden goal draws full height while the pill
  box still sits at the shed position, understating
  the settled stack so the shed never re-fires.
  Gate-caught at 1920x1080 @ touchScale 1.50 (the
  first full-matrix run went 36/37 with exactly this
  family red: pill_top 275.14 vs goal drawn bottom
  294.68); fixed, variant re-verified 605/0, matrix
  re-run in full (below).
F3+F4 (centre stack, phone branch of _layout_hud):
- Span: left = max(hero right, stat-chip row's
  MEASURED right) + 12; right = min(minimap left,
  touch lane left) - 12; stored in _dbg_span.
- Flow from the top card's drawn bottom + 8, 8 px
  gaps, hidden items skipped: boss card (scale
  min(s, span/460)) -> mini bars (scale
  min(s_top, span/300), tops flowed; offset_bottom
  moves WITH the top — these are plain Panels, a
  top-only write stretches them to their creation
  bottoms, which the gate's measured heights caught
  in the first fixed-tree probe) -> banner (label
  scale min(s, span*0.96/text width); the backing
  is SIZED to the span — its 892 design width
  exceeds the free span at phone widths — height
  56*bsc).
F5:
- _ult_name_label hides wherever _ult_circle hides
  while touch is visible (the O11 orphan).
- _layout_prompt (phone branch): scale cap 1.6,
  autowrap on, width fitted to the free span, visual
  bottom pinned to (BL global top + 48*scale) - 8
  via the delta method on offset_bottom. The span's
  right end is the touch CLUSTER's left edge
  (TouchControls.cluster_left(), the audit F5c's own
  bound): at touchScale 1.50 the big dash/jump
  buttons protrude ~21 px past the moved column and
  the prompt crossed dash by 5.4 px (gate-caught at
  1.50 + left inset).
§3 policy:
- Touch show condition gains `and not
  _any_modal_open()` — explicit, not state luck.
- _any_modal_open() gains _meowth_panel — THE
  GATE-CAUGHT BUG the audit missed: the in-run shop
  never raised the scrim and never suppressed the
  banner, because its panel was missing from the
  modal list (the list's _shop_panel is the daily
  shop, a different panel).
- _apply_safe_area extends _modal_scrim's offsets
  over the insets (the scrim covers the WHOLE
  screen, not just the inset UI area).
§5 (only the five in-scope items):
- Goal next line split: the description keeps its
  clip; the count has its own right-aligned label
  (_goal_count) that never clips.
- "› Lv.24 进化": font 13 -> 14 (colour alpha is
  already 1.0, >= the audit's 0.8 floor).
- Kills pill label: centred -> left-aligned.
- Banner backing alpha 0.55 -> 0.75 (after F3).
- Prompt ink-glass backing (_prompt_back, glass
  (12, 0.75)); geometry mirrored from the prompt in
  _layout_prompt; visibility tracks the prompt text.

### Rider (harness only, pre-specified by 21.2)
- Test/harness.gd passive-block entry guard: if
  running is stranded false at the block entry,
  print C213DBG and re-assert running=true.
- Confirming suite verdict: the starvation mode did
  NOT recur — the guard never had to fire (no
  C213DBG line), the passive block ran with
  running=true throughout (run_time advancing,
  C21DBG trail), and 4 of the 5 tick passives passed
  outright (tentacles, arena-trap, intimidate,
  static; beacon is not a tick passive and passed).
  The guard stays in as a permanent precondition.
- The suite's single remaining fail is the OTHER
  half of C22 item 3, reported still-open, NOT
  shopped for green: c21 passive serpent-glare.
  GLAREDBG in this very run proves the game side:
  tick 1 evaluated in_cone=true and APPLIED
  paralyze (status=paralyze at rt 27.38); the
  fixture subject then drifted out of cone
  (dot 0.466 -> 0.14 — the side-settling sub-mode
  photographed in 21.2), the ailment expired, tick
  2 evaluated in_cone=false, and the check's final
  sample read status="". The cure is the queued
  fixture subject pinning, not game code and not
  the entry guard.

### Gate-scoping notes (desktop)
Two §4 pairings are asserted on PHONE only, per the
audit's own scoping (F3/F4 are phone-branch
prescriptions; desktop geometry is the kept
baseline): banner x hero-deep (on desktop the deep
union box false-positives; the chips row it could
really hit is paired separately as banner x pw row
on BOTH modes and passes) and boss x pw row (on
desktop the shipped centred boss card, drawn bottom
230, covers the stat-chip row's right end at y 206 —
a pre-existing desktop trait the audit left alone;
first of the C22 additions below). The gate's span
comparison converts _dbg_span from _ui_root-local
to global (they differ exactly by the safe-area
inset; at inset 0 they coincide). Two gate checks
gained detail strings (banner x bar, boss x bar).

### Verification (final tree, NUC unless noted)
- Phonehud gate, FULL matrix re-run after the last
  fix: 37/37 runs OK (wrapper RC=0); 22,550 checks /
  0 fails / 0 script errors across the run logs.
  (First fixed-tree matrix: 36/37 — the 1920 @ 1.50
  family above; VM probes during development:
  2400 s070/s085/s100/s150 i0, s100/s150 i48L,
  w2340 s100 i48R, w1920 s085, desktop — all 0-fail.)
- Full suite (harness --mode=cycle9): C9 SUMMARY
  checks=463 fails=1 — the serpent-glare fixture
  item adjudicated above; c212 regression phase
  6/6 in-suite; 0 script errors. (21.2's confirming
  suite was 463/5; the four extra 21.2 fails were
  the takeover starvation this cycle's rider
  targeted.)
- uiaudit _fixed captures: Test/out/ui_audit_c21/,
  12 states x {2048x920_s085, 2400x1080_s100}_fixed
  (24 PNG, 0 script errors), same states as the
  audit evidence for before/after comparison.
- APK (NUC build, class-cache gate OK):
  build/android/SpriteBonk.apk = 57,643,092 bytes,
  sha256 2d46a654e7408017e9982d98ddafa28f23f9693
  e20fa157da1469547d29ef0f8, signing cert SHA-256
  b05b80e1...a232 (unchanged), reference/ entries
  in the APK: 0.
- Housekeeping: the NUC resident profile drifted
  during this cycle's verification (sha e84c8212...
  -> 4da1b945...; stardust 197,128 -> 97,318; the
  bag and settings are intact). Probable cause: an
  accidental starters-mode harness launch (wrong
  --mode) before the real suite, whose snapshot
  then preserved the dirtied state. The e84c8212
  bytes exist in no vault on either host and are
  not recoverable; the current resident is
  preserved byte-exact as the new battery baseline
  at Test/profile_vault/profile_postcycle213.json
  (sha 4da1b945...) in BOTH hosts' vaults.

### C22 queue additions (from this cycle)
1. Serpent-glare fixture subject pinning (the
   still-open item above; C22 item 3's other half).
2. Desktop boss card x stat-chip row (kept
   baseline; audit left it, noted in the scoping
   notes above).
3. The rest of audit §5: pause panel empty
   interior; loadout evolution-line size + portrait
   overflow; scrim 0.7-under-pause option; goal
   next-line on the narrowest window.
(Plus the pre-existing C22 list in the 21.2 record;
its item 3's entry-guard half is DONE above.)

Cycle 21.3 verdict: the audit's O1–O12 register is
closed on phone geometry — the hardened gate is
green across the full matrix, the suite is green
but for the one pre-queued fixture item, and the
build above carries the fixes.

## Cycle 21.3.1 — re-audit fix micro-pass

Closes the three conditions of the official Claude
re-audit of 21.3 (~/workspace/claude-audits/
spritebonk-ui-c213-reaudit-2026-10-28/, verdict SHIP
WITH DISCLOSED RESIDUAL): N6 evidence re-pull, N1
the dropped F5c 2-line rule, N2 the unasserted
prompt backing. Plus the record corrections the
auditor required. Game-code changes are ONLY in
world.gd's prompt region (item 2); everything else
is harness / docs.

### 1. N6 — evidence re-pulled and re-counted

The 21.3 NUC logs never reached the VM (one rsync
failed 255 while its .done file claimed RC=0 — a
stale .done from an earlier step). All c213 NUC
logs were re-pulled into Test/out/ (57 files,
3,188,091 B) with the new standing tool
Test/pull_from_nuc.sh, and the headline numbers
re-counted FROM THE LOGS THEMSELVES:
- Green matrix: 22,550 checks / 0 failures across
  the 37 per-run PHONEHUD DONE lines — matches the
  21.3 record exactly.
- Full suite: 463 checks / 1 failure, the failure
  being the serpent-glare fixture item; the run's
  GLAREDBG lines are in the log and consistent
  with the mechanism recorded in 21.2 (tick 1 in
  cone, paralysed; tick 2 out of cone).
- Red baseline: the wrapper log
  (c213_base_ubantu.log) confirms all 37 runs
  FAILED (0 OK) on the un-fixed tree, per-run
  lines 2,973–9,130 B. The exact totals the crew
  reported (23,467 checks / 3,573 fails) CANNOT be
  re-derived: the baseline per-run logs were
  overwritten on the NUC by the two green rounds
  (same filenames) before the re-pull, and the
  aggregate appears in no surviving file on either
  host. The 21.3 record's baseline totals stand as
  the crew's contemporaneous count, unverifiable
  after the fact — recorded here so the limit is
  explicit.
Pull-step honesty fix (the auditor's underlying
point): Test/pull_from_nuc.sh deletes its .done
up front, rsyncs with retries, and writes
"RC=0 files=N bytes=B" into .done ONLY after
verifying every pulled file's size against the
NUC-side manifest; on any mismatch it writes the
real RC. Two field lessons are in its header:
pull-direction rsync does not expand "~/" in the
remote source (absolute paths required), and -a's
chown fails cross-machine (rc=23) even when all
bytes land — use -rltz. The false c213 .done is
preserved next to the honest c213_repull pair as
the historical record.

### 2. N1 — the F5c 2-line rule, implemented for real

world.gd prompt setup now sets
_prompt.max_lines_visible = 2 (was: nothing — the
cap existed only in the audit text). Two companion
rules in _layout_prompt keep the cap from clipping
the longest strings (both from _prop_label: the
chest insufficient-funds line and the meowth line):
- Fit-within-the-span: where 2 lines are
  achievable at scale >= 1.0 (fit2 = 2*span /
  (w1 * 1.06) >= 1.0, w1 = measured one-line text
  width), the prompt scale is lowered (floor 1.0)
  until the text fits 2 lines of the span. At
  touchScale 1.50 the span is already fully used,
  so without this the cap clipped both strings
  (gate-proven: lines=3 before, lines=2 after, at
  every 1.50 combo of the 20:9 windows and at
  1920x1080 with either side inset).
- Span-aware lift: where 2 legible lines are
  geometrically impossible (fit2 < 1.0 — the
  16:9 centre span is ~140 visual px; at
  1920x1080 + touchScale 1.50 + no inset the
  F5c cluster bound leaves a ~38 px gap), the cap
  lifts (max_lines_visible = 0) and the scale
  additionally fits by height (260 px target) so
  the prompt wraps FULLY as a bounded column,
  bottom-pinned, exactly as it shipped in 21.3 —
  complete text over a clipped price line. The
  gate asserts lines <= cap where the cap is
  engaged, and the column height (<= 288) where
  it is not. Disclosed residual: at that one
  combo the prompt is a narrow column (chest 13
  lines / h 38, meowth 19 lines / h 40 in the
  gate's measurement); a real relocation for
  hopeless spans is queued in C22 (item 6 below).
  A lane-bound fallback (ignore the cluster
  bound when it strangles) was implemented and
  REVERTED inside this pass: the gate showed the
  drawn prompt reaching x~1009 against the
  dash/jump buttons' left edge at 956 — a real
  overlap of the buttons, worse than narrow.

### 3. N2 — the gate now asserts the prompt BACKING

Test/phonehud.gd: the prompt's asserted rect is
the UNION of the label and its ink-glass backing
(_prompt_back) in every state (_prompt_rect()),
plus the F5c line-cap assertion from item 2. The
backing was trimmed to match: side pads +-12 ->
+-8 design px in _layout_prompt (top/bottom -+6
unchanged), keeping the ink-glass look. One more
real defect the union assertion exposed on
DESKTOP: the desktop branch never called
_layout_prompt, so the backing kept its creation
slab (624x130, bottom 726 — past the 720
viewport, over the skill band). The prompt
visibility tick now mirrors the backing onto the
label's drawn rect every tick on desktop
(factor <= 1.01). Verified: desktop run green,
backing bottom 640 vs band top 650.
Full matrix re-run on the NUC with the union
assertion in force: 37/37 runs OK — 22,624
checks / 0 failures summed from the 37 per-run
PHONEHUD DONE lines (wrapper rc=0; logs pulled
and verified, Test/out/c2131b_pull.done: 64
files, 4,550,969 B). Targeted pre-runs
(check_phonehud-faithful invocations — see the
methods note): the eight stressed combos
(1920x1080 at 0.70/0.85/1.50, 1920x1080 @1.50
with both insets, 2400x1080 @1.50 with/without
left inset, desktop) all OK, per-combo cap
outcomes as listed in item 2.
Methods note: three early targeted subsets in
this pass were invoked with --resolution /
--touchscale flags the harness ignores (it takes
--win / --scale under xvfb); their geometry was
wrong (all 2400x1080) and NONE of their results
are used above. All verification cited here is
from check_phonehud.sh itself or byte-identical
invocations.

### 4. Phrasing correction (auditor-required)

The 21.3 record's "37/37 red -> green" is
corrected: the desktop run went green by
RE-SCOPING 6 checks to phone-only, one of them a
REAL desktop overlap (boss card x stat-chip
row), already queued in the 21.3 C22 additions
(item 2 there). The honest summary of 21.3 is:
36 runs fixed + 1 run re-scoped. This addendum's
own matrix claim in item 3 is stated per-run for
the same reason.

### 5. C22 queue additions (from the re-audit)

Appended to the 21.3 "C22 queue additions" list
as items 4-6:
4. N3: CJK wrap splitting (the insufficient-
   funds line breaks mid-phrase) — cosmetic;
   needs a break-opportunity pass on prompt
   strings.
5. N4: centre-stack lopsidedness (stack sits
   right of centre at wide spans) — design look.
6. Prompt relocation for hopeless spans
   (1920x1080 + touchScale 1.50 + no inset: the
   F5c gap is ~38 px; see item 2's residual).

### 6. Suite, bootsmoke, build (this micro-pass)

Full suite on the NUC (cycle9): C9 SUMMARY
checks=463 fails=0 — one better than 21.3's
463/1: the serpent-glare fixture item passed
this time (GLAREDBG lines in the log; the
fixture's position sensitivity is the recorded
21.2 mechanism, and pinning stays queued in
C22). Bootsmoke: OK (export alive at 75 s, 0
script errors). APK rebuilt on the NUC and
verified on the VM pull: build/android/
SpriteBonk.apk, 57,643,092 B, sha256
71f31b44625b27fe7115fd09e7e7a4c95c3c1d5328
f6c8566c83fb85c7155f9c, signer certificate
SHA-256 b05b80e1...a232 (the standing cert),
package com.spritebonk.game v1.0.0 (code 1),
reference/ entries in the archive: 0.
Process note: a Linux export binary from a
21.3-era smoke run was found still spinning on
the NUC after ~22 h (225% CPU) and killed; it,
plus the bot fleet's normal load, is why this
pass's NUC runs were slow — no gate result
above rests on a timed-out run (the matrix's
900 s per-run timeout never fired).

## Cycle 21.3.2 — the cap-lift regression fix (2026-10-28)

Closes the P1 BLOCKING item of the targeted
re-audit of 21.3.1 (~/workspace/claude-audits/
spritebonk-ui-c2131-reaudit-2026-10-28/, verdict
HOLD). Game-code changes are ONLY in world.gd's
_layout_prompt; the gate change is in
Test/phonehud.gd.

### 1. Correction of the 21.3.1 record (item 2 there)

The 21.3.1 "span-aware lift" paragraph is WRONG
and is corrected here. It said the cap "lifts
(max_lines_visible = 0)" so "the prompt wraps
FULLY as a bounded column... complete text over
a clipped price line", and reported the lifted
column as "chest 13 lines / h 38, meowth 19
lines / h 40 in the gate's measurement". In
Godot 4.3, max_lines_visible = 0 shows NO lines
(unlimited is -1). On the 10 combos that took
the lift path — all of 1920x1080 at touchScale
0.70 / 0.85 / 1.00 (every inset) plus 1.50
no-inset — the chest and meowth prompts rendered
as EMPTY glass boxes: the measured heights
(h 38 / h 40) were the empty label's, and 13 or
19 wrapped lines cannot fit in 38-40 px — the
record's own numbers were the tell, missed at
the time. This was a regression against 21.3
(the pre-cap prompt showed its full text in a
column). The 21.3.1 gate passed those combos
because it bounded HEIGHT only; no assertion
checked that any line was visible.

### 2. The fix (world.gd _layout_prompt only)

- Correct semantics: where 2 lines fit at any
  scale >= 0.6, the cap stays 2 and the span-fit
  scale may go BELOW the old 1.0 floor, down to
  the computed fit2 itself (hard floor 0.6).
- Only where fit2 < 0.6 does the cap lift, now
  to max_lines_visible = -1 (all lines), seeded
  with the analytic height fit (260 px target).
- The analytic fit under-measures real wrapped
  height (it models ~24 px rows; the real row
  pitch at the lifted scales is ~33 px, so the
  first lifted columns measured up to 449 px
  against the 288 bound). _layout_prompt now
  ends the lifted regime with a measure-and-
  correct loop (max 4 iterations): apply width
  and scale, refresh the minimum size, measure
  the REAL height, and shrink the scale by
  288/measured until the union fits. The capped
  regime measures once and exits. Full text AND
  height within bound are now simultaneous, in
  every combo — see the per-combo table in
  item 5.
- Two further real defects found by the new
  gate assertion during this pass, both in the
  same function:
  (a) set_max_lines_visible does not dirty the
  Label's minimum-size cache in Godot 4.3, so
  after a cap flip the rect height was computed
  from the OLD cap and re-clipped the lifted
  column to 2 lines. _layout_prompt now calls
  _prompt.update_minimum_size() after the cap
  assignment and again before reading min_h.
  (b) Stale-pivot backing displacement:
  _set_scaled computes the pivot from the size
  current at call time, and the label's height
  trails its container-fitted minimum size, so
  mid-layout the pivot referenced a stale height
  (626 when the final height was 196). The
  bottom-pin then baked that pivot error into
  the label's offsets; the backing — copied
  offsets, fresh pivot — drew ~236 px away from
  its label (1920x1080 / 1.50 / no inset, meowth
  state; the gate's union rect caught it).
  _layout_prompt now refreshes the label's pivot
  from its final size before pinning. Latent
  since 21.3; it only bites when consecutive
  prompt states differ greatly in height, which
  is exactly what the lifted regime does.

### 3. Gate (Test/phonehud.gd)

New assertion in EVERY prompt state, per the
re-audit: the prompt label's
get_visible_line_count() == get_line_count()
("prompt shows every wrapped line :: vis=N
total=N cap=C scale=S"), alongside the existing
height/union bounds. Also fixed: the stale
"~12 px pads" comment in _prompt_rect (actual
pads: 8 side / 6 vertical).

### 4. Second log loss — disclosure + standing rule

The re-audit found, and this record confirms: a
21.3.1 evidence pull (the c2131b pull) landed on
the VM under SHARED per-run filenames and
overwrote the 21.3 green per-run logs (e.g. the
desktop log changed 70,269 -> 70,568 B). No copy
survives, so the 21.3 green total (22,550
checks / 0 failures) is NO LONGER RECOUNTABLE.
The 21.3.1 total (22,624 / 0) WAS recounted and
verified by the auditor and stands. Standing
rule adopted from this pass: evidence pulls land
under PER-PASS filename prefixes. Applied here:
before this pass began, the surviving 21.3.1
per-run logs were snapshotted to c2131_-prefixed
names; every 21.3.2 log in Test/out/ carries the
c2132_ prefix (37 per-run matrix logs + wrapper,
suite, bootsmoke, build).

### 5. Per-combo behaviour — the 10 affected combos

From the c2132_ per-run logs ("prompt shows
every wrapped line" lines; heights asserted
<= 288 in the same runs). vis/total = visible
lines / wrapped lines; cap -1 = lifted,
2 = capped.

  combo (1920x1080)      chest prompt        meowth prompt
  ts 0.70, no inset      6/6, -1, s=1.378    2/2, cap 2, s=0.628
  ts 0.70, left inset    6/6, -1, s=0.938    6/6, -1, s=1.047
  ts 0.70, right inset   6/6, -1, s=0.938    6/6, -1, s=1.047
  ts 0.85, no inset      6/6, -1, s=1.378    6/6, -1, s=1.385
  ts 0.85, left inset    6/6, -1, s=0.845    6/6, -1, s=1.047
  ts 0.85, right inset   6/6, -1, s=0.845    6/6, -1, s=1.047
  ts 1.00, no inset      5/5, -1, s=0.938    5/5, -1, s=1.047
  ts 1.00, left inset    6/6, -1, s=0.845    5/5, -1, s=0.770
  ts 1.00, right inset   6/6, -1, s=0.845    5/5, -1, s=0.770
  ts 1.50, no inset      13/13, -1, s=0.655  6/6, -1, s=0.451

Every line of both prompts is visible in all
10 combos, and the prompt union stays within
the 288 px height bound in all of them. The
ts 1.50 no-inset column remains narrow (the C22
relocation item from 21.3.1 item 5.6 is
unchanged), but it now shows its text —
visually confirmed in the _fixed2 captures
(Test/out/ui_audit_c21/: chest_nofunds and
meowth_prompt at 1920x1080, touchScale 1.00 and
1.50 no-inset).

### 6. Matrix, suite, bootsmoke, build

- Phonehud matrix on the NUC: 37/37 runs OK —
  22,696 checks / 0 failures summed from the 37
  per-run PHONEHUD DONE lines (c2132_-prefixed
  logs). Delta vs 21.3.1's 22,624 is exactly
  +72 = the new visibility assertion (36 phone
  runs x 2 prompt states; the desktop run has
  no touch prompt states).
- Full suite (cycle9): C9 SUMMARY checks=463
  fails=1 — the serpent-glare fixture item
  again. Its GLAREDBG trace in
  c2132_suite_ubantu.log shows the mechanism
  working (tick 1 in cone -> status=paralyze);
  the assertion read the status after it had
  expired, and tick 2 found the enemy at
  dist~0 / dot=0 (the face-hug cone degeneracy
  recorded in 21.2). Fixture flake, not a game
  defect and unrelated to this pass's change
  surface (prompt layout only); the fixture
  pinning stays queued in C22. Not re-run to
  chase green.
- Bootsmoke: OK (export alive at 75 s, 0 script
  errors).
- APK rebuilt on the NUC and verified on the VM
  pull: build/android/SpriteBonk.apk,
  57,643,092 B (same byte count as 21.3.1, a
  different package), sha256
  9a47ef2cf85d4cc6b0880acb5447c3e31997d98c961
  3a18fdc4f98010370ceb3, signer certificate
  SHA-256 b05b80e1...a232 (the standing cert),
  package com.spritebonk.game v1.0.0 (code 1),
  reference/ entries in the archive: 0.
  VM <-> NUC tree parity verified before the
  runs (86 files, 0 diffs).
## Cycle 22 — non-UI alignment continuation (2026-10-28)

Scope: the C22 queue items 1, 3 (pinning half), 4 and
6 from the 21.2 record. The UI line is owned by the
mobile-UI plan (design/ui-mobile-plan-v1.md) — no HUD
layout, panel or phonehud assertion was touched.
Verification: NUC station, tree parity 86 files /
0 diffs, .godot purge + import. c22 phase standalone:
51 checks / 0 fails. Glare evidence correction (C23B2 F2):
the original C22 x4 logs were absent from the audit package;
pre-fix passive flakes also contradict an all-four-69/0 claim.
B2's first reproduced c21 x4: 69/1, 69/0, 69/3, 69/0
(full details and fixture correction in section 6 below).
Phonehud matrix: rc=0
(all combos, assertions unchanged). Full suite,
first pass: 514 checks / 1 fail — the props census
(its 51-prop / 14-kind premise predates the ditto
addition; the census now reads 52 / 15 with ditto
counted, per-kind counts still exact). Final pass
on the closing tree: 514 checks / 1 fail — a
different single red (guardian: chest exists to
open; green in pass 1). Triage: in that same run
the kill-side checks prove the chest spawned
(spawned=1); the failing finder runs after a
14-level draft settle, during which the chest —
spawned at the guardian's feet, inside the
player's proximity — auto-opened (the bundle's
walk-over channel), leaving chests_positions()
empty. A pre-existing fixture race in code this
cycle did not touch; the two passes' reds are
disjoint. c22 was 51/0 in both full suites; props was
46/0 standalone. The c21/glare x4 claim is corrected in
section 6; it must not imply all pre-fix phases were green.
Bootsmoke: OK (rc=0, run against the rebuilt APK).
APK: 57,663,572 B, sha256 938dcef0…,
cert b05b80e1…a232, reference/ entries 0.

### 1. N6 — chestCost luck clamp (queue item 1, DONE)
world._chest_cost now clamps the luck term with
maxf(0.0, luck), the bundle's Math.max(0, luck)
(@1236548). Harness: luck 0 / -400 / -100000 all price
at the luck-0 price (18); luck +400 still discounts
(14). Mutation-sensitive: without the clamp the
negative cases price above base.

### 2. Boss mechs — the gengar/marowak premise was
### wrong (queue item 4, DONE with a correction)
Mining the boss dispatch (@996446) shows the mech
source splits by mode: mech = kit ? null : (tower ?
gb[e] : fb(a, this, l)). The gb classes (gengar 94,
marowak 105) attach ONLY in tower mode; stage play
reads fb/db, which has no gengar or marowak entry,
and neither species is in the Pb signature table
(@1009705) — EXCEPT marowak, whose stage presence is
the Pb cross the port already had. Tower is a
separate game mode (mode === 'tower' @1441046, own
candle/grave layouts) that this port does not have.
Consequences, recorded plainly:
- C21 item 5's gengar kit (double team + volley)
  was the TOWER class's phase 1 misapplied to stage
  play. It is REMOVED: BOSS_MECH / BOSS_MECH_NAMES /
  _boss_reset / the cast no longer carry gengar.
  Zone 2's shipped guardian is always gengar, so
  this changes the most-reachable boss fight: stage
  gengar now fights with generic boss moves only,
  exactly as the bundle's stage mode does.
- Marowak needed nothing (its stage kit is the Pb
  cross, already ported); the "tower veil" belongs
  to the unported tower mode.
- The mined gb classes are recorded here for a
  future tower mode: gengar — doubleTeam + volley /
  blackout dive (veil = 1, class hitMul 0.05,
  exposed x1.6) / hypnosis strip -> sleep 1.6 ->
  dream eater strike 1.5 + 5% heal; marowak —
  veil = 3, candles calm -> x1.6 for 12 s, silph
  scope shown 4 s, lament snuffs candles, bone/wail
  casts. Veil in the bundle's combat.hit (@724299):
  veil === 1 -> damage x0.25 (separate from class
  hitMul).
- Queue item 2 (reachability) is reframed, not
  closed: models + a summon path would make the
  four db kits below reachable, but gengar/marowak
  gb content stays tower-gated regardless of models.

The four db kits + the cloyster follow-on are now
ported at full fidelity (all numbers from the mined
db classes @939840-966255):
- Starmie (121): the true reflecting path — centre =
  player position, start clamped to the r=14 circle,
  4 legs (6 enraged) each solving the r=15 circle
  exit and reflecting off the circle normal with
  +/-0.35 rad jitter; per-leg telegraph lines
  (colours alternate per leg parity); run at 26 u/s
  starting at u = 1.2 tk, one contact strike 1.4 per
  leg, dizzy 2.5 s + hold 2.5 at the end (hitMul 1.8
  while dizzy, as before). FOUND BY THE HARNESS: the
  cast originally returned u + 4.5, shorter than the
  move itself (delay + ~4.3 s travel + 2.5 dizzy);
  the boss brain re-cast mid-run and reset it, so
  the dizzy could never land — in the harness or in
  real play. The return now covers u + path
  travel/26 + 2.5 + 0.3, computed from the path.
- Dewgong (87): the slide chain now leaves a TRAIL
  segment per slide (start -> end, 6 s life): a
  player within segDist < 1.2 of it slips
  (player.arena_slip, see the status system below);
  at burst = 1.2 s the trail bursts — shard novas
  along the segment, and a player standing on it at
  low 1.3 takes strike 1.1 + frozen 0.9 s. The old
  pool-at-slide-end approximation is deleted.
- Lapras (131): pillars are real attackable OBJECT
  bodies (new Enemy.is_object: no AI, no contact
  damage, no kill credit — _on_enemy_killed returns
  early), hp = 1.2% of the boss's max HP, lobbed 5
  (7 enraged) onto the r=4.6 ring, 9 s life. (The
  body uses a modelled donor species under the hood
  — unmodelled species are never spawned in this
  port — with species_id/types overridden and the
  rig hidden behind an ice cylinder mesh.) Hydro
  pump at +1.8 s: the 34 u beam STOPS at the first
  pillar within 1.2 of the line (bundle block()) —
  blocked = no damage + floater; unblocked and the
  player within 1.75 of the segment at low 1.6 =
  strike 1.8. Surf at +5 s is lapras's own wave
  (11 u/s, max r 26, strike 1.3) and SHATTERS the
  pillars in its band.
- Hypno (97): the pendulum is now a field, not a
  visual: base angle tracks the player at <= 0.4
  rad/s, beam = base + sin(t * pi / 0.8) * 0.87
  (enraged: a mirrored second beam); in-field =
  dist < 16 and |angle diff| < 0.61; drowsy builds
  +0.2 per 0.25 s in-field (decay 0.35/s, "z"
  floaters); at 1.0 the player sleeps 1.6 s and
  hypno dream-eats: teleport to the player's side,
  strike 1.4 at +0.8 s, heal 4% max HP if the strike
  actually dropped the player's HP.
- Cloyster (91): the close snap now also applies
  bound 1.0 s (unconditional inside radius + 2.2 at
  low 1.6, the bundle's order: strike, then bind);
  initial phase 3.0 (was 4.5); the volley ring's
  base angle is the volley index x 0.11 (was
  random). Open/closed durations and hitMuls were
  already correct.

Supporting system — player status (new,
player.gd): pstat, a dict of parallel status
timers (sleep / frozen / bound) with the bundle's
inflict rules (@831004): frozen is refused vs an
ice-typed player (with floater), sleep is halved
vs a psychic-typed player, a new application only
replaces a shorter remaining time; sleep/frozen/
bound block movement input, dash and jump;
sleep/frozen block firing (cooldowns still run).
arena_slip (0..1) decays at 1.2/s and flattens the
ground-velocity response by (1 - 0.8 x slip).

### 3. Ditto (queue item 6, DONE)
Populate: the bundle places ditto as a utility prop
(JC dex 132, spacing 150, LC weight 2), count 1 in
stage play (2 in endless — the port's shared plan
uses 1; the endless count is recorded as an open
deviation, endless sharing the stage plan). No
independent Ditto enemy-transform encounter was found in
this pass's encounter dispatches (C23B2 F7 qualification).
Search: full main chunk ditto/imposter/transform/Transformación/
132; inspected JC mapping, populate/label/interact -> openDitto
-> showDitto, enemies.spawn, event spawner and boss kit/mech
routing. Ditto prop cloning and imposter are distinct from
Ditto's player ultimate (132 @590343); Mew's combat transform
also exists (eb kit @896506, transform @901827). This is a
bounded search result, not a bundle-wide absence of combat
transformation. Reproduction details: design/c23-changes.md B2. Port: PROP_PLAN gains
["ditto", 1, 2.6, 2]; the body is a primitive glossy
purple blob on a #c88aff ring (no ditto GLB exists;
the snorlax/porygon primitive precedent). Interact:
with an empty inventory it refuses and is NOT
consumed (bundle @1251293); otherwise the clone
picker opens (cry on open and on a successful
pick). Deviation: the port's choice cards have no
disabled state, so a maxed item still gets a card;
picking it denies and reopens the picker — the
player-visible outcome matches the bundle's dimmed
"Max." card (@2051392).
Imposter (abilities.json already carried the stat
side): PTICK_EVERY gains imposter: 30.0; the tick
copies the CURRENT types of the nearest enemy
within 25 (bundle @711560) into the new
player.types_override (cleared on setup/evolve);
player.types() is the single read path and now
feeds the passive tick's type read, the slam type
read and the item-roll type weighting. Recorded
limit: the port's enemy->player damage is
type-neutral by design, so the copy drives the
offensive/STAB-type channels only.

### 4. Golden-meowth event (queue item 6, DONE)
The fourth stage event (sx class @1034682; spawn/
update @1040859): kinds fog/storm/eclipse/meowth,
weights meowth 0.8 vs 1.0, once per kind per run,
duration 25 s, no weather look. The golden meowth
is a Treasure body: HP x9 (@325834), speed 7.4,
dmg x1, gold ring marker (the gold sprite grade
@339684 is approximated by a gold torus). It flees
with the bundle's steering (away + perpendicular
sin sway, tangential beyond 18, @332566). onHit
(@727019, wired at the end of Enemy.take_damage,
killing blows included): every 0.16 s a landed hit
shakes loose ceil((2 + zone x 2) x gold_mult)
coins. onKilled: a 30-coin fountain of
ceil((4 + zone x 4) x gold_mult) each + the Pay
Day banner. Timeout: it escapes (nova + removal,
no rewards). Adaptation, standing since cycle 9:
coins credit gold DIRECTLY (this build has no coin
entities; the guardian reward does the same).
event_marker_pos() exposes the treasure to the
maps (gold dot + white arc on minimap and big map).

### 5. Fog blinding + event spawn internals
### (queue item 6, DONE)
sx.blind = kind == fog && k > .5 (@1034963), where
k is the event envelope (ramps +delta/3 while
active). Consumed at the big-map draw (@2031938):
fog fill rgba(70,60,100,0.85) + ONLY the player
dot; world pins hide (@2035971). Port: world gains
the _event_k envelope + event_blind(); minimap.gd
and big_map.gd draw the blind branch (same fill,
player dot only; the minimap keeps its cardinal
letters). NOT ported (UI-line note): the big map's
side list treatment under blind — layout territory.
Event spawn internals upgraded to the bundle's
updateSpawns: batches of 3 + zone every 4 s from
the 20-27 ring, cap 30 event spawns, stops when
left < 6; fog spawns carry xp_mult = 2 (new Enemy
field, applied in _award_kill); eclipse's
first-of-batch after 90 s is a flag-1 elite at
dmg x1.4 / max HP x4.5. Not ported: the fog pool's
Flying flag (no counterpart system; the pool
species already hover visually except drowzee) and
the eclipse elite's post-hoc rig scale. Event-end
floaters added (fog/storm/eclipse).

### 6. Serpent-glare fixture pinning (queue item 3,
### DONE — harness only)
_c212_glare_wait now pins like the wet/props
fixtures: anchors (player + subject positions) are
captured at entry; every frame after physics_frame
the subject is re-pinned at its anchor with _kb_vel
zeroed, the player re-pinned with _vel zeroed
(facing source kept on the rig), and _spawn_t is
held at 5.0. The GLAREDBG instrumentation is
untouched — it still recomputes the game's cone
every frame, so an in-cone miss would still be
caught. C23B2 F2 proof, first reproduced group:
Test/out/c23b2_glare_{1,2,3,4}.log = 69/1, 69/0, 69/3, 69/0.
Runs 1/2/4: 390/390 in-cone frames, 2/2 in-cone ticks,
final paralyze. Run 3 first landed paralyze, then facing
turned away at frame 199 and the final status expired;
199/390 in-cone frames, 1/1 ticks. Other reds were the
previously recorded tentacles/static fixture family. Logs
were pulled and size-verified (4 files, 87,824 bytes).
B2 therefore also pins the lab passive across recalc and
the entry rig yaw; the game's cone/tick/status code and
final paralyze assertion stay unchanged. The corrected
full-suite glare window is 390/390, 2/2, final paralyze.
The separate corrected x4 proof is recorded in the B2
construction log once its detached batch ends.

### Game-code changes (this cycle)
- scripts/world.gd: _chest_cost luck clamp;
  BOSS_MECH(_NAMES) gengar removal + _boss_reset
  list; starmie cast (true path + occupancy return)
  and tick (path run); dewgong cast chain + tick
  (trails, bursts); lapras cast (object pillars),
  _boss_lapras_pillar / _kill_pillar / _pump
  (block) / _surf + tick (lifetimes, wave shatter);
  hypno tick (pendulum field, drowsy) +
  _boss_hypno_dream_eat; cloyster tick (bind,
  phase 3.0, volley base angle); _seg_dist +
  _telegraph_line helpers; ditto prop (plan, body,
  label, interact, _open_ditto); imposter tick
  case + PTICK_EVERY entry + types() routing;
  stage events: EVENT_DEFS meowth, _event_k
  envelope, event_blind(), _event_spawn_meowth,
  event_hit, treasure kill/escape in the event
  tick, event_marker_pos(), bundle spawn batches
  (fog xp x2, eclipse elite), end floaters.
- scripts/player.gd: pstat status system (inflict
  with the bundle's immunity/halving/longer-only
  rules, move/act blocks in _physics_process and
  _try_fire), arena_slip, types_override +
  types().
- scripts/enemy.gd: is_object flag (AI/contact
  gates), treasure steering in _hostile_process,
  event_hit hook at the end of take_damage,
  xp_mult field.
- scripts/minimap.gd / scripts/big_map.gd: fog
  blind branch + golden-meowth treasure markers
  (draw branches only; no layout changes).

### Harness changes (Test/harness.gd only)
- New c22 phase (51 checks) registered in the
  runner and the --only list: N6 prices, ditto
  populate/interact/maxed-deny/imposter, the
  gengar/marowak stage-truth assertions, starmie
  path geometry + dizzy, dewgong trail slip +
  burst freeze, lapras pillars/blocked vs
  unblocked pump, hypno drowsy -> sleep ->
  dream-eat, cloyster bind, golden meowth (spawn
  stats, flee, coin drip + cooldown, fountain,
  escape), fog blind envelope, fog batch size/xp/
  cap. Boss blocks force mechs on a real summoned
  guardian (the c21 seam) and quiet the brain via
  _boss_t where a cast must not be interrupted.
- _c212_glare_wait: fixture pinning (item 6 above).
- One check-side correction during the cycle: the
  meowth fountain expectation now includes the
  standard kill drip (0.2 x gold_mult, _award_kill)
  the bundle pays on every kill — the fountain
  figure itself was exact.
- The c21 phase's event fixture named its done list
  ["fog", "storm"]; with the fourth kind added, its
  unique-remainder premise broke (the scheduler now
  legitimately picks between eclipse and meowth).
  The fixture now names meowth done as well; the
  scheduler assertions are unchanged. Same family:
  the props phase census (51 props / 14 kinds)
  predates ditto and now reads 52 / 15.
- Two c21 passive-lab blocks (tentacles, static)
  flaked in the first two pre-fix glare-proof runs
  and were reported green at the C22 close. B2 re-observed
  this family (see section 6); this is not an all-runs-green
  claim. The C22 report recorded 0 script errors
  throughout; in those same red runs the arena, glare,
  intimidate and beacon ticks all landed, and the
  tentacles window showed 2 ambient enemies inside
  the whip's 7 u — the fixture's known ambient-
  absorption family, cf. the 21.1 static note. The
  blocks carry C21DBG/C22DBG prints for pid /
  pending_levels / _ptick_next now. No game-code
  fault was found; recorded as fixture pacing, not
  a regression.

### Still queued after C22
- Queue item 2: boss-kit reachability (models +
  summon-path decision) — reframed by item 2 above
  for gengar/marowak (tower-gated regardless).
- Queue item 5: run-tier ladder tiers 1-2 + Db/Ob
  impatience re-mining.
- A tower game mode (the gb classes are mined and
  recorded in item 2 above).
- Ditto endless count 2 (deviation, item 3 above).
- EN item names (unrecovered from the bundle).
- Fog: big-map side list under blind (UI line);
  fog Flying flag; eclipse elite rig scale.
