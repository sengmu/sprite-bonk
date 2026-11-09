class_name Enemy
extends Node3D
## Enemy / guardian / league encounter / captured ally.
## Base stats come from the original's pokemon.json via GameData
## (MECHANICS §1.1 fields); derivations are the bundle's (§1.3):
##   HP   = (12 + bst*0.055) * hpCurve(stage,t) * toughness * flagMult
##   dmg  = (5 + atk/16 + spa/24) * dmgMult * flagMult
##   spd  = min(6.2, 3 + spe/55) * (weight > 2500 ? 0.8 : 1)
## Flag multipliers (§1.3): elite x4.5 HP / x1.4 dmg / x1.35 size,
## alpha x22 / x1.8 / x2.0. Kill XP (§4.4):
##   (1 + bst/300) * (1 + (toughness-1)*0.35) * flagXP (1/6/25/60 boss).
## Capture states (§5): a league encounter at lethal damage weakens
## instead of dying (1% HP, 10 s window, recover 40%); an alpha drops
## to a downed state (1% HP, 8 s window, revive 30%). The world runs
## the throw logic; this class owns the state machine + timers.

signal killed(e)
signal weakened(e)
signal downed(e)
signal recovered(e)

const MODE_WILD := 0
const MODE_GUARDIAN := 1
const MODE_LEAGUE := 2
const MODE_ALLY := 3

const FLAG_XP := {0: 1.0, 1: 6.0, 2: 25.0, 4: 60.0}  # normal/elite/alpha/boss (§4.4)

var species_id := "rattata"
var max_hp := 24.0
var hp := 24.0
var speed := 4.0
var dmg := 9.0

## Cycle 21: outgoing damage — the charm status (loyal-guard
## / intimidate auras) cuts it 40% while it lasts.
func out_dmg() -> float:
	if status_kind == "charm" and status_t > 0.0:
		return dmg * 0.6
	return dmg
var radius := 0.5
var body_height := 1.0
var is_guardian := false
# Cycle 22: bundle R.Object units (lapras's ice pillars):
# attackable, but no AI, no contact, no kill credit.
var is_object := false
# Cycle 22: bundle R.Treasure (the golden meowth): flee
# steering in _hostile_process; hits and the kill route
# through the world's stage-event hooks.
var treasure := false
# Cycle 22: per-unit kill-XP multiplier (fog event
# spawns earn x2 in the bundle).
var weight := 1.0  # C23 drop wt (ordinary bodies have weight one)
var xp_mult := 1.0
var boss_hold := false  # cycle 21: the world boss brain
	# holds the guardian (casts / charges) — hostile AI off
var mode := MODE_WILD
var flag := 0  # bit flags: Elite=1, Alpha=2, Boss=4, Flying=16 (§附录 B)
var bst := 0.0
var capture_rate := 255
var types: Array = []
var capture_attempts := 0  # per-generation memory (§5.3)
var status_kind := ""  # "sleep" (frozen) / "burn" / "poison" (DoT)
var status_t := 0.0
var wet_t := 0.0  # cycle 14: PARALLEL wet timer — the bundle keeps
	# per-status arrays (@337234); wet never occupies the slot above
var _soaked_counted := false
# Cycle 15: reaction-layer parallel state (the bundle's status
# arrays are all parallel; our slot keeps move-applied kinds).
# poison_stacks feeds the gas reaction (applyStatus @731739:
# each poison application assigns 5x duration and stacks+1,
# cap 10); confuse_t/root_t are written RAW by the steam /
# mind reactions (x resist, no duration-factor scaling).
var poison_stacks := 0
var classic := false  # C24: separate Capture|Classic encounter, never a shiny ally
var ally_slot := 0
var shiny := false  # cycle 20: shiny encounter flag (bundle spawnShiny)
var confuse_t := 0.0
var root_t := 0.0
var pickup_stun_t := 0.0
var _counted: Dictionary = {}  # countOnce channels (confused)
var _wet_vis := false
# Cycle 14 guardian damage cap + exhaust (Eb @995459, boss.exhaust):
var cap_rate := 0.0  # <= 0 -> uncapped (every non-guardian)
var fight_secs := 50.0
var _fight_t := 0.0
var _cap_bank := 0.0
var _cap_t := 0.0
var _cap_clock := 0.0
var last_meter_amount := -1.0  # combat-meter bookkeeping (B_ @720250)
var weak_t := 0.0  # league weakened window remaining
var down_t := 0.0  # alpha downed window remaining
var is_weakened := false
var is_downed := false
var ally_power := 0.0  # legacy field; cycle 9 computes power live (ally_power_now)
var ally_cd_max := 1.6
var ally_physical := true
# Cycle 9 channels: knockback velocity (bundle strike knock: slam
# 3+3o, ally land 2, ally projectile 1 — an impulse that decays;
# decay rate INFERRED at exp(-7t)), guardian roar count (each roar
# = +1 free chest in the guardian reward, bundle onBossKilled), and
# last-hit ally credit (the original credits bond kills via
# lastHitBy >= ally slot, credit() @741771 region).
var _kb_vel := Vector3.ZERO
var roars := 0  # cycle 14: set ONLY at guardian spawn from the
	# run's shrine count (boss.spawn @996027); drives the kill
	# reward's +1 chest per roar (onBossKilled @1462726)
