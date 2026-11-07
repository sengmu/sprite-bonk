extends Node
## Zone dressing + minimap composite capture (cycle 9).
## Boots the real world, starts a run, then walks zones 1..4
## through the game's own _apply_zone_visuals and screenshots
## each arena from the spawn view. Zone 1 also gets a chest +
## an ally so the minimap markers (r=6 ally w/ stroke, chest
## dots) are in frame. Output: Test/out/zone<n>.png.

var _world: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://Test/out/" + name + ".png")
	print("ZONESHOT ", name)

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
		print("ZONESHOT FAIL no player")
		get_tree().quit(1)
		return
	p.invulnerable = true
	# Minimap dressing: an ally + a chest near the player.
	var foe = _world._spawn_enemy_at("rattata", p.global_position + Vector3(3, 0, 2), 1.0)
	foe.make_ally()
	_world._spawn_chest(p.global_position + Vector3(-3, 0, -2))
	await _frames(30)
	for z in range(1, 5):
		_world.set("zone", z)
		_world._apply_zone_visuals()
		await _frames(45)
		_snap("zone%d" % z)
	print("ZONESHOT DONE")
	get_tree().quit()
