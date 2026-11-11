class_name UiMedallion
extends Control

## Cycle 17 — the HUD player medallion (UI_SPEC §2.3: tl-medal
## = tl-ring XP ring + tl-portrait + tl-lvl). Replaces the
## pre-cycle-17 disc with a single CJK glyph and the 78x7 XP
## sliver under it: the portrait is the species' baked disc
## (UiTheme.portrait), the XP progress is an arc swept around
## it, and the disc underlay keeps the starter's medal color.
## Without a baked portrait the world leaves its glyph label
## visible on top of the medal disc (fallback, same as the
## original's generated-badge path).

var portrait: Texture2D = null:
	set(v):
		portrait = v
		queue_redraw()
var medal := Color(0.4, 0.4, 0.45):
	set(v):
		medal = v
		queue_redraw()
var xp_frac := 0.0:
	set(v):
		if absf(v - xp_frac) > 0.001:
			xp_frac = v
			queue_redraw()

## UI-mobile P3 (plan I3): the portrait is tappable on
## phone (pause) — a white wash of this alpha while pressed.
var press_a := 0.0:
	set(v):
		press_a = v
		queue_redraw()

const XP_COLOR := UiTheme.GREEN_DEEP  # #7aff8a

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_xp(frac: float) -> void:
	xp_frac = clampf(frac, 0.0, 1.0)

func _draw() -> void:
	var centre := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	# Medal disc + ink rim.
	draw_circle(centre, r, medal)
	draw_arc(centre, r, 0.0, TAU, 48, Color(1, 1, 1, 0.85), 2.5, true)
	# Portrait disc (baked with transparent corners).
	# U1 1:1 round 14 (coordinator): inset 7 -> 3.5 so the
	# face fills the disc the way the reference's does, and
	# the XP track slims to a neutral rim (the reference rim
	# reads light; a 5 px ink track read as a thick dark
	# border). The green sweep still rides on top.
	if portrait != null:
		var d := r * 2.0 - 3.5
		draw_texture_rect(portrait, Rect2(centre - Vector2(d, d) * 0.5, Vector2(d, d)), false)
	# XP ring: neutral track + swept arc from the top.
	draw_arc(centre, r - 1.0, 0.0, TAU, 48, Color(0.45, 0.45, 0.55), 3.5, true)
	if xp_frac > 0.001:
		draw_arc(centre, r - 1.0, -PI / 2.0, -PI / 2.0 + TAU * xp_frac, 48, XP_COLOR, 3.5, true)
	if press_a > 0.001:
		draw_circle(centre, r, Color(1, 1, 1, press_a))
