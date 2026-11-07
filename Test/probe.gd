extends Node3D
## Isolated rig probe (Test/* is excluded from exports): builds ONE
## ModelRig through the real setup() path on a flat cyan void with a
## 1.3 u reference box, freezes its pose, and dumps visibility-diff
## screenshots. The offline pass measures the RENDERED silhouette
## height + body color — the ground truth the bind-AABB fit math is
## checked against (hotfix: Charmander-as-player rendered at 1/4 size
## while its fit believed the bind box).
##
## Usage: godot --path . res://Test/probe.tscn -- --species=charmander

var _species := "charmander"
var _mode := "fitted"
var _dist := 1.0
var _rig: ModelRig
var _phase := 0
var _frames := 0
var _cam: Camera3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			_species = a.trim_prefix("--species=")
		elif a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")
		elif a.begins_with("--dist="):
			_dist = float(a.trim_prefix("--dist="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Test/out"))
	# Flat cyan void.
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 1.0, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.83, 1.0)
	env.ambient_light_energy = 1.05
	we.environment = env
	add_child(we)
	# Sun approximating the game's (energy ~1.65, warm).
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.65
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = false
	add_child(sun)
	# Camera: fitted mode frames y 0..~2 at z=0; native mode pulls
	# back so tall species (charizard ~4 u) stay inside the frame.
	_cam = Camera3D.new()
	_cam.fov = 50.0
	if _mode == "native":
		_cam.position = Vector3(0, 1.3 * _dist, 8.0 * _dist)
		add_child(_cam)
		_cam.look_at(Vector3(0, 1.0 * _dist, 0), Vector3.UP)
	else:
		_cam.position = Vector3(0, 0.9, 4.4)
		add_child(_cam)
		_cam.look_at(Vector3(0, 0.7, 0), Vector3.UP)
	# Reference box: exactly 1.3 u tall, unshaded green, at x=+1.15.
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 1.3, 0.3)
	box.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(0.0, 1.0, 0.0)
	box.material_override = bmat
	box.position = Vector3(1.15, 0.65, 0)
	add_child(box)
	# The rig under test.
	_rig = ModelRig.new()
	add_child(_rig)
	_rig.setup(_species)

func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://Test/out/" + name + ".png")
	print("SNAP ", name)

func _process(_delta: float) -> void:
	_frames += 1
	match _phase:
		0:
			if _rig and _rig.fitted:
				var cfg: Dictionary = ModelRig.SPECIES[_species]
				var denom := -1.0
				if _rig.model.scale.x > 0.0001:
					denom = float(cfg["height"]) / _rig.model.scale.x
				print("DIAG PROBE species=", _species,
					" cfg_h=", float(cfg["height"]),
					" model_scale=", _rig.model.scale.x,
					" believed_denom=", denom)
				if _mode == "native":
					# Undo the fit: measure the raw authored render at
					# scale 1 with the model origin at the rig origin.
					# Species with a lay-flat rot_x keep it (that IS
					# their authored pose in-game).
					var rx := 0.0
					if cfg.has("rot_x"):
						rx = float(cfg["rot_x"])
					_rig.model.scale = Vector3.ONE
					_rig.model.position = Vector3.ZERO
					_rig.model.rotation = Vector3(rx, 0, 0)
				_rig.process_mode = Node.PROCESS_MODE_DISABLED  # freeze pose
				_phase = 1
				_frames = 0
			elif _frames > 3600:
				print("PROBE TIMEOUT")
				get_tree().quit(1)
		1:
			if _frames == 4:
				_snap("probe_" + _species + ("_native" if _mode == "native" else "") + "_all")
			elif _frames == 6:
				_rig.model.visible = false
			elif _frames == 8:
				_snap("probe_" + _species + ("_native" if _mode == "native" else "") + "_none")
			elif _frames == 10:
				var y0: Vector2 = _cam.unproject_position(Vector3(0, 0.0, 0))
				var y1: Vector2 = _cam.unproject_position(Vector3(0, 1.3, 0))
				print("PXPERUNIT probe=", absf(y1.y - y0.y) / 1.3,
					" anchor=", _cam.unproject_position(Vector3.ZERO))
				print("PROBE DONE ", _species)
				get_tree().quit()
