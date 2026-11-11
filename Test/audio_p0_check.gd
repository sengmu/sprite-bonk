extends SceneTree
## P0 audio batch checks: every produced SFX key must resolve to
## its file under assets/audio/sfx/ (not the legacy synth), an
## unproduced key must still fall back to the synth, and the BGM
## track path must be untouched. See design/audio-production-p0.md.
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
	# GameAudio fills its noise buffer in _ready(); it must enter
	# the tree before any stream_for() call, like in world.gd.
	var a := GameAudio.new()
	root.add_child(a)
	await process_frame
	await process_frame
	var file_keys := ["click", "deny", "xp", "coin", "sparkle", "heal",
		"chest", "charge", "bell", "whoosh", "shot_default", "shot_grass",
		"shot_fire", "shot_water", "slash", "ult_grass", "ult_fire",
		"ult_water", "hit_weak", "hit_neutral", "hit_super", "hit_crit",
		"mega", "pop", "hurt", "jump", "alarm", "boom", "boss_start",
		"level_up", "power", "victory", "defeat", "ball_click", "caught"]
	for k in file_keys:
		var s := a.stream_for(k)
		ck(s != null, k + " stream exists")
		if s:
			ck(s.resource_path == "res://assets/audio/sfx/" + k + ".wav",
				k + " is file-backed (got: " + s.resource_path + ")")
			ck(s.get_length() > 0.03, k + " has length")
			ck(s.mix_rate == 44100, k + " is 44.1 kHz")
	var fb := a.stream_for("slot_tick")
	ck(fb != null, "fallback renders unproduced key slot_tick")
	if fb:
		ck(fb.resource_path == "", "fallback is synth (no resource_path)")
	var tr := a.stream_for("track:menu")
	ck(tr != null and tr.get_length() > 1.0, "BGM track path intact")
	print("AUDIO_P0 DONE checks=%d fails=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)
