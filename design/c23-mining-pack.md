# Cycle 23 MINING PACK — bundle-proven specs for the remaining alignment systems

Read-only research output (no construction). All offsets are character offsets
into the main chunk
`origins/3be62a71…/assets/main-CkI7dQhz-mvml8e65.js` (2,154,272 B) unless
marked **[news]** (the `news-BfmMIm3P-mvml8e65.js` chunk in the same folder).
Alias resolution used throughout: the main chunk imports news exports under
short names; the news chunk's own `export{}` maps local→exported names, so
every cross-chunk table below was resolved through both hops and verified at a
call site.

Port-state references are to the tree as of the end of C22 (APK sha256
938dcef0…). Sizes: S ≤ ~1 day of construction+harness, M ≈ 2–4 days,
L ≥ a week or a dedicated sub-project.

---

## 1. Run-tier ladder (tiers 1–2) + Db/Ob impatience — PROVEN

### 1.1 The ladder table

`Ze` in main ≡ `Vt` in news, defined **[news] @89568** (the same object that
carries `towerMax: 999` in its limits sibling). Rows are `[tier0, tier1,
tier2]`; tier names **[news] @60672**: `[Normal, Difícil, Pesadilla]`.

| row | values | consumed at (main chunk) |
|---|---|---|
| hp | 1 / 1.4 / 1.9 | run.diff build @1439645 (`Ze.hp[tier] ?? 1`) |
| dmg | 1 / 1.42 / 1.96 | same (`Ze.dmg`) |
| speed | 1 / 1.08 / 1.16 | same (`Ze.speed`) |
| amount | 1 / 1.3 / 1.6 | same (`Ze.amount`) |
| kills | 1 / 1.25 / 1.5 | **no client consumer found** (see unknowns) |
| level | 1 / 1.5 / 1.8 | **no client consumer found** (see unknowns) |
| cap | 1 / 1.15 / 1.3 | director @857500 (spawn caps ×Ze.cap) |
| elite | 0 / .04 / .08 | director @857016 (adds to elite chance) |
| events | 1 / 1.2 / 1.4 | director @859567/@860266/@861175 (event counts ×Ze.events) |
| early | 0 / 15 / 30 | director @852474 (non-card/event timeline entries start Ze.early s earlier, floor 60 s) |
| tele | 1 / .92 / .85 | boss brain getter @1001734 (`Ze.tele[tier] ?? 1`, scales boss teleport cadence) |
| fury | .5 / .55 / .6 | boss brain @999509 (enrage threshold fraction) |
| escorts | 0 / 1 / 2 | boss brain @1000258 (+Ze.escorts add-spawns) |
| wound | 4 / 5 / 6 | `Gy = Ze.wound[tier] ?? 4` @868855 (wound duration s) |
| strike | 1 / 1.2 / 1.4 | boss strike floors @336528 (×.05) and @499071 (×.02) |
| late | 1 / 1.12 / 1.25 | director @855811 (stage ≥ 2 damage ×Ze.late) |
| alphaCap1 | .15 / .25 / .25 | director @322243 (stage-1 alpha chance cap `Ze.alphaCap1[tier] ?? .25`, non-endless) |

Derived at run setup @1439645: `xpMult = 1 + tier×.15`,
`stardustMult = 1 + tier×.75`. Score formula **[news] @83497**:
`round(kills×2 + time×3 + damage/200 + (stage−1)×1500 + bosses×800 + (victory ? 6000 : 0)) × (1 + tier×.5)`.
Tier is forced 0 in tower runs (run ctor @1439261) and in endless setup
(@1871186).

### 1.2 Unlock / selection semantics

- `profile.biomes[biome]` ∈ {missing/−1 = locked, 0 = unlocked not cleared,
  ≥1 = highest cleared tier + 1}. Display map `fR` @1971611:
  1→Normal, 2→Difícil, 3→Pesadilla. Profile aggregates @1570136 count
  biomes `>= 2` (@hard) and `>= 3` (@night).
- Selectable tier cap at setup @1872312: `min(2, max(0, biomeTier(biome)))`;
  co-op @1645544 applies the same rule to the team's minimum.
- Chain unlock: `biomeUnlockedByChain` @1581465 — a biome is chain-unlocked
  when the previous biome's value ≥ 1.
- **Unknown (honest):** the exact write site that bumps `biomes[biome]` on
  victory was not located in the main chunk (finish/adopt path merges
  profile data); the semantics above are proven by three independent
  readers (setup cap, display map, quest aggregates). `Ze.kills` /
  `Ze.level` likewise have no consumer in either chunk — most likely
  backend score/medal inputs or vestigial. Construction should wire the
  readers and the score multiplier, and treat kills/level as no-ops until
  a consumer surfaces.

### 1.3 Db/Ob — RECOVERED

`var Db = 12, Ob = 20, kb = .4` @994585 (boss-brain module scope). In the
boss brain (class Yy) @1000489–1000603:

```
s = (dist(player, boss) < 30) ? kb × clamp((player.noHitT − Db) / Ob, 0, 1) : 0
this.t -= dt × (enraged ? 1.35 : 1) × (1 + s)
```

- `player.noHitT`: seconds since the player last took a landed hit —
  reset in `hurt()` @820359, incremented per tick @837774.
