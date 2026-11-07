# SpriteBonk 3D — Milestone 2 (parity) + Android / wallet / dApp Store phases

> **Phase status lives in `PHASES.md`**: A parity (DIFF.md) · B Android —
> signed release APK at `build/android/SpriteBonk.apk`
> (com.spritebonk.game, reproducible via `android/build_apk.sh`) ·
> C wallet — guest default + read-only address connect with live SOL
> balance (`scripts/wallet.gd`) · D dApp Store — package drafted in
> `store/` up to the publisher-wallet step.

3D remake of SpriteBonk, reverse-compared against the original PokéBonk until
each dimension matched or was named a residual — full evidence table in
**`DIFF.md`**. Structure follows the original: roam a 360×360 forest →
activate the **Boss altar** → a guardian (zone-1 trio: Scyther / Pinsir /
Nidoking, one at random + the other two as escorts) → kill it → **portal** →
**Stage Clear**, inside a 600 s zone countdown (Final Swarm at zero).

The live 2D version (`~/workspace/sprite-bonk-godot/`) is untouched; this is a
separate local project. Nothing is deployed. No web export this round.

## Run it

```bash
GODOT=~/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64
$GODOT --path ~/workspace/sprite-bonk-3d            # menu → pick a starter
$GODOT --headless --path ~/workspace/sprite-bonk-3d --import   # first-time import
```

**Controls:** WASD move (camera-relative) · attacks are automatic · **Shift**
dash · **Space** jump · hold mouse-drag to orbit camera, wheel to zoom ·
walk to the altar in the north and press **E** to summon the guardian ·
walk into the purple portal to clear the stage.

## What milestone 2 aligned (evidence in DIFF.md)

- **Camera = the original's formula**: FOV 70 (+ speed kick), pitch 0.45 rad,
  distance 9, focus +1.5y, lookAt +1.8y, terrain clearance, mouse orbit/zoom.
- **World**: 360×360 heightfield with terraced plateaus and cliffs, invisible
  ±168 play clamp, fog #bfe3ff 40–160, exact sky gradient, sun #fff1d6 from
  (60,120,40), fog-exempt mountain silhouettes, ~470 props. Ground colors
  calibrated by sampling against the original's frames (median #388347 vs
  #389243/#40a03d).
- **Numbers from the original's own data** (runtime-captured
  `pokebonk.com/data/*.json`, saved in `reference/data/`): starter HP/armor/
  regen/speed multipliers, enemy stat formulas with base stats verified 1:1,
  spawn ring 24–36 and the on-screen cap curve, Vine Whip 24.8/0.8 s/3.3 m.
- **HUD replica**: portrait medallion + starter panel, in-world HP pill with
  number at the player's feet (#44d878), zone card + countdown pill + tenths
  elapsed + CALM segments + counter pill, circular minimap, bottom-left
  item/move/lock/ult cluster, enemy bars only after damage.
- **Geodude defect fixed**: its texture was never missing — the bind-pose
  T-span + light blowout were. Skeleton arm-pose override + height fit +
  albedo tint; same stance fix for the guardian trio.

## Models — sources & status

Repo: **Sudhanshu-Ambastha/Pokemon-3D-api** (GitHub), raw models at
`https://raw.githubusercontent.com/Sudhanshu-Ambastha/Pokemon-3D-api/main/models/glb/regular/<dex>.glb`;
Bulbasaur uses the decoded "opt" build (see `tools/decode/`).

| Species | Role | Animation |
|---|---|---|
| Bulbasaur 妙蛙种子 (starter) | Vine Whip melee arc | ✅ real clips: idle/walk/run/fight/jump/ko |
| Charmander 小火龙 (starter) | Ember projectile | ❌ no clips in source → procedural |
| Squirtle 杰尼龟 (starter) | Water Gun projectile | ❌ procedural |
| Rattata / Pidgey / Sandshrew / Geodude | wild spawns | ❌ procedural (Geodude stance posed via skeleton) |
| Scyther / Pinsir / Nidoking | zone-1 guardian trio (1 guardian + 2 escorts) | ❌ procedural (stances posed via skeleton) |
| Snorlax 卡比兽 | regular heavy species (not a zone-1 guardian) | ❌ static mesh in source |

Per-species heights/facing/pose/fit live in `scripts/model_rig.gd` (`SPECIES`).

## Layout

```
project.godot            Godot 4.3, GL Compatibility
scenes/main.tscn         root = World (scripts/world.gd builds everything in code)
scripts/world.gd         terrain/sky/fog, props, altar/portal, camera formula, spawner, projectiles/slash, HUD, stage state machine, debug_* hooks
scripts/player.gd        per-starter stats (original's formulas), terrain movement, jump/dash, melee/projectile auto-attack, foot HP pill
scripts/enemy.gd         original stat formulas (BASE table verified vs pokemon.json), chase + separation, timed attacks
scripts/model_rig.gd     model fit/grounding, skeleton pose overrides, tints, clip playback or procedural motion
scripts/hp_bar.gd        original-style pill bars (player number bar / enemy on-damage / wide guardian bar)
scripts/minimap.gd       circular minimap (disc, ring, cardinals, objective/enemy dots)
assets/models/*.glb      11 species (+ extracted texture PNGs)
assets/NotoSC-subset.ttf CJK font for HUD
reference/               original's screenshots (orig_*.png) + runtime-captured data JSON (data/)
screenshots/             verification renders + vs_*.png side-by-side composites
DIFF.md                  the parity table (MATCHED / RESIDUAL per dimension)
```

## Verification (native, Xvfb + opengl3)

A temporary `Test/` harness (deleted after use) drove the real flow via
`world.debug_*` hooks, zero script errors:
`screenshots/game_a_spawn.png` (spawn framing), `game_b_combat.png` (mixed
pack), `game_c_altar.png`, `game_d_guardian.png` (trio fight),
`game_e_portal.png` → Stage Clear. Composites: `vs_gameplay.png`,
`vs_combat.png`, `vs_guardian.png` (original side of the guardian pair is the
region-select screen — a live guardian frame is unobtainable: the site runs
at ~0.03× clock under SwiftShader).

## Known gaps (details in DIFF.md)

- Only Bulbasaur has authored animation clips; other species use a
  procedural **skeletal gait** (cycle 4, model_rig.gd) — no attack/hurt/
  faint cycles.
- Terrain has hand-placed terrace features + near-camera dressing
  (cycle 4) but still reads less authored than the original's forest.
- PMD-sprite look vs 3D models is a deliberate direction difference; minimap
  is schematic (not a terrain render); no weather, blessing altars, capture
  system, XP/evolution, Lab, or zones 2–4 yet.
