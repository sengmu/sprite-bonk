extends Node
## Portrait bake (cycle 17). Renders every modelled species'
## rig in a transparent SubViewport studio (front three-quarter
## framing on the head/upper body) and saves
## assets/portraits/<species>.png discs for the HUD medallion
## and the menu/draft cards. Run:
##   godot --path . res://Test/portraitshot.tscn
## Post-process (circular alpha mask) is a separate PIL step in
## the cycle-17 log; this scene only renders square frames.

const SIZE := 224

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var w := World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.78)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	w.environment = env
	_vp.world_3d = w
	add_child(_vp)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = false
	_vp.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.6, 1.2, 2.6)
	fill.light_energy = 0.5
	fill.omni_range = 8.0
	_vp.add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_run()

var _box := AABB()
var _box_first := true

func _collect_aabb(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var b := mi.global_transform * mi.mesh.get_aabb()
			_box = b if _box_first else _box.merge(b)
			_box_first = false
	for ch in n.get_children():
		_collect_aabb(ch)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _run() -> void:
	await _frames(5)
	var keys := ModelRig.SPECIES.keys()
	keys.sort()
	# --only=a,b,c bakes a subset (batching keeps each run
	# inside one foreground window on the software renderer).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			keys = a.trim_prefix("--only=").split(",")
	for key in keys:
		var cfg: Dictionary = ModelRig.SPECIES[key]
		var rig := ModelRig.new()
		_holder.add_child(rig)
		rig.setup(key)
		var waited := 0
		while not rig.fitted and waited < 600:
			await get_tree().process_frame
			waited += 1
		if not rig.fitted:
			print("PORTRAIT FAIL ", key, " (rig never fitted)")
			rig.queue_free()
			await _frames(2)
			continue
		# Framing: nearly full body on the rig origin (the
		# game's own placement center), with only the
		# horizontal center taken from the fitted AABB —
		# charmander's GLB origin sits off its body axis,
		# while full-AABB framing proved unstable (bind-pose
		# boxes on skinned meshes). Height is the fitted
		# cycle-9 height from the species cfg.
		_box_first = true
		_collect_aabb(rig)
		var h := float(cfg["height"])
		var cx := 0.0
		if not _box_first and _box.size.y > 0.1:
			cx = clampf(_box.get_center().x, -h * 0.3, h * 0.3)
		var frame_h: float = h * 1.06
		var dist: float = (frame_h * 0.5) / tan(deg_to_rad(_cam.fov * 0.5)) * 1.05
		var target := Vector3(cx, h * 0.50, 0)
		_cam.position = target + Vector3(dist * 0.14, h * 0.04, dist)
		_cam.look_at(target, Vector3.UP)
		await _frames(3)
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		# Absolute path: res:// writes from a backgrounded run
		# were lost to the VM's volatile overlay twice (cycle-17
		# log); the bake tool writes straight to the workspace.
		var path: String = "/home/hatch/workspace/sprite-bonk-3d/assets/portraits/" + String(key) + ".png"
		var err := img.save_png(path)
		print("PORTRAIT ", key, " size=", img.get_size(), " save_err=", err,
			" exists=", FileAccess.file_exists(path))
		rig.queue_free()
		await _frames(2)
	print("PORTRAIT DONE")
	get_tree().quit()
