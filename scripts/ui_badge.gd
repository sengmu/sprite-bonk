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
func _ready() -> void:
	var key: String = {"ball":"wallet", "bag":"bell", "sound":"gear", "shake":"vibrate", "spark":"sparkle", "coin":"wallet", "fire":"flame", "water":"droplet", "grass":"leaf", "attack":"sword", "defense":"shield", "hp":"heart", "drop":"droplet", "reroll":"again", "banish":"close", "skip":"check"}.get(icon, icon)
	_fallback = not ResourceLoader.exists("res://assets/ui/badges/badge_%s.png" % key)
	_texture = UiTheme.asset("badges", "badge_" + ("star_empty" if _fallback else key))
	if _fallback:
		var glyph := UiIcon.new(icon, UiTheme.TEXT, size.x * 0.5)
		glyph.position = size * 0.25
		add_child(glyph)
	queue_redraw()
func _draw() -> void:
	if _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
