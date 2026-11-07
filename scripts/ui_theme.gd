class_name UiTheme
extends RefCounted

## Cycle 17 — the design-token layer (UI_SPEC §1). One home for
## the palette, the font stack, and the component factories every
## screen builds from, replacing the pre-cycle-17 state where
## colors were bare Color() literals per call site and every
## Button wore the engine's stock theme.
##
## Token provenance (UI_SPEC §1.2, bundle-verified): panel ink
## #1d1236 (glass alpha .78/.80/.82 — toast cssText @2134144
## proves rgba(29,18,54,.82)), light-face ink #2a2350, outline
## ink #1a1030 (damage-text stroke @187085), accent gold
## #ffd23a, muted #9aa0b4 / #6a6488, rarity legend "blue =
## common, green = rare, purple = epic, gold = legendary"
## (map legend @~2079000), the Yi type-color table (@3184), and
## the danger ramp WR (@1997817, thresholds UR alongside).
## Per-class padding/radius/shadow values were NOT captured
## (the original's main CSS is the named evidence gap, UI_SPEC
## §0/§4): geometry below is judged against the verified tokens,
## not claimed as original numbers.

# ---------------------------------------------------------------- tokens
const INK := Color8(29, 18, 54)          # #1d1236 panel ink
const INK_DEEP := Color8(26, 16, 48)     # #1a1030 outline ink
const INK_SOFT := Color8(42, 35, 80)     # #2a2350 ink on light faces
const GLASS_A := 0.82                    # verified glass alpha
const GOLD := Color8(255, 210, 58)       # #ffd23a
const YELLOW := Color8(255, 226, 58)      # #ffe23a
const GREEN := Color8(122, 255, 138)     # #7aff8a
const GREEN_DEEP := Color8(54, 201, 106) # #36c96a
const SKY := Color8(138, 232, 255)       # #8ae8ff
const PIN := Color8(255, 210, 58)        # #ffd23a map pin gold
const PINK := Color8(255, 90, 138)       # #ff5a8a
const PINK_SOFT := Color8(255, 154, 224) # #ff9ae0
const PURPLE := Color8(154, 106, 255)    # #9a6aff
const LILAC := Color8(200, 168, 255)     # #c8a8ff
const MUTED := Color8(154, 160, 180)     # #9aa0b4
const FAINT := Color8(106, 100, 136)     # #6a6488
const RED := Color8(255, 74, 74)         # #ff4a4a
const WHITE := Color(1, 1, 1)

## Rarity ramp (UI_SPEC §1.2): the map legend anchors blue =
## common, green = rare, purple = epic, gold = legendary against
## our five names [普通， 优秀， 稀有， 史诗， 传说] — indices
## 0/2/3/4 land on the legend grades; index 1 （优秀） is an
## interpolated teal, named as such in DIFF cycle 17.
const RARITY: Array[Color] = [
	Color8(84, 124, 214),   # r0 普通 royal blue (cycle 19: was
	# #3aa0ff — byte-identical to TYPE_COLORS.water, so a common
	# card and a water-move card read the same; the legend only
	# fixes "blue", the CSS hex is unrecoverable)
	Color8(57, 198, 216),   # r1 优秀 teal (interpolated)
	Color8(54, 201, 106),   # r2 稀有 green
	Color8(154, 106, 255),  # r3 史诗 purple
	Color8(255, 210, 58),   # r4 传说 gold
]

## Danger meter (bundle @1997817): thresholds UR, ramp WR, and
## the tier names GR — [Tranquilo, Moderado, Peligroso, Muy
## peligroso, Brutal, Letal, Imposible], localized.
const DANGER_THRESHOLDS: Array[float] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.5, 7.0]
const DANGER_COLORS: Array[Color] = [
	Color8(54, 201, 106), Color8(155, 210, 58), Color8(255, 194, 26),
	Color8(255, 138, 42), Color8(255, 74, 74), Color8(208, 32, 106),
	Color8(106, 26, 168),
]
const DANGER_NAMES: Array[String] = ["平静", "温和", "危险", "极危险", "残暴", "致命", "不可能"]

