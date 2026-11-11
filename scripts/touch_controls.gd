class_name TouchControls
extends Control
## Touch input layer, active only while the run is on a touch
## device (World toggles `visible`).
##
## Cycle 18 (UI_SPEC §5.5, bundle touch part @1951466):
##   tc-joy    floating joystick (zone = left 52%) — geometry
##             knobs (baseCfg touchRadius 65 / nubSize)
##             unchanged; `fixedStick` pins the origin to the
##             base disc.
##   tc-right  the action cluster now mirrors the bundle: the
##             ULT button lives IN the cluster (tc-ultb — the
##             same UltGauge, World pushes state to both and
##             hides the HUD one while touch is up), interact
##             (tc-act, exclamation icon), jump (tc-jump, icon
##             only), dash (tc-dash, icon only), aim (tc-aim —
##             our camera-assist toggle, target icon), lock
##             (tc-lock, crosshair icon), pause (tc-pause,
##             icon only). No text labels where the bundle
##             uses icons.
## UI-mobile P3 (plan §B4 P3, D1/D2): the NEW layout drops
##   pause (-> tap the hero portrait) and aim (-> the pause
##   panel's quick row) from the cluster, puts lock on the
##   arc (-300,-216)-(-236,-152), and grows every hit area to
##   >= 70 logical px around its centred visual (plan I2).
##   The CLASSIC layout (D6) is the 21.3.2 cluster: the
##   pause / aim / lock column, hit == visual. World picks
##   the layout (set_layout_classic); the layer boots classic.
##   touchScale [0.7-1.5] resizes every element in UNSCALED
##   space (offsets/sizes), never this layer itself — scaling
##   the layer would break the viewport-space joystick math.

signal ult_pressed

const UiTheme := preload("res://scripts/ui_theme.gd")
const UiIcon := preload("res://scripts/ui_icon.gd")
const UltGauge := preload("res://scripts/ult_gauge.gd")

const BASE_R := 62.0
const KNOB_R := 29.0
const DEADZONE := 0.15
const JOY_HOME_X := 104.0
# Cycle 19 hotfix: 168 -> 196. The stick scales with
# touchScale only, but the HUD's bottom-left cluster
# scales with the world UI factor (up to 2x on phones) —
# at phone factors the cluster's slot tops reach
# vh-62*factor and the idle ring (bottom at vh-106)
# settled ON the slots. At 196 the ring's bottom
# (vh-134) clears the slot tops even at factor 2.
const JOY_HOME_UP := 196.0

var _travel := 65.0
var joy_vector := Vector2.ZERO
## World-facing logical inputs (its getters read these without
## parens; keep them properties, not methods).
var move_vector: Vector2:
	get: return joy_vector
var jump_held: bool:
	get: return held("jump")
var dash_held: bool:
	get: return held("dash")
