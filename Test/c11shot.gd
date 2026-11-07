extends Node
## Cycle 11 capture: environment composition + melee FX, before/after
## pairs from matched viewpoints on the real game. Scenes:
##   env_spawn_<tag>  spawn basin, settled gameplay camera
##   env_mid_<tag>    mid-field at (58,-50)
##   env_far_<tag>    far field at (-95,62)
##   fx_strike_<tag>  real tackle strike, caught mid-swing
##   fx_vine_<tag>    real vine-whip strike, caught mid-swing
##   fx_slam_<tag>    real player_slam rings
##   zone2/3/4_<tag>  spawn view after each portal advance
## Usage: godot ... res://Test/c11shot.tscn -- --tag=before

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
	# Let one render frame land after the last physics tick.
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://Test/out/" + name + ".png")
	print("C11SHOT ", name)

func _settle() -> void:
	# Wait until the gameplay camera stops moving (damped follow).
	var cam = _world.get("_cam")
	var last: Vector3 = cam.global_position
	for i in range(40):
		await _frames(10)
		var now: Vector3 = cam.global_position
		if now.distance_to(last) < 0.03:
			return
		last = now

func _teleport(p: Node, x: float, z: float) -> void:
	p.global_position = Vector3(x, _world.height_at(x, z), z)
	p.reset_physics_interpolation()
	_world.set("_cam_focus", p.global_position)

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
		print("C11SHOT FAIL no player")
		get_tree().quit(1)
		return
	p.invulnerable = true
	await _settle()
	await _snap("env_spawn_" + _tag)
	_teleport(p, 58.0, -50.0)
	await _settle()
	await _snap("env_mid_" + _tag)
	_teleport(p, -95.0, 62.0)
	await _settle()
	await _snap("env_far_" + _tag)
	# --- combat FX: real strikes against a ring of foes ---
	_teleport(p, 0.0, 6.0)
	await _settle()
	var species := ["rattata", "pidgey", "caterpie"]
	for i in range(3):
		var ang := -0.5 + float(i) * 0.5
		var pos: Vector3 = p.global_position + Vector3(sin(ang) * 2.3, 0.0, -cos(ang) * 2.3)
		_world._spawn_enemy_at(species[i], pos, 1.0)
	var got := await _wait_fx(500)
	await _snap("fx_strike_" + _tag)
	print("C11SHOT strike fx seen: ", got)
	var skinds := []
	for fx in _world.get("_effects"):
		skinds.append(str(fx.get("kind", "legacy")))
	print("C11SHOT strike effects: ", skinds, " particles: ", _world.get("_particles").size())
	# Vine whip: swap the loadout for the signature move (real path).
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	# Clear lingering FX from the tackle shot so they can't pose as
	# the vine cast in frame (a 0.16 s beam outlives the loadout swap).
	for fx in _world.get("_effects"):
		if is_instance_valid(fx.get("node")):
			fx["node"].queue_free()
	_world.get("_effects").clear()
	for pt in _world.get("_particles"):
		if is_instance_valid(pt.get("node")):
			pt["node"].queue_free()
	_world.get("_particles").clear()
	await _frames(5)
	p.moves.clear()
	p.moves.append({"key": "vine-whip", "level": 1, "mult": 1.0, "cd_t": 0.0})
	for i in range(3):
		var ang := -0.5 + float(i) * 0.5
		var pos: Vector3 = p.global_position + Vector3(sin(ang) * 2.3, 0.0, -cos(ang) * 2.3)
		_world._spawn_enemy_at(species[i], pos, 1.0)
	got = await _wait_fx(500)
	await _snap("fx_vine_" + _tag)
	print("C11SHOT vine fx seen: ", got)
	var kinds := []
	for fx in _world.get("_effects"):
		var nd = fx.get("node")
		var verts := -1
		if nd != null and nd.get_child_count() > 0 and nd.get_child(0) is MeshInstance3D:
			verts = nd.get_child(0).mesh.surface_get_array_len(0)
		elif nd is MeshInstance3D:
			verts = nd.mesh.surface_get_array_len(0)
		kinds.append(str(fx.get("kind", "legacy")) + ":" + str(verts))
	print("C11SHOT vine effects: ", kinds, " particles: ", _world.get("_particles").size(), " moves: ", p.moves)
	# Slam rings through the real slam entry point.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(5)
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + 0.4
		var pos: Vector3 = p.global_position + Vector3(cos(ang) * 2.0, 0.0, sin(ang) * 2.0)
		_world._spawn_enemy_at(species[i % 3], pos, 1.0)
	await _frames(3)
	_world.player_slam(p.global_position, 8.0, true)
	await _snap("fx_slam_" + _tag)
	# --- zones 2-4 spawn views ---
	for z in range(2, 5):
		_world._advance_zone()
		await _settle()
		await _frames(250)  # banner (4 s) clears
		await _snap("zone%d_%s" % [z, _tag])
	print("C11SHOT DONE")
	get_tree().quit()

func _wait_fx(max_frames: int) -> bool:
	# Wait for a NEW cast (cast parity increments in spawn_strike_fx)
	# so a previous move's tail can't pose as this shot's effect.
	var before: int = _world.get("_cast_parity")
	for i in range(max_frames):
		await get_tree().physics_frame
		if int(_world.get("_cast_parity")) > before:
			return true
	return false
