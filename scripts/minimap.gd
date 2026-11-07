class_name Minimap
extends Control
## Circular minimap in the original's style. Cycle 5: the disc is a
## baked render of the actual terrain (world._bake_minimap, absolute
## zone map like the original's), with dynamic markers on top: gold
## altar, purple portal, red enemy dots, white player dot. Falls back
## to the old schematic disc if no bake is available.

var world: Node = null  # the World node (scripts/world.gd)
var world_range := 170.0
var baked: Texture2D = null

func _ready() -> void:
	custom_minimum_size = Vector2(168, 168)
	size = custom_minimum_size
	# Cycle 18: clickable -> the big map (the bundle binds
	# minimap.onclick -> run.openMap(), @2001850 region).
	mouse_filter = MOUSE_FILTER_STOP
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			if world != null and world.has_method("open_big_map"):
				world.open_big_map())

func _process(_delta: float) -> void:
	queue_redraw()

## Absolute world position -> map pixel (map covers +/-world_range).
func _w2m_abs(p: Vector3) -> Vector2:
	return Vector2(
		(p.x / world_range * 0.5 + 0.5) * size.x,
		(p.z / world_range * 0.5 + 0.5) * size.y)

func _draw() -> void:
	var center := size * 0.5
	var radius := size.x * 0.5 - 3.0
	if baked:
		draw_texture_rect(baked, Rect2(Vector2.ZERO, size), false)
	else:
		draw_circle(center, radius + 3.0, Color(0.85, 0.25, 0.3))
		draw_circle(center, radius, Color(0.16, 0.13, 0.26, 0.92))
	if world == null:
		return
	# Cycle 22: fog blinding (sx.blind, bundle minimap
	# draw @2031938) — the disc fills with fog and ONLY
	# the player dot remains; every marker is hidden.
	if world.has_method("event_blind") and bool(world.event_blind()):
		draw_circle(center, radius + 3.0, Color(0.275, 0.235, 0.392, 0.85))
		var bpl = world.get("player")
		if bpl and is_instance_valid(bpl):
			draw_circle(_w2m_abs(bpl.global_position), 5.0, Color.WHITE)
		var bfont := get_theme_default_font()
		draw_string(bfont, center + Vector2(-4, -radius + 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.6, 0.6))
		draw_string(bfont, center + Vector2(-4, radius - 4), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.9))
		draw_string(bfont, center + Vector2(-radius + 5, 4), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.9))
		draw_string(bfont, center + Vector2(radius - 14, 4), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.9))
		return
	# Objective markers (absolute positions, clamped into the disc).
	var altar: Vector3 = world.get("altar_pos")
	var am := _w2m_abs(altar)
	if (am - center).length() < radius - 4.0:
		draw_circle(am, 6.0, Color(1.0, 0.8, 0.25))
		draw_circle(am, 6.0, Color(1, 1, 1, 0.0))
	var portal = world.get("portal_node")
	if portal and is_instance_valid(portal):
		var pm := _w2m_abs(portal.global_position)
		if (pm - center).length() < radius - 4.0:
			draw_circle(pm, 6.0, Color(0.75, 0.45, 1.0))
	# Enemies (absolute; skip any that fall outside the disc).
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var em := _w2m_abs(e.global_position)
		if (em - center).length() > radius - 3.0:
			continue
		var col := Color(0.95, 0.35, 0.3) if not e.get("is_guardian") else Color(1.0, 0.55, 0.2)
		draw_circle(em, 4.0 if not e.get("is_guardian") else 6.0, col)
	# Guardian chests (cycle 9): the original marks unopened
	# Poké Ball chests on the minimap (onBossKilled toast @1461354).
	if world.has_method("chests_positions"):
		for cp in world.chests_positions():
			var cm := _w2m_abs(cp)
			if (cm - center).length() > radius - 3.0:
				continue
			draw_circle(cm, 3.5, Color(1.0, 0.8, 0.25))
	# Allies (cycles 8-9): the original plots allies as green dots —
	# fillStyle #7aff9a, strokeStyle #1d1236, lineWidth 2, arc
	# radius 6*g (bundle minimap draw @2038659; cycle 8 had the
	# fill but a 4px radius and no stroke — audit §4).
	for a in get_tree().get_nodes_in_group("allies"):
		if not is_instance_valid(a):
			continue
		var am2 := _w2m_abs(a.global_position)
		if (am2 - center).length() > radius - 3.0:
			continue
		draw_circle(am2, 6.0, Color("7aff9a"))
		draw_arc(am2, 6.0, 0.0, TAU, 32, Color("1d1236"), 2.0)
	# Cycle 18: the shiny encounter (cyan capture ring, the
	# gR ring color for capturables) and the player's pins
	# (gold #ffd23a, shared with the big map).
	var se = world.get("_shiny_e")
	if se != null and is_instance_valid(se):
		var sm := _w2m_abs(se.global_position)
		if (sm - center).length() < radius - 3.0:
			draw_arc(sm, 7.0, 0.0, TAU, 24, Color(0.35, 0.94, 1.0), 2.0)
	if world.get("_map_pins") != null:
		for pin in world.get("_map_pins"):
			var pm2 := _w2m_abs(pin)
			if (pm2 - center).length() < radius - 3.0:
				draw_circle(pm2, 3.5, Color(1, 0.82, 0.23))
	# Cycle 22: the golden meowth's treasure marker
	# (sx.marker; bundle minimap @2034218 draws Treasure
	# units in the special-marker pass).
	if world.has_method("event_marker_pos"):
		var mp = world.event_marker_pos()
		if mp != null:
			var mm := _w2m_abs(mp)
			if (mm - center).length() < radius - 3.0:
				draw_circle(mm, 5.0, Color(1, 0.78, 0.23))
				draw_arc(mm, 7.0, 0.0, TAU, 24, Color.WHITE, 1.5)
	# Player dot (absolute — moves within the zone map).
	var player = world.get("player")
	if player and is_instance_valid(player):
		var pp := _w2m_abs(player.global_position)
		draw_circle(pp, 5.0, Color.WHITE)
		draw_circle(pp, 5.0, Color(0.2, 0.5, 1.0, 0.0))
	# Cardinal letters.
	var font := get_theme_default_font()
	draw_string(font, center + Vector2(-4, -radius + 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.6, 0.6))
	draw_string(font, center + Vector2(-4, radius - 4), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.9))
	draw_string(font, center + Vector2(-radius + 5, 4), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.9))
	draw_string(font, center + Vector2(radius - 14, 4), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.8, 0.8, 0.9))