var _joy_id := -1
var _joy_origin := Vector2.ZERO
var _joy_cur := Vector2.ZERO
var _joy_zone: Control
var _base_ring: Control
var _knob: Control
var _buttons: Dictionary = {}  # kind -> {area, panel, base_off}
var _held: Dictionary = {}
var _edges: Dictionary = {}
var ult_gauge: UltGauge = null
var _scale_s := 1.0
var fixed_stick := false
var _lock_on := false
var _aim_on := false
# UI-mobile P1.2: interact button state, pushed by World
# every frame — 0 idle (nothing in range), 1 ready, 2 throw
# (ready + a 0.8 Hz border pulse).
var _interact_mode := 1
var _pulse_t := 0.0
# UI-mobile P1.3: the cluster gauge's identity glyph.
var _ult_glyph: Label
var _classic := true
const MIN_HIT := 70.0
const LOCK_ARC := Vector4(-300, -216, -236, -152)
const INTERACT_FILL := Color(0.96, 0.52, 0.08, 0.95)
const INTERACT_BORDER := Color(0.96, 0.52, 0.08, 0.85)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_zone = Control.new()
	_joy_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_joy_zone.anchor_right = 0.52
	_joy_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_zone.gui_input.connect(_on_zone_input)
	add_child(_joy_zone)
	_base_ring = _make_disc(Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.35))
	_knob = _make_disc(Color(1, 1, 1, 0.28), Color(1, 1, 1, 0.5))
	add_child(_base_ring)
	add_child(_knob)
	_reset_stick_visual()
	var f := UiTheme.body_font()
	_build_button(f, "interact", "exclaim", 96, -120, -24, -148, -52,
		Color(1, 0.85, 0.3, 0.20), Color(1, 0.85, 0.3, 0.85))
	_build_button(f, "jump", "up", 80, -216, -136, -128, -48,
		Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.55))
	_build_button(f, "dash", "wind", 80, -216, -136, -224, -144,
		Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.55))
	_build_button(f, "lock", "crit", 56, -118, -62, -316, -260,
		Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.55))
	_build_button(f, "aim", "target", 56, -118, -62, -384, -328,
		Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.55))
	_build_button(f, "pause", "pause", 56, -118, -62, -452, -396,
		Color(1, 1, 1, 0.13), Color(1, 1, 1, 0.55))
	# The cluster ult gauge (tc-ultb): the same UltGauge the
	# HUD uses, fed by World.set_ult_state pushes.
	ult_gauge = UltGauge.new()
	ult_gauge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ult_gauge.offset_left = -124
	ult_gauge.offset_right = -40
	ult_gauge.offset_top = -248
	ult_gauge.offset_bottom = -164
	ult_gauge.set_meta("base_off", Vector4(-124, -248, -40, -164))
	ult_gauge.pressed.connect(func() -> void: ult_pressed.emit())
	add_child(ult_gauge)
	# UI-mobile P1.3 (plan K5): the gauge was an unlabeled
	# dark disc on touch — it now wears the 必 glyph (the
	# HUD gauge's identity), sized 22 x touchScale.
	_ult_glyph = Label.new()
	_ult_glyph.text = "必"
	_ult_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ult_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ult_glyph.add_theme_font_override("font", UiTheme.display_font())
	_ult_glyph.add_theme_font_size_override("font_size", 48)
	_ult_glyph.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_ult_glyph.add_theme_color_override("font_outline_color", UiTheme.ORANGE.darkened(0.25))
	_ult_glyph.add_theme_constant_override("outline_size", 4)
	_ult_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ult_gauge.add_child(_ult_glyph)
	visibility_changed.connect(_on_visibility)
	resized.connect(_apply_column)

func _make_disc(fill: Color, border: Color) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(999)
	sb.set_border_width_all(2)
	sb.border_color = border
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _reset_stick_visual() -> void:
	var home := _joy_home()
	_base_ring.position = home - Vector2(BASE_R, BASE_R) * _scale_s
	_base_ring.size = Vector2(BASE_R, BASE_R) * 2.0 * _scale_s
	_knob.position = home - Vector2(KNOB_R, KNOB_R) * _scale_s
	_knob.size = Vector2(KNOB_R, KNOB_R) * 2.0 * _scale_s

## Cycle 20.2 (re-audit HOLD): viewport-space cap for the
## idle ring's BOTTOM edge, pushed by World._layout_hud —
## the BL cluster's slot-row visual top. The row is laid
## out by the HUD factor (up to 2x) while the ring scales
## with touchScale only, so the raw home (bottom at
## vp.y - 134*s) crossed the row at touchScale 0.70-0.85
## (626.2 at s=0.70 vs row top 600.65 — the C19 overlap
## class, reproduced in the phonehud sweep). INF =
## uncapped (pre-layout frames / no HUD).
var _ring_bottom_limit := INF

func set_ring_bottom_limit(y: float) -> void:
	_ring_bottom_limit = y
	if _joy_id == -1:
		_reset_stick_visual()

## Cycle 21.3 (audit F1): the HUD right column's visual
## left edge, pushed by World._layout_hud in THIS layer's
## local space. The pause / aim / lock column moves to
## sit immediately LEFT of it (right edge = _col_left -
## 10), out of the goal / event cards' text. Jump, dash,
## interact and the ult gauge never move (audit: their
## offsets and apply_scale are unchanged). INF = no lane
## pushed yet (pre-layout frames).
var _col_left := INF

func set_right_column_left(x: float) -> void:
	_col_left = x
	_apply_column()

## The moved column's visual left edge (for the world's
## centre-stack span maths). UI-mobile P3: the new layout
## has no column (INF — the span's lane falls back to the
## minimap).
func column_left() -> float:
	if _col_left == INF or not _classic:
		return INF
	return _col_left - 10.0 - 56.0 * _scale_s

## UI-mobile P2: the moved column's top edge (layer space) —
## at touchScale 1.50 the pause button rises into the top
## card's band and the world fits the card left of it.
func column_top() -> float:
	if not _classic:
		return INF
	var m := INF
	for kind in ["pause", "aim", "lock"]:
		if _buttons.has(kind):
			m = minf(m, ((_buttons[kind] as Dictionary)["area"] as Control).get_rect().position.y)
	return m

