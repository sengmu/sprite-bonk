extends Node
## Cycle 12 weather checks (standing tool): damage table, look
## factors, base pick + passive override, timed revert, and the
## sand/hail ambient hazards staged through the real _weather_tick
## and _spawn_enemy_at paths. Prints C12WX PASS/FAIL lines.

var _fails := 0

func _ck(cond: bool, label: String) -> void:
	if cond:
		print("C12WX PASS ", label)
	else:
		_fails += 1
		print("C12WX FAIL ", label)

func _ready() -> void:
	var w = load("res://scenes/main.tscn").instantiate()
	add_child(w)
	await get_tree().process_frame
	await get_tree().process_frame
	w.start_game("charmander")
	await get_tree().process_frame
	# --- damage multiplier table (bundle weather table `tr`) ---
	var cases := [
		["rain", "fire", 0.75], ["rain", "water", 1.3], ["rain", "electric", 1.3],
		["rain", "grass", 1.0], ["sun", "fire", 1.3], ["sun", "water", 0.75],
		["sand", "rock", 1.3], ["sand", "fire", 1.0], ["hail", "ice", 1.3],
		["fog", "ghost", 1.3], ["fog", "dark", 1.3], ["ash", "dragon", 1.3],
		["ash", "ice", 0.75], ["clear", "fire", 1.0],
	]
	for c in cases:
		w.weather = String(c[0])
		_ck(is_equal_approx(w.weather_damage_mul(String(c[1])), float(c[2])),
			"mul %s/%s == %s" % [c[0], c[1], c[2]])
	# --- look factors (applyWeatherLook on our 40/160 bases) ---
	w.weather = "rain"
	w.apply_weather_look()
	_ck(is_equal_approx(w._env.fog_depth_end, 136.0), "look rain fog far 136")
	_ck(is_equal_approx(w._sun.light_energy, 1.32), "look rain light x0.8")
	w.weather = "sun"
	w.apply_weather_look()
	_ck(is_equal_approx(w._sun.light_energy, 1.8975), "look sun light x1.15")
	w.weather = "fog"
	w.apply_weather_look()
	_ck(is_equal_approx(w._env.fog_depth_begin, 20.0) and is_equal_approx(w._env.fog_depth_end, 96.0),
		"look fog 20/96")
	w.weather = "sand"
	w.apply_weather_look()
	var fc: Color = w._env.fog_light_color
	_ck(fc.is_equal_approx(Color(0.847, 0.725, 0.502)), "look sand fog color #D8B980")
	w.weather = "hail"
	w.apply_weather_look()
	_ck(is_equal_approx(w._env.fog_depth_end, 120.0), "look hail fog far 120")
	w.weather = "clear"
	w.apply_weather_look()
	# --- base pick: zone 3 candidates only; passive override ---
	var ok := true
	for i in range(20):
		w._weather_pick(3)
		if not ["clear", "sand", "sun"].has(w.base_weather):
			ok = false
	_ck(ok, "pick zone3 in {clear,sand,sun}")
	var pid_save: String = w.player.passive_id
	w.player.passive_id = "drizzle"
	w._weather_pick(1)
	_ck(w.base_weather == "rain", "passive drizzle overrides base to rain")
	w.player.passive_id = pid_save
	# --- timed weather reverts to base ---
	w.base_weather = "clear"
	w.set_weather("hail", 0.05)
	_ck(w.weather == "hail" and w.weather_t > 0.0, "timed hail set")
	w._weather_tick(0.1)
	_ck(w.weather == "clear", "timed hail reverts to base")
	# --- ambient hazards, staged through the real tick ---
	var pp: Vector3 = w.player.global_position
	var e_norm = w._spawn_enemy_at("rattata", pp + Vector3(20, 0, 0), 1.0)
	var e_rock = w._spawn_enemy_at("geodude", pp + Vector3(-20, 0, 0), 1.0)
	await get_tree().physics_frame
	var hp0n: float = e_norm.hp
	var hp0r: float = e_rock.hp
	w.weather = "sand"
	w.weather_t = 0.0
	w._weather_tick(10.0)  # gate rand < dt*2 always true at dt=10
	for i in range(40):
		await get_tree().physics_frame
	_ck(e_norm.hp <= hp0n - 3.5, "sand chip hits normal enemy (~4 dmg)")
	_ck(is_equal_approx(e_rock.hp, hp0r), "sand chip spares rock/ground")
	# hail: freeze a free-slot non-ice enemy; never clobber paralyze;
	# never freeze an ice enemy.
	var e_frz = w._spawn_enemy_at("rattata", pp + Vector3(0, 0, 20), 1.0)
	var e_par = w._spawn_enemy_at("rattata", pp + Vector3(0, 0, -20), 1.0)
	var e_ice = w._spawn_enemy_at("swinub", pp + Vector3(14, 0, 14), 1.0)
	e_par.apply_status("paralyze", 60.0)
	_ck(e_ice.types.has("ice"), "staged ice enemy really is ice-type (types=%s)" % str(e_ice.types))
	_ck(e_rock.types.has("rock"), "staged rock enemy really is rock-type")
	w.weather = "hail"
	for i in range(80):
		w._weather_tick(10.0)
	_ck(e_frz.status_kind == "freeze", "hail freezes free-slot enemy")
	_ck(e_par.status_kind == "paralyze", "hail never clobbers other status")
	_ck(e_ice.status_kind != "freeze", "hail spares ice enemy")
	w.weather = "clear"
	print("C12WX DONE fails=", _fails)
	get_tree().quit()
