extends SceneTree
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
	Profile._loaded = true
	Profile.data = {"league":[], "captured":{}, "shinies":[], "stardust":0, "totalStardust":0}
	var w = load("res://scenes/main.tscn").instantiate()
	var override := OS.get_environment("C24_LIVE_WORLD_SCRIPT")
	if override != "":
		w.set_script(load(override))
	root.add_child(w)
	await process_frame
	w.start_game("bulbasaur")
	w.set_process(false)
	w.player.set_physics_process(false)
	for n in get_nodes_in_group("enemies"):
		n.set_physics_process(false)
	var actual: Dictionary = w._make_prop("fossil",Vector2(0,0),1,w._rng)
	var carvings: Dictionary = actual.data.fossil_carvings
	ck(carvings.size() == 2 and carvings.has("helix") and carvings.has("dome") and not carvings.has("amber"), "two fossil carvings no Amber model")
	carvings.helix.visible = false
	carvings.dome.position.y = 3.0
	w.Fossils.reset_visual(actual)
	ck(carvings.helix.visible and is_equal_approx(carvings.dome.position.y,.45), "new run fossil visuals reset")
	actual.root.free()
	var p := {"kind":"fossil", "used":false, "data":{}, "dim":[]}
	var fossil_count := 0
	for plan in w.PROP_PLAN:
		if plan[0] == "fossil": fossil_count += int(plan[1])
	ck(fossil_count == 1, "exactly one fossil per stage")
	w._interact_prop(p)
	ck(w._choice_open and w._choice_opts_box.get_child_count() == 2, "fossil wired with exactly two offers")
	w._choice_close(true)
	ck(not p.used and w.player.temp_mods.is_empty(), "fossil cancel free and unused")
	var seed: int = w._bless_rng.state
	var base: Array = w._blessing_roll(4,3)
	w._bless_rng.state = seed
	var dome: Array = w._blessing_roll(4,3,1.5)
	for i in range(3):
		var a: Dictionary = base[i].mods[0]
		var b: Dictionary = dome[i].mods[0]
		ck(is_equal_approx(float(b.get("add",b.get("mul",1.0)-1.0)),float(a.get("add",a.get("mul",1.0)-1.0))*1.5), "dome blessing actual mod x1.5 %d" % i)
	for i in range(3):
		var e = w._spawn_enemy_at("bulbasaur",Vector3(2,0,2),1.0,false)
		e.set_physics_process(false)
		e.mode = Enemy.MODE_LEAGUE
		e.shiny = true
		e.is_weakened = true
		e.capture_attempts = 3
		w._shiny_e = e
		var old = w._shiny_ally
		w._throw_ball(e)
		if i == 0:
			ck(e.mode == Enemy.MODE_ALLY and not e.is_weakened and e.is_in_group("allies"), "real shiny throw creates active ally")
			ck(w._shiny_ally == e and e.ally_slot == 10, "first shiny slot ten")
		else:
			ck(w._choice_open and not e.is_in_group("allies"), "real second shiny waits for swap")
			w._choice_pick(0 if i == 1 else 1)
			ck(w._pending_shiny_ally == null, "swap clears pending")
			ck(w._shiny_ally == (e if i == 1 else old), "swap choice respected")
			ck(get_nodes_in_group("allies").size() == 1, "one shiny ally after swap")
	ck(Profile.stardust() == 220, "shiny real capture first120 repeat50 twice")
	ck(Profile.data.captured.is_empty() and Profile.data.league.is_empty(), "shiny no normal capture or Liga")
	var dust_before: int = Profile.stardust()
	w._throw_ball(w._shiny_ally)
	ck(Profile.stardust() == dust_before and w._shiny_ally.is_in_group("allies"), "already caught ally cannot be thrown again")
	var ally = w._shiny_ally
	ally.bond_level = 2
	ally.ally_kills = 24
	ally._ally_credit_kill()
	ck(ally.bond_level == 2, "seeded bond2 stays two at25 kills")
	ally.ally_kills = 74
	ally._ally_credit_kill()
	ck(ally.bond_level == 2, "seeded bond2 stays two at75 kills")
	ally.ally_kills = 149
	ally._ally_credit_kill()
	ck(ally.bond_level == 3, "seeded bond2 reaches three at150 kills")
	ally.ally_kills = 499
	ally._ally_credit_kill()
	ck(ally.bond_level == 5, "seeded bond2 reaches five at500 kills")
	w._spawn_classic()
	var classic = w._classic_e
	ck(is_instance_valid(classic) and classic.classic and not classic.shiny, "real Classic spawn separate flags")
	if is_instance_valid(classic):
		var key: String = classic.species_id
		ck(is_equal_approx(classic.max_hp,Enemy.base_hp(key)*w._spawn_mult()*2.5*w.tier_value("hp")), "Classic actual HP x2.5")
		classic.set_physics_process(false)
		classic.capture_attempts = 3
		classic.is_weakened = true
		w._throw_ball(classic)
		ck(Profile.skin_available(key,"classic") and Profile.stardust() == 420, "real Classic capture records and pays200")
		ck(w._shiny_ally == ally and get_nodes_in_group("allies").size() == 1, "Classic never creates ally")
		ck(Profile.data.league.is_empty() and Profile.data.captured.is_empty(), "Classic never Liga or normal capture")
	var normal_a = w._spawn_enemy_at("rattata",Vector3(3,0,3),1.0,false)
	normal_a.make_ally()
	var normal_b = w._spawn_enemy_at("rattata",Vector3(4,0,4),1.0,false)
	normal_b.is_downed = true
	w._master_ball = true
	w._throw_ball(normal_b)
	ck(normal_b.mode == Enemy.MODE_ALLY and get_nodes_in_group("allies").size() == 3, "shiny extra slot allows two normal allies at cap2")
	Profile.data["counters"] = {"runs":2}
	ck(Profile.challenge_done("bulbasaur"), "Liga fixture actually eligible")
	w.state = "playing"
	w.running = true
	w._league_done = false
	w._league_spawn_at = 60.0
	w._shiny_spawned = false
	w._shiny_at = .01
	w._classic_at = .01
	w.elapsed = 61.0
	w._spawn_t = 1000.0
	w._process(.02)
	ck(is_instance_valid(w._shiny_e) and not is_instance_valid(w._classic_e) and not is_instance_valid(w._league_e), "actual director gives shiny priority over Classic and Liga")
	w._spawn_classic()
	ck(not is_instance_valid(w._classic_e), "direct Classic call respects active shiny")
	if is_instance_valid(w._classic_e):
		w._classic_e.capture_remove()
		w._classic_e = null
	w._process(.02)
	ck(w._classic_at == .01, "Classic due time waits while encounter busy")
	if is_instance_valid(w._shiny_e):
		w._shiny_e.capture_remove()
	w._shiny_e = null
	if is_instance_valid(w._league_e):
		w._league_e.capture_remove()
	w._league_e = null
	w._league_done = true
	w._process(.02)
	ck(is_instance_valid(w._classic_e) and is_inf(w._classic_at), "Classic fires once encounter idle")
	if not is_instance_valid(w._classic_e):
		w._spawn_classic()  # Continue negative-control diagnostics after a missed spawn.
	w._spawn_shiny()
	ck(not is_instance_valid(w._shiny_e), "direct eclipse shiny call respects active Classic")
	if is_instance_valid(w._shiny_e):
		w._shiny_e.capture_remove()
		w._shiny_e = null
	w._shiny_spawned = false
	w._shiny_at = .02
	w._process(.02)
	ck(not w._shiny_spawned and w._shiny_at == .02 and not is_instance_valid(w._shiny_e), "shiny due time waits while Classic busy")
	w._classic_e.capture_remove()
	w._classic_e = null
	w._process(.02)
	ck(is_instance_valid(w._shiny_e) and not is_instance_valid(w._league_e), "due shiny fires after Classic before Liga")
	if is_instance_valid(w._shiny_e):
		w._shiny_e.capture_remove()
	w._shiny_e = null
	w._league_done = false
	w._process(.02)
	ck(is_instance_valid(w._league_e), "Liga fires after due rare encounters settled")
	w.running = false
	w._prebuild_abort = true
	for task in w._terrain_tasks.values():
		WorkerThreadPool.wait_for_task_completion(int(task))
	for i in range(3):
		await process_frame
	w.queue_free()
	await process_frame
	if existed:
		var f := FileAccess.open(Profile.PATH,FileAccess.WRITE)
		f.store_buffer(disk)
	else:
		DirAccess.remove_absolute(Profile.PATH)
	print("C24 LIVE SUMMARY checks=%d fails=%d" % [checks,fails])
	quit(0 if fails == 0 else 1)