var _last_hit_ally: Enemy = null
## Cycle 13: hit-slot attribution (the bundle's strike slot). Ult
## hits land with slot 8 and status/DoT ticks count as slot 8 too;
## the ult controller's onKill ignores slot-8 kills, so ult and
## DoT kills never refund charge. Direct hits default to 0.
var last_hit_slot := 0
# Ally bond (§5.3, cycle 8): the original's ally record (jh.make(),
# bundle ~@523543) carries kills/bond fields; bond thresholds
# Eh = [25, 75, 150, 300, 500] (@517639) each add +10% ally power
# (onAllyKill @528148). NOTE: the record has NO hp field — allies
# cannot be damaged in the original (see DIFF cycle 8, item 3).
const BOND_THRESHOLDS := [25, 75, 150, 300, 500]
var ally_kills := 0
var bond_level := 0
var _dying := false  # faint animation running; freed when _die_t ends
var _die_t := 0.0
var rig: ModelRig
var target: Node3D
var world: Node

var _touch_cd := 0.0
var _ally_cd := 0.0
var _dot_t := 0.0
var _wander_t := 0.0
var _wander_dir := Vector3.ZERO

static func base_hp(species: String) -> float:
	var s: Dictionary = GameData.species(species)
	return 12.0 + float(s.get("bst", 0)) * 0.055

static func base_speed(species: String) -> float:
	var s: Dictionary = GameData.species(species)
	var st: Dictionary = s.get("stats", {})
	var y := 0.8 if float(s.get("weight", 0)) > 2500.0 else 1.0
	return minf(6.2, 3.0 + float(st.get("spe", 0)) / 55.0) * y

static func base_dmg(species: String) -> float:
	var s: Dictionary = GameData.species(species)
	var st: Dictionary = s.get("stats", {})
	return 5.0 + float(st.get("atk", 0)) / 16.0 + float(st.get("spa", 0)) / 24.0

## Kill XP per §4.4 (weight factor is 1: swarm merging not implemented).
func xp_value(toughness: float) -> float:
	return (1.0 + bst / 300.0) * (1.0 + (toughness - 1.0) * 0.35) * float(FLAG_XP.get(flag, 1.0))

func setup(p_species: String, p_target: Node3D, p_world: Node, hp_mult: float = 1.0, scale_mult: float = 1.0, guardian: bool = false) -> void:
	species_id = p_species
	is_guardian = guardian
	if guardian:
		mode = MODE_GUARDIAN
		flag = 4
	target = p_target
	world = p_world
	var s: Dictionary = GameData.species(p_species)
	bst = float(s.get("bst", 0))
	capture_rate = int(s.get("captureRate", 255))
	types = s.get("types", [])
	max_hp = base_hp(p_species) * hp_mult
	hp = max_hp
	speed = base_speed(p_species)
	dmg = base_dmg(p_species)
	radius = 0.55 * scale_mult
	# 3D port body height: use the shipped model dimensions, not a JS sprite atlas.
	body_height = float(ModelRig.SPECIES.get(p_species, {}).get("height", 1.0)) * scale_mult
	rig = ModelRig.new()
	add_child(rig)
	rig.setup(p_species, scale_mult)
	# Cycle 10: NO world-space HP bar — the original's sprite shader
	# (Rl @113906) has no bar branch and its instanced attributes
	# carry no HP channel; enemy HP reads via damage numbers + hit
	# flash, and the guardian's HP lives in the HUD boss bar
	# (world.gd). See DIFF.md "Cycle 10 — HP-bar alignment".
	add_to_group("enemies")
	_snap_to_ground()

