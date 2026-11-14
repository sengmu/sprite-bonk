extends Node
## Phone-resolution HUD gate. Cycle 19 hotfix origin:
## boots the real world at phone-class windows with the
## phone UI factor and asserts the HUD clusters' VISUAL
## rects stay inside the viewport and never intersect.
##
## Cycle 21.3 HARDENING (official Claude UI audit §4 —
## the C21 build shipped with device overlaps this gate
## passed, because the gate never rendered the touch
## layer, never paired the banner / prompt / boss card /
## mini bars / pill stack against each other or the
## touch cluster, never simulated safe-area insets, and
## measured the top card without its wallet pill):
##  * the touch layer is FORCED ON (_touch_forced) — the
##    device truth; every touch element is asserted
##    against every readable HUD element;
##  * _vis_rect_deep: union of visible descendants'
##    visual rects (top card incl. wallet, goal card);
##  * six driven states per run: hud_start (banner up),
##    hud_alpha, chest prompt (gold=0), meowth prompt,
##    boss + alpha + banner, and the pause/shop/choice
##    modals (touch hidden, scrim covers the viewport);
##  * --inset=L,T,R,B feeds the world's
##    debug_safe_insets seam (audit F6);
##  * matrix (check_phonehud.sh): windows 2400x1080 /
##    2340x1080 / 1920x1080 x touchScale {0.70, 0.85,
##    1.00, 1.50} x insets {0, left 48, right 48}, plus
##    the 1280x720 desktop baseline (legacy pins kept).
##    On desktop the banner keeps its shipped centred
##    offsets by the audit's own F3 ruling, so the
##    banner x boss pair and the span assertion are
##    phone-only; every other assertion runs in both.
## Cycle 21.3.1 (re-audit N1/N2): the prompt's asserted
## rect now includes its ink-glass backing (_prompt_rect),
## and prompt states assert the F5c 2-line fit wherever
## the game's span-aware cap is engaged (get_line_count
## <= max_lines_visible = 2); at spans too narrow for 2
## legible lines the cap lifts and the column's drawn
## height is bounded instead.
## UI-mobile P1 (design/ui-mobile-plan-v1.md §B4 P1):
## "P1: ..." assertions are ADDED alongside every kept
## assertion above (none of which changed) — touch
## wording, the interact button's three states, the
## touch ult glyph, the banner queue, the pause status
## page / quick settings / quit confirm, and the two-
## thumb camera (simulated through Input.parse_input_event
## so the real GUI routing decides who owns each touch).
## The desktop variant runs the text assertions INVERTED
## with the touch latch released (keyboard wording kept).
## P1 captures land flat as Test/out/mobile_p1_<state>_
## <tag>.png for the two plan combos only.
## UI-mobile P2 (§B4 P2): "P2: ..." assertions added the
## same way (kept ones untouched) — see the P2 section at
## the end; captures mobile_p2_<state>_<tag>.png.
## UI-mobile P3 (§B4 P3 + the P2-closure rulings): "P3: ..."
## assertions — objective pill + drawer (D4), portrait pause
## (D1), aim out of the HUD (D2), lock in the pause menu
## (U1 round 10 — no lock button on the HUD anymore), hit areas
## >= 70, I3 press feedback, side-by-side mini bars, cut-in in
## the centre stack; --layout=classic runs the D6 classic
## layout (21.3.2 geometry) and --hud= / --mm= pin hudScale /
## minimapScale for the plan-P7 corner variants. Captures
## mobile_p3_<state>_<tag>.png. See the P3 section at the end.
## UI-mobile P4 (§B4 P4): "P4: ..." assertions — the BL two-row
## slots (moves + vitamins, parity with the pause status page),
## Z7 vs the joystick ring, the interaction bubble (Z6) between
## the BL rows and the thumb cluster. Two kept BL assertions
## take Z7's top as their subject on a P4 tree (see
## _p4_slots_top); captures mobile_p4_<state>_<tag>.png.
## UI-mobile P5 (§B4 P5 + §B3): "P5: ..." assertions — the modal
## family (M0 scale, text / button floors, primary bottom-right,
## close paths, banner freeze per modal, loadout tiles) and the
## main menu design Control; menu + overlays at boot, the loadout
## at its boot open, the in-run modals in a closing block (results
## last). Captures mobile_p5_<state>_<tag>.png.
## Run via Test/check_phonehud.sh. NOT in the export.