- Rising edge of s (0 → >0) fires the "¡Se impacienta!" popup; s back to 0
  clears the impatient flag. So a boss's move cadence accelerates up to
  ×1.4 when the player has gone 32+ s unhit at close range (full ramp at
  noHitT = Db+Ob = 32 s), on top of the enrage ×1.35.

### 1.4 Port state today

- **No run-tier concept at all.** `world.gd` difficulty comes only from
  greed/cursed altar `difficulty_mult`; there is no tier select, no
  run.diff object, no score multiplier application of tier.
- `Profile` approximates the unlock semantics with counters
  `tier_<biome>` (`profile.gd:185/230`, count_max, records 1 on a clear) —
  the *shape* differs from `biomes[biome] = highest tier + 1` and will
  need rework, not just wiring.
- Impatience exists as a wrong approximation, `world.gd:7955–7961`:
  `s = clamp((_boss_no_hit_t − 8) / 10, 0, 1)` — and `_boss_no_hit_t` is
  reset when the **boss** takes damage, i.e. the port measures "time
  since the boss was hit", the bundle measures "time since the **player**
  was hit". Constants (8/10, cap 1.0) and the missing dist<30 gate are
  also off; the port has no impatient popup.

### 1.5 Construction hooks & size

- New `run_tier` on the run state; `world.gd` `_spawn_mult`/director
  paths multiply hp/dmg/speed/amount by the Ze rows; director elite/cap/
  late/early/events/alpha-cap call sites mirror §1.1 (the port's director
  lives in world.gd spawn logic + `director_beats`).
- Boss brains (`world.gd` boss tick + `enemy.gd` guardian logic): tele,
  fury, escorts, strike floors, and the corrected impatience
  (player-side no-hit timer — the port's `player.gd` needs a `no_hit_t`
  accumulated in its tick and reset in `take_damage`/`hurt_fixed`).
- Tier select UI belongs to the UI line's menu work; this pack only
  requires the data path + the setup cap rule.
- **Size: M** (ladder wiring + unlock rework + impatience fix is S alone).

---

## 2. Pickup-entity system — PROVEN

### 2.1 The entity class

Class `ph` @503300–509800 (full dump archived during mining). Struct-of-
arrays, capacity **ah = 2500**. Kind table `oh` @502697, index order:

```
0 xp · 1 coin · 2 heal · 3 magnet · 4 bomb · 5 repel · 6 candy ·
7 chestkey · 8 tm-swords · 9 tm-agility · 10 tm-iron · 11 tm-thunder · 12 tm-payday
```

- Lifetimes `dh`: heal 60 s, magnet/bomb/repel 120 s, kind ≥ 6 infinite,
  xp/coin infinite. Blink-out warning window `uh = 8` s before expiry.
- `spawn(kind,x,y,z,value)`: initial velocity random dir 1–3.5, vy
  range(4,7); lands at y+0.6.
- `spawnMerged`: if same-kind count > 500 (xp) / > 200 (coin), merge into
  the nearest unattracted same-kind within 4 u (else recycle the farthest
  slot when total > 1800 or dist² > 3600).
- `consolidate` @511750: every 1.2 s, when total > 260, merge same-kind
  pickups sharing a 3.5 u grid cell (age ≥ 1, unattracted; only when
  xp > 240 or coin > 100 in the cell) summing values.
- Update: attraction when `age > 0.35` and (`dist < pickupRange` or
  (`magnetAll > 0` and kind ≤ 1)); attracted velocity 16 + age×6 toward
  the player, velocity lerp 9/s; collect at dist < 0.9. A pickup at rest
  (`rest` flag, set after landing velocity decays) only re-activates when
  the player enters range².
- Base `pickupRange = 6` (base stats @786941).

### 2.2 collect() dispatch @508147

| kind | effect |
|---|---|
| xp | `addXp(value)` + xpChain (0.45 s chain window raises pickup pitch) |
| coin | `addGold(value)`; coinSum batches floaters over a 0.4 s window |
| heal | counter `berries` +1; heal 25% maxHp |
| magnet | `magnetAll = 4 × stats.powerup` (seconds; attracts all xp/coin) |
| bomb | `run.nuke()` @1453825: within 28 u, normal enemies take 1e9 fixed damage; Boss/flag-12290 enemies take 8% maxHp; Object-flag skipped; knockback 6. Revive variant caps bosses at hp−1 instead |
| repel | `run.repel()` @1455204: within 20 u, knockback 40 × resist (Boss/Summoner .05, flag-12290 .2, else 1) + stun max(existing, 1.5 × resist) |
| candy | `gainLevel()` (a full level) |
| chestkey | `run.keys++` — **no consumer and no spawn site found in the main chunk (honest unknown; treat as reserved)** |
| tm-swords | +50% damage, 10 s |
| tm-agility | +35% moveSpeed, +30% attackSpeed, 10 s |
| tm-iron | damage taken −60%, 8 s |
| tm-thunder | all enemies within rp = 40 u stunned `secs × powerup` |
| tm-payday | gold ×2, 15 s |

TM durations all scale × `stats.powerup`; the TM table `tp` is @314400,
the applier `op()` @315287.

### 2.3 Spawn sources (drops)

`drops()` @742641 (on kill; `wt` = enemy weight):

- **Coins:** `goldFrac += V_ × stats.gold × wt` with **V_ = 0.2**; each
  time goldFrac ≥ 1 a coin entity spawns with floor(goldFrac) value.