## Convert this instance into a captured ally (§5.3): leaves the enemy
## group, follows the player, and attacks with the original's ally
## model (cycle 9, audit §4): power/cooldown are NOT frozen at
## capture — power(e) (bundle @519822) is recomputed from the
## player's CURRENT level and the current stage on every attack,
## and the cooldown reads the player's CURRENT attack speed.
func make_ally() -> void:
	mode = MODE_ALLY
	var st: Dictionary = GameData.species(species_id).get("stats", {})
	ally_physical = float(st.get("atk", 0)) >= float(st.get("spa", 0))
	ally_kills = 0
	bond_level = 0
	remove_from_group("enemies")
	add_to_group("allies")
	is_downed = false
	down_t = 0.0
	hp = max_hp

## power(e) @519822: (12 + 1.1 * playerLevel) * (0.75 + bst/800) *
## (1 + 0.25 * (min(3, stage) - 1)) * (1 + 0.1 * bond) * shiny(1.2 —
## C24 shiny ally) * lemonade item (not ported).
func ally_power_now() -> float:
	if world == null or world.get("player") == null:
		return ally_power
	var p = world.player
	var stage := mini(3, int(world.get("zone")))
	return (12.0 + 1.1 * float(p.level)) * (0.75 + bst / 800.0) \
		* (1.0 + 0.25 * float(stage - 1)) * bond_mult() * (1.2 if shiny else 1.0)

## cooldown(e) @519822: (physical 1.8 / special 1.6) / sqrt(player
## attackSpeed), read live.
func ally_cd_now() -> float:
	if world == null or world.get("player") == null:
		return ally_cd_max
	return (1.8 if ally_physical else 1.6) / sqrt(maxf(float(world.player.get("atk_speed")), 0.05))

## Knockback channel (cycle 9): strike's knock is a velocity impulse
## away from the hit source. Set (not accumulated); decays in physics.
func apply_knockback(from_pos: Vector3, power: float) -> void:
	var dir: Vector3 = global_position - from_pos
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = -global_transform.basis.z
		dir.y = 0.0
	dir = dir.normalized()
	var v := dir * power
	if v.length() > _kb_vel.length():
		_kb_vel = v

## Failed Friend Ball (§5.3): the alpha gets back up at 30% HP and
## keeps fighting; its attempt count persists for the next knockdown.
func friend_ball_fail() -> void:
	is_downed = false
	down_t = 0.0
	hp = max_hp * 0.3

## Removed by a successful capture (no killed signal, no drops).
func capture_remove() -> void:
	remove_from_group("enemies")
	queue_free()

func _die_real() -> void:
	if _dying:
		return
	hp = 0.0
	_dying = true
	_die_t = 0.35  # bundle dying[e] = 0.35 (@739397), fade w = 1 - dying/0.35
	emit_signal("killed", self)
	remove_from_group("enemies")
	# Bond credit (§5.3): the killing blow's ally gets the kill
	# (original: lastHitBy slot check in credit()).
	if _last_hit_ally and is_instance_valid(_last_hit_ally):
		_last_hit_ally._ally_credit_kill()
	# Cycle 9: the corpse FADES over 0.35 s (rig fade channel) —
	# the cycle-8 tip-over collapse was invented; the original's
	# enemies hold their hurt frame and fade (audit §1).
	if rig:
		rig.play_faint()

func apply_status(kind: String, secs: float) -> void:
	# Cycle 14: the bundle scales every applyStatus duration by the
	# attacker's stats.duration (applyStatus @731454). Our callers
	# are all player/weather-sourced, so the player's duration_mult
	# applies centrally (exactly 1.0 until a blessing/lab raises it,
	# so every standing duration check stays exact).
	status_kind = kind
	status_t = maxf(status_t, secs * _duration_mult())

func _duration_mult() -> float:
	if world and world.get("player"):
		var pl = world.get("player")
		if is_instance_valid(pl):
			return float(pl.get("duration_mult"))
	return 1.0

## Cycle 14 wet application (applyStatus @731454): parallel timer,
## ASSIGN 5 x attacker duration factor; 'soaked' counts once per
## enemy lifetime (countOnce(e, 64, 'soaked')).
func apply_wet_status() -> void:
	wet_t = 5.0 * _duration_mult()
	_count_soaked()

## Rain ambient (weatherFx @1489897): wet = max(wet, 2) raw — no
## duration scaling; the caller gates the counter (timed rain only).
func apply_wet_raw(secs: float, count: bool) -> void:
	wet_t = maxf(wet_t, secs)
	if count:
		_count_soaked()

func _count_soaked() -> void:
	if _soaked_counted:
		return
	_soaked_counted = true
	_count_status("soaked")

