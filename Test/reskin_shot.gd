extends "res://Test/uishot.gd"
## Focused approved-screen capture using the standing real-world screenshot helper.
## Avoids unrelated archive/shop/capture fixtures; all screens use their real builders.
func _run() -> void:
	_world = load("res://scenes/main.tscn").instantiate()
	add_child(_world)
	await _frames(40)
	await _snap("menu")
	(_world.get("_wallet_panel") as Control).show()
	_world._refresh_wallet_ui()
	await _frames(4)
	await _snap("wallet")
	(_world.get("_wallet_panel") as Control).hide()
	(_world.get("_lab_panel") as Control).show()
	_world._refresh_lab()
	await _frames(4)
	await _snap("lab")
	(_world.get("_lab_panel") as Control).hide()
	_world._open_settings()
	_world._settings_show_tab("legal")
	for doc in ["privacy", "terms"]:
		for lang in ["zh", "en"]:
			_world._settings_page_legal(doc, lang)
			await _frames(6)
			(_world.get("_settings_page").get_parent() as ScrollContainer).scroll_vertical = 0
			await _frames(4)
			await _snap("legal_" + doc + "_" + lang)
			if doc == "terms":
				(_world.get("_settings_page").get_parent() as ScrollContainer).scroll_vertical = 100000
				await _frames(4)
				await _snap("legal_" + doc + "_" + lang + "_end")
	_world._close_settings()
	_world._open_loadout("charmander")
	_world._loadout_start()
	await _frames(60)
	var player = _world.get("player")
	assert(player != null, "No live player")
	player.invulnerable = true
	await _snap("hud")
	_world._open_draft()
	await _frames(6)
	await _snap("draft")
	_world._close_draft()
	_world.debug_teleport_player(0, -28)
	_world.debug_summon()
	await _frames(60)
	var header := _world.get("_boss_card") as Control
	var overlaps: bool = _world._boss_body_overlaps_header()
	assert(not overlaps or header.modulate.a == 0.0, "Boss body covered by header")
	print("RESKIN BOSS body_overlap=", overlaps, " header_alpha=", header.modulate.a)
	await _snap("boss")
	_world.set("kills", 87)
	_world.set("gold", 1234.0)
	_world.set("damage_dealt", 54321.0)
	_world._finish_run(false)
	await _frames(8)
	await _snap("result")
	print("RESKIN SHOT DONE")
	get_tree().quit()
