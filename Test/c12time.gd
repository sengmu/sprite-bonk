extends Node
## Cycle 12 timing probe (standing tool, kept).
##   --mode=switch : boot, wait for the menu prebuild to cache all
##                   four zone scenes, then measure warm switches
##                   (park/restore), a repeat switch, and one cold
##                   fallback build (cache entry dropped).
##   --mode=phases : the pre-cycle-12 phase mirror (frozen record).

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var mode := String(args.get("mode", "switch"))
	var w = load("res://scenes/main.tscn").instantiate()
	add_child(w)
	await get_tree().process_frame
	await get_tree().process_frame
	print("C12 boot static mem MB: ", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	# Fail-fast: zone-1 grid hash by the baseline method, at boot.
	var h1 := 2166136261
	for idx in range(w._grid.size()):
		var v1 := int(w._grid[idx] * 1000.0)
		h1 = (h1 ^ (v1 & 0xffffffff)) * 16777619 & 0xffffffff
	print("C12 zone 1 boot hash n=", w._grid.size(), " h=", h1, " (baseline 845780485)")
	if mode == "phases":
		_phases(w)
		get_tree().quit()
		return
	# Wait for the menu prebuild to finish (data threads + scenes).
	# Do NOT proceed on timeout: measuring switches while the
	# prebuild coroutine still owns member state races it and the
	# numbers are garbage (first c12 run, 2026-10-26 — see DIFF).
	var t0 := Time.get_ticks_msec()
	while w._scene_cache.size() < 4 and Time.get_ticks_msec() - t0 < 1500000:
		await get_tree().process_frame
	print("C12 prebuild: cache=", w._scene_cache.size(), " after ",
		Time.get_ticks_msec() - t0, " ms; static mem MB: ",
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	if w._scene_cache.size() < 4:
		print("C12 ABORT measurement: prebuild did not finish")
		get_tree().quit()
		return
	for z in [2, 3, 4, 1, 2]:
		var t := Time.get_ticks_msec()
		w.zone = z
		w._apply_zone_visuals()
		print("C12 warm switch -> zone ", z, ": ", Time.get_ticks_msec() - t, " ms")
	# Cold fallback: drop zone 3's cache entry, switch to it live.
	w._scene_cache.erase(3)
	var t3 := Time.get_ticks_msec()
	w.zone = 3
	w._apply_zone_visuals()
	print("C12 cold switch -> zone 3 (full build, data cached): ", Time.get_ticks_msec() - t3, " ms")
	# Terrain identity after all the caching. Hash = the BASELINE
	# method (full grid array, FNV-1a over int(h*1000)) so values
	# compare against the pre-change record: z1 845780485,
	# z2 924739516, z3 34206095, z4 249583396.
	for z in range(1, 5):
		w.zone = z
		var g = w._zone_data(z)
		w._apply_zone_data(g)
		var h := 2166136261
		for idx in range(w._grid.size()):
			var v := int(w._grid[idx] * 1000.0)
			h = (h ^ (v & 0xffffffff)) * 16777619 & 0xffffffff
		print("C12 zone ", z, " grid n=", w._grid.size(), " h=", h,
			" ponds=", w._ponds.size(), " paths=", w._paths.size(),
			" wl=", w._water_level)
	get_tree().quit()

func _phases(w) -> void:
	for z in range(2, 5):
		w.zone = z
		w._pal = w.ZONES[z - 1]["pal"]
		var t := Time.get_ticks_msec()
		w._gen_terrain()
		var t_gen := Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		w._build_terrain()
		var t_terr := Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		w._build_water()
		var t_water := Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		w._bake_minimap()
		var t_map := Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		for c in w._dress_root.get_children():
			c.queue_free()
		await get_tree().process_frame
		w._props.clear()
		w._props.append(Vector3(w.ALTAR_XZ.x, w.ALTAR_XZ.y, 2.7))
		w._pk.clear()
		w._rng.seed = 7 + z * 13
		w._build_props()
		var t_props := Time.get_ticks_msec() - t
		t = Time.get_ticks_msec()
		w._build_set_dressing()
		w._cull_subtree(w._dress_root)
		var t_dress := Time.get_ticks_msec() - t
		var h := 2166136261
		for j in range(0, 240):
			for i in range(0, 240, 7):
				var v := int(w._grid[j * 240 + i] * 1000.0)
				h = (h ^ (v & 0xffffffff)) * 16777619 & 0xffffffff
		print("C12 zone ", z, " phases ms gen=", t_gen, " terrain=", t_terr,
			" water=", t_water, " minimap=", t_map, " scatter+deco=", t_props,
			" dressing=", t_dress, " | grid h=", h, " ponds=", w._ponds.size(),
			" paths=", w._paths.size(), " wl=", w._water_level,
			" memMB=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