## The whole right cluster's leftmost visual edge, in
## this layer's space (Cycle 21.3, audit F5c): the big
## dash / jump buttons (80 design px) protrude further
## left than the moved small column at large
## touchScales, and the prompt's free span ends at the
## CLUSTER, not the column.
func cluster_left() -> float:
	var m := INF
	for kind in _buttons.keys():
		var area := (_buttons[kind] as Dictionary)["area"] as Control
		if area != null and area.visible:
			m = minf(m, area.get_rect().position.x)
	if ult_gauge != null and ult_gauge.visible:
		m = minf(m, ult_gauge.get_rect().position.x)
	return m

## UI-mobile P3: lowest top (this layer's space) of the
## visible cluster pieces whose x-range meets [x0, x1] — the
## right column / objective pill / drawer must end above it.
## INF before layout or when nothing is under the range.
func cluster_top_over(x0: float, x1: float) -> float:
	if size.y <= 1.0:
		return INF
	var m := INF
	var rs: Array = []
	for kind in _buttons.keys():
		var area := (_buttons[kind] as Dictionary)["area"] as Control
		if area.visible:
			rs.append(area.get_rect())
	if ult_gauge != null and ult_gauge.visible:
		rs.append(ult_gauge.get_rect())
	for r in rs:
		if (r as Rect2).end.x > x0 and (r as Rect2).position.x < x1:
			m = minf(m, (r as Rect2).position.y)
	return m

## UI-mobile P3 / D6: classic = the 21.3.2 cluster (pause /
## aim / lock column, hit == visual); new = pause + aim gone,
## lock on the arc, hit areas >= 70.
func set_layout_classic(on: bool) -> void:
	_classic = on
	for kind in ["pause", "aim"]:
		if _buttons.has(kind):
			((_buttons[kind] as Dictionary)["area"] as Control).visible = on
			_held[kind] = false
			_edges[kind] = false
	apply_scale(_scale_s)

func is_classic() -> bool:
	return _classic

func _apply_column() -> void:
	if _col_left == INF or size.x <= 1.0 or not _classic:
		return
	for kind in ["pause", "aim", "lock"]:
		if not _buttons.has(kind):
			continue
		var rec: Dictionary = _buttons[kind]
		var area: Control = rec["area"]
		var bo: Vector4 = rec["base_off"]
		var wdt := (bo.z - bo.x) * _scale_s
		area.offset_right = _col_left - 10.0 - size.x
		area.offset_left = _col_left - 10.0 - size.x - wdt

func _joy_home() -> Vector2:
	# Cycle 21.3 (audit F6): home is computed in THIS
	# layer's space — the layer carries the safe-area
	# insets, so its own size is the inset size, not the
	# raw viewport's. Fallback covers pre-layout frames.
	var vp := size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = get_viewport_rect().size
	var home := Vector2(JOY_HOME_X * _scale_s, vp.y - JOY_HOME_UP * _scale_s)
	if _ring_bottom_limit < INF:
		var bottom := home.y + BASE_R * _scale_s
		if bottom > _ring_bottom_limit:
			home.y -= bottom - _ring_bottom_limit
	return home

func _on_visibility() -> void:
	if not visible:
		_joy_id = -1
		joy_vector = Vector2.ZERO
		_held.clear()
		_edges.clear()
		_reset_stick_visual()

func _on_zone_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _joy_id == -1:
			var pos := get_global_mouse_position()
			if fixed_stick and pos.distance_to(_joy_home()) > 100.0 * _scale_s:
				return  # fixed stick: presses land on the base only
			_joy_id = 0
			_joy_origin = pos
			_joy_cur = pos
			_update_stick()
		elif not event.pressed and _joy_id != -1:
			_joy_id = -1
			joy_vector = Vector2.ZERO
			_reset_stick_visual()
	elif event is InputEventScreenTouch:
		if event.pressed and _joy_id == -1:
			var pos2: Vector2 = (event as InputEventScreenTouch).position
			if fixed_stick and pos2.distance_to(_joy_home()) > 100.0 * _scale_s:
				return
			_joy_id = event.index
			_joy_origin = pos2
			_joy_cur = pos2
			_update_stick()
		elif not event.pressed and event.index == _joy_id:
			_joy_id = -1
			joy_vector = Vector2.ZERO
			_reset_stick_visual()
	elif event is InputEventMouseMotion and _joy_id == 0:
		_joy_cur = get_global_mouse_position()
		_update_stick()
	elif event is InputEventScreenDrag and event.index == _joy_id:
		_joy_cur = event.position
		_update_stick()

