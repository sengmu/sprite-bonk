extends "res://Test/phonehud.gd"
## P3 fix round 2 diagnostic (throwaway, not a gate): logs the
## objective drawer's drawn rect + visibility at every touch the
## gate injects and at every drawer check. Base logic untouched.

func _p3r2_dr() -> String:
	if _world == null:
		return "<no world>"
	var dr = _world.get("_obj_drawer")
	if not (dr is Control):
		return "<no drawer>"
	var c := dr as Control
	return "vis=%s rect=%s t=%.2f state=%s" % [str(c.visible), str(_vis_rect(c)),
		float(_world.get("_obj_drawer_t")), String(_world.get("state"))]

func _p1_touch(idx: int, pos: Vector2, down: bool) -> void:
	var dr = _world.get("_obj_drawer") if _world != null else null
	if dr is Control and (dr as Control).visible:
		print("P3R2DIAG touch idx=%d pos=%s down=%s BEFORE %s" % [idx, str(pos), str(down), _p3r2_dr()])
	super(idx, pos, down)

func _check(name: String, ok: bool, detail: String = "") -> void:
	if name.contains("drawer"):
		print("P3R2DIAG check '%s' ok=%s %s" % [name, str(ok), _p3r2_dr()])
	super(name, ok, detail)

func _input(event: InputEvent) -> void:
	if _world == null:
		return
	var dr = _world.get("_obj_drawer")
	if not (dr is Control) or not (dr as Control).visible:
		return
	var pp := Vector2.INF
	var kind := ""
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pp = (event as InputEventScreenTouch).position
		kind = "touch"
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		pp = (event as InputEventMouseButton).position
		kind = "mouse"
	if pp == Vector2.INF:
		return
	var c := dr as Control
	var r: Rect2 = _world.call("_p3_draw_rect", c)
	var hit := _world.get("_obj_hit") as Control
	print("P3R2DIAG input %s pp=%s drawer=%s has=%s size=%s min=%s hit=%s/%s" % [kind, str(pp), str(r),
		str(r.has_point(pp)), str(c.size), str(c.get_combined_minimum_size()),
		str(hit.visible), str(hit.get_global_rect())])

var _p3r2_last := ""

func _process(_d: float) -> void:
	if _world == null:
		return
	var dr = _world.get("_obj_drawer")
	if not (dr is Control) or not (dr as Control).visible:
		_p3r2_last = ""
		return
	var c := dr as Control
	var box := _world.get("_obj_drawer_box") as Control
	var sc := _world.get("_obj_drawer_scroll") as Control
	var rows: Array = []
	for ch in box.get_children():
		if ch is Control:
			rows.append("%s:%.0f" % [ch.get_class().substr(0, 4), (ch as Control).get_combined_minimum_size().y])
	var s := "size=%s ob=%.1f min=%.1f box_min=%.1f scroll_min=%.1f scroll_sz=%.1f rows=%s sig=%s" % [
		str(c.size), c.offset_bottom, c.get_combined_minimum_size().y, box.get_combined_minimum_size().y,
		sc.custom_minimum_size.y, sc.size.y, str(rows), String(_world.get("_obj_drawer_sig")).substr(0, 120)]
	if s != _p3r2_last:
		_p3r2_last = s
		print("P3R2DIAG frame %d %s" % [Engine.get_process_frames(), s])
