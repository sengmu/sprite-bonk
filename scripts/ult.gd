class_name Ult
extends RefCounted

## Cycle 13 — the ultimate （必） controller: a port of the bundle's
## ult class (main-CkI7dQhz, class defined right after byte
## ~1394600; constants pD=95, mD=.004, hD=.024, gD=40 on one line).
## Full spec with byte offsets lives in DIFF.md "Cycle 13".
##
## One instance per run (World.start_game creates it; World
## ._process ticks update()). Every damage number flows through
## World.combat_hit with slot 8 — the bundle's wg() (@618671) —
## so ult kills never refund charge (onKill ignores slot 8).
##
## Deliberate non-ports (named in DIFF): the drones/risers
## sub-controllers belong to OTHER species' ults; the soul-dew /
## poke-flute rate factors are item-gated and we have no item
## system; the "wet" status has no layer in our engine (cycle 12
## gap) — squirtle's casts deal their full damage/knock/drag and
## simply do not apply wet.

const P_FULL := 95.0        # pD: passive seconds to a full bar
const KILL_PLAIN := 0.004   # mD: plain-kill credit (room-throttled)
const ROOM_CAP := 0.024     # hD: killRoom cap, also its refill / s
const BASE_DMG := 40.0      # gD: cast damage base
const STAGE_MULT := [1.0, 1.8, 3.2, 4.0]  # j_ @719436 (== slam table)
const ZONE_TICK := 0.45     # Hv ground-zone tick interval @771563
const READY_RING := Color(1.0, 0.839, 0.29)  # 16765498 gold

## Starter ult definitions (Bg literal @627348; EN names from the
## en chunk — offsets in DIFF). dur/names are per evolution form.
const DEFS := {
	1: {"type": "grass", "cls": "special", "tint": 7002186,
		"dur": [1.6, 2.0, 2.6],
		"names": ["Furious Roots", "Frenzy Plant", "Giga Flower Whip"]},
	4: {"type": "fire", "cls": "special", "tint": 16738858,
		"dur": [1.2, 1.8, 3.0],
		"names": ["Rising Blaze", "Blast Burn", "Giga Blaze"]},
	7: {"type": "water", "cls": "special", "tint": 4892927,
		"dur": [2.4, 1.6, 2.8],
		"names": ["Shell Whirlpool", "Tidal Wave", "Hydro Cannon"]},
}

## Cycle 18 (audit §7): CN display names for the ults — the
## bundle's names are EN-only, and every other name in the UI
## shows CN + EN. Display sites compose "CN EN" via name_zh.
const NAMES_ZH := {
	"Furious Roots": "狂怒根须", "Frenzy Plant": "疯狂藤蔓",
	"Giga Flower Whip": "巨花藤鞭",
	"Rising Blaze": "升腾烈焰", "Blast Burn": "爆裂燃烧",
	"Giga Blaze": "终极烈焰",
	"Shell Whirlpool": "甲壳漩涡", "Tidal Wave": "滔天巨浪",
	"Hydro Cannon": "强力水炮",
}

static func display_name(en_name: String) -> String:
	var zh := String(NAMES_ZH.get(en_name, ""))
	return zh if zh != "" else en_name

var world  # the World (untyped cross-ref, project idiom)

var charge := 0.0
var active := 0.0
var uses := 0
var kill_room := ROOM_CAP
var deny_t := 0.0
var deny_count := 0  # harness diagnostic (the bundle only plays a sound)
var fissures_spawned := 0  # harness diagnostics
var zones_spawned := 0

var _hold_ok := true
var _r_key_was := false
var _button_latch := false
var rng := RandomNumberGenerator.new()

var _timers: Array = []     # {t: float, fn: Callable} — their later()
var _fissures: Array = []   # kg walkers
var _waves: Array = []      # jg ring waves
var _zones: Array = []      # Hv ground zones (own their visual node)
var _repeaters: Array = []  # W() timed repeaters

func _init(w) -> void:
	world = w
	# Fixed seed: scatter is distribution-equivalent to the
	# original's Math.random and deterministic under the harness
	# (the cycle-12 weather pattern).
	rng.seed = 0xC13

