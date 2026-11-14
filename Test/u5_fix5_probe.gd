## U5 fix5 probe: per-child minimum-size breakdown of the result
## panel in s100-exact geometry (2400x1080 window, phone factor
## 1.925, _touch_forced) -- the fix4 scroll trim (400->340) left
## the panel min at 786, so the 14 px spill survived; find which
## fixed child actually sets the 786.
## Boots like phonehud: resize window first, wait 8 frames, then
## instantiate the world, so _ui_root is 1600x720 like s100.
extends SceneTree

var _world: Node = null
var _t: int = 0
var _stage: int = 0

func _initialize() -> void:
	root.size = Vector2i(2400, 1080)

func _child_dump(prefix: String, c: Control) -> void:
	print("PROBE ", prefix, " ", c.get_class(), " '", c.name,
		"' min=", c.get_combined_minimum_size(),
		" size=", c.size,
		" custom_min=", c.custom_minimum_size)

func _dump() -> void:
	var rp := _world.get("_result_panel") as Control
	var ur := _world.get("_ui_root") as Control
	print("PROBE ui_root size=", ur.size)
	print("PROBE result scale=", rp.scale, " size=", rp.size,
		" min=", rp.get_combined_minimum_size(),
		" p5_sm=", rp.get_meta("p5_sm", -1.0),
		" rect=", rp.get_global_rect())
	var vb := rp.get_child(0) as Control
	print("PROBE vb min=", vb.get_combined_minimum_size(), " size=", vb.size)
	for ch in vb.get_children():
		_child_dump("vb", ch)
		if ch.name == "ScrollContainer" or ch.get_class() == "ScrollContainer":
			for gch in ch.get_children():
				_child_dump("scroll>", gch)
				for gg in (gch as Control).get_children():
					_child_dump("scroll>>", gg)
	var core := _world.get("_result_core") as Control
	if core != null:
		print("PROBE core min=", core.get_combined_minimum_size(), " size=", core.size)
		for ch in core.get_children():
			_child_dump("core", ch)
	var sb := _world.get("_result_box") as Control
	if sb != null:
		print("PROBE result_box min=", sb.get_combined_minimum_size(),
			" size=", sb.size, " children=", sb.get_child_count())
	var st := rp.get_theme_stylebox("panel") as StyleBox
	if st != null:
		print("PROBE panel stylebox content margins L/T/R/B=",
			st.content_margin_left, "/", st.content_margin_top, "/",
			st.content_margin_right, "/", st.content_margin_bottom)

func _process(_delta: float) -> bool:
	_t += 1
	if _t == 8 and _stage == 0:
		_stage = 1
		var ps: PackedScene = load("res://scenes/main.tscn")
		_world = ps.instantiate()
		_world.set("debug_phone_factor", 1.925)
		_world.set("debug_safe_insets", Vector4.ZERO)
		_world.set("_touch_forced", true)
		root.add_child(_world)
	if _t == 68 and _stage == 1:
		_stage = 2
		_world.call("_finish_run", true)
	if _t == 98 and _stage == 2:
		_stage = 3
		_dump()
	if _t == 128 and _stage == 3:
		_stage = 4
		_dump()
		return true
	return false