- **Heal:** chance .006 × powerup × wt.
- **Power-up cycle:** when `time ≥ powerUpAt`, chance
  .0018 × luckMult × powerup × wt → `up()` @317666 draws from
  [magnet, repel, tm-swords, tm-agility, tm-iron, tm-thunder, tm-payday],
  adding bomb only when `time ≥ bombAt`; then
  `powerUpAt = time + max(18, 40/powerup)`; drawing bomb sets
  `bombAt = time + 120`. Initial powerUpAt = bombAt = 0 (run fields
  @1437952).
- Alpha kills also drop candy @741264. Summoner/totem-class kills drop
  candy + coin bundles @1032925/@1033322. Boss kills: 20 coin entities of
  ceil(5 × stage × gold) @1461024 (tower floor bosses: 16 coins of
  ceil(5 × curveStage × gold), §8). Golden Meowth: on-hit coin every
  0.16 s of ceil((2 + stage×2) × gold) @1041871; on kill 30 coins of
  ceil((4 + stage×4) × gold) @1042082.
- **Rocks** @1253358: gold round(range(6,14) × max(stage, VC/90)) plus a
  **15% × luckMult** draw from [heal, magnet, bomb] spawned as entities.
- **Sky supply drops** `supplyDrop()` @1354456, driven by the milestone
  director: first at range(55,75) s, then every range(70,95) s
  (@1350190/@1351317); lands at randomPoint(22–38 u), ≥ 15 u from the
  player; 65% a chest falls from +22 (of which 15% is a Super Ball chest,
  else normal), 35% a pickup drawn from [magnet, repel, heal, heal, bomb]
  falls from +16. Skipped while a Mewtwo-class event is active.
- Other magnetAll writers: magnet prop (populate §7) sets magnetAll = 5
  @1252271; streak ≥ 25 → magnetAll = 4 @1450832; tower clearFloor →
  magnetAll = max(current, 8) (§8); `harvest` passive spawns a heal
  pickup beside the player every 15 s @700006; sanctuary/tower `berry()`
  spawns heal @1064632/@1277136.

### 2.4 pickupRange stat — all sources

Base 6. Passives: magnet-pull +4, magneton "pickup" +4, long-tongue +4,
static-wool +3, keen-eye +2, beacon +2, gem-hoarder +2. Bug vitamin +1
@518510. Items: honey +1.5, exp-share +2. Lab row "magnet" +0.6/level.

### 2.5 Port state today

- **No pickup entities at all.** Kills settle instantly in `_award_kill`;
  the coin drip rate is already bundle-true (0.2 × gold_mult — the same
  V_), so entity-ification changes timing/collection feel, not totals.
- Blocked item effects in `assets/data/items.json` (their pickupRange
  mods currently fall into `player.gd:261`'s passive_extra record-only
  bucket): **honey** (+1.5 range — its other effects live), **exp-share**
  (xpGain ×1.25 live; +2 range blocked). The Lab "magnet" row
  (`profile.gd:31`, fx:false) also has no consumer.
- Boss/Meowth coins are credited directly (standing port adaptation);
  rocks pay heal directly on player hurt instead of spawning entities
  (partial mapping); nuke/repel/TM-buff effects do not exist.
- The port does have a temp-buff idiom (tempMods/addBuff-style timed
  stat mods) that the five TM effects can ride — construction must
  verify the exact helper names against the tree at build time.

### 2.6 Size

**M.** One entity layer (pooled nodes or a lightweight manager —
2500-entity SoA is a bundle implementation detail; the port's enemy
counts make a few hundred live pickups the realistic ceiling), the drop
table, magnetAll, and the five TM effects. The chestkey kind should be
implemented as a counter only (no consumer exists upstream either).

---

## 3. Shiny tail — PROVEN

Constants **[news] @83497**: stardust `it = {first: 120, repeat: 50}`;
zone shiny `at/ze = {zone: .08, luckDiv: 1000}`; classic `ot/xr =
{zone: .025, luckDiv: 3000}`; Cx weight floor `st = {floor: .15}`;
legendary rate `ct = .03`; charm multiplier `dt/Sn = 1.5`; flee seconds
`ft/vn = {base: 120, charm: 150}`.

Perk ladder `lt` **[news] @83680–84130** (n = distinct shiny species):
2 → luck +3 · 4 → xpGain +.04 · 6 → charm (shiny rate ×1.5, flee 150 s) ·
10 → damage +.03 · 15 → **bond: 2**.

### 3a. Shiny ally + swap

`caught()` @1057700–1058700: on a shiny capture → `addShiny` grants
stardust (120 new / 50 repeat) → `allies.makeShiny(species)` (make
@523543: bond starts 0, slot = 10 + serial % 100) then the ally's bond is
**seeded to `meta.shinyBond()`** = the largest bond value among unlocked
perks (i.e. 2 once the n ≥ 15 perk is owned, else 0) and `shiny = true`.

Ally damage @519768:
`(12 + 1.1×level) × (.75 + bst/800) × (1 + .25×(stage−1)) × (1 + .1×bond) × (shiny ? 1.2 : 1) × r`
(r carries lemonade ×(1 + .25/stack) etc.). Generic bond growth: ally
kills crossing Eh = [25, 75, 150, 300, 500] @517639 raise bond +1 each
(onAllyKill @528359) — so shiny bond 2 is a head start on the same
ladder, worth +20% via the (1+.1×bond) factor, *separate* from the shiny
×1.2 (`Dh = 1.2`).