## Type colors: the bundle's Yi table (@3184), hex for hex.
const TYPE_COLORS := {
	"normal": Color8(200, 196, 168), "fighting": Color8(224, 82, 58),
	"flying": Color8(168, 196, 255), "poison": Color8(181, 96, 224),
	"ground": Color8(224, 184, 96), "rock": Color8(191, 166, 90),
	"bug": Color8(168, 200, 50), "ghost": Color8(122, 106, 216),
	"steel": Color8(184, 200, 216), "fire": Color8(255, 122, 42),
	"water": Color8(58, 160, 255), "grass": Color8(90, 210, 74),
	"electric": Color8(255, 216, 42), "psychic": Color8(255, 90, 160),
	"ice": Color8(142, 240, 255), "dragon": Color8(122, 90, 255),
	"dark": Color8(106, 80, 72), "fairy": Color8(255, 160, 224),
}

static func type_color(t: String) -> Color:
	return TYPE_COLORS.get(t, Color8(160, 160, 170)) as Color

static func rarity_color(i: int) -> Color:
	return RARITY[clampi(i, 0, RARITY.size() - 1)]

static func glass_color(alpha: float = GLASS_A) -> Color:
	return Color(INK.r, INK.g, INK.b, alpha)

# ---------------------------------------------------------------- fonts
## Display stack: Fredoka SemiBold (headings/numbers, OFL) ->
## Smiley Sans （得意黑， OFL — the CJK display face; M PLUS
## Rounded 1c was fetched but covers only ~2/3 of the game's
## CJK glyphs, see DIFF cycle 17) -> Noto Sans SC Black subset.
## Body stack: Nunito ExtraBold (OFL) -> Noto Sans SC Heavy
## (800) subset -> the standing Noto SC subset. Fallback order
## is per-glyph, so Latin always lands on the rounded faces
## and CJK on a heavy face — never on a light default.
static var _display_font: Font = null
static var _body_font: Font = null

static func _load_ttf(path: String) -> FontFile:
	# Via the resource pipeline, NOT load_dynamic_font: in an
	# exported build the raw .ttf path is not a readable file
	# (the resource lives in the PCK as .fontdata), so
	# load_dynamic_font fails with "Can't open file" and the
	# whole stack silently fell back — caught by the cycle-17
	# Linux-export boot smoke, invisible in editor runs where
	# res:// is a real directory. load() resolves the import
	# remap in both worlds.
	var f := load(path) as FontFile
	if f == null:
		push_warning("UiTheme: font failed to load: " + path)
	return f

static func load_fonts() -> void:
	if _display_font != null:
		return
	var fredoka := _load_ttf("res://assets/fonts/Fredoka-SemiBold.ttf")
	var smiley := _load_ttf("res://assets/fonts/SmileySans-sub.ttf")
	var noto_black := _load_ttf("res://assets/fonts/NotoSC-Black-sub.ttf")
	var nunito := _load_ttf("res://assets/fonts/Nunito-ExtraBold.ttf")
	var noto_heavy := _load_ttf("res://assets/fonts/NotoSC-Heavy-sub.ttf")
	var noto := _load_ttf("res://assets/NotoSC-subset.ttf")
	_display_font = _chain(fredoka, [smiley, noto_black, noto])
	_body_font = _chain(nunito, [noto_heavy, noto])
	if _display_font == null:
		_display_font = noto
	if _body_font == null:
		_body_font = noto

static func _chain(head: FontFile, rest: Array) -> Font:
	if head == null:
		for r in rest:
			if r != null:
				return r
		return null
	var fb: Array[Font] = []
	for r in rest:
		if r != null and r != head:
			fb.append(r)
	head.fallbacks = fb
	return head

static func display_font() -> Font:
	load_fonts()
	return _display_font

static func body_font() -> Font:
	load_fonts()
	return _body_font

