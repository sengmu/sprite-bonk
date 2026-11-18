class_name Player
extends Node3D
## Player: terrain-following movement with the original's velocity model
## (bundle-traced, DIFF "Game feel" — unchanged), plus the full §2.2
## stat block derived LIVE from pokemon.json via GameData:
##   share(x) = stat/bst*6;  o = 1 + (evoStage + growth)*0.12
##   maxHp = round((70 + 45*share(hp)) * o);  regen = 0.25 + 0.25*share(hp)
##   armor = 6*share(def) + 3*share(spd)  (reduction = armor/(armor+45))
##   speed = 8 * (0.92 + 0.12*share(spe));  phys/spec = 0.82 + 0.2*share
##   evasion = 0.02 + 0.02*share(spe);  crit 5% x1.75 (§2.2)
## Sanity anchors (starters, stage 0): HP 108/104/108, armor 9/8/11,
## regen ~2.0 (Bulbasaur photosynthesis +1.5, §3) / 0.44 / 0.46,
## speed x1.02 / x1.07 / x1.02 — all reproduced by the derivation.
## Move damage = power * DMG_SCALE * (phys|spec) * o * move_mult, with
## the type chart applied per target inside Enemy.take_damage.
## DMG_SCALE is calibrated so Vine Whip (power 45, phys 1.0049, o 1)
## deals exactly the CONFIRMED League-screen 24.8; the bundle's own
## move-damage constant was not extracted (INFERRED scale, DIFF §6).

signal died
signal evolved

const BASE_SPEED := 8.0
const RADIUS := 0.5
const DMG_SCALE := 0.54837
const TYPE_COLORS := {
	"grass": Color(0.45, 0.95, 0.4), "fire": Color(1.0, 0.55, 0.2),
	"water": Color(0.35, 0.65, 1.0), "normal": Color(0.9, 0.9, 0.85),
	"electric": Color(1.0, 0.9, 0.3), "poison": Color(0.7, 0.4, 0.9),
	"ground": Color(0.85, 0.7, 0.4), "flying": Color(0.6, 0.75, 1.0),
	"psychic": Color(1.0, 0.45, 0.7), "rock": Color(0.7, 0.6, 0.45),
	"bug": Color(0.6, 0.8, 0.3), "ghost": Color(0.5, 0.45, 0.75),
	"dragon": Color(0.45, 0.4, 0.95), "steel": Color(0.7, 0.72, 0.78),
	"ice": Color(0.6, 0.9, 0.95), "fighting": Color(0.85, 0.4, 0.3),
	"dark": Color(0.4, 0.35, 0.35), "fairy": Color(1.0, 0.65, 0.8),
}

var species_id := "bulbasaur"
var base_species := "bulbasaur"  # the starter chosen (kit/family anchor)
var _attack_face_t := 0.0  # 出招朝向短暂保持窗口，防止移动拉扯下一帧就把角色扭回跑动方向
# Cycle 22: runtime type override (the imposter passive's
# 30 s type copy, bundle @711560: t.types = nearest enemy's
# types). Empty = the species' own types. Every consumer
# that reads the player's types goes through types().
var types_override: Array = []

func types() -> Array:
	if not types_override.is_empty():
		return types_override
	return Array(GameData.species(species_id).get("types", []))

# Cycle 22: player status conditions (bundle player.inflict
# @831004 + pstat). Before this cycle the port's player
# could not be slept / bound / frozen at all — the boss
# mechs that inflict them (hypno, cloyster, dewgong) had
# no payoff. pstat maps kind -> seconds remaining; kinds
# tick in parallel like the bundle's.
var pstat: Dictionary = {}
# Cycle 22: dewgong's ice trails set this while the player
# stands on them (bundle arenaSlip, max .85); it decays
# when unrefreshed and loosens the ground-velocity lerp.
var arena_slip := 0.0

func pstat_t(kind: String) -> float:
	return float(pstat.get(kind, 0.0))

## Bundle inflict: type immunities (frozen vs ice types),
## sleep halved vs psychic types, a shorter-or-equal
## application is refused (returns false — dream-eater
## callers gate on it).
func inflict(kind: String, dur: float) -> bool:
	if hp <= 0.0 or invulnerable:
		return false
	var ts := types()
	if kind == "frozen" and ts.has("ice"):
		if world and world.has_method("spawn_floater"):
			world.spawn_floater(global_position + Vector3(0, 2.4, 0), "不起作用！", Color(0.78, 0.85, 0.91))
		return false
	if kind == "sleep" and ts.has("psychic"):
		dur *= 0.5
	if pstat_t(kind) >= dur:
		return false
	pstat[kind] = dur
	if world and world.has_method("spawn_floater"):
		var txt: String = String({"sleep": "睡着了！", "frozen": "冻住了！", "bound": "被缠住了！"}.get(kind, ""))
		if txt != "":
			world.spawn_floater(global_position + Vector3(0, 2.4, 0), txt,
				Color(0.85, 0.65, 1.0) if kind == "sleep" else Color(0.6, 0.85, 1.0))
	return true

func status_move_blocked() -> bool:
	return pstat_t("sleep") > 0.0 or pstat_t("frozen") > 0.0 or pstat_t("bound") > 0.0

func status_act_blocked() -> bool:
	return pstat_t("sleep") > 0.0 or pstat_t("frozen") > 0.0
# Cycle 9: the family's roster passive (bundle ability table) and
# the stat channels its mods drive. passive_id is anchored on the
# BASE species (the roster is per-family; evolutions keep it).
var passive_id := ""
var slam_mult := 1.0
var proj_speed_mult := 1.0
var extra_jumps := 0
var heal_mult := 1.0
var status_chance_mult := 1.0
var duration_mult := 1.0  # cycle 14: stats.duration — scales every
	# status duration this player applies (bundle applyStatus);
	# consumers: blessing duration mods, Enemy.apply_status/wet
var lock_target: Enemy = null  # cycle 18: touch lock-on target
var temp_mods: Array = []  # cycle 14: run-scoped blessing mods
var recompiled_mods: Array = []  # cycle 15: Porygon trade mods
	# (bundle run.recompiled — applied in recalc after temp_mods)
var difficulty_mult := 1.0  # cycle 15: stats.difficulty (director)
var enemy_amount_mult := 1.0  # cycle 15: stats.enemyAmount
	# (bundle tempMods) — pushed by World.offer_blessing picks and
	# re-applied at the END of every recalc(), in push order
