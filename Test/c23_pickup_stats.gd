extends SceneTree
# Real Player.recalc integration; optional isolated mutant supplied via env.
var checks := 0
var fails := 0
var p: Node

func ck(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", message)

func near(value: float, expected: float, message: String) -> void:
	ck(absf(value - expected) < .00001, "%s actual=%s expected=%s" % [message,value,expected])

func _initialize() -> void:
	call_deferred("run")

func clean() -> void:
	Profile.data = {"lab": {}, "shinies": [], "counters": {}}
	GameData._roster["1"]["passive"] = "photosynthesis"
	p.set("species_id", "bulbasaur")
	p.set("base_species", "bulbasaur")
	p.set("items", {})
	p.set("vit", {})
	p.set("vit_levels", {})
	p.set("timed_buffs", {})
	p.set("temp_mods", [])
	p.set("recompiled_mods", [])
	p.call("recalc")

func run() -> void:
	var old_loaded := Profile._loaded
	var old_profile := Profile.data.duplicate(true)
	Profile._loaded = true
	GameData.roster_for_species("bulbasaur")
	var old_one: Dictionary = GameData._roster["1"].duplicate(true)
	var old_magnet: Dictionary = GameData._roster["81"].duplicate(true)
	var script_path := OS.get_environment("C23_PLAYER_SCRIPT")
	if script_path == "":
		script_path = "res://scripts/player.gd"
	p = load(script_path).new()
	clean()
	near(float(p.get("pickup_range")), 6.0, "base pickup range")
	var sources := {"magnet-pull":4.0, "long-tongue":4.0, "static-wool":3.0,
		"keen-eye":2.0, "beacon":2.0, "gem-hoarder":2.0}
	for passive in sources:
		clean()
		GameData._roster["1"]["passive"] = passive
		p.call("recalc")
		near(float(p.get("pickup_range")), 6.0 + sources[passive], "passive range " + passive)
		p.call("recalc")
		near(float(p.get("pickup_range")), 6.0 + sources[passive], "recalc does not accumulate " + passive)
	clean()
	GameData._roster["81"]["passive"] = "pickup"
	p.set("base_species", "magneton")
	p.set("species_id", "magneton")
	p.call("recalc")
	near(float(p.get("pickup_range")), 10.0, "magneton pickup +4")
	for spec in [{"items":{"honey":1},"extra":1.5}, {"items":{"exp-share":1},"extra":2.0}, {"items":{"honey":1,"exp-share":1},"extra":3.5}]:
		clean()
		p.set("items", spec.items)
		p.call("recalc")
		near(float(p.get("pickup_range")), 6.0+float(spec.extra), "item pickup range " + str(spec.items))
	for lv in [1,3,5]:
		clean()
		Profile.data["lab"] = {"magnet":lv}
		p.call("recalc")
		near(float(p.get("pickup_range")), 6.0+.6*lv, "lab magnet level%d" % lv)
	for lv in [1,3,5]:
		clean()
		p.set("vit_levels", {"bug":lv})
		p.call("recalc")
		near(float(p.get("pickup_range")), 6.0+lv, "bug pickup vitamin level%d" % lv)
	clean()
	GameData._roster["1"]["passive"] = "static-wool"
	Profile.data["lab"] = {"magnet":3}
	p.set("vit_levels", {"bug":2})
	p.set("items", {"honey":1,"exp-share":1})
	p.call("recalc")
	near(float(p.get("pickup_range")), 16.3, "passive+lab+bug+items sum")
	buffs()
	p.free()
	GameData._roster["1"] = old_one
	GameData._roster["81"] = old_magnet
	Profile.data = old_profile
	Profile._loaded = old_loaded
	print("C23 PICKUP STATS SUMMARY checks=%d fails=%d" % [checks,fails])
	quit(0 if fails == 0 else 1)

func buffs() -> void:
	for spec in [{"key":"tm-swords", "duration":10.0, "field":"damage_mult", "mult":1.5},
		{"key":"tm-agility", "duration":10.0, "field":"speed_mult", "mult":1.35},
		{"key":"tm-payday", "duration":15.0, "field":"gold_mult", "mult":2.0}]:
		clean()
		var base := float(p.get(spec.field))
		var base_atk := float(p.get("atk_speed"))
		p.call("add_buff", spec.key, spec.duration)
		near(float(p.get(spec.field)), base*float(spec.mult), "live buff stat " + spec.key)
		if spec.key == "tm-agility":
			near(float(p.get("atk_speed")), base_atk*1.3, "agility attackSpeed +30%")
		p.call("recalc")
		near(float(p.get(spec.field)), base*float(spec.mult), "buff recalc nonaccumulating " + spec.key)
		p.call("tick_buffs", float(spec.duration)-.25)
		ck(bool(p.call("has_buff", spec.key)), "buff alive before expiry " + spec.key)
		near(float(p.get(spec.field)), base*float(spec.mult), "buff stays before expiry " + spec.key)
		p.call("tick_buffs", .25)
		ck(not bool(p.call("has_buff", spec.key)), "buff expires at exact duration " + spec.key)
		near(float(p.get(spec.field)), base, "buff stat restores on expiry " + spec.key)
		near(float(p.get("atk_speed")), base_atk, "attackSpeed restored " + spec.key)
	clean()
	var base_damage := float(p.get("damage_mult"))
	var base_speed := float(p.get("speed_mult"))
	var base_gold := float(p.get("gold_mult"))
	p.call("add_buff", "tm-swords", 10.0)
	p.call("add_buff", "tm-agility", 10.0)
	p.call("add_buff", "tm-payday", 15.0)
	p.call("tick_buffs", 10.0)
	near(float(p.get("damage_mult")), base_damage, "coexisting swords expires")
	near(float(p.get("speed_mult")), base_speed, "coexisting agility expires")
	near(float(p.get("gold_mult")), base_gold*2, "coexisting payday remains")
	p.call("tick_buffs", 5.0)
	near(float(p.get("gold_mult")), base_gold, "coexisting payday eventually restores")