Slot rule: **one shiny ally at a time.** If none, `setShiny` (replaces
the old shiny in the list, recompute) and the capture settles with the
`l(true)` popup. If one exists → `showShinySwap` modal: keep the new one
(the old "returns to the forest") or release the new one.

**Port today:** `profile.gd` has the ladder API surface
(`shiny_bond_unlocked` records a boolean @741; `record_shiny` @677) but
nothing consumes it. `enemy.gd` already has the bond chassis
(bond_level / bond_mult = 1 + 0.1×bond @620) and its `ally_power`
comment @195 already names the shiny 1.2 factor — what's missing is
makeShiny/setShiny/swap wiring and bond seeding. The swap modal's UI
belongs to the UI line; the data flow is fully specified above.
**Size: S–M.**

### 3b. Classic — the parallel system

Encounter class `wx`, scheduled alongside shiny via `classicAt`
@1046929. At each stage settle (@1048050–1048700) the shiny roll happens
first (P = (ze.zone + min(ze.zone, luck/1000)) × shinyRate →
shinyAt = range(40,420) or ∞; stage-1 shiny-stone clamps shinyAt to
range(40,150)), then:

```
classicAt = (not coop && classicPool non-empty &&
             rand < (xr.zone + min(xr.zone, luck/3000)) × shinyRate())
            ? range(60, 420) : ∞
```

Tick priority: shiny encounter first, Classic second.
`classicPool` @1051478: director pool ∩ families the player owns a
classic of, excluding legendary/mythical, must have an animated sprite
and a not-yet-classic member in the line.
`spawnClassic` @1051974: species drawn by Cx weights (floor .15); loads
the normal sprite AND the `Vl`-prefixed PMD-shiny atlas variant; HP
×2.5; flags Capture|Classic; mode 'classic'; not a sure capture.
`caughtClassic` @1059298: `addClassic` → **+200 stardust if new, +0 if
repeat**; the popup lists per-member classic-unlock lines for the family
(two phrasings: member in the Liga / not). No ally is created; no Liga
join.

**Port today:** nothing. Note the bundle's classic *visual* is a
replacement sprite atlas — the port is 3D with no atlas swap; the
construction cycle must decide the 3D equivalent (the zl hue-rotation
used for shiny, §3c, is the obvious candidate) — flagged as a porting
decision, not a bundle fact. **Size: M.**

### 3c. Shiny-skin unlock (C20 audit N1)

`skinMember(e)` @1579612: `Zt.get(e) ?? Ct.find(same family line)` — the
Liga roster's representative member of that family line. On a shiny
capture the popup's tail line (@1058204) reads: representative in the
Liga → "Aspecto variocolor de {name} desbloqueado en la Liga";
otherwise → "Desbloqueará … cuando se una a tu Liga". The dex page
repeats the rule @1883174 and notes a shiny capture does not count as a
normal capture. The skin itself is the looks system (`yT` @1327428:
normal/shiny/classic/m1/m2/spectral/t1/t2; `skinFor`/`skinAvailable`
@1576837); at run start a member with `shinySkin` gets `skinGl = Ku`
(member, skin) @1439645; sprite key resolver `qu(e,t)` @194546 prefixes
classic with `Vl`.

**Port today:** no skin system; `ModelRig.apply_shiny` (zl hue rotation)
already exists as the 3D equivalent of the shiny look. Construction:
record unlocks per family line + apply at spawn + the popup/dex strings
(dex strings belong with the UI line). **Size: M** (record+apply alone: S).

---

## 4. Bill move fusion — PROVEN (rules + data; modal is a later cycle)

### 4.1 Access

Bill prop ×1/stage (populate §7). Idle label @1248797 recomputed every
0.5 s: "una fusión, a elegir entre {n} parejas" (n = ready pairs).
Interact case @1251580 → `PC()`.

### 4.2 Pair enumeration — MC(run) @1229016