var elite_mult := 1.0
var lifesteal := 0.0
var passive_extra := {}
var _sturdy_used := false
var invulnerable := false
var max_hp := 108.0
var hp := 108.0
var armor := 9.0
var regen := 1.96
var speed_mult := 1.02
var ult_name := "Furious Roots"
var phys := 1.0
var spec := 1.0
var damage_mult := 1.0
var crit_chance := 0.05
var crit_dmg := 1.75
var evasion := 0.04
var atk_speed := 1.0
var area_mult := 1.0
var luck := 0.0
var xp_mult := 1.0
var pickup_range := 6.0
var powerup_mult := 1.0
var timed_buffs: Dictionary = {}

func has_buff(key: String) -> bool:
	return float(timed_buffs.get(key, 0.0)) > 0.0

func add_buff(key: String, secs: float) -> void:
	timed_buffs[key] = secs
	recalc()

func tick_buffs(dt: float) -> void:
	var changed := false
	for key in timed_buffs.keys():
		timed_buffs[key] = float(timed_buffs[key])-dt
		if float(timed_buffs[key]) <= 0.0:
			timed_buffs.erase(key)
			changed = true
	if changed:
		recalc()

var gold_mult := 1.0
var level := 1
var xp := 0.0
var pending_levels := 0
var growth := 0
var moves: Array = []  # {key, level, mult, cd_t}
var vit: Dictionary = {}  # vitamin accumulators (GameData.VITAMINS acc keys)
var vit_levels: Dictionary = {}  # vitamin key -> times drafted (cap VIT_CAP)
# Cycle 21: the run item inventory (bundle player.items, a
# key -> stack count Map; addItem @814962). Run-scoped:
# cleared in setup(). Item defs live in GameData (items.json).
var items: Dictionary = {}
var revives := 0  # bundle player.revives (max-revive adds 1)
var peak_items := 0  # bundle run.peakItems (max total held)
var type_boost: Dictionary = {}  # cycle 21: charm typeBoost
	# (type -> damage multiplier, recomputed in recalc)
var rig: ModelRig
var world: Node

var _vy := 0.0
var _grounded := true
var _vel := Vector3.ZERO
var _slide_t := 0.0
var _slide_cd := 0.0
var _diving := false
# Cycle 8: dive-slam bookkeeping (bundle slam() @828969 — apex is
# tracked while airborne @846795; slam cooldown my = 2.0 s) and the
# per-run healed total for the best_healed challenge counter (§3).
var _apex_y := 0.0
var _slam_cd := 0.0
var healed_run := 0.0
var _land_buffer := 0.0
var _dash_was := false
var _jump_was := false
var _air_jumps := 0
var _speed_now := 0.0
var _invuln_t := 0.0

const GRAVITY := 30.0
const JUMP_VEL := 11.0
const SLIDE_TIME := 0.55
const SLIDE_CD := 0.9
const SLIDE_MULT := 1.9
const SLIDE_DECAY := 2.2
const DIVE_VEL := -34.0

func _share(stat: String) -> float:
	var sp: Dictionary = GameData.species(species_id)
	var st: Dictionary = sp.get("stats", {})
	return float(st.get(stat, 0)) / maxf(float(sp.get("bst", 1)), 1.0) * 6.0

