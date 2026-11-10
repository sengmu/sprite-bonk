class_name UiBadge
extends Control
## Code-native glossy badge; no generated lettering or external art.
var tint := UiTheme.GREEN_DEEP
var icon := "flask"

func _init(glyph: String = "flask", color: Color = UiTheme.GREEN_DEEP, diameter: float = 64.0) -> void:
	icon = {"clock": "hourglass", "star": "spark", "paw": "heart", "magnet": "area"}.get(glyph, glyph)
	tint = color
	custom_minimum_size = Vector2.ONE * diameter
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var glyph := UiIcon.new(icon, Color.WHITE, size.x * 0.5)
	glyph.position = size * 0.25
	add_child(glyph)

func _draw() -> void:
	var c := size * 0.5
	var r := minf(c.x, c.y) - 4.0
	draw_circle(c + Vector2(0, 4), r + 3, Color(0.34, 0.25, 0.13, 0.22))
	draw_circle(c, r + 3, UiTheme.CREAM)
	draw_circle(c, r, tint.darkened(0.2))
	draw_circle(c - Vector2(0, 2), r - 2, tint)
	draw_arc(c, r - 4, PI * 1.12, PI * 1.7, 24, Color(1, 1, 1, 0.65), 3, true)
	draw_circle(c + Vector2(-r * 0.48, -r * 0.5), r * 0.10, Color(1, 1, 1, 0.8))
