class_name UiTheme
extends RefCounted

## Approved U1–U6 palette, 2026-11-09. Shared presentation tokens.
# ---------------------------------------------------------------- tokens
const INK := Color8(255, 247, 229)          # #1d1236 panel ink
const INK_DEEP := Color8(218, 198, 162)     # #1a1030 outline ink
const INK_SOFT := Color8(82, 64, 49)     # #2a2350 ink on light faces
const GLASS_A := 0.98                    # verified glass alpha
const GOLD := Color8(255, 210, 58)       # #ffd23a
const YELLOW := Color8(255, 226, 58)      # #ffe23a
const GREEN := Color8(144, 205, 62)     # #7aff8a
const GREEN_DEEP := Color8(103, 166, 40) # #36c96a
const SKY := Color8(72, 170, 218)       # #8ae8ff
const PIN := Color8(255, 210, 58)        # #ffd23a map pin gold
const PINK := Color8(255, 90, 138)       # #ff5a8a
const PINK_SOFT := Color8(255, 154, 224) # #ff9ae0
const PURPLE := Color8(154, 106, 255)    # #9a6aff
const LILAC := Color8(200, 168, 255)     # #c8a8ff
const MUTED := Color8(119, 101, 79)     # #9aa0b4
## U1 1:1 (dark HUD): secondary text on the dark HUD faces —
## MUTED is a brown-grey tuned for cream, too dim on ink.
const HUD_DIM := Color8(206, 200, 190)
const FAINT := Color8(151, 134, 111)     # #6a6488
const RED := Color8(255, 74, 74)         # #ff4a4a
const ORANGE := Color8(255, 151, 36)
const CREAM := INK
const TEXT := INK_SOFT
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
	return Color(INK.r, INK.g, INK.b, 1.0)

# Approved asset registry. Source PNGs are copied byte-for-byte.
static var _ui_textures: Dictionary = {}
static func asset(category: String, key: String) -> Texture2D:
	var path := "res://assets/ui/%s/%s.png" % [category, key]
	if not _ui_textures.has(path):
		_ui_textures[path] = load(path)
	return _ui_textures[path] as Texture2D

