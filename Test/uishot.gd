extends Node
## UI alignment capture (cycle 17; extended cycle 18). Boots
## the real world and snaps the screens the round restyles:
## menu, lab, shop, settings, loadout, in-run HUD (bare and
## populated), draft, blessing, pause, big map, result. Tag
## via -- --tag=<name>: outputs Test/out/ui_<screen>_<tag>.png.
## Presentation-only: it drives the same public open/apply
## functions the game and harness use; the result screen is
## filled by the REAL _finish_run path (its data fields are
## seeded for the portrait — the harness ui2 phase verifies
## the same screen fed by real play).

var _world: Node
var _tag := "after"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			_tag = a.trim_prefix("--tag=")
	_run()

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _snap(name: String) -> void:
	# Cycle 19: the viewport texture holds the last RENDERED
	# frame; physics-frame waits can elapse with no render
	# under llvmpipe (the shop snap once re-captured the Lab
	# frame byte-identical). Wait for two render frames and
	# the post-draw signal so the capture is the live screen.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://Test/out/ui_" + name + "_" + _tag + ".png")
	print("UISHOT ", name)

func _run() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	_world = ps.instantiate()
	add_child(_world)
	await _frames(45)
	await _snap("menu")
	# Lab + shop panels (menu meta screens).
	(_world.get("_lab_panel") as Control).visible = true
	_world._refresh_lab()
	await _frames(6)
	await _snap("lab")
	# Cycle 19: the Archive tab, shown with the upgrade
	# bought + two items shelved on a snapshot-restored
	# profile (the standing tool leaves the resident
	# profile byte-identical).
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	GameProfile.add_stardust(100000)
	GameProfile.lab_buy("archive")
	GameProfile.lab_buy("archive")
	GameProfile.archive_item("protein", true)
	GameProfile.archive_item("iron", true)
	_world._lab_set_mode("items")
	await _frames(6)
	await _snap("labitems")
	_world._lab_set_mode("upgrades")
	GameProfile.data = snap
	GameProfile.save_profile()
	(_world.get("_lab_panel") as Control).visible = false
	(_world.get("_shop_panel") as Control).visible = true
	_world._refresh_shop()
	await _frames(6)
	await _snap("shop")
	(_world.get("_shop_panel") as Control).visible = false
	# Settings screen (cycle 18: the 6-section screen, 界面 tab).
	_world._open_settings()
	_world._settings_show_tab("hud")
	await _frames(8)
	await _snap("settings")
	_world._close_settings()
	# Loadout (cycle 18: the menu->run bridge).
	_world._open_loadout("charmander")
	await _frames(8)
	await _snap("loadout")
	# In-run HUD with the second starter (started through the
	# loadout's real start path).
	_world._loadout_start()
	var p = null
	for i in range(600):
		await get_tree().physics_frame
		p = _world.get("player")
		if p != null and p.get("rig") != null and bool(p.get("rig").get("fitted")):
			break
	if p == null:
		print("UISHOT FAIL no player")
		get_tree().quit(1)
		return
	p.invulnerable = true
	await _frames(30)
	await _snap("hud")
	# Draft (level-up three-choice).
	_world._open_draft()
	await _frames(6)
	await _snap("draft")
	# Cycle 18: the draft swallows input for 600 ms after
	# opening (bundle modal guard) — let it lapse first.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await get_tree().physics_frame
	_world._apply_draft_option(0)
	await _frames(4)
	# Blessing modal. The wait is long: under the software
	# renderer the modal's first frame (30+ fresh canvas items)
	# lags the physics clock — at 6 frames the capture raced
	# the render thread and missed the panel (cycle-17 log;
	# the panel's rect/visibility were verified correct).
	_world.offer_blessing("未知祭坛", 2, 3, 1)
	await _frames(40)
	await _snap("blessing")
	_world._apply_blessing_offer(0)
	await _frames(4)
	# Populated HUD: capture an alpha into the party, leave a
	# second alpha live for the mini bar (real throw path).
	for round in range(2):
		_world._spawn_alpha()
		await _frames(20)
		var alpha = null
		for e in get_tree().get_nodes_in_group("enemies"):
			if int(e.get("flag")) == 2 and int(e.get("mode")) != 3:
				alpha = e
		if alpha == null:
			break
		if round == 0:
			for t in range(16):
				var att := 0
				while is_instance_valid(alpha) and not bool(alpha.get("is_downed")) and att < 40:
					alpha.take_damage(99999.0)
					att += 1
				if not is_instance_valid(alpha) or not bool(alpha.get("is_downed")):
					break
				_world._throw_ball(alpha)
				await _frames(4)
				if is_instance_valid(alpha) and int(alpha.get("mode")) == 3:
					break
	_world._refresh_hud()
	await _frames(10)
	await _snap("hud2")
	# Pause (cycle 18).
	_world._open_pause()
	await _frames(8)
	await _snap("pause")
	_world._close_pause()
	await _frames(4)
	# Big map (cycle 18).
	_world.open_big_map()
	await _frames(8)
	await _snap("bigmap")
	_world._close_big_map()
	await _frames(4)
	# Result screen through the real _finish_run fill path.
	_world.set("kills", 87)
	_world.set("gold", 1234.0)
	_world.set("damage_dealt", 54321.0)
	_world.set("bosses", 2)
	_world.set("captured", 3)
	_world.set("run_counts", {"reactions": 5})
	_world.set("run_move_dmg", {"vine-whip": 15230.0, "razor-leaf": 11040.0, "slam": 6230.0, "ult": 4800.0})
	_world.set("run_captures", ["caterpie", "pidgey"])
	_world.set("run_blessings", ["攻击祝福", "速度祝福"])
	_world._finish_run(false)
	await _frames(8)
	await _snap("result")
	print("UISHOT DONE")
	get_tree().quit()