func recalc() -> void:
	var sp: Dictionary = GameData.species(species_id)
	var o := 1.0 + (float(sp.get("evoStage", 0)) + float(growth)) * 0.12
	var old_max := max_hp
	max_hp = round((70.0 + 45.0 * _share("hp")) * o) + float(vit.get("hp_flat", 0.0)) + float(GameProfile.lab_level("hp")) * 8.0
	armor = 6.0 * _share("def") + 3.0 * _share("spd") + float(vit.get("armor_flat", 0.0)) + float(GameProfile.lab_level("armor")) * 2.0
	regen = 0.25 + 0.25 * _share("hp") + float(vit.get("regen_flat", 0.0)) + float(GameProfile.lab_level("regen")) * 0.2
	speed_mult = (0.92 + 0.12 * _share("spe")) * (1.0 + (float(vit.get("speed_pct", 0.0)) + float(GameProfile.lab_level("spd")) * 2.5) / 100.0)
	phys = (0.82 + 0.2 * _share("atk")) * (1.0 + float(vit.get("phys_pct", 0.0)) / 100.0)
	spec = (0.82 + 0.2 * _share("spa")) * (1.0 + float(vit.get("spec_pct", 0.0)) / 100.0)
	damage_mult = o * (1.0 + float(GameProfile.lab_level("dmg")) * 0.04 + GameProfile.shiny_damage_bonus())
	crit_chance = 0.05 + float(vit.get("crit_pct", 0.0)) / 100.0 + float(GameProfile.lab_level("crit")) * 0.01
	evasion = minf(0.6, 0.02 + 0.02 * _share("spe"))
	atk_speed = 1.0 + (float(vit.get("atkspd_pct", 0.0)) + float(GameProfile.lab_level("atkspd")) * 2.0) / 100.0
	area_mult = 1.0 + float(GameProfile.lab_level("area")) * 0.03
	luck = float(vit.get("luck_flat", 0.0)) + float(GameProfile.lab_level("luck")) * 5.0
	xp_mult = 1.0 + (float(vit.get("xp_pct", 0.0)) + float(GameProfile.lab_level("xp")) * 5.0) / 100.0
	gold_mult = 1.0 + (float(vit.get("gold_pct", 0.0)) + float(GameProfile.lab_level("gold")) * 8.0) / 100.0
	# Cycle 20: the shiny perk ladder's stat rungs (bundle
	# labStats @1578843 sums them into the permanent stat
	# block): n>=2 -> +3 Luck, n>=4 -> +4% XP, n>=10 -> +3%
	# damage, on UNIQUE shiny species owned (Profile ladder,
	# DIFF §7 correction). Cycle 20.1 (audit N10): the
	# bundle ADDS the rungs into the stat block — the XP
	# rung adds here; the damage rung adds inside the
	# damage factor above, summed with the Lab dmg adds
	# exactly as labStats sums them (NOT a x1.03 fold).
	luck += GameProfile.shiny_luck_bonus()
	xp_mult += GameProfile.shiny_xp_bonus()
	# Cycle 9: roster passive stat mods (bundle ability table,
	# assets/data/abilities.json). The cycle-7 hardcoded
	# "photosynthesis +1.5 regen" is REPLACED by whatever the
	# bundle's own table says for the passive (its real effect is
	# a grass-hit leech hook — see World.photosynthesis_tick —
	# plus any mods listed here).
	passive_id = GameData.passive_for_species(base_species)
	slam_mult = 1.0
	proj_speed_mult = 1.0
	extra_jumps = 0
	heal_mult = 1.0
	shield_max = 0.0
	status_chance_mult = 1.0
	duration_mult = 1.0
	elite_mult = 1.0
	lifesteal = 0.0
	difficulty_mult = 1.0
	enemy_amount_mult = 1.0
	pickup_range = 6.0 + float(vit_levels.get("bug", 0)) + float(GameProfile.lab_level("magnet")) * 0.6
	powerup_mult = 1.0
	passive_extra = {}
	for m in GameData.passive_mods(passive_id):
		var stat := String(m.get("stat", ""))
		var mul := float(m.get("mul", 1.0))
		var add := float(m.get("add", 0.0))
		match stat:
			"physical": phys *= mul
			"special": spec *= mul
			"damage": damage_mult *= mul
			"moveSpeed": speed_mult *= mul
			"attackSpeed": atk_speed *= mul
			"maxHp": max_hp = round(max_hp * mul) + add
			"armor": armor = armor * mul + add
			"critChance": crit_chance = crit_chance * mul + add
			"critDamage": crit_dmg = crit_dmg * mul + add  # data carries ADD (sniper +0.5); the old mul-only arm silently dropped it
			"evasion": evasion += add
			"area": area_mult *= mul
			"xpGain": xp_mult *= mul
			"gold": gold_mult *= mul
			"regen": regen += add
			"luck": luck += add
			"slam": slam_mult *= mul
			"projSpeed": proj_speed_mult *= mul
			"extraJumps": extra_jumps += int(add)
			"healing": heal_mult *= mul
			"shieldMax": shield_max = shield_max * mul + add
			"statusChance": status_chance_mult *= mul
			"eliteDamage": elite_mult *= mul
			"lifesteal": lifesteal += add
			"pickupRange": pickup_range = pickup_range * mul + add
			"powerup": powerup_mult = powerup_mult * mul + add
			_: passive_extra[stat] = float(passive_extra.get(stat, 0.0)) + add + (mul - 1.0)  # Remaining unsupported stat channels stay recorded (DIFF).
	# C23 pack §2.4 is authoritative where the older data snapshot differs.
	var pickup_adds := {"magnet-pull":4.0,"long-tongue":4.0,"static-wool":3.0,"keen-eye":2.0,"beacon":2.0,"gem-hoarder":2.0}
	if pickup_adds.has(passive_id):
		pickup_range = 6.0 + float(vit_levels.get("bug",0)) + float(GameProfile.lab_level("magnet"))*0.6 + float(pickup_adds[passive_id])
	if base_species == "magneton" and passive_id == "pickup":
		pickup_range += 2.0  # existing pickup table gives +2, pack proves +4 for magneton
	# Cycle 14: blessing temp mods LAST, in push order (the bundle's
	# tempMods.push + recompute()). Same stat vocabulary as the
	# passive table plus duration/statusChance consumers.
	# Cycle 15: + the greed/cursed arms "gold" / "difficulty" /
	# "enemyAmount" (the bundle's full tempMod vocabulary).
	for m in temp_mods:
		var stat := String(m.get("stat", ""))
		var mul := float(m.get("mul", 1.0))
		var add := float(m.get("add", 0.0))
		match stat:
			"damage": damage_mult *= mul
			"attackSpeed": atk_speed *= mul
			"maxHp": max_hp = max_hp * mul + add
			"moveSpeed": speed_mult *= mul
			"critChance": crit_chance += add
			"area": area_mult *= mul
			"xpGain": xp_mult *= mul
			"gold": gold_mult *= mul
			"regen": regen += add
			"armor": armor += add
			"luck": luck += add
			"duration": duration_mult *= mul
			"statusChance": status_chance_mult *= mul
			"difficulty": difficulty_mult *= mul
			"enemyAmount": enemy_amount_mult *= mul
			_: passive_extra[stat] = float(passive_extra.get(stat, 0.0)) + add + (mul - 1.0)
	# Cycle 15: Porygon's recompiled mods (the bundle's
	# run.recompiled, recompute @713400 region). The By table's
	# regen/armor entries carry BOTH shapes (gain add / loss
	# mul), so these arms apply mul-then-add generically.
	for m in recompiled_mods:
		var stat := String(m.get("stat", ""))
		var mul := float(m.get("mul", 1.0))
		var add := float(m.get("add", 0.0))
		match stat:
			"damage": damage_mult *= mul
			"attackSpeed": atk_speed *= mul
			"maxHp": max_hp = max_hp * mul + add
			"moveSpeed": speed_mult *= mul
			"critChance": crit_chance = crit_chance * mul + add
			"area": area_mult *= mul
			"xpGain": xp_mult *= mul
			"gold": gold_mult *= mul
			"regen": regen = regen * mul + add
			"armor": armor = armor * mul + add
			"luck": luck += add
			"duration": duration_mult *= mul
			"statusChance": status_chance_mult *= mul
			"difficulty": difficulty_mult *= mul
			"enemyAmount": enemy_amount_mult *= mul
			_: passive_extra[stat] = float(passive_extra.get(stat, 0.0)) + add + (mul - 1.0)
	# Cycle 21: item mods (bundle recompute @812155: the
	# def's mods array is pushed ONCE PER STACK, so mul mods
	# exponentiate and add mods sum across stacks; the type
	# charms additionally feed typeBoost[type] += .3/stack —
	# the same dict the ability typeBoost fractions fold
	# into). System-less stats (thorns / statusDamage /
	# flinch / projectiles / pickupRange / jumpHeight /
	# bounces / superEffective) land in passive_extra like
	# the passive table's unbuilt arms.
	type_boost.clear()
	var pho: Dictionary = GameData.passive_hooks(passive_id).get("typeBoost", {})
	for t in pho.keys():
		type_boost[t] = float(type_boost.get(t, 1.0)) + float(pho[t])
	for key in items.keys():
		var k := String(key)
		var stacks := item_count(k)
		var def := GameData.item_def(k)
		if def.is_empty():
			continue
		if GameData.CHARM_TYPES.has(k):
			var ct := String(GameData.CHARM_TYPES[k])
			type_boost[ct] = float(type_boost.get(ct, 1.0)) + 0.3 * float(stacks)
		for s in range(stacks):
			for m in (def.get("mods", []) as Array):
				var stat := String(m.get("stat", ""))
				var mul := float(m.get("mul", 1.0))
				var add := float(m.get("add", 0.0))
				match stat:
					"damage": damage_mult *= mul
					"attackSpeed": atk_speed *= mul
					"maxHp": max_hp = max_hp * mul + add
					"moveSpeed": speed_mult *= mul
					"critChance": crit_chance = crit_chance * mul + add
					"critDamage": crit_dmg = crit_dmg * mul + add
					"area": area_mult *= mul
					"xpGain": xp_mult *= mul
					"gold": gold_mult *= mul
					"regen": regen = regen * mul + add
					"armor": armor = armor * mul + add
					"luck": luck += add
					"duration": duration_mult *= mul
					"statusChance": status_chance_mult *= mul
					"difficulty": difficulty_mult *= mul
					"enemyAmount": enemy_amount_mult *= mul
					"physical": phys *= mul
					"special": spec *= mul
					"evasion": evasion += add
					"projSpeed": proj_speed_mult *= mul
					"healing": heal_mult *= mul
					"eliteDamage": elite_mult *= mul
					"lifesteal": lifesteal += add
					"extraJumps": extra_jumps += int(add)
					"pickupRange": pickup_range = pickup_range * mul + add
					"powerup": powerup_mult = powerup_mult * mul + add
					_: passive_extra[stat] = float(passive_extra.get(stat, 0.0)) + add + (mul - 1.0)
	# Cycle 21: eviolite (bundle recompute, bespoke): while
	# the species can still evolve, armor x1.5 + maxHp x1.25.
	if item_count("eviolite") > 0 and not GameData.evo_target(species_id).is_empty():
		armor *= 1.5
		max_hp = round(max_hp * 1.25)
	if has_buff("tm-swords"):
		damage_mult *= 1.5
	if has_buff("tm-agility"):
		speed_mult *= 1.35
		atk_speed *= 1.3
	if has_buff("tm-payday"):
		gold_mult *= 2.0
	evasion = minf(0.6, evasion)
	if max_hp != old_max and hp > 0.0:
		hp = minf(hp + maxf(max_hp - old_max, 0.0), max_hp)