## Cycle 15: the bundle's countOnce(e, bit, name) — a counter
## increments at most once per enemy lifetime (steam / mind
## confusion use bit 32 'confused', @733964 / @735500).
func count_once(key: String, counter: String) -> void:
	if bool(_counted.get(key, false)):
		return
	_counted[key] = true
	_count_status(counter)

## reactions' resist(e): guardian (boss flag) 0.35, elite /
## alpha (flags&12290 class) 0.6, else 1.
func resist_factor() -> float:
	if flag == 4:
		return 0.35
	if flag == 1 or flag == 2:
		return 0.6
	return 1.0

## Cycle 15: the ailment arms of take_damage, extracted so
## reaction code (wildfire's burn spread) applies a status
## with the SAME durations and counters as a landed hit.
## Poison: 5.0 s (applyStatus @731739 — was 3.0 flat, a
## pre-cycle-15 deviation) and stacks+1 (cap 10).
func apply_ailment(ailment: String) -> void:
	match ailment:
		"sleep":
			apply_status("sleep", 2.5)
			_count_status("slept")
		"burn":
			apply_status("burn", 3.0)
			_count_status("burned")
		"poison":
			apply_status("poison", 5.0)
			poison_stacks = mini(10, poison_stacks + 1)
			_count_status("poisoned")
		"paralysis":
			apply_status("paralyze", 3.0)
			_count_status("paralyzed")
		"confusion":
			apply_status("confuse", 3.0)
			_count_status("confused")
		"freeze":
			apply_status("freeze", 2.0)
			_count_status("frozen")
			if wet_t > 0.0:
				# Bundle freeze path (@731454): a wet target's
				# chill jumps straight to the freeze threshold
				# and the freeze CONSUMES the wet. Our engine's
				# freeze is already instant — the consume is the
				# portable half.
				wet_t = 0.0
		"wet":
			# Cycle 14: wet lands on the PARALLEL timer, never
			# the single slot (applyStatus @731454).
			apply_wet_status()
		"stun":
			apply_status("stun", 1.0)
		"root":
			# Cycle 13: the bundle's applyStatus switch
			# (@732957) — root[e] = 2 x attacker factor =
			# 2.0 s for the player. Blocks movement via
			# _frozen() but earns NEITHER the sleep x1.8
			# nor the freeze x1.2 strike multiplier.
			apply_status("root", 2.0)

## Cycle 14 (Eb @995459): arm the guardian damage cap — the bank
## starts full at 3x capRate and refills at capRate/s.
func set_damage_cap(rate: float) -> void:
	cap_rate = rate
	_cap_bank = rate * 3.0
	_cap_t = _cap_clock

func _cap_hit(dmg: float) -> float:
	var avail := minf(cap_rate * 3.0, _cap_bank + maxf(0.0, _cap_clock - _cap_t) * cap_rate)
	var dealt := minf(dmg, avail)
	_cap_bank = avail - dealt
	_cap_t = _cap_clock
	return dealt

func has_capture_status() -> bool:
	return status_kind == "sleep" and status_t > 0.0

func _snap_to_ground() -> void:
	if world and world.has_method("surface_at"):
		global_position.y = world.surface_at(global_position.x, global_position.z)

func _frozen() -> bool:
	return pickup_stun_t > 0.0 or _frozen_without_pickup()

func _frozen_without_pickup() -> bool:
	return is_weakened or is_downed or root_t > 0.0 or (status_kind == "sleep" and status_t > 0.0) \
		or (status_kind == "stun" and status_t > 0.0) \
		or (status_kind == "freeze" and status_t > 0.0) \
		or (status_kind == "root" and status_t > 0.0)

