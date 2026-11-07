extends Node
## UI-overlap audit captures (cycle 21 follow-up, 2026-10-27).
## The user reports HUD overlaps on his real Seeker while the
## phonehud geometry gate passes. This harness drives the
## CURRENT build into the states where the C21 UI lives, at
## phone-class windows, with the touch layer FORCED ON (the
## world's _touch_forced seam — on the gate the layer never
## renders, so the right-hand action-button column has never
## been in a checked or captured frame), and saves full-screen
## PNGs for eyeball audit. Capture-only: it changes no game
## or layout code; states are reached through the same public
## drive functions the harness/uishot use.
##
## Args: --win=2400x1080 (window; viewport follows stretch)
##       --scale=1.00    (pin profile touchScale; omit = resident)
##       --tag=<suffix>  (output filename suffix)
##       --states=a,b    (subset of: settings,loadout,hud,
##                        chest,shop,boss,pause; default all)
## Output: Test/out/ui_audit_c21/<state>_<tag>.png
## Profile discipline copied from phonehud.gd: load BEFORE
## the snapshot, restore at the end — the resident profile is
## left byte-identical.

var _world: Node
var _tag := "run"
var _scale := -1.0
var _win := Vector2i(2400, 1080)
var _states: Array = []
var _snaps := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
		elif a.begins_with("--scale="):
			_scale = float(a.trim_prefix("--scale="))
		elif a.begins_with("--win="):
			var parts := a.trim_prefix("--win=").split("x")
			if parts.size() == 2:
				_win = Vector2i(int(parts[0]), int(parts[1]))
		elif a.begins_with("--states="):
			_states = a.trim_prefix("--states=").split(",")
	_run()

func _want(state: String) -> bool:
	return _states.is_empty() or _states.has(state)

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _snap(name: String) -> void:
	# Same capture discipline as uishot/phonehud: two render
	# frames + the post-draw signal, so the PNG is the live
	# screen, not a stale llvmpipe frame.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "res://Test/out/ui_audit_c21/" + name + "_" + _tag + ".png"
	img.save_png(path)
	_snaps += 1
	print("UIAUDIT snap ", name, " -> ", path, " size=", img.get_size())

func _prop_of_kind(kind: String) -> Dictionary:
	var st: Dictionary = _world.get("_inter_state")
	var zd: Dictionary = st.get(int(_world.get("zone")), {})
	for p in zd.get("props", []):
		if String(p["kind"]) == kind and not bool(p["used"]):
			return p
	return {}

