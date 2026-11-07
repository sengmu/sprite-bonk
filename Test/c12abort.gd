extends Node
## Cycle 12 abort stress (standing tool): start_game fired while
## the menu prebuild is mid-scene-build must abort cleanly — live
## zone-1 state restored, partial scene freed, no bogus cache
## entry, gameplay proceeds, and a later portal takes the pending
## -> fallback-build path to a working zone 2. All waits are
## wall-clock (this VM is shared; frame counts lie).

var _fails := 0

func _ck(cond: bool, label: String) -> void:
	if cond:
		print("C12ABORT PASS ", label)
	else:
		_fails += 1
		print("C12ABORT FAIL ", label)

func _wait_secs(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await get_tree().process_frame

func _ready() -> void:
	var w = load("res://scenes/main.tscn").instantiate()
	add_child(w)
	# Wait until the prebuild is genuinely mid-build (a zone cached,
	# still running). If it finished before we got there, re-kick it
	# over the uncached zones so the abort still lands mid-build.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600000:
		await get_tree().process_frame
		if w._scene_cache.size() >= 2 and w._prebuild_running:
			break
		if not w._prebuild_running:
			break
	if not w._prebuild_running:
		w._scene_cache.erase(3)
		w._scene_cache.erase(4)
		w._prebuild_scenes()
		await get_tree().process_frame
	_ck(w._prebuild_running, "prebuild running at start_game time (cache=%d)" % w._scene_cache.size())
	w.start_game("charmander")
	_ck(w.state == "playing" and is_instance_valid(w.player), "run started after abort")
	# The dead coroutine unwinds on its phase yields; gameplay ticks.
	var t1 := Time.get_ticks_msec()
	while w._prebuild_running and Time.get_ticks_msec() - t1 < 300000:
		await get_tree().process_frame
	_ck(not w._prebuild_running, "prebuild coroutine unwound")
	var bogus := false
	for z in w._scene_cache:
		if w._scene_cache[z].get("terrain_mi") == null:
			bogus = true
	_ck(not bogus, "no bogus cache entries (null terrain)")
	_ck(w._terrain_mi != null and w._terrain_mi.get_parent() == w, "zone-1 terrain live in tree")
	_ck(w.height_at(w.SPAWN_XZ.x, w.SPAWN_XZ.y) > -50.0, "height_at sane at spawn")
	await _wait_secs(5.0)
	_ck(is_instance_valid(w.player) and w.player.hp > 0.0, "player alive after seconds of play")
	# Portal into whatever state zone 2's cache is in: pending one
	# frame, then either a warm restore or the fallback build.
	w._on_portal_entered()
	var t2 := Time.get_ticks_msec()
	while w.zone != 2 and Time.get_ticks_msec() - t2 < 600000:
		await get_tree().process_frame
	_ck(w.zone == 2, "portal advanced to zone 2")
	_ck(w._terrain_mi != null and w._terrain_mi.get_parent() == w, "zone-2 terrain live in tree")
	_ck(w.height_at(w.SPAWN_XZ.x, w.SPAWN_XZ.y) > -50.0, "height_at sane in zone 2")
	print("C12ABORT DONE fails=", _fails)
	get_tree().quit()
