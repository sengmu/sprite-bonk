class_name UiIcon
extends Control

## Cycle 17 — the icon set (UI_SPEC §1.1: the original draws
## its UI icons from an SVG system at fixed px tiers). Ours are
## bold vector glyphs drawn per icon name in a 24x24 logical
## space, single-accent color, sized by the control rect. They
## stand in for the original's icon art until the reskin pass
## ships real assets — shapes are generic (sword, heart,
## shield, star), never traced from the original's files.

## U1 (2026-11-11): the coin/ball SVG textures MUST be resolved
## before the first _draw — a load() issued inside _draw() lands
## after the renderer built the frame's draw list, so the first
## paint is the default white texture, and a Control never
## redraws on its own: the white square was permanent (repro:
## Test/out/u1_icon_render.png white vs u1_icon_render2.png
## gold once preloaded). Textures are therefore resolved when
## the icon is assigned (setter / _init) and cached
## process-wide; _draw only draws.
static var _svg_cache: Dictionary = {}

var icon := "":
	set(v):
		icon = v
		_refresh_tex()
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var _tex: Texture2D = null

func _svg_path() -> String:
	if icon == "coin":
		return "res://assets/ui-v2/icons/coin.svg"
	if icon == "ball":
		return "res://assets/ui-v2/icons/wooden-chest.svg"
	return ""

func _refresh_tex() -> void:
	_tex = null
	var path := _svg_path()
	if path == "":
		return
	if not _svg_cache.has(path):
		_svg_cache[path] = load(path) as Texture2D
	_tex = _svg_cache[path] as Texture2D

func _init(p_icon: String = "", p_color: Color = Color.WHITE, px: float = 24.0) -> void:
	icon = p_icon
	color = p_color
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_tex()

## Point in 24-space -> draw space.
func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y) / 24.0
	return Vector2(size.x * 0.5 + (x - 12.0) * s, size.y * 0.5 + (y - 12.0) * s)

func _u(v: float) -> float:
	return v * minf(size.x, size.y) / 24.0

func _line(pts: Array, w: float = 2.2, closed: bool = false) -> void:
	var pp := PackedVector2Array()
	for v in pts:
		pp.append(_p(v.x, v.y))
	if closed and pp.size() > 2:
		pp.append(pp[0])
	if pp.size() >= 2:
		draw_polyline(pp, color, _u(w), true)

func _poly(pts: Array, c: Color) -> void:
	var pp := PackedVector2Array()
	for v in pts:
		pp.append(_p(v.x, v.y))
	draw_colored_polygon(pp, c)

func _circ(x: float, y: float, r: float, c: Color = Color(0, 0, 0, 0)) -> void:
	draw_circle(_p(x, y), _u(r), color if c.a == 0.0 else c)

func _ring(x: float, y: float, r: float, w: float = 2.2) -> void:
	draw_arc(_p(x, y), _u(r), 0.0, TAU, 32, color, _u(w), true)