func dispose() -> void:
	for z in _zones:
		var n: Node = z.get("node")
		if n and is_instance_valid(n):
			n.queue_free()
	_zones.clear()
	_timers.clear()
	_fissures.clear()
	_waves.clear()
	_repeaters.clear()

# ------------------------------------------------------------ def access

func family_dex() -> int:
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return 0
	return GameData.roster_id_for_species(String(p.get("base_species")))

func def() -> Dictionary:
	return DEFS.get(family_dex(), {})

func form() -> int:
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return 0
	return int(GameData.species(String(p.get("species_id"))).get("evoStage", 0))

func tier() -> int:
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return 0
	return mini(2, form() + int(p.get("growth")))

func ult_name() -> String:
	var d := def()
	if d.is_empty():
		return ""
	var names: Array = d["names"]
	return String(names[mini(form(), names.size() - 1)])

func cast_dur() -> float:
	var d := def()
	if d.is_empty():
		return 0.0
	var ds: Array = d["dur"]
	return float(ds[mini(form(), ds.size() - 1)])

func tint_color() -> Color:
	var d := def()
	if d.is_empty():
		return READY_RING
	var t := int(d["tint"])
	return Color(float((t >> 16) & 255) / 255.0,
		float((t >> 8) & 255) / 255.0, float(t & 255) / 255.0)

func ready() -> bool:
	return charge >= 1.0

## rate(): lunar-blessing x1.3 (passive-gated) x lab "ult"
## (+4%/level). Soul-dew x1.4 / poke-flute x1.25 are item-gated —
## no item system in our build.
func rate() -> float:
	var r := 1.0
	var p = world.get("player")
	if p != null and is_instance_valid(p) \
			and String(p.get("passive_id")) == "lunar-blessing":
		r *= 1.3
	r *= 1.0 + 0.04 * float(GameProfile.lab_level("ult"))
	return r

# ------------------------------------------------------------- charging

## add(x): a hard no-op while an ult is active; on the crossing
## to ready, the bundle fires a gold ring + a toast.
func add(x: float) -> void:
	if active > 0.0:
		return
	var was := charge
	charge = minf(1.0, charge + x * rate())
	if was < 1.0 and charge >= 1.0:
		var p = world.get("player")
		if p != null and is_instance_valid(p):
			world.spawn_nova(p.global_position, 3.0, READY_RING)
			# UI-mobile P1.1: the verb follows the device.
			world.show_banner("必杀技就绪！%s释放：%s" % [world.call("_ik_ult"), display_name(ult_name())], 2.5)

## onKill(flags, slot) @1395922: slot 8 (ult hits, DoT ticks)
## earns nothing. Flag mapping: our 4 = their Boss bit, 2 =
## Alpha (their mask is Alpha|12290 — alpha-class bits we don't
## carry), 1 = Elite; plain kills draw on the killRoom throttle.
func on_kill(flag: int, slot: int) -> void:
	if slot == 8:
		return
	if flag == 4:
		add(0.2)
	elif flag == 2:
		add(0.08)
	elif flag == 1:
		add(0.03)
	else:
		var a := minf(KILL_PLAIN, kill_room)
		kill_room -= a
		add(a)

## onHurt(frac): frac = HP damage actually taken / maxHp,
## called from Player.take_damage (bundle hurt() @820982).
func on_hurt(frac: float) -> void:
	add(frac * 0.35)

## The touch button's edge (UltGauge.pressed -> World): latched
## and consumed by update() exactly like a KeyR press.
func press_button() -> void:
	if bool(world.get("running")):
		_button_latch = true

# ----------------------------------------------------------------- tick

