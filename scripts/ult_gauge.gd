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
	var centre := size * 0.5
	var r_out := minf(size.x, size.y) * 0.5 - 1.0 - hit_pad
	# Base disc: ult purple (reference U1: purple disc +
	# white 必) with a lighter rim — the old star badge
	# texture read as an orange star and buried the glyph.
	draw_circle(centre, r_out, Color(0.55, 0.28, 0.88))
	draw_arc(centre, r_out - 1.5, 0.0, TAU, 48, Color(0.72, 0.50, 1.0), 3.0, true)
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