static func art(key: String, extent: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = asset("decorations", key)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = extent
	node.size = extent
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func scaled_texture(key: String) -> Texture2D:
	var cache_key := "scaled/" + key
	if not _ui_textures.has(cache_key):
		var image := asset("textures", key).get_image()
		image.resize(image.get_width() / 4, image.get_height() / 4, Image.INTERPOLATE_LANCZOS)
		_ui_textures[cache_key] = ImageTexture.create_from_image(image)
	return _ui_textures[cache_key]

static func panel_underlay(node: Control) -> void:
	var box := panel_texture(0)
	node.draw.connect(func() -> void: node.draw_style_box(box, Rect2(Vector2.ZERO, node.size)))

static func panel_texture(margin: int = 14) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = scaled_texture("panel_9patch")
	box.set_texture_margin_all(28)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_expand_margin(side, 3)
		box.set_content_margin(side, margin)
	return box

static func badge_base() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = asset("badges", "badge_star_empty")
	# The empty star remains behind the existing move glyph.
	return box

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
## The one panel language: opaque cream, white top highlight,
## soft drop shadow, real content margins (pre-cycle-17 _style
## never set shadow or margins — UI_SPEC §1.5).
static func glass(radius: int = 16, alpha: float = GLASS_A,
		border: Color = Color(1, 1, 1, 0.14), bw: int = 1,
		margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = glass_color(alpha)
	s.set_corner_radius_all(maxi(radius, 28))
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = Color(1, 1, 1, 0.92)
		s.border_width_top = maxi(bw, 3)
	s.shadow_size = 8
	s.shadow_color = Color(0.29, 0.21, 0.10, 0.23)
	s.shadow_offset = Vector2(0, 5)
	s.set_content_margin_all(margin)
	return s

## U1 1:1 (dark HUD): the HUD's dark face — deep ink at 0.92,
## light rim, same shadow as glass(). The menu keeps glass()
## (opaque cream); only in-run HUD chrome uses this.
static func dark_glass(radius: int = 16, alpha: float = 0.92,
		border: Color = Color(1, 1, 1, 0.25), bw: int = 1,
		margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.07, 0.20, alpha)
	s.set_corner_radius_all(maxi(radius, 12))
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
		s.border_width_top = maxi(bw, 1)
	s.shadow_size = 8
	s.shadow_color = Color(0.02, 0.01, 0.05, 0.35)
	s.shadow_offset = Vector2(0, 5)
	s.set_content_margin_all(margin)
	return s

## U1 1:1 定稿半透明灰蓝磨砂玻璃语言（顶栏胶囊、英雄背板、技能底带、目标卡共用），
## 支持真半圆胶囊大圆角（传 radius 即可，不强制覆写下限）及细亮白灰内描边。
static func hud_glass(radius: int = 24, alpha: float = 0.74,
		border: Color = Color(0.88, 0.94, 1.0, 0.62), bw: int = 2,
		margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.22, 0.28, 0.36, alpha)
	s.set_corner_radius_all(radius)
	if bw > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.shadow_size = 6
	s.shadow_color = Color(0.04, 0.07, 0.12, 0.30)
	s.shadow_offset = Vector2(0, 4)
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
	"green": Color8(128, 187, 43),
	"blue": Color8(66, 174, 224),
	"red": Color8(206, 62, 52),
	"orange": ORANGE,
	"ghost": CREAM,
}

## 自适应真半圆胶囊按钮样式：按当前按钮实际高度等比例缩放左右半圆端盖，
## 仅水平拉伸中间均匀过渡带（源图 x=224..800 为水平常值纯平列），
## 彻底消除九宫格垂直压扁导致的左右尖刺，并避免大按钮被拉成方肩矩形。
class CapsuleStyleBox extends StyleBox:
	## 原始高分辨率按钮纹理（1024×320）
	var texture: Texture2D = null
	## 颜色调制（兼容禁用态透明度及 U3 蓝/红按钮着色）
	var modulate_color: Color = Color.WHITE
	## 源纹理左右端盖宽度（像素，覆盖半圆弧及左上斜高光区）
	var cap_src_px: float = 224.0

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
			return
		var sz := texture.get_size()
		if sz.x <= 0.0 or sz.y <= 0.0:
			return
		var cap_w := (cap_src_px / sz.y) * rect.size.y
		var total_cap := cap_w * 2.0
		if total_cap > rect.size.x and total_cap > 0.0:
			var k := rect.size.x / total_cap
			cap_w *= k
		var rid := texture.get_rid()
		# 左半圆端盖（含左上角柔椭圆高光）
		RenderingServer.canvas_item_add_texture_rect_region(
			to_canvas_item,
			Rect2(rect.position, Vector2(cap_w, rect.size.y)),
			rid,
			Rect2(0.0, 0.0, cap_src_px, sz.y),
			modulate_color
		)
		# 中间水平均匀过渡带
		var mid_w := rect.size.x - cap_w * 2.0
		if mid_w > 0.0:
			var mid_src_w := sz.x - cap_src_px * 2.0
			RenderingServer.canvas_item_add_texture_rect_region(
				to_canvas_item,
				Rect2(Vector2(rect.position.x + cap_w, rect.position.y), Vector2(mid_w, rect.size.y)),
				rid,
				Rect2(cap_src_px, 0.0, mid_src_w, sz.y),
				modulate_color
			)
		# 右半圆端盖
		RenderingServer.canvas_item_add_texture_rect_region(
			to_canvas_item,
			Rect2(Vector2(rect.position.x + rect.size.x - cap_w, rect.position.y), Vector2(cap_w, rect.size.y)),
			rid,
			Rect2(sz.x - cap_src_px, 0.0, cap_src_px, sz.y),
			modulate_color
		)

static func _btn_box(bg: Color, radius: int, border: Color, bw: int, pad: int) -> StyleBox:
	var s := CapsuleStyleBox.new()
	var key := "button_cream"
	if bg.g > bg.r * 1.12 and bg.b < bg.g * 0.7:
		key = "button_green"
	elif bg.r > bg.g * 1.3 and bg.b < bg.g * 0.8:
		key = "button_orange"
	s.texture = asset("textures", key)
	s.modulate_color = Color(1, 1, 1, bg.a)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

## U3 draft: a semantic button face from the cream 9-patch,
## tinted to an exact target color by modulate (there is no
## blue button texture — the _btn_box heuristic falls through
## to cream for blue, which is why the draft reroll rendered
## cream). The tint is solved against the face pixel of the
## cream texture (248,230,199) so the face lands on `bg`;
## the baked shading survives because only the tint changes.
static func tinted_btn_box(bg: Color, radius: int, border: Color, bw: int, pad: int) -> StyleBox:
	var s := _btn_box(bg, radius, border, bw, pad)
	var face := Color8(248, 230, 199)
	(s as CapsuleStyleBox).modulate_color = Color(
		clampf(bg.r / face.r, 0.0, 1.0),
		clampf(bg.g / face.g, 0.0, 1.0),
		clampf(bg.b / face.b, 0.0, 1.0),
		bg.a)
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
		hover = CREAM.lightened(0.06)
		pressed = CREAM.darkened(0.08)
	b.add_theme_stylebox_override("normal", _btn_box(base, radius, border, bw, pad))
	b.add_theme_stylebox_override("hover", _btn_box(hover, radius, border, bw, pad))
	b.add_theme_stylebox_override("pressed", _btn_box(pressed, radius, border, bw, pad))
	var dis := base
	dis.a *= 0.45
	b.add_theme_stylebox_override("disabled", _btn_box(dis, radius, border, bw, pad))
	b.add_theme_stylebox_override("focus", flat_box(Color(0, 0, 0, 0), 24, GOLD, 2))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(TEXT, 0.5))
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
		hover = CREAM.lightened(0.06)
		pressed = CREAM.darkened(0.08)
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
	var ic := UiIcon.new(icon, TEXT, px)
	row.add_child(ic)
	var l := Label.new()
	l.add_theme_font_override("font", body_font())
	l.add_theme_font_size_override("font_size",
		13 if size == "small" else (20 if size == "big" else 16))
	l.add_theme_color_override("font_color", TEXT)
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
	# A "min_w" meta pins a reference width (U5 result buttons):
	# _p5_fit re-fits icon buttons when the font floor moves, which
	# would otherwise shrink them back to text width.
	b.custom_minimum_size.x = maxf(pad * 2.0 + float(b.get_meta("icon_px")) + 6.0 + tw + 4.0, float(b.get_meta("min_w", 0.0)))

