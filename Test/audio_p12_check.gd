extends SceneTree
## P1/P2 audio batch checks: every second-batch key resolves to
## its produced file, the new public API actually plays, the
## shape dispatchers pick the right keys, and the ambience beds
## load as looping OGG and start/stop on command.
## See design/audio-production-p12.md.
var checks := 0
var fails := 0

func ck(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", msg)

func run() -> void:
	var a := GameAudio.new()
	root.add_child(a)
	await process_frame
	await process_frame
	var file_keys := ["hover", "shot_electric", "shot_ice", "shot_psychic",
		"shot_ghost", "beam", "beam_ice", "cone_fire", "cone_other",
		"nova", "nova_ground", "dodge", "land", "dive", "slam",
		"encounter", "throw_ball", "ball_open", "ball_shake",
		"slot_tick", "slot_lever", "slot_stop", "slot_coins",
		"slot_curse", "jackpot", "zap", "evolve_done", "streak",
		"confirm", "start", "panel_open", "panel_close", "buff",
		"chest_gold", "mimic", "ult_ready", "revive", "rage",
		"boss_down", "banish", "shiny_spawn", "terminal", "greet"]
	for k in file_keys:
		var s := a.stream_for(k)
		ck(s != null, k + " stream exists")
		if s:
			ck(s.resource_path == "res://assets/audio/sfx/" + k + ".wav",
				k + " is file-backed (got: " + s.resource_path + ")")
			ck(s.get_length() > 0.03, k + " has length")
			ck(s.mix_rate == 44100, k + " is 44.1 kHz")
	# The new public API plays (counted under its key).
	a.confirm()
	a.start()
	a.panel_open()
	a.buff()
	a.chest_gold()
	a.mimic()
	a.ult_ready()
	a.revive()
	a.rage()
	a.boss_down()
	a.banish()
	a.shiny_spawn()
	a.terminal()
	a.greet()
	for k in ["confirm", "start", "panel_open", "buff", "chest_gold",
			"mimic", "ult_ready", "revive", "rage", "boss_down",
			"banish", "shiny_spawn", "terminal", "greet"]:
		ck(a.count_of(k) >= 1, "API plays " + k)
	# panel_close shares the 0.05 s "panel" gate with panel_open;
	# wait it out before asserting the close slide plays.
	await create_timer(0.12).timeout
	a.panel_close()
	ck(a.count_of("panel_close") >= 1, "API plays panel_close")
	# Shape dispatchers pick the produced variants.
	a.shot("electric")
	ck(a.count_of("shot_electric") >= 1, "shot dispatches electric")
	a.shot("fire", -6.0)
	ck(a.count_of("shot_fire") >= 1, "shot accepts a volume offset")
	a.beam("ice")
	ck(a.count_of("beam_ice") >= 1, "beam dispatches ice")
	a.beam("fire")
	ck(a.count_of("beam") >= 1, "beam dispatches base")
	a.cone("fire")
	ck(a.count_of("cone_fire") >= 1, "cone dispatches fire")
	a.cone("water")
	ck(a.count_of("cone_other") >= 1, "cone dispatches other")
	a.nova(true)
	ck(a.count_of("nova_ground") >= 1, "nova dispatches ground")
	a.slot_tick()
	ck(a.count_of("slot_tick") >= 1, "slot_tick plays")
	# Ambience: beds load as looping OGG; layers start/stop.
	for k in ["amb_forest", "amb_rain", "amb_wind"]:
		var s := a._amb_stream(k)
		ck(s != null, k + " loads")
		if s:
			ck(s.loop, k + " loops (loop flag set at load)")
			ck(s.get_length() > 15.0, k + " is a long bed")
	ck(a._amb_players.size() == 2, "ambience has bed + weather players")
	a.ambience("forest")
	await process_frame
	ck(a._amb_players[0].playing, "forest bed plays")
	a.ambience_weather("rain")
	await process_frame
	ck(a._amb_players[1].playing, "rain layer plays")
	ck(a._amb_players[1].stream != null
		and a._amb_players[1].stream.resource_path.ends_with("amb_rain.ogg"),
		"rain layer is the rain bed")
	a.ambience_weather("fog")
	await process_frame
	ck(a._amb_players[1].stream != null
		and a._amb_players[1].stream.resource_path.ends_with("amb_wind.ogg"),
		"fog layer is the wind bed")
	a.ambience_weather("clear")
	ck(not a._amb_players[1].playing, "clear weather stops the layer")
	a.ambience("")
	ck(not a._amb_players[0].playing, "ambience stops the bed")
	print("AUDIO_P12 DONE checks=%d fails=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _initialize() -> void:
	call_deferred("run")