func _physics_process(delta: float) -> void:
	# Cycle 9 (audit §8): the world-clock gate comes FIRST — corpses
	# included. Cycle 8 ticked _die_t before the pause check, so
	# corpses kept fading while the world was paused. Hitstop (the
	# new world channel) freezes bodies AND rigs the same way.
	var world_running := world != null and world.get("running") != null and bool(world.get("running"))
	var frozen := world != null and world.has_method("hitstop_active") and bool(world.hitstop_active())
	if rig:
		var want := Node.PROCESS_MODE_DISABLED if (frozen or not world_running) else Node.PROCESS_MODE_INHERIT
		if rig.process_mode != want:
			rig.process_mode = want
	if not world_running or frozen:
		return
	if _dying:
		_die_t -= delta
		if _die_t <= 0.0:
			queue_free()
		return
	if hp <= 0.0:
		return
	_touch_cd -= delta
	_ally_cd -= delta
	# --- cycle 14: cap clock, guardian fight clock, wet timer ---
	_cap_clock += delta
	if is_guardian:
		_fight_t += delta
	if wet_t > 0.0:
		wet_t = maxf(0.0, wet_t - delta)
	if rig and (wet_t > 0.0) != _wet_vis:
		_wet_vis = wet_t > 0.0
		rig.set_wet(_wet_vis)
	# --- cycle 15: parallel reaction timers decay ---
	if confuse_t > 0.0:
		confuse_t = maxf(0.0, confuse_t - delta)
	if root_t > 0.0:
		root_t = maxf(0.0, root_t - delta)
	# --- status timers / DoT ---
	pickup_stun_t = maxf(0.0, pickup_stun_t - delta)
	if status_t > 0.0:
		status_t -= delta
		if status_kind in ["burn", "poison"]:
			_dot_t -= delta
			if _dot_t <= 0.0:
				_dot_t = 1.0
				_dot_tick(4.0)
		if status_t <= 0.0:
			# Cycle 15: poison expiry ends the stack count
			# (single-slot adaptation — DIFF cycle 15, gas).
			if status_kind == "poison":
				poison_stacks = 0
			status_kind = ""
	# --- capture windows ---
	if is_weakened:
		weak_t -= delta
		if weak_t <= 0.0:
			is_weakened = false
			hp = max_hp * 0.4  # §5.2 recover(): back to 40%, roaming again
			emit_signal("recovered", self)
		return
	if is_downed:
		down_t -= delta
		if down_t <= 0.0:
			# §5.3: no throw inside the window -> it really dies
			# (normal drops). Only a FAILED throw revives it (30%).
			is_downed = false
			_die_real()
		return
	if target == null or not is_instance_valid(target):
		return
	# Pickup stun stops autonomous AI, while repel's physical impulse
	# continues immediately. Preserve the older root/sleep/freeze gates.
	var pickup_only_stun := pickup_stun_t > 0.0 and not _frozen_without_pickup()
	if _frozen():
		if rig:
			rig.set_move_speed(0.0)
		if not pickup_only_stun:
			return
	if is_object:
		return  # cycle 22: objects never move, chase or touch
	if not pickup_only_stun:
		match mode:
			MODE_ALLY:
				_ally_process(delta)
			MODE_LEAGUE:
				_league_process(delta)
			_:
				_hostile_process(delta)
	# Knockback channel (cycle 9): impulse velocity with exp decay,
	# integrated after the mode's own movement.
	if _kb_vel.length() > 0.05 and not is_weakened and not is_downed:
		var next := global_position + _kb_vel * delta
		if world and world.has_method("collide_circle"):
			next = world.collide_circle(next, radius)
		next.x = clamp(next.x, -168.0, 168.0)
		next.z = clamp(next.z, -168.0, 168.0)
		global_position = Vector3(next.x, 0.0, next.z)
		_snap_to_ground()
		_kb_vel *= exp(-7.0 * delta)
	elif _kb_vel != Vector3.ZERO and (is_weakened or is_downed):
		_kb_vel = Vector3.ZERO

func _move_toward(dir: Vector3, spd: float, delta: float, separation: bool) -> void:
	# Status movement effects (cycle 9): paralysis halves speed,
	# confusion wobbles the heading (the bundle keeps separate
	# para/frozen/sleep timers; our single slot carries one kind).
	if status_t > 0.0:
		if status_kind == "paralyze":
			spd *= 0.5
		elif status_kind == "confuse" and dir.length() > 0.01:
			var wob := sin(Time.get_ticks_msec() * 0.006 + float(get_instance_id() % 89))
			dir = dir.rotated(Vector3.UP, wob * 0.8)
	# Cycle 15: reaction confusion lives on the parallel
	# timer (the bundle's para/frozen/sleep/confuse timers
	# are all parallel) — same heading-wobble channel.
	if confuse_t > 0.0 and dir.length() > 0.01 and not (status_t > 0.0 and status_kind == "confuse"):
		var wob2 := sin(Time.get_ticks_msec() * 0.006 + float(get_instance_id() % 89))
		dir = dir.rotated(Vector3.UP, wob2 * 0.8)
	var vel := dir * spd
	if separation:
		var sep := Vector3.ZERO
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == self or not is_instance_valid(e):
				continue
			var d: Vector3 = global_position - e.global_position
			d.y = 0.0
			var l := d.length()
			if l > 0.01 and l < 1.6:
				sep += d.normalized() * (1.6 - l)
		vel = (dir + sep * 0.7).normalized() * spd if dir.length() > 0.01 else sep * 2.0
	var next := global_position + vel * delta
	if world and world.has_method("collide_circle"):
		next = world.collide_circle(next, radius)
	next.x = clamp(next.x, -168.0, 168.0)
	next.z = clamp(next.z, -168.0, 168.0)
	global_position = Vector3(next.x, 0.0, next.z)
	_snap_to_ground()
	if rig:
		if vel.length() > 0.1:
			rig.set_facing(vel.normalized())
		rig.set_move_speed(vel.length())