func _teleport_near(p: Dictionary, off: float) -> void:
	var x := float(p["x"]) - off
	var z := float(p["z"])
	var pl = _world.get("player")
	pl.global_position = Vector3(x, float(_world.call("height_at", x, z)) + 0.1, z)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://Test/out/ui_audit_c21")
	Profile.load_profile()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(Profile.data))
	if _scale > 0.0:
		Profile.set_setting("touchScale", _scale)
	get_window().size = _win
	await _frames(8)
	var ps: PackedScene = load("res://scenes/main.tscn")
	_world = ps.instantiate()
	# The production _phone_factor() value for the Seeker-class
	# panel (2400x1080 @ ~420 dpi -> css_h 411 -> 1.925). Fed
	# through the debug seam for every pass: the window size
	# reproduces the capture/screenshot pixel space, the factor
	# stays the physical panel's value.
	var css_h := 1080.0 / (420.0 / 160.0)
	_world.set("debug_phone_factor", clampf((720.0 / css_h) * 1.1, 1.0, 2.0))
	# The device truth the gate never renders: touch layer up.
	_world.set("_touch_forced", true)
	add_child(_world)
	await _frames(45)
	var vp := get_viewport().get_visible_rect().size
	var tc0: Object = _world.get("touch_controls")
	print("UIAUDIT boot vp=", vp, " win=", _win,
		" factor=", _world.call("_phone_factor"),
		" touchScale=", Profile.setting("touchScale"),
		" scale_s=", (tc0.get("_scale_s") if tc0 else "?"))
	# ---- menu-context screens --------------------------------
	if _want("settings"):
		_world._open_settings()
		_world._settings_show_tab("hud")
		await _frames(10)
		await _snap("settings_hud")
		_world._close_settings()
		await _frames(4)
	if _want("loadout"):
		_world._open_loadout("bulbasaur")
		await _frames(8)
		await _snap("loadout")
	# ---- start the run (the loadout's real start path) -------
	_world._open_loadout("bulbasaur")
	await _frames(6)
	_world._loadout_start()
	var p = null
	for i in range(900):
		await get_tree().physics_frame
		p = _world.get("player")
		if p != null and p.get("rig") != null and bool(p.get("rig").get("fitted")):
			break
	if p == null:
		print("UIAUDIT FAIL no fitted player")
		_finish(snap)
		return
	p.invulnerable = true
	await _frames(30)
	# ---- state 1: in-run HUD, stage banner + populated ------
	if _want("hud"):
		_world._refresh_goal_card()
		await _frames(6)
		await _snap("hud_start")
		_world.call("_spawn_alpha")
		for i in range(600):
			await get_tree().physics_frame
			var bars: Array = _world.get("_mini_bars")
			if bars.size() > 0 and bool((bars[0]["panel"] as Control).visible):
				break
		await _frames(10)
		await _snap("hud_alpha")
	# ---- state 2+3: paid chest -------------------------------
	var chest := _prop_of_kind("chest")
	if _want("chest"):
		if chest.is_empty():
			print("UIAUDIT MISS no chest prop in zone")
		else:
			_teleport_near(chest, 2.0)
			await _frames(30)
			print("UIAUDIT chest prompt=", String(_world.get("_prompt").text),
				" gold=", _world.get("gold"), " cost=", _world.call("_chest_cost"))
			await _snap("chest_nofunds")
			_world.set("gold", 500.0)
			_world._interact_prop(chest)
			await _frames(45)
			print("UIAUDIT pick3 choice_open=", _world.get("_choice_open"))
			await _snap("chest_pick3")
			_world._choice_pick(0)
			await _frames(15)
			# Single-card take-or-sell modal: the same call the
			# free-chest interact path makes.
			_world._chest_roll_single(1)
			await _frames(45)
			print("UIAUDIT single choice_open=", _world.get("_choice_open"))
			await _snap("chest_single")
			_world._choice_pick(0)
			await _frames(12)
	# ---- state 4: meowth shop --------------------------------
	if _want("shop"):
		var meo := _prop_of_kind("meowth")
		if meo.is_empty():
			print("UIAUDIT MISS no meowth prop in zone")
		else:
			_teleport_near(meo, 2.0)
			await _frames(30)
			print("UIAUDIT meowth prompt=", String(_world.get("_prompt").text))
			await _snap("meowth_prompt")
			_world._interact_prop(meo)
			await _frames(20)
			print("UIAUDIT shop_open=", _world.get("_shop_open"))
			await _snap("meowth_shop")
			_world._shop_close()
			await _frames(6)
	# ---- state 5: boss bar with phase ticks ------------------
	if _want("boss"):
		# Zone 1's draw can land on nidoking (no kit -> ticks
		# hidden BY DESIGN). Zone 3's trio (sandslash /
		# marowak / dragonite) are all modelled and all carry
		# signature kits, so the summon there always shows
		# the ticks. The summon itself is the real one.
		_world.set("zone", 3)
		_world.summon_guardian()
		await _frames(30)
		var g = _world.get("guardian")
		print("UIAUDIT guardian=", (g.species_id if g else "null"),
			" state=", _world.get("state"))
		if g != null:
			p.global_position = g.global_position + Vector3(9, 0, 9)
		await _frames(30)
		var ticks: Array = _world.get("_boss_ticks")
		var tv := []
		for t in ticks:
			tv.append((t as Control).visible)
		print("UIAUDIT boss_card=", (_world.get("_boss_card") as Control).visible,
			" ticks=", tv)
		await _snap("boss")
	# ---- state 6: pause tabs ---------------------------------
	if _want("pause"):
		_world._open_pause()
		await _frames(10)
		await _snap("pause_moves")
		_world._pause_show_tab(2)
		await _frames(8)
		await _snap("pause_settings")
		_world._close_pause()
		await _frames(4)
	_finish(snap)

func _finish(snap: Dictionary) -> void:
	Profile.data = snap
	Profile.save_profile()
	print("UIAUDIT DONE snaps=", _snaps)
	get_tree().quit()