func update(dt: float) -> void:
	kill_room = minf(ROOM_CAP, kill_room + ROOM_CAP * dt)
	deny_t = maxf(0.0, deny_t - dt)
	if active > 0.0:
		active = maxf(0.0, active - dt)
	else:
		add(dt / P_FULL)
	_tick_effects(dt)
	# Trigger poll (bundle update): KeyR edge fires or denies;
	# holding R fires the moment the bar fills (holdOk); the
	# autoUlt setting fires when an enemy is within 16.
	var p = world.get("player")
	if p == null or not is_instance_valid(p) or not bool(world.get("running")):
		return
	var st := String(world.get("state"))
	if st != "playing" and st != "guardian" and st != "portal":
		return
	if float(p.get("hp")) <= 0.0:
		return
	var down := Input.is_key_pressed(KEY_R)
	if not down:
		_hold_ok = true
	var hit := (down and not _r_key_was) or _button_latch
	_r_key_was = down
	_button_latch = false
	if hit:
		if ready() and active <= 0.0:
			fire()
		else:
			deny_t = 0.4
			deny_count += 1
			if GameAudio.instance:
				GameAudio.instance.deny()  # cycle 16: the deny veil's sound
	elif (down and _hold_ok and ready() and active <= 0.0) \
			or (bool(GameProfile.setting("autoUlt")) and ready() \
				and active <= 0.0 and _enemy_near(16.0)):
		fire()

func _enemy_near(radius: float) -> bool:
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return false
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and float(e.get("hp")) > 0.0:
			var dx: float = e.global_position.x - p.global_position.x
			var dz: float = e.global_position.z - p.global_position.z
			if dx * dx + dz * dz <= radius * radius:
				return true
	return false

func later(delay: float, fn: Callable) -> void:
	_timers.append({"t": delay, "fn": fn})

func _tick_effects(dt: float) -> void:
	for i in range(_timers.size() - 1, -1, -1):
		var tm: Dictionary = _timers[i]
		tm["t"] = float(tm["t"]) - dt
		if float(tm["t"]) <= 0.0:
			_timers.remove_at(i)
			(tm["fn"] as Callable).call()
	for i in range(_repeaters.size() - 1, -1, -1):
		var rp: Dictionary = _repeaters[i]
		rp["left"] = float(rp["left"]) - dt
		(rp["cb"] as Callable).call(float(rp["dur"]) - float(rp["left"]), dt)
		if float(rp["left"]) <= 0.0:
			_repeaters.remove_at(i)
			(rp["done"] as Callable).call()
	for i in range(_fissures.size() - 1, -1, -1):
		if _tick_fissure(_fissures[i], dt):
			_fissures.remove_at(i)
	for i in range(_waves.size() - 1, -1, -1):
		if _tick_wave(_waves[i], dt):
			_waves.remove_at(i)
	for i in range(_zones.size() - 1, -1, -1):
		if _tick_zone(_zones[i], dt):
			var n: Node = _zones[i].get("node")
			if n and is_instance_valid(n):
				n.queue_free()
			_zones.remove_at(i)

# ----------------------------------------------------------------- fire

func fire() -> void:
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return
	var d := def()
	if d.is_empty():
		return
	var ti := tier()
	# Aim: nearest living enemy within 18 (horizontal), else the
	# rig's facing (+Z, the attack-hotfix convention).
	var ax := 0.0
	var az := 1.0
	var best := 18.0
	var found := false
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		var dx: float = e.global_position.x - p.global_position.x
		var dz: float = e.global_position.z - p.global_position.z
		var dist := sqrt(dx * dx + dz * dz)
		if dist < best:
			best = dist
			found = true
			if dist > 0.01:
				ax = dx / dist
				az = dz / dist
	if not found and p.get("rig") != null:
		var fw: Vector3 = (p.get("rig") as Node3D).global_transform.basis.z
		fw.y = 0.0
		if fw.length() > 0.01:
			fw = fw.normalized()
			ax = fw.x
			az = fw.z
	var stage := clampi(int(world.get("zone")), 1, 4)
	var ctx := {
		"x": p.global_position.x, "y": p.global_position.y,
		"z": p.global_position.z, "ax": ax, "az": az,
		"tier": ti, "form": form(),
		"type": String(d["type"]), "cls": String(d["cls"]),
		"dmg": BASE_DMG * (1.0 + 0.1 * float(p.get("level"))) \
			* STAGE_MULT[stage - 1] * (1.0 + 0.15 * float(ti)),
		"R": sqrt(maxf(float(p.get("area_mult")), 0.01)),
	}
	charge = 0.0
	_hold_ok = false
	active = cast_dur()
	uses += 1
	world.count_run_event("ultimates")
	world.count_event("ultimates")  # lifetime counter, at cast (meta.count)
	# player.onUltimate() is a poke-flute item hook — no-op here.
	p.set("_invuln_t", maxf(float(p.get("_invuln_t")), active + 0.6))
	Input.vibrate_handheld(320)  # eo(.8, 320) rumble approximation
	var quiet := bool(GameProfile.setting("autoUlt"))
	if not quiet:
		# Cycle 16: the bundle ducks the music under the ult
		# (duck(.35, dur + .6) @1397336) and plays the def's own
		# sfx from _cast below.
		if GameAudio.instance:
			GameAudio.instance.duck(0.35, active + 0.6)
		if p.get("rig") != null:
			p.get("rig").play_ult_pose()  # ultPoseT = .6
		if bool(GameProfile.setting("ultPose")):
			world.hitstop(0.32)
			world.show_ult_cutin(display_name(ult_name()), tint_color())
		world.show_ult_look(tint_color(), active + 0.3)
	world.spawn_nova(p.global_position, 4.5, tint_color())
	world.ult_twinkle_fx(p.global_position, tint_color())
	world.add_trauma(0.25)  # shake(.25)
	if String(p.get("passive_id")) == "lunar-blessing":
		p.leech_heal(float(p.get("max_hp")) * 0.15)
	var fam := family_dex()
	later(0.03, _cast.bind(fam, ctx))