var _world: Node
var _mode := "phone"
var _touch_scale := -1.0  # cycle 20.2: --scale= pins touchScale (sweep)
var _win := Vector2i(2400, 1080)
var _inset := Vector4.ZERO
var _fails := 0
var _checks := 0
var _hud := -1.0       # UI-mobile P3: --hud= pins hudScale (P7 corners)
var _mm := -1.0        # --mm= pins minimapScale
var _classic := false  # --layout=classic (D6)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")
		elif a.begins_with("--scale="):
			_touch_scale = float(a.trim_prefix("--scale="))
		elif a.begins_with("--win="):
			var parts := a.trim_prefix("--win=").split("x")
			if parts.size() == 2:
				_win = Vector2i(int(parts[0]), int(parts[1]))
		elif a.begins_with("--inset="):
			var ip := a.trim_prefix("--inset=").split(",")
			if ip.size() == 4:
				_inset = Vector4(float(ip[0]), float(ip[1]),
					float(ip[2]), float(ip[3]))
		elif a.begins_with("--hud="):
			_hud = float(a.trim_prefix("--hud="))
		elif a.begins_with("--mm="):
			_mm = float(a.trim_prefix("--mm="))
		elif a.begins_with("--layout="):
			_classic = a.trim_prefix("--layout=") == "classic"
	_run()

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _check(name: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("PHONEHUD PASS ", name, " :: ", detail)
	else:
		_fails += 1
		print("PHONEHUD FAIL ", name, " :: ", detail)

## The node's on-screen rect: its local rect pushed
## through the global transform (scale included), as an
## axis-aligned box. This is what the player's eye sees.
func _vis_rect(c: Control) -> Rect2:
	if c == null:
		return Rect2()
	var t := c.get_global_transform()
	var r := Rect2(Vector2.ZERO, c.size)
	var pts := [t * r.position, t * Vector2(r.end.x, r.position.y),
		t * r.end, t * Vector2(r.position.x, r.end.y)]
	var out := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		out = out.expand(p)
	return out

## Audit §4: the union of the visible descendants'
## visual rects (the top card's wallet pill overhangs
## the card's own rect; the plain rect misses it).
func _vis_rect_deep(c: Control) -> Rect2:
	if c == null:
		return Rect2()
	var out := Rect2()
	var have := false
	var stack: Array = [c]
	while not stack.is_empty():
		var n: Control = stack.pop_back()
		if n == null or not n.is_visible_in_tree():
			continue
		if n.size.x > 0.0 and n.size.y > 0.0:
			var r := _vis_rect(n)
			if not have:
				out = r
				have = true
			else:
				out = out.merge(r)
		for ch in n.get_children():
			if ch is Control:
				stack.append(ch)
	return out

## Cycle 21.3.1 (re-audit N2): the prompt's asserted
## footprint is label + ink-glass backing. The backing
## extends 8 x pscale past the label on each side and
## 6 x pscale top/bottom (offsets in _layout_prompt)
## and passed within
## 1-2 px of the lock button in the
## meowth_prompt_2048x920_s085_fixed capture while the
## gate asserted only the label's rect.
func _prompt_rect() -> Rect2:
	var prompt := _world.get("_prompt") as Control
	var r := _vis_rect(prompt)
	var back := _world.get("_prompt_back") as Control
	if back != null and back.is_visible_in_tree():
		r = r.merge(_vis_rect(back))
	return r

func _disjoint(a: Rect2, b: Rect2) -> bool:
	return not a.grow(-1.0).intersects(b.grow(-1.0))

func _inside(r: Rect2, outer: Rect2) -> bool:
	return r.position.x >= outer.position.x - 1.0 \
		and r.position.y >= outer.position.y - 1.0 \
		and r.end.x <= outer.end.x + 1.0 \
		and r.end.y <= outer.end.y + 1.0

func _snap(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://Test/out/" + name + ".png")
	print("PHONEHUD snap ", name)

func _run_tag() -> String:
	var ts := "s100"
	if _touch_scale > 0.0:
		ts = "s" + str(int(round(_touch_scale * 100.0))).pad_zeros(3)
	var ins := "i0"
	if _inset != Vector4.ZERO:
		ins = "i%d_%d_%d_%d" % [int(_inset.x), int(_inset.y),
			int(_inset.z), int(_inset.w)]
	var tag := "%dx%d_%s_%s" % [_win.x, _win.y, ts, ins]
	# UI-mobile P3: the P7 corners / classic layout carry
	# their own suffix (never collide with the plan combos).
	if _hud > 0.0:
		tag += "_h" + str(int(round(_hud * 100.0))).pad_zeros(3)
	if _mm > 0.0:
		tag += "_m" + str(int(round(_mm * 100.0))).pad_zeros(3)
	if _classic:
		tag += "_classic"
	return tag

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

## The touch layer's assertable elements: the six
## buttons, the cluster ult gauge, the joystick ring.
func _touch_elems() -> Array:
	var out: Array = []
	var tc: Object = _world.get("touch_controls")
	if tc == null or not (tc as Control).visible:
		return out
	var btns: Dictionary = tc.get("_buttons")
	for kind in btns.keys():
		# UI-mobile P3: a hidden button (pause / aim leave the
		# new layout's cluster) cannot overlap anything.
		var ar := (btns[kind] as Dictionary)["area"] as Control
		if ar.visible:
			out.append(["tc_" + String(kind), ar])
	out.append(["tc_ult", tc.get("ult_gauge") as Control])
	out.append(["tc_ring", tc.get("_base_ring") as Control])
	return out

func _visible_bars() -> Array:
	var out: Array = []
	for bar in (_world.get("_mini_bars") as Array):
		var mp := (bar as Dictionary)["panel"] as Control
		if mp != null and mp.is_visible_in_tree():
			out.append(mp)
	return out

func _banner_up() -> bool:
	var bb := _world.get("_banner_back") as Control
	return bb != null and bb.is_visible_in_tree() and bb.modulate.a > 0.5 \
		and float(_world.get("_banner_t")) > 0.0

func _run() -> void:
	# Cycle 20.2: load BEFORE the snapshot (a pre-load
	# snapshot restores {} and WIPES the resident).
	GameProfile.load_profile()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	if _touch_scale > 0.0:
		GameProfile.set_setting("touchScale", _touch_scale)
	# UI-mobile P3: P7 corner / classic pins (the snapshot
	# taken above restores the resident's own values).
	GameProfile.set_setting("hudScale", _hud if _hud > 0.0 else 1.0)
	GameProfile.set_setting("minimapScale", _mm if _mm > 0.0 else 1.0)
	GameProfile.set_setting("classicLayout", _classic)
	var win := _win
	var factor := -1.0
	if _mode == "phone":
		# The _phone_factor() formula for the Seeker-class
		# panel, held constant across the matrix windows
		# (audit §4: 1920x1080 is "16:9 phone, factor
		# 1.925").
		var css_h := 1080.0 / (420.0 / 160.0)
		factor = clampf((720.0 / css_h) * 1.1, 1.0, 2.0)
	else:
		win = Vector2i(1280, 720)
	get_window().size = win
	await _frames(8)
	var ps: PackedScene = load("res://scenes/main.tscn")
	_world = ps.instantiate()
	if factor >= 0.0:
		_world.set("debug_phone_factor", factor)
	_world.set("debug_safe_insets", _inset)
	# Audit §4 setup: the device truth the old gate never
	# rendered — the touch layer is up in every run state.
	_world.set("_touch_forced", true)
	add_child(_world)
	await _frames(45)
	var vp := get_viewport().get_visible_rect().size
	print("PHONEHUD mode=", _mode, " viewport=", vp, " win=", win,
		" factor=", factor, " inset=", _inset,
		" kr=", _world.call("_kr"))
	# UI-mobile P5: the main menu + its overlays at boot.
	await _p5_menu_block(vp)
	_world._open_loadout("bulbasaur")
	await _frames(8)
	await _p5_loadout(vp)
	_world._loadout_start()
	var p = null
	for i in range(900):
		await get_tree().physics_frame
		p = _world.get("player")
		if p != null and p.get("rig") != null and bool(p.get("rig").get("fitted")):
			break
	if p == null:
		_check("run boots with a fitted player", false)
		_finish(snap)
		return
	p.invulnerable = true
	await _frames(30)
	var tc0: Object = _world.get("touch_controls")
	print("PHONEHUD scale dump touchScale=", GameProfile.setting("touchScale"),
		" scale_s=", (tc0.get("_scale_s") if tc0 else -1),
		" tc_visible=", (tc0.get("visible") if tc0 else false))
	# ---- state 1: hud_start, banner up -------------------
	# The stage banner is pinned through the game's own
	# public API (the run start shows it for 4 s of wall
	# time, which a slow host can burn before the first
	# assertion — geometry is what's being gated).
	_world._refresh_goal_card()
	_world.show_banner("第一关 · 青苔林 — 去北边的祭坛召唤守护者！", 600.0)
	await _frames(6)
	_assert_state(vp, "hud_start", false)
	await _snap("phone_hud_touch_" + _run_tag() + "_hudstart")
	_p1_hud_start()
	await _p1_snap("hud_start")
	await _p2_snap("hud_start")
	await _p3_snap("hud_start")
	await _p4_snap("hud_start")
	# ---- state 2: hud_alpha ------------------------------
	_world.call("_spawn_alpha")
	await _wait_bar()
	await _frames(10)
	_assert_state(vp, "hud_alpha", false)
	await _p2_snap("hud_alpha")
	await _p1_alpha_banner()
	# ---- state 3: chest prompt (gold = 0, long string) ---
	var chest := _prop_of_kind("chest")
	if not chest.is_empty():
		_teleport_near(chest, 2.0)
		await _frames(30)
		_check("chest prompt shown", String(_world.get("_prompt").text) != "",
			String(_world.get("_prompt").text))
		_assert_state(vp, "chest_prompt", true)
		_p1_prompt_verb("chest")
		_p1_interact_mode("chest", true)
		await _p1_snap("chest_prompt_gold0")
		# U1 1:1 round 7: capture-only 2340 chest shot — the
		# interact button is READY here (solid orange disc),
		# the state-matched对照 for the idle faint circle in
		# the hud_start compare (same pattern as that snap).
		await _snap("phone_hud_touch_" + _run_tag() + "_chest")
		await _p2_snap("chest_prompt")
		await _p4_snap("chest_prompt")
		await _p1_paid_chest()
	else:
		_check("chest prop present for the prompt state", false)
	# ---- state 4: meowth prompt --------------------------
	var meo := _prop_of_kind("meowth")
	if not meo.is_empty():
		_teleport_near(meo, 2.0)
		await _frames(30)
		_check("meowth prompt shown", String(_world.get("_prompt").text) != "",
			String(_world.get("_prompt").text))
		_assert_state(vp, "meowth_prompt", true)
		_p1_prompt_verb("meowth")
		await _p1_snap("meowth_prompt")
		await _p4_snap("meowth_prompt")
		await _p1_desktop_prompt("meowth")
		# ---- modal: shop ---------------------------------
		_world._interact_prop(meo)
		await _frames(20)
		_assert_modal(vp, "shop")
		_world._shop_close()
		await _frames(6)
	else:
		_check("meowth prop present for the prompt state", false)
	# ---- P1: altar prompt (summon wording) ---------------
	await _p1_altar()
	# ---- state 5: boss + alpha + banner ------------------
	_world.set("zone", 3)
	_world.summon_guardian()
	await _frames(30)
	var g = _world.get("guardian")
	if g != null:
		p.global_position = g.global_position + Vector3(9, 0, 9)
	await _frames(30)
	if _visible_bars().is_empty():
		_world.call("_spawn_alpha")
		await _wait_bar()
		await _frames(6)
	if not _banner_up():
		_world.show_banner("守护者现身了！", 600.0)
		await _frames(4)
	_check("boss state: guardian summoned", g != null)
	_check("boss state: boss card visible",
		(_world.get("_boss_card") as Control).is_visible_in_tree())
	_check("boss state: banner up", _banner_up())
	_assert_state(vp, "boss", false)
	# U1 1:1 round 5: the boss card fades (by design) while the
	# guardian's body overlaps the header — for the card shot,
	# step the guardian aside AFTER the assertions so the card
	# renders at full alpha (a reachable play state: the player
	# far from the guardian). The fight itself is untouched.
	if g != null:
		g.global_position += Vector3(60, 0, 0)
		await _frames(6)
	await _snap("phone_hud_touch_" + _run_tag())
	await _p2_snap("boss")
	await _p3_snap("boss")
	if _p3_new():
		await _p3_boss(vp)
	# ---- modal: pause ------------------------------------
	_world._open_pause()
	await _frames(10)
	_assert_modal(vp, "pause")
	if _mode == "phone" and not _classic:
		_p2_parity()
	_world._close_pause()
	await _frames(4)
	# ---- modal: choice (paid chest roll) -----------------
	if not chest.is_empty():
		_world.set("gold", 500.0)
		_teleport_near(chest, 2.0)
		await _frames(10)
		_world._interact_prop(chest)
		await _frames(45)
		_assert_modal(vp, "choice")
		if bool(_world.get("_choice_open")):
			_world._choice_pick(0)
			await _frames(12)
	# ---- UI-mobile P1 block (after every kept state) -----
	if _mode == "phone" and not _classic:
		await _p1_phone_block(vp)
		await _p2_phone_block(vp)
		await _p3_phone_block(vp)
		await _p4_phone_block(vp)
		await _p5_run_block(vp)
	elif _mode == "phone":
		await _p1_phone_block(vp)
		await _p3_classic_block(vp)
		await _p5_run_block(vp)
	else:
		await _p1_desktop_block()
		await _p2_desktop_block()
		await _p5_run_block(vp)
	_finish(snap)

func _wait_bar() -> void:
	for i in range(600):
		await get_tree().physics_frame
		if not _visible_bars().is_empty():
			break

## The §4 assertion set for a live-HUD state. All
## "disjoint" checks use the 1 px shrink; only visible
## nodes are paired.
func _assert_state(vp: Vector2, st: String, prompt_state: bool) -> void:
	var hud := _world.get("_hud_root") as Control
	var hero := _world.get("_hero_cluster") as Control
	var topc := _world.get("_top_card") as Control
	var mmf := hud.get_node_or_null("MinimapFrame") as Control
	var kills := hud.get_node_or_null("KillsPill") as Control
	var goal := _world.get("_goal_card") as Control
	# UI-mobile P3 (plan P3 "栈的定义改为目标 pill 底"): in the
	# new phone layout the goal card is not resident — its
	# role in every kept right-column assertion passes to the
	# objective pill (R3+R4+R5 merged). When the pill folds
	# into the kills pill's "+N" (plan Z3) there is no third
	# column element to pair. Old tree: no _obj_pill, the
	# goal card stays the subject (red baseline unchanged).
	var gname := _world.get("_goal_name") as Control
	var obj_mode := _p3_new() and _world.get("_obj_pill") is Control
	var goal_on := true
	if obj_mode:
		goal = _world.get("_obj_pill") as Control
		gname = _world.get("_obj_title") as Control
		goal_on = goal.is_visible_in_tree()
	var bl := _world.get("_bl_cluster") as Control
	var ult_name := _world.get("_ult_name_label") as Control
	var move_slot := _world.get("_move_slot") as Control
	var boss := _world.get("_boss_card") as Control
	var prompt := _world.get("_prompt") as Control
	var pw := _world.get("_pw_row") as Control
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var r_hero := _vis_rect(hero)
	var r_hero_deep := _vis_rect_deep(hero)
	var r_top := _vis_rect_deep(topc)
	var r_mm := _vis_rect(mmf)
	var r_kills := _vis_rect(kills)
	var r_goal := _vis_rect(goal)
	var r_goal_deep := _vis_rect_deep(goal)
	var r_bl := _vis_rect(bl)
	var r_pw := _vis_rect_deep(pw)
	var bars := _visible_bars()
	# -- inside the (inset) UI area -------------------------
	_check(st + ": hero cluster inside UI area", _inside(r_hero, ui_rect), str(r_hero))
	_check(st + ": top card inside UI area", _inside(r_top, ui_rect), str(r_top))
	_check(st + ": minimap inside UI area", _inside(r_mm, ui_rect), str(r_mm))
	_check(st + ": kills pill inside UI area", _inside(r_kills, ui_rect), str(r_kills))
	if obj_mode and not goal_on:
		_check(st + ": goal card visible (objective folded into kills +N)",
			_p3_folded(), "pill hidden, kills badge=" + str(_p3_folded()))
	else:
		_check(st + ": goal card visible", goal.is_visible_in_tree())
		_check(st + ": goal name label has real width",
			_vis_rect(gname).size.x >= 60.0, "w=" + str(_vis_rect(gname).size.x))
		_check(st + ": goal card inside UI area", _inside(r_goal, ui_rect), str(r_goal))
		_check(st + ": goal card keeps its right margin",
			r_goal.end.x <= ui_rect.end.x - 6.0, "right=" + str(r_goal.end.x))
	_check(st + ": bottom-left cluster inside UI area", _inside(r_bl, ui_rect), str(r_bl))
	# -- the C19 pairs (kept) --------------------------------
	var info := _world.get("_hero_info") as Control
	var medal := _world.get("_medal_panel") as Control
	_check(st + ": top card x hero info plate disjoint",
		_disjoint(_vis_rect(info), r_top),
		str(_vis_rect(info)) + " vs " + str(r_top))
	_check(st + ": top card x medallion disjoint",
		_disjoint(_vis_rect(medal), r_top))
	_check(st + ": top card x minimap disjoint", _disjoint(r_top, r_mm))
	_check(st + ": minimap x kills disjoint", _disjoint(r_mm, r_kills))
	if goal_on:
		_check(st + ": kills x goal disjoint", _disjoint(r_kills, r_goal_deep))
		_check(st + ": minimap x goal disjoint (the device clip)",
			_disjoint(r_mm, r_goal_deep))
	# -- pile stack (F2 + F1 budget) -------------------------
	var pill_rects: Array = []
	for c in (_world.get("_pill_box") as Control).get_children():
		var pc := c as Control
		if pc != null and pc.is_visible_in_tree():
			pill_rects.append(_vis_rect(pc))
	if not pill_rects.is_empty():
		_check(st + ": pill top clears goal bottom + 4",
			pill_rects[0].position.y >= r_goal.end.y + 4.0,
			"pill_top=" + str(pill_rects[0].position.y)
			+ " goal_bot=" + str(r_goal.end.y))
	# -- joystick ring x slot row (kept; ring now visible) ---
	var tc: Object = _world.get("touch_controls")
	var tc_vis: bool = tc != null and (tc as Control).visible
	if tc_vis:
		var ring := tc.get("_base_ring") as Control
		var r_ring := _vis_rect(ring)
		var slots_top := r_bl.position.y + 56.0 * bl.scale.x
		# UI-mobile P4 (plan "参照物改为 Z7 顶"): the whole
		# cluster is slot rows — its drawn top (higher than
		# the old +56 offset, so stricter).
		if _p4_mode():
			slots_top = _p4_slots_top(r_bl)
		_check(st + ": joystick ring clears the slot row",
			r_ring.end.y <= slots_top + 2.0,
			"ring_bottom=" + str(r_ring.end.y) + " slots_top=" + str(slots_top))
	# -- touch elements x everything readable ----------------
	var elems := _touch_elems()
	var targets: Array = [
		["minimap", r_mm], ["kills", r_kills],
		["topcard", r_top], ["hero", r_hero], ["pw_row", r_pw],
	]
	if goal_on:
		targets.append(["goal", r_goal_deep])
	if boss.is_visible_in_tree():
		targets.append(["boss", _vis_rect(boss)])
	for i in range(bars.size()):
		targets.append(["bar" + str(i), _vis_rect(bars[i])])
	if _banner_up():
		targets.append(["banner", _vis_rect(_world.get("_banner_back") as Control)])
	if prompt_state or String(prompt.text) != "":
		targets.append(["prompt", _prompt_rect()])
	for e in elems:
		var er := _vis_rect(e[1] as Control)
		_check(st + ": " + String(e[0]) + " inside UI area",
			_inside(er, ui_rect), str(er))
		for t in targets:
			_check(st + ": " + String(e[0]) + " x " + String(t[0]) + " disjoint",
				_disjoint(er, t[1] as Rect2),
				str(er) + " vs " + str(t[1]))
		for pr in pill_rects:
			_check(st + ": " + String(e[0]) + " x pill disjoint",
				_disjoint(er, pr), str(er) + " vs " + str(pr))
	# -- info-stack budget: stack bottom vs ult gauge top ----
	if tc_vis:
		var ult_r := _vis_rect(tc.get("ult_gauge") as Control)
		var stack_bot := r_goal.end.y if goal_on else r_kills.end.y
		if not pill_rects.is_empty():
			stack_bot = pill_rects[pill_rects.size() - 1].end.y
		_check(st + ": info stack bottom <= ult top - 4",
			stack_bot <= ult_r.position.y - 4.0,
			"stack_bot=" + str(stack_bot) + " ult_top=" + str(ult_r.position.y))
	# -- banner (F3 centre stack) -----------------------------
	if _banner_up():
		var r_bb := _vis_rect(_world.get("_banner_back") as Control)
		_check(st + ": banner x minimap disjoint", _disjoint(r_bb, r_mm), str(r_bb))
		_check(st + ": banner x kills disjoint", _disjoint(r_bb, r_kills))
		_check(st + ": banner x goal disjoint", _disjoint(r_bb, r_goal))
		# Phone only (audit F3): the span construction
		# guarantees x-disjointness from the hero cluster
		# on phone. On desktop the banner keeps its
		# centred offsets (the kept baseline) and the
		# cluster's DEEP union box false-positives — its
		# bottom row (the stat chips) is paired with the
		# banner separately below, on both modes.
		if _mode == "phone":
			_check(st + ": banner x hero disjoint", _disjoint(r_bb, r_hero_deep))
		_check(st + ": banner x top card disjoint", _disjoint(r_bb, r_top))
		_check(st + ": banner x pw row disjoint", _disjoint(r_bb, r_pw))
		for i in range(bars.size()):
			_check(st + ": banner x bar" + str(i) + " disjoint",
				_disjoint(r_bb, _vis_rect(bars[i])),
				str(r_bb) + " vs " + str(_vis_rect(bars[i]))
				+ " bar_scale=" + str((bars[i] as Control).scale))
		if boss.is_visible_in_tree() and _mode == "phone":
			_check(st + ": banner x boss disjoint",
				_disjoint(r_bb, _vis_rect(boss)),
				str(r_bb) + " vs " + str(_vis_rect(boss))
				+ " boss_scale=" + str(boss.scale))
		if _mode == "phone":
			var span: Vector2 = _world.get("_dbg_span")
			# _dbg_span is in _ui_root LOCAL space; the
			# measured rects are global — shift by the
			# layer's global origin (the safe-area inset)
			# before comparing.
			var sl := span.x + ui_rect.position.x
			var sr := span.y + ui_rect.position.x
			if sr <= sl:
				# Unfixed tree / desktop-shaped layout: the
				# audit's span from measured geometry.
				sl = r_hero_deep.end.x + 12.0
				sr = r_mm.position.x - 12.0
				for e in elems:
					if String(e[0]) in ["tc_pause", "tc_aim", "tc_lock"]:
						sr = minf(sr, _vis_rect(e[1] as Control).position.x - 12.0)
			_check(st + ": banner within span",
				r_bb.position.x >= sl - 2.0 and r_bb.end.x <= sr + 2.0,
				"banner=" + str(r_bb) + " span=" + str(Vector2(sl, sr)))
	# -- boss card + mini bars (F4) ----------------------------
	if boss.is_visible_in_tree():
		var r_boss := _vis_rect(boss)
		_check(st + ": boss card inside UI area", _inside(r_boss, ui_rect), str(r_boss))
		_check(st + ": boss card x top card disjoint",
			_disjoint(r_boss, r_top), str(r_boss))
		# Phone only (audit F4): the flowed stack keeps
		# the boss card clear of the stat-chip row on
		# phone. On desktop the card keeps its shipped
		# centred position (top 160, bottom 230) whose
		# bottom-left corner covers the chips row's
		# right end (y 206) — the kept baseline, outside
		# the audit's fix scope; recorded for C22.
		if _mode == "phone":
			_check(st + ": boss card x pw row disjoint",
				_disjoint(r_boss, r_pw), str(r_boss) + " vs " + str(r_pw))
		for i in range(bars.size()):
			_check(st + ": boss card x bar" + str(i) + " disjoint",
				_disjoint(r_boss, _vis_rect(bars[i])),
				str(r_boss) + " vs " + str(_vis_rect(bars[i])))
	for i in range(bars.size()):
		var r_bar := _vis_rect(bars[i])
		_check(st + ": bar" + str(i) + " inside UI area", _inside(r_bar, ui_rect), str(r_bar))
		_check(st + ": bar" + str(i) + " x hero disjoint",
			_disjoint(r_bar, r_hero), str(r_bar) + " vs " + str(r_hero))
		_check(st + ": bar" + str(i) + " x minimap disjoint", _disjoint(r_bar, r_mm))
		_check(st + ": bar" + str(i) + " x pw row disjoint",
			_disjoint(r_bar, r_pw), str(r_bar) + " vs " + str(r_pw))
	# -- prompt (F5) -------------------------------------------
	if prompt_state:
		var r_pr := _prompt_rect()
		var slot_top := r_bl.position.y + 48.0 * bl.scale.y
		var bl_slots := Rect2(r_bl.position.x, slot_top,
			r_bl.size.x, r_bl.end.y - slot_top)
		# UI-mobile P4: the band is both slot rows (the
		# cluster's whole drawn rect — a superset of the old
		# band, so stricter).
		if _p4_mode():
			bl_slots = _vis_rect_deep(bl).merge(r_bl)
		_check(st + ": prompt x BL slot band disjoint",
			_disjoint(r_pr, bl_slots),
			str(r_pr) + " vs " + str(bl_slots))
		# Cycle 21.3.2 (re-audit issue 1, BLOCKING):
		# the 21.3.1 lift set max_lines_visible = 0,
		# which in Godot 4.3 shows NO lines — the
		# prompt rendered as an empty glass box on 10
		# phone combos while this block's only lifted-
		# regime check was the height bound (an empty
		# label always passes it). The assertion whose
		# absence let that through: EVERY wrapped line
		# must actually be visible, in every prompt
		# state and every regime.
		var cap := (prompt as Label).max_lines_visible
		_check(st + ": prompt shows every wrapped line",
			(prompt as Label).get_visible_line_count()
				== (prompt as Label).get_line_count(),
			"vis=" + str((prompt as Label).get_visible_line_count())
			+ " total=" + str((prompt as Label).get_line_count())
			+ " cap=" + str(cap)
			+ " scale=" + str((prompt as Label).scale.x)
			+ " text=" + String(prompt.text))
		# Regime checks (world.gd _layout_prompt): the
		# F5c 2-line cap stays engaged wherever 2 lines
		# fit at scale >= 0.6; below that it lifts to
		# -1 (ALL lines) and the scale fits the full
		# column by height instead. Capped -> wrapped
		# count <= cap (over = clipped text); lifted
		# -> the column stays a minor element (the
		# height bound catches a runaway wrap).
		if cap > 0:
			_check(st + ": prompt fits the F5c 2-line cap",
				(prompt as Label).get_line_count() <= cap,
				"lines=" + str((prompt as Label).get_line_count())
				+ " cap=" + str(cap)
				+ " text=" + String(prompt.text))
		else:
			_check(st + ": narrow-span prompt column bounded",
				r_pr.size.y <= 288.0,
				"lines=" + str((prompt as Label).get_line_count())
				+ " h=" + str(r_pr.size.y)
				+ " text=" + String(prompt.text))
		if tc_vis:
			_check(st + ": ult name hidden in touch mode or clear of prompt",
				not ult_name.is_visible_in_tree()
				or _disjoint(_vis_rect(ult_name), r_pr),
				"ultname_vis=" + str(ult_name.is_visible_in_tree()))
	# -- orphaned ult name (kept legacy pair) -------------------
	if ult_name.is_visible_in_tree():
		_check(st + ": ult name x move slot disjoint (the device overprint)",
			_disjoint(_vis_rect(ult_name), _vis_rect(move_slot)),
			str(_vis_rect(ult_name)) + " vs " + str(_vis_rect(move_slot)))
	# -- safe-area insets (F6) ----------------------------------
	if _mode == "phone":
		_check(st + ": hero respects left inset",
			r_hero.position.x >= _inset.x - 1.0, str(r_hero.position.x))
		_check(st + ": minimap respects right inset",
			r_mm.end.x <= vp.x - _inset.z + 1.0, str(r_mm.end.x))
	# -- desktop pins (kept verbatim from the C19 gate) ---------
	if _mode == "desktop":
		_check("desktop: top card left edge == 350",
			absf(r_top.position.x - 350.0) <= 2.0, str(r_top.position.x))
		_check("desktop: kills top == 190",
			absf(r_kills.position.y - 190.0) <= 1.5, str(r_kills.position.y))
		_check("desktop: goal top == 226",
			absf(r_goal.position.y - 226.0) <= 1.5, str(r_goal.position.y))
		_check("desktop: minimap right margin == 12",
			absf(vp.x - r_mm.end.x - 12.0) <= 1.5, str(r_mm.end.x))
		_check("desktop: hero at (12,10) scale 1",
			absf(r_hero.position.x - 12.0) <= 1.0
			and absf(r_hero.position.y - 10.0) <= 1.0
			and absf(hero.scale.x - 1.0) < 0.01, str(r_hero))
	# -- UI-mobile P2 (top band) / P3 (right column, cluster) --
	if _mode == "phone" and not _classic:
		_p2_state(vp, st)
		_p3_state(vp, st)
		_p4_state(vp, st, prompt_state)
	elif _mode == "phone":
		_p3_classic_state(vp, st)
		_p4_legacy_state(st, "P4 classic")
	else:
		_p2_desktop_state(st)
		_p3_desktop_state(st)
		_p4_legacy_state(st, "P4 desktop")

## Audit §3/§4 modal policy: with any modal open the
## touch layer is hidden, the shared scrim is visible
## and covers the whole viewport (insets included).
func _assert_modal(vp: Vector2, name: String) -> void:
	var tc: Object = _world.get("touch_controls")
	_check("modal " + name + ": a modal is open",
		bool(_world.call("_any_modal_open")))
	_check("modal " + name + ": touch layer hidden",
		tc != null and not (tc as Control).visible)
	var scrim := _world.get("_modal_scrim") as Control
	_check("modal " + name + ": scrim visible",
		scrim != null and scrim.is_visible_in_tree())
	if scrim != null:
		var sr := scrim.get_global_rect()
		_check("modal " + name + ": scrim covers the viewport",
			sr.position.x <= 1.0 and sr.position.y <= 1.0
			and sr.end.x >= vp.x - 1.0 and sr.end.y >= vp.y - 1.0,
			str(sr) + " vp=" + str(vp))

func _finish(snap: Dictionary) -> void:
	GameProfile.data = snap
	GameProfile.save_profile()
	print("PHONEHUD DONE checks=", _checks, " fails=", _fails)
	get_tree().quit(1 if _fails > 0 else 0)

# ================================================== UI-mobile P1
## Plan §B4 P1 capture combos: 2400x1080 s1.00 i0 and
## 1920x1080 s1.50 i48,0,0,0. Flat names (the NUC pull
## script matches Test/out basenames only).
func _p1_capture_combo() -> bool:
	var tag := _run_tag()
	# U2 2026-11-13: 2340 s100 is the signoff batch first leg; its menu
	# snapshot feeds compare/U2.png. Snapshots only, no check changes.
	return tag == "2400x1080_s100_i0" or tag == "2340x1080_s100_i0" or tag == "1920x1080_s150_i48_0_0_0"

func _p1_snap(state: String) -> void:
	if _mode != "phone" or not _p1_capture_combo():
		return
	await _snap("mobile_p1_" + state + "_" + _run_tag())

func _p1_interact_alpha() -> float:
	var tc: Object = _world.get("touch_controls")
	if tc == null:
		return -1.0
	var btns: Dictionary = tc.get("_buttons")
	var panel := (btns["interact"] as Dictionary)["panel"] as Panel
	return (panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a

func _p1_interact_mode(st: String, ready: bool) -> void:
	var a := _p1_interact_alpha()
	if ready:
		_check("P1: interact ready at " + st, a >= 0.18, "bg_a=" + str(a)
			+ " prompt=" + String(_world.get("_prompt").text))
	else:
		_check("P1: interact idle when nothing near", a >= 0.0 and a <= 0.10,
			"bg_a=" + str(a) + " prompt=" + String(_world.get("_prompt").text))

func _p1_hud_start() -> void:
	_p1_interact_mode("hud_start", false)
	var tc: Object = _world.get("touch_controls")
	var ug := tc.get("ult_gauge") as Control if tc != null else null
	var has_charging_art := false
	var has_ready_art := false
	var has_duplicate_glyph := false
	var art_visible := false
	if ug != null:
		for ch in ug.get_children():
			if ch is Label and (ch as Label).text == "必":
				has_duplicate_glyph = true
			elif ch is TextureRect and (ch as TextureRect).texture != null:
				var art_path: String = String((ch as TextureRect).texture.resource_path)
				has_charging_art = has_charging_art or art_path.ends_with("btn_ult_charging.png")
				has_ready_art = has_ready_art or art_path.ends_with("btn_ult.png")
				art_visible = art_visible or (ch as TextureRect).visible
	var medal: Color = ug.get("medal") if ug != null else Color(0.4, 0.4, 0.45)
	_check("P1: touch ult gauge uses glyph art without duplicate label",
		bool(ug.get("art_mode")) and has_charging_art and has_ready_art
		and art_visible and not has_duplicate_glyph
		and not medal.is_equal_approx(Color(0.4, 0.4, 0.45)),
		"art_mode=" + str(ug.get("art_mode") if ug != null else false)
		+ " charging=" + str(has_charging_art) + " ready=" + str(has_ready_art)
		+ " visible=" + str(art_visible) + " duplicate=" + str(has_duplicate_glyph)
		+ " medal=" + str(medal))

## Current banner (if live) + the queued ones, in order.
func _p1_banner_texts() -> Array:
	var out: Array = []
	if float(_world.get("_banner_t")) > 0.0:
		out.append(String((_world.get("_banner") as Label).text))
	var q = _world.get("_banner_q")
	if q is Array:
		for e in q:
			out.append(String((e as Array)[0]))
	return out

func _p1_alpha_banner() -> void:
	var texts := _p1_banner_texts()
	var alpha_t := ""
	for t in texts:
		if String(t).contains("头领"):
			alpha_t = String(t)
	if _mode == "phone":
		_check("P1: alpha banner has no keyboard verb",
			alpha_t != "" and not alpha_t.contains("按 E"),
			"alpha=" + alpha_t + " all=" + str(texts))
		# Bring the alpha line to the front for the capture
		# (the queue rotates on its own; bounded wait).
		if _p1_capture_combo():
			for i in range(400):
				if String((_world.get("_banner") as Label).text).contains("头领") \
						and float(_world.get("_banner_t")) > 0.0:
					break
				await get_tree().process_frame
			await _p1_snap("alpha_banner")

func _p1_prompt_verb(st: String) -> void:
	if _mode != "phone":
		return
	var t := String(_world.get("_prompt").text)
	_check("P1: prompt has no keyboard verb (" + st + ")",
		t != "" and not t.contains("按 E"), "text=" + t)

## The gold=0 chest line carries no verb at all (金币不足),
## so the plan's chest state cannot bite; the paid line
## does. Same chest, gold lifted for 20 frames, restored
## (the kept states that follow see gold = 0 again).
## Desktop: the same paid line with the touch latch
## released must carry the keyboard verb.
func _p1_paid_chest() -> void:
	var desk := _mode != "phone"
	if desk:
		await _p1_latch(false)
	_world.set("gold", 500.0)
	await _frames(20)
	await _p1_pframes(4)
	var t := String(_world.get("_prompt").text)
	if desk:
		_check("P1 desktop: chest prompt keeps the keyboard verb",
			t.contains("按 E") and not t.contains("点互动"), "text=" + t)
	else:
		_check("P1: paid chest prompt uses the touch verb",
			t.contains("点互动") and not t.contains("按 E"), "text=" + t)
	_world.set("gold", 0.0)
	await _frames(4)
	if desk:
		await _p1_latch(true)

## Desktop variant: the kept states run with the touch
## layer FORCED ON (header), so the inverted (keyboard)
## wording is checked in place — latch released, prompt
## re-read, latch restored before the next kept state.
## Waits count PROCESS frames: _touch_text_sync and the
## prompt block both run in World._process, and several
## physics frames can pass inside one main-loop iteration
## (the first desktop run read the altar label before any
## _process had re-synced it).
func _p1_latch(on: bool) -> void:
	_world.set("_touch_forced", on)
	await _p1_pframes(8)

func _p1_desktop_prompt(st: String) -> void:
	if _mode == "phone":
		return
	await _p1_latch(false)
	var t := String(_world.get("_prompt").text)
	_check("P1 desktop: " + st + " prompt keeps the keyboard verb",
		t.contains("按 E") and not t.contains("点互动"), "text=" + t)
	await _p1_latch(true)

func _p1_altar() -> void:
	var pl = _world.get("player")
	var av = _world.get("ALTAR_XZ")
	var a: Vector2 = av if av is Vector2 else Vector2(0, -30)
	pl.global_position = Vector3(a.x + 1.5, float(_world.call("height_at", a.x + 1.5, a.y)) + 0.1, a.y)
	await _frames(30)
	var t := String(_world.get("_prompt").text)
	_check("P1: altar prompt is the summon line", t.contains("召唤守护者"), "text=" + t)
	_p1_prompt_verb("altar")
	_p1_interact_mode("altar", true)
	if _mode == "phone":
		var al := _world.get("_altar_label") as Label3D
		_check("P1: altar 3D label has no keyboard verb",
			al != null and not al.text.contains("按 E"), al.text if al else "null")
	else:
		await _p1_desktop_prompt("altar")
		await _p1_latch(false)
		var al2 := _world.get("_altar_label") as Label3D
		_check("P1 desktop: altar 3D label keeps the keyboard verb",
			al2 != null and al2.text.contains("按 E"), al2.text if al2 else "null")
		await _p1_latch(true)

func _p1_settle_drafts() -> void:
	for i in range(40):
		var s := String(_world.get("state"))
		if s == "draft":
			_world._apply_draft_option(0)
		elif s == "blessing":
			_world._apply_blessing_offer(0)
		elif s == "choice":
			_world._choice_pick(0)
		else:
			return
		await _frames(8)

## Sum process deltas (the world's banner clock) while no
## modal is open, until `secs` have elapsed.
func _p1_wait_banner_clock(secs: float) -> float:
	var acc := 0.0
	var guard := 0
	while acc < secs and guard < 4000:
		await get_tree().process_frame
		guard += 1
		if not bool(_world.call("_any_modal_open")):
			acc += get_process_delta_time()
	return acc

func _p1_find_label(root: Node, needle: String) -> bool:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text.contains(needle) \
				and (n as Label).is_visible_in_tree():
			return true
		for ch in n.get_children():
			stack.append(ch)
	return false

func _p1_visible_kbd_caps(b: Control) -> int:
	var n := 0
	for ch in b.get_children():
		if ch is PanelContainer and (ch as Control).visible \
				and ch.get_child_count() > 0 and ch.get_child(0) is Label:
			n += 1
	return n

func _p1_phone_block(vp: Vector2) -> void:
	await _p1_settle_drafts()
	var pl = _world.get("player")
	# ---- capture prompt: a downed alpha in throw range ----
	var alpha: Node3D = null
	var ally_label := "<none>"
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and int(e.get("flag")) == 2 and not bool(e.get("is_guardian")):
			alpha = e
			break
	if alpha != null:
		alpha.set("is_downed", true)
		alpha.set("down_t", 30.0)  # the throw window (0 = dies next tick)
		pl.global_position = alpha.global_position + Vector3(3, 0.2, 0)
		await _frames(12)
		var t := String(_world.get("_prompt").text)
		_check("P1: capture prompt shown", t.contains("邀伴"), "text=" + t
			+ " state=" + String(_world.get("state"))
			+ " d=" + str(pl.global_position.distance_to(alpha.global_position)))
		_p1_prompt_verb("capture")
		_p1_interact_mode("capture", true)
		var tc0: Object = _world.get("touch_controls")
		_check("P1: interact throw mode on capture",
			tc0 != null and tc0.get("_interact_mode") == 2,
			"mode=" + str(tc0.get("_interact_mode") if tc0 else -1))
		# Party injection for the status page: the alpha joins.
		alpha.call("make_ally")
		ally_label = String(ModelRig.SPECIES[String(alpha.get("species_id"))]["label"])
	else:
		_check("P1: alpha present for the capture prompt", false)
	# ---- pause: status page / quick settings / quit -------
	var ikey := String(GameData.item_keys()[0])
	pl.items = {ikey: 2}
	var vk := String(GameData.VITAMINS.keys()[0])
	pl.vit_levels[vk] = maxi(1, int(pl.vit_levels.get(vk, 0)))
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	_world.show_banner("P1 冻结探针", 30.0)
	await _frames(3)
	_world._open_pause()
	await _frames(10)
	var bt0 := float(_world.get("_banner_t"))
	var pp := _world.get("_pause_panel") as Control
	var seg := pp.get_meta("seg") as HBoxContainer
	var first := String((seg.get_child(0) as Button).text) if seg else ""
	var pages: Dictionary = _world.get("_pause_pages")
	var status := pages.get("status") as Control
	var chips := 0
	if status != null:
		var pwb := status.find_child("PwChips", true, false)
		if pwb != null:
			chips = pwb.get_child_count()
	var iname := String(GameData.item_def(ikey).get("name", ikey))
	_check("P1: pause tabs", first == "状态" and status != null and status.visible
		and chips >= 6 and _p1_find_label(status, iname),
		"first=" + first + " chips=" + str(chips) + " item=" + iname
		+ " found=" + str(status != null and _p1_find_label(status, iname)))
	_check("P1: status page lists vitamin + party",
		status != null and _p1_find_label(status, String(GameData.VITAMINS[vk]["label"]))
		and _p1_find_label(status, ally_label),
		"vit=" + String(GameData.VITAMINS[vk]["label"]) + " ally=" + ally_label)
	_check("P1: status page carries the run block (stardust)",
		status != null and _p1_find_label(status, str(GameProfile.stardust())),
		"dust=" + str(GameProfile.stardust()))
	await _p1_snap("pause_status")
	# The pause is a modal: the banner clock must not move.
	var acc := 0.0
	for i in range(4000):
		await get_tree().process_frame
		acc += get_process_delta_time()
		if acc >= 2.0:
			break
	var bt1 := float(_world.get("_banner_t"))
	_check("P1: banner timer frozen under modal", absf(bt1 - bt0) < 0.001 and bt0 > 0.0,
		"t0=" + str(bt0) + " t1=" + str(bt1) + " wall=" + str(acc))
	# Quick settings row.
	_world._pause_show_tab(2)
	await _frames(4)
	var setp := pages.get("settings") as Control
	var quick := 0
	if setp != null:
		var qb := setp.find_child("QuickRow", true, false)
		if qb != null:
			quick = qb.get_child_count()
	_check("P1: pause settings quick row", quick >= 4, "rows=" + str(quick))
	# U1 1:1 round 10: the target lock lives in this quick row
	# now (no tc-lock button on the HUD) — the switch mirrors
	# the live lock state and re-syncs after each press.
	var lock_sw: Button = null
	if setp != null:
		var qb2 := setp.find_child("QuickRow", true, false)
		if qb2 != null:
			for row in qb2.get_children():
				if row is HBoxContainer and _p1_find_label(row, "锁定目标"):
					for ch in (row as HBoxContainer).get_children():
						if ch is Button:
							lock_sw = ch as Button
	_check("P1: pause quick row carries the target lock",
		lock_sw != null and lock_sw.is_visible_in_tree(),
		"switch=" + str(lock_sw))
	var pl1 = _world.get("player")
	var lock_of := func() -> bool:
		var lt = pl1.get("lock_target") if pl1 != null else null
		return lt != null and is_instance_valid(lt)
	if lock_sw != null:
		_check("P1: lock switch mirrors the live lock state",
			bool(lock_sw.get_meta("sw_on", false)) == lock_of.call(),
			"sw=" + str(bool(lock_sw.get_meta("sw_on", false))) + " locked=" + str(lock_of.call()))
		lock_sw.emit_signal("pressed")
		await _frames(4)
		_check("P1: lock switch press re-syncs to the live lock state",
			bool(lock_sw.get_meta("sw_on", false)) == lock_of.call(),
			"sw=" + str(bool(lock_sw.get_meta("sw_on", false))) + " locked=" + str(lock_of.call()))
	await _p1_snap("pause_settings")
	# Quit needs a confirm: one press arms, scene stays.
	var qbtn := _world.get("_pause_quit_btn") as Button
	var scene0 := get_tree().current_scene
	if qbtn != null:
		qbtn.emit_signal("pressed")
	await _frames(3)
	_check("P1: main-menu quit needs confirm",
		qbtn != null and get_tree().current_scene == scene0
		and qbtn.text.contains("再点一次") and String(_world.get("state")) == "pause",
		"text=" + (qbtn.text if qbtn else "null"))
	_world._close_pause()
	await _frames(4)
	_check("P1: quit confirm disarms on close",
		qbtn != null and not qbtn.text.contains("再点一次"),
		"text=" + (qbtn.text if qbtn else "null"))
	# ---- banner queue: A then B --------------------------
	await _p1_settle_drafts()
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	_world.show_banner("A", 3.0)
	_world.show_banner("B", 3.0)
	var a1 := await _p1_wait_banner_clock(0.3)
	var ta := String((_world.get("_banner") as Label).text)
	var a2 := await _p1_wait_banner_clock(1.1)
	var tb := String((_world.get("_banner") as Label).text)
	_check("P1: banner queue keeps both", ta == "A" and tb == "B",
		"t0.3=" + ta + " t1.4=" + tb + " clocks=" + str(a1) + "/" + str(a1 + a2))
	# ---- draft: no kbd caps, no [Tab] ---------------------
	_world._open_draft()
	await _frames(12)
	if String(_world.get("state")) == "draft":
		var rb := _world.get("_draft_rb") as Control
		var tbtn := _world.get("_draft_team_btn") as Button
		_check("P1: draft has no kbd caps",
			rb != null and _p1_visible_kbd_caps(rb) == 0
			and tbtn != null and not tbtn.text.contains("[Tab]"),
			"caps=" + str(_p1_visible_kbd_caps(rb) if rb else -1)
			+ " team=" + (tbtn.text if tbtn else "null"))
		await _p1_snap("draft")
	else:
		_check("P1: draft opened for the kbd-cap check", false,
			"state=" + String(_world.get("state")))
	await _p1_settle_drafts()
	# ---- settings: the touch "操作" page ------------------
	_world._open_settings()
	_world._settings_show_tab("keys")
	await _frames(6)
	var tabs: Dictionary = _world.get("_settings_tabs")
	var ktab := tabs.get("keys") as Button
	var page := _world.get("_settings_page") as Control
	_check("P1: settings keys tab is the touch ops page",
		ktab != null and ktab.text == "操作"
		and _p1_find_label(page, "摇杆") and _p1_find_label(page, "外接键盘"),
		"tab=" + (ktab.text if ktab else "null"))
	await _p1_snap("settings_ops")
	_world._close_settings()
	await _frames(4)
	# ---- two-thumb camera (A6/A9 addendum) ----------------
	await _p1_two_thumb(vp)

## Simulated two-touch: index 0 holds the joystick, index
## 1 drags the empty right half. Events go through
## Input.parse_input_event (mouse emulation + GUI routing
## exactly as on device).
func _p1_two_thumb(vp: Vector2) -> void:
	# UI-mobile P4 (sampling only, criteria unchanged): a level-
	# up draft landing mid-test hid the touch layer and released
	# the stick (joy=true/false, dyaw=0 — the P2/P3 "fixture
	# event" signature; P4's extra capture frames made it hit
	# both capture combos in the red run). XP is frozen for the
	# test, as P3 froze it for its block.
	var pl0 = _world.get("player")
	var xpm_tt := float(pl0.xp_mult) if pl0 != null else 1.0
	if pl0 != null:
		pl0.xp_mult = 0.0
	await _p1_two_thumb_run(vp)
	if pl0 != null:
		pl0.xp_mult = xpm_tt

func _p1_two_thumb_run(vp: Vector2) -> void:
	await _p1_settle_drafts()
	GameProfile.set_setting("camAssist", false)
	var tc: Object = _world.get("touch_controls")
	for i in range(300):
		if tc != null and (tc as Control).visible:
			break
		# A draft already queued by the previous fixture can open
		# after the initial settle. Resolve it before sampling input.
		if String(_world.get("state")) == "draft":
			await _p1_settle_drafts()
			var player = _world.get("player")
			if player != null:
				player.xp_mult = 0.0
		await get_tree().process_frame
	if tc == null or not (tc as Control).visible:
		var open: Array = []
		for pn in ["_draft_panel", "_blessing_panel", "_choice_panel", "_pause_panel",
				"_bigmap_panel", "_result_panel", "_lab_panel", "_shop_panel",
				"_sound_panel", "_wallet_panel", "_unlock_panel", "_loadout_panel",
				"_meowth_panel"]:
			var pc = _world.get(pn)
			if pc != null and (pc as Control).visible:
				open.append(pn)
		_check("P1: touch layer up for the two-thumb test", false,
			"state=" + String(_world.get("state")) + " modals=" + str(open))
		return
	var cs := float(GameProfile.setting("camSpeed"))
	var layer_off := (tc as Control).get_global_rect().position
	var jp: Vector2 = layer_off + Vector2(tc.call("_joy_home"))
	var cp := Vector2(vp.x * 0.62, vp.y * 0.62)
	# UI-mobile P3 fix round 2 (sampling only, criteria
	# unchanged): the camera thumb must START on free screen.
	# At 1920 ts1.50 + right inset 48 the spec-placed lock
	# (arc centre (830,444), 96 px) covers the fixed 62%/62%
	# point, so the press was a lock tap and dyaw = 0. Slide
	# the start left of any touch control it lands on (70 px
	# clear, same start rule as the P3 lock-swipe test).
	for k in range(4):
		var moved := false
		for e in _touch_elems():
			var er := _vis_rect(e[1] as Control)
			if (e[1] as Control).visible and er.has_point(cp):
				cp.x = er.position.x - 70.0
				moved = true
		if not moved:
			break
	# 1) single right-thumb drag (index 0): exactly one
	# rotation path (no double count with mouse emulation).
	var y0 := float(_world.get("cam_yaw"))
	_p1_touch(0, cp, true)
	await _p1_pframes(3)
	for i in range(6):
		_p1_drag(0, cp + Vector2(20 * (i + 1), 0), Vector2(20, 0))
		await _p1_pframes(2)
	_p1_touch(0, cp + Vector2(120, 0), false)
	await _p1_pframes(3)
	var d1 := float(_world.get("cam_yaw")) - y0
	_check("P1: single-thumb drag rotates once",
		d1 <= -0.45 * cs and d1 >= -0.75 * cs,
		"dyaw=" + str(d1) + " expect~" + str(-0.6 * cs) + " from=" + str(cp))
	# 2) left thumb on the stick (index 0), right thumb
	# (index 1) drags the camera.
	_p1_touch(0, jp, true)
	await _p1_pframes(3)
	_p1_drag(0, jp + Vector2(0, -50), Vector2(0, -50))
	await _p1_pframes(3)
	var joy_on := bool(tc.call("debug_joy_active"))
	var y1 := float(_world.get("cam_yaw"))
	_p1_touch(1, cp, true)
	await _p1_pframes(3)
	for i in range(6):
		_p1_drag(1, cp + Vector2(20 * (i + 1), 0), Vector2(20, 0))
		await _p1_pframes(2)
	await _p1_pframes(2)
	var d2 := float(_world.get("cam_yaw")) - y1
	var still := bool(tc.call("debug_joy_active"))
	var mv: Vector2 = tc.get("joy_vector")
	_check("P1: two-thumb camera rotates while the stick is held",
		joy_on and still and mv.length() > 0.2
		and d2 <= -0.45 * cs and d2 >= -0.75 * cs,
		"joy=" + str(joy_on) + "/" + str(still) + " mv=" + str(mv)
		+ " dyaw=" + str(d2) + " expect~" + str(-0.6 * cs))
	_p1_touch(1, cp + Vector2(120, 0), false)
	_p1_touch(0, jp + Vector2(0, -50), false)
	await _p1_pframes(4)
	_check("P1: stick releases after the two-thumb test",
		not bool(tc.call("debug_joy_active")))

## Input waits count PROCESS frames: parse_input_event
## buffers until the next main-loop flush, and several
## physics frames can fall inside one iteration.
func _p1_pframes(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

## Event coordinates are WINDOW pixels (the device truth);
## the stretched viewport maps them to logical px itself.
## Index 0 also moves the cursor: on device the emulated
## mouse position IS touch 0 (the joystick's mouse branch
## reads get_global_mouse_position); under X11 it would
## otherwise read the real, unrelated X cursor.
func _p1_k() -> Vector2:
	return Vector2(get_window().size) / get_viewport().get_visible_rect().size

func _p1_touch(idx: int, pos: Vector2, down: bool) -> void:
	if idx == 0:
		get_viewport().warp_mouse(pos)
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = pos * _p1_k()
	ev.pressed = down
	Input.parse_input_event(ev)

func _p1_drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == 0:
		get_viewport().warp_mouse(pos)
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = pos * _p1_k()
	ev.relative = rel * _p1_k()
	Input.parse_input_event(ev)

## Desktop variant: text assertions INVERTED with the
## touch latch released (no touch device on desktop). The
## chest / meowth / altar inversions run in place at their
## kept states (_p1_paid_chest, _p1_desktop_prompt) — by
## this point those props may be used up.
func _p1_desktop_block() -> void:
	await _p1_settle_drafts()
	await _p1_latch(false)
	_world.call("_spawn_alpha")
	await _frames(4)
	var alpha_t := ""
	for t3 in _p1_banner_texts():
		if String(t3).contains("阿尔法"):
			alpha_t = String(t3)
	_check("P1 desktop: alpha banner keeps the keyboard verb",
		alpha_t.contains("按 E"), "alpha=" + alpha_t)
	_world._open_draft()
	await _frames(12)
	if String(_world.get("state")) == "draft":
		var rb := _world.get("_draft_rb") as Control
		var tbtn := _world.get("_draft_team_btn") as Button
		_check("P1 desktop: draft keeps kbd caps + [Tab]",
			rb != null and _p1_visible_kbd_caps(rb) == 1
			and tbtn != null and tbtn.text.contains("[Tab]"),
			"caps=" + str(_p1_visible_kbd_caps(rb) if rb else -1)
			+ " team=" + (tbtn.text if tbtn else "null"))
	else:
		_check("P1 desktop: draft opened for the kbd-cap check", false,
			"state=" + String(_world.get("state")))
	await _p1_settle_drafts()
	_world._open_settings()
	_world._settings_show_tab("keys")
	await _frames(6)
	var tabs: Dictionary = _world.get("_settings_tabs")
	var ktab := tabs.get("keys") as Button
	_check("P1 desktop: keys tab keeps its keyboard title",
		ktab != null and ktab.text == "键位", "tab=" + (ktab.text if ktab else "null"))
	_world._close_settings()
	await _frames(4)

# ================================================== UI-mobile P2
## Plan §B4 P2 (top band de-dup + recovered scale, Z1/Z2/Z3).
## Geometry/text assertions run inside every live-HUD state
## (_assert_state tail); the parity gate runs on the kept
## pause modal; the tap / toast / contextual checks run after
## the P1 block. Font floors per D7: the 20:9 line (viewport
## aspect >= 2) uses the plan's 19 / 24 / 20; the 16:9 line's
## floor is 17 and the numeral floors scale by the same 17/19.
## Glance-text scope = the P2 zones (hero cluster Z1, top card
## Z2, kills pill Z3): the goal card / pill stack (P3), the
## centre stack (P3) and the BL cluster (P4) are rebuilt in
## later phases — their sub-floor labels are printed as INFO.
## Centre-clear scope likewise omits the BL cluster (P4 owns
## it; plan P4 re-asserts centre clear with the prompt).
func _p2_tier20(vp: Vector2) -> bool:
	return vp.x / maxf(vp.y, 1.0) >= 2.0

func _p2_floor(vp: Vector2, f20: float) -> float:
	return f20 if _p2_tier20(vp) else f20 * 17.0 / 19.0

## Drawn font size: theme size x the node's global scale.
func _p2_drawn(l: Label) -> float:
	return float(l.get_theme_font_size("font_size")) * l.get_global_transform().get_scale().y

func _p2_labels(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).is_visible_in_tree() \
				and String((n as Label).text).strip_edges() != "":
			out.append(n)
		for ch in n.get_children():
			stack.append(ch)
	return out

func _p2_find_text(root: Node, needle: String) -> String:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text.contains(needle):
			return (n as Label).text
		for ch in n.get_children():
			stack.append(ch)
	return ""

## The tier chip ("普通") has no world reference on the P1
## tree — found by its text under the top card.
func _p2_tier_chip() -> Control:
	var t = _world.get("_tier_chip")
	if t is Control:
		return t
	var topc := _world.get("_top_card") as Control
	var stack: Array = [topc]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and (n as Label).text == "普通":
			return n.get_parent() as Control
		for ch in n.get_children():
			stack.append(ch)
	return null

func _p2_allies() -> int:
	return get_tree().get_nodes_in_group("allies").size()

func _p2_state(vp: Vector2, st: String) -> void:
	var hud := _world.get("_hud_root") as Control
	var hero := _world.get("_hero_cluster") as Control
	var topc := _world.get("_top_card") as Control
	var kills := hud.get_node_or_null("KillsPill") as Control
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var vw := ui_rect.size.x
	# -- s_t floor ------------------------------------------
	# The plan's 1.40 tier starts at vw 1500, but its own §B2
	# formula reaches 1.40 only at vw 1536.8 (default hud /
	# minimap scale): 2340x1080 + 48 inset (vw 1512) gives
	# 1.372. The tier edge sits at the formula's crossing and
	# the exact-formula check below pins every vw instead.
	var s_t := hero.scale.x
	var hs := float(GameProfile.setting("hudScale"))
	var mms := float(GameProfile.setting("minimapScale"))
	var s_full := float(_world.call("_kr")) * hs
	# UI-mobile P3 (plan P7): s_mm also fits the column
	# (minimap + kills) above the thumb cluster — binds only
	# at the minimapScale 1.50 / touchScale 1.50 corners.
	var s_mm_f := _p3_s_mm_want()
	var fit := (vw - 48.0 - 176.0 * mms * s_mm_f) / 900.0
	var s_t_want := minf(minf(s_full, 1.45), fit)
	var need := 0.0
	if absf(hs - 1.0) < 0.001 and absf(mms - 1.0) < 0.001:
		if vw >= 1537.0:
			need = 1.40
		elif vw >= 1270.0:
			need = 1.10
	_check("P2: s_t floor (" + st + ")", s_t >= need - 0.001,
		"s_t=" + str(s_t) + " need=" + str(need) + " vw=" + str(vw))
	_check("P2: s_t formula (" + st + ")", absf(s_t - s_t_want) < 0.002,
		"s_t=" + str(s_t) + " want=min(s,1.45,fit)=" + str(s_t_want)
		+ " fit=" + str(fit))
	# -- glance text (Z1 / Z2 / kills) ----------------------
	var floor_g := _p2_floor(vp, 19.0)
	var bad: Array = []
	var n_lab := 0
	for root in [hero, topc]:
		for l in _p2_labels(root):
			n_lab += 1
			if _p2_drawn(l) < floor_g - 0.01:
				bad.append("%s=%.1f" % [String((l as Label).text).substr(0, 10), _p2_drawn(l)])
	_check("P2: glance text size (" + st + ")", bad.is_empty() and n_lab > 0,
		"floor=" + str(floor_g) + " labels=" + str(n_lab) + " below=" + str(bad))
	var kl := _world.get("_kills_label") as Label
	var kd := _p2_drawn(kl)
	_check("P2: kills pill text >= 18 (" + st + ")", kd >= 18.0 - 0.01, "drawn=" + str(kd))
	var info: Array = []
	for nm in ["_goal_card", "_pill_box", "_bl_cluster", "_boss_card"]:
		for l in _p2_labels(_world.get(nm) as Node):
			if _p2_drawn(l) < floor_g - 0.01:
				info.append("%s:%s=%.1f" % [nm, String((l as Label).text).substr(0, 8), _p2_drawn(l)])
	print("PHONEHUD INFO P2 out-of-scope sub-floor labels (", st, "): ", info)
	# -- must-glance numerals --------------------------------
	var f24 := _p2_floor(vp, 24.0)
	var f20 := _p2_floor(vp, 20.0)
	var nums := [["timer", "_timer_label", f24], ["hp", "_hud_hp_num", f20],
		["gold", "_gold_label", f24], ["ball", "_ball_price_label", f24]]
	var nd: Array = []
	var nok := true
	for e in nums:
		var lab := _world.get(String(e[1])) as Label
		var d := _p2_drawn(lab) if lab != null else 0.0
		nd.append("%s=%.1f/%.1f" % [String(e[0]), d, float(e[2])])
		if lab == null or not lab.is_visible_in_tree() or d < float(e[2]) - 0.01:
			nok = false
	_check("P2: must-glance numerals (" + st + ")", nok, str(nd))
	# -- collapsed items are hidden on phone ------------------
	# U1 1:1 round 3: zone / tier chips and the stardust item
	# are restored on phone (reference U1_final.jpg) — the
	# collapse now covers only the English name, the elapsed
	# clock and the power row; the restored items are
	# asserted VISIBLE instead (same strictness, new target).
	var zchip := (_world.get("_zone_chip_label") as Control).get_parent() as Control
	var tchip := _p2_tier_chip()
	var hid := {
		"pw_row": _world.get("_pw_row"), "zone_en": _world.get("_zone_en"),
		"elapsed": _world.get("_elapsed_label"),
		# U1 1:1 round 7: the zone NAME is hidden on phone too
		# (reference top bar has no place name) — same
		# strictness, new target.
		"zone_cn": _world.get("_zone_cn")}
	var shown: Array = []
	for k in hid.keys():
		var c := hid[k] as Control
		if c == null or c.is_visible_in_tree():
			shown.append(k)
	_check("P2: collapsed top-band items hidden (" + st + ")", shown.is_empty(),
		"still shown=" + str(shown))
	var restored := {
		"zone_chip": zchip, "tier_chip": tchip,
		"dust": _world.get("_dust_label")}
	var missing: Array = []
	for k in restored.keys():
		var c := restored[k] as Control
		if c == null or not c.is_visible_in_tree():
			missing.append(k)
	_check("P2: restored top-band items visible (" + st + ")", missing.is_empty(),
		"hidden=" + str(missing))
	var hn := String((_world.get("_hud_name") as Label).text)
	var pl = _world.get("player")
	var en := String(pl.species_id).capitalize() if pl != null else "?"
	_check("P2: hero name is Chinese only (" + st + ")",
		not hn.contains(en) and hn.strip_edges() != "", "name=" + hn)
	var party := _world.get("_party_row") as Control
	var na := _p2_allies()
	_check("P2: party row only with allies (" + st + ")",
		party.is_visible_in_tree() == (na > 0),
		"allies=" + str(na) + " visible=" + str(party.is_visible_in_tree()))
	# U1 1:1 round 14 (coordinator ruling): the medallion grew
	# 86 -> 108 to the reference's measure and is now the
	# cluster's tallest element in both states (party bottom
	# is 104), so the box-height pin follows it at the same
	# strength — the pin's purpose (box = tallest element's
	# bottom) is unchanged.
	var want_h := 108.0
	_check("P2: hero cluster box = 340 x HP/party bottom (" + st + ")",
		absf(hero.size.x - 340.0) < 0.5 and absf(hero.size.y - want_h) < 0.5,
		"size=" + str(hero.size) + " want_h=" + str(want_h))
	# -- top card content version ------------------------------
	_check("P2: top card design width 560 (" + st + ")",
		absf(topc.size.x - 560.0) < 0.5, "size=" + str(topc.size))
	var track := (_world.get("_hud_hp_num") as Control).get_parent() as Control
	_check("P2: HP track 20 tall (" + st + ")",
		absf(track.size.y - 20.0) < 0.5, "track=" + str(track.size))
	var segs: Array = _world.get("_danger_segs")
	var seg0 := segs[0] as Control
	_check("P2: danger segments 13x14 (" + st + ")",
		absf(seg0.size.x - 13.0) < 0.5 and absf(seg0.size.y - 14.0) < 0.5, str(seg0.size))
	var mm := _world.get("_minimap") as Control
	var mmf := hud.get_node_or_null("MinimapFrame") as Control
	var s_mm_want := _p3_s_mm_want()
	_check("P2: minimap at s_mm (" + st + ")",
		absf(mmf.scale.x - s_mm_want) < 0.01 and absf(mm.scale.x - s_mm_want) < 0.01
		and absf(kills.scale.x - s_mm_want) < 0.01,
		"frame=" + str(mmf.scale.x) + " mm=" + str(mm.scale.x)
		+ " kills=" + str(kills.scale.x) + " want=" + str(s_mm_want))
	var badge = _world.get("_mm_expand")
	var r_mmf := _vis_rect(mmf)
	var badge_ok := false
	var bdet := "missing"
	if badge is Control and (badge as Control).is_visible_in_tree():
		var rb := _vis_rect(badge as Control)
		bdet = str(rb) + " in " + str(r_mmf)
		badge_ok = _inside(rb, r_mmf) and rb.get_center().x > r_mmf.get_center().x \
			and rb.get_center().y > r_mmf.get_center().y
	_check("P2: minimap expand badge in the bottom-right inner corner (" + st + ")",
		badge_ok, bdet)
	# -- top card scale: s_t wherever the touch column leaves
	# the card band (P2-era column: pause rises into the
	# band at touchScale 1.50 — the card fits to it there).
	var tc: Object = _world.get("touch_controls")
	var r_top := _vis_rect_deep(topc)
	var col_clear := true
	if tc != null and (tc as Control).visible:
		for k in ["pause", "aim", "lock"]:
			var btns: Dictionary = tc.get("_buttons")
			if btns.has(k) and ((btns[k] as Dictionary)["area"] as Control).visible:
				var ar := _vis_rect((btns[k] as Dictionary)["area"] as Control)
				if ar.position.y < r_top.end.y + 12.0:
					col_clear = false
	if col_clear:
		_check("P2: top card rides s_t (" + st + ")",
			absf(topc.scale.x - s_t) < 0.01,
			"card=" + str(topc.scale.x) + " s_t=" + str(s_t))
	else:
		print("PHONEHUD INFO P2 card fitted to the touch column (", st, "): card=",
			topc.scale.x, " s_t=", s_t)
	# -- centre clear (P2 zones + right column) ----------------
	var cr := Rect2(ui_rect.position.x + 0.30 * ui_rect.size.x,
		ui_rect.position.y + 0.42 * ui_rect.size.y,
		0.40 * ui_rect.size.x, 0.43 * ui_rect.size.y)
	var perm: Array = [["hero", _vis_rect_deep(hero)], ["topcard", r_top],
		["minimap", r_mmf], ["kills", _vis_rect(kills)],
		["goal", _vis_rect_deep(_world.get("_goal_card") as Control)]]
	for c in (_world.get("_pill_box") as Control).get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			perm.append(["pill", _vis_rect(c as Control)])
	var hits: Array = []
	for e in perm:
		var r := e[1] as Rect2
		if r.size.x > 0.0 and not _disjoint(r, cr):
			hits.append(String(e[0]) + str(r))
	_check("P2: centre clear (" + st + ")", hits.is_empty(),
		"centre=" + str(cr) + " hits=" + str(hits))
	var r_bl := _vis_rect_deep(_world.get("_bl_cluster") as Control)
	print("PHONEHUD INFO P2 BL cluster vs centre (P4 scope): ", r_bl,
		" intersects=", not _disjoint(r_bl, cr))

## Desktop: the P2 branch must not engage (factor 1).
func _p2_desktop_state(st: String) -> void:
	var hero := _world.get("_hero_cluster") as Control
	var topc := _world.get("_top_card") as Control
	var vis_ok := true
	var det: Array = []
	for nm in ["_pw_row", "_zone_en", "_elapsed_label", "_dust_label"]:
		var c := _world.get(nm) as Control
		if c == null or not c.is_visible_in_tree():
			vis_ok = false
			det.append(nm)
	var track := (_world.get("_hud_hp_num") as Control).get_parent() as Control
	var seg0 := (_world.get("_danger_segs") as Array)[0] as Control
	var badge = _world.get("_mm_expand")
	var badge_vis: bool = badge is Control and (badge as Control).is_visible_in_tree()
	_check("P2 desktop: top band unchanged (" + st + ")",
		vis_ok and absf(topc.size.x - 726.0) < 0.5
		and absf(hero.size.x - 454.0) < 0.5
		and absf(track.size.y - 15.0) < 0.5
		and absf(seg0.size.y - 10.0) < 0.5 and not badge_vis
		and String((_world.get("_hud_name") as Label).text).contains("Bulbasaur"),
		"hidden=" + str(det) + " card=" + str(topc.size) + " hero=" + str(hero.size)
		+ " track=" + str(track.size) + " seg=" + str(seg0.size)
		+ " badge=" + str(badge_vis)
		+ " name=" + String((_world.get("_hud_name") as Label).text))

## Parity gate (plan B5 P1): every value the phone top band
## hides is on the pause status page, same value.
func _p2_parity() -> void:
	var pages: Dictionary = _world.get("_pause_pages")
	var status := pages.get("status") as Control
	if status == null or not status.visible:
		_check("P2: hidden items reachable (status page open)", false)
		return
	var pl = _world.get("player")
	var zone := int(_world.get("zone"))
	var zones: Array = _world.get("ZONES")
	var zrow: Dictionary = zones[zone - 1]
	var want := {
		"zone_en": String(zrow["en"]),
		"elapsed": String(_world.call("_fmt_elapsed", float(_world.get("elapsed")))),
		"dust": str(GameProfile.stardust()),
		"zone_idx": "第 %d/%d 区" % [zone, zones.size()],
		"tier": "难度：普通",
		"species_en": String(_world.call("_hud_info_for", String(pl.species_id))["en"]),
		"evo": String(_world.call("_hud_info_for", String(pl.species_id))["evo"]).trim_prefix("› "),
	}
	var wx: Dictionary = (_world.get("WEATHER_TABLE") as Dictionary)[String(_world.get("weather"))]
	want["weather"] = "天气：" + String(wx["cn"])
	for d in _world.call("_pw_defs"):
		want["pw:" + String(d[0])] = String(d[0])
	var miss: Array = []
	for k in want.keys():
		if _p2_find_text(status, String(want[k])) == "":
			miss.append(String(k) + "=" + String(want[k]))
	_check("P2: hidden items reachable", miss.is_empty(),
		"checked=" + str(want.size()) + " missing=" + str(miss))
	for k in ["zone_en", "elapsed", "dust", "species_en", "evo", "weather"]:
		_check("P2: parity " + k, _p2_find_text(status, String(want[k])) != "",
			"want=" + String(want[k]) + " got=" + _p2_find_text(status, String(want[k])))

## Phone tail: weather tap, stat toast, contextual evo,
## party row with an ally.
func _p2_phone_block(vp: Vector2) -> void:
	await _p1_settle_drafts()
	var tc: Object = _world.get("touch_controls")
	for i in range(300):
		if tc != null and (tc as Control).visible and not bool(_world.call("_any_modal_open")):
			break
		await get_tree().process_frame
	# ---- T6: tap the weather chip -> 1.5 s explanation -----
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	var chip := (_world.get("_wx_label") as Control).get_parent() as Control
	var c := _vis_rect(chip).get_center()
	var wx: Dictionary = (_world.get("WEATHER_TABLE") as Dictionary)[String(_world.get("weather"))]
	_p1_touch(0, c, true)
	await _p1_pframes(3)
	var joy_on := tc != null and bool(tc.call("debug_joy_active"))
	_p1_touch(0, c, false)
	await _p1_pframes(3)
	var texts := _p1_banner_texts()
	var hit := ""
	for t in texts:
		if String(t).contains("天气：" + String(wx["cn"])):
			hit = String(t)
	_check("P2: weather chip tap explains the weather",
		hit != "" and float(_world.get("_banner_secs")) <= 1.5 + 0.001,
		"tap=" + str(c) + " banners=" + str(texts) + " secs=" + str(_world.get("_banner_secs")))
	var hitc = _world.get("_wx_hit")
	var hr := _vis_rect(hitc as Control) if hitc is Control else Rect2()
	_check("P2: weather chip hit area >= 70", hr.size.x >= 70.0 and hr.size.y >= 70.0,
		"hit=" + str(hr))
	_check("P2: weather chip tap does not start the stick", tc != null and not joy_on,
		"joy_active_while_down=" + str(joy_on))
	# ---- D3: stat change toast -------------------------------
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	var pl = _world.get("player")
	var dm0 := float(pl.damage_mult)
	pl.damage_mult = dm0 + 0.10
	var tt := await _p2_watch_banner(["伤害 ×", "↑"], 120)
	_check("P2: stat change toast (伤害 ↑)", tt != "",
		"seen=" + tt + " banners=" + str(_p1_banner_texts()))
	pl.damage_mult = dm0
	var td := await _p2_watch_banner(["伤害 ×", "↓"], 120)
	_check("P2: stat change toast (伤害 ↓)", td != "",
		"seen=" + td + " banners=" + str(_p1_banner_texts()))
	# ---- H6: evo line only within 3 levels -------------------
	var evo_lv := int(GameData.evo_level_for(String(pl.species_id)))
	var evo := _world.get("_hud_evo") as Control
	if evo_lv > 0:
		var lv0 := int(pl.level)
		pl.level = maxi(1, evo_lv - 10)
		await _p1_pframes(30)
		# U1 1:1 round 4: the evo label lives inside the hero
		# info plate, hidden on phone — read its own flag,
		# not in-tree visibility (the tick logic is what's
		# under test: off far, on near).
		var far_vis := evo.visible
		pl.level = evo_lv - 2
		await _p1_pframes(30)
		var near_vis := evo.visible
		pl.level = lv0
		await _p1_pframes(20)
		_check("P2: evo line only within 3 levels",
			not far_vis and near_vis,
			"evo_lv=" + str(evo_lv) + " far=" + str(far_vis) + " near=" + str(near_vis))
	else:
		print("PHONEHUD INFO P2 evo check skipped: species ", pl.species_id, " has no evo")
	# ---- H8: party row back with an ally ---------------------
	var party := _world.get("_party_row") as Control
	var hero := _world.get("_hero_cluster") as Control
	_check("P2: party row shows with an ally",
		# U1 1:1 round 14: height pin follows the same ruling
		# as the box pin above — 108 (the medallion) in both
		# states; the party row's own bottom stays 104.
		_p2_allies() == 0 or (party.is_visible_in_tree() and absf(hero.size.y - 108.0) < 0.5),
		"allies=" + str(_p2_allies()) + " vis=" + str(party.is_visible_in_tree())
		+ " hero=" + str(hero.size))

## Watch the banner channel (current + queue) every process
## frame for up to n frames; returns the first text holding
## every needle, "" if none showed. A single sample after a
## fixed frame count missed the 1.5 s toast on the slow
## software-GL host (30 frames ~ 1.5 s there) — and could
## let the desktop inversion pass on a toast that came and
## went between samples.
func _p2_watch_banner(needles: Array, n: int) -> String:
	for i in range(n):
		await get_tree().process_frame
		for t in _p1_banner_texts():
			var ok := true
			for nd in needles:
				if not String(t).contains(String(nd)):
					ok = false
			if ok:
				return String(t)
	return ""

func _p2_desktop_block() -> void:
	await _p1_settle_drafts()
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	var pl = _world.get("player")
	var dm0 := float(pl.damage_mult)
	pl.damage_mult = dm0 + 0.10
	var tt := await _p2_watch_banner(["伤害 ×"], 120)
	_check("P2 desktop: no stat toast (the row is on screen)", tt == "",
		"seen=" + tt + " banners=" + str(_p1_banner_texts()))
	pl.damage_mult = dm0
	await _p1_pframes(20)

## Plan P2 captures: the two plan combos get all four
## states; the matrix corners (2400 / 1920 x touchScale
## 0.70 / 1.50, no inset) get hud_start + boss.
func _p2_snap(state: String) -> void:
	if _mode != "phone":
		return
	var tag := _run_tag()
	var corner := tag in ["2400x1080_s070_i0", "2400x1080_s150_i0",
		"2340x1080_s070_i0", "2340x1080_s150_i0",
		"1920x1080_s070_i0", "1920x1080_s150_i0"]
	if _p1_capture_combo() or (corner and state in ["hud_start", "boss"]):
		await _snap("mobile_p2_" + state + "_" + tag)

# ================================================== UI-mobile P3
## Plan §B4 P3 (right column + thumb cluster) + the P2-closure
## coordinator additions: D6 classic layout (--layout=classic,
## 21.3.2 geometry), the P7 hudScale / minimapScale corners
## (--hud= / --mm=), I3 press feedback on every tappable HUD
## element. Per-state checks run from _assert_state; the
## boss sub-step (2+ alphas, cut-in) after the kept boss
## state; the drawer / portrait / aim / round-trip block
## after the P2 phone block. Parity rule: every value or
## control moved this phase is exercised at its new home.
func _p3_new() -> bool:
	return _mode == "phone" and not _classic

func _p3_folded() -> bool:
	# U1 1:1 round 10: the fold signal is the layout flag, not
	# the kills badge — the "+N" badge is gone (clean kills
	# pill per the reference; folded objectives live in the
	# drawer, see _p3_obj_target).
	return bool(_world.get("_obj_folded"))

## Lowest top (global y) of the visible touch elements whose
## x-range meets [x0, x1]; INF when the layer is hidden.
func _p3_cluster_top(x0: float, x1: float) -> float:
	var m := INF
	for e in _touch_elems():
		if String(e[0]) == "tc_ring":
			continue
		var r := _vis_rect(e[1] as Control)
		if r.end.x > x0 and r.position.x < x1:
			m = minf(m, r.position.y)
	return m

## Plan §B2 s_mm = min(s, 1.30), plus the P7 guard: the
## column (minimap + 4 + kills 28) ends above the cluster
## element under it - 8 (floor 0.5). The x-range is the
## uncapped column (conservative).
func _p3_s_mm_want() -> float:
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var s := float(_world.call("_kr")) * float(GameProfile.setting("hudScale"))
	var mmw := 176.0 * float(GameProfile.setting("minimapScale"))
	var w := minf(s, 1.30)
	var ct := _p3_cluster_top(ui_rect.end.x - 12.0 - mmw * w, ui_rect.end.x - 12.0)
	if ct < INF:
		var z := ct - ui_rect.position.y - 8.0
		w = minf(w, maxf((z - 14.0) / (mmw + 28.0), 0.5))
	return w

## Objective count (drawer entries): the event list (new
## layout filter) + the goal. -1 on a tree without it.
func _p3_total() -> int:
	if not _world.has_method("_event_list"):
		return -1
	var n := (_world.call("_event_list", true) as Array).size()
	if String(_world.get("_goal_species")) != "":
		n += 1
	return n

func _p3_alpha(c: Control) -> float:
	if c == null:
		return -1.0
	if c is UiMedallion:
		return float(c.get("press_a"))
	var sb := c.get_theme_stylebox("panel") as StyleBoxFlat
	return sb.bg_color.a if sb != null else -1.0

func _p3_visual(e: Array) -> Rect2:
	var c := e[1] as Control
	var tc: Object = _world.get("touch_controls")
	var btns: Dictionary = tc.get("_buttons")
	var k := String(e[0]).trim_prefix("tc_")
	if btns.has(k):
		return _vis_rect((btns[k] as Dictionary)["panel"] as Control)
	if k == "ult":
		var pad = c.get("hit_pad")
		return _vis_rect(c).grow(-(float(pad) if pad != null else 0.0))
	return _vis_rect(c)

func _p3_hits() -> Array:
	var out: Array = []
	for nm in ["_portrait_hit", "_obj_hit", "_wx_hit"]:
		var h = _world.get(nm)
		if h is Control and (h as Control).is_visible_in_tree():
			out.append([nm, h])
	return out

func _p3_state(vp: Vector2, st: String) -> void:
	var hud := _world.get("_hud_root") as Control
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var tc: Object = _world.get("touch_controls")
	var tc_vis: bool = tc != null and (tc as Control).visible
	var obj = _world.get("_obj_pill")
	var objc: Control = obj as Control if obj is Control else null
	var kills := hud.get_node_or_null("KillsPill") as Control
	var mmf := hud.get_node_or_null("MinimapFrame") as Control
	var goal := _world.get("_goal_card") as Control
	# -- one objective pill + "+N" -----------------------------
	var pills_vis := 0
	for c in (_world.get("_pill_box") as Control).get_children():
		if c is Control and (c as Control).is_visible_in_tree():
			pills_vis += 1
	var total := _p3_total()
	var badge_ok := false
	var bdet := "no _obj_pill"
	if objc != null and total >= 0:
		if objc.is_visible_in_tree():
			var b := _world.get("_obj_badge") as Control
			var bl := _world.get("_obj_badge_label") as Label
			badge_ok = (total == 1 and not b.is_visible_in_tree()) \
				or (total > 1 and b.is_visible_in_tree() and bl.text == "+%d" % (total - 1))
			bdet = "pill badge=" + (bl.text if b.is_visible_in_tree() else "<hidden>")
		elif _p3_folded():
			# U1 1:1 round 10: the kills pill is clean — no "+N"
			# badge. The folded objectives are in the drawer
			# (the tap test below asserts the drawer opens
			# from the kills pill and lists them all).
			var kb := _world.get("_kills_badge") as Control
			badge_ok = kb != null and not kb.is_visible_in_tree()
			bdet = "folded, kills badge hidden=" + str(badge_ok)
		else:
			badge_ok = total == 0
			bdet = "no pill"
	_check("P3: one objective pill on phone (" + st + ")",
		objc != null and pills_vis == 0 and not goal.is_visible_in_tree() and badge_ok,
		"pill_box_visible=" + str(pills_vis) + " goal_card=" + str(goal.is_visible_in_tree())
		+ " total=" + str(total) + " " + bdet)
	# -- objective text size (D7 floors, same as P2 glance) ----
	var floor_g := _p2_floor(vp, 19.0)
	var bad: Array = []
	var roots: Array = []
	if objc != null and objc.is_visible_in_tree():
		roots.append(objc)
	# U1 1:1 round 10: the kills badge is always hidden now —
	# no text-size roots from it.
	for r in roots:
		for l in _p2_labels(r as Node):
			if _p2_drawn(l) < floor_g - 0.01:
				bad.append("%s=%.1f" % [String((l as Label).text).substr(0, 8), _p2_drawn(l)])
	if objc == null:
		bad.append("no _obj_pill")
	_check("P3: objective pill text size (" + st + ")", bad.is_empty(),
		"floor=" + str(floor_g) + " below=" + str(bad))
	# -- no alpha pill while a mini bar shows it ---------------
	if not _visible_bars().is_empty():
		var titles: Array = []
		if _world.has_method("_event_list"):
			for ev in (_world.call("_event_list", true) as Array):
				titles.append(String(ev[0]))
		for c in (_world.get("_pill_box") as Control).get_children():
			if c is Control and (c as Control).is_visible_in_tree():
				titles.append(_p2_find_text(c, "阿尔法"))
		if objc != null and objc.is_visible_in_tree():
			titles.append(String((_world.get("_obj_title") as Label).text))
		_check("P3: no alpha pill while bar visible (" + st + ")",
			not titles.has("阿尔法") and not titles.has("阿尔法出没"), str(titles))
	if not tc_vis:
		return
	# -- cluster: pause / aim / lock gone ----------------------
	# U1 1:1 round 10: lock joins pause + aim — no lock button
	# on the combat HUD anymore (its home is the pause menu's
	# quick row; the P1 pause block asserts it there).
	var btns: Dictionary = tc.get("_buttons")
	var gone := true
	for k in ["pause", "aim", "lock"]:
		if btns.has(k) and ((btns[k] as Dictionary)["area"] as Control).visible:
			gone = false
	_check("P3: no pause / aim / lock button in the thumb cluster (" + st + ")", gone)
	var ts := float(tc.get("_scale_s"))
	# -- touch targets >= 70; a hit never covers another's disc
	var small: Array = []
	var elems := _touch_elems()
	for e in elems:
		if String(e[0]) == "tc_ring":
			continue
		var r := _vis_rect(e[1] as Control)
		if r.size.x < 70.0 - 0.5 or r.size.y < 70.0 - 0.5:
			small.append(String(e[0]) + str(r.size))
	var hits := _p3_hits()
	for h in hits:
		var r2 := _vis_rect(h[1] as Control)
		if r2.size.x < 70.0 - 0.5 or r2.size.y < 70.0 - 0.5:
			small.append(String(h[0]) + str(r2.size))
	_check("P3: touch targets >= 70 (" + st + ")", small.is_empty() and hits.size() >= 2,
		"ts=" + str(ts) + " small=" + str(small) + " world_hits=" + str(hits.size()))
	var cover: Array = []
	for a in elems:
		if String(a[0]) == "tc_ring":
			continue
		var ha := _vis_rect(a[1] as Control)
		for b in elems:
			if b == a or String(b[0]) == "tc_ring":
				continue
			if not _disjoint(ha, _p3_visual(b)):
				cover.append(String(a[0]) + ">" + String(b[0]))
	_check("P3: hit areas never cover another button (" + st + ")", cover.is_empty(), str(cover))
	# -- portrait = pause (D1) ---------------------------------
	var ph = _world.get("_portrait_hit")
	var med := _world.get("_medal_panel") as Control
	var mr := _vis_rect(med)
	var pok := false
	var pdet := "no _portrait_hit"
	if ph is Control:
		var pr := _vis_rect(ph as Control)
		pdet = "hit=" + str(pr) + " medal=" + str(mr)
		pok = (ph as Control).is_visible_in_tree() and pr.size.x >= 69.5 and pr.size.y >= 69.5 \
			and pr.grow(1.0).encloses(mr)
	_check("P3: portrait tap target >= 70 covers the portrait (" + st + ")", pok, pdet)
	var pb = _world.get("_pause_badge")
	var lv := _world.get("_lv_label") as Control
	# U1 1:1 round 10: the reference has no pause badge on the
	# portrait — the badge node stays but must be hidden. The
	# portrait-tap pause entry itself is covered by the check
	# above.
	_check("P3: no pause badge on the portrait (reference) (" + st + ")",
		pb is Control and not (pb as Control).is_visible_in_tree(),
		("badge=" + str(_vis_rect(pb as Control))) if pb is Control else "none")
	# U1 1:1 round 10: the Lv badge is the reference's dark chip
	# with white text (round 6's cream chip was a misread).
	var lv_ok := false
	var lv_det := "no _lv_label"
	if lv != null:
		var fc: Color = lv.get_theme_color("font_color")
		var par := lv.get_parent() as Control
		var sb := par.get_theme_stylebox("panel") as StyleBoxFlat if par != null else null
		lv_ok = fc.r > 0.9 and fc.g > 0.9 and fc.b > 0.9 and sb != null \
			and sb.bg_color.a > 0.4 and (sb.bg_color.r + sb.bg_color.g + sb.bg_color.b) < 0.9
		lv_det = "font=" + str(fc) + " bg=" + (str(sb.bg_color) if sb != null else "none")
	_check("P3: Lv badge dark chip, white text (" + st + ")", lv_ok, lv_det)

## Plan P3: 2+ alphas (side-by-side bars, "+N" past two) and
## the ult cut-in at the head of the centre stack.
func _p3_actives() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if is_instance_valid(en) and en.flag == 2 and en.hp > 0.0 \
				and en.mode != Enemy.MODE_ALLY and not en.is_downed and not en.is_guardian:
			n += 1
	return n

func _p3_boss(vp: Vector2) -> void:
	var tries := 0
	while _p3_actives() < 3 and tries < 4:
		_world.call("_spawn_alpha")
		tries += 1
		await _frames(4)
	for i in range(600):
		await get_tree().physics_frame
		if _visible_bars().size() >= 2:
			break
	await _p1_pframes(12)
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var span: Vector2 = _world.get("_dbg_span")
	var sl := span.x + ui_rect.position.x
	var sr := span.y + ui_rect.position.x
	var bars := _visible_bars()
	if bars.size() == 2:
		var r0 := _vis_rect(bars[0])
		var r1 := _vis_rect(bars[1])
		_check("P3: mini bars side by side",
			absf(r0.position.y - r1.position.y) < 1.0 and _disjoint(r0, r1)
			and r0.position.x >= sl - 2.0 and r0.end.x <= sr + 2.0
			and r1.position.x >= sl - 2.0 and r1.end.x <= sr + 2.0,
			str(r0) + " | " + str(r1) + " span=" + str(Vector2(sl, sr)))
		var na := _p3_actives()
		var nm := String(((_world.get("_mini_bars") as Array)[1]["name"] as Label).text)
		_check("P3: second bar names the alphas past two",
			na <= 2 or nm.ends_with("+%d" % (na - 2)), "actives=" + str(na) + " name=" + nm)
	else:
		_check("P3: two alphas for the side-by-side bars", false,
			"bars=" + str(bars.size()) + " actives=" + str(_p3_actives()))
	_p3_state(vp, "boss_2alpha")
	await _p3_snap("boss_2alpha")
	_world.show_ult_cutin("狂怒根须", Color(0.55, 0.85, 0.4))
	await _p1_pframes(3)
	var cut := _world.get("_cutin_panel") as Control
	var boss := _world.get("_boss_card") as Control
	var rc := _vis_rect(cut)
	var rb := _vis_rect(boss)
	var clear := true
	for b in _visible_bars():
		clear = clear and _disjoint(rc, _vis_rect(b))
	_check("P3: cutin x boss disjoint",
		cut.is_visible_in_tree() and boss.is_visible_in_tree() and _disjoint(rc, rb)
		and rb.end.y <= rc.position.y + 1.0 and clear
		and rc.position.x >= sl - 2.0 and rc.end.x <= sr + 2.0,
		"cutin=" + str(rc) + " boss=" + str(rb) + " bars_clear=" + str(clear)
		+ " span=" + str(Vector2(sl, sr)))
	# The tallest centre stack (cut-in + boss + two bars +
	# toast) must still clear the prompt (plan Z4 / Z6).
	if String(_world.get("_prompt").text) != "":
		var pr := _prompt_rect()
		var stk: Array = [["cutin", rc], ["boss", rb]]
		for i in range(_visible_bars().size()):
			stk.append(["bar" + str(i), _vis_rect(_visible_bars()[i])])
		if _banner_up():
			stk.append(["banner", _vis_rect(_world.get("_banner_back") as Control)])
		var ph2: Array = []
		for e in stk:
			if not _disjoint(e[1] as Rect2, pr):
				ph2.append(String(e[0]) + str(e[1]))
		_check("P3: centre stack clears the prompt (cut-in up)", ph2.is_empty(),
			"prompt=" + str(pr) + " hits=" + str(ph2))
	await _p3_snap("ult_cutin_boss")

## Tap through the real GUI routing (touch 0 + its emulated
## mouse), sampling the target's alpha while held.
func _p3_tap(at: Vector2, tgt: Control) -> Array:
	var a0 := _p3_alpha(tgt)
	_p1_touch(0, at, true)
	await _p1_pframes(3)
	var a1 := _p3_alpha(tgt)
	_p1_touch(0, at, false)
	await _p1_pframes(4)
	return [a0, a1, _p3_alpha(tgt)]

func _p3_fb_ok(a: Array) -> bool:
	var a0 := float(a[0])
	return a0 >= 0.0 and absf(float(a[1]) - minf(a0 + 0.25, 1.0)) < 0.011 \
		and absf(float(a[2]) - a0) < 0.011

func _p3_drawer_texts() -> Array:
	var out: Array = []
	for l in _p2_labels(_world.get("_obj_drawer") as Node):
		out.append(String((l as Label).text))
	return out

func _p3_has_text(texts: Array, needle: String) -> bool:
	for t in texts:
		if String(t).contains(needle):
			return true
	return false

# P5 closing diagnosis: observe fixture state transitions without changing gates.
var _p3_diag_last := ""

func _p3_diag_tick() -> void:
	var pl = _world.get("player")
	var sig := "state=%s xp_mult=%s level=%s pending=%s guardian=%s" % [
		_world.get("state"), pl.xp_mult, pl.level, pl.pending_levels,
		is_instance_valid(_world.get("guardian"))]
	if sig != _p3_diag_last:
		print("PHONEHUD INFO P3 fixture frame=", Engine.get_process_frames(), " ", sig,
			" xp=", pl.xp)
		_p3_diag_last = sig

## P3 input samples must begin in live play. Settling a draft can
## recalc xp_mult, so re-pin the existing XP fixture after settling.
func _p3_sample_ready() -> void:
	await _p3_ready()
	var pl = _world.get("player")
	pl.xp_mult = 0.0
	pl.xp = 0.0

## A direct level reward can open a draft during the objective
## tap's asynchronous frames even with XP frozen. Re-open only
## when a foreign modal interrupted this sample (bounded guard).
func _p3_challenge_sample(hit: Control, tgt: Control) -> void:
	for attempt in range(4):
		await _p3_sample_ready()
		await _p3_tap(_vis_rect(hit).get_center(), tgt)
		if not bool(_world.call("_any_modal_open")):
			return
		print("PHONEHUD INFO P3 challenge sample interrupted attempt=", attempt + 1,
			" state=", _world.get("state"))

func _p3_phone_block(vp: Vector2) -> void:
	get_tree().process_frame.connect(_p3_diag_tick)
	await _p1_settle_drafts()
	var tc: Object = _world.get("touch_controls")
	for i in range(300):
		if tc != null and (tc as Control).visible and not bool(_world.call("_any_modal_open")):
			break
		await get_tree().process_frame
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var pl = _world.get("player")
	# The injected swarm + alphas feed XP: a level-up draft
	# mid-block hides the touch layer (it1: the drawer tap
	# landed under a draft, then every modal-gated wait idled
	# to its guard and the run hit the 900 s timeout). XP is
	# frozen for the block (restored at its end) and every
	# tap re-settles first.
	var xpm0 := float(pl.xp_mult)
	pl.xp_mult = 0.0
	pl.xp = 0.0
	await _p3_sample_ready()
	# ---- inject: stage event + comet + swarm (plan events3) --
	_world.set("_event_kind", "fog")
	_world.set("_event_left", 40.0)
	if _world.has_method("_comet_spawn"):
		var pp: Vector3 = pl.global_position
		_world.call("_comet_spawn", Vector2(pp.x + 14.0, pp.z + 6.0))
	_world.set("_swarm", true)
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	await _p1_pframes(20)
	_world._refresh_goal_card()
	_world._refresh_event_pills()
	await _p1_pframes(4)
	var evs: Array = _world.call("_event_list", true) if _world.has_method("_event_list") else []
	_check("P3: three events injected", evs.size() >= 3, "events=" + str(evs.size()))
	_assert_state(vp, "events3", false)
	await _p3_snap("hud_events3")
	# ---- objective tap -> drawer (I4) ----------------------
	var hit = _world.get("_obj_hit")
	var dr = _world.get("_obj_drawer")
	if not (hit is Control and dr is Control):
		_check("P3: objective tap opens the drawer", false, "no _obj_hit / _obj_drawer")
		_check("P3: drawer lists all", false, "no drawer")
		_check("P3: press feedback (objective)", false, "no _obj_hit")
	else:
		var objc := _world.get("_obj_pill") as Control
		var tgt: Control = objc if objc.is_visible_in_tree() else \
			(_world.get("_hud_root") as Control).get_node("KillsPill") as Control
		await _p3_sample_ready()
		var c := _vis_rect(hit as Control).get_center()
		var fb := await _p3_tap(c, tgt)
		_check("P3: press feedback (objective)", _p3_fb_ok(fb), "alpha base/held/after=" + str(fb))
		var drc := dr as Control
		_check("P3: objective tap opens the drawer", drc.is_visible_in_tree(),
			"tap=" + str(c) + " folded=" + str(_p3_folded()))
		_check("P3: drawer does not pause the game",
			String(_world.get("state")) in ["playing", "guardian", "portal"] and bool(_world.get("running")),
			"state=" + String(_world.get("state")))
		# parity: every event's title + sub, the full goal card
		# (countdown subs tick each second — list + drawer are
		# re-read in the same frame after a synchronous refresh)
		_world._refresh_goal_card()
		_world._refresh_event_pills()
		evs = _world.call("_event_list", true)
		var texts := _p3_drawer_texts()
		var miss: Array = []
		for ev in evs:
			for k in [0, 1]:
				if not _p3_has_text(texts, String(ev[k])):
					miss.append(String(ev[k]))
		for nm in ["_goal_name", "_goal_next", "_goal_count"]:
			var gt := String((_world.get(nm) as Label).text)
			if gt != "" and not _p3_has_text(texts, gt):
				miss.append(nm + "=" + gt)
		_check("P3: drawer lists all", drc.is_visible_in_tree() and miss.is_empty()
			and _p3_drawer_has_button(),
			"missing=" + str(miss) + " texts=" + str(texts.size()))
		var rd := _vis_rect(drc)
		_check("P3: drawer inside UI area", _inside(rd, ui_rect), str(rd))
		var dhits: Array = []
		for e in _touch_elems():
			if not _disjoint(rd, _vis_rect(e[1] as Control)):
				dhits.append(String(e[0]))
		_check("P3: drawer x thumb cluster disjoint", drc.is_visible_in_tree() and dhits.is_empty(),
			"drawer=" + str(rd) + " hits=" + str(dhits))
		var dbad: Array = []
		for l in _p2_labels(drc):
			if _p2_drawn(l) < _p2_floor(vp, 19.0) - 0.01:
				dbad.append("%s=%.1f" % [String((l as Label).text).substr(0, 8), _p2_drawn(l)])
		_check("P3: drawer text size", dbad.is_empty(), str(dbad))
		var allb := _p3_drawer_button()
		var abr := _vis_rect(allb) if allb != null else Rect2()
		_check("P3: drawer button tap target >= 70", allb != null and abr.size.y >= 69.5
			and _inside(abr, rd), "button=" + str(abr))
		_p3_state(vp, "drawer_open")
		await _p3_snap("drawer_open")
		# tap outside closes (no input is eaten for it)
		var outp := Vector2(ui_rect.position.x + ui_rect.size.x * 0.60,
			ui_rect.position.y + ui_rect.size.y * 0.70)
		_p1_touch(0, outp, true)
		await _p1_pframes(3)
		_p1_touch(0, outp, false)
		await _p1_pframes(3)
		_check("P3: tap outside closes the drawer", not drc.visible, "at=" + str(outp))
		# 4 s without input closes it
		await _p3_sample_ready()
		await _p3_tap(_vis_rect(hit as Control).get_center(), tgt)
		var opened := drc.visible
		await _p1_wait_banner_clock(3.4)
		var at34 := drc.visible
		await _p1_wait_banner_clock(1.2)
		var at46 := drc.visible
		_check("P3: drawer auto-collapses after 4 s", opened and at34 and not at46,
			"open=" + str(opened) + " 3.4s=" + str(at34) + " 4.6s=" + str(at46))
		# 查看全部挑战: paused, read-only G10, back to pause
		await _p3_challenge_sample(hit as Control, tgt)
		print("PHONEHUD INFO P3 challenge after tap state=", _world.get("state"), " drawer=", drc.visible, " xp_mult=", pl.xp_mult, " pending=", pl.pending_levels)
		var btn := _p3_drawer_button()
		if btn != null:
			btn.emit_signal("pressed")
		await _p1_pframes(4)
		var up := _world.get("_unlock_panel") as Control
		var pp2 := _world.get("_pause_panel") as Control
		_check("P3: drawer opens all challenges paused",
			btn != null and String(_world.get("state")) == "pause" and up.visible
			and not pp2.visible and not bool(_world.get("running")) and not drc.visible,
			"state=" + String(_world.get("state")) + " unlock=" + str(up.visible))
		var xb = _world.get("_unlock_close_btn")
		if xb is Button:
			(xb as Button).emit_signal("pressed")
		await _p1_pframes(4)
		_check("P3: closing the challenge list returns to pause",
			String(_world.get("state")) == "pause" and pp2.visible and not up.visible,
			"state=" + String(_world.get("state")) + " pause=" + str(pp2.visible))
		_world._close_pause()
		await _p1_pframes(6)
	# ---- portrait tap = pause (D1) + I3 ---------------------
	var ph = _world.get("_portrait_hit")
	var med := _world.get("_medal_panel") as Control
	await _p3_sample_ready()
	if ph is Control and (ph as Control).is_visible_in_tree():
		var fb2 := await _p3_tap(_vis_rect(ph as Control).get_center(), med)
		_check("P3: press feedback (portrait)", absf(float(fb2[0])) < 0.001
			and absf(float(fb2[1]) - 0.25) < 0.011 and absf(float(fb2[2])) < 0.001,
			"press_a base/held/after=" + str(fb2))
		var pages: Dictionary = _world.get("_pause_pages")
		_check("P3: pause reachable",
			String(_world.get("state")) == "pause" and (pages["status"] as Control).visible
			and not (pages["legend"] as Control).visible and not (pages["settings"] as Control).visible,
			"state=" + String(_world.get("state")))
		_world._close_pause()
		await _p1_pframes(6)
	else:
		_check("P3: pause reachable", false, "no visible _portrait_hit")
		_check("P3: press feedback (portrait)", false, "no visible _portrait_hit")
	# ---- weather chip I3 (shipped tappable, uniform feedback)
	var wh = _world.get("_wx_hit")
	await _p3_sample_ready()
	if wh is Control and (wh as Control).is_visible_in_tree():
		var chip := (_world.get("_wx_label") as Control).get_parent() as Control
		var fb3 := await _p3_tap(_vis_rect(wh as Control).get_center(), chip)
		_check("P3: press feedback (weather chip)", _p3_fb_ok(fb3), "alpha base/held/after=" + str(fb3))
	else:
		_check("P3: press feedback (weather chip)", false, "no visible _wx_hit")
	# ---- aim (D2): the pause quick row is its home ----------
	_world._open_pause()
	await _p1_pframes(4)
	_world._pause_show_tab(2)
	await _p1_pframes(4)
	var quick := (_world.get("_pause_pages")["settings"] as Control).find_child("QuickRow", true, false)
	var sw: Button = null
	if quick != null:
		for row in quick.get_children():
			var lab := _p2_find_text(row, "镜头辅助")
			if lab != "":
				for ch in row.get_children():
					if ch is Button:
						sw = ch
	var v0 := bool(GameProfile.setting("camAssist"))
	var v1 := v0
	var aim1 := false
	if sw != null:
		sw.emit_signal("pressed")
		await _p1_pframes(2)
		v1 = bool(GameProfile.setting("camAssist"))
		aim1 = bool(tc.get("_aim_on"))
		sw.emit_signal("pressed")
		await _p1_pframes(2)
	_check("P3: aim toggle lives in the pause quick row",
		sw != null and v1 != v0 and aim1 == v1 and bool(GameProfile.setting("camAssist")) == v0,
		"found=" + str(sw != null) + " v0=" + str(v0) + " v1=" + str(v1) + " tc_aim=" + str(aim1))
	_world._close_pause()
	await _p1_pframes(6)
	# ---- a camera swipe sliding across the thumb cluster keeps
	# turning (U1 1:1 round 10: the lock button is gone — the
	# swipe now crosses the dash button, which sits on the
	# arc where the lock was, in the right thumb's path).
	await _p3_sample_ready()
	GameProfile.set_setting("camAssist", false)
	var btns: Dictionary = tc.get("_buttons")
	var lr := _vis_rect((btns["dash"] as Dictionary)["area"] as Control)
	var cs := float(GameProfile.setting("camSpeed"))
	var st0 := Vector2(lr.position.x - 70.0, lr.get_center().y)
	var y0 := float(_world.get("cam_yaw"))
	for attempt in range(4):
		await _p3_sample_ready()
		y0 = float(_world.get("cam_yaw"))
		print("PHONEHUD INFO P3 camera start state=", _world.get("state"), " point=", st0, " k=", _p1_k())
		_p1_touch(1, st0, true)
		await _p1_pframes(3)
		var interrupted := bool(_world.call("_any_modal_open"))
		for i in range(6):
			_p1_drag(1, st0 + Vector2(20 * (i + 1), 0), Vector2(20, 0))
			await _p1_pframes(2)
			interrupted = interrupted or bool(_world.call("_any_modal_open"))
			print("PHONEHUD INFO P3 camera step=", i, " state=", _world.get("state"), " id=", _world.get("_cam_touch_id"), " dy=", float(_world.get("cam_yaw")) - y0)
		_p1_touch(1, st0 + Vector2(120, 0), false)
		await _p1_pframes(3)
		interrupted = interrupted or bool(_world.call("_any_modal_open"))
		if not interrupted:
			break
		print("PHONEHUD INFO P3 camera sample interrupted attempt=", attempt + 1,
			" state=", _world.get("state"))
	var dy := float(_world.get("cam_yaw")) - y0
	_check("P3: camera swipe across the thumb cluster keeps turning",
		lr.has_point(st0 + Vector2(70, 0)) and dy <= -0.45 * cs and dy >= -0.75 * cs,
		"dash=" + str(lr) + " from=" + str(st0) + " dyaw=" + str(dy) + " expect~" + str(-0.6 * cs))
	# ---- cleanup the injected events ------------------------
	pl.xp_mult = xpm0
	_world.set("_swarm", false)
	_world.set("_event_left", 0.01)
	if _world.has_method("_comet_clear"):
		_world.call("_comet_clear")
	await _p1_pframes(20)
	get_tree().process_frame.disconnect(_p3_diag_tick)
	# ---- D6 round trip (settings -> 界面 switch) ------------
	await _p3_round_trip("new")

## No modal up, touch layer showing (drafts settled).
func _p3_ready() -> void:
	await _p1_settle_drafts()
	var tc: Object = _world.get("touch_controls")
	for i in range(300):
		if tc != null and (tc as Control).visible and not bool(_world.call("_any_modal_open")):
			return
		await get_tree().process_frame

func _p3_drawer_button() -> Button:
	var dr = _world.get("_obj_drawer")
	if not (dr is Control):
		return null
	var stack: Array = [dr]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and String((n as Button).text).contains("查看全部挑战"):
			return n
		for ch in n.get_children():
			stack.append(ch)
	return null

func _p3_drawer_has_button() -> bool:
	return _p3_drawer_button() != null

## Layout signature for the D6 round trip.
func _p3_layout_sig() -> Dictionary:
	var hud := _world.get("_hud_root") as Control
	var topc := _world.get("_top_card") as Control
	var tc: Object = _world.get("touch_controls")
	var btns: Dictionary = tc.get("_buttons")
	var obj = _world.get("_obj_pill")
	var ph = _world.get("_portrait_hit")
	return {
		"classic": bool(GameProfile.setting("classicLayout")),
		"pause_btn": ((btns["pause"] as Dictionary)["area"] as Control).visible,
		"aim_btn": ((btns["aim"] as Dictionary)["area"] as Control).visible,
		# U1 1:1 round 10: no "lock" key — the lock button left
		# the HUD (its home is the pause menu's quick row).
		"card_w": topc.size.x,
		"card_s": snappedf(topc.scale.x, 0.001),
		"hero_s": snappedf((_world.get("_hero_cluster") as Control).scale.x, 0.001),
		"mm_s": snappedf((hud.get_node("MinimapFrame") as Control).scale.x, 0.001),
		"goal_card": (_world.get("_goal_card") as Control).visible,
		"pill_box": (_world.get("_pill_box") as Control).visible,
		"objective": (obj as Control).visible or _p3_folded() if obj is Control else false,
		"portrait_tap": (ph as Control).visible if ph is Control else false,
	}

func _p3_flip_classic() -> void:
	_world._open_settings()
	_world._settings_show_tab("hud")
	await _p1_pframes(4)
	var page := _world.get("_settings_page") as Control
	var sw := page.find_child("ClassicLayoutSwitch", true, false) as Button
	if sw != null:
		sw.emit_signal("pressed")
	await _p1_pframes(4)
	_world._close_settings()
	await _p1_pframes(20)

func _p3_round_trip(tag: String) -> void:
	await _p1_settle_drafts()
	var s0 := _p3_layout_sig()
	await _p3_flip_classic()
	var s1 := _p3_layout_sig()
	await _p3_flip_classic()
	var s2 := _p3_layout_sig()
	_check("P3: classic switch flips the layout (" + tag + ")",
		s1["classic"] != s0["classic"] and s1["pause_btn"] != s0["pause_btn"]
		and s1["card_w"] != s0["card_w"] and s1["goal_card"] != s0["goal_card"]
		and s1["portrait_tap"] != s0["portrait_tap"],
		"before=" + str(s0) + " flipped=" + str(s1))
	_check("P3: classic switch round-trip restores the layout (" + tag + ")",
		str(s2) == str(s0), "before=" + str(s0) + " after=" + str(s2))

## D6 classic (21.3.2 geometry; the plan's one gate corner
## 2400 s1.00): the pre-P2 top band fit, the pause / aim
## column, the resident goal card — and none of the
## new layout's pieces. (U1 1:1 round 10: the lock button
## left the column — its home is the pause menu's quick row.)
func _p3_classic_state(vp: Vector2, st: String) -> void:
	var hud := _world.get("_hud_root") as Control
	var hero := _world.get("_hero_cluster") as Control
	var topc := _world.get("_top_card") as Control
	var mmf := hud.get_node_or_null("MinimapFrame") as Control
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var s := float(_world.call("_kr")) * float(GameProfile.setting("hudScale"))
	var want := minf(s, (ui_rect.size.x - 24.0) / 1368.0)
	var vis_ok := true
	for nm in ["_pw_row", "_zone_en", "_elapsed_label", "_dust_label"]:
		var c := _world.get(nm) as Control
		vis_ok = vis_ok and c != null and c.is_visible_in_tree()
	var badge = _world.get("_mm_expand")
	_check("P3 classic: 21.3.2 top band (" + st + ")",
		vis_ok and absf(topc.size.x - 726.0) < 0.5 and absf(hero.size.x - 454.0) < 0.5
		and absf(hero.scale.x - want) < 0.002 and absf(topc.scale.x - want) < 0.002
		and absf(mmf.scale.x - want) < 0.002
		and not (badge is Control and (badge as Control).is_visible_in_tree()),
		"s_top=" + str(hero.scale.x) + " card=" + str(topc.scale.x) + " mm=" + str(mmf.scale.x)
		+ " want=" + str(want) + " card_w=" + str(topc.size.x) + " collapsed_shown=" + str(vis_ok))
	var tc: Object = _world.get("touch_controls")
	if tc != null and (tc as Control).visible:
		var btns: Dictionary = tc.get("_buttons")
		var ts := float(tc.get("_scale_s"))
		var xs: Array = []
		var ok := true
		for k in ["pause", "aim"]:
			var ar := (btns[k] as Dictionary)["area"] as Control
			var r := _vis_rect(ar)
			xs.append(r.get_center().x)
			ok = ok and ar.visible and absf(r.size.x - 56.0 * ts) < 0.6 \
				and _vis_rect((btns[k] as Dictionary)["panel"] as Control).is_equal_approx(r)
		ok = ok and absf(float(xs[0]) - float(xs[1])) < 0.6
		_check("P3 classic: thumb cluster keeps the pause / aim column (" + st + ")",
			ok, "centres_x=" + str(xs) + " ts=" + str(ts))
	var obj = _world.get("_obj_pill")
	var ph = _world.get("_portrait_hit")
	var wh = _world.get("_wx_hit")
	_check("P3 classic: goal card resident, no objective pill / portrait tap (" + st + ")",
		(_world.get("_goal_card") as Control).is_visible_in_tree()
		and not (obj is Control and (obj as Control).is_visible_in_tree())
		and not _p3_folded()
		and not (ph is Control and (ph as Control).is_visible_in_tree())
		and not (wh is Control and (wh as Control).is_visible_in_tree()),
		"goal=" + str((_world.get("_goal_card") as Control).is_visible_in_tree()))

func _p3_classic_block(vp: Vector2) -> void:
	await _p1_settle_drafts()
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	var pl = _world.get("player")
	var dm0 := float(pl.damage_mult)
	pl.damage_mult = dm0 + 0.10
	var tt := await _p2_watch_banner(["伤害 ×"], 120)
	_check("P3 classic: no stat toast (the pw row is on screen)", tt == "", "seen=" + tt)
	pl.damage_mult = dm0
	await _p1_pframes(20)
	await _p3_round_trip("classic")

func _p3_desktop_state(st: String) -> void:
	var obj = _world.get("_obj_pill")
	var ph = _world.get("_portrait_hit")
	var tc: Object = _world.get("touch_controls")
	var btns: Dictionary = tc.get("_buttons") if tc != null else {}
	var col := true
	for k in ["pause", "aim"]:
		col = col and btns.has(k) and ((btns[k] as Dictionary)["area"] as Control).visible
	_check("P3 desktop: no phone-layout pieces (" + st + ")",
		not (obj is Control and (obj as Control).is_visible_in_tree()) and not _p3_folded()
		and not (ph is Control and (ph as Control).is_visible_in_tree())
		and (_world.get("_goal_card") as Control).is_visible_in_tree() and col,
		"column=" + str(col))

## P3 captures: the two plan combos get every P3 state; the
## P7 corners and the classic corner get hud_start + boss.
func _p3_snap(state: String) -> void:
	if _mode != "phone":
		return
	var corner := _classic or _hud > 0.0 or _mm > 0.0
	if (_p1_capture_combo() and not corner) or (corner and state in ["hud_start", "boss"]):
		await _snap("mobile_p3_" + state + "_" + _run_tag())

# ================================================== UI-mobile P4
## Plan §B4 P4 (Z6 / Z7): the BL cluster restores the original's
## two slot rows — moves (every learned move: type icon + Lv +
## cooldown sweep, lock slot at the row end) over vitamins (one
## 34 slot each: icon + level) — at s_bl = min(s, 1.35) anchored
## (12, vh - 12), width = the rows + the band's 2x8 overhang
## (U1 1:1 round 6; floor P4_SBL_FLOOR = minimum legible slot
## size in logical px, 36.8); the joystick ring clamps to Z7's
## bubble between the rows and the thumb cluster (right edge =
## cluster_left - 16, bottom = vh - 24, <= 2 lines, scale <= 1.4,
## a pointer toward the ❗ button). Parity: the slot rows and
## the pause status page read the same player data and move
## together. Slots are display only (plan I1 — the tappable HUD
## set is portrait / minimap / objective / weather).
## Interface read from world.gd: _bl_move_slots / _bl_vit_slots
## (Array of {panel, lv, key[, sweep]}), _bl_lock, _bl_rows,
## _prompt_tri (Polygon2D on the prompt backing).
const P4_BUBBLE_MIN := 300.0
## U1 1:1 round 6: the s_bl floor is a minimum legible slot size
## in logical px (pre-round-6: 46 x 0.8 = 36.8 px), not a scale —
## 36.8 / 130 ~= 0.28 at the new slot size. Must track world's
## P4_SBL_FLOOR exactly; the s_bl check asserts equality.
const P4_SBL_FLOOR := 0.28

func _p4_world() -> bool:
	return _world.get("_bl_move_slots") is Array

func _p4_mode() -> bool:
	return _p3_new() and _p4_world()

## Z7's drawn top: the BL cluster's rect (sized to the rows).
func _p4_slots_top(r_bl: Rect2) -> float:
	return r_bl.position.y

func _p4_num(t: String) -> int:
	var d := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			d += ch
	return int(d) if d != "" else -1

func _p4_vis_slots(nm: String) -> Array:
	var out: Array = []
	var a = _world.get(nm)
	if not (a is Array):
		return out
	for d in (a as Array):
		var pnl := (d as Dictionary)["panel"] as Control
		if pnl != null and pnl.is_visible_in_tree():
			out.append(d)
	return out

## Visible touch elements' leftmost drawn x (ring excluded) —
## the plan's cluster_left (global). INF when hidden.
func _p4_cluster_left() -> float:
	# The layer's own buttons (+ ult gauge), whether or not the
	# layer is showing — the world fits to the same geometry.
	var tc: Object = _world.get("touch_controls")
	if tc == null:
		return INF
	var m := INF
	var btns: Dictionary = tc.get("_buttons")
	for kind in btns.keys():
		var ar := (btns[kind] as Dictionary)["area"] as Control
		if ar.visible:
			m = minf(m, _vis_rect(ar).position.x)
	var ug := tc.get("ult_gauge") as Control
	if ug != null and ug.visible:
		m = minf(m, _vis_rect(ug).position.x)
	return m

## The ❗ button's drawn centre (global), or null.
func _p4_interact_centre():
	var tc: Object = _world.get("touch_controls")
	if tc == null or not (tc as Control).visible:
		return null
	var btns: Dictionary = tc.get("_buttons")
	if not btns.has("interact"):
		return null
	return _vis_rect((btns["interact"] as Dictionary)["panel"] as Control).get_center()

func _p4_state(vp: Vector2, st: String, prompt_state: bool) -> void:
	var bl := _world.get("_bl_cluster") as Control
	var ui_rect := (_world.get("_ui_root") as Control).get_global_rect()
	var pl = _world.get("player")
	var r_bl := _vis_rect(bl)
	var have := _p4_world()
	# -- parity: every move / vitamin has its slot, levels match
	var ms := _p4_vis_slots("_bl_move_slots")
	var mbad: Array = []
	if pl != null:
		for i in range(maxi(ms.size(), pl.moves.size())):
			if i >= ms.size() or i >= pl.moves.size():
				mbad.append("count")
				break
			var m: Dictionary = pl.moves[i]
			var d: Dictionary = ms[i]
			if String(d["key"]) != String(m["key"]) \
					or _p4_num(String((d["lv"] as Label).text)) != int(m["level"]):
				mbad.append("%s:%s" % [String(m["key"]), String((d["lv"] as Label).text)])
	_check("P4: all moves visible (" + st + ")", have and mbad.is_empty(),
		"slots=" + str(ms.size()) + " moves=" + str(pl.moves.size() if pl != null else -1)
		+ " bad=" + str(mbad) + ("" if have else " no _bl_move_slots"))
	var vs := _p4_vis_slots("_bl_vit_slots")
	var vbad: Array = []
	if pl != null:
		var vk: Array = pl.vit_levels.keys()
		if vk.size() != vs.size():
			vbad.append("count")
		for i in range(mini(vk.size(), vs.size())):
			var d2: Dictionary = vs[i]
			if String(d2["key"]) != String(vk[i]) \
					or _p4_num(String((d2["lv"] as Label).text)) != int(pl.vit_levels[vk[i]]):
				vbad.append("%s:%s" % [String(vk[i]), String((d2["lv"] as Label).text)])
	_check("P4: vitamins visible (" + st + ")", have and vbad.is_empty(),
		"slots=" + str(vs.size()) + " vits=" + str(pl.vit_levels.size() if pl != null else -1)
		+ " bad=" + str(vbad))
	# -- the cluster IS the two rows + the band's 8 px overhang:
	# anchored (23, vh-12), width = rows + 2x8, no legacy /
	# ult piece left in it (U1 1:1 round 6; round 10 moved the
	# anchor 12 -> 23 per the main-controller ruling: first
	# slot's left edge 31 design px, reference U1_final.jpg) ---
	var slot_rs: Array = []
	for d in ms + vs:
		slot_rs.append(_vis_rect((d as Dictionary)["panel"] as Control))
	var lk = _world.get("_bl_lock")
	var lock_r := Rect2()
	if lk is Control and (lk as Control).is_visible_in_tree():
		lock_r = _vis_rect(lk as Control)
		slot_rs.append(lock_r)
	# U1 1:1 round 4: the extra lock slots (2nd..nth) count
	# as row slots too; the last one ends row 1.
	for lp in _world.get("_bl_locks"):
		var lpc := lp as Control
		if lpc != null and lpc.is_visible_in_tree():
			var lr := _vis_rect(lpc)
			slot_rs.append(lr)
			lock_r = lr
	var right := -INF
	var encl := true
	for r in slot_rs:
		right = maxf(right, (r as Rect2).end.x)
		encl = encl and r_bl.grow(1.0).encloses(r as Rect2)
	var deep := _vis_rect_deep(bl)
	var ms_leg := _world.get("_move_slot") as Control
	_check("P4: BL cluster is exactly the slot rows (" + st + ")",
		have and not slot_rs.is_empty() and encl
		and absf(r_bl.position.x - (ui_rect.position.x + 23.0)) <= 1.0
		and absf(r_bl.end.y - (ui_rect.end.y - 12.0)) <= 1.0
		and absf(r_bl.end.x - right - 8.0 * bl.scale.x) <= 1.0
		and r_bl.grow(1.0).encloses(deep)
		and not ms_leg.is_visible_in_tree(),
		"bl=" + str(r_bl) + " deep=" + str(deep) + " rows_right=" + str(right)
		+ " legacy_move_slot=" + str(ms_leg.is_visible_in_tree()))
	# moves row above vitamins row; lock slots end row 1
	var order_ok := true
	for a in ms:
		for b in vs:
			order_ok = order_ok and _vis_rect(a["panel"]).end.y <= _vis_rect(b["panel"]).position.y + 0.5
	if lock_r.size.x > 0.0:
		for a in ms:
			var ra := _vis_rect(a["panel"])
			order_ok = order_ok and ra.end.x <= lock_r.position.x + 0.5 \
				and absf(ra.position.y - lock_r.position.y) < 1.0
	_check("P4: moves row over vitamins row, lock slots end row 1 (" + st + ")", order_ok)
	# -- s_bl = min(s, 1.35), narrowed only to keep the rows out
	# of the centre rect and the bubble's span >= 300 (floor 0.8)
	var s := float(_world.call("_kr")) * float(GameProfile.setting("hudScale"))
	var want := minf(s, 1.35)
	# centre rect (plan B0.2): rows past 0.30·vw must keep their
	# top at/below 0.85·vh (rows design height 192, U1 1:1 round 6;
	# round 10: the left-margin term tracks the new 23 anchor,
	# same bound, same strength — the bottom term stays 12.0)
	if bl.size.x > 0.0:
		want = minf(want, maxf((0.30 * ui_rect.size.x - 23.0) / bl.size.x,
			(0.15 * ui_rect.size.y - 12.0) / 192.0))
	var cl := _p4_cluster_left()
	if cl < INF and bl.size.x > 0.0:
		var s_fit := (cl - ui_rect.position.x - 16.0 - P4_BUBBLE_MIN - 16.0 - 23.0) / bl.size.x
		want = maxf(minf(want, s_fit), P4_SBL_FLOOR)
	var touch: Control = _world.get("touch_controls")
	if touch != null:
		var touch_scale := float(touch.get("_scale_s"))
		if touch_scale >= 0.999:
			var ring_bottom := touch.get_global_rect().end.y - 134.0 * touch_scale
			want = maxf(P4_SBL_FLOOR, minf(want, (ui_rect.end.y - 12.0 - ring_bottom) / 192.0))
	_check("P4: s_bl = min(s, 1.35, bubble fit) (" + st + ")",
		have and absf(bl.scale.x - want) < 0.002,
		"s_bl=" + str(bl.scale.x) + " want=" + str(want) + " W=" + str(bl.size.x))
	# -- slot text (D7 floors) + slots never take touches (I1) --
	var floor_g := _p2_floor(vp, 19.0)
	var tbad: Array = []
	var n_lab := 0
	for l in _p2_labels(bl):
		n_lab += 1
		if _p2_drawn(l) < floor_g - 0.01:
			tbad.append("%s=%.1f" % [String((l as Label).text).substr(0, 6), _p2_drawn(l)])
	_check("P4: slot text size (" + st + ")", have and n_lab > 0 and tbad.is_empty(),
		"floor=" + str(floor_g) + " labels=" + str(n_lab) + " below=" + str(tbad))
	var stop: Array = []
	var stack: Array = [bl]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).is_visible_in_tree() \
				and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			stop.append(n.name)
		for ch in n.get_children():
			stack.append(ch)
	_check("P4: slots pass touches through (" + st + ")", stop.is_empty(), str(stop))
	# -- pairwise: slots, BL x thumb cluster / ring / hero -------
	var sp: Array = []
	for i in range(slot_rs.size()):
		for j in range(i + 1, slot_rs.size()):
			if not _disjoint(slot_rs[i], slot_rs[j]):
				sp.append(str(i) + "x" + str(j))
	_check("P4: slots pairwise disjoint (" + st + ")", sp.is_empty(), str(sp))
	var hits: Array = []
	for e in _touch_elems():
		if not _disjoint(r_bl, _vis_rect(e[1] as Control)):
			hits.append(String(e[0]) + str(_vis_rect(e[1] as Control)))
	var hero_r := _vis_rect_deep(_world.get("_hero_cluster") as Control)
	if not _disjoint(r_bl, hero_r):
		hits.append("hero" + str(hero_r))
	_check("P4: BL rows x thumb cluster / ring / hero disjoint (" + st + ")",
		hits.is_empty(), "bl=" + str(r_bl) + " hits=" + str(hits))
	# -- ring vs Z7 (home is clamped by the slot rows) -----------
	var tc: Object = _world.get("touch_controls")
	if tc != null and (tc as Control).visible:
		var rr := _vis_rect(tc.get("_base_ring") as Control)
		_check("P4: ring clears slot rows (Z7 top) (" + st + ")",
			rr.end.y <= r_bl.position.y + 0.5,
			"ring_bottom=" + str(rr.end.y) + " z7_top=" + str(r_bl.position.y))
		var ts := float(tc.get("_scale_s"))
		if ts >= 0.999:
			var raw := (tc as Control).get_global_rect().end.y - 134.0 * ts
			_check("P4: ring home unmoved at touchScale >= 1 (" + st + ")",
				absf(rr.end.y - raw) <= 1.0,
				"ring_bottom=" + str(rr.end.y) + " raw=" + str(raw) + " z7_top=" + str(r_bl.position.y))
	# -- centre clear incl. the BL rows (and the bubble below) ---
	var cr := Rect2(ui_rect.position.x + 0.30 * ui_rect.size.x,
		ui_rect.position.y + 0.42 * ui_rect.size.y,
		0.40 * ui_rect.size.x, 0.43 * ui_rect.size.y)
	var prompt := _world.get("_prompt") as Label
	var has_pr := String(prompt.text) != ""
	var chits: Array = []
	if not _disjoint(r_bl, cr):
		chits.append("bl" + str(r_bl))
	if has_pr and not _disjoint(_prompt_rect(), cr):
		chits.append("prompt" + str(_prompt_rect()))
	_check("P4: centre clear incl. BL rows + bubble (" + st + ")", chits.is_empty(),
		"centre=" + str(cr) + " hits=" + str(chits))
	# -- the interaction bubble (Z6) -----------------------------
	if prompt_state or has_pr:
		_p4_bubble(st, r_bl, ui_rect)

func _p4_bubble(st: String, r_bl: Rect2, ui_rect: Rect2) -> void:
	var prompt := _world.get("_prompt") as Label
	var r_pr := _prompt_rect()
	var cl := _p4_cluster_left()
	var span_l := r_bl.end.x + 16.0
	var span_r := cl - 16.0
	_check("P4: prompt width (bubble span >= 300) (" + st + ")",
		cl < INF and span_r - span_l >= P4_BUBBLE_MIN,
		"span=" + str(Vector2(span_l, span_r)) + " w=" + str(span_r - span_l))
	_check("P4: prompt inside its span (" + st + ")",
		r_pr.position.x >= span_l - 1.0 and r_pr.end.x <= span_r + 1.0,
		"prompt=" + str(r_pr) + " span=" + str(Vector2(span_l, span_r)))
	_check("P4: bubble right edge = cluster_left - 16 (" + st + ")",
		absf(r_pr.end.x - span_r) <= 1.5, "right=" + str(r_pr.end.x) + " want=" + str(span_r))
	_check("P4: bubble bottom = vh - 24 (" + st + ")",
		absf(r_pr.end.y - (ui_rect.end.y - 24.0)) <= 1.5,
		"bottom=" + str(r_pr.end.y) + " want=" + str(ui_rect.end.y - 24.0))
	var lc := prompt.get_line_count()
	_check("P4: prompt <= 2 lines, all visible (" + st + ")",
		prompt.max_lines_visible == 2 and lc <= 2 and lc >= 1
		and prompt.get_visible_line_count() == lc,
		"lines=" + str(lc) + " vis=" + str(prompt.get_visible_line_count())
		+ " cap=" + str(prompt.max_lines_visible) + " text=" + prompt.text)
	_check("P4: bubble scale <= 1.4 (" + st + ")", prompt.scale.x <= 1.4 + 0.001,
		"scale=" + str(prompt.scale.x))
	var hits: Array = []
	for e in _touch_elems():
		if not _disjoint(r_pr, _vis_rect(e[1] as Control)):
			hits.append(String(e[0]))
	_check("P4: prompt x thumb cluster / ring disjoint (" + st + ")", hits.is_empty(),
		"prompt=" + str(r_pr) + " hits=" + str(hits))
	_check("P4: prompt x BL cluster disjoint (" + st + ")",
		_disjoint(r_pr, _vis_rect_deep(_world.get("_bl_cluster") as Control).merge(r_bl)),
		str(r_pr) + " vs " + str(r_bl))
	# pointer: a triangle on the backing's right edge, tip in
	# the 16 px gap, aimed at the ❗ centre's y (clamped)
	var tri = _world.get("_prompt_tri")
	var back := _world.get("_prompt_back") as Control
	var ic = _p4_interact_centre()
	var tok := false
	var tdet := "no _prompt_tri"
	if tri is Polygon2D and (tri as Polygon2D).is_visible_in_tree() and ic != null:
		var t := (tri as Polygon2D).get_global_transform()
		var pts: PackedVector2Array = (tri as Polygon2D).polygon
		var tip := t * pts[0]
		for p in pts:
			if (t * p).x > tip.x:
				tip = t * p
		var rb := _vis_rect(back)
		var pad := 10.0 * back.scale.y
		var want_y := clampf((ic as Vector2).y, rb.position.y + pad, rb.end.y - pad)
		tok = tip.x > rb.end.x + 1.0 and tip.x <= cl - 1.0 and absf(tip.y - want_y) <= 2.0
		tdet = "tip=" + str(tip) + " back=" + str(rb) + " ic=" + str(ic) + " want_y=" + str(want_y)
	_check("P4: bubble pointer aims at the interact button (" + st + ")", tok, tdet)

## Classic (D6) and desktop: the 21.3.2 BL cluster untouched.
func _p4_legacy_state(st: String, tag: String) -> void:
	var bl := _world.get("_bl_cluster") as Control
	var s := float(_world.call("_kr")) * float(GameProfile.setting("hudScale"))
	var rows = _world.get("_bl_rows")
	var tri = _world.get("_prompt_tri")
	_check(tag + ": legacy BL cluster unchanged (" + st + ")",
		absf(bl.size.x - 460.0) < 0.5 and absf(bl.size.y - 118.0) < 0.5
		and absf(bl.offset_left) < 0.5 and absf(bl.scale.x - s) < 0.002
		and (_world.get("_move_slot") as Control).is_visible_in_tree()
		and not (rows is Control and (rows as Control).is_visible_in_tree())
		and not (tri is Polygon2D and (tri as Polygon2D).is_visible_in_tree()),
		"size=" + str(bl.size) + " scale=" + str(bl.scale.x) + " s=" + str(s))

func _p4_status_texts() -> Array:
	var out: Array = []
	var pages: Dictionary = _world.get("_pause_pages")
	var stack: Array = [pages["status"]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label and not n.is_queued_for_deletion():
			out.append(String((n as Label).text))
		for ch in n.get_children():
			stack.append(ch)
	return out

## Pause status page lists exactly what the slot rows show.
func _p4_parity(tag: String) -> void:
	var pl = _world.get("player")
	await _p3_ready()
	_world._open_pause()
	await _p1_pframes(4)
	_world._pause_show_tab(0)
	await _p1_pframes(4)
	var texts := _p4_status_texts()
	var miss: Array = []
	for m in pl.moves:
		var want := "%s %d级" % [String(_world.call("_move_zh", String(m["key"]))), int(m["level"])]
		if not _p3_has_text(texts, want):
			miss.append(want)
	for vk in pl.vit_levels.keys():
		var want2 := "%s %d级" % [String(GameData.VITAMINS[vk]["label"]), int(pl.vit_levels[vk])]
		if not _p3_has_text(texts, want2):
			miss.append(want2)
	var ms := _p4_vis_slots("_bl_move_slots")
	var vs := _p4_vis_slots("_bl_vit_slots")
	var pages: Dictionary = _world.get("_pause_pages")
	var shown := String(_world.get("state")) == "pause" and (pages["status"] as Control).is_visible_in_tree()
	_check("P4: slot rows and pause page agree (" + tag + ")",
		_p4_world() and shown and miss.is_empty() and ms.size() == pl.moves.size()
		and vs.size() == pl.vit_levels.size(),
		"missing_on_page=" + str(miss) + " slots=" + str(ms.size()) + "/" + str(vs.size())
		+ " page_shown=" + str(shown) + " labels=" + str(texts.size()))
	_world._close_pause()
	await _p1_pframes(6)

func _p4_move_pool(pl) -> Array:
	var out: Array = []
	for sp in ["bulbasaur", "charmander", "squirtle", "pikachu", "pidgey", "geodude", "abra", "machop"]:
		for pair in GameData.learnset(sp):
			var k := String(pair[0])
			var md: Dictionary = GameData.move(k)
			if GameData.move_is_draftable(k) and md.get("power") != null and int(md["power"]) > 0 \
					and not pl.has_move(k) and not out.has(k):
				out.append(k)
	return out

## The XP freeze does not survive a build injection:
## _grant_vitamin -> player.recalc() rebuilds xp_mult (>= 1),
## and a level-up draft then opens mid-sample (prompt "" while
## state == "draft" — the P4 full-slots red, it2 a). Re-pin
## after every injection.
func _p4_freeze_xp(pl) -> void:
	pl.xp_mult = 0.0
	pl.xp = 0.0

## A prompt sample is read only in live play (no modal); an
## empty sample logs the state it was taken in.
func _p4_prompt_live(where: String) -> bool:
	await _p3_ready()
	await _frames(2)
	var t := String(_world.get("_prompt").text)
	var modal := bool(_world.call("_any_modal_open"))
	if t == "" or modal:
		print("PHONEHUD INFO P4 full-slots prompt sample at ", where, ": state=", String(_world.get("state")),
			" modal=", modal, " text=", t)
	return t != "" and not modal

func _p4_any_prompt() -> bool:
	for kind in ["meowth", "slots", "cage", "rock", "berry", "chest", "freechest", "snorlax"]:
		var p := _prop_of_kind(kind)
		if p.is_empty():
			continue
		_teleport_near(p, 2.0)
		await _frames(30)
		if await _p4_prompt_live(kind):
			return true
	# The boss step set zone = 3 (its props are not in this
	# scene): the altar always prompts (summon / 击败守护者).
	var pl = _world.get("player")
	var av = _world.get("ALTAR_XZ")
	var a: Vector2 = av if av is Vector2 else Vector2(0, -30)
	pl.global_position = Vector3(a.x + 1.5, float(_world.call("height_at", a.x + 1.5, a.y)) + 0.1, a.y)
	await _frames(30)
	return await _p4_prompt_live("altar")

func _p4_phone_block(vp: Vector2) -> void:
	await _p3_ready()
	var pl = _world.get("player")
	var tc: Object = _world.get("touch_controls")
	var xpm0 := float(pl.xp_mult)
	pl.xp_mult = 0.0
	pl.xp = 0.0
	var moves0: Array = pl.moves.duplicate(true)
	var vl0: Dictionary = pl.vit_levels.duplicate(true)
	var vit0: Dictionary = pl.vit.duplicate(true)
	# ---- plan capture p4_moves3_vits2 --------------------------
	var pool := _p4_move_pool(pl)
	while pl.moves.size() < 3 and not pool.is_empty():
		pl.learn_move(String(pool.pop_front()))
	var vkeys: Array = GameData.VITAMINS.keys()
	pl.vit_levels.clear()
	pl.vit.clear()
	_world.call("_grant_vitamin", String(vkeys[0]), 1.0)
	_world.call("_grant_vitamin", String(vkeys[0]), 1.0)
	_world.call("_grant_vitamin", String(vkeys[1]), 1.0)
	_p4_freeze_xp(pl)
	await _p1_pframes(12)
	await _p3_ready()
	_assert_state(vp, "moves3_vits2", false)
	await _p3_ready()
	await _p4_snap("moves3_vits2")
	await _p4_parity("moves3_vits2")
	# ---- one build change reaches both homes together ----------
	await _p3_ready()
	var mk := String(pl.moves[pl.moves.size() - 1]["key"])
	var mlv0 := int(pl.moves[pl.moves.size() - 1]["level"])
	pl.upgrade_move(mk, 1.0)
	_world.call("_grant_vitamin", String(vkeys[1]), 1.0)
	_p4_freeze_xp(pl)
	await _p1_pframes(12)
	var ms := _p4_vis_slots("_bl_move_slots")
	var vs := _p4_vis_slots("_bl_vit_slots")
	var lv_hud := _p4_num(String((ms[ms.size() - 1]["lv"] as Label).text)) if not ms.is_empty() else -1
	var vlv_hud := _p4_num(String((vs[1]["lv"] as Label).text)) if vs.size() >= 2 else -1
	_check("P4: a build change reaches the HUD slots",
		lv_hud == int(pl.moves[pl.moves.size() - 1]["level"]) and vlv_hud == int(pl.vit_levels[vkeys[1]])
		and lv_hud == mlv0 + 1 and vlv_hud == 2,
		"move " + mk + " hud=" + str(lv_hud) + " vit hud=" + str(vlv_hud))
	await _p4_parity("after level-up")
	# ---- cooldown sweep reads cd_t ------------------------------
	await _p3_ready()
	ms = _p4_vis_slots("_bl_move_slots")
	var swept := false
	var sdet := "no slot"
	if not ms.is_empty():
		var i := 0
		var m: Dictionary = pl.moves[i]
		var cdmax := float(GameData.ARCH_CD[GameData.archetype(String(m["key"]))]) / maxf(float(pl.atk_speed), 0.01)
		var sw = (ms[i] as Dictionary).get("sweep")
		# (a) pinned: a cooldown far past its max reads a full sweep
		m["cd_t"] = cdmax * 50.0
		await get_tree().process_frame
		await get_tree().process_frame
		var fr_full := float((sw as Control).get_meta("frac", -1.0)) if sw is Control else -1.0
		# (b) running: the sweep is drawn from cd_t as of its last
		# render frame — physics ticks between that frame and this
		# read only lower cd_t, so frac sits in [now, now + 0.25 s]
		m["cd_t"] = cdmax * 0.6
		await get_tree().process_frame
		await get_tree().process_frame
		var fr := float((sw as Control).get_meta("frac", -1.0)) if sw is Control else -1.0
		var want_f := clampf(float(m["cd_t"]) / cdmax, 0.0, 1.0)
		var hi := clampf((float(m["cd_t"]) + 0.25) / cdmax, 0.0, 1.0)
		swept = sw is Control and (sw as Control).is_visible_in_tree() and absf(fr_full - 1.0) < 0.001 \
			and fr > 0.0 and fr >= want_f - 0.02 and fr <= hi + 0.02
		sdet = "full=" + str(fr_full) + " frac=" + str(fr) + " cd_t/max=" + str(want_f) \
			+ " window_hi=" + str(hi) + " cdmax=" + str(cdmax)
	_check("P4: cooldown sweep reads cd_t", swept, sdet)
	# ---- a touch on a slot drives the stick (display only, I1)
	await _p3_ready()
	var fs0 := bool(tc.get("fixed_stick"))
	tc.set("fixed_stick", false)
	var tgt := Vector2.ZERO
	if not ms.is_empty():
		tgt = _vis_rect(ms[0]["panel"]).get_center()
	var joy := -1
	if not ms.is_empty():
		_p1_touch(0, tgt, true)
		await _p1_pframes(3)
		joy = int(tc.get("_joy_id"))
		_p1_touch(0, tgt, false)
		await _p1_pframes(3)
	tc.set("fixed_stick", fs0)
	_check("P4: a touch on a slot drives the stick (slots display only)",
		not ms.is_empty() and joy != -1 and String(_world.get("state")) != "pause",
		"at=" + str(tgt) + " joy_id=" + str(joy) + " state=" + String(_world.get("state")))
	# ---- full slots (move cap, every vitamin) + a prompt --------
	await _p3_ready()
	pool = _p4_move_pool(pl)
	while pl.moves.size() < int(pl.move_cap()) and not pool.is_empty():
		pl.learn_move(String(pool.pop_front()))
	for vk in vkeys:
		if not pl.vit_levels.has(vk):
			_world.call("_grant_vitamin", String(vk), 1.0)
	_p4_freeze_xp(pl)
	await _p1_pframes(12)
	await _p3_ready()
	_check("P4: full rows injected", pl.moves.size() >= 8 and pl.vit_levels.size() == vkeys.size(),
		"moves=" + str(pl.moves.size()) + " vits=" + str(pl.vit_levels.size()))
	_assert_state(vp, "full_slots", false)
	await _p3_ready()
	await _p4_snap("full_slots")
	var got := await _p4_any_prompt()
	_check("P4: a prompt in the full-slots state", got, String(_world.get("_prompt").text))
	if got:
		await _p3_ready()
		_assert_state(vp, "full_prompt", true)
		await _p4_snap("full_prompt")
	# ---- D6 round trip keeps the rows ---------------------------
	var bl := _world.get("_bl_cluster") as Control
	var r0 := _vis_rect(bl)
	await _p3_flip_classic()
	_p4_legacy_state("round trip", "P4 classic")
	await _p3_flip_classic()
	await _p1_pframes(6)
	var r2 := _vis_rect(bl)
	_check("P4: classic round trip restores the slot rows",
		r2.is_equal_approx(r0) and _p4_vis_slots("_bl_move_slots").size() == pl.moves.size(),
		"before=" + str(r0) + " after=" + str(r2))
	# ---- restore the build ------------------------------------
	pl.moves = moves0
	pl.vit_levels = vl0
	pl.vit = vit0
	pl.recalc()
	pl.xp_mult = xpm0
	await _p1_pframes(12)

## P4 captures: the two plan combos (2400 s1.00 i0, 1920 s1.50
## i48) get every P4 state (no-items hud_start / moves3_vits2 /
## full rows, chest / meowth / full-rows prompts).
func _p4_snap(state: String) -> void:
	if _mode != "phone" or _classic or _hud > 0.0 or _mm > 0.0:
		return
	if _p1_capture_combo():
		await _snap("mobile_p4_" + state + "_" + _run_tag())

# ================================================== UI-mobile P5
## Plan §B4 P5 + §B3 (modal family + main menu): M0 — every modal
## panel scales at s_m = min(s, (vh - 16) / H_design) with its width
## flowing to the screen (W = min(W_max, (vw - 24) / s_m)) instead of
## the 4:3 fit clamp; modal text drawn >= 21 (tag chips >= 17), every
## modal Button drawn >= 76 tall (the primary >= 83), the primary
## action (继续 / 离开 / 开始 / 关闭 / 返回菜单 / the choice foot) in
## the bottom-right quadrant, the destructive pause action top-left;
## the loadout grid's portraits inside their tiles; the main menu in
## a design Control scaled >= 1.5 on phone (== 1 on desktop). Each
## modal must have a working close path (pressed for real where it
## does not leave the run), and the banner clock stays frozen under
## each one (the P1 rule, now per modal). Desktop runs the same visits
## and asserts the legacy geometry (scale 1, the shipped offsets).
## Phone modals follow the phone factor in BOTH layouts (D6 classic
## is a HUD arrangement; the modal family has one phone form).
## Captures mobile_p5_<state>_<tag>.png (two plan combos + the plan's
## 1920 s1.00 i48 combo).
const P5_TEXT := 21.0
const P5_TAG := 17.0
const P5_BTN := 76.0
const P5_PRIMARY := 83.0
const P5_TAP := 70.0
const P5_PRIMARY_TXT := {"pause": "继续", "meowth": "离开", "sound": "关闭",
	"lab": "关闭", "shop": "关闭", "unlock": "关闭", "wallet": "关闭",
	"bigmap": "关闭", "result": "返回菜单", "loadout": "开始"}
## Desktop legacy offsets (shipped C21.3.2 / P4 tree): W x H.
const P5_LEGACY := {"draft": Vector2(860, 452), "blessing": Vector2(860, 396),
	"choice": Vector2(860, 380), "meowth": Vector2(860, 430),
	"pause": Vector2(780, 540), "bigmap": Vector2(780, 610),
	"result": Vector2(700, 580), "lab": Vector2(660, 560),
	"shop": Vector2(600, 504), "sound": Vector2(740, 570),
	"wallet": Vector2(560, 248), "unlock": Vector2(660, 560),
	"loadout": Vector2(1090, 636)}

func _p5_phone() -> bool:
	return _mode == "phone"

func _p5_panel(name: String) -> Control:
	if name == "loadout":
		var lp := _world.get("_loadout_panel") as Control
		if lp != null:
			for c in lp.get_children():
				if c is PanelContainer:
					return c
		return null
	return _world.get("_" + name + "_panel") as Control

func _p5_snap(state: String) -> void:
	if _mode != "phone" or _classic or _hud > 0.0 or _mm > 0.0:
		return
	var tag := _run_tag()
	if _p1_capture_combo() or tag == "1920x1080_s100_i48_0_0_0":
		await _snap("mobile_p5_" + state + "_" + tag)

func _p5_ui_rect() -> Rect2:
	return (_world.get("_ui_root") as Control).get_global_rect()

## The panel's drawn footprint: visible descendants, but not the
## contents of scroll / clipping containers (their overflow is
## clipped, not drawn) — the container itself counts.
func _p5_rect(c: Control) -> Rect2:
	var out := _vis_rect(c)
	var stack: Array = []
	for ch in c.get_children():
		stack.append(ch)
	while not stack.is_empty():
		var n = stack.pop_back()
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var cn := n as Control
		if cn.size.x > 0.0 and cn.size.y > 0.0:
			out = out.merge(_vis_rect(cn))
		if cn is ScrollContainer or cn.clip_contents:
			continue
		for ch in cn.get_children():
			stack.append(ch)
	return out

## INFO only (no verdict): on an overflow, the visible subtree's
## combined minimum sizes (design px) — which piece forces the
## panel past its M0 W / H.
func _p5_dump_min(panel: Control, key: String) -> void:
	print("PHONEHUD INFO P5 overflow ", key, " p5_w=", panel.get_meta("p5_w", -1),
		" scale=", panel.scale.x, " size=", panel.size)
	var stack: Array = [[panel, 0]]
	var n_out := 0
	while not stack.is_empty() and n_out < 120:
		var e: Array = stack.pop_back()
		var c := e[0] as Control
		var d := int(e[1])
		if c == null or not c.is_visible_in_tree():
			continue
		var tx := ""
		if c is Label:
			tx = String((c as Label).text).substr(0, 16)
		elif c is Button:
			tx = String((c as Button).text).substr(0, 16)
		print("PHONEHUD INFO P5 min ", "  ".repeat(d), c.get_class(), " '", tx, "' min=",
			c.get_combined_minimum_size(), " size=", c.size)
		n_out += 1
		if d >= 7:
			continue
		for ch in c.get_children():
			if ch is Control:
				stack.append([ch, d + 1])

func _p5_is_tag(l: Label) -> bool:
	var p := l.get_parent()
	return p is PanelContainer and p.get_child_count() == 1

## [min drawn text px, offender, min drawn tag px, tag offender, count]
func _p5_text_scan(root: Control) -> Array:
	var mn := INF
	var who := ""
	var mt := INF
	var twho := ""
	var n_items := 0
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		var fs := -1.0
		var txt := ""
		var tag := false
		if n is Label:
			txt = String((n as Label).text).strip_edges()
			fs = float((n as Label).get_theme_font_size("font_size"))
			tag = _p5_is_tag(n)
		elif n is Button:
			txt = String((n as Button).text).strip_edges()
			fs = float((n as Button).get_theme_font_size("font_size"))
		elif n is LineEdit:
			txt = String((n as LineEdit).placeholder_text) + String((n as LineEdit).text)
			fs = float((n as LineEdit).get_theme_font_size("font_size"))
		if txt != "" and fs > 0.0:
			var drawn: float = fs * absf((n as Control).get_global_transform().get_scale().y)
			n_items += 1
			if tag:
				if drawn < mt:
					mt = drawn
					twho = txt.substr(0, 24)
			elif drawn < mn:
				mn = drawn
				who = txt.substr(0, 24)
		for ch in (n as Node).get_children():
			stack.append(ch)
	return [mn, who, mt, twho, n_items]

func _p5_buttons(root: Control) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		if n is Button:
			out.append(n)
		for ch in (n as Node).get_children():
			stack.append(ch)
	return out

func _p5_btn_text(b: Button) -> String:
	var t := String(b.text)
	if t == "" and b.has_meta("label"):
		t = String((b.get_meta("label") as Label).text)
	return t

func _p5_primary(name: String, panel: Control) -> Button:
	if name == "choice":
		var f := _world.get("_choice_foot") as Button
		return f if f != null and f.is_visible_in_tree() else null
	if not P5_PRIMARY_TXT.has(name):
		return null
	var kw := String(P5_PRIMARY_TXT[name])
	for b in _p5_buttons(panel):
		if _p5_btn_text(b).begins_with(kw):
			return b
	return null

## The full P5 set on one open modal (phone).
func _p5_modal(vp: Vector2, name: String, st: String) -> void:
	var panel := _p5_panel(name)
	var lab := "P5: "
	var key := name + "/" + st
	if panel == null or not panel.is_visible_in_tree():
		_check(lab + "modal open (" + key + ")", false, "panel missing or hidden")
		return
	_assert_modal(vp, key)
	# Panel node scale is a content-fit factor, not touchScale. Large
	# map/result panels can fit below 1.50 while keeping the same
	# measured 21/17 px text, 76/83 px buttons, and safe-area bounds.
	# Keep a positive floor here; the visible-size gates below are the
	# acceptance criteria for every profile, including touchScale 1.50.
	var modal_scale_floor := 0.50
	_check(lab + "modal scale (" + key + ")", panel.scale.x >= modal_scale_floor,
		"scale=" + str(snappedf(panel.scale.x, 0.001))
		+ " floor=" + str(modal_scale_floor))
	var pr := _p5_rect(panel)
	var ui := _p5_ui_rect()
	_check(lab + "modal inside UI area (" + key + ")", _inside(pr, ui),
		str(pr) + " ui=" + str(ui))
	if not _inside(pr, ui):
		_p5_dump_min(panel, key)
	var ts := _p5_text_scan(panel)
	_check(lab + "modal text (" + key + ")",
		int(ts[4]) > 0 and float(ts[0]) >= P5_TEXT - 0.01 and (float(ts[2]) == INF or float(ts[2]) >= P5_TAG - 0.01),
		"min=" + str(snappedf(float(ts[0]), 0.1)) + " '" + String(ts[1]) + "' tag_min="
		+ str(snappedf(float(ts[2]), 0.1)) + " '" + String(ts[3]) + "' items=" + str(ts[4]))
	var prim := _p5_primary(name, panel)
	var low := INF
	var lwho := ""
	for b in _p5_buttons(panel):
		var h := _vis_rect(b).size.y
		var need := P5_PRIMARY if b == prim else P5_BTN
		if h < need - 0.01 and h < low:
			low = h
			lwho = _p5_btn_text(b).substr(0, 20) + (" (primary)" if b == prim else "")
	_check(lab + "modal buttons (" + key + ")", low == INF,
		"short=" + (lwho + " h=" + str(snappedf(low, 0.1)) if low != INF else "none"))
	# Sliders are drag targets: their tap band >= 70 too.
	var sl_low := INF
	var stack: Array = [panel]
	while not stack.is_empty():
		var n = stack.pop_back()
		if not (n is Control) or not (n as Control).is_visible_in_tree():
			continue
		if n is HSlider:
			sl_low = minf(sl_low, _vis_rect(n).size.y)
		for ch in (n as Node).get_children():
			stack.append(ch)
	if sl_low != INF:
		_check(lab + "modal sliders tap band >= 70 (" + key + ")", sl_low >= P5_TAP - 0.01,
			"min_h=" + str(snappedf(sl_low, 0.1)))
	if P5_PRIMARY_TXT.has(name) or name == "choice":
		var c := _vis_rect(prim).get_center() if prim != null else Vector2(-1, -1)
		_check(lab + "primary action bottom-right (" + key + ")",
			prim != null and c.x > 0.6 * vp.x and c.y > 0.6 * vp.y,
			("'" + _p5_btn_text(prim) + "' centre=" + str(c.round())) if prim != null else "no primary found")

## Banner clock under an open modal (P1 rule, per modal).
func _p5_banner_frozen(key: String) -> void:
	var t0 := float(_world.get("_banner_t"))
	for i in range(20):
		await get_tree().process_frame
	var t1 := float(_world.get("_banner_t"))
	_check("P5: banner frozen under " + key, t0 > 0.0 and absf(t1 - t0) < 0.001,
		"t0=" + str(t0) + " t1=" + str(t1))

func _p5_probe_banner() -> void:
	_world.set("_banner_q", [])
	_world.set("_banner_t", 0.0)
	_world.show_banner("P5 冻结探针", 600.0)
	await _frames(2)

## Press a primary / close button for real and require the modal
## to close (the explicit close path).
func _p5_close_path(name: String, key: String) -> void:
	var panel := _p5_panel(name)
	var prim := _p5_primary(name, panel)
	if prim != null:
		prim.emit_signal("pressed")
	await _p1_pframes(6)
	_check("P5: close path closes (" + key + ")",
		prim != null and panel != null and not panel.is_visible_in_tree(),
		("pressed '" + _p5_btn_text(prim) + "'") if prim != null else "no close button")

func _p5_desktop_modal(name: String, st: String) -> void:
	var panel := _p5_panel(name)
	var lg: Vector2 = P5_LEGACY[name]
	var w := panel.offset_right - panel.offset_left if panel else -1.0
	var h := panel.offset_bottom - panel.offset_top if panel else -1.0
	_check("P5 desktop: modal legacy geometry (" + name + "/" + st + ")",
		panel != null and absf(panel.scale.x - 1.0) < 0.001
		and absf(w - lg.x) < 0.5 and absf(h - lg.y) < 0.5,
		"scale=" + (str(panel.scale.x) if panel else "-") + " wh=" + str(Vector2(w, h)) + " want=" + str(lg))

func _p5_check(vp: Vector2, name: String, st: String) -> void:
	if _p5_phone():
		_p5_modal(vp, name, st)
	else:
		_p5_desktop_modal(name, st)

## ---- main menu + menu overlays (boot, menu state) ----------------
func _p5_menu_button(kw: String) -> Button:
	var mp := _world.get("_menu_panel") as Control
	var stack: Array = [mp]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is Button:
			for ch in (n as Node).get_children():
				if ch is Label and String((ch as Label).text).begins_with(kw):
					return n
		for ch in (n as Node).get_children():
			stack.append(ch)
	return null

func _p5_menu_block(vp: Vector2) -> void:
	await _frames(20)
	var md = _world.get("_menu_design")
	var mdc := md as Control if md is Control else null
	if _p5_phone():
		_check("P5: menu scaled", mdc != null and mdc.scale.x >= 1.5,
			"scale=" + (str(snappedf(mdc.scale.x, 0.001)) if mdc else "no _menu_design"))
		if mdc != null:
			var mr := _p5_rect(mdc)
			_check("P5: menu inside UI area", _inside(mr, _p5_ui_rect()),
				str(mr) + " ui=" + str(_p5_ui_rect()))
			var ts := _p5_text_scan(mdc)
			var wordmark := mdc.get_node_or_null("MenuLogo/LogoArt/Wordmark") as Label
			_check("P5: U2 wordmark keeps its cream face",
				wordmark != null and UiTheme.luminance(wordmark.get_theme_color("font_color")) >= 0.8,
				str(wordmark.get_theme_color("font_color")) if wordmark != null else "wordmark missing")
			_check("P5: menu text",
				float(ts[0]) >= P5_TEXT - 0.01 and (float(ts[2]) == INF or float(ts[2]) >= P5_TAG - 0.01),
				"min=" + str(snappedf(float(ts[0]), 0.1)) + " '" + String(ts[1]) + "' tag_min="
				+ str(snappedf(float(ts[2]), 0.1)) + " '" + String(ts[3]) + "'")
			var low := INF
			var lwho := ""
			for b in _p5_buttons(mdc):
				# U2: the two resource pills are reference-sized info
				# counters (52 ref px tall per the U2 ref measurement),
				# not labelled action buttons; the 76 floor is for those.
				if (b as Control).get_parent() != null and (b as Control).get_parent().name == "Resources":
					continue
				var h := _vis_rect(b).size.y
				if h < low:
					low = h
					lwho = _p5_btn_text(b).substr(0, 16)
			_check("P5: menu buttons >= 76", low >= P5_BTN - 0.01,
				"min_h=" + str(snappedf(low, 0.1)) + " '" + lwho + "'")
			# Every top-level menu piece (title, subtitle, starter
			# column, the six items, hero card, hint) disjoint.
			var pieces: Array = []
			for ch in mdc.get_children():
				if ch is Control and (ch as Control).is_visible_in_tree() and (ch as Control).size.x > 0.0:
					pieces.append(ch)
			var clash := ""
			for i in range(pieces.size()):
				for j in range(i + 1, pieces.size()):
					var a: Control = pieces[i]
					var b2: Control = pieces[j]
					# The hint label rides on its own backing panel.
					if (a is Panel and b2 is Label) or (a is Label and b2 is Panel):
						if _vis_rect(a).encloses(_vis_rect(b2)) or _vis_rect(b2).encloses(_vis_rect(a)):
							continue
					if not _disjoint(_vis_rect(a), _vis_rect(b2)):
						clash = a.get_class() + str(_vis_rect(a).position.round()) + " x " \
							+ b2.get_class() + str(_vis_rect(b2).position.round())
						break
				if clash != "":
					break
			_check("P5: menu pieces pairwise disjoint", clash == "" and pieces.size() >= 8,
				"pieces=" + str(pieces.size()) + " " + clash)
			var entry_positions := {}
			for entry_name in ["MenuWallet", "MenuLab", "MenuShop", "MenuChallenge", "MenuSettings"]:
				entry_positions[entry_name] = _p5_rect(mdc.get_node(entry_name)).position
			_world.call("_apply_ui_scale")
			await _frames(4)
			var drifting: Array[String] = []
			for entry_name in entry_positions:
				if _p5_rect(mdc.get_node(entry_name)).position.distance_to(entry_positions[entry_name]) > 1.0:
					drifting.append(entry_name)
			_check("P5: menu entry positions survive relayout", drifting.is_empty(), str(drifting))
			var inset_pairs: Array = []
			var lab_rect := _vis_rect(mdc.get_node("MenuLab"))
			_check("P5: left menu card keeps reference proportions",
				absf(lab_rect.size.x / lab_rect.size.y - 224.0 / 185.0) < 0.02, str(lab_rect.size))
			for entry_name in ["MenuLab", "MenuShop", "MenuChallenge", "MenuSettings"]:
				var entry := mdc.get_node(entry_name) as Control
				inset_pairs.append([entry.get_node("MenuEntryArt"), entry])
				inset_pairs.append([entry.get_child(1), entry])
			for content_path in ["MenuWallet/MenuWalletArt", "MenuWallet/WalletChip",
					"MenuShake/MenuShakeIcon", "MenuShake/MenuShakeText"]:
				var content := mdc.get_node(content_path) as Control
				var content_back := mdc.get_node("MenuWallet/MenuWalletFace") if content_path.begins_with("MenuWallet/") else content.get_parent()
				inset_pairs.append([content, content_back])
			inset_pairs.append([mdc.get_node("MenuShake/ShakeSwitch/SwitchTrack"), mdc.get_node("MenuShake")])
			inset_pairs.append([mdc.get_node("MenuWallet").get_child(1), mdc.get_node("MenuWallet/MenuWalletFace")])
			inset_pairs.append([mdc.get_node("StartCaption"), mdc.get_node("StartCaptionBack")])
			var crowded: Array[String] = []
			for pair in inset_pairs:
				if not _inside(_vis_rect(pair[0]), _vis_rect(pair[1]).grow(-6.0)):
					crowded.append(String(pair[0].name))
			_check("P5: menu icons and text keep inner padding", crowded.is_empty(), str(crowded))
		await _p5_snap("menu")
	else:
		_check("P5 desktop: menu design unscaled", mdc == null or absf(mdc.scale.x - 1.0) < 0.001,
			"scale=" + (str(mdc.scale.x) if mdc else "none (legacy tree)"))
		var fc := _world.get("_first_starter_card") as Control
		_check("P5 desktop: menu starter card keeps its spot",
			fc != null and _vis_rect(fc).position.distance_to(Vector2(358, 470)) < 1.5,
			str(_vis_rect(fc).position) if fc else "none")
	# The menu overlays, opened through their menu items.
	for row in [["wallet", "钱包"], ["lab", "实验室"], ["shop", "萤尘商店"],
			["unlock", "伙伴营挑战"], ["sound", "设置"]]:
		var nm := String(row[0])
		var mb := _p5_menu_button(String(row[1]))
		if mb == null:
			_check("P5: menu item for " + nm, false, "button not found")
			continue
		mb.emit_signal("pressed")
		await _p1_pframes(8)
		if nm == "lab":
			_p5_check(vp, nm, "upgrades")
			await _p5_snap("lab_upgrades")
			var tb := _world.get("_lab_tab_items") as Button
			if tb != null:
				tb.emit_signal("pressed")
			await _p1_pframes(8)
			_p5_check(vp, nm, "items")
			await _p5_snap("lab_items")
			var tu := _world.get("_lab_tab_upgrades") as Button
			if tu != null:
				tu.emit_signal("pressed")
			await _p1_pframes(4)
		elif nm == "sound":
			var tabs: Dictionary = _world.get("_settings_tabs")
			for tid in ["sound", "gfx", "controls", "keys", "hud", "account"]:
				if tabs.has(tid):
					(tabs[tid] as Button).emit_signal("pressed")
				await _p1_pframes(8)
				_p5_check(vp, nm, tid)
				await _p5_snap("settings_" + tid)
			if tabs.has("sound"):
				(tabs["sound"] as Button).emit_signal("pressed")
			await _p1_pframes(4)
		else:
			_p5_check(vp, nm, "menu")
			await _p5_snap(nm)
		await _p5_close_path(nm, nm)
		var pnl := _p5_panel(nm)
		if pnl != null and pnl.visible:
			pnl.visible = false
			await _p1_pframes(2)
	if _p5_phone():
		await _p5_menu_roster()

func _p5_menu_roster() -> void:
	var saved_league: Array = GameProfile.data.get("league", []).duplicate()
	var saved_hero := String(_world.get("_menu_hero_sp"))
	GameProfile.data["league"] = [19, 16, 27]
	_world.call("_refresh_starter_unlocks")
	await _p1_pframes(8)
	var scroll := _world.get("_menu_starters") as ScrollContainer
	var roster := _world.get("_starter_unlock_box") as BoxContainer
	var tray := (_world.get("_menu_design") as Control).get_node("StarterSelection") as Control
	_check("P5: unlocked roster stays in its tray",
		roster.get_child_count() == 3 and _inside(_vis_rect(scroll), _vis_rect(tray)),
		"roster=" + str(roster.get_child_count()) + " scroll=" + str(_vis_rect(scroll)))
	var incorrect: Array[String] = []
	for card in roster.get_children():
		card.grab_focus()
		await _p1_pframes(2)
		var selected_count := 0
		for button in scroll.find_children("*", "Button", true, false):
			if button.has_meta("starter_species") and button.get_node("SelectedMark").visible:
				selected_count += 1
		var species := String(card.get_meta("starter_species"))
		if selected_count != 1 or not card.get_node("SelectedMark").visible or String(_world.get("_menu_hero_sp")) != species:
			incorrect.append(species)
	_check("P5: unlocked starter has the only selected mark", incorrect.is_empty(), str(incorrect))
	scroll.scroll_horizontal = int(scroll.get_h_scroll_bar().max_value)
	await _p1_pframes(4)
	(tray.get_node("StarterNext") as Button).pressed.emit()
	await _p1_pframes(4)
	var first := _world.get("_first_starter_card") as Control
	_check("P5: starter arrow brings its selected card into view",
		String(_world.get("_menu_hero_sp")) == "bulbasaur" and _inside(_vis_rect(first), _vis_rect(scroll)),
		"selected=" + String(_world.get("_menu_hero_sp")) + " card=" + str(_vis_rect(first)) + " scroll=" + str(_vis_rect(scroll)))
	GameProfile.data["league"] = saved_league
	_world.call("_refresh_starter_unlocks")
	_world.call("_menu_hero_show", saved_hero)
	scroll.scroll_horizontal = 0
	await _p1_pframes(4)

## Loadout (opened by the harness's own boot path).
func _p5_loadout(vp: Vector2) -> void:
	await _frames(12)
	_p5_check(vp, "loadout", "boot")
	if not _p5_phone():
		return
	var grid := _world.get("_ls_grid") as Control
	var bad := ""
	var nt := 0
	var ntile := 0
	if grid != null:
		for tile in grid.get_children():
			if not (tile is Control) or not (tile as Control).is_visible_in_tree():
				continue
			ntile += 1
			var tr := _vis_rect(tile)
			for ch in (tile as Node).get_children():
				if ch is TextureRect and (ch as Control).is_visible_in_tree():
					nt += 1
					var rr := _vis_rect(ch)
					if not _inside(rr, tr) and bad == "":
						bad = str(rr) + " out of " + str(tr)
	_check("P5: loadout tiles", ntile > 0 and nt == ntile and bad == "",
		"tiles=" + str(ntile) + " portraits=" + str(nt) + " " + bad)
	await _p5_snap("loadout")

## Settle any level-up / blessing / choice and wait for live play
## (no modal). Unlike _p3_ready it does not wait for the touch
## layer — the desktop variant has none, and _p3_ready would burn
## its full 300-frame guard there on every call (red-run timeout).
func _p5_ready() -> void:
	await _p1_settle_drafts()
	for i in range(300):
		if not bool(_world.call("_any_modal_open")) \
				and String(_world.get("state")) in ["playing", "guardian", "portal"]:
			return
		await get_tree().process_frame

## ---- in-run modals (after every earlier block) ------------------
func _p5_run_block(vp: Vector2) -> void:
	await _p5_ready()
	var pl = _world.get("player")
	var xpm0 := float(pl.xp_mult)
	_p4_freeze_xp(pl)
	# pause: three pages, the destructive action top-left, 继续 closes.
	await _p5_probe_banner()
	_world._open_pause()
	await _p1_pframes(6)
	for i in range(3):
		var tn := ["status", "legend", "settings"][i] as String
		_world._pause_show_tab(i)
		await _p1_pframes(6)
		_p5_check(vp, "pause", tn)
		await _p5_snap("pause_" + tn)
	if _p5_phone():
		var qb := _world.get("_pause_quit_btn") as Button
		var qc := _vis_rect(qb).get_center() if qb else Vector2(-1, -1)
		_check("P5: destructive action top-left (pause)",
			qb != null and qc.x < 0.4 * vp.x and qc.y < 0.4 * vp.y, "回主菜单 centre=" + str(qc.round()))
	await _p5_banner_frozen("pause")
	if _p5_phone():
		await _p5_close_path("pause", "pause")
		_check("P5: pause close returns to play", String(_world.get("state")) != "pause",
			"state=" + String(_world.get("state")))
	_world._close_pause()
	await _p1_pframes(4)
	# big map.
	await _p5_ready()
	await _p5_probe_banner()
	_world.open_big_map()
	await _p1_pframes(8)
	_p5_check(vp, "bigmap", "run")
	await _p5_snap("bigmap")
	await _p5_banner_frozen("bigmap")
	if _p5_phone():
		await _p5_close_path("bigmap", "bigmap")
	_world._close_big_map()
	await _p1_pframes(4)
	# draft (level-up cards + buildMini + tools).
	await _p5_ready()
	await _p5_probe_banner()
	_world._open_draft()
	await _p1_pframes(10)
	if String(_world.get("state")) == "draft":
		_p5_check(vp, "draft", "run")
		if _p5_phone():
			var cards: Array = _world.get("_draft_card_btns")
			var opts: Array = _world.get("_draft_options")
			var ys := {}
			var pr := _p5_rect(_p5_panel("draft"))
			var inside := true
			for c in cards:
				if is_instance_valid(c) and (c as Control).is_visible_in_tree():
					ys[int(round(_vis_rect(c).position.y))] = true
					inside = inside and _inside(_vis_rect(c), pr)
			_check("P5: draft cards in one row inside the panel",
				cards.size() == opts.size() and ys.size() == 1 and inside,
				"cards=" + str(cards.size()) + " opts=" + str(opts.size()) + " rows=" + str(ys.size()))
			var rb := _world.get("_draft_rb") as Control
			var tb := _world.get("_draft_team_btn") as Control
			_check("P5: draft tools left, team right (one row)",
				rb != null and tb != null and _vis_rect(tb).get_center().x > _vis_rect(rb).get_center().x
				and absf(_vis_rect(tb).get_center().y - _vis_rect(rb).get_center().y) < 2.0,
				"rb=" + str(_vis_rect(rb).get_center().round()) + " team=" + str(_vis_rect(tb).get_center().round()))
		await _p5_snap("draft")
		await _snap("phone_hud_touch_" + _run_tag() + "_draft")
		await _p5_banner_frozen("draft")
	else:
		_check("P5: draft opened", false, "state=" + String(_world.get("state")))
	await _p1_settle_drafts()
	# blessing.
	await _p5_ready()
	await _p5_probe_banner()
	_world.offer_blessing("测试祭坛", 0, 3, 1)
	await _p1_pframes(10)
	if String(_world.get("state")) == "blessing":
		_p5_check(vp, "blessing", "run")
		await _p5_snap("blessing")
		await _p5_banner_frozen("blessing")
	else:
		_check("P5: blessing opened", false, "state=" + String(_world.get("state")))
	await _p1_settle_drafts()
	# choice: chest pick-3, single item, Porygon recompile.
	var keys: Array = GameData.item_keys()
	keys.sort()
	var k3: Array = []
	for k in keys:
		if k3.size() < 3:
			k3.append(String(_world.call("_item_card_text", String(k))))
	var cfg := [["pick3", "宝箱", "选择一件带走", k3, "全部出售 +42 金币"],
		["single", "获得物品", "选择带走，或出售换金币", [k3[0]], "出售 +12 金币"],
		["porygon", "多边兽 · 重编译", "选择一组重编译（本局生效）",
			["重编译\n伤害 +12%\n代价：移速 −6%", "重编译\n暴击率 +8%\n代价：护甲 −10%",
			"重编译\n攻速 +10%\n代价：生命 −8%"], "离开（不选择）"]]
	for row in cfg:
		await _p5_ready()
		await _p5_probe_banner()
		_world._choice_show(String(row[1]), String(row[2]), row[3], String(row[4]), Callable(), Callable())
		await _p1_pframes(8)
		_p5_check(vp, "choice", String(row[0]))
		await _p5_snap("choice_" + String(row[0]))
		await _p5_banner_frozen("choice/" + String(row[0]))
		if _p5_phone():
			await _p5_close_path("choice", "choice/" + String(row[0]))
		if bool(_world.get("_choice_open")):
			_world._choice_close(true)
		await _p1_pframes(4)
	# Meowth shop (stock + the sell row: give the player two items).
	await _p5_ready()
	var gk := String(keys[0])
	pl.add_item(gk)
	await _p5_probe_banner()
	_world.set("gold", 400.0)
	_world.set("_shop", {})
	_world._open_shop()
	await _p1_pframes(8)
	_p5_check(vp, "meowth", "run")
	await _p5_snap("meowth")
	await _p5_banner_frozen("meowth")
	if _p5_phone():
		await _p5_close_path("meowth", "meowth")
	_world._shop_close()
	await _p1_pframes(4)
	pl.remove_item(gk)
	pl.xp_mult = xpm0
	# Results (ends the run — last).
	await _p5_ready()
	_world.call("_finish_run", false)
	await _p1_pframes(10)
	_p5_check(vp, "result", "dead")
	if _p5_phone():
		var rb2 := _p5_primary("result", _p5_panel("result"))
		_check("P5: result back-to-menu wired", rb2 != null and rb2.get_signal_connection_list("pressed").size() > 0,
			"btn=" + (_p5_btn_text(rb2) if rb2 else "none"))
	await _p5_snap("result")
