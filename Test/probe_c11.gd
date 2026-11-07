extends Node
## Cycle 11 seed-fitness probe: for each zone, roll layout seeds and
## score spawn-area openness (the original's spawn reads as an open
## glade). Score = mean over r in {12,18,24,30,36} x 16 angles of
## clamp(1 - |h - XD| / 7). Higher = gentler spawn neighbourhood.

func _ready() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	var w = ps.instantiate()
	add_child(w)
	await get_tree().physics_frame
	for zone in range(1, 5):
		w.set("zone", zone)
		var best := -1.0
		var best_roll := 0
		var rolls := range(12)
		if zone == 1:
			rolls = range(42)  # headline zone gets a deeper scan
		for roll in rolls:
			w.set("_seed_roll_override", roll)
			var t0 := Time.get_ticks_msec()
			w._gen_terrain()
			var gen_ms := Time.get_ticks_msec() - t0
			var score := 0.0
			var cnt := 0
			for r in [12.0, 18.0, 24.0, 30.0, 36.0]:
				for a in range(16):
					var ang := float(a) / 16.0 * TAU
					var rf: float = r
					var h: float = w.height_at(cos(ang) * rf, sin(ang) * rf)
					score += clampf(1.0 - absf(h - 4.6) / 7.0, 0.0, 1.0)
					cnt += 1
			score /= float(cnt)
			print("ROLL zone ", zone, " roll ", roll, " score ", snappedf(score, 0.001), " gen ", gen_ms, " ms ponds ", w.get("_ponds").size())
			if score > best:
				best = score
				best_roll = roll
		print("ROLL zone ", zone, " BEST roll ", best_roll, " score ", snappedf(best, 0.001))
	print("ROLL DONE")
	get_tree().quit()