func _cast(fam: int, ctx: Dictionary) -> void:
	# Cycle 16: per-def cast one-shots in the bundle's spirit
	# (the real def sfx live in unported move kits; typed
	# generic sounds stand in).
	if GameAudio.instance:
		match fam:
			1: GameAudio.instance.shot("grass")
			4:
				GameAudio.instance.boom(1.0)
				GameAudio.instance.shot("fire")
			7: GameAudio.instance.shot("water")
	match fam:
		1: _cast_roots(ctx)
		4: _cast_blaze(ctx)
		7: _cast_shell(ctx)

# --------------------------------------------------------- hit plumbing
## wg()/q() (@618671/@618777): every ult hit is slot 8, goes
## through combat_hit, status chances convert fraction->percent.

func _hit(ctx: Dictionary, e: Enemy, mul: float, o: Dictionary) -> void:
	var p = world.get("player")
	if p == null or not is_instance_valid(p) or not is_instance_valid(e):
		return
	var opts := {
		"status": String(o.get("status", "")),
		"status_chance": float(o.get("chance", 0.0)) * 100.0,
		"knock": float(o.get("knock", 2.0)),
		"from": p.global_position,
		"slot": 8,
	}
	if o.has("silent") and rng.randf() < float(o["silent"]):
		opts["silent"] = true
	var types: Array = GameData.species(String(p.get("species_id"))).get("types", [])
	world.combat_hit(e, float(ctx["dmg"]) * mul, String(ctx["type"]),
		String(ctx["cls"]), types, opts)

func _q(ctx: Dictionary, x: float, z: float, radius: float,
		mul: float, o: Dictionary, dedupe: Dictionary) -> void:
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		if dedupe.has(e.get_instance_id()):
			continue
		var dx: float = e.global_position.x - x
		var dz: float = e.global_position.z - z
		if dx * dx + dz * dz <= radius * radius:
			dedupe[e.get_instance_id()] = true
			_hit(ctx, e, mul, o)

## Eg drag (~619000): velocity toward the point, x.08 for
## bosses, x.35 for the alpha class, x1 otherwise; only beyond
## .8 u from the centre. Written into the enemy's knockback
## channel (_kb_vel) — re-applied every ult tick like the
## bundle's per-frame velocity set.
func _drag(x: float, z: float, radius: float, strength: float) -> void:
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		var dx: float = x - e.global_position.x
		var dz: float = z - e.global_position.z
		var dist := sqrt(dx * dx + dz * dz)
		if dist <= radius and dist > 0.8:
			var f := 1.0
			if bool(e.get("is_guardian")) or int(e.get("flag")) == 4:
				f = 0.08
			elif int(e.get("flag")) == 2:
				f = 0.35
			e.set("_kb_vel", Vector3(dx / dist * strength * f, 0.0,
				dz / dist * strength * f))

