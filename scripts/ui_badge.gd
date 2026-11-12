class_name UiBadge
extends Control
## Semantic production badge; unsupported moves retain their original glyph.
var tint := UiTheme.GREEN_DEEP
var icon := "flask"
var _texture: Texture2D
var _fallback := false
func _init(glyph: String = "flask", color: Color = UiTheme.GREEN_DEEP, diameter: float = 64.0) -> void:
	icon = glyph
	tint = color
	custom_minimum_size = Vector2.ONE * diameter
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
## Icon order 1 (2026-11-12): direct file overrides for semantics
## whose badge_<key>.png is missing, or whose old alias pointed at
## the WRONG art (coin->wallet, bag->bell, sound->gear,
## banish->close, skip->check — those five aliases are removed
## below). FULL = finished die-cut art drawn full-rect; GLYPH =
## white monochrome glyph drawn over a disc in the badge tint.
const FULL_FILES := {
	"tile_clock": "res://assets/ui/badges/tile_clock.png",
	"tile_sword": "res://assets/ui/badges/tile_sword_orange.png",
	"tile_star": "res://assets/ui/badges/tile_star.png",
	"tile_coin": "res://assets/ui/badges/tile_coin.png",
	"clock": "res://assets/ui/badges/tile_clock.png",
	"coin": "res://assets/ui/badges/tile_coin.png",
	"vit_protein": "res://assets/ui/items/vit_protein.png",
	"vit_calcium": "res://assets/ui/items/vit_calcium.png",
	"vit_iron": "res://assets/ui/items/vit_iron.png",
	"vit_carbos": "res://assets/ui/items/vit_carbos.png",
	"vit_hp_up": "res://assets/ui/items/vit_hp_up.png",
	"vit_ether": "res://assets/ui/items/vit_ether.png",
	"vit_dire_hit": "res://assets/ui/items/vit_dire_hit.png",
	"vit_exp_candy": "res://assets/ui/items/vit_exp_candy.png",
	"vit_nugget": "res://assets/ui/items/vit_nugget.png",
	"vit_super_potion": "res://assets/ui/items/vit_super_potion.png",
	"vit_star_piece": "res://assets/ui/items/vit_star_piece.png",
}
const GLYPH_FILES := {
	"bag": "res://assets/ui/glyphs/glyph_bag.png",
	"skip": "res://assets/ui/glyphs/glyph_skip.png",
	"banish": "res://assets/ui/glyphs/glyph_banish.png",
	"sound": "res://assets/ui/glyphs/glyph_sound.png",
	"bolt": "res://assets/ui/glyphs/glyph_bolt.png",
	"candy": "res://assets/ui/glyphs/glyph_candy.png",
	"wind": "res://assets/ui/glyphs/glyph_wind.png",
}
var _mode := 0  # 0 = badge file / fallback, 1 = FULL override, 2 = GLYPH override
var _fallback_glyph: UiIcon = null
func _ready() -> void:
	_resolve()
## Icon order 2: live icon swap (the weather chip changes icon
## with the weather). Re-runs the same resolution as _ready.
func set_icon(glyph: String) -> void:
	icon = glyph
	if _fallback_glyph != null:
		_fallback_glyph.queue_free()
		_fallback_glyph = null
	_resolve()
func _resolve() -> void:
	# Icon order 2: whole regular families live at
	# badges/<key>.png — the 18 type tiles, the 18 move tiles,
	# the 7 weather tiles, the 11 lab node patterns and the
	# status faces (status_*; no dedicated status-icon surface
	# exists in the UI yet — statuses read off the 3D bodies —
	# so these resolve here, ready for the first display site).
	for prefix in ["type_", "move_", "weather_", "lab_", "class_", "status_"]:
		if icon.begins_with(prefix):
			var p := "res://assets/ui/badges/%s.png" % icon
			if ResourceLoader.exists(p):
				_mode = 1
				_texture = load(p)
				queue_redraw()
				return
	if FULL_FILES.has(icon):
		_mode = 1
		_texture = load(FULL_FILES[icon])
		queue_redraw()
		return
	if GLYPH_FILES.has(icon):
		_mode = 2
		_texture = load(GLYPH_FILES[icon])
		queue_redraw()
		return
	var key: String = {"ball":"wallet", "shake":"vibrate", "spark":"sparkle", "fire":"flame", "water":"droplet", "grass":"leaf", "attack":"sword", "defense":"shield", "hp":"heart", "drop":"droplet", "reroll":"again"}.get(icon, icon)
	_fallback = not ResourceLoader.exists("res://assets/ui/badges/badge_%s.png" % key)
	_texture = UiTheme.asset("badges", "badge_" + ("star_empty" if _fallback else key))
	if _fallback:
		_fallback_glyph = UiIcon.new(icon, UiTheme.TEXT, size.x * 0.5)
		_fallback_glyph.position = size * 0.25
		add_child(_fallback_glyph)
	queue_redraw()
func _draw() -> void:
	if _texture == null:
		return
	if _mode == 2:
		draw_circle(size * 0.5, size.x * 0.5, tint)
		var gs := size * 0.62
		draw_texture_rect(_texture, Rect2((size - gs) * 0.5, gs), false)
		return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
