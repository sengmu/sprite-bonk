extends Node
## HP-bar alignment capture (cycle 10). Boots the real world,
## starts a run, builds a damaged horde around the player (the
## user's screenshot scenario), snaps it, then summons the
## guardian damaged and snaps that. Tag via -- --tag=<name>:
## outputs Test/out/horde_<tag>.png and Test/out/boss_<tag>.png.
## Used for before/after evidence when world-space bars were
## removed in favour of the bundle's HUD bars.

var _world: Node
var _tag := "after"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
	_run()

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://Test/out/" + name + ".png")
	print("BARSHOT ", name)

func _run() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	_world = ps.instantiate()
	add_child(_world)
	await _frames(10)
	_world.start_game("bulbasaur")
	var p = null
	for i in range(600):
		await get_tree().physics_frame
		p = _world.get("player")
		if p != null and p.get("rig") != null and bool(p.get("rig").get("fitted")):
			break
	if p == null:
		print("BARSHOT FAIL no player")
		get_tree().quit(1)
		return
	p.invulnerable = true
	# --- horde: a ring of damaged foes closing in (user's shot) ---
	var species := ["rattata", "pidgey", "zubat", "caterpie", "weedle", "spearow"]
	var fracs := [0.32, 0.55, 0.78, 0.45, 0.66, 0.28, 0.6, 0.72, 0.4, 0.5, 0.85, 0.36]
	for i in range(12):
		var ang := TAU * float(i) / 12.0 + 0.26
		var r := 3.8 + float(i % 3) * 1.1
		var pos: Vector3 = p.global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		var foe = _world._spawn_enemy_at(species[i % species.size()], pos, 1.0)
		foe.take_damage(foe.max_hp * (1.0 - fracs[i]))
	# Player at ~55% HP: old world bar shows number + partial fill;
	# new HUD bar shows the mid band + lag ghost after regen ticks.
	p.hp = p.max_hp * 0.55
	await _frames(35)
	_snap("horde_" + _tag)
	# --- guardian: HUD boss bar (after) vs world pill (before) ---
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(5)
	_world.summon_guardian()
	var g = _world.get("guardian")
	if g == null:
		print("BARSHOT FAIL no guardian")
		get_tree().quit(1)
		return
	await _frames(10)
	g.take_damage(g.max_hp * 0.38)
	p.global_position = g.global_position + Vector3(6.5, 0.0, 6.5)
	# Wait out the summon banner (3.5 s) so the boss bar is bare.
	await _frames(320)
	_snap("boss_" + _tag)
	print("BARSHOT DONE")
	get_tree().quit()