# ---------------------------------------------------------------- boxes
## The one panel language: deep-ink glass, white hairline,
## soft drop shadow, real content margins (pre-cycle-17 _style
## never set shadow or margins — UI_SPEC §1.5).
static func glass(radius: int = 16, alpha: float = GLASS_A,
		border: Color = Color(1, 1, 1, 0.14), bw: int = 1,
		margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = glass_color(alpha)
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.shadow_size = 8
	s.shadow_color = Color(0.04, 0.02, 0.10, 0.45)
	s.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(margin)
	return s

static func flat_box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	return s

# ---------------------------------------------------------------- buttons
## The semantic button library (UI_SPEC §1.3): green = primary
## confirm, blue = secondary op, red = danger, ghost = quiet;
## sizes big / normal / small. Four states each; disabled goes
## to the spec's .45 opacity family (sold-out cards @2053527).
const BTN_KINDS := {
	"green": Color8(38, 176, 84),
	"blue": Color8(43, 116, 214),
	"red": Color8(206, 62, 52),
	"ghost": Color(0.114, 0.071, 0.212, 0.72),
}

static func _btn_box(bg: Color, radius: int, border: Color, bw: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.shadow_size = 4
	s.shadow_color = Color(0.04, 0.02, 0.10, 0.4)
	s.shadow_offset = Vector2(0, 2)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

static func make_button(text: String, kind: String = "ghost",
		size: String = "normal") -> Button:
	var b := Button.new()
	b.text = text
	b.set_meta("btn_size", size)
	b.set_meta("btn_kind", kind)
	var base: Color = BTN_KINDS.get(kind, BTN_KINDS["ghost"])
	var font_size := 16
	var min_h := 42.0
	var radius := 12
	var pad := 16
	match size:
		"big":
			font_size = 20
			min_h = 52.0
			radius = 14
			pad = 22
		"small":
			font_size = 13
			min_h = 32.0
			radius = 10
			pad = 12
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_override("font", body_font())
	b.add_theme_font_size_override("font_size", font_size)
	var border := Color(1, 1, 1, 0.16) if kind == "ghost" else Color(0, 0, 0, 0.18)
	var bw := 1 if kind == "ghost" else 2
	var hover := base.lightened(0.13)
	var pressed := base.darkened(0.15)
	if kind == "ghost":
		hover = Color(INK.r, INK.g, INK.b, 0.88)
		pressed = Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.9)
	b.add_theme_stylebox_override("normal", _btn_box(base, radius, border, bw, pad))
	b.add_theme_stylebox_override("hover", _btn_box(hover, radius, border, bw, pad))
	b.add_theme_stylebox_override("pressed", _btn_box(pressed, radius, border, bw, pad))
	var dis := base
	dis.a *= 0.45
	b.add_theme_stylebox_override("disabled", _btn_box(dis, radius, border, bw, pad))
	b.add_theme_stylebox_override("focus", _btn_box(Color(0, 0, 0, 0), radius, GOLD, 2, pad))
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_color_override("font_pressed_color", WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	return b

## Re-apply a semantic kind to an existing button (cycle 18:
## tab rails / toggle chips keep their size class from
## make_button's meta).
static func retint_button(b: Button, kind: String) -> void:
	var size := String(b.get_meta("btn_size", "normal"))
	var base: Color = BTN_KINDS.get(kind, BTN_KINDS["ghost"])
	var radius := 12
	var pad := 16
	match size:
		"big":
			radius = 14
			pad = 22
		"small":
			radius = 10
			pad = 12
	var border := Color(1, 1, 1, 0.16) if kind == "ghost" else Color(0, 0, 0, 0.18)
	var bw := 1 if kind == "ghost" else 2
	var hover := base.lightened(0.13)
	var pressed := base.darkened(0.15)
	if kind == "ghost":
		hover = Color(INK.r, INK.g, INK.b, 0.88)
		pressed = Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.9)
	b.add_theme_stylebox_override("normal", _btn_box(base, radius, border, bw, pad))
	b.add_theme_stylebox_override("hover", _btn_box(hover, radius, border, bw, pad))
	b.add_theme_stylebox_override("pressed", _btn_box(pressed, radius, border, bw, pad))
	var dis := base
	dis.a *= 0.45
	b.add_theme_stylebox_override("disabled", _btn_box(dis, radius, border, bw, pad))
	b.set_meta("btn_kind", kind)

## Button with the spec's anatomy (UI_SPEC §1.3: [icon
## 18–20px] text): an icon + label row centered over the
## semantic button face. Children ignore the mouse so the
## Button keeps its own press/hover handling.
static func make_icon_button(icon: String, text: String,
		kind: String = "ghost", size: String = "normal") -> Button:
	var b := make_button("", kind, size)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px := 18.0 if size == "small" else 20.0
	var ic := UiIcon.new(icon, WHITE, px)
	row.add_child(ic)
	var l := Label.new()
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size",
		13 if size == "small" else (20 if size == "big" else 16))
	l.add_theme_color_override("font_color", WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(l)
	b.add_child(row)
	# The full-rect row does not feed the Button's minimum
	# size, so the width is fitted from the text metrics
	# (cycle-17 draft-tools bug: buttons collapsed to their
	# padding and the row overflowed its labels).
	b.set_meta("label", l)
	b.set_meta("icon_px", px)
	b.set_meta("btn_size", size)
	_fit_icon_button(b, text)
	return b

static func _fit_icon_button(b: Button, text: String) -> void:
	(b.get_meta("label") as Label).text = text
	var size := String(b.get_meta("btn_size"))
	var fs := 13 if size == "small" else (20 if size == "big" else 16)
	# UI-mobile P5: the phone modal font floor raises the label
	# (meta fs_over) — the width follows the drawn size.
	fs = int(b.get_meta("fs_over", fs))
	var pad := 12.0 if size == "small" else (22.0 if size == "big" else 16.0)
	var tw := body_font().get_string_size(text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	b.custom_minimum_size.x = pad * 2.0 + float(b.get_meta("icon_px")) + 6.0 + tw + 4.0

static func set_icon_button_text(b: Button, text: String) -> void:
	if b.has_meta("label"):
		_fit_icon_button(b, text)

## Card button (draft / blessing / menu starter): a Button
## whose face is glass with a colored 2px rim — the accent
## carries rarity or type; hover lifts the rim to full color.
static func card_box(accent: Color, hover: bool = false,
		radius: int = 14, alpha: float = 0.92) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = glass_color(alpha if not hover else 0.97)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(2)
	s.border_color = Color(accent.r, accent.g, accent.b, 1.0 if hover else 0.75)
	s.shadow_size = 8
	s.shadow_color = Color(0.04, 0.02, 0.10, 0.45)
	s.shadow_offset = Vector2(0, 3)
	s.set_content_margin_all(0)
	return s

static func make_card(accent: Color, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = min_size
	b.add_theme_stylebox_override("normal", card_box(accent))
	b.add_theme_stylebox_override("hover", card_box(accent, true))
	b.add_theme_stylebox_override("pressed", card_box(accent.darkened(0.25), true))
	b.add_theme_stylebox_override("focus", card_box(GOLD, true))
	return b

# ---------------------------------------------------------------- chips
## sRGB luminance of a chip face (text-contrast decisions).
static func luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

## The readable text color on a filled chip: white fails on
## the light type faces (normal #c8c4a8 measures ~1.8:1), so
## faces lighter than ~0.55 luminance take ink text (cycle
## 19, audit punch #10). An explicit non-white fg is always
## respected.
static func readable_fg(bg: Color, want: Color = WHITE) -> Color:
	if want == WHITE and luminance(bg) > 0.55:
		return INK_SOFT
	return want

## Small rounded label chip (type chips, rarity chips, kbd).
static func chip(text: String, bg: Color, font_size: int = 12,
		fg: Color = WHITE, min_w: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := flat_box(bg, font_size)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if min_w > 0.0:
		p.custom_minimum_size = Vector2(min_w, 0)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", readable_fg(bg, fg))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

## The original's kbd key cap (UI_SPEC §1.3): ink cap, light rim.
static func kbd(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := flat_box(Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.92), 6,
		Color(1, 1, 1, 0.35), 1)
	s.content_margin_left = 7
	s.content_margin_right = 7
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

## Portrait lookup: portraits are baked discs (transparent
## corners) under assets/portraits/<species>.png by
## Test/portraitshot.tscn; a species without a bake returns
## null and the caller falls back to the medal disc + glyph.
static func portrait(species: String) -> Texture2D:
	var path := "res://assets/portraits/" + species + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## Dark outline for floating/display text (UI_SPEC §1.1: the
## original strokes world text with #1a1030).
static func outline(l: Label, size: int = 3) -> void:
	l.add_theme_color_override("font_outline_color", Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.95))
	l.add_theme_constant_override("outline_size", size)

# ------------------------------------------------- settings components
## Cycle 18 — the settings component family (UI_SPEC §1.3/§2.8:
## st-row rows, st-range sliders with a --p filled segment, pill
## segmented groups, switch toggles). Geometry is judged against
## the verified tokens (the per-class CSS is the named gap).

## Style an HSlider as an st-range: ink track, accent-filled
## portion before the grabber (the --p segment), round knob.
static func style_slider(s: HSlider, accent: Color = GOLD) -> void:
	var track := flat_box(Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.9), 5,
		Color(1, 1, 1, 0.14), 1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := flat_box(accent, 5)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.add_theme_icon_override("grabber_disabled", knob)

static var _knob_tex: Texture2D = null

static func _knob_texture() -> Texture2D:
	if _knob_tex != null:
		return _knob_tex
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	for y in range(22):
		for x in range(22):
			var d := Vector2(x - 10.5, y - 10.5).length()
			if d <= 8.0:
				img.set_pixel(x, y, Color(1, 1, 1))
			elif d <= 10.0:
				img.set_pixel(x, y, Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_knob_tex = ImageTexture.create_from_image(img)
	return _knob_tex

## A switch toggle (the original's `switch` with its <i> knob):
## a pill track Button; the knob child slides and the track
## retints. State lives with the caller (Profile); set_switch
## repaints. The button's `toggled`-style presses are plain
## `pressed` — the caller flips its own state then repaints.
static func make_switch(on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(54, 28)
	b.text = ""
	b.focus_mode = Control.FOCUS_NONE
	var knob := Panel.new()
	knob.name = "knob"
	knob.size = Vector2(22, 22)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(knob)
	set_switch(b, on)
	return b

static func set_switch(b: Button, on: bool) -> void:
	var rk := int(round(14.0 * float(b.get_meta("sw_k", 1.0))))
	var track := flat_box(GREEN_DEEP if on else Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.9), rk,
		Color(1, 1, 1, 0.2), 1)
	b.add_theme_stylebox_override("normal", track)
	b.add_theme_stylebox_override("hover", track)
	b.add_theme_stylebox_override("pressed", track)
	b.add_theme_stylebox_override("focus", flat_box(Color(0, 0, 0, 0), rk, GOLD, 2))
	var knob := b.get_node_or_null("knob") as Panel
	if knob:
		# UI-mobile P5: phone modals grow the switch by k (meta
		# sw_k, set by size_switch) — the knob scales with it.
		var k := float(b.get_meta("sw_k", 1.0))
		knob.size = Vector2(22, 22) * k
		knob.position = Vector2(29 if on else 3, 3) * k
		knob.add_theme_stylebox_override("panel", flat_box(Color.WHITE, int(round(11.0 * k))))
	b.set_meta("sw_on", on)

## UI-mobile P5: resize a switch to k x its 54x28 design (the
## phone modal button floor), repainting knob + track.
static func size_switch(b: Button, k: float) -> void:
	if absf(float(b.get_meta("sw_k", 1.0)) - k) < 0.001:
		return
	b.set_meta("sw_k", k)
	b.custom_minimum_size = Vector2(54, 28) * k
	set_switch(b, bool(b.get_meta("sw_on", false)))

## A segmented pill group (the original's `seg` + `pill.on`):
## returns the HBox; buttons carry their index in meta "seg_i"
## and the caller wires `pressed`. set_segmented repaints.
static func make_segmented(options: Array, current: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i in range(options.size()):
		var b := Button.new()
		b.text = String(options[i])
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("seg_i", i)
		b.add_theme_font_override("font", body_font())
		b.add_theme_font_size_override("font_size", 13)
		hb.add_child(b)
	set_segmented(hb, current)
	return hb

static func set_segmented(hb: HBoxContainer, current: int) -> void:
	for b in hb.get_children():
		var on := int(b.get_meta("seg_i", -1)) == current
		var box := flat_box(Color(GREEN_DEEP.r, GREEN_DEEP.g, GREEN_DEEP.b, 0.95) if on else Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.75), 10,
			Color(1, 1, 1, 0.25 if on else 0.12), 1)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 3
		box.content_margin_bottom = 3
		(b as Button).add_theme_stylebox_override("normal", box)
		(b as Button).add_theme_stylebox_override("hover", box)
		(b as Button).add_theme_stylebox_override("pressed", box)
		(b as Button).add_theme_stylebox_override("focus", flat_box(Color(0, 0, 0, 0), 10, GOLD, 2))
		(b as Button).add_theme_color_override("font_color", WHITE if on else MUTED)
		(b as Button).add_theme_color_override("font_hover_color", WHITE)
