extends SceneTree
# C23B executable, mutation-sensitive damage/defense checks.
var checks := 0
var fails := 0
var p: Node
var w: Node

func ck(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", label)

func near(actual: float, expected: float, label: String) -> void:
	ck(absf(actual - expected) < 0.0001, "%s actual=%s expected=%s" % [label,actual,expected])

func reset() -> void:
	p.set("hp", 100.0)
	p.set("max_hp", 100.0)
	p.set("armor", 0.0)
	p.set("evasion", 0.0)
	p.set("passive_id", "")
	p.set("_invuln_t", 0.0)
	p.set("invulnerable", false)
	p.set("shield", 0.0)
	p.set("overheal", 0.0)
	p.set("wound_t", 0.0)
	p.set("no_hit_t", 0.0)
	p.set("items", {})
	p.set("timed_buffs", {})
	p.set("guard_t", 0.0)
	p.set("overheal_ratio", 0.0)
	p.set("fresh_store", 0.0)
	if p.get("buffs") != null:
		p.set("buffs", {})
	if p.get("hurt_mod") != null:
		p.set("hurt_mod", Callable())

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	p = load("res://scripts/player.gd").new()
	w = load("res://scripts/world.gd").new()
	var ready := true
	for method in ["heal", "wound", "tick_defenses"]:
		var exists := p.has_method(method)
		ck(exists, "Player API " + method)
		ready = ready and exists
	for field in ["shield_max", "shield", "overheal", "wound_t", "wound_pop_t"]:
		var exists: bool = p.get(field) != null
		ck(exists, "Player field " + field)
		ready = ready and exists
	for method in ["alpha_hurt_cap", "strike_options", "contact_hurt", "hostile_hurt", "miniboss_strike", "legendary_hurt"]:
		var exists := w.has_method(method)
		ck(exists, "World API " + method)
		ready = ready and exists
	if ready:
		shield_sources()
		defenses()
		damage()
		evasion_scaling()
		dispatch()
		wrappers()
		landed_bookkeeping()
		contact_geometry()
		hostile_geometry()
	else:
		print("C23B baseline: implementation API missing; behavioral checks guarded.")
	p.free()
	w.free()
	print("C23 DAMAGE SUMMARY checks=%d fails=%d" % [checks, fails])
	quit(0 if fails == 0 else 1)

func shield_sources() -> void:
	GameData.roster_for_species("bulbasaur")
	var old: Dictionary = GameData._roster["1"].duplicate(true)
	var expected := {"torrent-shell":20.0, "metamorph":20.0, "shield-dust":20.0,
		"leaf-guard":15.0, "water-veil":15.0, "flower-veil":15.0,
		"sweet-veil":15.0, "overcoat":10.0}
	for ability in expected:
		GameData._roster["1"]["passive"] = ability
		p.set("base_species", "bulbasaur")
		p.call("recalc")
		near(float(p.get("shield_max")), float(expected[ability]), "shield source " + ability)
	GameData._roster["1"] = old
	p.call("recalc")
	near(float(p.get("shield_max")), 0.0, "shieldMax resets on recalc")

func defenses() -> void:
	reset()
	p.set("shield_max", 20.0)
	p.set("no_hit_t", 0.0)
	p.call("tick_defenses", 3.0)
	near(float(p.get("shield")), 0.0, "no regen at exactly 3s")
	p.call("tick_defenses", 1.0)
	near(float(p.get("shield")), 5.0, "quarter shield/s after >3")
	p.call("tick_defenses", 10.0)
	near(float(p.get("shield")), 20.0, "regen clamps max")
	p.set("shield", 0.0)
	p.call("wound", 6.0)
	p.call("tick_defenses", 1.0)
	near(float(p.get("shield")), 2.5, "wound halves shield regen")
	near(float(p.get("wound_t")), 5.0, "wound ticks")
	p.call("wound", 4.0)
	near(float(p.get("wound_t")), 5.0, "shorter wound does not shorten")
	p.call("wound", 6.0)
	near(float(p.get("wound_t")), 6.0, "refresh max not sum")
	p.call("tick_defenses", 7.0)
	near(float(p.get("wound_t")), -1.0, "expired timer may be negative")
	p.set("hp", 0.0)
	p.call("wound", 9.0)
	near(float(p.get("wound_t")), -1.0, "dead wound ignored")
	p.call("tick_defenses", 2.0)
	near(float(p.get("wound_t")), -1.0, "dead timers stop")
	reset()
	p.set("heal_mult", 1.25)
	p.set("hp", 20.0)
	near(float(p.call("heal", 16.0)), 20.0, "healing stat applied")
	p.call("wound", 4.0)
	near(float(p.call("heal", 16.0)), 10.0, "wound halves healing")
	p.call("leech_heal", 16.0)
	near(float(p.get("hp")), 60.0, "leech routes through wounded heal")
	p.call("heal", -20.0)
	near(float(p.get("hp")), 60.0, "negative heal ignored")

func damage() -> void:
	reset()
	p.set("overheal", 4.0)
	p.set("shield", 10.0)
	p.set("no_hit_t", 20.0)
	ck(bool(p.call("take_damage", 6.0, {})), "shield-only hit returns true")
	near(float(p.get("overheal")), 0.0, "overheal first")
	near(float(p.get("shield")), 8.0, "shield second")
	near(float(p.get("hp")), 100.0, "full absorption HP unchanged")
	near(float(p.get("no_hit_t")), 0.0, "full absorption resets noHit")
	near(float(p.get("_invuln_t")), .45, "full absorption grants iframe")
	ck(not bool(p.call("take_damage", 6.0, {})), "iframe returns false")
	reset()
	p.set("invulnerable", true)
	ck(not bool(p.call("take_damage", 10.0, {})), "invulnerability false")
	reset()
	p.set("evasion", 1.0)
	ck(not bool(p.call("take_damage", 10.0, {})), "certain evade false")
	reset()
	p.set("armor", 405.0)
	p.call("take_damage", 10.0, {"floor": .08})
	near(float(p.get("hp")), 94.52, "floor uses reduction ratio .35")
	reset()
	p.set("armor", 405.0)
	p.call("take_damage", 0.0, {"floor": .08})
	near(float(p.get("hp")), 92.0, "zero raw floor has no reduction discount")
	reset()
	p.call("take_damage", 1000.0, {"floor": .4, "cap": .15})
	near(float(p.get("hp")), 85.0, "cap after floor")
	reset()
	p.set("passive_id", "multiscale")
	p.set("hp", 99.6)
	p.call("take_damage", 20.0, {})
	near(float(p.get("hp")), 89.6, "multiscale half within .5 HP")
	reset()
	p.set("passive_id", "magic-guard")
	p.call("take_damage", 20.0, {"source": -1})
	near(float(p.get("hp")), 86.0, "magic guard noncontact .7")
	reset()
	p.set("passive_id", "magic-guard")
	p.call("take_damage", 20.0, {"source": 0})
	near(float(p.get("hp")), 80.0, "magic guard contact unchanged")

	reset()
	p.set("timed_buffs", {"tm-iron": 8.0})
	p.call("take_damage", 1000.0, {"cap": .15})
	near(float(p.get("hp")), 94.0, "TM iron after cap .4")
	reset()
	p.set("hurt_mod", func(_world, _player, _dmg, _source): return -5.0)
	p.call("take_damage", 10.0, {"floor": .08})
	near(float(p.get("hp")), 94.8, "hurtMod clamped before discounted floor")
	reset()
	p.set("types_override", ["grass", "poison"])
	p.call("take_damage", 10.0, {"type": "fire"})
	near(float(p.get("hp")), 84.0, "super effective type clamped 1.6")
	reset()
	p.set("types_override", ["grass", "poison"])
	p.call("take_damage", 10.0, {"type": "grass"})
	near(float(p.get("hp")), 95.0, "quarter effective type clamped .5")
	p.set("types_override", [])
	reset()
	p.set("items", {"guard-spec": 2})
	ck(not bool(p.call("take_damage", 10.0, {})), "guard-spec rejects hit")
	near(float(p.get("guard_t")), 11.0, "guard-spec stack cooldown")
	near(float(p.get("hp")), 100.0, "guard-spec no damage")
	reset()
	p.set("hp", 90.0)
	p.set("heal_mult", 1.0)
	p.set("items", {"fresh-water": 1})
	p.set("overheal_ratio", .2)
	p.call("wound", 4.0)
	p.call("heal", 60.0)
	near(float(p.get("hp")), 100.0, "wounded heal fills missing HP")
	near(float(p.get("fresh_store")), 20.0, "fresh-water excess uses halved input")
	near(float(p.get("overheal")), 20.0, "overheal excess uses halved input")
	p.set("shield", 10.0)
	p.set("shield_max", 20.0)
	near(float(p.call("shield_hud_fraction")), .1, "HUD shield denominator maxHp")
	ck(String(p.call("hp_hud_text")) == "100 +30", "HUD adds shield+overheal")
	p.set("shield", .5)
	p.set("overheal", .5)
	ck(String(p.call("hp_hud_text")) == "100", "HUD omits exact one extra")

func evasion_scaling() -> void:
	seed(2309)
	var dodges := 0
	for i in range(1000):
		reset()
		p.set("evasion", .8)
		if not bool(p.call("take_damage", 0.0, {"evade": .5})):
			dodges += 1
	ck(dodges > 320 and dodges < 480, "qy evade .5 probability, observed %d/1000" % dodges)

func dispatch() -> void:
	w.set("player", p)
	w.set("zone", 1)
	for tier in range(3):
		w.set("run_tier", tier)
		near(float(w.call("alpha_hurt_cap")), [.15,.25,.25][tier], "alpha stage1 tier%d" % tier)
		var opts: Dictionary = w.call("strike_options", .08)
		near(float(opts.get("floor", -1)), [.08,.096,.112][tier], "qy default tier%d" % tier)
		near(float(opts.get("evade", -1)), .5, "qy evasion tier%d" % tier)
		opts = w.call("strike_options", .3)
		near(float(opts.get("floor", -1)), .3, "qy >=.3 not scaled tier%d" % tier)
		reset()
		w.call("hostile_hurt", 1000.0, false, true, "")
		near(float(p.get("hp")), 100.0 - 100.0 * [.15,.25,.25][tier], "alpha projectile cap tier%d" % tier)
		near(float(p.get("wound_t")), 0.0, "alpha projectile no wound")
		reset()
		w.call("hostile_hurt", 1000.0, true, true, "")
		near(float(p.get("hp")), 85.0, "Capped wins over Alpha tier%d" % tier)
		near(float(p.get("wound_t")), 0.0, "Capped projectile no wound")
		reset()
		w.call("hostile_hurt", 0.0, true, false, "")
		near(float(p.get("hp")), 100.0 - [.02,.024,.028][tier]*100.0, "Capped floor tier%d" % tier)
	w.set("zone", 2)
	w.set("run_tier", 0)
	near(float(w.call("alpha_hurt_cap")), .25, "stage2 alpha .25")
	w.set("zone", 1)
	w.set("endless", true)
	near(float(w.call("alpha_hurt_cap")), .25, "endless stage1 alpha .25")
	w.set("endless", false)
	w.set("player", null)

func wrappers() -> void:
	var e: Node = load("res://scripts/enemy.gd").new()
	e.set("dmg", 1000.0)
	e.set("species_id", "rattata")
	w.set("player", p)
	w.set("guardian", e)
	w.set("zone", 1)
	for tier in range(3):
		w.set("run_tier", tier)
		reset()
		w.call("_boss_strike", 1.0, Vector2.ZERO, 0.0, .4)
		near(float(p.get("hp")), 66.0, "Nb cap remains .34 for explicit .4")
		near(float(p.get("wound_t")), 4.0+tier, "Nb wound tier%d" % tier)
		reset()
		p.set("shield", 100.0)
		w.call("_boss_strike", 1.0)
		near(float(p.get("hp")), 100.0, "Nb full shield HP unchanged")
		near(float(p.get("wound_t")), 4.0+tier, "Nb full shield wound")
		reset()
		p.set("invulnerable", true)
		w.call("_boss_strike", 1.0, Vector2.ONE, 5.0)
		near(float(p.get("wound_t")), 0.0, "Nb failed hit no wound")
		ck(p.get("_vel") == Vector3.ZERO, "Nb failed hit no shove")
		if w.has_method("miniboss_strike"):
			reset()
			w.call("miniboss_strike", e, 1.0, .08)
			near(float(p.get("hp")), 66.0, "ix cap .34")
			near(float(p.get("wound_t")), 4.0+tier, "ix wound")
		if w.has_method("legendary_hurt"):
			reset()
			w.call("legendary_hurt", e, 1.0, .4, "")
			near(float(p.get("hp")), 40.0, "Yy >=.3 cap .6")
			near(float(p.get("wound_t")), 4.0+tier, "Yy wound")
			reset()
			w.call("legendary_hurt", e, 1.0, -1.0, "")
			near(float(p.get("hp")), 66.0, "Yy negative cap .34")
			near(float(p.get("wound_t")), 0.0, "Yy negative no wound")
		reset()
		e.set("flag", 2)
		w.call("contact_hurt", e)
		near(float(p.get("hp")), 100.0 - 100.0*[.15,.25,.25][tier], "alpha contact cap")
		near(float(p.get("wound_t")), 0.0, "alpha contact no wound")
		reset()
		e.set("flag", 4)
		e.set("is_guardian", true)
		e.set("dmg", 0.0)
		w.call("contact_hurt", e)
		near(float(p.get("hp")), 100.0 - 100.0*[.05,.06,.07][tier], "boss contact floor")
		near(float(p.get("wound_t")), 0.0, "boss contact no wound")
		e.set("is_guardian", false)
		e.set("dmg", 1000.0)
	w.set("player", null)
	w.set("guardian", null)
	e.free()

func landed_bookkeeping() -> void:
	reset()
	p.set("shield", 100.0)
	p.set("pstat", {"sleep": 3.0})
	p.call("take_damage", 10.0, {})
	near(float(p.call("pstat_t", "sleep")), 0.0, "full shield landed hit wakes sleep")
	var found := false
	for prop in p.get_property_list():
		if prop.name == "last_hit":
			found = true
	ck(found, "Player last_hit attribution field exists")
	if not found:
		return
	var e: Node = load("res://scripts/enemy.gd").new()
	e.set("dmg", 10.0)
	reset()
	p.set("last_hit", null)
	w.set("player", p)
	w.call("miniboss_strike", e, 1.0)
	ck(p.get("last_hit") == e, "ix strike saves Enemy attribution")
	reset()
	p.set("last_hit", null)
	w.call("legendary_hurt", e, 1.0, 0.0)
	ck(p.get("last_hit") == e, "Yy hurt saves Enemy attribution")
	reset()
	p.set("last_hit", null)
	w.call("hostile_hurt", 10.0, true, false, "", e)
	ck(p.get("last_hit") == e, "hostile saves supplied Enemy attribution")
	reset()
	p.set("last_hit", e)
	p.set("shield", 100.0)
	w.call("hostile_hurt", 10.0, false, false, "", null)
	ck(p.get("last_hit") == e, "full shield keeps previous attribution")
	w.set("player", null)
	p.set("last_hit", null)
	e.free()

func contact_geometry() -> void:
	var e: Node = load("res://scripts/enemy.gd").new()
	ck(e.has_method("contact_reaches"), "Enemy contact_reaches API")
	if e.has_method("contact_reaches"):
		p.process_mode = Node.PROCESS_MODE_DISABLED
		e.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(p)
		root.add_child(e)
		p.position = Vector3.ZERO
		e.set("target", p)
		e.set("radius", .5)
		e.set("body_height", 1.2)
		e.position = Vector3(.99, 0, 0)
		ck(bool(e.call("contact_reaches")), "body contact within sum radii")
		e.position.x = 1.0
		ck(not bool(e.call("contact_reaches")), "body contact strict radius boundary")
		e.position = Vector3(.5, 1.99, 0)
		ck(bool(e.call("contact_reaches")), "body contact within height")
		e.position.y = 2.0
		ck(not bool(e.call("contact_reaches")), "body contact strict height boundary")
		e.position.y = 0.0
		for flags in [128, 16384]:
			e.set("flag", flags)
			ck(not bool(e.call("contact_reaches")), "body contact excludes flag %d" % flags)
		e.set("flag", 0)
		for kind in ["sleep", "freeze", "stun"]:
			e.set("status_kind", kind)
			e.set("status_t", 1.0)
			ck(not bool(e.call("contact_reaches")), "body contact disabled by " + kind)
		e.set("status_kind", "")
		e.set("status_t", 0.0)
		e.set("pickup_stun_t", 1.0)
		ck(not bool(e.call("contact_reaches")), "body contact disabled by pickup stun")
		# Drive actual chase state, not merely the geometry helper: the old
		# 1.35 stop threshold strands normals outside their new contact radius.
		e.set("pickup_stun_t", 0.0)
		e.set("radius", .55)
		e.set("speed", 1.0)
		e.set("_touch_cd", 100.0)
		e.position = Vector3(1.2, 0, 0)
		e.call("_hostile_process", .1)
		ck(e.position.x < 1.19, "actual chase advances from 1.2 outside normal contact radius")
		e.set("radius", .5)
		e.position = Vector3(1.0, 0, 0)
		e.call("_hostile_process", .1)
		ck(e.position.x < .99, "actual chase advances at strict contact boundary")
		e.position = Vector3(.9, 0, 0)
		e.call("_hostile_process", .1)
		near(float(e.position.x), .9, "actual chase stops strictly within contact radius")
		root.remove_child(e)
		root.remove_child(p)
	e.free()

func hostile_geometry() -> void:
	ck(w.has_method("hostile_reaches"), "World hostile_reaches API")
	if not w.has_method("hostile_reaches"):
		return
	p.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(p)
	p.position = Vector3.ZERO
	w.set("player", p)
	ck(bool(w.call("hostile_reaches", Vector3(.99,.8,0), .5)), "hostile inside summed radii")
	ck(not bool(w.call("hostile_reaches", Vector3(1.0,.8,0), .5)), "hostile strict summed radius boundary")
	ck(bool(w.call("hostile_reaches", Vector3(0,2.29,0), .5)), "hostile vertical within 1.5 of player+.8")
	ck(not bool(w.call("hostile_reaches", Vector3(0,2.31,0), .5)), "hostile vertical beyond 1.5")
	ck(not bool(w.call("hostile_reaches", Vector3(0,-.71,0), .5)), "hostile vertical below player rejects")
	w.set("player", null)
	root.remove_child(p)