## Dg: the n nearest living enemies, distance jittered x.8-1.2.
func _nearest(x: float, z: float, radius: float, n: int) -> Array:
	var scored: Array = []
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		var dx: float = e.global_position.x - x
		var dz: float = e.global_position.z - z
		var dist := sqrt(dx * dx + dz * dz)
		if dist <= radius:
			scored.append([dist * rng.randf_range(0.8, 1.2), e])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for i in range(mini(n, scored.size())):
		out.append(scored[i][1])
	return out

# -------------------------------------------------------------- fissures
## Ag/kg (@620265 / ~619700): `count` curving fissure walkers,
## steps of 1.5 u at speed 24, heading relaxing x.6 toward the
## fissure angle with +- .55 jitter per step; each walker owns
## its dedupe set and hits with radius width x R per step.

func _ag(ctx: Dictionary, x: float, z: float, count: int, o: Dictionary) -> void:
	var base := rng.randf() * TAU
	var length := float(o.get("len", 12.0))
	var steps := int(ceil(length / 1.5))
	for k in range(count):
		var ang := base + TAU * float(k) / float(count) \
			+ rng.randf_range(-0.15, 0.15)
		_fissures.append({
			"ctx": ctx, "x": x, "z": z, "ang": ang, "base_ang": ang,
			"i": 0, "steps": steps, "acc": 0.0, "iv": 1.5 / 24.0,
			"mul": float(o.get("mul", 1.0)),
			"o": (o.get("o", {}) as Dictionary).duplicate(),
			"width": float(o.get("width", 1.9)),
			"erupt": String(o.get("erupt", "")),
			"hit": {},
		})
		fissures_spawned += 1

func _tick_fissure(f: Dictionary, dt: float) -> bool:
	f["acc"] = float(f["acc"]) + dt
	var ctx: Dictionary = f["ctx"]
	while float(f["acc"]) >= float(f["iv"]) and int(f["i"]) < int(f["steps"]):
		f["acc"] = float(f["acc"]) - float(f["iv"])
		f["i"] = int(f["i"]) + 1
		var ang := float(f["ang"])
		f["x"] = float(f["x"]) + cos(ang) * 1.5
		f["z"] = float(f["z"]) + sin(ang) * 1.5
		f["ang"] = float(f["base_ang"]) \
			+ (ang - float(f["base_ang"])) * 0.6 \
			+ rng.randf_range(-0.55, 0.55)
		_q(ctx, float(f["x"]), float(f["z"]),
			float(f["width"]) * float(ctx["R"]), float(f["mul"]),
			f["o"], f["hit"])
		world.ult_step_fx(Vector3(float(f["x"]), float(ctx["y"]),
			float(f["z"])), String(f["erupt"]), tint_color())
	return int(f["i"]) >= int(f["steps"])

# ----------------------------------------------------------------- waves
## jg (@620361): an expanding ring over 0.9 s; an enemy is hit
## once when the front passes it (inside front+.8, beyond
## front-2.2), dedupe per wave.

func _wave(ctx: Dictionary, x: float, z: float, radius: float,
		mul: float, o: Dictionary) -> void:
	_waves.append({"ctx": ctx, "x": x, "z": z, "radius": radius,
		"mul": mul, "o": o, "t": 0.0, "hit": {}})
	world.spawn_nova(Vector3(x, float(ctx["y"]), z), radius, tint_color())

func _tick_wave(wv: Dictionary, dt: float) -> bool:
	wv["t"] = float(wv["t"]) + dt
	var frac := clampf(float(wv["t"]) / 0.9, 0.0, 1.0)
	var front := lerpf(1.0, float(wv["radius"]), frac)
	var ctx: Dictionary = wv["ctx"]
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		if (wv["hit"] as Dictionary).has(e.get_instance_id()):
			continue
		var dx: float = e.global_position.x - float(wv["x"])
		var dz: float = e.global_position.z - float(wv["z"])
		var dist := sqrt(dx * dx + dz * dz)
		if dist > front - 2.2 and dist < front + 0.8:
			(wv["hit"] as Dictionary)[e.get_instance_id()] = true
			_hit(ctx, e, float(wv["mul"]), wv["o"])
	return float(wv["t"]) >= 0.9

