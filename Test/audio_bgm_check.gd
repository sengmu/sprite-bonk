extends SceneTree
## BGM batch checks: every engine track name resolves to its
## produced OGG file, play_track puts the file (not the legacy
## sequencer render) on the active music player with looping on
## and unity pitch, re-asking for the current track is a no-op,
## and stop_music clears the track. File format / loudness /
## true-peak are verified at generation time (generate_bgm.py +
## ffmpeg loudnorm, numbers in design/audio-production-bgm.md).
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
	var tracks := ["menu", "ingame1", "ingame2", "ingame3", "ingame4", "boss"]
	for t in tracks:
		var path := "res://assets/audio/music/bgm_" + t + ".ogg"
		ck(ResourceLoader.exists(path), t + " file exists")
		a.play_track(t)
		ck(a.current_track == t, t + " is current")
		var p = a._music_players[a._music_active]
		ck(p.stream != null, t + " has a stream")
		if p.stream:
			ck(p.stream is AudioStreamOggVorbis, t + " stream is OGG (file, not sequencer WAV)")
			ck(p.stream.resource_path == path, t + " stream path is the produced file (got: " + p.stream.resource_path + ")")
			ck(p.stream.loop, t + " loops")
			ck(p.stream.get_length() > 5.0, t + " has real length")
		ck(absf(p.pitch_scale - 1.0) < 0.001, t + " plays at unity pitch")
		ck(a.count_of("track:" + t) >= 1, t + " play counted")
		var before: int = a.count_of("track:" + t)
		a.play_track(t)
		ck(a.count_of("track:" + t) == before, t + " re-ask is a no-op")
	a.stop_music()
	ck(a.current_track == "", "stop_music clears current track")
	print("AUDIO_BGM DONE checks=%d fails=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _initialize() -> void:
	call_deferred("run")
