extends SceneTree
## Cry batch checks: every species the game can field (the 159
## species of the 79 roster families, computed here from the same
## data files the game ships) resolves through cry_stream_for to
## its own produced file at 44.1 kHz; the three generic fallbacks
## exist and catch unlisted ids; cry() actually plays (counted).
## Distinctness / family casting are verified at generation time
## (generate_cries.py QA in design/audio-production-cries.md).
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
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/roster.json"))
	var poke = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/pokemon.json"))
	ck(roster is Dictionary, "roster.json parses")
	ck(poke is Array, "pokemon.json parses")
	var fams := {}
	for k in roster.keys():
		fams[int(k)] = true
	var keys: Array[String] = []
	for sp in poke:
		if fams.has(int(sp["family"])):
			keys.append(String(sp["key"]))
	ck(keys.size() == 159, "fielded species set is 159 (got %d)" % keys.size())
	for key in keys:
		var s := a.cry_stream_for(key)
		ck(s != null, key + " cry resolves")
		if s:
			ck(s.resource_path == "res://assets/audio/sfx/cry_" + key + ".wav",
				key + " cry is its own file (got: " + s.resource_path + ")")
			ck(s.mix_rate == 44100, key + " cry is 44.1 kHz")
			ck(s.get_length() > 0.15 and s.get_length() < 1.25,
				key + " cry length sane")
	for b in ["s", "m", "l"]:
		ck(ResourceLoader.exists("res://assets/audio/sfx/cry_fallback_" + b + ".wav"),
			"fallback " + b + " exists")
	var unk := a.cry_stream_for("missingno_unlisted_probe")
	ck(unk != null and unk.resource_path.begins_with("res://assets/audio/sfx/cry_fallback_"),
		"unlisted id resolves to a fallback file (got: " + (unk.resource_path if unk else "null") + ")")
	for key in ["bulbasaur", "charmander", "squirtle", "meowth", "gengar"]:
		a.cry(key)
		ck(a.count_of("cry:" + key) >= 1, "cry plays " + key)
	print("AUDIO_CRY DONE checks=%d fails=%d" % [checks, fails])
	quit(1 if fails > 0 else 0)

func _initialize() -> void:
	call_deferred("run")