## ---- cycle 21: item inventory (bundle addItem @814962) ----
func item_count(key: String) -> int:
	return int(items.get(key, 0))

func can_hold_item(key: String) -> bool:
	var d := GameData.item_def(key)
	if d.is_empty():
		return false
	return item_count(key) < int(d.get("max", 10))

func vit_cap() -> int:
	return GameData.VIT_CAP + (2 if item_count("max-ether") > 0 else 0)

func move_cap() -> int:
	return GameData.MOVE_CAP + (2 if item_count("tm-case") > 0 else 0)

## Returns true when the stack was added (bundle addItem
## returns false at the def cap). Immediate specials:
## rare-candy -> gainLevel() now and again after .3 s;
## max-revive -> revives += 1. old-rod's sprite preloads
## (129/130) have no rod system here — recorded in DIFF.
func add_item(key: String) -> bool:
	if not can_hold_item(key):
		return false
	items[key] = item_count(key) + 1
	var total := 0
	for v in items.values():
		total += int(v)
	peak_items = maxi(peak_items, total)
	if key == "rare-candy":
		gain_level()
		if world and world.has_method("_later"):
			world._later(0.3, func() -> void: gain_level())
	elif key == "max-revive":
		revives += 1
	recalc()
	return true

func remove_item(key: String) -> void:
	var n := item_count(key)
	if n <= 0:
		return
	if n <= 1:
		items.erase(key)
	else:
		items[key] = n - 1
	if key == "max-revive":
		revives = maxi(0, revives - 1)
	recalc()

func setup(p_species: String, p_world: Node) -> void:
	species_id = p_species
	base_species = p_species
	world = p_world
	level = 1
	xp = 0.0
	growth = 0
	items.clear()
	types_override.clear()
	pstat.clear()
	arena_slip = 0.0
	revives = 0
	peak_items = 0
	_sturdy_used = false
	recalc()
	hp = max_hp
	# Starting attack: the first damaging learnset move learned at
	# level 1 (tackle / scratch — §1.1 learnsets). The signature move
	# arrives through the draft, gated by its learnset level (§2.3).
	moves.clear()
	for pair in GameData.learnset(p_species):
		if int(pair[1]) <= 1 and GameData.move_is_draftable(String(pair[0])):
			var md: Dictionary = GameData.move(String(pair[0]))
			if md.get("power") != null and int(md["power"]) > 0:
				moves.append({"key": String(pair[0]), "level": 1, "mult": 1.0, "cd_t": 0.0})
				break
	_spawn_rig()
	# Cycle 10: NO world-space player HP bar — in the original the
	# player's HP is the HUD plate's .bar.hpbar (@2000723); the
	# world bar we used to park at y=0.14 sat across the enemy being
	# fought. Player HP now lives in world.gd's HUD bar.
	_snap_to_ground()

func _spawn_rig() -> void:
	rig = ModelRig.new()
	rig.is_player = true  # player hurt/faint profiles differ (rig header)
	add_child(rig)
	rig.setup(species_id)
	# C24: selected family look survives evolution and run restart.
	if GameProfile.skin_for(base_species) in ["shiny", "classic"]:
		rig.apply_shiny()  # Classic hue is a documented 3D port choice.

func move_slots() -> int:
	return 3 + GameProfile.lab_level("slot-move")

func has_move(key: String) -> bool:
	for m in moves:
		if String(m["key"]) == key:
			return true
	return false

func learn_move(key: String) -> void:
	moves.append({"key": key, "level": 1, "mult": 1.0, "cd_t": 0.0})

func upgrade_move(key: String, pe: float) -> void:
	for m in moves:
		if String(m["key"]) == key:
			m["level"] = int(m["level"]) + 1
			m["mult"] = float(m["mult"]) + 0.10 * pe  # +10%/level x rarity (INFERRED amplitude, §2.3)
			return

func move_level(key: String) -> int:
	for m in moves:
		if String(m["key"]) == key:
			return int(m["level"])
	return 0

## Expected single-target damage of a learned move (neutral type,
## no crit) — used for draft display and the guardian DPS budget.
func move_damage(mv: Dictionary) -> float:
	var md: Dictionary = GameData.move(String(mv["key"]))
	if md.get("power") == null:
		return 0.0
	var f := phys if String(md.get("cls", "")) == "physical" else spec
	return float(md["power"]) * DMG_SCALE * f * damage_mult * float(mv["mult"])

func get_dps() -> float:
	var t := 0.0
	for m in moves:
		var arch := GameData.archetype(String(m["key"]))
		var cd := float(GameData.ARCH_CD[arch]) / atk_speed
		t += move_damage(m) / maxf(cd, 0.05)
	return maxf(t, 1.0)