# ----------------------------------------------------------------- zones
## Hv ground zones (@771563): tick every .45 s after an initial
## delay; a tick hits every enemy inside with the stored damage
## (slot 8, knock .2, 50% silent). Visual = a flat tinted disc.

func _add_zone(ctx: Dictionary, x: float, z: float, o: Dictionary) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = float(o["r"])
	mesh.bottom_radius = float(o["r"])
	mesh.height = 0.12
	mesh.radial_segments = 24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c := tint_color()
	mat.albedo_color = Color(c.r, c.g, c.b, 0.35)
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = Vector3(x, float(ctx["y"]) + 0.1, z)
	_zones.append({"ctx": ctx, "x": x, "z": z, "r": float(o["r"]),
		"life": float(o.get("life", 4.0)), "tick": float(o.get("tick0", ZONE_TICK)),
		"dmg": float(o["dmg"]), "o": o.get("o", {}), "node": mi})
	zones_spawned += 1

func _tick_zone(z: Dictionary, dt: float) -> bool:
	z["life"] = float(z["life"]) - dt
	if float(z["life"]) <= 0.0:
		return true
	z["tick"] = float(z["tick"]) - dt
	if float(z["tick"]) > 0.0:
		return false
	z["tick"] = ZONE_TICK
	var ctx: Dictionary = z["ctx"]
	var o: Dictionary = z["o"]
	for e in world.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
			continue
		var dx: float = e.global_position.x - float(z["x"])
		var dz: float = e.global_position.z - float(z["z"])
		if dx * dx + dz * dz <= float(z["r"]) * float(z["r"]):
			var opts := {
				"status": String(o.get("status", "")),
				"status_chance": float(o.get("chance", 0.0)) * 100.0,
				"knock": 0.2, "slot": 8,
				"from": Vector3(float(z["x"]), float(ctx["y"]), float(z["z"])),
			}
			if rng.randf() < 0.5:
				opts["silent"] = true
			var p = world.get("player")
			var types: Array = []
			if p != null and is_instance_valid(p):
				types = GameData.species(String(p.get("species_id"))).get("types", [])
			world.combat_hit(e, float(z["dmg"]), String(ctx["type"]),
				String(ctx["cls"]), types, opts)
	return false

# ------------------------------------------------------------- repeaters
## W(): cb(elapsed, dt) every tick for `dur`, then done().
## NOTE: Callable.bind appends bound args AFTER call-time args,
## so repeater callbacks take (elapsed, dt, ...bound) — the
## whirlpool/cannon tick signatures follow that order.

func _every(dur: float, cb: Callable, done: Callable) -> void:
	_repeaters.append({"left": dur, "dur": dur, "cb": cb, "done": done})

# ------------------------------------------------------------ Bg[1] grass
## Furious Roots / Frenzy Plant / Giga Flower Whip.

func _cast_roots(ctx: Dictionary) -> void:
	var ti := int(ctx["tier"])
	var r := float(ctx["R"])
	var counts := [6, 8, 10]
	var lens := [12.0, 15.0, 17.0]
	_ag(ctx, float(ctx["x"]), float(ctx["z"]), counts[ti], {
		"len": lens[ti] * r, "mul": 1.1, "erupt": "root",
		"o": {"status": "root", "chance": 0.9, "knock": 1.0}})
	if ti >= 1:
		later(0.35, _roots_sun.bind(ctx))
	if ti >= 2:
		for k in range(3):
			later(0.7 + 0.32 * float(k), _roots_petal.bind(ctx, k))

func _roots_sun(ctx: Dictionary) -> void:
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return
	p.leech_heal(float(p.get("max_hp")) * 0.2)
	_q(ctx, float(ctx["x"]), float(ctx["z"]), 9.0 * float(ctx["R"]),
		0.3, {"status": "sleep", "chance": 0.6, "knock": 0.0}, {})
	world.spawn_nova(p.global_position, 9.0 * float(ctx["R"]), tint_color())