func contact_reaches() -> bool:
	if target == null or _frozen() or is_object or treasure or mode == MODE_LEAGUE or (flag & 16512) != 0:
		return false
	var delta_pos := target.global_position - global_position
	return Vector2(delta_pos.x, delta_pos.z).length() < radius + Player.RADIUS and absf(delta_pos.y) < body_height + 0.8

func _hostile_process(delta: float) -> void:
	# Cycle 21: while the boss brain holds the guardian
	# (casting, charging, beaming), the chase/contact AI
	# stands down — the world drives the body.
	if is_guardian and boss_hold:
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir: Vector3 = to / maxf(dist, 0.001)
	if treasure:
		# Cycle 22: bundle Treasure steering (@332566) —
		# run directly away with a sin sway (x.8 lateral),
		# and past 18 u switch to a tangential orbit.
		var sway := sin(_cap_clock * 1.7) * 0.8
		var flee := -dir + Vector3(dir.z, 0, -dir.x) * sway
		if dist > 18.0:
			flee = Vector3(dir.z, 0, -dir.x)
		_move_toward(flee.normalized(), speed, delta, true)
	elif dist >= radius + Player.RADIUS:
		_move_toward(dir, speed, delta, true)
	else:
		_move_toward(Vector3.ZERO, 0.0, delta, true)
		if rig:
			rig.set_facing(dir)
	# Contact attack (timed, like the original's basic attacks).
	if contact_reaches() and _touch_cd <= 0.0 and target.has_method("take_damage"):
		_touch_cd = 1.0
		if world and world.has_method("contact_hurt"):
			if world.contact_hurt(self):
				var shove_power := 9.0 if (flag & 12294) != 0 or is_guardian else 3.0 + minf(4.0, radius * 2.5)
				target.set("_vel", (target.get("_vel") as Vector3) + dir * shove_power)
		else:
			target.take_damage(out_dmg())
		if rig:
			rig.play_lunge()

func _league_process(delta: float) -> void:
	# Roaming encounter (§5.2): wanders, never attacks. The world owns
	# the 150 s escape timer and the throw interaction.
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.0, 4.0)
		var a := randf() * TAU
		_wander_dir = Vector3(cos(a), 0, sin(a))
	_move_toward(_wander_dir, speed * 0.45, delta, false)

func _ally_process(delta: float) -> void:
	# Follow the player; engage the nearest enemy inside 26 u (§5.3).
	var foe: Node3D = null
	var best := 26.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		if bool(e.get("is_weakened")) or bool(e.get("is_downed")):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d < best:
			best = d
			foe = e
	var anchor: Vector3 = target.global_position
	if foe != null:
		var to: Vector3 = foe.global_position - global_position
		to.y = 0.0
		# Cycle 9 (audit §4): the original's ally attacks are typed
		# combat.hit strikes, not raw HP subtraction. Physical allies
		# hop onto the foe and land() — an AoE around the landing
		# point (r = 2.6 * sqrt(player area), knock 2); special
		# allies fire a homing projectile that explodes
		# (r = 2.2 * sqrt(area), knock 1). Both carry the ally
		# type's J_ status at 20% and the ally's OWN types for STAB
		# (strike's slot>=10 branch, @722351). Our hop is compressed
		# to contact range; the damage model is the bundle's.
		if ally_physical:
			if to.length() > 1.7:
				_move_toward(to.normalized(), speed * 1.15, delta, false)
			else:
				if rig:
					rig.set_facing(to.normalized())
					rig.set_move_speed(0.0)
				if _ally_cd <= 0.0:
					_ally_cd = ally_cd_now()
					if rig:
						rig.play_lunge()
					if world and world.has_method("ally_land"):
						world.ally_land(self)
		else:
			if to.length() > 10.0:
				_move_toward(to.normalized(), speed * 1.15, delta, false)
			else:
				if rig:
					rig.set_facing(to.normalized())
					rig.set_move_speed(0.0)
				if _ally_cd <= 0.0:
					_ally_cd = ally_cd_now()
					if rig:
						rig.play_lunge()
					if world and world.has_method("ally_shoot"):
						world.ally_shoot(self, foe)
	else:
		var to: Vector3 = anchor - global_position
		to.y = 0.0
		if to.length() > 3.2:
			_move_toward(to.normalized(), speed * 1.1, delta, false)
		elif rig:
			rig.set_move_speed(0.0)