func _arc(x: float, y: float, r: float, a0: float, a1: float, w: float = 2.2) -> void:
	draw_arc(_p(x, y), _u(r), a0, a1, 24, color, _u(w), true)

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	if icon in ["coin", "ball"]:
		if _tex == null:
			# Late-assignment safety net: the setter / _init
			# normally preloads _tex, so this only heals a
			# load that failed the first time — and the queued
			# redraw paints it on the next frame instead of
			# leaving the first white paint permanent.
			_refresh_tex()
			if _tex != null:
				queue_redraw()
		if _tex != null:
			var side := minf(size.x, size.y)
			draw_texture_rect(_tex, Rect2((size - Vector2.ONE * side) * 0.5, Vector2.ONE * side), false)
			return
	match icon:
		"sword":
			_poly([Vector2(6, 18), Vector2(15.5, 8.5), Vector2(19, 5), Vector2(18.5, 10.5), Vector2(9, 20)], color)
			_line([Vector2(5, 15), Vector2(9, 19)], 2.6)
			_circ(4.2, 19.8, 1.7)
		"brand_leaf":
			_poly([Vector2(3, 22), Vector2(3, 13), Vector2(6, 7), Vector2(13, 3),
				Vector2(23, 1), Vector2(21, 12), Vector2(17, 19), Vector2(10, 22)], color)
			_poly([Vector2(6, 19), Vector2(6, 13), Vector2(9, 8), Vector2(15, 5),
				Vector2(20, 4), Vector2(18, 12), Vector2(14, 17)], Color("8eaf35"))
			draw_line(_p(6, 19), _p(18, 6), Color("b9cc66"), _u(1.3), true)
		"phone_shake":
			_poly([Vector2(9, 3), Vector2(19, 6), Vector2(15, 22), Vector2(5, 19)], Color("e9efcc"))
			_line([Vector2(9, 3), Vector2(19, 6), Vector2(15, 22), Vector2(5, 19)], 2.3, true)
			_circ(10.8, 18.2, 0.7)
			_line([Vector2(4, 5), Vector2(2, 8), Vector2(2, 11)], 1.5)
			_line([Vector2(21, 10), Vector2(22, 13), Vector2(21, 16)], 1.5)
		"magnet":
			# Icon order 1 (2026-11-12): horseshoe magnet so the
			# lab magnet node stops falling back to the plain
			# ring. Arc over the top, two pole blocks hanging
			# from its ends.
			_arc(12, 11.4, 6.2, 3.49, 5.93, 3.4)
			_poly([Vector2(4.4, 9.6), Vector2(7.0, 9.6), Vector2(7.0, 15.4), Vector2(4.4, 15.4)], color)
			_poly([Vector2(17.0, 9.6), Vector2(19.6, 9.6), Vector2(19.6, 15.4), Vector2(17.0, 15.4)], color)
		"wind":
			# U1 1:1 round 10: a bold "3" swirl with two speed
			# lines (reference U1_final.jpg dash glyph) — the
			# round-8 three straight lines read as a menu icon,
			# not a swirl (main-controller ruling, local crops
			# compared). Two C-bowls opening left, pinched at
			# the middle; speed lines to their left.
			_arc(15, 8, 5, -2.0, 2.0, 3.2)
			_arc(15, 16, 5, -2.0, 2.0, 3.2)
			_line([Vector2(3, 10), Vector2(9.5, 10)], 2.6)
			_line([Vector2(3, 14.5), Vector2(9.5, 14.5)], 2.6)
		"heart":
			_circ(8.3, 9.2, 3.6)
			_circ(15.7, 9.2, 3.6)
			_poly([Vector2(5.2, 11.4), Vector2(18.8, 11.4), Vector2(12, 20.6)], color)
		"result_home":
			# Wide two-tone house with an open doorway (P5 result only).
			_poly([Vector2(2, 11.595), Vector2(12, 4.305), Vector2(22, 11.595), Vector2(20, 12.810), Vector2(12, 7.140), Vector2(4, 12.810)], Color("69421b"))
			_poly([Vector2(4.5, 11.595), Vector2(12, 6.735), Vector2(19.5, 11.595), Vector2(19.5, 18.885), Vector2(14, 18.885), Vector2(14, 13.620), Vector2(10, 13.620), Vector2(10, 18.885), Vector2(4.5, 18.885)], Color("98652e"))
		"result_spark":
			_poly([Vector2(12, 3), Vector2(15, 9), Vector2(21, 12), Vector2(15, 15), Vector2(12, 21), Vector2(9, 15), Vector2(3, 12), Vector2(9, 9)], color)
			_poly([Vector2(12, 3), Vector2(12, 12), Vector2(3, 12), Vector2(9, 9)], color.lightened(0.35))
		"result_coins":
			# Overlapping gold coins, without the row tile's square plate.
			for cx in [15.0, 9.0]:
				draw_set_transform(_p(cx, 12), 0, Vector2(0.78, 1))
				draw_circle(Vector2.ZERO, _u(8), Color("b9790d"))
				draw_circle(Vector2.ZERO, _u(6.5), Color("ffcf32"))
				draw_arc(Vector2.ZERO, _u(5), 0, TAU, 32, Color("fff09a"), _u(1.2), true)
				draw_line(Vector2(0, -_u(2.8)), Vector2(0, _u(2.8)), Color("d49210"), _u(1.5), true)
				draw_set_transform(Vector2.ZERO)
		"home":
			# U5: house glyph for the result screen's 返回菜单 button.
			_poly([Vector2(2.5, 12.5), Vector2(12, 3.5), Vector2(21.5, 12.5)], color)
			_poly([Vector2(5, 11.5), Vector2(19, 11.5), Vector2(19, 21), Vector2(5, 21)], color)
		"speed":
			# Two chevron strokes as polylines — the filled
			# chevron polygons self-intersected and failed
			# triangulation (canvas_item_add_polygon errors,
			# cycle 17).
			_line([Vector2(5, 5), Vector2(12, 12), Vector2(5, 19)], 2.6)
			_line([Vector2(13, 5), Vector2(20, 12), Vector2(13, 19)], 2.6)
		"crit":
			_ring(12, 12, 6.4)
			_circ(12, 12, 1.6)
			_line([Vector2(12, 2.4), Vector2(12, 6.4)])
			_line([Vector2(12, 17.6), Vector2(12, 21.6)])
			_line([Vector2(2.4, 12), Vector2(6.4, 12)])
			_line([Vector2(17.6, 12), Vector2(21.6, 12)])
		"area":
			_circ(12, 12, 1.8)
			_ring(12, 12, 5.2, 1.9)
			_ring(12, 12, 8.8, 1.9)
		"up":
			_poly([Vector2(12, 3.4), Vector2(19.4, 12.4), Vector2(15.2, 12.4), Vector2(15.2, 20.6), Vector2(8.8, 20.6), Vector2(8.8, 12.4), Vector2(4.6, 12.4)], color)
		"plus":
			_line([Vector2(12, 5), Vector2(12, 19)], 4.4)
			_line([Vector2(5, 12), Vector2(19, 12)], 4.4)
		"shield":
			_poly([Vector2(12, 2.8), Vector2(19.4, 5.2), Vector2(19.4, 11), Vector2(12, 21.4), Vector2(4.6, 11), Vector2(4.6, 5.2)], color)
		"luck":
			_circ(12, 7.6, 3.4)
			_circ(8.2, 12.8, 3.4)
			_circ(15.8, 12.8, 3.4)
			_circ(12, 15.4, 3.2)
			_line([Vector2(12, 16), Vector2(10.5, 21.5)], 2.0)
		"hourglass":
			_poly([Vector2(6, 3.4), Vector2(18, 3.4), Vector2(13.8, 10.6), Vector2(18, 17.8), Vector2(18, 20.6), Vector2(6, 20.6), Vector2(6, 17.8), Vector2(10.2, 10.6)], color)
		"spark":
			_poly([Vector2(12, 2.2), Vector2(14.6, 9.4), Vector2(21.8, 12), Vector2(14.6, 14.6), Vector2(12, 21.8), Vector2(9.4, 14.6), Vector2(2.2, 12), Vector2(9.4, 9.4)], color)
		"coin":
			_ring(12, 12, 8.6, 2.4)
			_ring(12, 12, 4.4, 1.7)
		"ball":
			_ring(12, 12, 8.8, 2.3)
			_line([Vector2(3.4, 12), Vector2(9.2, 12)], 2.3)
			_line([Vector2(14.8, 12), Vector2(20.6, 12)], 2.3)
			_ring(12, 12, 2.9, 2.0)
			_circ(12, 12, 1.1)
		"skull":
			_circ(12, 10.4, 7.4)
			_poly([Vector2(8.2, 15.5), Vector2(15.8, 15.5), Vector2(15.8, 20), Vector2(8.2, 20)], color)
			var cutout: Color = get_meta("cutout_color", Color(0.1, 0.07, 0.2, 1))
			_circ(9.2, 10.8, 1.9, cutout)
			_circ(14.8, 10.8, 1.9, cutout)
		"reroll":
			_arc(12, 12, 7.6, -PI * 0.35, PI * 1.15)
			_poly([Vector2(18.9, 5.6), Vector2(20.9, 11.4), Vector2(15.2, 10.6)], color)
			_arc(12, 12, 7.6, PI * 0.65, PI * 2.15)
			_poly([Vector2(5.1, 18.4), Vector2(3.1, 12.6), Vector2(8.8, 13.4)], color)
		"result_refresh":
			# P5 result only: two disjoint 136-degree clockwise arcs,
			# each ending in a tangent-facing filled arrowhead. The
			# shared reroll arcs overlap into a ring; leave them intact.
			_arc(12, 12, 8.4, -PI * 0.82, -PI * 0.06, 2.8)
			_poly([Vector2(22.0, 14.2), Vector2(15.7, 10.4), Vector2(21.5, 6.9)], color)
			_arc(12, 12, 8.4, PI * 0.18, PI * 0.94, 2.8)
			_poly([Vector2(2.0, 9.8), Vector2(8.3, 13.6), Vector2(2.5, 17.1)], color)
		"skip":
			_poly([Vector2(4.6, 5.6), Vector2(11.6, 12), Vector2(4.6, 18.4)], color)
			_poly([Vector2(11.4, 5.6), Vector2(18.4, 12), Vector2(11.4, 18.4)], color)
			_line([Vector2(19.8, 5.6), Vector2(19.8, 18.4)], 2.4)
		"banish":
			_ring(12, 12, 8.6, 2.4)
			_line([Vector2(6.4, 6.4), Vector2(17.6, 17.6)], 2.6)
		"close":
			_line([Vector2(6, 6), Vector2(18, 18)], 2.8)
			_line([Vector2(18, 6), Vector2(6, 18)], 2.8)
		"check":
			_line([Vector2(4.4, 12.8), Vector2(9.8, 18.2), Vector2(19.6, 5.8)], 3.0)
		"flask":
			_poly([Vector2(10, 3.4), Vector2(14, 3.4), Vector2(14, 8.6), Vector2(18.6, 18.4), Vector2(18.6, 20.6), Vector2(5.4, 20.6), Vector2(5.4, 18.4), Vector2(10, 8.6)], color)
			_line([Vector2(8.4, 15.4), Vector2(15.6, 15.4)], 1.8)
		"bag":
			# Cycle 19: redrawn as a drawstring pouch — the
			# old trapezoid + top arc read as a padlock at
			# 20 px (audit §2.3), the "locked" signifier on
			# a shop card. A tied sack: neck band, two ties
			# converging to the knot, bulging body.
			_poly([Vector2(8.4, 9.8), Vector2(15.6, 9.8), Vector2(18.8, 14.8), Vector2(17.2, 20.4), Vector2(6.8, 20.4), Vector2(5.2, 14.8)], color)
			_line([Vector2(9.6, 9.6), Vector2(11.5, 4.9)], 2.2)
			_line([Vector2(14.4, 9.6), Vector2(12.5, 4.9)], 2.2)
			_line([Vector2(8.2, 9.8), Vector2(15.8, 9.8)], 2.6)
		"shake":
			# Cycle 19: screen-shake glyph (the menu's 画面震动
			# item used "wind", an indistinct blob — audit
			# §2.3): a frame with vibration ticks both sides.
			_line([Vector2(8.8, 6.6), Vector2(15.2, 6.6), Vector2(15.2, 17.4), Vector2(8.8, 17.4), Vector2(8.8, 6.6)], 2.2)
			_line([Vector2(4.4, 9.2), Vector2(4.4, 14.8)], 2.2)
			_line([Vector2(19.6, 9.2), Vector2(19.6, 14.8)], 2.2)
			_line([Vector2(1.8, 10.6), Vector2(1.8, 13.4)], 1.8)
			_line([Vector2(22.2, 10.6), Vector2(22.2, 13.4)], 1.8)
		"blessing":
			# Cycle 19: the bundle's generic blessing glyph
			# (Z('blessing', 64) @2064760) — a radiant amulet
			# star; blessing cards now draw this, not a
			# per-stat icon (audit punch #14).
			_poly([Vector2(12, 2.6), Vector2(14.3, 9.7), Vector2(21.4, 12), Vector2(14.3, 14.3), Vector2(12, 21.4), Vector2(9.7, 14.3), Vector2(2.6, 12), Vector2(9.7, 9.7)], color)
			_circ(12, 12, 2.0, Color(0.07, 0.05, 0.13, 1))
		"lock":
			_poly([Vector2(5.4, 10.6), Vector2(18.6, 10.6), Vector2(18.6, 20.6), Vector2(5.4, 20.6)], color)
			_arc(12, 10.4, 4.6, PI, TAU, 2.4)
			_circ(12, 15.4, 1.7, Color(0.07, 0.05, 0.13, 1))
		"sound":
			_poly([Vector2(4, 9.6), Vector2(8.6, 9.6), Vector2(14.6, 4.8), Vector2(14.6, 19.2), Vector2(8.6, 14.4), Vector2(4, 14.4)], color)
			_arc(15.5, 12, 3.6, -PI * 0.35, PI * 0.35, 2.0)
			_arc(15.5, 12, 6.4, -PI * 0.35, PI * 0.35, 2.0)
		"trophy":
			_poly([Vector2(6.4, 3.6), Vector2(17.6, 3.6), Vector2(17.6, 9.4), Vector2(14.8, 13.4), Vector2(13.4, 13.4), Vector2(13.4, 17.4), Vector2(16.6, 17.4), Vector2(16.6, 20.4), Vector2(7.4, 20.4), Vector2(7.4, 17.4), Vector2(10.6, 17.4), Vector2(10.6, 13.4), Vector2(9.2, 13.4), Vector2(6.4, 9.4)], color)
			_arc(6.2, 7.6, 2.9, PI * 0.4, PI * 1.5, 1.9)
			_arc(17.8, 7.6, 2.9, -PI * 0.5, PI * 0.6, 1.9)
		"sun":
			_circ(12, 12, 4.6)
			for k in range(8):
				var a := TAU * float(k) / 8.0
				_line([Vector2(12 + cos(a) * 6.8, 12 + sin(a) * 6.8), Vector2(12 + cos(a) * 9.6, 12 + sin(a) * 9.6)], 2.0)
		"rain":
			_circ(9, 9.5, 3.8)
			_circ(14.5, 8.6, 4.6)
			_line([Vector2(5.6, 13.4), Vector2(18.6, 13.4)], 2.6)
			_line([Vector2(8, 16.4), Vector2(7, 19.6)], 1.9)
			_line([Vector2(12.4, 16.4), Vector2(11.4, 19.6)], 1.9)
			_line([Vector2(16.8, 16.4), Vector2(15.8, 19.6)], 1.9)
		"snow":
			for k in range(3):
				var a := PI * float(k) / 3.0
				_line([Vector2(12 - cos(a) * 8.4, 12 - sin(a) * 8.4), Vector2(12 + cos(a) * 8.4, 12 + sin(a) * 8.4)], 1.9)
			_circ(12, 12, 1.7)
		"fog":
			_line([Vector2(4.6, 8.6), Vector2(19.4, 8.6)], 2.4)
			_line([Vector2(6.8, 12.6), Vector2(21, 12.6)], 2.4)
			_line([Vector2(3.4, 16.6), Vector2(17.2, 16.6)], 2.4)
		"flame":
			_poly([Vector2(12, 2.6), Vector2(15.6, 8), Vector2(17.6, 12.2), Vector2(16.4, 17.4), Vector2(12, 21.2), Vector2(7.6, 17.4), Vector2(6.4, 12.2), Vector2(8.4, 8), Vector2(10, 10.4), Vector2(10.4, 6.2)], color)
		"drop":
			_poly([Vector2(12, 2.8), Vector2(17.8, 12.4), Vector2(17.2, 17), Vector2(12, 21.2), Vector2(6.8, 17), Vector2(6.2, 12.4)], color)
			_circ(12, 14.6, 5.6)
		"leaf":
			_poly([Vector2(12, 2.8), Vector2(19.4, 6.4), Vector2(19, 14.8), Vector2(14.6, 19.6), Vector2(6.6, 18.4), Vector2(4.8, 10.4)], color)
			_line([Vector2(7.4, 16.6), Vector2(16.4, 7.6)], 1.7)
		"bolt":
			_poly([Vector2(13.4, 2.4), Vector2(5.8, 13.6), Vector2(10.6, 13.6), Vector2(9.2, 21.6), Vector2(18.2, 9.8), Vector2(13.2, 9.8)], color)
		"candy":
			_circ(12, 12, 4.9)
			_poly([Vector2(7.6, 9.6), Vector2(2.6, 6.4), Vector2(3.6, 12), Vector2(2.6, 17.6), Vector2(7.6, 14.4)], color)
			_poly([Vector2(16.4, 9.6), Vector2(21.4, 6.4), Vector2(20.4, 12), Vector2(21.4, 17.6), Vector2(16.4, 14.4)], color)
		"chest":
			_poly([Vector2(4.6, 9.4), Vector2(19.4, 9.4), Vector2(19.4, 20.4), Vector2(4.6, 20.4)], color)
			_arc(12, 9.6, 7.4, PI, TAU, 2.4)
			_poly([Vector2(10.4, 12), Vector2(13.6, 12), Vector2(13.6, 16.4), Vector2(10.4, 16.4)], Color(0.1, 0.07, 0.2, 1))
		"egg":
			_poly([Vector2(12, 3), Vector2(16.4, 8.4), Vector2(17.4, 14.4), Vector2(12, 21), Vector2(6.6, 14.4), Vector2(7.6, 8.4)], color)
			_circ(12, 12.6, 5.4)
		"play":
			_poly([Vector2(7.4, 4.4), Vector2(19.4, 12), Vector2(7.4, 19.6)], color)
		"pause":
			_line([Vector2(8.6, 5), Vector2(8.6, 19)], 3.6)
			_line([Vector2(15.4, 5), Vector2(15.4, 19)], 3.6)
		"target":
			_ring(12, 12, 8.4, 2.1)
			_ring(12, 12, 4.2, 1.9)
			_circ(12, 12, 1.3)
		"exclaim":
			# cycle 18: the touch interact button (the bundle's
			# tc-act is an exclamation mark in a circle)
			_poly([Vector2(10.2, 3.6), Vector2(13.8, 3.6), Vector2(13.4, 14.8), Vector2(10.6, 14.8)], color)
			_circ(12, 18.8, 1.9)
		"expand":
			# UI-mobile P2: the minimap's "⤢" tap badge — a
			# diagonal double arrow (corner heads + shaft).
			_line([Vector2(6, 18), Vector2(18, 6)], 2.4)
			_poly([Vector2(19.6, 4.4), Vector2(19.6, 12.2), Vector2(11.8, 4.4)], color)
			_poly([Vector2(4.4, 19.6), Vector2(4.4, 11.8), Vector2(12.2, 19.6)], color)
		"pin":
			# cycle 18: map pin (big-map side list / pins legend)
			_ring(12, 9.2, 5.6, 2.2)
			_circ(12, 9.2, 2.0)
			_poly([Vector2(7.6, 13.4), Vector2(16.4, 13.4), Vector2(12, 21.6)], color)
		_:
			_ring(12, 12, 8.4, 2.0)
			_circ(12, 12, 1.6)