static func set_icon_button_text(b: Button, text: String) -> void:
	if b.has_meta("label"):
		_fit_icon_button(b, text)

## Card button (draft / blessing / menu starter): a Button
## whose face is glass with a colored 2px rim — the accent
## carries rarity or type; hover lifts the rim to full color.
static func card_box(accent: Color, hover: bool = false,
		radius: int = 32, alpha: float = 0.99) -> StyleBoxTexture:
	var box := panel_texture(0)
	box.modulate_color = Color.WHITE if not hover else Color(1, 0.97, 0.88)
	return box

## Icon order 2: rarity card frames (assets/ui/frames/card_*.png,
## 444x604 equal-ratio full faces). Callers pass frame_rarity >= 0
## only for cards whose aspect matches the art (~0.735) — the
## frame is drawn unstretched, per the order.
const CARD_FRAMES := ["common", "uncommon", "rare", "epic", "legendary"]
static func card_frame_box(rarity: int, hover: bool = false) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load("res://assets/ui/frames/card_%s.png" % CARD_FRAMES[clampi(rarity, 0, 4)])
	box.modulate_color = Color(1, 0.97, 0.88) if hover else Color.WHITE
	return box

static func make_card(accent: Color, min_size: Vector2, frame_rarity: int = -1) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = min_size
	if frame_rarity >= 0:
		b.add_theme_stylebox_override("normal", card_frame_box(frame_rarity))
		b.add_theme_stylebox_override("hover", card_frame_box(frame_rarity, true))
		var pressed := card_frame_box(frame_rarity, true)
		pressed.modulate_color = Color(0.82, 0.78, 0.72)
		b.add_theme_stylebox_override("pressed", pressed)
		var focus := StyleBoxTexture.new()
		focus.texture = load("res://assets/ui/frames/card_selected.png")
		b.add_theme_stylebox_override("focus", focus)
		return b
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
	l.add_theme_color_override("font_outline_color", Color(TEXT, 0.95))
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
static func make_switch(on: bool, visual_scale: float = 1.0) -> Button:
	var b := Button.new()
	b.set_meta("sw_visual_scale", visual_scale)
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
	var k := float(b.get_meta("sw_k", 1.0))
	var visual_scale := float(b.get_meta("sw_visual_scale", 1.0))
	var visual_k := k * visual_scale
	var inset := Vector2.ZERO
	var rk := int(round(14.0 * visual_k))
	var track := flat_box(GREEN_DEEP if on else Color(INK_DEEP.r, INK_DEEP.g, INK_DEEP.b, 0.9), rk,
		Color(1, 1, 1, 0.2), 1)
	if visual_scale < 1.0:
		var painted := b.get_node_or_null("SwitchTrack") as Panel
		if painted == null:
			painted = Panel.new()
			painted.name = "SwitchTrack"
			painted.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(painted)
			b.move_child(painted, 0)
		painted.size = Vector2(54, 28) * visual_k
		inset = (b.size.max(b.custom_minimum_size) - painted.size) * 0.5
		painted.position = inset
		painted.add_theme_stylebox_override("panel", track)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	else:
		b.add_theme_stylebox_override("normal", track)
		b.add_theme_stylebox_override("hover", track)
		b.add_theme_stylebox_override("pressed", track)
	b.add_theme_stylebox_override("focus", flat_box(Color(0, 0, 0, 0), rk, GOLD, 2))
	var knob := b.get_node_or_null("knob") as Panel
	if knob:
		# UI-mobile P5: phone modals grow the switch by k (meta
		# sw_k, set by size_switch) — the knob scales with it.
		knob.size = Vector2(22, 22) * visual_k
		knob.position = inset + Vector2(29 if on else 3, 3) * visual_k
		knob.add_theme_stylebox_override("panel", flat_box(Color.WHITE, int(round(11.0 * visual_k))))
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

static func text_color(color: Color) -> Color:
	if color.r > 0.74 and color.g > 0.74 and color.b > 0.74:
		return TEXT
	return color.darkened(0.20) if luminance(color) > 0.6 else color
