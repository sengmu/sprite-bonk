extends RefCounted
## Cycle 12: the cycle-11 terrain generator (a port of the bundle's
## `of` class — see the terrain comment block in world.gd and DIFF
## cycle 11/12), extracted from world.gd VERBATIM so it can run on
## WorkerThreadPool threads: it touches no scene-tree nodes, no
## RenderingServer and no world members — inputs arrive as
## parameters, outputs stay on the instance (grid / mask_grid /
## ponds / water_level / paths + the gate scratch: lattices, path
## distance grid, simplex fields). world.gd preloads this script
## (no class_name: nothing new enters the global class cache).
## The generation math, RNG seeds and call order are unchanged from
## the in-world version; per-zone grid checksums in DIFF cycle 12
## prove the extraction is bit-identical.

const BOUND := 168.0  # == world.BOUND (play bound, world 360)
var _cfg: Dictionary = {}
var _zone_index := 1
var _altar_xz := Vector2.ZERO
var mask_bytes := PackedByteArray()
var mask_n := 0
var mask_tex: Texture2D = null  # built lazily by world (main thread)

class Simplex:
	## 2D simplex gradient noise: structural port of the bundle's td
	## class (@198044) — seeded permutation shuffle, 8 gradients,
	## fbm normalized by the amplitude sum. Output ~[-1, 1].
	var perm := PackedByteArray()
	const F2 := 0.3660254037844386
	const G2 := 0.21132486540518713
	const GX := [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 0.0, 0.0]
	const GY := [1.0, 1.0, -1.0, -1.0, 0.0, 0.0, 1.0, -1.0]

	func _init(seed_: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_
		var p := PackedByteArray()
		p.resize(256)
		for i in range(256):
			p[i] = i
		for i in range(255, 0, -1):
			var j := rng.randi_range(0, i)
			var t := p[i]
			p[i] = p[j]
			p[j] = t
		perm.resize(512)
		for i in range(512):
			perm[i] = p[i & 255]

	func getv(x: float, y: float) -> float:
		var s := (x + y) * F2
		var i := int(floorf(x + s))
		var j := int(floorf(y + s))
		var t := float(i + j) * G2
		var x0 := x - (float(i) - t)
		var y0 := y - (float(j) - t)
		var i1 := 0
		var j1 := 1
		if x0 > y0:
			i1 = 1
			j1 = 0
		var x1 := x0 - float(i1) + G2
		var y1 := y0 - float(j1) + G2
		var x2 := x0 - 1.0 + 2.0 * G2
		var y2 := y0 - 1.0 + 2.0 * G2
		var ii := i & 255
		var jj := j & 255
		var out := 0.0
		var t0 := 0.5 - x0 * x0 - y0 * y0
		if t0 >= 0.0:
			var g := perm[ii + perm[jj]] & 7
			t0 *= t0
			out += t0 * t0 * (GX[g] * x0 + GY[g] * y0)
		var t1 := 0.5 - x1 * x1 - y1 * y1
		if t1 >= 0.0:
			var g1 := perm[ii + i1 + perm[jj + j1]] & 7
			t1 *= t1
			out += t1 * t1 * (GX[g1] * x1 + GY[g1] * y1)
		var t2 := 0.5 - x2 * x2 - y2 * y2
		if t2 >= 0.0:
			var g2 := perm[ii + 1 + perm[jj + 1]] & 7
			t2 *= t2
			out += t2 * t2 * (GX[g2] * x2 + GY[g2] * y2)
		return 70.0 * out

	func fbm(x: float, y: float, oct: int) -> float:
		var sum := 0.0
		var amp := 1.0
		var norm := 0.0
		var fx := x
		var fy := y
		for o in range(oct):
			sum += amp * getv(fx, fy)
			norm += amp
			fx *= 2.0
			fy *= 2.0
			amp *= 0.5
		return sum / norm

const XD := 4.6           # terrace step height (bundle Xd)
## Per-zone layout seed rolls (cycle 11 tuning): the bundle's world
## seed is fixed but unrecoverable (their RNG stream differs), so
## ours is chosen by an openness metric around the spawn shelf —
## the original's spawn reads as an open glade, and these rolls are
## the picks from Test/probe_c11 rolls (see DIFF cycle 11).
const ZONE_SEED_ROLL := [11, 1, 2, 11]
const GRID_N := 240       # height grid res; cell = 360/240 = 1.5
const AREA_MUL := 1.6533  # (360/280)^2: the bundle's areaMul at world 360
var _grid := PackedFloat32Array()
var _mask_grid := PackedFloat32Array()
var _dist_coarse := PackedFloat32Array()  # 121x121 path distance, cell 3
var _ponds: Array = []    # {x, z, r, h, level, seed}
var _water_level := -99.0
var _levels := 4
var _carve_water := false
var _noise_a: Simplex
var _noise_b: Simplex
var _paths: Array = []    # Array of PackedVector2Array
var _massifs: Array = []  # {c: Vector2, r: float}

func _fc(e0: float, e1: float, x: float) -> float:
	# Bundle Fc (@93982): smoothstep with arbitrary edge order.
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _bilinear(arr: PackedFloat32Array, x: float, z: float, cell: float, maxi: int) -> float:
	var gx := clampf((x + 180.0) / cell, 0.0, float(maxi))
	var gz := clampf((z + 180.0) / cell, 0.0, float(maxi))
	var i0 := int(floorf(gx))
	var j0 := int(floorf(gz))
	var i1 := mini(i0 + 1, maxi)
	var j1 := mini(j0 + 1, maxi)
	var fx := gx - float(i0)
	var fz := gz - float(j0)
	var w := maxi + 1
	var a := arr[j0 * w + i0]
	var b := arr[j0 * w + i1]
	var c := arr[j1 * w + i0]
	var d := arr[j1 * w + i1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)

func _path_dist(x: float, z: float) -> float:
	return _bilinear(_dist_coarse, x, z, 3.0, 120)

func _field_h(x: float, z: float) -> float:
	# The bundle's height function f (inside generate() @238277),
	# without the pond/spawn/rim finishing _gen_terrain applies.
	var i := _noise_a.fbm(x * 0.011, z * 0.011, 4) * 0.5 + 0.5
	i += _noise_b.fbm(x * 0.03, z * 0.03, 2) * 0.04
	i = clampf(i, 0.0, 1.0)
	for m in _massifs:
		var c: Vector2 = m["c"]
		var d := Vector2(x - c.x, z - c.y).length() + _noise_b.getv(x * 0.05, z * 0.05) * 6.0
		var s := clampf((float(m["r"]) - d) / (float(m["r"]) * 0.85), 0.0, 1.0)
		i += s * ((float(_levels) + 1.35) / float(_levels) - i)
	var cc := _fc(0.25, 0.55, _noise_b.getv(x * 0.014 + 40.0, z * 0.014 - 17.0))
	var fl := i * float(_levels)
	var p := floorf(fl)
	var mm := fl - p
	var hh := 0.035 + cc * 0.4
	var g := (p + _fc(0.5 - hh, 0.5 + hh, mm)) * XD
	if _carve_water and i < 0.17:
		g -= (0.17 - i) * 18.0
	var pb := _fc(8.0, 3.0, _path_dist(x, z)) * (0.55 + 0.45 * _fc(-0.2, 0.3, _noise_b.getv(x * 0.02, z * 0.02)))
	var v := i * float(_levels) * XD
	return g * (1.0 - pb * 0.92) + v * (pb * 0.92)

var _lat_a := PackedFloat32Array()
var _lat_b := PackedFloat32Array()
var _lat_c := PackedFloat32Array()
var _lat_d := PackedFloat32Array()
var _lat_e := PackedFloat32Array()
var _lat_f := PackedFloat32Array()
var _lat_g := PackedFloat32Array()
var _lat_h := PackedFloat32Array()

func _bake_lattices() -> void:
	# The smooth noise fields are baked once onto a cell-3 lattice
	# and bilinearly sampled by _field_h_fast / the placement gates:
	# their feature wavelengths (>= ~11 u) make the upsample
	# lossless in practice, and it cuts generation from ~10 s to
	# ~2 s per zone. _field_h (exact) remains for pond trials.
	for arr in [_lat_a, _lat_b, _lat_c, _lat_d, _lat_e, _lat_f, _lat_g, _lat_h]:
		arr.resize(121 * 121)
	for j in range(121):
		for i in range(121):
			var x := -180.0 + float(i) * 3.0
			var z := -180.0 + float(j) * 3.0
			var k := j * 121 + i
			_lat_a[k] = _noise_a.fbm(x * 0.011, z * 0.011, 4)
			_lat_b[k] = _noise_b.fbm(x * 0.03, z * 0.03, 2)
			_lat_c[k] = _noise_b.getv(x * 0.014 + 40.0, z * 0.014 - 17.0)
			_lat_d[k] = _noise_b.getv(x * 0.02, z * 0.02)
			_lat_e[k] = _noise_b.getv(x * 0.05, z * 0.05)
			_lat_f[k] = _noise_b.getv(x * 0.07, z * 0.07)
			_lat_g[k] = _noise_a.getv(x * 0.05, z * 0.05)
			_lat_h[k] = _noise_a.getv(x * 0.03, z * 0.03)

func _field_h_fast(x: float, z: float) -> float:
	# _field_h with lattice-sampled noise (see _bake_lattices).
	var i := _bilinear(_lat_a, x, z, 3.0, 120) * 0.5 + 0.5
	i += _bilinear(_lat_b, x, z, 3.0, 120) * 0.04
	i = clampf(i, 0.0, 1.0)
	for m in _massifs:
		var c: Vector2 = m["c"]
		var d := Vector2(x - c.x, z - c.y).length() + _bilinear(_lat_e, x, z, 3.0, 120) * 6.0
		var s := clampf((float(m["r"]) - d) / (float(m["r"]) * 0.85), 0.0, 1.0)
		i += s * ((float(_levels) + 1.35) / float(_levels) - i)
	var cc := _fc(0.25, 0.55, _bilinear(_lat_c, x, z, 3.0, 120))
	var fl := i * float(_levels)
	var p := floorf(fl)
	var mm := fl - p
	var hh := 0.035 + cc * 0.4
	var g := (p + _fc(0.5 - hh, 0.5 + hh, mm)) * XD
	if _carve_water and i < 0.17:
		g -= (0.17 - i) * 18.0
	var pb := _fc(8.0, 3.0, _path_dist(x, z)) * (0.55 + 0.45 * _fc(-0.2, 0.3, _bilinear(_lat_d, x, z, 3.0, 120)))
	var v := i * float(_levels) * XD
	return g * (1.0 - pb * 0.92) + v * (pb * 0.92)

func generate(zone_cfg: Dictionary, zone_index: int, roll: int, altar_xz: Vector2) -> void:
	var t0 := Time.get_ticks_msec()
	_cfg = zone_cfg
	_zone_index = zone_index
	_altar_xz = altar_xz
	var zc: Dictionary = zone_cfg
	_levels = int(zc["levels"])
	_carve_water = String(zc["water"]) == "plane" or String(zc["water"]) == "lava"
	var seed_base: int = 5000 + _zone_index * 131 + roll * 104729
	_noise_a = Simplex.new(seed_base)
	_noise_b = Simplex.new(seed_base ^ 1540483477)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base
	# Path network: 4-6 random walks out of the origin.
	_paths.clear()
	var nwalks := 4 + rng.randi_range(0, 2)
	var steps := int(round(BOUND / 13.0))
	for t in range(nwalks):
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		var ang := float(t) / float(nwalks) * TAU + rng.randf_range(-0.4, 0.4)
		var px := 0.0
		var pz := 0.0
		for s in range(steps):
			ang += rng.randf_range(-0.55, 0.55)
			px += cos(ang) * 15.0
			pz += sin(ang) * 15.0
			pts.append(Vector2(px, pz))
		_paths.append(pts)
	# Massifs (forest relief): plateau discs whose spiral outlines
	# join the path set (rim smoothing), as in the bundle.
	_massifs.clear()
	var want := int(zc["massifs"])
	var guard := 0
	while _massifs.size() < want and guard < 80:
		guard += 1
		var a := rng.randf() * TAU
		var rad := rng.randf_range(0.4, 0.68) * BOUND
		var r := rng.randf_range(44.0, 50.0)
		var c := Vector2(cos(a) * rad, sin(a) * rad)
		if c.length() < r + 22.0:
			continue
		var ok := true
		for m in _massifs:
			if c.distance_to(m["c"]) < float(m["r"]) + r + 30.0:
				ok = false
				break
		if not ok:
			continue
		_massifs.append({"c": c, "r": r})
		var spiral := PackedVector2Array()
		var u := rng.randf() * TAU
		var d := 1.0 if rng.randf() < 0.5 else -1.0
		for k in range(23):
			var f := float(k) / 22.0
			var th := u + d * f * TAU * 2.3
			var rr := r * (1.12 - f * 0.95)
			spiral.append(c + Vector2(cos(th) * rr, sin(th) * rr))
		_paths.append(spiral)
	# Coarse path-distance grid (cell 3) feeding _field_h and gates.
	_dist_coarse = PackedFloat32Array()
	_dist_coarse.resize(121 * 121)
	for j in range(121):
		for i in range(121):
			var x := -180.0 + float(i) * 3.0
			var z := -180.0 + float(j) * 3.0
			var best2 := 1.0e12
			for line in _paths:
				for s in range(line.size() - 1):
					var a: Vector2 = line[s]
					var b: Vector2 = line[s + 1]
					var abx := b.x - a.x
					var abz := b.y - a.y
					var tt := 0.0
					var len2 := abx * abx + abz * abz
					if len2 > 0.0001:
						tt = clampf(((x - a.x) * abx + (z - a.y) * abz) / len2, 0.0, 1.0)
					var ddx := x - (a.x + abx * tt)
					var ddz := z - (a.y + abz * tt)
					var d2 := ddx * ddx + ddz * ddz
					if d2 < best2:
						best2 = d2
			_dist_coarse[j * 121 + i] = sqrt(best2)
	_bake_lattices()
	# Water plan: shared plane for no-relief water biomes; ponds for
	# the forest (planPonds @246400).
	_ponds.clear()
	var wmode := String(zc["water"])
	_water_level = -99.0
	if _carve_water:
		_water_level = 0.17 * float(_levels) * XD - 0.9
	if wmode == "ponds":
		var target := int(round(6.0 * sqrt(AREA_MUL))) + rng.randi_range(0, 1)
		var tries := 0
		while _ponds.size() < target and tries < 800:
			tries += 1
			var r := rng.randf_range(6.0, 11.0)
			var cx := rng.randf_range(-BOUND + r + 12.0, BOUND - r - 12.0)
			var cz := rng.randf_range(-BOUND + r + 12.0, BOUND - r - 12.0)
			if Vector2(cx, cz).length() < 26.0 + r:
				continue
			var bad := false
			for m in _massifs:
				if Vector2(cx, cz).distance_to(m["c"]) < float(m["r"]) + r + 8.0:
					bad = true
					break
			if not bad:
				for pn in _ponds:
					if Vector2(cx, cz).distance_to(Vector2(pn["x"], pn["z"])) < float(pn["r"]) + r + 30.0:
						bad = true
						break
			if bad:
				continue
			var ah0 := _field_h(cx, cz)
			var o := roundf(ah0 / XD) * XD
			if o < XD * 0.5 or absf(ah0 - o) > 0.4:
				continue
			var off := 0
			for k in range(12):
				var th := float(k) / 12.0 * TAU
				if absf(_field_h(cx + cos(th) * (r + 3.0), cz + sin(th) * (r + 3.0)) - o) > 1.0:
					off += 1
			if off > 2:
				continue
			_ponds.append({"x": cx, "z": cz, "r": r, "h": o,
				"level": o - 0.3, "seed": rng.randf_range(0.0, 100.0)})
	# Height grid + path mask.
	var n := GRID_N + 1
	_grid = PackedFloat32Array()
	_grid.resize(n * n)
	_mask_grid = PackedFloat32Array()
	_mask_grid.resize(n * n)
	var cell := 360.0 / float(GRID_N)
	for j in range(n):
		for i in range(n):
			var x := -180.0 + float(i) * cell
			var z := -180.0 + float(j) * cell
			var o := _field_h_fast(x, z)
			for pn in _ponds:
				var dx := x - float(pn["x"])
				var dz := z - float(pn["z"])
				var s := sqrt(dx * dx + dz * dz)
				var pr := float(pn["r"])
				if s > pr + 7.0:
					continue
				var ang := atan2(dz, dx)
				var wob := pr * (0.82 + 0.3 * _noise_b.getv(cos(ang) * 1.2 + float(pn["seed"]), sin(ang) * 1.2 - float(pn["seed"])))
				o = lerpf(o, float(pn["h"]), _fc(pr + 7.0, pr + 3.0, s))
				if s < wob:
					o = minf(o, float(pn["level"]) - 0.06 - 0.39 * _fc(wob, wob - 3.2, s))
			o = lerpf(o, XD, _fc(18.0, 9.0, Vector2(x, z).length()))
			o += _bilinear(_lat_f, x, z, 3.0, 120) * 0.12
			o += _fc(BOUND - 4.0, BOUND + 10.0, maxf(absf(x), absf(z))) * (18.0 + _bilinear(_lat_g, x, z, 3.0, 120) * 8.0)
			_grid[j * n + i] = o
			# Path mask: full within 2 u of a centreline, gone by
			# 5 u (the bundle's grid fill for pathMask was not in the
			# extracted window; this width matches the dirt ribbons
			# in the original's frames — see DIFF cycle 11).
			_mask_grid[j * n + i] = _fc(5.0, 2.0, _path_dist(x, z))
	# Altar clearing (kept gameplay constant): blend toward the
	# centre height inside r 11, before the smoothing pass.
	var ah := _bilinear(_grid, _altar_xz.x, _altar_xz.y, cell, GRID_N)
	for j in range(n):
		for i in range(n):
			var x := -180.0 + float(i) * cell
			var z := -180.0 + float(j) * cell
			var d := Vector2(x - _altar_xz.x, z - _altar_xz.y).length()
			if d < 11.0:
				var t := clampf((d - 5.5) / 5.5, 0.0, 1.0)
				t = t * t * (3.0 - 2.0 * t)
				_grid[j * n + i] = lerpf(ah, _grid[j * n + i], t)
	# One 3x3 smoothing pass (weights 4/2/1 over 16), as the bundle.
	var src := _grid.duplicate()
	for j in range(1, GRID_N):
		for i in range(1, GRID_N):
			var sum := src[j * n + i] * 4.0
			sum += (src[j * n + i - 1] + src[j * n + i + 1] + src[(j - 1) * n + i] + src[(j + 1) * n + i]) * 2.0
			sum += src[(j - 1) * n + i - 1] + src[(j - 1) * n + i + 1] + src[(j + 1) * n + i - 1] + src[(j + 1) * n + i + 1]
			_grid[j * n + i] = sum / 16.0
	# Path mask texture for the terrain shader.
	var bytes := PackedByteArray()
	bytes.resize(n * n)
	for k in range(n * n):
		bytes[k] = int(clampf(_mask_grid[k], 0.0, 1.0) * 255.0)
	mask_bytes = bytes
	mask_n = n
	print("C11 terrain gen zone ", _zone_index, ": ", Time.get_ticks_msec() - t0, " ms, ponds ", _ponds.size(), ", paths ", _paths.size())