## §5.3 bond: +10% ally power per bond level (bundle onAllyKill).
func bond_mult() -> float:
	return 1.0 + 0.1 * float(bond_level)

func _ally_credit_kill() -> void:
	ally_kills += 1
	var lvl := 0
	for th in BOND_THRESHOLDS:
		if ally_kills >= int(th):
			lvl += 1
	if lvl > bond_level:
		bond_level = lvl
		if world and world.has_method("show_banner"):
			world.show_banner("💚 羁绊 Lv." + str(lvl) + "！队友攻击 +10%", 2.0)

func _dot_tick(d: float) -> void:
	if is_weakened or is_downed or mode == MODE_ALLY:
		return
	# Cycle 13: status ticks are slot-8 hits in the bundle (their
	# damage flows through combat.hit with slot 8), so a DoT kill
	# must not feed the ult gauge.
	last_hit_slot = 8
	# Cycle 14: DoT passes the guardian damage cap too (hit0 applies
	# capHit to every channel) and feeds the combat meter (@737969).
	var dd := d
	if cap_rate > 0.0:
		dd = _cap_hit(dd)
	hp -= dd
	if world and world.has_method("meter_add"):
		world.meter_add(self, minf(dd, hp + dd))
	if hp <= 0.0:
		_lethal()

func _count_status(counter: String) -> void:
	if world and world.has_method("count_run_event"):
		world.count_run_event(counter)

## Returns the damage actually dealt (after the type chart and the
## status multipliers) so callers can accumulate the run's damage
## stat (§8 scoring). fx (cycle 9, optional): {knock: float,
## from: Vector3, ally: Enemy} — strike's knockback channel and the
## lastHitBy ally credit for bond kills.
## C23 pickup effects bypass combat multipliers/caps, retain lethal capture routing.
func pickup_fixed_damage(amount: float) -> float:
	if hp <= 0.0 or is_downed or is_weakened or mode == MODE_ALLY:
		return 0.0
	_last_hit_ally = null
	last_hit_slot = 0
	var dealt := minf(hp, amount)
	hp -= amount
	if hp <= 0.0:
		_lethal()
	return dealt

## Raw status timers: pickup durations already include resistance, not duration stat.
func pickup_stun(secs: float) -> void:
	pickup_stun_t = maxf(pickup_stun_t, secs)