func xp_next() -> int:
	return int(round(8.0 + 5.5 * float(level) + pow(float(level), 1.8)))  # §2.1 Sy(level)

func gain_xp(amount: float) -> void:
	var tier_xp := 1.0 + float(world.get("run_tier")) * 0.15 if world != null else 1.0
	xp += amount * xp_mult * tier_xp
	while xp >= float(xp_next()):
		xp -= float(xp_next())
		level += 1
		pending_levels += 1

func planned_evo_level() -> int:
	return GameData.evo_level_for(species_id)

func evolve() -> void:
	var tgt: Dictionary = GameData.evo_target(species_id)
	if tgt.is_empty():
		return
	# Cycle 9 guard: never evolve into an unmodelled species —
	# several lines end at forms we ship no GLB for (Pidgeot,
	# Golbat, Golem, Rapidash, Rhydon...). Cycle 8 would have
	# crashed the rig on those; the evolution simply doesn't
	# trigger (logged in DIFF as a coverage gap, not a feature).
	if not ModelRig.SPECIES.has(String(tgt.get("key", ""))):
		return
	var old_max := max_hp
	var ratio := hp / maxf(old_max, 1.0)
	species_id = String(tgt["key"])
	types_override.clear()  # cycle 22: a copied type set dies with the form
	recalc()
	# §1.2: heal to max(current ratio, 50%) + 30% of the new max.
	hp = minf(max_hp * maxf(ratio, 0.5) + max_hp * 0.3, max_hp)
	if rig:
		rig.queue_free()
	_spawn_rig()
	emit_signal("evolved")

func apply_growth() -> void:
	growth += 1
	recalc()

func revive(frac: float) -> void:
	hp = max_hp * frac
	_invuln_t = 2.0
	# Audit P0 (cycle 9): the rig's faint latch must be cleared or
	# the revived player stays collapsed with dead gait/hurt.
	if rig:
		rig.revive_reset()

## Rare candy (guardian reward, cycle 9): the bundle's candy pickup
## calls gainLevel() — one level, queued into the draft flow.
func gain_level() -> void:
	level += 1
	pending_levels += 1
	if world and world.has_method("count_max_level"):
		world.count_max_level()

## Heal that also feeds the healed counters (photosynthesis leech).
func heal(amount: float) -> float:
	if amount <= 0.0 or hp <= 0.0:
		return 0.0
	var before := hp
	# No endless mode exists in this port; its healing multiplier is 1.
	var effective := amount * heal_mult * (0.5 if wound_t > 0.0 else 1.0)
	hp = minf(max_hp, hp + effective)
	var healed := hp - before
	healed_run += healed
	var excess := maxf(0.0, effective - healed)
	if item_count("fresh-water") > 0:
		fresh_store = minf(max_hp * 0.4, fresh_store + excess)
	overheal = minf(max_hp * overheal_ratio, overheal + excess) if overheal_ratio > 0.0 else overheal
	return healed

func leech_heal(amount: float) -> void:
	heal(amount)

func wound(duration: float) -> void:
	if hp <= 0.0:
		return
	if wound_t <= 0.0 and wound_pop_t <= 0.0:
		wound_pop_t = 3.0
		if world and world.has_method("spawn_floater") and is_inside_tree():
			world.spawn_floater(global_position + Vector3(0, 2.9, 0), "受伤！治疗减半", Color(1.0, 0.42, 0.54))
	wound_t = maxf(wound_t, duration)

func tick_defenses(delta: float) -> void:
	if hp <= 0.0:
		return
	no_hit_t += delta
	wound_t -= delta
	wound_pop_t -= delta
	guard_t -= delta
	if shield_max > 0.0 and no_hit_t > 3.0:
		shield = minf(shield_max, shield + shield_max * 0.25 * delta * (0.5 if wound_t > 0.0 else 1.0))

func shield_hud_fraction() -> float:
	return minf(1.0, shield / maxf(max_hp, 1.0))

func hp_hud_text() -> String:
	var extra := shield + overheal
	return str(int(ceil(hp))) + (" +%d" % int(round(extra)) if extra > 1.0 else "")

## Contact passives (bundle hurt()): poison-point (poison), static
## (paralysis), flame-body (burn) and effect-spore (random of
## poison/paralysis/sleep) strike back at the toucher at 30%.
func _contact_status(attacker: Node = null) -> void:
	var kind := ""
	match passive_id:
		"poison-point":
			kind = "poison"
		"static":
			kind = "paralysis"
		"flame-body":
			kind = "burn"
		"effect-spore":
			kind = ["poison", "paralysis", "sleep"][randi() % 3]
	if kind == "" or randf() >= 0.30:
		return
	if is_instance_valid(attacker) and attacker.has_method("apply_status"):
		attacker.apply_status(kind, 3.0)
		return
	var best: Node = null
	var bd := 2.6
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	if best and best.has_method("apply_status"):
		best.apply_status(kind, 3.0)

func _snap_to_ground() -> void:
	if world and world.has_method("surface_at"):
		global_position.y = world.surface_at(global_position.x, global_position.z)

func get_speed_now() -> float:
	return _speed_now

