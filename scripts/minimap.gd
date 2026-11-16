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

## Icon order 2: map markers wear the shipped art
## (assets/ui/badges/map_*.png, event_dot_*.png). Positions and
## the fog-blind rule are unchanged — only the marks' faces.
const TEX_ARROW := preload("res://assets/ui/badges/map_player_arrow.png")
const TEX_STAR := preload("res://assets/ui/badges/map_star.png")
const TEX_CHEST := preload("res://assets/ui/badges/map_chest.png")
const TEX_DOT_RED := preload("res://assets/ui/badges/map_dot_red.png")
const TEX_DOT_ORANGE := preload("res://assets/ui/badges/map_dot_orange.png")
const TEX_DOT_GREEN := preload("res://assets/ui/badges/map_dot_green.png")
const TEX_DOT_PURPLE := preload("res://assets/ui/badges/map_dot_purple.png")
const TEX_DOT_YELLOW := preload("res://assets/ui/badges/map_dot_yellow.png")
const TEX_EVENT_RED := preload("res://assets/ui/badges/event_dot_red.png")

func _mark(tex: Texture2D, at: Vector2, sz: float) -> void:
	draw_texture_rect(tex, Rect2(at - Vector2.ONE * sz * 0.5, Vector2.ONE * sz), false)

func _player_mark(at: Vector2) -> void:
	var pl = world.get("player")
	var rot := 0.0
	if pl and is_instance_valid(pl):
		var fwd: Vector3 = -(pl as Node3D).global_transform.basis.z
		rot = atan2(fwd.x, -fwd.z)
	draw_set_transform(at, rot, Vector2.ONE)
	draw_texture_rect(TEX_ARROW, Rect2(Vector2.ONE * -8.0, Vector2.ONE * 16.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

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
		draw_circle(center, radius, Color(0.16, 0.13, 0.26, 0.92))
	# 对齐定稿 U1_final.jpg 暖金灰立体双圆外框
	draw_arc(center, radius + 1.5, 0, TAU, 64, Color(0.24, 0.28, 0.24, 0.50), 2.0, true)
	draw_arc(center, radius - 0.5, 0, TAU, 64, Color(0.87, 0.86, 0.78, 0.96), 6.5, true)
	draw_arc(center, radius - 4.0, PI * 1.10, PI * 1.72, 32, Color(1, 1, 1, 0.65), 2.0, true)
	if world == null:
		return
	# Cycle 22: fog blinding (sx.blind, bundle minimap
	# draw @2031938) — the disc fills with fog and ONLY
	# the player dot remains; every marker is hidden.
	if world.has_method("event_blind") and bool(world.event_blind()):
		draw_circle(center, radius + 3.0, Color(0.275, 0.235, 0.392, 0.85))
		var bpl = world.get("player")
		if bpl and is_instance_valid(bpl):
			_player_mark(_w2m_abs(bpl.global_position))
		# U1 1:1 round 4: no cardinal letters — the reference
		# minimap (U1_final.jpg) is a clean disc.
		return
	# Objective markers (absolute positions, clamped into the disc).
	var altar: Vector3 = world.get("altar_pos")
	var am := _w2m_abs(altar)
	if (am - center).length() < radius - 4.0:
		_mark(TEX_STAR, am, 15.0)
	var portal = world.get("portal_node")
	if portal and is_instance_valid(portal):
		var pm := _w2m_abs(portal.global_position)
		if (pm - center).length() < radius - 4.0:
			_mark(TEX_DOT_PURPLE, pm, 12.0)
	# Enemies (absolute; skip any that fall outside the disc).
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var em := _w2m_abs(e.global_position)
		if (em - center).length() > radius - 3.0:
			continue
		if e.get("is_guardian"):
			_mark(TEX_DOT_ORANGE, em, 12.0)
		else:
			_mark(TEX_DOT_RED, em, 8.0)
	# Guardian chests (cycle 9): the original marks unopened
	# Poké Ball chests on the minimap (onBossKilled toast @1461354).
	if world.has_method("chests_positions"):
		for cp in world.chests_positions():
			var cm := _w2m_abs(cp)
			if (cm - center).length() > radius - 3.0:
				continue
			_mark(TEX_CHEST, cm, 13.0)
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
		_mark(TEX_DOT_GREEN, am2, 11.0)
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
				_mark(TEX_DOT_YELLOW, pm2, 8.0)
	# Cycle 22: the golden meowth's treasure marker
	# (sx.marker; bundle minimap @2034218 draws Treasure
	# units in the special-marker pass).
	if world.has_method("event_marker_pos"):
		var mp = world.event_marker_pos()
		if mp != null:
			var mm := _w2m_abs(mp)
			if (mm - center).length() < radius - 3.0:
				_mark(TEX_EVENT_RED, mm, 12.0)
				draw_arc(mm, 7.0, 0.0, TAU, 24, Color.WHITE, 1.5)
	# Player mark (absolute — moves within the zone map).
	var player = world.get("player")
	if player and is_instance_valid(player):
		_player_mark(_w2m_abs(player.global_position))
	# U1 1:1 round 4: no cardinal letters (see blind path above).
