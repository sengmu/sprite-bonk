class_name UltGauge
extends Control

## Cycle 13 — the ult （必） button: replaces the decorative
## MOUSE_FILTER_IGNORE Panel. Draws the charge as a sweep arc
## around the disc (the bundle's HUD gauge fills as charge
## accrues and lights at ready), bright + pulsing rim at full
## charge, and — the actual point — it is a real button: touch
## and mouse presses emit `pressed`, which World latches into
## the Ult controller's trigger poll (the same edge as KeyR).
## The bundle's touch variant of the ready toast says "tap its
## button"; this is that button.

signal pressed

var charge := 0.0
var tint := Color(0.55, 0.85, 0.4)
var medal := Color(0.4, 0.4, 0.45)
var deny_t := 0.0
## UI-mobile P3 (plan I2): the touch cluster grows this
## control's rect to a >= 70 px hit area; the disc keeps
## its visual size, inset by hit_pad on every side.
var hit_pad := 0.0
## Icon order 2: art mode — the touch cluster's gauge wears the
## btn_ult / btn_ult_charging art (state swapped by TouchControls)
## instead of the drawn disc. The HUD gauge instance never sets
## this and keeps the drawn U1 form.
var art_mode := false
var _pulse := 0.0
var _last_drawn := -1.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	# Handle presses through the gui_input SIGNAL (not only the
	# _gui_input virtual) so the harness can drive the real path
	# by emitting the signal with a synthetic event.
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pressed.emit()
		accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit()
			accept_event()

func set_state(c: float, t: Color, deny: float) -> void:
	tint = t
	deny_t = deny
	if absf(c - charge) > 0.002 or (c >= 1.0) != (charge >= 1.0):
		charge = c
		queue_redraw()

func _process(delta: float) -> void:
	if charge >= 1.0:
		_pulse += delta
		queue_redraw()  # the ready pulse animates
	elif deny_t > 0.0:
		queue_redraw()

func _draw() -> void:
	if art_mode:
		return
	var centre := size * 0.5
	var r_out := minf(size.x, size.y) * 0.5 - 1.0 - hit_pad
	# Base disc: ult purple (reference U1: purple disc +
	# white 必) with a lighter rim — the old star badge
	# texture read as an orange star and buried the glyph.
	draw_circle(centre, r_out, Color(0.55, 0.28, 0.88))
	draw_arc(centre, r_out - 1.5, 0.0, TAU, 48, Color(0.72, 0.50, 1.0), 3.0, true)
	# U1 1:1 round 8: darker inner bed so the white 必 reads
	# like the reference (dark purple centre, bold white
	# glyph); the charge sweep / ready face / deny veil draw
	# on top of it.
	draw_circle(centre, r_out - 6.0, Color(0.38, 0.16, 0.68))
	# U1 1:1 round 7: segmented charge ring (reference) — 12
	# segments just outside the disc; lit ones track charge,
	# unlit ones stay dim so the ring reads at any charge
	# (at 0 charge the plain disc read as "missing ring").
	var segs := 12
	var r_ring := r_out + 3.0
	var lit := int(floor(charge * float(segs) + 0.001))
	for i in range(segs):
		var a0 := TAU * float(i) / float(segs) + 0.06
		var a1 := TAU * float(i + 1) / float(segs) - 0.06
		var col := Color(0.88, 0.78, 1.0, 0.95) if i < lit else Color(0.75, 0.62, 1.0, 0.65)
		draw_arc(centre, r_ring, a0, a1, 12, col, 5.0, true)
	if charge >= 1.0:
		# Ready: full bright face + pulsing rim in the ult tint.
		var pulse := 0.75 + 0.25 * sin(_pulse * 6.0)
		draw_circle(centre, r_out - 3.0,
			Color(tint.r, tint.g, tint.b, 0.35 + 0.2 * pulse))
		draw_arc(centre, r_out - 1.5, 0.0, TAU, 48,
			Color(tint.r, tint.g, tint.b, pulse), 3.0, true)
	else:
		# Charging: tinted sweep from the top, fraction = charge.
		if charge > 0.001:
			draw_arc(centre, r_out - 5.0, -PI / 2.0,
				-PI / 2.0 + TAU * charge, 48, tint, 5.0, true)
	if deny_t > 0.0:
		# Deny feedback window (.4 s in the bundle): red veil.
		draw_circle(centre, r_out - 3.0,
			Color(0.9, 0.2, 0.2, 0.45 * clampf(deny_t / 0.4, 0.0, 1.0)))