func _roots_petal(ctx: Dictionary, k: int) -> void:
	_q(ctx, float(ctx["x"]), float(ctx["z"]),
		(9.0 + 3.0 * float(k)) * float(ctx["R"]), 0.9,
		{"knock": 3.0}, {})
	world.spawn_nova(Vector3(float(ctx["x"]), float(ctx["y"]),
		float(ctx["z"])), (9.0 + 3.0 * float(k)) * float(ctx["R"]),
		tint_color())

# ------------------------------------------------------------- Bg[4] fire
## Rising Blaze / Blast Burn / Giga Blaze.

func _cast_blaze(ctx: Dictionary) -> void:
	var ti := int(ctx["tier"])
	var r := float(ctx["R"])
	var p = world.get("player")
	if p != null and is_instance_valid(p):
		world.ult_flame_jet(p.global_position, tint_color(), 26)
	var rings := 3 if ti >= 1 else 1
	for k in range(rings):
		later(0.18 + 0.22 * float(k), _blaze_ring.bind(ctx, k))
	if ti >= 1:
		_ag(ctx, float(ctx["x"]), float(ctx["z"]), 6, {
			"len": 13.0 * r, "mul": 0.9, "erupt": "magma",
			"o": {"status": "burn", "chance": 0.8, "knock": 2.0}})
	if ti >= 2:
		for c in range(14):
			later(float(c) / 14.0 * 1.8, _meteor_pick.bind(ctx, c))
		later(2.55, _blaze_final.bind(ctx))

func _blaze_ring(ctx: Dictionary, k: int) -> void:
	var r := float(ctx["R"])
	var rad := (8.0 + 3.0 * float(k)) * r
	_q(ctx, float(ctx["x"]), float(ctx["z"]), rad, 1.3,
		{"status": "burn", "chance": 0.9, "knock": 4.0}, {})
	var p = world.get("player")
	if p != null and is_instance_valid(p):
		world.spawn_nova(p.global_position, rad, tint_color())
	world.add_trauma(0.18)
	for i in range(8):
		var a := TAU * float(i) / 8.0 + float(k)
		_add_zone(ctx, float(ctx["x"]) + cos(a) * rad * 0.6,
			float(ctx["z"]) + sin(a) * rad * 0.6, {
				"r": 2.2, "life": 4.0, "tick0": 0.2,
				"dmg": float(ctx["dmg"]) * 0.18,
				"o": {"status": "burn", "chance": 0.5}})

func _meteor_pick(ctx: Dictionary, c: int) -> void:
	var r := float(ctx["R"])
	var targets := _nearest(float(ctx["x"]), float(ctx["z"]), 16.0 * r, 14)
	var tx: float
	var tz: float
	if c < targets.size():
		var e: Node3D = targets[c]
		tx = e.global_position.x + rng.randf_range(-0.6, 0.6)
		tz = e.global_position.z + rng.randf_range(-0.6, 0.6)
	else:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(3.0, 16.0)
		tx = float(ctx["x"]) + cos(a) * dist
		tz = float(ctx["z"]) + sin(a) * dist
	world.spawn_nova(Vector3(tx, float(ctx["y"]), tz), 3.6 * r,
		Color(1.0, 0.4, 0.2))
	later(0.55, _meteor_land.bind(ctx, tx, tz))

func _meteor_land(ctx: Dictionary, tx: float, tz: float) -> void:
	_q(ctx, tx, tz, 3.6 * float(ctx["R"]), 1.2,
		{"status": "burn", "chance": 0.8, "knock": 2.0}, {})
	world.spawn_nova(Vector3(tx, float(ctx["y"]), tz),
		3.6 * float(ctx["R"]), tint_color())
	world.add_trauma(0.12)

func _blaze_final(ctx: Dictionary) -> void:
	var r := float(ctx["R"])
	_q(ctx, float(ctx["x"]), float(ctx["z"]), 13.0 * r, 2.0,
		{"status": "burn", "chance": 1.0, "knock": 6.0}, {})
	_ag(ctx, float(ctx["x"]), float(ctx["z"]), 8, {
		"len": 15.0 * r, "mul": 0.6, "erupt": "magma", "o": {}})
	world.add_trauma(0.5)
	var p = world.get("player")
	if p != null and is_instance_valid(p):
		world.spawn_nova(p.global_position, 13.0 * r, tint_color())

