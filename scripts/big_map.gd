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
			draw_circle(_w2m(bpl.global_position), 5, Color.WHITE)
			draw_arc(_w2m(bpl.global_position), 7.5, 0, TAU, 24, Color(0.11, 0.07, 0.21), 2.0)
		return
	var tex: Texture2D = world.get("terrain_baked")
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.08, 0.16))
	# fog: unvisited cells dark (objectives drawn AFTER fog,
	# so they stay visible like the bundle's map)
	var fog: PackedByteArray = world.get("_fog")
	if fog.size() == 48 * 48:
		var cw := size.x / 48.0
		var ch := size.y / 48.0
		for gy in range(48):
			for gx in range(48):
				if fog[gy * 48 + gx] == 0:
					draw_rect(Rect2(gx * cw, gy * ch, cw + 1.0, ch + 1.0),
						Color(0.05, 0.04, 0.10, 0.78))
	var ap = world.get("altar_pos")
	if ap != null:
		draw_circle(_w2m(ap), 6, Color(1, 0.85, 0.2))
		draw_arc(_w2m(ap), 9, 0, TAU, 24, Color.WHITE, 1.5)
	var pn = world.get("portal_node")
	if pn != null and is_instance_valid(pn):
		var pp := _w2m((pn as Node3D).global_position)
		draw_circle(pp, 6, Color(0.72, 0.4, 1))
		draw_arc(pp, 9, 0, TAU, 24, Color.WHITE, 1.5)
	for c in world.call("chests_positions"):
		draw_circle(_w2m(c), 3.5, Color(1, 0.8, 0.25))
	var g: Node = world.get("guardian")
	if g != null and is_instance_valid(g) and float(g.get("hp")) > 0.0:
		var gp := _w2m(g.global_position)
		draw_circle(gp, 7, Color(1, 0.42, 0.1))
		draw_arc(gp, 10, 0, TAU, 24, Color(1, 0.2, 0.3), 2.0)
	var pl: Node = world.get("player")
	if pl != null and is_instance_valid(pl):
		draw_circle(_w2m(pl.global_position), 5, Color.WHITE)
		draw_arc(_w2m(pl.global_position), 7.5, 0, TAU, 24,
			Color(0.11, 0.07, 0.21), 2.0)
	for pin in world.get("_map_pins"):
		var mp := _w2m(pin)
		draw_circle(mp, 6, Color(1, 0.82, 0.23))
		draw_arc(mp, 9.5, 0, TAU, 24, Color(1, 0.82, 0.23), 2.0)
		draw_line(mp + Vector2(0, 2), mp + Vector2(0, 12),
			Color(1, 0.82, 0.23), 2.0)
	# Cycle 22: the golden meowth's treasure marker
	# (sx.marker; the bundle's big map plots Treasure
	# units in its special-marker pass).
	if world.has_method("event_marker_pos"):
		var tp = world.event_marker_pos()
		if tp != null:
			var tm2 := _w2m(tp)
			draw_circle(tm2, 6, Color(1, 0.78, 0.23))
			draw_arc(tm2, 9.5, 0, TAU, 24, Color.WHITE, 2.0)