- Candidates: player moves whose def passes `kC` @1228461:
  `arch ∉ {weather, buff, fusion}` (fusion products can't be re-fused).
- For each pair (i<j): result `o = AC(defA, defB)` (§4.3);
  `need[]` lists `"{name} Nv. {lv}/8"` for any parent below level 8
  (`jC`); **ready = both parents ≥ level 8**.
- Roster signature pairs (from `EC(roster.id).moves`) are appended with
  a = b = −1, always ready:false, and need[] carrying per-move status
  strings (not learned / level short / already inside another fusion
  (`parents.includes`) / banished).
- Sort: ready first, then kind order signature(0) < reaction(1) <
  type(2) < glitch(3).
- MC's output shape `{r, a, b, names, types, ready, need[]}` is exactly
  the data the (future) modal needs — no other UI data source exists.

### 4.3 Result resolution — AC(a, b) @1228522

1. **Signature:** the SC table contains an entry whose `moves` pair
   matches (both directions).
2. **Reaction:** an entry whose `pair[0]` type-set contains typeA and
   `pair[1]` contains typeB (both directions tried).
3. **Type:** same type → that type's entry.
4. **Glitch:** fallback entry.

### 4.4 The SC table @1228007

`SC = [...WS, ...KS, ...YS, ...rC, ...lC, ...vC]`, entry ids
**IS = 50000 + index** (IS @1083497). Power is overridden via `yC`
(table at the vC definition @1226219; e.g. fu-95: 11.83, fu-16: 7,
fu-27: 6.46); cd ×`bC`; when power > 4, cd and power are jointly scaled
by max(2/cd, sqrt(4/power)) if < 1. Indices: CC key→{r, id},
TC(key)→id, wC(key)→def, EC(member)→signature entries.

Composition (counted this pass):
- **82 signature fusions** (`fu-*` keys in @1085516–1228007; WS/KS/YS/rC
  are generation blocks of ~16 member-keyed bespoke defs each, lC/vC
  carry the rest including sub-arrays pC/hC/_C spreads).
- **8 reaction fusions** built by factory `mC` (hC): conduct, steam,
  wildfire, shatter, toxicfire, nightmare, psyspark, charmbreath.
  (Naming caution: steam/wildfire/shatter here are *fusion results*,
  distinct from the combat status-reaction system the port already has.)
- **18 type fusions**, one per type, built by factory `dC` (pC).
- **1 glitch fusion**: `fu-missingno` @1225547 — on each cast it becomes
  a random type fusion (F.pick(pC)) wrapped in corruption blocks.

### 4.5 Applying a fusion — NC(run, pair)

Result move via `kv(TC(r.key))` (`kv` @768467: level starts 1, default
mods). **Mods merge `RS(A, B)` @1083580: dmg/area/speed/dur/status each
a+b−1; cd multiplies; count/pierce/crit/bounce add.**
`parents = [idA, idB, ...A.parents, ...B.parents]`; timer = 1.2; both
parents are forgotten (`forgetMove`); the product takes slot min(a, b);
`run.fusions.push(r.key)`; result sprite preloaded.
Damage formula `zS` @1083580: `def.dmg × 1.3 × mods.dmg × (1 + (level−1)×.04)`.

`PC/FC` flow: PC @1230490 → state=modal, `ui.showFusion(run, MC list,
callback)` → on a ready pick: prop used (one per stage), a 2.7 s
cinematic (camera dist 7.5 / pitch .22 / orbit .25, audio duck .3), then
NC lands with flash/ring FX.

### 4.6 Port state today

- No fusion system, no fusion data (DIFF @2937). The C21 tm-case item
  already exposes the "+1 move star" hook but has no consumer.
- Structural gap to flag: bundle move instances are `kv` objects
  `{def, level, mods{10 fields}, parents[]}`; the port's are
  `{key, level, mult, cd_t}` (`player.gd:141`). RS merging presumes the
  kv mods structure — construction must either grow a mods dict on port
  move instances (default identity) or accept a lossy mult-only merge.
  The honest route is the mods dict; budget for it.
- The 82 signature defs are bespoke `cast()` JS built on bundle effect
  primitives; the port interprets moves from `moves.json` data via its
  own arch/shape machinery. The 27 factory defs (reaction+type) port
  cheaply; the 82 bespoke casts are the bulk of the work.

**Size: L** (system+MC/NC M; data/cast extraction L). Modal UI excluded
by design — a later UI cycle consumes MC's output shape.

---

## 5. Shield system — PROVEN

- Stat `shieldMax`: base 0 (base stats @786941; stat metadata @785249:
  "Escudo", flat). Glossary @1551892: "a shield that regenerates on its
  own and absorbs damage before your HP."
- **Sources — passives only** (full-main-chunk sweep; no item, blessing,
  or Lab row grants it): torrent-shell +20, caterpie-line passive +20,
  shield-dust +20, leaf-guard +15, water-veil +15, flower-veil +15,
  sweet-veil +15, overcoat +10.
- **Regen** (player tick @839125): if `shieldMax > 0` and `noHitT > 3`:
  `shield = min(shieldMax, shield + shieldMax × .25 × dt × (woundT > 0 ? .5 : 1))`
  — full charge in 4 s of charging, halved while wounded. Any landed hit
  resets noHitT (see below), so regen effectively starts 3 s after the
  last hit.
- **Absorption order** in `hurt()` @818209: gates (iframes/dead/…) →
  evasion roll → guard-spec full block → damage calc (type effectiveness
  clamp .5–1.6, armor `armor/(armor+45)`, ability dmgTaken, multiscale,
  hurtMod, boss-strike floors/caps) → **overheal absorbs first, then
  shield** (`min(shield, f)`), remainder to HP. Post-absorption
  bookkeeping (iframes .45, noHitT = 0, hits++) runs **even when the
  shield absorbed everything** — a fully blocked hit still delays regen.
- **HUD** @2019779: shield bar fill = `scaleX(min(1, shield / maxHp))` —
  denominator is maxHp, not shieldMax; the HP numeric appends
  `+{round(shield + overheal)}` when > 1.
- Enemy-side shields exist as a separate mechanic (enemies have a
  `shield[]` field consumed in combat.hit @739864, and the mold-breaker
  passive ignores enemy shields) — that is boss-kit territory, already
  partially covered by C21/C22 boss work; out of scope here.

**Port today:** nothing — `shieldMax` mods from the 8 passives land in
`player.gd:261`'s record-only bucket; `player.take_damage` runs
evasion → dmgTaken/fullHp hooks → armor/(armor+45) → sturdy → HP, with
no shield or overheal layer. The insertion point is exactly between the
armor step and HP subtraction, preserving bundle order (overheal, when
it lands, goes before shield).
**Size: S.**

---

## 6. Fossils — PROVEN

Single fossil-ruins prop ×1/stage (populate §7). Interact case
@1251456 → `openFossil` @1478748: state=modal, `ui.showTrade` with
title "Ruinas del Fósil", portrait species 142, offers from `Py(run)`;
help text states it answers only once. Cancelling costs nothing and
leaves the prop unused; picking runs `Iy(run, prop, key)` @863666+.

Tables @863402: costs `Oy = {helix: .15, dome: .20, amber: .25}`;
species `Ay = {helix: 138, dome: 140, amber: 142}` (Omanyte / Kabuto /
Aerodactyl — the fossil's creature: cry + prop model); colors
`jy = {helix: #4a9ad8, dome: #b07a3a, amber: #ff9a2a}`; dome pool
multiplier `ky = 1.5`.

`Py(run)` offer rows: {key, color, species, name (Fósil Hélix / Fósil
Domo / Ámbar Viejo), tag (Objeto / Bendición / Compañero), boon, bane
("−{n}% de PS máx.")}. The amber boon text changes when the team is full
("…you'll choose whom to release").

`Fy(run, key)` — the cost: `tempMods.push({stat: maxHp, mul: 1 − Oy[key]})`,
recompute, `run.shrines.fossil.push(key)` (feeds the `fossil_<key>`
counters behind the @fossils quests, DA = [helix, dome, amber]
@1570136).

`Iy` resolution (prop used + dimmed; chosen fossil model rises/spins,
others hide at .6 s; cry of Ay[key] at .5 s):
- **helix:** Fy charged immediately; at .8 s →
  `rollChestItem(free=false, tierFloor=3, count=2)` — pick 1 of 2
  epic-or-better items.
- **dome:** Fy; at .8 s → `offerBlessing("Bendición ancestral del Fósil
  Domo", minTier=4, count=3, picks=1, pool×1.5)`.
- **amber:** **no upfront charge** — at .8 s →
  `allies.recruit(142, …, onSuccess → Fy('amber'))`: Aerodactyl joins as
  a run ally (normal ally machinery, not a Liga join); the maxHp cost
  is charged only if the recruit actually succeeds (team-full release
  flow included; cancelling the recruit = no charge).

**Port today:** the fossil prop kind doesn't exist (PROP_PLAN
`world.gd:5724` has no fossil/bill/hypno/magnet entries); roster data
for 138/140/142 exists (`roster.json` passive/kit/rank/challenge). The
blessing and chest-item flows the first two offers call already exist
in the port (altar blessings, chest rolls). The amber recruit is
**model-blocked**: 142 has no GLB, and the port's rig hard-indexes
species models (DIFF's standing warning) — helix/dome are buildable
now; amber needs either the GPT-art GLB or a primitive-body precedent
(ditto's blob) accepted for it.
**Size: S (helix+dome+prop+modal data) / amber gated on the model call.**

---

## 7. Micro-deviations — ALL THREE CLOSED

### 7a. Ditto endless count — the real story is the endless populate plan

`populate()` @1239743 branches on `o = !!run.endless`, i(n) =
round(n × (.5 + .5 × areaMul)):

| kind | stage plan | endless plan |
|---|---|---|
| altar | i(5) | i(3) |
| greed | 1 | — |
| challenge | i(2) | i(1) |
| cursed | 1 | 1 |
| fossil | 1 | 1 |
| rhydon | 1 | — |
| porygon | 1 | 1 |
| bill | 1 | 1 |
| nest | 1 | 1 |
| meowth | 1 | — |
| **ditto** | **1** | **2** |
| hypno | 1 | 1 |
| snorlax | 2 | 1 |
| magnet | 2 | 1 |
| slots | i(2) | i(1) |
| freechest | i(3) | i(2) |
| cursedchest | i(2) | i(1) |
| cage | i(2) | — |
| berry | i(5) | i(4) |
| chest | i(14) | i(8) |
| rock | i(14) | i(8) |

(Stage mode also places the boss altar separately at ring .55–.97 of
the play radius; endless has none. Dowsing-machine: altar += c,
chest += 2c, solo only.)

**Port today:** no endless mode exists at all (comments at
`world.gd:5498/6412/10364` confirm). So the ditto "deviation" is one
cell of an unbuilt mode: the stage count 1 is bundle-true and must NOT
be special-cased. The cell closes automatically when endless mode is
built (its own cycle, alongside §8's tower — both are run-mode
projects). **Size: — (no standalone work).**

### 7b. Fog Flying flag

Flag enum `R` @321816: Elite=1, Alpha=2, Boss=4, Ranged=8, **Flying=16**,
Healer=32, Shielder=64, Capture=128, Charger=256, Swarm=512,
Stampede=1024, Shiny=2048, Totem=4096, Summoner=8192, Treasure=16384.
In the stage-event spawner `sx.updateSpawns` @1037642, fog spawns get
`flags |= R.Flying` **and xp ×2** (the port has the xp half, C22). What
Flying does: ground-hazard ticks skip Flying enemies (@1346041 —
slow/pull/bite from ground zones), and league encounters preserve the
flag (@1054058; league-mode encounters gain Flying outright). Boss kits
with `kit.float` also set it (@996504).

**Port today:** no Flying concept on Enemy; fog spawns are ordinary
ground enemies (the pool species already hover visually except
drowzee, per C22). Construction: a `flying` flag on Enemy set by the
fog spawn path, gating player ground-pool/zone damage against those
enemies, plus the drowzee hover offset. **Size: S.**

### 7c. Eclipse elite rig scale

The definitive scaling block is `enemies.spawn` @325053 (flags a,
caller scale o):

```
bodyScale h = Boss ? 2.6 : Totem ? 2.2 : Alpha ? 2 : Summoner ? 1.9 : Elite ? 1.35 : 1
              (Capture flag → h = 1.25, overriding)
hp  = (12 + bst×.055) × hpMult × toughness × o;  Elite ×4.5, Alpha ×22,
      Boss ×70, Totem ×30, Summoner ×14, Treasure ×9
dmg = (5 + atk/16 + spa/24) × dmgMult × (Boss 2.2 / Alpha 1.8 / Totem 1.6 /
      Summoner 1.2 / Elite 1.4 / else 1)
speed = min(6.2, (3 + spe/55) × (weight>2500 ? .8 : 1)) × (Boss .85 /
      Alpha|Totem .9 / else 1) × diff.enemySpeed × director.speedMult()
radius = clamp(bodyWidth(h) × .42, .45, 4); height = bodyHeight(h)
```

**Port today:** the eclipse path (`world.gd` _event_tick) spawns with
scale_mult 1.0 and patches flag/dmg ×1.4/HP ×4.5 post-hoc — the rig and
radius never get the **1.35**. Fix: pass 1.35 at spawn (Enemy.setup
already accepts scale_mult and multiplies radius 0.55 × scale). Note
the same spawn block proves the port's other flag scales (alpha 2.0
etc.) — worth a harness cross-check while in there. **Size: S**
(fold into any C23 spawn-touching batch).

---

## 8. Tower mode — STRUCTURE SURVEY (not a full spec)

### 8.1 What it is

A separate run mode: class `fD` @1364453, arena builder `VE` @1362234.
The run is forced to biome `graveyard`, tier 0 (run ctor @1439261);
`result().stage = tower.floor` @1468924. The arena is a round tower
floor (radius 31, plateaus from the floor def, dais 5.5 or 9 on the
roof, wall height 13 — 1.2 on the roof — entry at OE, stairs up/down).

### 8.2 Entry conditions

**Backend-event-gated.** `YP(e)` = the backend events list's live
`tower` event; the setup screen refuses entry outside the event
("La Torre Lavanda solo abre durante su evento", setup @1864929).
Results are ranked against the event: the finish screen `XP` @1864929+
shows floor PB ("Piso alcanzado"), PB deltas, event rank and player
count. **The port has no backend/events system** — construction must
choose a local substitute (always-open, or a local calendar window).
That is a porting decision to take with the user, not a bundle fact.

### 8.3 Floor progression

- Floors 1–7, each with a def (name, layout plan, enemy pool, guardian
  {kind, id}, curve {min, step}, memorial flag) — `where()` @1388101+
  names them "{n}F · {def.name}"; the roof is "Azotea"; floors ≥ 8 are
  "Más Allá · Piso {n}" (the beyond).
- Per floor: state machine intro (KE s) → **3 waves** (wave 0–2;
  wave-clear heals 8% maxHp, toast "¡Oleada superada!") with a break
  (qE s) between → clearFloor. Guardian floors (`bossFloor`: def.guardian
  .kind === 'boss'; beyond: every 5th floor, (floor−7) % 5 == 0) run the
  guardian as the wave capstone.
- Difficulty is virtual-time driven: `vmin` getter @1365397 —
  normal floors `def.curve.min + min(wave,2)×step + min(1, waveT/60)×.5`;
  beyond `21 + (floor−8)×2 + …`. Director hooks: effTime = vmin×60
  @854353; hp/dmg/speed curves read vmin and the tower `curse` object
  {hp, speed, amount} (all start 1, modified by offerings/curses).
- Straggler rules (in `update` @1378300): veiled enemies are force-
  revealed when ≤ 4 remain or waveT > 75 s; stuck enemies teleport to a
  spawn point when ≤ 2 remain and waveT > 100 s.
- clearFloor @1377681: stagesCleared++, split recorded, heal 30% maxHp,
  hostile projectiles cleared, **magnetAll = max(magnetAll, 8)**, a free
  chest spawns at (0, 4.5), checkpoint saved (@.2 s), banner (floor 7:
  "Sube a la azotea"). Floor 4 with dark4 == 0 pushes the `dark4`
  offering (§8.4).
- Climbing: walking the exit stairs in state=clear calls
  `interact(stairs)`; if an altar offering is pending, `warnAltar()`
  delays the climb 5 s. `advance()` @1392710: floor 7 → roof=true;
  roof cleared → floor 8 (beyond begins); else floor++.
- **Win:** the floor-7 guardian is Gengar (94). Killing it (non-beyond)
  sets `won = true` @1377069 — "¡Has vencido a Gengar! La Torre Lavanda
  recupera la calma" — and the roof opens. The roof tells the Marowak
  story: Marowak guardian (105, gb class), after which Cubone (104) is
  recruited at the mother's grave (`allies.recruit(104, …)` with the
  flavor line). The beyond is open-ended score play.

### 8.4 Floor dressing: candles, offerings, altar

- **Candles:** floors have candle props (charge → light, `light()`
  @1383549); lit candles counter the dark: Gengar's damage taken ×1.35
  when a lit candle is within 7.5 (@972638, gb class); on the floor-4
  dark floor each lit candle increments dark4, unlocking the `dark4`
  offering.
- **Offerings:** table `oD` @1362848+ (dark, twin, graves, swift, iron,
  hunger, … — full count not extracted this pass). Each is a
  boon+curse pair applied for the rest of the run: e.g. twin = "+20%
  XP" with doubled hidden ghosts; iron = "an Epic-or-better item"
  (afterClimb → rollChestItem) with wilds at +40% HP. Offerings feed
  the tower curse multipliers and hook lists (arrivalBall, afterClimb).
  One offering choice happens at the floor altar before climbing
  (warnAltar when skipped).
- Tower interactables are `kind = 'tower'` props with `data.sub`
  (stairs/altar/candle/trick/…) — labels and interact dispatch go
  through `tower.label(e)` / `tower.interact(e)` @1248754/@1249910, and
  'tower' props stay live across the used-check (except sub 'trick').

### 8.5 Boss-class hookup (confirms C22)

`bossSystem` dispatch @996446: `mech = kit ? … : (run.tower ? gb[species]
: fb generic)`. The gb classes (Gengar: veil — combat.hit @724299
multiplies damage ×0.25 while veil == 1, clones per phase, blackout
levels .75/0 by phase, candle interplay, bell rings; Marowak: tower
shadow) exist **only** under the tower. C22's removal of the Gengar
double-shadow from zone play was therefore correct, and the classes'
data is archived in DIFF C22 §2.

### 8.6 Rewards, failure, save

- Floor boss kill: 16 coin entities of ceil(5 × curveStage × gold) +
  a candy @1377300 region (boss-calm fanfare).
- Per-floor: free chest + heal + magnet (§8.3). Offerings give items/
  blessings/run mods (§8.4). Meta: the run result reports stage =
  floor reached; ranked PB/rank live in the backend event record
  (port: local profile best-floor is the substitute).
- Failure: player death ends the run through the normal finish path
  (no tower-specific revive found). Mid-run exit: no tower-specific
  exit found in this pass — the entry stairs only reposition the
  player inside the arena; leaving is death/abandon. **Flagged for the
  full pass.**
- Save: `checkpoint()` serializes tower state @1392710
  ({floor, wave(min 3), won, marowak, curses, reveals, tricks,
  candlesLit, offerings}) — mid-run resume exists. Item pool is the
  shared pool except dowsing-machine, which is excluded in tower
  (`Wx` @1073022).

### 8.7 Port state & what a full mining pass still needs

Port: **nothing** — no tower mode, arena, floor defs, candles,
offerings, gb host, or checkpointing (grep "tower" in world.gd hits
only scenery names). Models: Gengar exists (zone guardian); Marowak /
Cubone model coverage unverified — check before scoping.

Still to mine for a full spec: the per-floor def table (7 floors:
pools, guardians, curves, plans), the full oD offerings table with
exact boon/curse numbers, candle counts/placement per floor, wave
composition formulas (spawnTick / waveList building), gb class
constants in full (C22 archived the headlines), roof/beyond specifics,
checkpoint/resume flow, and the entry/exit UX. Estimate for the full
pass: one more mining cycle like this one. **Construction size: XL —
its own cycle (probably two: structure+waves, then gb bosses+
offerings), gated on the entry-rule decision in §8.2.**

---

## Proposed construction order

Constraints honored: tower is its own cycle; model-blocked work stays
out (amber recruit; boss-kit GLB species from the C22 queue remain with
the user's art pipeline); UI-owned surfaces (tier select screen, swap
modal, fusion modal, trade modal chrome) are specced here as data
only.

**C23 (systems batch — no new modes, no modals):**
1. §1 ladder wiring + Profile biomes rework + corrected impatience
   (Db/Ob) — M. (Tier-select UI data hooks only; screen belongs to
   the UI line.)
2. §2 pickup-entity system incl. TM effects, magnetAll, rock/sky
   sources, honey/exp-share pickupRange unblocked — M.
3. §5 shield — S. §7b Flying flag — S. §7c eclipse scale 1.35 — S.
   (7a closes itself with endless; do not touch.)
   Batch total ≈ M+ — a full but coherent cycle: all five pieces touch
   the player/enemy stat spine and share harness patterns.

**C24 (content batch):**
4. §3a shiny ally + bond seeding (data side; swap modal data ready
   for the UI line) — S–M. §3c skin unlock record+apply — S.
5. §6 fossils: prop + helix/dome end-to-end — S (amber parked until
   the Aerodactyl model decision lands).
6. §3b Classic system — M (includes the 3D-visual decision).
7. §4 fusion **data extraction only**: SC's 109 defs converted to port
   move data + the kv-mods representation on move instances — the
   engine/NC landing waits for the modal cycle.

**Own cycles, later:**
8. §4 fusion engine + NC flow (modal by the UI line) — L.
9. §8 tower — full mining pass first, then XL construction in (likely)
   two cycles; entry rule needs the user's call.
10. Endless mode (closes §7a) — structure survey available free from
    §7a's table + the director's updateEndless; size after a mining
    pass, likely L.
