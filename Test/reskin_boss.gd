extends "res://Test/uishot.gd"
## Hard UI gate: real boss geometry, fixed header, both clear and intersecting projections.
func _run() -> void:
	_world = load("res://scenes/main.tscn").instantiate()
	add_child(_world)
	await _frames(40)
	_world.debug_start("charmander")
	await _frames(60)
	_world.get("player").invulnerable = true
	_world.debug_teleport_player(0, -28)
	_world.debug_summon()
	await _frames(60)
	var boss := _world.get("guardian") as Node3D
	var header := _world.get("_boss_card") as Control
	var cam := _world.get("_cam") as Camera3D
	assert(boss != null and header.visible, "Boss / header missing")
	boss.hp = boss.max_hp * 0.49
	_world._boss_enrage()
	_world._update_hud_bars(0.0)
	_world.set("running", false)
	await _frames(4)
	_world._reskin_boss_visibility()
	assert(_world.get("_boss_enraged"), "Rage fixture missing")
	assert("狂怒" in (_world.get("_boss_tag_label") as Label).text, "Rage tag missing")
	assert(not _world._boss_body_overlaps_header() and header.modulate.a > 0.0, "Rage header must be visible and clear of boss")
	await _snap("boss_rage")
	print("RESKIN BOSS RAGE PASS: HP=", boss.hp, " tag=", (_world.get("_boss_tag_label") as Label).text, " header=", _world._p3_draw_rect(header), " body_overlap=false alpha=", header.modulate.a)
	var saved := boss.global_position
	var top := header.position.y
	_world.set("running", false)
	var rect: Rect2 = _world._p3_draw_rect(header)
	boss.global_position = cam.project_position(rect.get_center(), 8.0) - Vector3(0, 1, 0)
	boss.reset_physics_interpolation()
	_world._reskin_boss_visibility()
	assert(_world._boss_body_overlaps_header(), "Fixture must intersect the header")
	assert(header.modulate.a == 0.0, "Intersecting boss must be unobstructed")
	assert(header.position.y == top, "Header must stay fixed")
	await _snap("boss_guard")
	boss.global_position = saved
	boss.reset_physics_interpolation()
	_world._reskin_boss_visibility()
	assert(header.position.y == top, "Restoring boss must not move header")
	print("RESKIN BOSS GATE PASS: intersecting body -> alpha=0; header stays fixed")
	get_tree().quit()