func _update_stick() -> void:
	var d := _joy_cur - _joy_origin
	if d.length() > _travel:
		d = d.normalized() * _travel
	joy_vector = d / _travel
	if joy_vector.length() < DEADZONE:
		joy_vector = Vector2.ZERO
	_base_ring.position = _joy_origin - Vector2(BASE_R, BASE_R) * _scale_s
	_base_ring.size = Vector2(BASE_R, BASE_R) * 2.0 * _scale_s
	_knob.position = _joy_origin + d * _scale_s \
		- Vector2(KNOB_R, KNOB_R) * _scale_s
	_knob.size = Vector2(KNOB_R, KNOB_R) * 2.0 * _scale_s

# ------------------------------------------------------------ buttons

func _build_button(font: Font, kind: String, icon: String, size: int,
		ol: float, orr: float, ot: float, ob: float,
		fill: Color, border: Color) -> void:
	var area := Control.new()
	area.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	area.offset_left = ol
	area.offset_right = orr
	area.offset_top = ot
	area.offset_bottom = ob
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = {"dash": UiTheme.GREEN_DEEP, "jump": UiTheme.SKY, "interact": UiTheme.ORANGE}.get(kind, UiTheme.CREAM)
	sb.set_corner_radius_all(999)
	sb.set_border_width_all(3)
	sb.border_width_bottom = 6
	sb.border_color = UiTheme.CREAM
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0, 3)
	sb.shadow_color = Color(0.25, 0.18, 0.09, 0.25)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(panel)
	var ic := UiIcon.new()
	ic.icon = icon
	ic.color = UiTheme.TEXT if kind in ["lock", "aim", "pause"] else Color.WHITE
	ic.set_anchors_preset(Control.PRESET_CENTER)
	var half := size * 0.30
	ic.offset_left = -half
	ic.offset_top = -half
	ic.offset_right = half
	ic.offset_bottom = half
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(ic)
	area.gui_input.connect(_on_button_input.bind(kind))
	add_child(area)
	_buttons[kind] = {"area": area, "panel": panel, "icon": ic,
		"base_off": Vector4(ol, ot, orr, ob)}
	_held[kind] = false
	_edges[kind] = false

