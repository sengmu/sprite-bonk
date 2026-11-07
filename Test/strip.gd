extends Node3D
## Gait frame-strip capture (Segment Z): walks ONE rig in a straight
## line past ground markers at a fixed speed and dumps a timed
## sequence of frames; an offline montage shows the stride cycle,
## bob and foot behaviour. Run before/after a gait change with
## --tag=before|after and compare the strips.
##
## Usage: godot --path . res://Test/strip.tscn -- --species=rattata --tag=after

var _species := "rattata"
var _tag := "after"
var _speed := 3.2
var _rig: ModelRig
var _cam: Camera3D
var _t := 0.0
var _shot := 0
var _started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--species="):
			_species = a.trim_prefix("--species=")
		elif a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
		elif a.begins_with("--speed="):
			_speed = float(a.trim_prefix("--speed="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Test/out"))
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.12, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.83, 1.0)
	env.ambient_light_energy = 1.05
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.65
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = false
	add_child(sun)
	# Ground plane + marker posts every 0.5 u (foot-skate reference).
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.16, 0.22, 0.14)
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(60, 0.1, 8)
	ground.mesh = gm
	ground.material_override = gmat
	ground.position = Vector3(10, -0.05, 0)
	add_child(ground)
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.9, 0.9, 0.9)
	for i in range(41):
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.06, 0.5, 0.06)
		post.mesh = pm
		post.material_override = mmat
		post.position = Vector3(-2.0 + float(i) * 0.5, 0.25, -1.4)
		add_child(post)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_rig = ModelRig.new()
	add_child(_rig)
	_rig.setup(_species)
	_rig.position = Vector3(-2.0, 0, 0)

func _process(delta: float) -> void:
	if _rig == null or not _rig.fitted:
		return
	if not _started:
		_started = true
		_rig.set_facing(Vector3(1, 0, 0))
		_rig.set_move_speed(_speed)
	_t += delta
	_rig.position.x += _speed * delta
	_cam.position = Vector3(_rig.position.x + 0.4, 1.1, 4.6)
	_cam.look_at(Vector3(_rig.position.x + 0.4, 0.65, 0), Vector3.UP)
	var want := int(_t / 0.11)
	if want > _shot and _shot < 16:
		_shot = want
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://Test/out/strip_%s_%s_%02d.png" % [_species, _tag, _shot])
		print("STRIP ", _species, " ", _tag, " ", _shot)
	if _shot >= 16:
		print("STRIP DONE ", _species, " ", _tag)
		get_tree().quit()
