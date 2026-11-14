## U5 fix4 probe: does _p5_place_modal ratchet across repeated
## _apply_ui_scale calls (fix3 loop + _p5_fit monotone floors)?
## Boot the real world like phonehud, open result/victory, print
## panel scale/min after each _apply_ui_scale, then bigmap likewise.
extends SceneTree

var _world: Node = null
var _t: int = 0
var _stage: int = 0

func _initialize() -> void:
	root.size = Vector2i(2400, 1080)
	var ps: PackedScene = load("res://scenes/main.tscn")
	_world = ps.instantiate()
	_world.set("debug_phone_factor", 1.925)
	_world.set("debug_safe_insets", Vector4.ZERO)
	_world.set("_touch_forced", true)
	root.add_child(_world)

func _dump(tag: String, p: Control) -> void:
	print("PROBE ", tag, " scale=", p.scale, " size=", p.size,
		" min=", p.get_combined_minimum_size(),
		" p5_sm=", p.get_meta("p5_sm", -1.0),
		" rect=", p.get_global_rect())

func _process(_delta: float) -> bool:
	_t += 1
	if _t == 60:
		_world.call("_finish_run", true)
	if _t == 90 and _stage == 0:
		_stage = 1
		var rp := _world.get("_result_panel") as Control
		_dump("result t90", rp)
	if _t == 120 and _stage == 1:
		_stage = 2
		_world.call("open_big_map")
	if _t == 150 and _stage == 2:
		_stage = 3
		var bm := _world.get("_bigmap_panel") as Control
		_dump("bigmap t150", bm)
		return true
	return false
