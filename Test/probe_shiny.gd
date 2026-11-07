extends Node
## Cycle 21.1 adjudication probe (temporary, kept for the
## record): is the c20 hue check's pidgey failure a game
## bug or a palette-sensitive estimator? For each species
## texture, rotate the NORMAL texture through the
## production operator (ModelRig._hue_rotate_texture at
## the species' own zl) and measure the circular-mean hue
## delta with the harness estimator copied verbatim
## (_c20_tex_hue_delta). If the simulated delta for
## pidgey lands at the in-suite reading (0.618) instead
## of zl (0.718), the operator + palette fully explain
## the reading and the game is correct; the check's
## fixed 0.05 tolerance against zl is what is wrong for
## narrow palettes.

func _tex_hue_delta(ta: Texture2D, tb: Texture2D) -> float:
	var ia := ta.get_image()
	var ib := tb.get_image()
	if ia == null or ib == null:
		return -1.0
	if ia.is_compressed():
		ia.decompress()
	if ib.is_compressed():
		ib.decompress()
	ia.convert(Image.FORMAT_RGBA8)
	ib.convert(Image.FORMAT_RGBA8)
	var va := Vector2.ZERO
	var vb := Vector2.ZERO
	var w := mini(ia.get_width(), ib.get_width())
	var h := mini(ia.get_height(), ib.get_height())
	for y in range(0, h, 5):
		for x in range(0, w, 5):
			var ca := ia.get_pixel(x, y)
			var cb := ib.get_pixel(x, y)
			if ca.s > 0.15 and ca.v > 0.12 and ca.v < 0.98:
				va += Vector2(cos(ca.h * TAU), sin(ca.h * TAU)) * ca.s
			if cb.s > 0.15 and cb.v > 0.12 and cb.v < 0.98:
				vb += Vector2(cos(cb.h * TAU), sin(cb.h * TAU)) * cb.s
	if va.length() < 0.001 or vb.length() < 0.001:
		return -1.0
	return fposmod(atan2(vb.y, vb.x) / TAU - atan2(va.y, va.x) / TAU, 1.0)

func _ready() -> void:
	var cases := [
		["pidgey", 16, "res://assets/models/pidgey_pm0016_00_Body1.png"],
		["pidgey", 16, "res://assets/models/pidgey_pm0016_00_Eye1.png"],
		["sandshrew", 27, "res://assets/models/sandshrew_pm0027_00_BodyA1.png"],
		["sandshrew", 27, "res://assets/models/sandshrew_pm0027_00_BodyB1.png"],
		["sandshrew", 27, "res://assets/models/sandshrew_pm0027_00_Eye1.png"],
	]
	for c in cases:
		var sp := String(c[0])
		var dex := int(c[1])
		var path := String(c[2])
		var tex := load(path) as Texture2D
		if tex == null:
			print("SHINYPROBE ", sp, " ", path.get_file(), " LOAD_FAIL")
			continue
		var zl := ModelRig.shiny_hue_shift(dex)
		var rot: Texture2D = ModelRig._hue_rotate_texture(tex, zl)
		var dh := _tex_hue_delta(tex, rot)
		print("SHINYPROBE ", sp, " dex=", dex, " tex=", path.get_file(),
			" zl=", zl, " dh_sim=", dh, " err=", absf(dh - zl))
	print("SHINYPROBE DONE")
	get_tree().quit()