# C23B: player defenses; shieldMax is a flat passive stat.
var shield_max := 0.0
var shield := 0.0
var overheal := 0.0
var overheal_ratio := 0.0
var fresh_store := 0.0
var wound_t := 0.0
var wound_pop_t := 0.0
var guard_t := 0.0
# Optional ability hurtMod extension, evaluated before strike floor/cap.
var hurt_mod: Callable
var last_hit: Variant = null
var no_hit_t := 0.0  # C23: simulated seconds since player last took a landed hit.

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	# Cycle 9: hitstop freezes the player (and its rig) exactly like
	# a world pause; the rig also freezes whenever the world clock
	# is stopped (draft/menu), which cycle 8 left bobbing.
	var running := world != null and bool(world.get("running"))
	var frozen := world != null and world.has_method("hitstop_active") and bool(world.hitstop_active())
	if rig:
		var want := Node.PROCESS_MODE_DISABLED if (frozen or not running) else Node.PROCESS_MODE_INHERIT
		if rig.process_mode != want:
			rig.process_mode = want
	if not running or frozen:
		_speed_now = 0.0
		if rig:
			rig.set_move_speed(0.0)
		return
	tick_defenses(delta)
	_invuln_t -= delta
	# Cycle 22: status timers + ice slip decay.
	for k in pstat.keys():
		var left := float(pstat[k]) - delta
		if left <= 0.0:
			pstat.erase(k)
		else:
			pstat[k] = left
	arena_slip = maxf(0.0, arena_slip - 1.2 * delta)
	var move_blocked := status_move_blocked()
	# --- movement: the original's velocity model (bundle-traced; DIFF) ---
	var ix := (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
	var iz := (1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0)
	if move_blocked:
		ix = 0.0
		iz = 0.0
	if world.has_method("get_touch_move"):
		var tm: Vector2 = world.get_touch_move()
		ix += tm.x
		iz += tm.y
	var input_dir := Vector3(ix, 0, iz)
	if move_blocked:
		input_dir = Vector3.ZERO
	var has_input := input_dir.length() > 0.01
	if has_input:
		input_dir = input_dir.limit_length(1.0)
		var yaw := 0.0
		if world.get("cam_yaw") != null:
			yaw = float(world.get("cam_yaw"))
		if abs(yaw) > 0.0001:
			input_dir = input_dir.rotated(Vector3.UP, yaw)
		input_dir = input_dir.normalized()
	else:
		input_dir = Vector3.ZERO
	var e_max := BASE_SPEED * speed_mult
	# Cycle 21: chlorophyll in sun (bundle desc: +30% speed,
	# +20% damage — the damage half lives in _roll_damage /
	# World.combat_hit; applied dynamically since weather
	# changes mid-run without a recalc).
	if passive_id == "chlorophyll" and world and String(world.get("weather")) == "sun":
		e_max *= 1.3
	var ground_y: float = world.surface_at(global_position.x, global_position.z) if world.has_method("surface_at") else 0.0
	var dash_in: bool = Input.is_key_pressed(KEY_SHIFT) or (world.has_method("is_touch_dash") and bool(world.is_touch_dash()))
	var dash_edge := dash_in and not _dash_was
	_dash_was = dash_in
	_slide_cd -= delta
	_slam_cd -= delta
	_land_buffer -= delta
	if dash_edge and not move_blocked:
		if _grounded and _slide_cd <= 0.0 and has_input:
			_slide_t = SLIDE_TIME
			_slide_cd = SLIDE_CD
			_vel = input_dir * e_max * SLIDE_MULT
			if GameAudio.instance:
				GameAudio.instance.whoosh()  # cycle 16: slide
		elif not _grounded and not _diving and global_position.y - ground_y > 1.2:
			_diving = true
			_vy = DIVE_VEL
			_vel *= 0.35
			if GameAudio.instance:
				GameAudio.instance.dive()  # cycle 16
	if _slide_t > 0.0:
		_slide_t -= delta
		var decay := exp(-SLIDE_DECAY * delta)
		_vel.x *= decay
		_vel.z *= decay
	elif _grounded:
		if _land_buffer > 0.0 and _vel.length() > e_max:
			_vel *= 0.97
		else:
			var rate := 70.0 if has_input else 40.0
			var r := minf(1.0, rate * delta / maxf(1.0, e_max))
			# Cycle 22: ice slip loosens the velocity lerp
			# (bundle arenaSlip) — starts and stops both lag.
			var f := minf(1.0, r * 4.0) * (1.0 - 0.8 * arena_slip)
			var target := input_dir * e_max
			_vel.x += (target.x - _vel.x) * f
			_vel.z += (target.z - _vel.z) * f
	else:
		var along := _vel.dot(input_dir)
		var add := clampf(0.9 * e_max - along, 0.0, 40.0 * delta * e_max / 8.0)
		_vel += input_dir * add
		var h := Vector2(_vel.x, _vel.z)
		if h.length() > e_max * 1.7:
			h = h.normalized() * e_max * 1.7
			_vel.x = h.x
			_vel.z = h.y
	_speed_now = Vector2(_vel.x, _vel.z).length()
	var next := global_position + Vector3(_vel.x, 0, _vel.z) * delta
	if world.has_method("collide_circle"):
		next = world.collide_circle(next, RADIUS)
	next.x = clamp(next.x, -168.0, 168.0)
	next.z = clamp(next.z, -168.0, 168.0)
	global_position.x = next.x
	global_position.z = next.z
	ground_y = world.surface_at(global_position.x, global_position.z) if world.has_method("surface_at") else 0.0
	var jump_in: bool = Input.is_key_pressed(KEY_SPACE) or (world.has_method("is_touch_jump") and bool(world.is_touch_jump()))
	var jump_edge := jump_in and not _jump_was
	_jump_was = jump_in
	if _grounded and jump_in and not move_blocked:
		_vy = JUMP_VEL
		_grounded = false
		if GameAudio.instance:
			GameAudio.instance.jump(1.0)  # cycle 16
	elif not _grounded and jump_edge and _air_jumps < extra_jumps and not _diving and not move_blocked:
		# Passive extra jumps (tailwind: +1, bundle ability table).
		_vy = JUMP_VEL
		_air_jumps += 1
		if GameAudio.instance:
			GameAudio.instance.jump(1.2)  # cycle 16: air jump pitches up
	if not _grounded:
		if _diving:
			_vy = minf(_vy, DIVE_VEL)
		_vy -= GRAVITY * delta
		global_position.y += _vy * delta
		_apex_y = maxf(_apex_y, global_position.y)  # bundle: apex tracked airborne
		if global_position.y <= ground_y:
			global_position.y = ground_y
			if _vy < -8.0:
				_land_buffer = 0.12
			# Landing squash (Segment Z): a plain fall (not a dive —
			# the slam owns its own 0.9 squash) compresses the rig.
			if not _diving and _vy < -4.0 and rig:
				rig.set_squash(0.22)
			if not _diving and _vy < -4.0 and GameAudio.instance:
				GameAudio.instance.land()  # cycle 16
			# Dive landing -> slam (bundle @846795: diving clears and
			# slam(groundY, apex - groundY) fires; slam itself owns
			# the 2 s cooldown, checked inside world.player_slam).
			if _diving and world.has_method("player_slam"):
				world.player_slam(global_position, _apex_y - ground_y, _slam_cd <= 0.0)
				if _slam_cd <= 0.0:
					_slam_cd = 2.0
			_vy = 0.0
			_grounded = true
			_diving = false
			_air_jumps = 0
			_apex_y = ground_y
	else:
		global_position.y = ground_y
		_apex_y = ground_y
	if rig:
		rig.set_move_speed(_speed_now)
		if _attack_face_t > 0.0:
			_attack_face_t -= delta
		elif _speed_now > 0.5:
			rig.set_facing(Vector3(_vel.x, 0, _vel.z) / _speed_now)
	# --- regen ---
	if hp < max_hp:
		var hp_before := hp
		hp = min(max_hp, hp + regen * delta)
		healed_run += hp - hp_before  # §3 best_healed counter feed
	# --- auto-attack: every learned move on its own cooldown (§2.5) ---
	# Cycle 22: sleep / frozen block firing (cooldowns still run).
	var act_blocked := status_act_blocked()
	for m in moves:
		m["cd_t"] = float(m["cd_t"]) - delta
		if float(m["cd_t"]) <= 0.0 and not act_blocked:
			if _try_fire(m):
				var arch := GameData.archetype(String(m["key"]))
				m["cd_t"] = float(GameData.ARCH_CD[arch]) / atk_speed
				# Photosynthesis hook (bundle strike @728982): the
				# player's grass-type hits leech — throttled by the
				# world at 0.2 s, matching photoT.
				if passive_id == "photosynthesis" and String(GameData.move(String(m["key"])).get("type", "")) == "grass" \
						and world and world.has_method("photosynthesis_tick"):
					world.photosynthesis_tick()

var _last_crit := false

func _roll_damage(mv: Dictionary) -> float:
	_last_crit = false
	var d := move_damage(mv)
	# Passive hooks (bundle strike order): lowHp multiplier and
	# per-type boost apply before the crit roll; pickup's critAdd
	# is min(.15, runGold/10000) added to the crit chance.
	var hooks := GameData.passive_hooks(passive_id)
	if hooks.has("lowHp") and hp < max_hp * 0.4:
		d *= float(hooks["lowHp"])
	# Cycle 21: chlorophyll's sun damage (+20%).
	if passive_id == "chlorophyll" and world and String(world.get("weather")) == "sun":
		d *= 1.2
	var mtype := String(GameData.move(String(mv["key"])).get("type", ""))
	# Cycle 21: typeBoost is one channel (recalc folds the
	# passive's fractions and the charms' +0.3/stack into
	# type_boost as a straight multiplier).
	if type_boost.has(mtype):
		d *= float(type_boost[mtype])
	var cc := crit_chance
	if passive_id == "pickup" and world:
		cc += minf(0.15, float(world.get("gold")) / 10000.0)
	if randf() < cc:
		d *= crit_dmg
		_last_crit = true
		# Cycle 9: crits were never counted anywhere — the roster's
		# crits / best_crits challenges sat at 0 forever.
		if world and world.has_method("count_run_event"):
			world.count_run_event("crits")
	return d

func _try_fire(mv: Dictionary) -> bool:
	var key := String(mv["key"])
	var md: Dictionary = GameData.move(key)
	var arch := GameData.archetype(key)
	var mtype := String(md.get("type", "normal"))
	var ailment := ""
	var achance := 0.0
	if md.get("ailment") != null:
		ailment = String(md["ailment"])
		achance = float(md.get("ailmentChance", 0))
		if arch == "nova":
			achance = float(md.get("accuracy", 75))  # status moves: accuracy is the success roll
		achance = minf(100.0, achance * status_chance_mult)  # passive statusChance stat
	var col: Color = TYPE_COLORS.get(mtype, Color.WHITE)
	match arch:
		"strike":
			var range_ := float(GameData.ARCH_RANGE["strike"]) * area_mult
			var target := _nearest_enemy(range_ + 0.3)
			if target == null:
				return false
			var to: Vector3 = target.global_position - global_position
			to.y = 0.0
			rig.set_facing(to.normalized())
			rig.play_lunge()
			_attack_face_t = 0.24
			if GameAudio.instance:
				GameAudio.instance.slash()  # cycle 16: melee cast
			var dealt_total := 0.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
					continue
				var d: Vector3 = e.global_position - global_position
				d.y = 0.0
				if d.length() <= range_ and d.normalized().dot(to.normalized()) > 0.25:
					dealt_total += e.take_damage(_roll_damage(mv), mtype, ailment, achance, {"crit": _last_crit})
			if world.has_method("add_damage"):
				world.add_damage(dealt_total)
			if world.has_method("add_move_damage"):
				world.add_move_damage(key, dealt_total)  # cycle 18: summary bars
			if world.has_method("spawn_strike_fx"):
				world.spawn_strike_fx(global_position, target.global_position, to.normalized(), range_, col, key)
			return true
		"projectile":
			var target := _nearest_enemy(float(GameData.ARCH_RANGE["projectile"]))
			if target == null:
				return false
			rig.set_facing((target.global_position - global_position).normalized())
			rig.play_lunge()
			_attack_face_t = 0.24
			if GameAudio.instance:
				GameAudio.instance.shot(mtype)  # cycle 16: typed cast
			world.spawn_projectile(global_position + Vector3(0, 1.0, 0), target, _roll_damage(mv), col, mtype, ailment, achance, key, _last_crit)
			return true
		"nova":
			var range_ := float(GameData.ARCH_RANGE["nova"]) * area_mult
			var any := false
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
					continue
				if global_position.distance_to(e.global_position) <= range_:
					e.take_damage(0.0, "", ailment, achance)
					any = true
			if any and world.has_method("spawn_nova"):
				rig.play_lunge()
				world.spawn_nova(global_position + Vector3(0, 0.4, 0), range_, col)
				if GameAudio.instance:
					GameAudio.instance.nova(false)  # cycle 16
			return any
		"beam":
			var range_ := float(GameData.ARCH_RANGE["beam"])
			var target := _nearest_enemy(range_)
			if target == null:
				return false
			var dir: Vector3 = target.global_position - global_position
			dir.y = 0.0
			dir = dir.normalized()
			rig.set_facing(dir)
			rig.play_lunge()
			_attack_face_t = 0.24
			if GameAudio.instance:
				GameAudio.instance.beam(mtype)  # cycle 16
			var dealt_total := 0.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
					continue
				var rel: Vector3 = e.global_position - global_position
				rel.y = 0.0
				var along := rel.dot(dir)
				if along > 0.0 and along <= range_ and Vector3(rel.x - dir.x * along, 0, rel.z - dir.z * along).length() < 1.4:
					dealt_total += e.take_damage(_roll_damage(mv), mtype, ailment, achance, {"crit": _last_crit})
			if world.has_method("add_damage"):
				world.add_damage(dealt_total)
			if world.has_method("add_move_damage"):
				world.add_move_damage(key, dealt_total)  # cycle 18: summary bars
			if world.has_method("spawn_beam"):
				world.spawn_beam(global_position + Vector3(0, 1.0, 0), dir, range_, col)
			return true
	return false

func _nearest_enemy(range_: float) -> Node3D:
	# Cycle 18: target lock (touch tc-lock / settings): a locked
	# target wins over the nearest scan while it stays valid and
	# within 30 u; the lock yields to the normal scan outside it.
	if lock_target != null and is_instance_valid(lock_target) \
			and float(lock_target.get("hp")) > 0.0 \
			and not bool(lock_target.get("is_downed")) \
			and not bool(lock_target.get("is_weakened")):
		var ld := Vector2(lock_target.global_position.x - global_position.x,
			lock_target.global_position.z - global_position.z).length()
		if ld <= range_:
			return lock_target
	var best: Node3D = null
	var best_d := range_
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		if bool(e.get("is_downed")):
			continue  # downed alphas wait for a Friend Ball, not attacks
		# HOTFIX (cycle 11 attack feel): HORIZONTAL distance. The
		# strike/beam hit tests below are already horizontal
		# (d.y = 0) and the bundle's within() is XZ-based — but
		# this gate used full 3D distance, so on cycle 11's
		# quantized terrain a target one 4.6 u terrace step below
		# the player (sqrt(2.3^2 + 4.6^2) ~= 5.1 > 3.6 gate) could
		# never be targeted at all: the player stood next to an
		# enemy and simply never attacked.
		var d := Vector2(e.global_position.x - global_position.x,
			e.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = e
	return best

## Cycle 21: fixed damage (bundle hurt(..., fixed=true) —
## boss pools / vortex): bypasses evasion and armor,
## still routes death through the died signal.
func hurt_fixed(amount: float) -> void:
	if hp <= 0.0 or invulnerable:
		return
	no_hit_t = 0.0
	hp -= amount
	if GameAudio.instance:
		GameAudio.instance.hurt()
	if hp <= 0.0:
		if rig:
			rig.play_faint()
		emit_signal("died")

func take_damage(dmg: float, opts: Dictionary = {}) -> bool:
	if hp <= 0.0 or invulnerable or _invuln_t > 0.0:
		return false
	if randf() < evasion * float(opts.get("evade", 1.0)):
		# Bundle hurt() dodge branch (@819063): iframes = 0.25, a
		# "-" floater over the player, the dodges counter.
		if GameAudio.instance:
			GameAudio.instance.dodge()  # cycle 16
		_invuln_t = 0.25
		if world and world.has_method("count_event"):
			world.count_event("dodges")  # §3 dodges counter (sandshrew)
		if world and world.has_method("spawn_floater"):
			world.spawn_floater(global_position + Vector3(0, 2.2, 0), "-", Color(0.66, 0.91, 0.06))
		return false  # §2.2 evasion roll
	var guard_stacks := item_count("guard-spec")
	if guard_stacks > 0 and guard_t <= 0.0:
		guard_t = 14.0 - 3.0 * float(guard_stacks - 1)
		_invuln_t = 0.4
		if world and world.has_method("count_event"):
			world.count_event("dodges")
		return false
	var raw := dmg
	var attack_type := String(opts.get("type", ""))
	if attack_type != "":
		dmg *= clampf(GameData.type_mult(attack_type, types()), 0.5, 1.6)
	dmg *= 1.0 - armor / (armor + 45.0)
	var hooks := GameData.passive_hooks(passive_id)
	if hooks.has("dmgTaken"):
		dmg *= float(hooks["dmgTaken"])
	if passive_id == "magic-guard" and int(opts.get("source", -1)) < 0:
		dmg *= 0.7
	if passive_id == "multiscale" and hp >= max_hp - 0.5:
		dmg *= 0.5
	if hurt_mod.is_valid():
		dmg = maxf(0.0, float(hurt_mod.call(world, self, dmg, int(opts.get("source", -1)))))
	var floor_frac := float(opts.get("floor", 0.0))
	if floor_frac != 0.0:
		dmg = maxf(dmg, max_hp * floor_frac * (1.0 - 0.35 * (1.0 - minf(1.0, dmg / raw) if raw > 0.0 else 0.0)))
	var cap := float(opts.get("cap", 0.0))
	if cap > 0.0:
		dmg = minf(dmg, max_hp * cap)
	if has_buff("tm-iron"):
		dmg *= 0.4
	var absorbed := minf(overheal, dmg)
	overheal -= absorbed
	dmg -= absorbed
	absorbed = minf(shield, dmg)
	shield -= absorbed
	var reduced := dmg - absorbed
	# Sturdy (bundle hurt()): survive a lethal hit at 1 HP, once
	# per run.
	if passive_id == "sturdy" and not _sturdy_used and reduced >= hp:
		_sturdy_used = true
		reduced = maxf(hp - 1.0, 0.0)
		if world and world.has_method("spawn_floater"):
			world.spawn_floater(global_position + Vector3(0, 2.4, 0), "结实！", Color(0.9, 0.9, 0.95))
	no_hit_t = 0.0
	hp -= reduced
	if reduced > 0.0:
		last_hit = opts.get("attacker", null)
	pstat.erase("sleep")
	if GameAudio.instance:
		GameAudio.instance.hurt()  # cycle 16: bundle hurt()
	# Cycle 13: ult charge from damage taken — the bundle calls
	# ult.onHurt(f / maxHp) with the damage that actually landed
	# (@820982); dodged hits returned above and earn nothing.
	if world and world.has_method("ult_on_player_hurt"):
		world.ult_on_player_hurt(reduced / maxf(max_hp, 1.0))
	if int(opts.get("source", -1)) >= 0:
		_contact_status(opts.get("attacker", null))
	# Bundle hurt() (@821025): iframes = 0.45, flash = 1, hurtT 0.3 /
	# squash 0.5 (the rig's hurt profile), r.kick(.006), shake(.12),
	# ui.damageFlash(). The cycle-8 version set NO iframes here and
	# had no flash/kick/damageFlash channels (audit §2/§8).
	_invuln_t = 0.45
	if rig:
		rig.play_hurt()
	if world:
		if world.has_method("add_trauma"):
			world.add_trauma(0.12)
		if world.has_method("camera_kick"):
			world.camera_kick(0.006)
		if world.has_method("damage_flash"):
			world.damage_flash()
		if world.has_method("vibrate"):
			world.vibrate(30)
		if reduced > 0.0 and world.has_method("spawn_hit_fx"):
			world.spawn_hit_fx(global_position + Vector3(0, 1.0, 0), String(opts.get("type", "fire")), reduced, 1.0, false)
	if hp <= 0.0:
		if rig:
			rig.play_faint()
		emit_signal("died")

	return true
