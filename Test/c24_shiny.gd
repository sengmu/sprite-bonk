extends SceneTree
var meta := Profile.new()
var checks := 0
var fails := 0
func ck(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", msg)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var existed := FileAccess.file_exists(Profile.PATH)
	var disk := FileAccess.get_file_as_bytes(Profile.PATH) if existed else PackedByteArray()
	var prior := Profile.data.duplicate(true)
	var loaded := Profile._loaded
	Profile._loaded = true
	Profile.data = {"league":[], "captured":{}, "shinies":[], "stardust":0, "totalStardust":0}
	var w = load(OS.get_environment("C24_WORLD_SCRIPT") if OS.get_environment("C24_WORLD_SCRIPT") != "" else "res://scripts/world.gd").new()
	var e := Enemy.new()
	var p := Player.new()
	w.player = p
	w.zone = 2
	p.level = 10
	e.world = w
	e.bst = 400
	e.bond_level = 2
	var normal := e.ally_power_now()
	e.shiny = true
	ck(is_equal_approx(e.ally_power_now(), normal * 1.2), "shiny damage independent x1.2")
	for method in ["skin_available", "set_skin", "skin_for", "record_classic"]:
		ck(meta.has_method(method), "Profile API " + method)
	if meta.has_method("skin_available"):
		Profile.record_shiny("ivysaur")
		ck(meta.call("skin_available", "bulbasaur", "shiny"), "shiny unlock follows family")
		ck(not meta.call("skin_available", "charmander", "shiny"), "other family locked")
		ck(not meta.call("set_skin", "bulbasaur", "shiny"), "selection requires Liga")
		Profile.join_league(int(GameData.species("bulbasaur").family), "bulbasaur")
		ck(meta.call("set_skin", "bulbasaur", "shiny"), "select unlocked Liga skin")
		ck(not meta.call("set_skin", "bulbasaur", "classic"), "locked classic cannot select")
		ck(meta.call("record_classic", "squirtle") == 200, "new Classic grants 200")
		ck(meta.call("record_classic", "squirtle") == 0, "repeat Classic grants zero")
		ck(Profile.stardust() == 200, "Classic paid once")
		ck(meta.call("skin_available", "wartortle", "classic"), "Classic unlock family")
		meta.call("record_classic", "hitmonlee")
		ck(not meta.call("skin_available", "hitmonchan", "classic"), "Classic roster106 does not unlock107")
		ck(meta.call("skin_available", "hitmonlee", "classic"), "Classic roster106 unlocks106")
		ck(not Profile.has_shiny("squirtle"), "Classic distinct from shiny")
		ck(not Profile.data.captured.has("squirtle"), "Classic never normal capture")
		Profile.save_profile()
		Profile._loaded = false
		Profile.load_profile()
		ck(meta.call("skin_for", "ivysaur") == "shiny", "selected family skin disk round trip")
		ck(meta.call("skin_available", "wartortle", "classic"), "classic disk round trip")
		ck(Profile.has_shiny("ivysaur"), "shiny disk round trip")
	for method in ["_classic_pool", "_classic_chance", "_make_shiny_ally", "_settle_shiny_swap"]:
		ck(w.has_method(method), "world API " + method)
	if w.has_method("_classic_pool"):
		Profile.data["classics"] = []
		ck(w.call("_classic_pool", ["bulbasaur", "mewtwo"]).has("bulbasaur"), "unowned Classic family eligible")
		Profile.data["classics"] = ["ivysaur"]
		ck(w.call("_classic_pool", ["bulbasaur", "mewtwo"]).is_empty(), "owned family and legendary excluded")
		Profile.data["classics"] = ["hitmonlee"]
		ck(w.call("_classic_pool", ["hitmonlee", "hitmonchan"]).is_empty(), "Classic pool excludes unmodelled roster siblings")
		ck(Profile.classic_covered_members().has(106) and not Profile.classic_covered_members().has(107), "Classic coverage preserves uncovered roster sibling")
		ck(is_equal_approx(w.call("_classic_chance", 0.0), .025 * Profile.shiny_rate()), "Classic base probability")
		ck(is_equal_approx(w.call("_classic_chance", 300.0), .05 * Profile.shiny_rate()), "Classic luck cap")
		e.species_id = "bulbasaur"
		w.call("_make_shiny_ally", e)
		ck(e.mode == Enemy.MODE_ALLY and e.shiny and e.bond_level == 0, "shiny ally conversion zero bond")
		Profile.data["shiny_bond"] = true
		var e2 := Enemy.new()
		e2.species_id = "squirtle"
		w.call("_make_shiny_ally", e2)
		ck(e2.bond_level == 2, "unlocked bond seeds two")
		e2.free()
	e.free()
	p.free()
	w.free()
	Profile.data = prior
	Profile._loaded = loaded
	if existed:
		var f := FileAccess.open(Profile.PATH, FileAccess.WRITE)
		f.store_buffer(disk)
	else:
		DirAccess.remove_absolute(Profile.PATH)
	print("C24 SHINY SUMMARY checks=%d fails=%d" % [checks, fails])
	quit(0 if fails == 0 else 1)
