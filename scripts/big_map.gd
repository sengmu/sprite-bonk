class_name BigMap
extends Control
## The big-map modal's map square (Cycle 18; UI_SPEC §4.2
## map modal, mined @1982885/@2093942: side length ≈ min(
## vh*.82, vw*.9) for the big variant; a side list of
## discovered things; up to 3 player pins; fog = only visited
## ground is shown, objectives stay visible).
##
## Draws the CURRENT zone's baked terrain, the world's fog
## grid (48×48 over +-170 u; unvisited cells go dark), the
## discoverable markers (altar gold / portal violet per the
## minimap's established colors), the guardian, the player,
## and the player's pins (gold #ffd23a). Clicking places or
## removes a pin through World._bigmap_click.

var world: Node = null

## Icon order 2: markers wear the shipped map art; fog, pins
## logic and click handling are unchanged.
const TEX_PIN := preload("res://assets/ui/badges/map_pin_player.png")
const TEX_STAR := preload("res://assets/ui/badges/map_star.png")
const TEX_CHEST := preload("res://assets/ui/badges/map_chest.png")
const TEX_DOT_PURPLE := preload("res://assets/ui/badges/map_dot_purple.png")
const TEX_EVENT_RED := preload("res://assets/ui/badges/event_dot_red.png")

func _mark(tex: Texture2D, at: Vector2, sz: float, mod := Color.WHITE) -> void:
	draw_texture_rect(tex, Rect2(at - Vector2.ONE * sz * 0.5, Vector2.ONE * sz), false, mod)

func _pin(at: Vector2, sz: float, mod := Color.WHITE) -> void:
	# Pin art anchors by its tip: rect bottom-centre on the point.
	draw_texture_rect(TEX_PIN, Rect2(at - Vector2(sz * 0.5, sz), Vector2.ONE * sz), false, mod)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(420, 420)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if world != null and world.has_method("_bigmap_click"):
			world._bigmap_click(event.position)

func _w2m(p: Vector3) -> Vector2:
	var wr := 170.0
	return Vector2((p.x / (wr * 2.0) + 0.5) * size.x,
		(p.z / (wr * 2.0) + 0.5) * size.y)

func _draw() -> void:
	if world == null:
		return
	# Cycle 22: fog blinding (sx.blind, bundle big-map
	# draw @2031938) — the whole square fills with fog;
	# only the player dot remains.
	if world.has_method("event_blind") and bool(world.event_blind()):
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.275, 0.235, 0.392, 0.85))
		var bpl = world.get("player")
		if bpl != null and is_instance_valid(bpl):
			_pin(_w2m(bpl.global_position), 22.0)
		return
	var tex: Texture2D = world.get("terrain_baked")
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	else:
		# 兜底使用深羊皮/暗苔蓝底色，避免大片死黑块
		draw_rect(Rect2(Vector2.ZERO, size), Color("192233"))
	# 柔和暗苔蓝未探索迷雾（保留探索神秘感与柔和坐标格，不再大面积纯黑沉闷）
	var fog: PackedByteArray = world.get("_fog")
	if fog.size() == 48 * 48:
		var cw := size.x / 48.0
		var ch := size.y / 48.0
		for gy in range(48):
			for gx in range(48):
				if fog[gy * 48 + gx] == 0:
					draw_rect(Rect2(gx * cw, gy * ch, cw + 1.0, ch + 1.0),
						Color(0.10, 0.13, 0.21, 0.72))
	# 淡雅 8×8 战术坐标网格线，提升全图定位感
	var gline_col := Color(1.0, 1.0, 1.0, 0.055)
	for gi in range(1, 8):
		var p_off := float(gi) / 8.0
		draw_line(Vector2(p_off * size.x, 0.0), Vector2(p_off * size.x, size.y), gline_col, 1.0)
		draw_line(Vector2(0.0, p_off * size.y), Vector2(size.x, p_off * size.y), gline_col, 1.0)
	var ap = world.get("altar_pos")
	if ap != null:
		var ap2 := _w2m(ap)
		draw_circle(ap2, 11.0, Color(0.10, 0.08, 0.18, 0.65))
		_mark(TEX_STAR, ap2, 18.0)
		draw_arc(ap2, 10.0, 0, TAU, 24, Color("ffe169"), 1.5)
	var pn = world.get("portal_node")
	if pn != null and is_instance_valid(pn):
		var pp := _w2m((pn as Node3D).global_position)
		draw_circle(pp, 10.0, Color(0.15, 0.08, 0.28, 0.65))
		_mark(TEX_DOT_PURPLE, pp, 14.0)
		draw_arc(pp, 9.5, 0, TAU, 24, Color.WHITE, 1.5)
	for c in world.call("chests_positions"):
		_mark(TEX_CHEST, _w2m(c), 14.0)
	var g: Node = world.get("guardian")
	if g != null and is_instance_valid(g) and float(g.get("hp")) > 0.0:
		var gp := _w2m(g.global_position)
		draw_circle(gp, 11.5, Color(0.25, 0.04, 0.08, 0.72))
		_mark(TEX_EVENT_RED, gp, 16.0)
		draw_arc(gp, 11.0, 0, TAU, 24, Color(1, 0.28, 0.35), 2.0)
	for pin in world.get("_map_pins"):
		_pin(_w2m(pin), 18.0, Color(1, 0.82, 0.23))
	# Cycle 22: the golden meowth's treasure marker
	# (sx.marker; the bundle's big map plots Treasure
	# units in its special-marker pass).
	if world.has_method("event_marker_pos"):
		var tp = world.event_marker_pos()
		if tp != null:
			var tm2 := _w2m(tp)
			_mark(TEX_CHEST, tm2, 15.0)
			draw_arc(tm2, 9.5, 0, TAU, 24, Color.WHITE, 2.0)
	# 将玩家航标压在最顶层绘制并配底光晕，防止被中心Boss/祭坛完全掩盖
	var pl: Node = world.get("player")
	if pl != null and is_instance_valid(pl):
		var pl2 := _w2m(pl.global_position)
		draw_circle(pl2 - Vector2(0, 6), 11.0, Color(1.0, 0.92, 0.45, 0.28))
		_pin(pl2, 21.0)
