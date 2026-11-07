# PHASES — SpriteBonk: parity → Android → wallet → dApp Store

Mission chain (user, 2026-10-25 04:13): 1:1 parity, then Android app,
wallet connect, Solana dApp Store listing — no stopping between phases.
Parity ledger = `DIFF.md`. This file tracks phases B–D.

## Phase A — 1:1 parity vs PokéBonk
**Status: done to the DIFF.md standard; cycle 4 improvements landed this run.**
- Cycle 4 (this run, opus path shelved → ⚑ items ground locally):
  - ⚑ #1 animation: procedural **skeletal gait** implemented in
    `model_rig.gd` — the clip-less GLBs' skeletons share bone names
    (…LThigh/LLeg/LFoot, …LArm/LForeArm, Tail1–4); legs swing anti-phase
    around local X, shins bend with lag, feet counter-rotate, arms swing
    opposite the same-side leg, tails wag at idle. Stance-held bones
    (Geodude/guardian arms) are skipped. Verified: 0 script errors;
    `screenshots/gait_a.png` vs `gait_b.png` (0.45 s apart) differ by
    ~35k pixels in the actor region; combat frame shows limbs mid-stride.
    Still RESIDUAL vs the original's authored PMD animation (no attack /
    hurt / faint cycles) — but no longer root-bob only.
  - ⚑ #2 terrain: 11 hand-placed **terrace features** in `world.gd`
    (`_terraces`: lifted, fully band-snapped cliff clusters flanking the
    spawn→altar corridor and around the map; spawn/altar flattening still
    wins inside the clearings) + a **near-camera dressing pass** (+70
    tufts, +26 flower clusters within ~55u of spawn / the corridor).
    Ground median unchanged (#388347 vs orig #389243/#40a03d). Still
    RESIDUAL vs the original's authored Viridian Forest, gap narrowed.
- Remaining residuals (unchanged, in DIFF.md): PMD sprites vs 3D models
  (deliberate), minimap schematic, post chain, weather, blessing altars,
  camera shake, slide/dive/glide, learnset gating, inferred Ember/Water
  Gun damage, non-player species heights INFERRED.
- Cycle 5 (visual fidelity, user: "画面效果还是差很多，继续对齐"; full
  evidence log in DIFF.md): character exposure defect fixed at the
  material layer (albedo ×0.52 + hue tints; Bulbasaur bulb #dfffff →
  #85b65d, body #7df6da → #90cc7c, into the sprite's family); PMD-style
  outline added (scale-hull — grow_amount and custom-shader routes
  probe-rejected on skinned meshes in this build; rim measured 5 px);
  post chain completed (grade + vignette + existing glow); ground
  richness (tileable tuft/sparkle detail texture + worn patches +
  900-instance MultiMesh tufts); +12 terraces (23 total); minimap is
  now a baked terrain render. Honest residuals: grass median #498c47
  vs #389243; outline thickness uneven; bloom curve/vignette strength
  approximate; Geodude still pale. APK rebuilt after the cycle.

## Phase B — Android build
**Status: DONE (signed release APK produced and structurally verified).**
- **Touch controls (2026-10-25, user on Seeker: "现在无法控制角色移动" —
  the shipped controls were keyboard-only).** `scripts/touch_controls.gd`:
  left analog joystick above the bottom-left slot cluster + right button
  cluster （互动 E / 跳跃 空格 / 冲刺 Shift), semi-transparent thumb-sized
  circles; feeds the player through the SAME logical inputs as the
  keyboard (world.get_touch_move / is_touch_jump / is_touch_dash /
  consume_touch_interact; player.gd reads both, joystick magnitude
  preserved via limit_length). Attack stays automatic. Visible only in
  play states and only on touch devices (OS Android / touchscreen /
  first real touch / harness latch); UI stays tappable (menu state hides
  them). Verified in the native harness with REAL synthesized
  InputEventScreenTouch/Drag events: joystick drove the player +2.77u in
  pure +X, dash peaked 15.9 u/s, jump apex 1.61u, interact summoned the
  guardian, 0 script errors (frames screenshots/touch_0..2_*.png).
  Two bugs found by the harness en route: (1) a new script class isn't
  resolvable headless until imported — touch_controls is preloaded, not
  class_name-referenced; (2) **_gui_input event positions are already
  control-local** — transforming them again read the stick as full-up.
  APK rebuilt: 28,888,590 B, same cert, touch_controls.gdc inside,
  zero reference/orig_assets files inside (that folder now carries a
  .gdignore so exports don't reimport the ~2,000 captured files).
- Toolchain installed under `~/workspace/tools/` (durable): JDK 17
  (apt), Android SDK at `~/workspace/tools/android-sdk` (cmdline-tools +
  platform-tools 37.0.1 + platforms/android-34 + build-tools 34.0.0,
  laid out manually from the official repository zips — sdkmanager
  itself cannot tunnel through this VM's egress proxy from Java).
- Godot editor settings now point at that SDK/JDK
  (`export/android/android_sdk_path`, `export/android/java_sdk_path`).
- **Gotcha (cost an hour):** Android export validation fails SILENTLY
  ("configuration errors:" with an empty list) unless the project sets
  `rendering/textures/vram_compression/import_etc2_astc=true`
  (Godot 4.3 source: `has_valid_project_configuration` hard-fails on it
  without appending an error string). Set in `project.godot`.
- Preset: `export_presets.cfg` — package **com.spritebonk.game**
  (neutral name; no business domain), label SpriteBonk, versionCode 1 /
  versionName 1.0.0, arm64-v8a only, permissions INTERNET +
  ACCESS_NETWORK_STATE (wallet RPC), landscape, excludes
  Test/store/reference/screenshots/tools/android/build from the PCK.
- Signing: local keystore `android/spritebonk.keystore` (alias
  `spritebonk`); credentials recorded ONLY in
  `android/keystore_credentials.txt` (chmod 600, project-local — not in
  chat/memory). Godot exports unsigned (its own signing step is skipped
  by design); `android/build_apk.sh` reproduces the whole flow:
  export → zipalign → apksigner sign → verify.
- Artifact: `build/android/SpriteBonk.apk` (28.9 MB).
  Verified with build-tools 34.0.0:
  - `apksigner verify --print-certs`: Signer DN `CN=SpriteBonk, OU=Game,
    O=SpriteBonk, …`, cert SHA-256
    `b05b80e128a7ff997282b1b80c1973e347ced316b6eb632670a6cbc64350a232`
  - `zipalign -c`: OK
  - `aapt2 dump badging`: package com.spritebonk.game, versionCode 1,
    versionName 1.0.0, minSdk 21, targetSdk 34, label SpriteBonk,
    launchable activity com.godot.game.GodotApp, permissions
    INTERNET + ACCESS_NETWORK_STATE
  - Contents: arm64 libgodot_android.so + the game's imported assets;
    zero Test/store/reference/screenshots files inside.
  - Boot check: no Android device/emulator on this VM, so on-device boot
    is unverified here; the APK embeds the same project build that runs
    natively (harness-verified) and the standard Godot runtime activity.
    First on-device check should happen on the user's Seeker.

## Phase C — Wallet integration (connect/read only)
**Status: DONE at the adapter layer described below; native MWA authorize
is the one documented gap.**
- Research (2026-10-25): the maintained plugin is
  **Virus-Axel/godot-solana-sdk** (GDExtension; RPC, token program, wallet
  adapter for Phantom/Solflare/Backpack — web/desktop oriented). Its
  Android **Mobile Wallet Adapter** support is still in-progress upstream
  (feature branches adding MWA actions), and community reports (Godot
  forum, Feb 2026) show the older godot-solana-client MWA flow freezing
  on a Seeker after wallet selection. Shipping that into the release now
  would put an unproven native dependency in the critical path.
- Implemented instead (`scripts/wallet.gd`, `WalletManager`), with the
  authorize step isolated so the MWA implementation drops into exactly
  one function later:
  - **Guest mode is the default** — menu shows 游客模式， game fully
    playable with no wallet.
  - Menu wallet panel （连接钱包 button): paste a Solana address →
    validated in GDScript (base58 charset + full 32-byte decode length;
    unit-checked against System Program / Token Program / wSOL mints =
    valid; short strings / non-base58 = rejected) → address saved to
    `user://wallet.cfg`, menu shows short address + **SOL balance read
    live via public JSON-RPC `getBalance`** (mainnet-beta default,
    devnet switchable in the config file).
  - `request_authorize()` returns `ERR_MWA_UNAVAILABLE` with the reason —
    the documented seam for the godot-solana-sdk MWA authorize.
  - **No transactions, no signing, no keys anywhere.** Address entry is
    watch-only by construction.
  - Token hooks from the tokenomics doc are clean stubs:
    `fetch_sprt_balance()` → -1 (SPRT_MINT unset; $SPRT not issued),
    `has_genesis_nft()` → false (collection not minted).
- UI proof: `screenshots/menu_wallet.png` (panel open, guest state);
  logic proof in the harness log (guest_default=true, 3 valid + 2
  invalid address cases correct, 0 script errors).

## Phase D — dApp Store release package
**Status: prepared up to the publisher-wallet step (the designated stop).**
- **Mainline plan (2026-10-25, user order): `STORE_MAINLINE.md`** — gap audit vs current docs.solanamobile.com + milestone schedule for this phase.
- `store/config.yaml` — dapp-store CLI config draft: publisher/app/
  release sections, `android_package: com.spritebonk.game`, release
  files → the signed APK, 4 screenshots, catalog copy in **en-US and
  zh-CN** (name, short/long description, new_in_version), portal testing
  instructions (guest play + optional read-only wallet connect).
- `store/media/icon-512.png` + `publisher-icon-512.png` (512×512 draft
  from in-game art), `store/screenshots/01..04_*.png` (1280×720).
- Remaining before `dapp-store validate` can run for real:
  1. **User supplies a dedicated publisher wallet** (keypair file) —
     never their main/trading wallet — funded with a small amount of
     SOL for the publisher/app/release NFT mint fees (docs: "fund your
     account with some SOL to mint the necessary NFTs"; devnet can be
     used for a dry run first).
  2. Publisher contact email + website, and a hosted privacy-policy URL
     (fields left blank in config.yaml, marked TODO_PUBLISHER).
  3. Confirm screenshot orientation requirements at validate time
     (current set is landscape 1280×720, matching the game).
- Commands staged in the config.yaml header (validate → create
  publisher → create app → create release → publish submit). **Nothing
  has been minted, submitted, or paid.** No wallet was created or funded
  by the agent.

## Cycle 6 addendum — original assets + set dressing (2026-10-25)
- Original's runtime assets acquired into `reference/orig_assets/`
  (971 PMD sheets + 971 portraits, 5 biome env sets, runtime JSON
  tables; snow/beach 404 = named gap; INVENTORY.md). Characters stay
  GLB per user ruling; assets serve as the environment's art bible
  and the mechanics source of truth.
- Zone 1 dressed to measured density (~13–15 set pieces/frame vs the
  original's ~11–13), in-playfield strata bluffs with the original's
  cliff tile, bare-earth pads; terrain base = the original's own
  ground/path/cliff tiles.
- Grass median closed: #3b9745 vs orig #389243 (Δ ≤ +5/channel,
  both gameplay frames). Root causes logged in DIFF.md cycle 6
  (missing .import files, pow double-decode, default SPECULAR sheen).
- APK rebuilt with cycle-6 visuals + touch controls; details in
  DIFF.md "Cycle 6" and §2 rows (Ground color ✅ MATCHED).

## Game-feel pass (2026-10-25, user feedback "操作手感比较差")

- Mined the original's movement model from the bundle and
  implemented it verbatim: exponential velocity approach
  (accel ≈0.573/frame, stop ≈0.327/frame at E=8.16), Quake-style
  air control (cap 1.7E), gravity 30, jump vy 11, Shift = slide
  (1.9E, 0.55 s, exp decay) on ground / dive (−34) in air,
  facing snaps to velocity, stick magnitude normalized away —
  all cited in DIFF.md "Game feel".
- Camera: original Ic() exponential damp (target 18 XZ / 10 Y),
  FOV speed-kick now damped at rate 6, terrain lift 22 up / 5 down.
- Touch UI v2: floating joystick (0.15 deadzone + radial
  rescale, 65 px travel, press states), larger buttons with
  press feedback.
- Rendering/perf choices for the Seeker: physics interpolation
  on (with resets at teleports/spawns), shadow maps 2048/1024,
  MSAA off, dressing visibility-range culling at 100 u, hulls +
  tufts shadowless. Headless harness: 14/14 feel checks PASS,
  0 errors (frame budget is a llvmpipe proxy, labeled as such).

## Cycle 7 — systems parity from the real data (2026-10-25)

- Data layer (GameData/Profile): all species stats, moves,
  learnsets and the type chart are read from the original's own
  JSON tables (assets/data/); player stats follow the §2.2
  derivation and reproduce the League-screen anchors exactly.
- XP draft per §2.3 (3 picks, kit/learnset/upgrade/vitamin pool,
  rarity pe ladder, reroll 2 / skip 2 / banish 1, evolution levels
  from the §1.2 formula — 24→41 / 24→44 — with the original's
  heal rule); both capture systems per §5.2/§5.3 replacing the
  hybrid (league roster persists; friend-ball allies at the §5.3
  power formula, team cap 2 + Lab).
- Zones 2–4 playable end-to-end (graveyard/desert/volcano on the
  original's tiles, per-zone palettes/fog/dressing, guardian DPS
  budgets, portal chain to the victory state); zone ground gains
  fixed from hue-erasing ratios to hue-preserving scalars.
- Lab: all 24 upgrades purchasable with stardust (19 effects
  wired, 5 stored inert), run-end gold→stardust settlement per
  §6.1, profile persisted at user://profile.json.
- 24 new GLB species imported; three rig defects found by A/B
  probes and fixed (hull over open/transparent surfaces —
  Venusaur flower, Gastly gas; gait discarding bone rest poses —
  Graveler legs). Harness: 41/41 checks PASS, 0 script errors.
  Full detail + residuals in DIFF.md "Cycle 7".

## Cycle 8 — combat life & meta layers (2026-10-25)

- Combat animation cycles on the procedural rig: hurt flinch
  (0.22 s push/tilt/squash from real damage events), faint
  collapse (0.7 s ease-out tip/sink; Bulbasaur "ko" clip when
  present), corpse linger 0.8 s before free. Sequenced close-up
  screenshots in screenshots/c8_anim_*.png.
- Feel residuals closed: camera trauma shake ported verbatim
  from the bundle (caps 0.22/0.7, decay 2/s, trauma²·0.3 at
  26 Hz; wired hurt 0.12 / boss 0.8 / evolution 0.6 / slam) and
  the dive slam (o = fallH/8, r = (3.2+3.3o)√area, dmg
  (12+1.5·Lv)·stageMult·(1+2o), cd 2 s, stun 0.35+0.4o).
  Knockback/hitstop not ported (no channels).
- Ally lifecycle: evidence inverted the brief's premise — the
  original's allies have NO hp and cannot die (jh.make() has no
  hp field), so "unkillable" already matched; the real gaps were
  bond (kills → thresholds [25,75,150,300,500] → +10%/level)
  and green minimap dots (#7aff9a), both now in.
- League challenge layer (§3): lifetime counters in the profile
  (add/max modes), verbatim challenge goals for all 15 modelled
  species from the bundle roster, encounters gated on
  leagueReady, unlocks screen, captured species become playable
  starters. Unsupported-counter parts (rocks/reactions/berries)
  render but never complete, honestly gating 5 species. Also
  fixed: §5.2 sure-capture clause (chance ≥ 1) and guardians
  silently awarding no XP/gold (cycle-7 fix overshoot).
- Zone dressing: zones 2–4 have their own prop mixes
  (tombstones/dead trees/bones; cacti/sandstone; obsidian/lava/
  char) instead of the shared "common" set.
- Harness: 53/53 checks PASS, 0 script errors. APK rebuilt
  48,164,890 bytes, audit clean (0 reference/, 0 Test/).
  Full detail + residuals in DIFF.md "Cycle 8".

## Hotfix (2026-10-25, post-cycle 8): player Charmander size/color
- Root cause: fit scaled from the bind-pose node AABB; Charmander's
  authored 2.54x node scale made the fit believe 5.206 u vs a 1.59 u
  render -> 0.2497x player (user screenshot 18:01). All 35 species
  re-measured empirically (rendered silhouettes) into native/feet
  table entries; Bulbasaur's hand native also corrected 0.7 -> 0.833;
  Charmander hue tint added (rendered body now (177,102,68) orange).
- Standing per-starter PLAYER check lives in Test/ permanently
  (harness + check_starters.sh): 3/3 PASS. Geodude-line "flopped
  body" = faint collapse pose, numeric match to the design curve.
- APK rebuilt: 48,168,986 bytes, same cert (b05b80e1...a232);
  contents audit: 438 entries, 0 Test/, 0 reference/.

## Cycle 9 — independent-audit fixes + Segment Z (2026-10-25)

Work order from the cycle-8 independent audit (2 VERIFIED /
5 OVERSTATED / 1 UNVERIFIABLE + 15 gaps). Full write-back in
DIFF.md "Cycle 9".

- P0 revive regression FIXED: ModelRig.revive_reset() clears
  the latched faint/flash/squash/lunge state; proven by the
  permanent cycle9 harness (die -> real Lab revive -> stand ->
  touch-joystick move 18.6 u -> hit lands with flash + 0.45 s
  iframes + damageFlash). 8/8 revive checks.
- P1.1 slam through world.combat_hit (the bundle's strike()
  order, STAB x1.25 incl.): dealt 50.8733 vs expected
  50.8733 (Lv1, 8 m fall); real key/button dive fires it.
- P1.2 league: GLOBAL encounter pool (bundle leagueReady);
  roster.json (79 families) + abilities.json (161 passives)
  extracted from the bundle and wired (kits, passive mods +
  hooks); 19 new species modelled with probe-measured fits
  (ekans parked: vertical-pole GLB, named blocker) ->
  completable families 31 >= 30, goals 20/25/30 reachable.
  Encounter proof: growlithe/charmander/doduo/pidgey/magikarp
  drawn in zone 1.
- P1.3 guardian rewards per bundle: 20 x ceil(5*stage*gold)
  coins (harness delta exactly 100), free chest + 1 per roar,
  candy level, boss hitstop 0.5; sourceless formula deleted.
- P2 residuals: hitstop/camera-kick(chroma)/damageFlash/
  dodge floater + iframes, settings-gated shake, ally LIVE
  power + typed AoE (exact-value checks), minimap ally
  r=6 + stroke + chest markers, per-biome dressing incl. the
  base-scatter fix (110 forest trees no longer spawn in zones
  2-4), corpse pause freeze, hurt/death timings restored.
- Found & fixed along the way: yaw table wrong for 5 species
  (charmander line walked backward, rattata line sideways —
  all GLBs face +Z natively); crits never counted; lifetime
  status counters never flushed; evolve-into-unmodelled
  crash; critDamage add-arm dropped sniper/hyper-cutter.
- Segment Z (user: "动作比较僵硬"): phase-locked stride
  (foot-skate killed by construction), 2x-frequency bob,
  spring-damper tails/head, idle breathing + head turns,
  gait archetypes (quad/biped/hopper/hover/serpent), step +
  landing squash, lunge anticipation/overshoot. Strips:
  Test/out/strip_*_montage.png. Honest gap logged in DIFF
  (no foot IK; T-pose binds stay stiff between swings).
- Process: harness permanent in Test/, mutation spot-checks
  red-verified (STAB / revive reset / league pool), bundle
  citations at real byte offsets. Final harness: 28/28 PASS
  (Test/out/c9_final.log); check_starters 3/3.
- APK rebuilt: build/android/SpriteBonk.apk 53,443,778 bytes
  (was 48,168,986; +19 species GLBs), signed with the project
  keystore (cert SHA-256 b05b80e1...a232, unchanged), package
  com.spritebonk.game v1.0.0 targetSdk 34. Contents audit:
  573 entries, 0 Test/, 0 reference/, 54 species models +
  roster.json + abilities.json packed. build_apk.sh now puts
  the workspace JDK on PATH for apksigner (system JDK is gone
  since the VM replacement).

## Hotfix — blue-screen APK (2026-10-25, post-Cycle 9)

- The Cycle 9 APK booted to the pure clear color on device.
  Root cause: Cycle 9 backup scripts left in Test/out/zbak/
  kept their `class_name` declarations and poisoned the global
  script class cache (ModelRig/Player -> Test/out/zbak paths);
  exports exclude Test/*, so world.gd failed to parse in the
  package and the main scene booted scriptless. Editor/harness
  never saw it — the backups exist on disk there. Full evidence
  chain (incl. a desktop Linux export reproducing the exact
  device frame pre-fix and rendering the full game post-fix)
  in DIFF.md "Hotfix — blue-screen APK".
- Fixes: zbak scripts defanged to .gd.bak, class cache
  regenerated clean (8/8 -> scripts/), new export gate
  Test/check_class_cache.sh wired into android/build_apk.sh,
  Profile loading hardened (version stamp + per-key type
  coercion).
- Re-verified end to end: cycle9 harness 28/28 against the true
  scripts, seeded old-schema profile boot clean, Linux export
  smoke green. New APK 53,443,778 bytes (same byte count as the broken build by coincidence — fingerprint sha256 c4e3a240…a5b150), same signing cert,
  baked class cache verified clean inside the package.

## Cycle 10 — HP-bar alignment (2026-10-25)

- User on the fixed build: HP bars overlap the characters in
  horde fights. Bundle spec (DIFF.md "Cycle 10", offsets
  verified): the original has NO world-space HP bars — the
  sprite shader/instancing carries no HP channel; regular
  enemies read via damage numbers + hit flash. Player HP is
  the HUD plate's .bar.hpbar (lag hold 0.4 s / drain 0.9);
  bosses get the HUD .bossbar (hold 0.45 s / drain 0.6/s,
  numeric HP, segment ticks only for phase-kit bosses) plus
  up to 2 mini bars for minibosses (no such system in our
  game — skipped).
- Changes: world-space HpBar deleted from enemies, guardian
  and player (scripts/hp_bar.gd removed); HUD player HP bar
  added under the top-left plate; HUD guardian boss bar added
  top-center (name + 守护者/传说守护者 tag + lag ghost + HP
  number, visible only while the guardian lives).
- Evidence: Test/barshot.tscn before/after pairs
  (horde_before/after, boss_before/after in Test/out/);
  cycle9 suite 28/28, check_starters 3/3 (charmander color
  floor recalibrated — the old floor was fit to samples
  contaminated by the removed bar; bar-free probe median
  identical before/after, model provably unchanged); class
  cache gate OK (7 classes); Linux export boots the shipped
  artifact clean. New APK 53,439,535 B, sha256 54fec0c9…,
  same cert.

## Cycle 11 — environment composition + melee FX (2026-10-25 22:59)

- User: "继续完善对齐" — the look is the longest-standing gap.
  Bundle spec (DIFF.md "Cycle 11", offsets verified): terrain is
  a seeded generator (simplex fbm quantized into 4.6 terraces,
  random-walk paths smoothing 92% along their course, forest
  massifs + terrace ponds, water carve + shared plane for
  graveyard/volcano); scatter = floor(560*propDensity*areaMul)
  gated attempts of mf-geometry props; ground detail =
  round(7000*areaMul) crossed-quad pixel sprites from a
  procedural atlas; melee = 126 deg beam-ribbon arc (r =
  0.7*range) + flash + sparks, Vine Whip = two curved vine
  chains + twinkle + leaves; nova rings are flat ground rings.
- Changes: terrain generator ported (grid heights, surface_at
  for actors; formula heightfield deleted); instanced scatter
  (~275-316 props/zone) + decoration (~9.1k-11.6k sprites/zone)
  replace node scatter + tuft field; per-zone layout seeds
  picked by a spawn-openness probe (rolls 11/1/2/11); the
  vertical torus slash/nova deleted and rebuilt to spec.
- Evidence: Test/c11shot.tscn before/after pairs; cycle9 suite
  28/28 effective (the single stateful-profile FAIL is the
  Cycle 10 suite's own revive purchase persisting in the saved
  profile — fresh-profile revive group passes 8/8, profile
  restored); check_starters 3/3; class-cache gate OK; Linux
  export boots the shipped artifact clean. New APK 53,468,207 B,
  sha256 f78b3abb…, same cert.

## Hotfix — attack feel (2026-10-26, on the cycle-11 build)

- User: "角色好像无法攻击" → "可能没攻击动作" — damage landed
  but no visible attack motion on auto-fire.
- Root cause 1: the Segment Z lunge thrust along -basis.z while
  every GLB faces +Z (set_facing aims +Z at the target) — the
  attacker recoiled AWAY from its target on every cast (player
  and enemies). Fixed to transform.basis.z, and play_lunge now
  also runs the bundle's cast squash pulse (attackT .3 s,
  sin(PI*p)*.12; bundle @836129/@850944).
- Root cause 2: _nearest_enemy gated on 3D distance while hit
  tests are horizontal — targets one 4.6 u terrace below were
  unattackable on cycle-11 terrain. Gate is XZ now (bundle
  within() parity).
- New permanent suite phase --only=attack (zero input, pinned
  in-range enemy): fires==hits, damage == hits x pipeline
  exactly, lunge forward >= 0.25 u, terrace-below target hit.
  5/5 PASS post-fix; mutation-verified (damage->0 and sign
  flip each turn the right checks red). Full DIFF.md entry:
  "Hotfix — attack feel".
- Flagged, not built: the 必 ultimate has no implementation
  (no cast path/button; HUD circle is decoration) — pre-existing,
  not a cycle-11 regression.
- Hotfix verification: suite 33 checks green (32 + revive 8/8
  on a fresh profile; the one main-run FAIL is the known
  pre-owned-revive profile artifact, profile restored
  byte-exact), starters 3/3, APK 53,480,652 B sha256
  760b66d5... (cert unchanged, in-APK class cache re-verified
  clean), Linux export smoke 0 script errors.

## Cycle 12 — zone-switch stall kill + weather parity (2026-10-26)

- Stall: terrain data now generates on WorkerThreadPool threads
  (generator extracted verbatim to scripts/terrain_gen.gd,
  grid checksums bit-identical to cycle 11) and all four zone
  scenes prebuild behind the menu (phase-sliced), then park /
  restore per portal. Warm switch 1-5 ms steady state (39 ms
  first, measured) vs 9.9-14.7 s before; cache footprint
  +14.6 MB static. (Numbers from the clean re-run in DIFF —
  the first quoted set was a mismatched capture and was
  withdrawn there.) start_game aborts the prebuild cleanly
  (stress-tested 10/10); an uncached portal defers one frame
  behind a loading banner and falls back to a data-warm build.
- Weather (spec in DIFF cycle 12, bundle offsets verified):
  7 states; per-zone base pick from biome lists + weather
  passive override; timed set_weather with toast/revert;
  boost x1.3 / nerf x0.75 wired into combat_hit (player/ally
  pipeline, after STAB); look (fog/light/sky) per spec;
  camera-centred GPU precipitation; ambient hazards (sand chip
  2+stage*2 via DoT channel, hail freeze with status-slot
  guard). Functional checks 31/31; screenshots per state in
  Test/out/wx_*.png. Named gaps: wet/electrocute layer
  (engine has no wet status), wind-sway uniform (no deco wind
  shader), timed-weather triggers await boss kits. Weather
  RNG is fixed-seed, so the sequence repeats per run
  (disclosed in DIFF; keeps suite damage values exact).
- Suite: 33 checks, 1 fail = revive-purchasable on the maxed
  local profile (fresh-profile revive group 8/8 PASS);
  check_starters 3/3; class-cache gate OK; Linux-export boot
  smoke on the shipped code: clean, prebuild completes.
- APK: 53,480,652 B, sha256 1ebf1d72…, same cert.

## Cycle 13 — the ultimate （必） wired for real

- Spec (DIFF cycle 13, offsets tail-verified): controller
  (95 s passive, killRoom-throttled plain kills .004, elite
  .03 / alpha .08 / boss .2, hurt .35 x fraction, slot-8
  exclusion), fire() (dmg 40 x (1+.1lv) x stage x (1+.15tier),
  R = sqrt(area), pose .6, hitstop .32, cut-in 1.3 s, iframes
  active+.6, cast at +0.03), and all three starter defs per
  evolution form/tier (Bg[1] roots/sun/petals, Bg[4] rings/
  zones/fissures/meteors/final blast, Bg[7] whirlpool/wave/
  rain/cannon sweep).
- Implementation: scripts/ult.gd + scripts/ult_gauge.gd (the
  HUD circle is a real touch/mouse button now), enemy "root"
  status + hit-slot attribution, rig ult-pose channel, lab
  "ult" row gained its consumer, "ultimates" left the
  unsupported-counter list. HUD labels corrected (Rising
  Blaze / Shell Whirlpool were invented names).
- Named gaps: wet status unapplied (no wet layer — cycle-12
  gap), ultLook as a tint overlay, Kg type-fallback defs not
  built (no playable species needs one), no deny sfx / audio
  duck counterparts.
- Suite: ult phase 32/32; full suite 65 checks, 64 PASS +
  the known resident-profile revive trap (fresh-profile
  revive 8/8); mutations verified (damage base, boss credit);
  check_starters 3/3; class-cache gate OK; profile restored
  byte-identical (e15aee84...).
- APK: 53,509,618 B, sha256 4469440c…, same cert; Linux-export
  boot smoke clean.

## Cycle 14 — blessing altars / roar shrines, guardian HP build scaling, wet layer

- Spec (DIFF cycle 14, offsets tail-verified): populate's
  interactables (altar i(5) + rhydon 1 of the 20 kinds —
  the rest mined, backlog), ZC tier table, tw() tiers,
  altarUpdate charge/waves/seal/drain, offerBlessing +
  Xx's 12 generators + Bx rarity (run-scoped tempMods),
  zy roar totem (run-scoped roars, +30%/+12% per roar,
  +1 chest per roar); boss.spawn's real HP pipeline
  (formula floor x70 boss flag, effTime, meter budget
  raise capped 4x via Tb/Cb, Eb damage cap [25/30/35],
  exhaust 2^(over/20)); wet as a parallel timer (5 s x
  duration, freeze consumes, electrocute x1.5 + .8 chain
  to 12 wet within 9u + 0.25 s gate, rain max(wet,2)).
- Implementation: interactables built/parked/restored
  with every zone scene; blessing modal in the draft
  idiom with a whenFree queue + stored return state;
  Player.temp_mods + duration_mult; combat meter (B_
  port) fed from combat_hit/DoT; summon_guardian
  rewritten (player.get_dps budget retired); enemy
  cap/exhaust/wet; rig wet tint; Bg[7] wet riders wired;
  rain soaking; ALLY_STATUS water->wet; "soaked" /
  "reactions" counters un-unsupported. The cycle-9
  invented HP-threshold roars are REMOVED (boss.roars
  is spawn-assigned from run.roars only).
- Named gaps: other populate kinds + comet altars +
  other reactions unbuilt; placement is distribution-
  equivalent (seeded RNG + _flat_open) not the terrain-
  reserve sampler; regular spawns still use raw minutes
  (guardian path exact); guardian escorts = 2 + roars
  is our mapping of "mas escoltas elite"; no audio.
- Suite: new phases shrine 24/24, bossscale 12/12,
  wet 18/18; full suite 120 checks, 119 PASS + the
  known resident-profile revive trap (fresh-profile
  revive 8/8); three mutations verified (blessing
  recalc, cap clamp, wet consume); check_starters 3/3;
  class-cache gate OK; profile restored byte-identical
  (e15aee84...).
- APK: 53,538,290 B, sha256 bf2e25c2…, same cert;
  Linux-export boot smoke clean.

## Cycle 15 — elemental reactions completed, comet altars, the populate long tail

- Spec (DIFF cycle 15, offsets tail-verified): the
  reactions() branch table @733487 (global per-key
  0.25 s canReact gate, countOnce counters) — steam /
  wildfire / shatter / gas in bundle order; comet
  altars (ZC tier 4, spawnComet @1245186 life 60,
  updateComet _E = 75 s then range 100–140, <18u retry
  10 s, burn-out only at zero charge); populate()
  @1240977's remaining kinds assessed one by one
  against this build's systems.
- Reactions: steam (burn consumed, 6u confuse 2.5x /
  root 2x resist on all incl. primary, x1.4), wildfire
  (7u burn spread, primary keeps burn, x1.3), shatter
  (freeze consumed, 5u chain at x.7 fixed, x2.6 with
  the frozen x1.2 folded in), gas (poison stacks r:
  x(1.4+.1r), 6u chain x(.5+.12r) + poison), mind
  collapse built as a bonus (x1.6, confuse 4x resist).
  Enemy gains parallel confuse/root timers + poison
  stacks (poison is 5 s per applyStatus now). Dragon
  fury OUT: charm has no source in this build.
- Comet: one live comet ref per stage (spent comets
  block respawn, as mined), charge/wave/payout via the
  cycle-14 altar machinery, ZC[4] blessing on completion.
- Populate: 14 kinds built (50 props/zone) on the
  cycle-9 vitamin mapping generalized to rollChestItem —
  berry, rock (VC-scaled gold), greed, cursed,
  snorlax, paid chest (BC cost curve + 3-vitamin pick
  or qC sell-all), freechest, cursed chest (ghost
  ambush), challenge (ring wave -> free chest), slots
  (x1.08 cost curve, 7-prize walk), cage (XP for gold),
  nest + egg system (kill-count hatch, team-cap ->
  chest roll), porygon (By-table trades into
  Player.recompiled_mods). OUT with evidence: meowth
  (in-run shop), ditto / bill / hypno (item/move
  systems we don't have), fossil (Aerodactyl unmodelled
  + helix pays items), magnet + supply-drop event
  (no pickup-entity system), dragon fury (above).
  Director arms wired: temp_mods difficulty /
  enemyAmount now actually consumed by _spawn_mult
  and the spawner rate.
- Suite: new phases react 25/25, comet 15/15, props
  46/46; full suite 206 checks, 205 PASS + the known
  resident-profile revive trap (fresh-profile revive
  8/8); four mutations verified (steam multiplier,
  gas stack term, comet life-while-charged, chest BC);
  check_starters 3/3; class-cache gate OK; profile
  restored byte-identical (e15aee84...). League's
  magikarp sampling check flaked once on a fresh
  profile (passed standalone + resident suites).
- Harness note: headless viewport does no GUI picking
  for synthetic events (bare-control proof) — slam /
  revive touch checks now deliver via the controls'
  gui_input signal per cycle 13's UltGauge precedent;
  game touch code untouched. Revive hurt segment
  de-flaked (evasion-dodge retries); attack phase
  cast-counter baselined from live cd_t.
- Named gaps / 近似： wildfire burnDps magnitudes ride
  the standing flat-DoT model (spread set / radius /
  multiplier / gate / counters exact); slots reel UI
  is presentation (results resolve at once); comet
  sky-fall is a fade-in, no audio; placement stays
  distribution-equivalent.
- APK: 53,571,058 B, sha256 f08aa2eb…, same cert;
  Linux-export boot smoke clean (menu screenshot in
  Test/out/linux_export_c15_menu.png).

## Cycle 16 (2026-10-26) — audio layer + daily shop

- Audio: the project had zero audio; the bundle's design is a
  procedural WebAudio engine (spec + offsets in DIFF cycle 16).
  Shipped `scripts/audio.gd`: bundle bus graph + volume law
  (.55/.32/.45 factors, defaults .8/.5/.7/.6), 26-voice pool,
  ok() throttles, ~45 synthesized one-shots wired at the real
  event sites, synthesized per-species cries (placeholder,
  reskin-swappable), and the live file-track BGM system
  mirrored with synthesized loops (menu / ingame1-4 draw /
  boss, crossfades, duck). The bundle's generative sequencer
  is never called in the original — not the live system.
  Settings surface matches: 4 volume sliders + muteHidden.
- Daily shop: EXISTS in the bundle (fixed stardust catalog,
  daily quotas, +50% intra-day escalation, UTC reset, bag
  cap 9) — implemented in Profile + a menu panel with
  persistence and fA sanitization. In-run bring-in/effects
  remain the named gap.
- Harness: audio 36/36, shop 18/18 (both mutation-verified);
  standing suite green in-suite except the known
  resident-profile revive trap (fresh-profile revive 8/8).
- APK: 53,608,067 B, sha256 2bb2aae3…, same cert;
  Linux-export boot smoke clean.

## Cycle 17 (2026-10-26) — UI alignment round 1

- User called the UI rough and made alignment the top
  priority. Round 1 = theme foundation + the screens touched
  constantly (menu / HUD / draft / blessing); results, pause,
  settings, loadout, big-map and mini boss bars are round 2.
- Shipped `scripts/ui_theme.gd` (tokens: ink #1d1236 family,
  rarity ramp, Yi type table, danger ramp — all bundle-verified
  in UI_SPEC; semantic button library green/blue/red/ghost ×
  big/small + icon buttons; glass panels; card factory),
  `scripts/ui_icon.gd` (~35 drawn icons), `scripts/ui_medallion.gd`
  (portrait + XP ring). Font stack: Fredoka + Nunito (OFL),
  Smiley Sans for CJK display (M PLUS Rounded 1c rejected on
  measured coverage: 212/642 glyphs missing; Smiley 0), Noto SC
  800/900 subsets as CJK body/fallback.
- Menu: gray panel deleted — floating accent cards over the
  live scene (HUD hidden in menu state), starter cards with
  baked portraits (Test/portraitshot.tscn: 53 species discs),
  type chips, base stats, ult line. HUD: glass top-center
  cluster (zone/tier/weather chips, pips, 7-segment danger
  meter with named tiers + WR ramp), wallet pill with icons,
  medallion with real portrait + XP ring, glass cut-in.
- Draft/blessing: icon top zones, rarity chips (no more
  bracketed rarity text), [n] kbd footers, buildMini chip row,
  banish as the original's mode toggle (red re-rim treatment;
  spec's 4px outline + hue filter approximated — named in
  DIFF), tools as counted buttons; number-key picks (blessing
  keys arm at 350 ms).
- Copy leaks fixed: Lab title's "§6.2", shop title's "Tienda",
  unlock title's "（§3）". Ledger: cycle-10 DIFF entry corrected
  in place (marked) — the original DOES have 2 mini boss bars
  (@2020582); building them is round 2.
- Eyeballed before/after captures for all seven screens
  (Test/out/ui_*_ui17{before,after}.png). Standing suite:
  260 checks / 257 pass (fails = resident-profile revive
  trap — fresh-profile 8/8 — plus the react 0.25 s gate
  pair, cycle-16-documented frame-delta sensitivity under
  a loaded box; no combat code touched). check_starters
  3/3; class-cache gate OK; profile restored byte-exact.
- Export smoke earned its keep: it caught that font
  loading via load_dynamic_font silently fails in exported
  builds (raw .ttf paths are not files inside the PCK) —
  UiTheme now loads via ResourceLoader; rebuilt and
  re-smoked clean (0 errors). APK: 57,483,124 B, sha256
  8505b8a7…, same cert.

## Cycle 18 (2026-10-26) — UI alignment round 2 + bring-in

- UI_SPEC finished on the cycle-17 foundation: sectioned
  results screen (payout chips, fact grid, per-move damage
  bars, pact chips, capture grid, task rows, dex panel —
  fed by real run attribution; BONK chip and rivals block
  omitted by design, named), tabbed pause (Esc/P + touch
  button, world clock bit-frozen in checks), 6-section
  settings (sound/gfx/controls/keys-read-only/HUD/account;
  hudScale/hudOpacity/bossOpacity/minimapScale/fpsCap/
  touchScale all live), HUD remainder (party row, pw-row
  chips, goal card fed by League challenges — the bundle's
  card is an online rival tracker, named adaptation,
  event pills, boss portrait + phase ticks, the 2 mini
  boss bars from the cycle-10 ledger correction latched
  to alphas), clickable minimap → big-map modal with fog
  + pins, and the loadout screen as the menu→run bridge
  (hero detail, 6-slot team bar with tap-to-swap, roster
  tile grid, bag bring-in row).
- Gameplay gap CLOSED: the daily shop's six items got
  their REAL bundle effects (cycle 16's descriptions were
  invented — corrected): rare-candy +2 levels at start,
  lucky-egg +25% XP, amulet-coin +50% gold, honey +1 alpha
  per zone at 240 s, shiny-stone guarantees a zone-1 shiny
  (new _spawn_shiny + shiny dex), master-ball makes the
  run's first capture certain. Bring-in = profile bag →
  loadout toggle (cap 2 + Lab 'bag' level, its fx flag now
  true) → consumed at start_game. New harness phase boost
  29/29 through the real buy→bring→effect path,
  mutation-checked.
- Mid-cycle fold-ins: the cycle-17 Claude audit's 7 routed
  items (phone scaler — the literal kR formula evaluates
  to 1.0 on phones; fixed via a CSS-surface _phone_factor
  ≈2.0 on the reference phone + a modal fit clamp;
  safe-area physical/logical unit mix; danger-name/weather
  chip overprint; cluster-over-plate at 16:9; Lab/Shop
  glass α .82→.95 readability regression; draft banish
  two-step confirm + the bundle's 600 ms modal guard,
  150 ms chained; copy leaks — draft descs, NORMAL/Zone
  chips, EN-only ult names → CN+EN everywhere) and the
  store items (shop wiring declared store-blocking — all
  six proven, none hidden; privacy + EULA rows in settings
  per Developer Agreement §2.1 — required, not optional;
  wallet RPC failure now a visible state + retry).
  Screenshot review caught and fixed three loadout defects
  (zeroed base stats — wrong data key; 1 px stat bars —
  deferred sizing vs scroll layout; ES passive prose +
  EN rank slug leaks — passive now renders mechanically
  in CN).
- Verification: 318/325 checks green on the final tree,
  zero script errors in every phase; the 7 misses are the
  two documented harness pacing sensitivities (guardian
  kill-loop × draft freeze — cap system exact in
  bossscale 12/12; react 0.25 s gate pair — wet's twin
  check passes), root-caused in DIFF, checks not weakened.
  Revive 8/8 on a fresh profile; resident restored
  byte-exact. check_starters 3/3; class-cache gate OK;
  12 + 12 screenshots inspected. APK 57,548,809 B, sha256
  8ebe4a89…, cert unchanged; fresh Linux export smoked
  (alive, 0 errors).