func _on_button_input(event: InputEvent, kind: String) -> void:
	var down := false
	var up := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenTouch:
		down = event.pressed
		up = not event.pressed
	if down:
		_held[kind] = true
		_edges[kind] = true
		var panel: Panel = _buttons[kind]["panel"]
		(panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a = 1.0 if kind == "interact" else 0.42
	elif up:
		_held[kind] = false
		var panel2: Panel = _buttons[kind]["panel"]
		(panel2.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a = \
			_interact_fill_a() if kind == "interact" else 0.13

func held(kind: String) -> bool:
	return bool(_held.get(kind, false))

func consume_edge(kind: String) -> bool:
	var v := bool(_edges.get(kind, false))
	_edges[kind] = false
	return v

func consume_interact() -> bool:
	return consume_edge("interact")

func consume_touch_pause() -> bool:
	return consume_edge("pause")

func consume_touch_lock() -> bool:
	return consume_edge("lock")

func consume_touch_aim() -> bool:
	return consume_edge("aim")

# ------------------------------------------------------------ state

## World pushes ult state to the cluster gauge (the HUD gauge
## is hidden while touch is up). UI-mobile P1.3: the third
## argument is the controller's deny window in seconds (a
## float — it was typed bool while World passed deny_t,
## so the gauge's red deny veil never drew on touch).
func set_ult_state(frac: float, pcol: Color, deny: float) -> void:
	if ult_gauge != null:
		ult_gauge.set_state(frac, pcol, deny)

## UI-mobile P1.2 (plan §B3 I8): the interact button tells
## the truth about what a tap does. 0 idle: near-clear fill
## (a .06), faint rim (a .30), dim icon (a .45); 1 ready:
## the shipped yellow; 2 throw: ready + 0.8 Hz rim pulse.
func set_interact_mode(m: int) -> void:
	if m == _interact_mode or not _buttons.has("interact"):
		return
	_interact_mode = m
	var rec: Dictionary = _buttons["interact"]
	var sb := (rec["panel"] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	var pressed := held("interact")
	sb.bg_color = Color(INTERACT_FILL.r, INTERACT_FILL.g, INTERACT_FILL.b,
		1.0 if pressed else _interact_fill_a())
	sb.border_color = Color(INTERACT_BORDER.r, INTERACT_BORDER.g,
		INTERACT_BORDER.b, 0.30 if m == 0 else INTERACT_BORDER.a)
	(rec["icon"] as Control).modulate.a = 0.45 if m == 0 else 1.0
	(rec["panel"] as Panel).queue_redraw()

func _interact_fill_a() -> float:
	return 0.06 if _interact_mode == 0 else INTERACT_FILL.a

func _process(delta: float) -> void:
	if _interact_mode != 2 or not visible or not _buttons.has("interact"):
		return
	_pulse_t += delta
	var sb := (_buttons["interact"]["panel"] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_color.a = 0.55 + 0.40 * (0.5 + 0.5 * sin(_pulse_t * TAU * 0.8))
	(_buttons["interact"]["panel"] as Panel).queue_redraw()

## Lock / aim latched visuals (green ring while engaged).
func set_lock_state(on: bool) -> void:
	_lock_on = on
	_tint_small("lock", on)

func set_aim_state(on: bool) -> void:
	_aim_on = on
	_tint_small("aim", on)

func _tint_small(kind: String, on: bool) -> void:
	if not _buttons.has(kind):
		return
	var panel: Panel = _buttons[kind]["panel"]
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	sb.border_color = Color(0.48, 1, 0.54, 0.95) if on else Color(1, 1, 1, 0.55)
	sb.bg_color = Color(0.15, 0.7, 0.33, 0.30) if on \
		else Color(1, 1, 1, 0.13)

## touchScale [0.7–1.5]: every element resized in unscaled
## space (offsets scale linearly from the anchor corner).
func apply_scale(s: float) -> void:
	_scale_s = clampf(s, 0.7, 1.5)
	_travel = 65.0 * _scale_s
	for kind in _buttons.keys():
		var rec: Dictionary = _buttons[kind]
		var area: Control = rec["area"]
		var bo: Vector4 = rec["base_off"]
		if kind == "lock" and not _classic:
			bo = LOCK_ARC
		# UI-mobile P3 (plan I2): the hit area grows to >= 70
		# about the visual; the panel insets back to the
		# visual size (it is FULL_RECT inside the area).
		var pad := 0.0
		if not _classic:
			pad = maxf(0.0, (MIN_HIT - (bo.z - bo.x) * _scale_s) * 0.5)
		area.offset_left = bo.x * _scale_s - pad
		area.offset_top = bo.y * _scale_s - pad
		area.offset_right = bo.z * _scale_s + pad
		area.offset_bottom = bo.w * _scale_s + pad
		var panel: Control = rec["panel"]
		panel.offset_left = pad
		panel.offset_top = pad
		panel.offset_right = -pad
		panel.offset_bottom = -pad
	if ult_gauge != null:
		var bo2: Vector4 = ult_gauge.get_meta("base_off")
		var gpad := 0.0
		if not _classic:
			gpad = maxf(0.0, (MIN_HIT - (bo2.z - bo2.x) * _scale_s) * 0.5)
		ult_gauge.offset_left = bo2.x * _scale_s - gpad
		ult_gauge.offset_top = bo2.y * _scale_s - gpad
		ult_gauge.offset_right = bo2.z * _scale_s + gpad
		ult_gauge.offset_bottom = bo2.w * _scale_s + gpad
		ult_gauge.hit_pad = gpad
		ult_gauge.queue_redraw()
	if _ult_glyph != null:
		_ult_glyph.add_theme_font_size_override("font_size", int(round(48.0 * _scale_s)))
	# Cycle 21.3: the lane column's offsets are NOT the
	# base x _scale_s products — re-derive them last.
	_apply_column()
	if _joy_id == -1:
		_reset_stick_visual()

# ------------------------------------------------------------ debug

func debug_joy_origin() -> Vector2:
	return _joy_origin

func debug_joy_active() -> bool:
	return _joy_id != -1

## UI-mobile P1 addendum: the touch index the joystick owns
## (-1 = none), so World's camera drag never reuses it.
func joy_touch_id() -> int:
	return _joy_id

func debug_button_center(kind: String) -> Vector2:
	if not _buttons.has(kind):
		return Vector2.INF
	var area: Control = _buttons[kind]["area"]
	return area.get_global_rect().get_center()

func debug_button_size(kind: String) -> Vector2:
	if not _buttons.has(kind):
		return Vector2.INF
	var area: Control = _buttons[kind]["area"]
	return area.get_global_rect().size