# ------------------------------------------------------------ Bg[7] water
## Shell Whirlpool / Tidal Wave / Hydro Cannon. Cycle 14: the
## wet layer exists now — the wave helper applies wet at chance
## 1, whirlpool ticks at .6, cannon ticks at .5 (the bundle's
## Bg[7] riders, DIFF cycle 13), on the parallel wet timer.

func _cast_shell(ctx: Dictionary) -> void:
	var ti := int(ctx["tier"])
	var r := float(ctx["R"])
	if ti == 0:
		var st := {"acc": 0.25}
		_every(2.2, _whirl_tick.bind(ctx, st), _whirl_done.bind(ctx))
	elif ti == 1:
		_wave(ctx, float(ctx["x"]), float(ctx["z"]), 16.0 * r, 1.8,
			{"knock": 6.0, "status": "wet", "chance": 1.0})
		later(0.9, _shell_rain)
	else:
		_wave(ctx, float(ctx["x"]), float(ctx["z"]), 12.0 * r, 1.8,
			{"knock": 6.0, "status": "wet", "chance": 1.0})
		later(0.5, _cannons_start.bind(ctx))

func _shell_rain() -> void:
	world.set_weather("rain", 12.0)

func _whirl_tick(elapsed: float, dt: float,
		ctx: Dictionary, st: Dictionary) -> void:
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return
	var r := float(ctx["R"])
	var cx: float = p.global_position.x
	var cz: float = p.global_position.z
	var frac := clampf(elapsed / 2.2, 0.0, 1.0)
	_drag(cx, cz, 5.0 * r + 2.0, 26.0 * frac)
	st["acc"] = float(st["acc"]) + dt
	if float(st["acc"]) >= 0.25:
		st["acc"] = 0.0
		_q(ctx, cx, cz, 5.0 * r, 0.32,
			{"knock": 0.3, "silent": 0.5, "status": "wet", "chance": 0.6}, {})
		world.spawn_nova(p.global_position,
			lerpf(5.0, 11.0, frac) * r, tint_color())

func _whirl_done(ctx: Dictionary) -> void:
	_wave(ctx, float(ctx["x"]), float(ctx["z"]),
		9.0 * float(ctx["R"]), 1.4, {"knock": 6.0, "status": "wet", "chance": 1.0})

func _cannons_start(ctx: Dictionary) -> void:
	var st := {"acc": 0.1}
	_every(2.2, _cannon_tick.bind(ctx, st), _noop)

func _noop() -> void:
	pass

func _cannon_tick(elapsed: float, dt: float,
		ctx: Dictionary, st: Dictionary) -> void:
	st["acc"] = float(st["acc"]) + dt
	if float(st["acc"]) < 0.1:
		return
	st["acc"] = 0.0
	var p = world.get("player")
	if p == null or not is_instance_valid(p):
		return
	var r := float(ctx["R"])
	var base := atan2(float(ctx["az"]), float(ctx["ax"])) \
		+ TAU * clampf(elapsed / 2.2, 0.0, 1.0)
	var len_ := 17.0 * r
	var half_w := 1.6 * r
	for sgn in [0.0, PI]:
		var a: float = base + sgn
		var dx := cos(a)
		var dz := sin(a)
		var ox: float = p.global_position.x + dx * 0.8
		var oz: float = p.global_position.z + dz * 0.8
		world.spawn_beam(p.global_position + Vector3(0, 1.0, 0),
			Vector3(-dx, 0, -dz), len_, tint_color())
		for e in world.get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or float(e.get("hp")) <= 0.0:
				continue
			var ex: float = e.global_position.x - ox
			var ez: float = e.global_position.z - oz
			var along := ex * dx + ez * dz
			var perp := absf(-ex * dz + ez * dx)
			if along >= 0.0 and along <= len_ and perp <= half_w:
				_hit(ctx, e, 0.42, {"knock": 1.5, "silent": 0.4, "status": "wet", "chance": 0.5})