func take_damage(d: float, move_type: String = "", ailment: String = "", ailment_chance: float = 0.0, fx: Dictionary = {}) -> float:
	last_meter_amount = -1.0
	if hp <= 0.0 or is_weakened or is_downed or mode == MODE_ALLY:
		return 0.0
	var dealt := d
	if move_type != "":
		dealt *= GameData.type_mult(move_type, types)
	# Elite damage stat (pressure / rivalry / mold-breaker passives,
	# cycle 9): the player's own hits on guardians and alphas scale
	# by the player's eliteDamage multiplier (bundle strike flags
	# step). Ally hits are excluded (fx carries the ally).
	if not fx.has("ally") and (is_guardian or flag == 2) and world and world.get("player"):
		var pl = world.get("player")
		if is_instance_valid(pl):
			dealt *= float(pl.get("elite_mult"))
	# strike() status multipliers (cycle 9, audit §3): a sleeping
	# target takes x1.8 and WAKES on the hit (bundle @725615:
	# sleep[e] = 0 after damage, barring the unported awakening
	# item); a frozen target takes x1.2 (@723851 region). "stun"
	# is a separate timer in the bundle and earns NEITHER.
	var wake := false
	if status_t > 0.0 and status_kind == "sleep":
		dealt *= 1.8
		wake = true
	# Cycle 21: boss mech hitMul (bundle hit0 consults the
	# mech: kingler guard facing, cloyster shell, gyarados
	# recharge...). Player-sourced hits only (not ally fx).
	if is_guardian and not fx.has("ally") and world and world.has_method("boss_hit_mul"):
		dealt *= float(world.boss_hit_mul(self))
	if status_t > 0.0 and status_kind == "freeze":
		dealt *= 1.2
		# Cycle 21: ice-heal (bundle damage() @724834): a
		# typed, non-ally player hit on a frozen target while
		# holding ice-heal shatters the ice — x1.6 + .3 per
		# extra stack, the freeze clears, and the shatter
		# freezes every other enemy within 2.5 u (world hook).
		if move_type != "" and not fx.has("ally") and world and world.get("player"):
			var pl2 = world.get("player")
			if is_instance_valid(pl2):
				var stacks := int(pl2.call("item_count", "ice-heal"))
				if stacks > 0:
					dealt *= 1.6 + 0.3 * float(stacks - 1)
					status_t = 0.0
					status_kind = ""
					if world.has_method("ice_shatter"):
						world.ice_shatter(self)
	# Cycle 14: guardian exhaust + damage cap (boss.exhaust / Eb
	# @995459). Past 2x fightSecs the guardian takes 2^(over/20)
	# damage; the cap then clamps to the refilling bank. Both sit
	# AFTER every other multiplier, exactly like hit0 (@727338),
	# and the combat meter records the post-cap amount divided by
	# the exhaust factor for bosses, min(dealt, hp) otherwise
	# (hit0's meter feed @727415).
	var exhaust_f := 1.0
	if is_guardian:
		var over := _fight_t - 2.0 * fight_secs
		if over > 0.0:
			exhaust_f = minf(1e9, pow(2.0, over / 20.0))
			dealt *= exhaust_f
	if cap_rate > 0.0:
		dealt = _cap_hit(dealt)
	last_meter_amount = minf(dealt, hp) / exhaust_f
	hp -= dealt
	# Cycle 16: the bundle's strike() plays hit(effectiveness)
	# on every landed hit (audio class @82036) — pitch follows
	# the type chart. Status-only applications (dealt 0) and
	# DoT ticks (which bypass take_damage) stay silent.
	if dealt > 0.0 and GameAudio.instance:
		GameAudio.instance.hit(GameData.type_mult(move_type, types) if move_type != "" else 1.0)
	if wake:
		status_kind = ""
		status_t = 0.0
	# lastHitBy semantics: EVERY direct hit rewrites the credit —
	# a player hit (no ally in fx) clears a stale ally mark.
	_last_hit_ally = fx.get("ally")
	last_hit_slot = int(fx.get("slot", 0))
	if fx.has("knock") and hp > 0.0:
		apply_knockback(fx.get("from", global_position), float(fx["knock"]))
	# Cycle 14 REMOVES the cycle-9 threshold roars: the bundle
	# assigns boss.roars ONLY at spawn from run.roars (the Rhydon
	# shrine count, boss.spawn @996027) — no HP-threshold trigger
	# exists. world.summon_guardian sets `roars` before the fight.
	# Status application (percent chance, the bundle's
	# applyStatus(statusChance) shape). Cycle 9 extends the
	# cycle-7 sleep/burn/poison subset with paralysis / confusion
	# / freeze / stun — statuses the engine now carries — and
	# counts every application for the roster counters.
	if ailment != "" and hp > 0.0 and randf() * 100.0 < ailment_chance:
		# Cycle 15: a slot-writing non-poison application
		# overwriting the poison slot ends the stack count
		# (single-slot adaptation — see DIFF cycle 15, gas).
		# "wet" never touches the slot, so it is excluded.
		if status_kind == "poison" and ailment in ["sleep", "burn", "paralysis", "confusion", "freeze", "stun", "root"]:
			poison_stacks = 0
		apply_ailment(ailment)
	# Hit response (cycle 9): flash + squash on the rig — the
	# original's only reaction channels (audit §1).
	if rig and hp > 0.0 and not is_weakened and not is_downed:
		rig.play_hurt()
	# Cycle 22: the bundle's hit0 fires events.onHit for
	# Treasure-flagged units on every landed hit, killing
	# blows included (@727019).
	if treasure and dealt > 0.0 and world and world.has_method("event_hit"):
		world.event_hit(self)
	if hp <= 0.0:
		_lethal()
	return dealt

func _lethal() -> void:
	if mode == MODE_LEAGUE:
		# §5.2: a league encounter doesn't die — it weakens at 1% HP.
		hp = max_hp * 0.01
		is_weakened = true
		weak_t = 10.0
		status_kind = ""
		status_t = 0.0
		if rig:
			rig.set_flash(1.0)  # bundle faint(): flash[e] = 1 (@520541)
		emit_signal("weakened", self)
		return
	if flag == 2:
		# §5.3: a downed alpha waits for a Friend Ball (8 s window).
		hp = max_hp * 0.01
		is_downed = true
		down_t = 8.0
		status_kind = ""
		status_t = 0.0
		if rig:
			rig.set_flash(1.0)  # bundle faint(): flash[e] = 1 (@520541)
		emit_signal("downed", self)
		return
	_die_real()
