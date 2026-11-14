## U5 diag: boot the real world like phonehud, force the result
## panel open, and print the live fit numbers (ui_root size,
## panel/scroll/box combined mins, scale, meta). Settles why the
## P5 result panel lands at scale ~0.53 (small) instead of ~1.6.
extends SceneTree

var _world: Node = null
var _t: int = 0
var _done: bool = false

func _initialize() -> void:
	root.size = Vector2i(2400, 1080)
	var ps: PackedScene = load("res://scenes/main.tscn")
	_world = ps.instantiate()
	_world.set("debug_phone_factor", 1.925)
	_world.set("debug_safe_insets", Vector4.ZERO)
	_world.set("_touch_forced", true)
	root.add_child(_world)

func _process(_delta: float) -> bool:
	_t += 1
	if _t == 60:
		_world.call("_finish_run", false)
	if _t == 90 and not _done:
		_done = true
		var rp := _world.get("_result_panel") as Control
		var ui := _world.get("_ui_root") as Control
		var rb := _world.get("_result_box") as Control
		var sc := rb.get_parent() as Control
		print("DIAG ui_root size: ", ui.size)
		print("DIAG result combined min: ", rp.get_combined_minimum_size())
		print("DIAG result scale: ", rp.scale, " size: ", rp.size)
		print("DIAG result meta p5_sm: ", rp.get_meta("p5_sm", -1.0), " p5_w: ", rp.get_meta("p5_w", -1.0))
		print("DIAG result_box combined min: ", rb.get_combined_minimum_size())
		print("DIAG scroll combined min: ", sc.get_combined_minimum_size(), " class: ", sc.get_class())
		print("DIAG result rect: ", rp.get_global_rect())
		return true
	return false
