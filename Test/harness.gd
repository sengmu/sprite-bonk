extends Node
## Standing rig-verification harness (Test/* is excluded from exports).
## Boots the real game with a chosen starter, spawns a same-species
## enemy through the normal world path, freezes the frame, and dumps
## (a) fit diagnostics and (b) visibility-diff screenshots so an
## offline pass can measure the RENDERED on-screen height + body color
## of the player and the enemy. Catches the bug class where the fit
## math (bind-pose AABB) disagrees with the skinned render — that
## shipped silently for Charmander-as-player because every earlier
## verification shot used Bulbasaur.
##
## Usage:
##   godot --path . res://Test/harness.tscn -- --starter=charmander
##   godot --path . res://Test/harness.tscn -- --mode=faint --faint=graveler
## Output PNGs land in Test/out/.

var _world: Node
var _starter := "bulbasaur"
var _enemy_species := "charmander"
var _mode := "starters"
var _faint_species := "graveler"
var _phase := 0
var _frames := 0
var _player: Node
var _enemy: Node
var _bare: Node  # bare rig, measures the fit's believed native height
var _c9_only := "all"
var _c9_fails := 0
var _c9_checks := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--starter="):
			_starter = a.trim_prefix("--starter=")
		elif a.begins_with("--enemy="):
			_enemy_species = a.trim_prefix("--enemy=")
		elif a.begins_with("--mode="):
			_mode = a.trim_prefix("--mode=")
		elif a.begins_with("--faint="):
			_faint_species = a.trim_prefix("--faint=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Test/out"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_c9_only = a.trim_prefix("--only=")
	var ps: PackedScene = load("res://scenes/main.tscn")
	_world = ps.instantiate()
	add_child(_world)
	if _mode == "cycle9":
		_run_cycle9()
	# Bare rig for the starter species: pure fit-math evidence.
	_bare = load("res://scripts/model_rig.gd").new()
	add_child(_bare)
	_bare.position = Vector3(0, -500, 0)  # far below the world, never framed
	_bare.setup(_starter)

func _diag(tag: String, rig: Node) -> void:
	var aabb: AABB = rig._merged_aabb(rig.model)
	var cfg: Dictionary = ModelRig.SPECIES[rig.species_id]
	var denom := -1.0
	if rig.model.scale.x > 0.0001:
		denom = float(cfg["height"]) / rig.model.scale.x
	print("DIAG ", tag, " species=", rig.species_id,
		" fit=", String(cfg.get("fit", "?")),
		" cfg_h=", float(cfg["height"]),
		" model_scale=", rig.model.scale.x,
		" believed_denom=", denom,
		" postfit_bind_aabb=", aabb.size,
		" has_anim=", rig.anim_player != null,
		" has_skel=", rig._find_skeleton(rig.model) != null)

func _freeze(n: Node) -> void:
	n.process_mode = Node.PROCESS_MODE_DISABLED
	for c in n.get_children():
		_freeze(c)

func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://Test/out/" + name + ".png")
	print("SNAP ", name, " ", img.get_size())

func _process(_delta: float) -> void:
	_frames += 1
	match _mode:
		"starters":
			_process_starters()
		"faint":
			_process_faint()
		"cycle9":
			pass  # driven by the _run_cycle9 coroutine

func _process_starters() -> void:
	match _phase:
		0:
			if _frames > 15:
				_world.start_game(_starter)
				_phase = 1
				_frames = 0
		1:
			var p = _world.get("player")
			if p and not _player:
				_player = p
				p.invulnerable = true  # wild spawns must not kill the subject
				p.moves.clear()  # disarm: no lunge/hurt poses during capture
			if p and p.rig and p.rig.fitted:
				_player = p
				_diag("PLAYER", p.rig)
				if _bare and _bare.fitted:
					_diag("BARE", _bare)
				var pos: Vector3 = p.global_position + Vector3(3.2, 0, -1.5)
				pos.y = _world.height_at(pos.x, pos.z)
				_enemy = _world._spawn_enemy_at(_enemy_species, pos, 1.0, false, 1.0)
				_phase = 2
				_frames = 0
			elif _frames > 7200:
				print("HARNESS TIMEOUT waiting for player fit")
				get_tree().quit(1)
		2:
			if _enemy and _enemy.rig and _enemy.rig.fitted:
				_diag("ENEMY", _enemy.rig)
				_phase = 3
				_frames = 0
			elif _frames > 7200:
				print("HARNESS TIMEOUT waiting for enemy fit")
				get_tree().quit(1)
		3:
			# Pin the enemy beside the player while the camera settles;
			# clear wild spawns so the diff windows stay clean.
			if _frames == 1:
				for e in get_tree().get_nodes_in_group("enemies"):
					if e != _enemy:
						e.queue_free()
			var pos: Vector3 = _player.global_position + Vector3(3.2, 0, -1.5)
			pos.y = _world.height_at(pos.x, pos.z)
			_enemy.global_position = pos
			if _frames == 20:
				# Dressing (tufts/props) sways on TIME shaders and poisons
				# frame diffs; hide it for the measurement frames.
				var dr = _world.get("_dress_root")
				if dr:
					dr.visible = false
			if _frames > 40:
				# Face the subject at the camera (spawn facing is
				# away; the color check needs the front), then freeze
				# EVERY world node: pause alone leaves
				# PROCESS_MODE_ALWAYS nodes (camera, billboards)
				# drifting between shots, which poisoned the
				# visibility diffs.
				var cam: Camera3D = _world.get("_cam")
				var to_cam: Vector3 = cam.global_position - _player.global_position
				to_cam.y = 0
				_player.rig.set_facing(to_cam.normalized())
				_enemy.rig.set_facing(-to_cam.normalized())
				_freeze(_world)
				get_tree().paused = true
				_phase = 4
				_frames = 0
		4:
			if _frames == 4:
				_snap(_starter + "_all")
			elif _frames == 6:
				_player.rig.model.visible = false
			elif _frames == 8:
				_snap(_starter + "_noplayer")
			elif _frames == 10:
				_player.rig.model.visible = true
				_enemy.rig.model.visible = false
			elif _frames == 12:
				_snap(_starter + "_noenemy")
			elif _frames == 14:
				# Projected pixel scale at the player's depth (px per world unit).
				var cam: Camera3D = _world.get("_cam")
				var base: Vector3 = _player.global_position
				var y0: Vector2 = cam.unproject_position(base + Vector3(0, 0.65, 0))
				var y1: Vector2 = cam.unproject_position(base + Vector3(0, 1.95, 0))
				print("PXPERUNIT player=", absf(y1.y - y0.y) / 1.3,
					" player_anchor=", cam.unproject_position(base))
				var eb: Vector3 = _enemy.global_position
				var e0: Vector2 = cam.unproject_position(eb + Vector3(0, 0.65, 0))
				var e1: Vector2 = cam.unproject_position(eb + Vector3(0, 1.95, 0))
				print("PXPERUNIT enemy=", absf(e1.y - e0.y) / 1.3,
					" enemy_anchor=", cam.unproject_position(eb))
				print("HARNESS DONE ", _starter)
				get_tree().quit()

func _process_faint() -> void:
	match _phase:
		0:
			if _frames > 15:
				_world.start_game("bulbasaur")
				_phase = 1
				_frames = 0
		1:
			var p = _world.get("player")
			if p and p.rig and p.rig.fitted:
				_player = p
				p.invulnerable = true
				p.moves.clear()
				for e in get_tree().get_nodes_in_group("enemies"):
					e.queue_free()
				var pos: Vector3 = p.global_position + Vector3(3.4, 0, -1.2)
				pos.y = _world.height_at(pos.x, pos.z)
				_enemy = _world._spawn_enemy_at(_faint_species, pos, 1.0, false, 1.0)
				_phase = 2
				_frames = 0
			elif _frames > 7200:
				print("HARNESS TIMEOUT (faint) player")
				get_tree().quit(1)
		2:
			if _enemy and _enemy.rig and _enemy.rig.fitted:
				_diag("FAINTSUBJ", _enemy.rig)
				_enemy.take_damage(100000.0)
				_phase = 3
				_frames = 0
			elif _frames > 7200:
				print("HARNESS TIMEOUT (faint) enemy")
				get_tree().quit(1)
		3:
			# Capture mid-collapse by the rig's own faint clock (a
			# frame count overshoots under slow software rendering:
			# the corpse is freed ~1.5 s after the kill).
			if is_instance_valid(_enemy) and _enemy.rig:
				var ft: float = _enemy.rig.get("_faint_t")
				if ft >= 0.3:
					print("FAINT t=", ft,
						" model_rotation=", _enemy.rig.model.rotation,
						" model_scale=", _enemy.rig.model.scale)
					get_tree().paused = true
					_phase = 4
					_frames = 0
			elif _frames > 900:
				print("FAINT MISS enemy freed before capture")
				get_tree().quit(1)
		4:
			if _frames == 4:
				if is_instance_valid(_enemy) and _enemy.rig and _enemy.rig.model:
					print("FAINT model_rotation=", _enemy.rig.model.rotation,
						" model_scale=", _enemy.rig.model.scale)
				_snap("faint_" + _faint_species)
				print("HARNESS DONE faint ", _faint_species)
				get_tree().quit()

# ------------------------------------------------------------ cycle 9
## Audit-fix verification (cycle 9). Every check drives the REAL
## game flow: runs start through start_game, deaths through
## take_damage, the guardian through summon_guardian + take_damage,
## the revive through the purchased Lab upgrade, movement through
## synthesized touch-joystick events, the dive through real key
## events. Fixture arrangement (placing targets, pinning a target's
## HP pool, zeroing crit for one deterministic pipeline reading) is
## labelled where it happens; no profile counters are written by
## the harness except through the game's own APIs (GameProfile.count
## happens inside the game code; lab dust is funded via
## GameProfile.add_stardust — the same function _finish_run awards
## through — and spent through the real lab_buy).
## Usage: --mode=cycle9 [--only=league|guardian|slam|revive|attack|ult|shrine|bossscale|wet|react|comet|props|audio|shop|boost|ui2|c19|c21|c212]

func _c9_check(name: String, ok: bool, detail: String = "") -> void:
	_c9_checks += 1
	if not ok:
		_c9_fails += 1
	print("C9 ", "PASS " if ok else "FAIL ", name, (" :: " + detail) if detail != "" else "")

func _c9_wait(cond: Callable, timeout_frames: int = 1800) -> bool:
	var n := 0
	while n < timeout_frames:
		if bool(cond.call()):
			return true
		await get_tree().physics_frame
		n += 1
	return false

func _c9_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

## Cycle 21: wait `secs` of sim time (physics frames at
## 60/s). The world arg is accepted for call-site symmetry
## with the world-side helpers and ignored.
func _wait_sim(_w: Node, secs: float) -> void:
	var n := int(secs * 60.0)
	for i in range(n):
		await get_tree().physics_frame

## Resolve any queued level-up drafts through the real draft
## path (the function the draft cards' buttons call) — a guardian
## kill queues many levels, and the world clock pauses in draft.
func _c9_settle_drafts() -> void:
	# Cycle 21.1: the draft pick guard is WALL-CLOCK (the
	# 600 ms anti-misclick window in world._draft_swallowed)
	# — a fixed frame-count loop can burn its whole budget
	# in less wall time than the guard at headless frame
	# rates and exit with the draft still open; a later
	# state writer then strands the run with running=false
	# (the C21.1 c21-standalone flake). Bound by wall time;
	# picks still go through the real _apply_draft_option.
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		var p = _world.get("player")
		if p == null:
			break
		if String(_world.get("state")) == "draft":
			_world._apply_draft_option(0)
		elif int(p.get("pending_levels")) <= 0:
			break
		await _c9_frames(3)

## Cycle 21: wait sim seconds while keeping the world out of
## the draft modal. A delayed kill (poison, a tick, an ally)
## can level the player mid-wait and open a draft, and in
## draft the gated world clock (boss brain, passive ticks)
## pauses — that starved the c21 boss/passive windows while
## their fixtures waited in good faith. Picks go through the
## real draft path, which restores the pre-draft state.
func _c21_wait(w, secs: float) -> void:
	var left := secs
	while left > 0.0:
		if bool(w.get("_choice_open")):
			w.call("_choice_pick", 0)
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		var step: float = minf(0.5, left)
		await _wait_sim(w, step)
		left -= step
	if bool(w.get("_choice_open")):
		w.call("_choice_pick", 0)
	if String(w.get("state")) == "draft":
		w._apply_draft_option(0)

## Cycle 21: resolve any open world modal (level-up draft
## or item choice) through its real pick path. A guardian
## kill pays levels AND a chest roll in the same breath, and
## either modal left open keeps running = false, freezing
## the world clock for every later block (the passive
## starvation root cause, bracketed by C21DBG prints).
func _c21_settle_modals(w) -> void:
	var guard := 0
	while guard < 40:
		if String(w.get("state")) == "draft":
			await _c9_settle_drafts()
		elif bool(w.get("_choice_open")):
			w.call("_choice_pick", 0)
			await _c9_frames(3)
		else:
			break
		guard += 1

## Cycle 21.1: shared-state diagnostic for the suite-red
## closing hunt — prints the modal/queue/profile axes the
## full-order failures turned on, at phase block boundaries.
func _c211_dbg(tag: String) -> void:
	var w = _world
	var p = w.get("player")
	print("C211DBG ", tag, ": state=", String(w.get("state")),
		" running=", w.get("running"),
		" choice=", w.get("_choice_open"),
		" choice_return=", String(w.get("_choice_return")),
		" pending_rolls=", (w.get("_pending_item_rolls") as Array).size(),
		" bless_open=", w.get("_blessing_open"),
		" bless_queue=", (w.get("_blessing_queue") as Array).size(),
		" pendlv=", (int(p.get("pending_levels")) if p else -1),
		" timers=", (w.get("_timers") as Array).size(),
		" chests=", (w.get("_chests") as Array).size(),
		" party_lab=", GameProfile.lab_level("party"))

## Cycle 21.1: _c21_wait with the player kept disarmed.
## Settling a draft mid-window can grant a MOVE (the draft
## pool is moves + vitamins) — in the C21.1 NUC standalone
## the glare/intimidate subjects ended up ASLEEP: a draft
## settled during their windows re-armed the player with
## a sleep-ailment move whose nova overwrote the tick's
## paralyze/charm in the enemy's single status slot.
## Clearing the move list after every settle step (and
## once more at the end) keeps the passive tick the only
## writer of the subject's status and HP during the window.
func _c211_wait_disarmed(w, p, secs: float) -> void:
	var lab_passive: String = p.passive_id
	var left := secs
	while left > 0.0:
		if bool(w.get("_choice_open")):
			w.call("_choice_pick", 0)
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		if p.passive_id != lab_passive:
			print("PTICKFIX recalc changed passive ", p.passive_id, " -> ", lab_passive)
		p.passive_id = lab_passive
		p.moves.clear()
		var step: float = minf(0.5, left)
		await _wait_sim(w, step)
		left -= step
	p.moves.clear()

## Cycle 21.2 (audit N7): instrumented variant of
## _c211_wait_disarmed for the serpent-glare segment.
## Same settle/disarm behaviour, but every physics frame
## it recomputes the game's own cone predicate for the
## subject (world.gd "serpent-glare" tick: facing from
## the rig, overridden by velocity when speed > 0.5;
## centre = pos + facing x 3.5, prefilter r 4.5 around
## the centre, then dist < 7 and dot > 0.45) and watches
## _ptick_next for the carrier's instance id, so each
## real tick instant is logged with the geometry and
## facing source the game actually used. GLAREDBG lines:
## t0 (spawn geometry), sample (every 30 frames), tick
## (a tick fired), summary (window totals).
func _c212_glare_wait(w, p, s1, secs: float) -> void:
	var uid: int = p.get_instance_id()
	var frames := int(secs * 60.0)
	var in_cone_frames := 0
	var ticks := 0
	var ticks_in_cone := 0
	# Cycle 22 (queue item): fixture pinning — the same
	# pattern _c9_attack_phase uses. The subject's own AI
	# path was the flake (it walked out of the cone, or
	# closed to dist ~0 where the cone degenerates): pin
	# the subject AND the player at their spawn anchors
	# every frame, zero the subject's knockback and the
	# player's velocity (so the facing source stays the
	# rig), and hold the ambient spawner shut. Positions
	# and facing (B2 also pins the selected lab passive across recalc)
	# only — the game's tick, cone predicate and status
	# application all run untouched, and the GLAREDBG
	# instrumentation below still recomputes the cone
	# from the live positions every frame: an in-cone
	# tick that fails to land would still be caught.
	var lab_passive: String = p.passive_id
	var yaw_anchor: float = p.rig.rotation.y if p.rig else 0.0
	var p_anchor: Vector3 = p.global_position
	var s_anchor: Vector3 = s1.global_position
	# _ptick_next holds ONE entry per unit across passives,
	# so seed from the pre-window value; a tick is the only
	# writer and jumps the entry by the 4 s period.
	var last_next := float((w.get("_ptick_next") as Dictionary).get(uid, -1.0))
	var last_status := ""
	print("GLAREDBG t0: rt=", snappedf(float(w.get("run_time")), 0.01),
		" next0=", last_next, " soff=",
		Vector2(snappedf(s1.global_position.x - p.global_position.x, 0.01),
			snappedf(s1.global_position.z - p.global_position.z, 0.01)))
	for i in range(frames):
		if bool(w.get("_choice_open")):
			w.call("_choice_pick", 0)
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		if p.passive_id != lab_passive:
			print("GLAREDBG recalc changed passive ", p.passive_id, " -> ", lab_passive)
		p.passive_id = lab_passive
		if p.rig:
			p.rig.rotation.y = yaw_anchor
		p.moves.clear()
		await get_tree().physics_frame
		if not is_instance_valid(s1) or not is_instance_valid(p):
			print("GLAREDBG gone at frame ", i)
			return
		# Cycle 22: pinning (see the header note).
		w.set("_spawn_t", 5.0)
		s1.global_position = s_anchor
		s1.set("_kb_vel", Vector3.ZERO)
		p.global_position = p_anchor
		p.set("_vel", Vector3.ZERO)
		if p.rig:
			p.rig.rotation.y = yaw_anchor
		# Facing, exactly as the game computes it.
		var rig: Node3D = p.get("rig")
		var fy := 0.0
		if rig:
			fy = rig.rotation.y
		var facing := Vector2(sin(fy), cos(fy))
		var fsrc := "rig"
		var v: Vector3 = p.get("_vel")
		var vlen := Vector2(v.x, v.z).length()
		if vlen > 0.5:
			facing = Vector2(v.x, v.z).normalized()
			fsrc = "vel"
		var pos: Vector3 = p.global_position
		var d := Vector2(s1.global_position.x - pos.x, s1.global_position.z - pos.z)
		var dist := d.length()
		var dot := 0.0
		if dist > 0.01:
			dot = facing.dot(d.normalized())
		var center := pos + Vector3(facing.x, 0, facing.y) * 3.5
		var cdist := Vector2(s1.global_position.x - center.x, s1.global_position.z - center.z).length()
		var in_cone := cdist <= 4.5 and dist < 7.0 and dist > 0.01 and dot > 0.45
		if in_cone:
			in_cone_frames += 1
		var nxt := float((w.get("_ptick_next") as Dictionary).get(uid, -1.0))
		if nxt > last_next + 0.5:
			ticks += 1
			if in_cone:
				ticks_in_cone += 1
			print("GLAREDBG tick ", ticks, ": rt=", snappedf(float(w.get("run_time")), 0.01),
				" in_cone=", in_cone, " dot=", snappedf(dot, 0.001),
				" dist=", snappedf(dist, 0.01), " cdist=", snappedf(cdist, 0.01),
				" fsrc=", fsrc, " vlen=", snappedf(vlen, 0.01),
				" soff=", Vector2(snappedf(d.x, 0.01), snappedf(d.y, 0.01)),
				" status=", String(s1.status_kind))
		last_next = nxt
		if i % 30 == 0 or String(s1.status_kind) != last_status:
			print("GLAREDBG sample f=", i, " rt=", snappedf(float(w.get("run_time")), 0.01),
				" in_cone=", in_cone, " dot=", snappedf(dot, 0.001),
				" dist=", snappedf(dist, 0.01), " cdist=", snappedf(cdist, 0.01),
				" fsrc=", fsrc, " vlen=", snappedf(vlen, 0.01),
				" status=", String(s1.status_kind))
		last_status = String(s1.status_kind)
	print("GLAREDBG summary: frames=", frames, " in_cone_frames=", in_cone_frames,
		" ticks=", ticks, " ticks_in_cone=", ticks_in_cone,
		" final_status=", String(s1.status_kind))

func _c9_start_run(species: String = "bulbasaur", requested_tier: int = 0) -> bool:
	_world.start_game(species, [], requested_tier)
	var ok := await _c9_wait(func() -> bool:
		var p = _world.get("player")
		return p != null and p.rig != null and p.rig.fitted, 3600)
	_player = _world.get("player")
	return ok

func _c9_cleanup_run() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for a in get_tree().get_nodes_in_group("allies"):
		a.queue_free()
	var p = _world.get("player")
	if p:
		p.queue_free()
		_world.set("player", null)
	_world.set("_league_e", null)
	_world.set("_alpha_enemy", null)
	_world.set("_guardian", null)
	_world.set("guardian", null)
	_world.set("state", "menu")
	_world.set("running", false)
	var rp = _world.get("_result_panel")
	if rp:
		rp.visible = false
	var mp = _world.get("_menu_panel")
	if mp:
		mp.visible = true
	await _c9_frames(3)

func _c9_key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _c9_touch(pos: Vector2, pressed: bool, drag_to: Vector2 = Vector2(-1, -1)) -> void:
	if drag_to.x >= 0.0:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = drag_to
		d.relative = drag_to - pos
		Input.parse_input_event(d)
	else:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = pos
		t.pressed = pressed
		Input.parse_input_event(t)

## GUI-signal touch delivery (cycle 15 harness adaptation).
## In this headless environment the viewport performs NO GUI
## picking for synthetic events: a bare top-level STOP control
## receives nothing from Input.parse_input_event (touch or
## mouse), while Node._input callbacks DO fire (the world's
## touch latch works). Cycle 13's UltGauge already documents
## the sanctioned workaround — deliver the synthetic event
## through the target control's gui_input SIGNAL. The handler
## chain that runs (accept_event, joystick/button state, the
## world's polls) is the game's real code; only the viewport's
## picking hop is bypassed. Event positions are control-local;
## the touch layer's zones sit at the root origin, so layout
## positions are used unchanged (touch_controls.gd's own note).
func _c9_gui_touch(ctrl: Control, pos: Vector2, pressed: bool, drag_to: Vector2 = Vector2(-1, -1)) -> void:
	if drag_to.x >= 0.0:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = drag_to
		d.relative = drag_to - pos
		ctrl.gui_input.emit(d)
	else:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = pos
		t.pressed = pressed
		ctrl.gui_input.emit(t)

func _run_cycle9() -> void:
	await _c9_frames(20)
	# Profile / GameData are class_name statics (no autoloads in
	# this project) — the phases call them directly.
	if _c9_only in ["all", "league"]:
		await _c9_league_phase()
	if _c9_only in ["all", "guardian"]:
		await _c9_guardian_phase()
	if _c9_only in ["all", "slam"]:
		await _c9_slam_phase()
	if _c9_only in ["all", "attack"]:
		await _c9_attack_phase()
	if _c9_only in ["all", "ult"]:
		await _c9_ult_phase()
	if _c9_only in ["all", "revive"]:
		await _c9_revive_phase()
	if _c9_only in ["all", "shrine"]:
		await _c9_shrine_phase()
	if _c9_only in ["all", "bossscale"]:
		await _c9_bossscale_phase()
	if _c9_only in ["all", "wet"]:
		await _c9_wet_phase()
	if _c9_only in ["all", "react"]:
		await _c9_react_phase()
	if _c9_only in ["all", "comet"]:
		await _c9_comet_phase()
	if _c9_only in ["all", "props"]:
		await _c9_props_phase()
	if _c9_only in ["all", "audio"]:
		await _c9_audio_phase()
	if _c9_only in ["all", "shop"]:
		await _c9_shop_phase()
	if _c9_only in ["all", "boost"]:
		await _c18_boost_phase()
	if _c9_only in ["all", "ui2"]:
		await _c18_ui2_phase()
	if _c9_only in ["all", "c19"]:
		await _c19_phase()
	if _c9_only in ["all", "c21"]:
		await _c21_phase()
	if _c9_only in ["all", "c212"]:
		await _c212_reset_phase()
	if _c9_only in ["all", "c22"]:
		await _c22_phase()
	if _c9_only in ["all", "c23b2"]:
		await _c23b2_phase()
	if _c9_only in ["all", "c23"]:
		await _c23_phase()
	print("C9 SUMMARY checks=", _c9_checks, " fails=", _c9_fails)
	get_tree().quit(1 if _c9_fails > 0 else 0)

## Cycle 21.2: regression guard for the C21.1 run-reset
## leak (audit N1). In the C21 closing suite a choice
## modal opened in "portal" state and never picked
## survived start_game into the next run: every later
## modal close restored the captured _choice_return
## ("portal"), freezing the _later timers, the egg tick
## and the challenge watch (all gated on play states)
## and failing the guardian summon gate — one leak,
## ~13 reds across props/c21. The 21.1 fix is the
## run-boundary reset block in world.start_game (clears
## the choice modal, the pending item-roll queue, the
## guardian chests and the portal node). This phase
## rebuilds the leak arrangement through the real paths
## (portal pieces, a real chest spawn, the real chest
## roll entry), resets through the real start path, and
## asserts the next run is hermetic AND alive.
func _c212_reset_phase() -> void:
	var w = _world
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("c212: run 1 boots", false, "player never fitted")
		return
	var p = _world.get("player")
	# Arrange the leak: the guardian-death portal context
	# (portal node up, state "portal"), a guardian chest
	# on the ground, and its item roll left unpicked with
	# a second roll queued behind it.
	w.call("_open_portal")
	w.set("state", "portal")
	w.call("_spawn_chest", p.global_position + Vector3(3, 0, 0))
	w.call("_roll_chest_item", 0, 1)
	await _c9_frames(2)
	w.call("_roll_chest_item", 0, 1)
	await _c9_frames(2)
	_c9_check("c212: fixture — modal open in portal state, roll queued, chest + portal up",
		bool(w.get("_choice_open")) and String(w.get("_choice_return")) == "portal"
		and (w.get("_pending_item_rolls") as Array).size() == 1
		and not (w.get("_chests") as Array).is_empty()
		and w.get("portal_node") != null,
		"choice=" + str(w.get("_choice_open")) + " ret=" + String(w.get("_choice_return"))
		+ " pending=" + str((w.get("_pending_item_rolls") as Array).size())
		+ " chests=" + str((w.get("_chests") as Array).size()))
	# Back to the menu through the harness's canonical
	# inter-run cleanup — which, like the game's own
	# run-end path, does NOT touch the modal state (that
	# is the leak's whole point). start_game only runs
	# from "menu", so the reset under test is its
	# preamble, reached exactly as the closing suite
	# reached it: menu state + leaked modal state.
	await _c9_cleanup_run()
	var ok2 := await _c9_start_run("bulbasaur")
	_c9_check("c212: run 2 boots", ok2)
	_c9_check("c212: reset clears the choice modal + queued rolls",
		not bool(w.get("_choice_open")) and not (w.get("_choice_panel") as Control).visible
		and (w.get("_pending_item_rolls") as Array).is_empty(),
		"choice=" + str(w.get("_choice_open"))
		+ " pending=" + str((w.get("_pending_item_rolls") as Array).size()))
	_c9_check("c212: reset clears guardian chests + the portal node",
		(w.get("_chests") as Array).is_empty() and w.get("portal_node") == null,
		"chests=" + str((w.get("_chests") as Array).size()))
	# The next run must be alive: not stranded in the
	# leaked return state, and the run clock advances.
	var rt0 := float(w.get("run_time"))
	var advanced := await _c9_wait(func() -> bool: return float(w.get("run_time")) > rt0 + 0.5, 1800)
	_c9_check("c212: run 2 timers advance (not frozen by the leak)",
		advanced and String(w.get("state")) != "portal" and String(w.get("state")) != "choice",
		"state=" + String(w.get("state")) + " rt " + str(rt0) + "->" + str(float(w.get("run_time"))))
	# And the guardian summon gate the leak used to fail.
	w.summon_guardian()
	var g = w.get("guardian")
	var gok := await _c9_wait(func() -> bool: return g != null and g.rig != null and g.rig.fitted, 3600)
	_c9_check("c212: guardian summon proceeds in run 2", gok)
	await _c9_cleanup_run()

## Cycle 22: the non-UI alignment continuation — N6 luck
## clamp, ditto populate + imposter tick, the boss-mech
## fidelity follow-on (incl. the gengar/marowak stage
## truth), the golden-meowth event, fog blinding and the
## bundle event-spawn internals. All blocks drive the
## real paths (interact, choice picks, take_damage,
## casts, the event tick); forced state is limited to
## the same seams the c21 phase uses (mech forcing,
## event kind/clock sets, _boss_t quieting).

func _c23b2_phase() -> void:
	var snap: Dictionary = GameProfile.data.duplicate(true)
	var w = _world
	var ok := await _c9_start_run("bulbasaur")
	_c9_check("c23b2: isolated run boots", ok)
	if not ok:
		return
	var p = w.get("player")
	p.invulnerable = true
	w.set("zone", 2)
	w.set("state", "playing")
	w.set("boss_spawned", false)
	w.summon_guardian()
	var g2 = w.get("guardian")
	_c9_check("c23b2 F8: actual zone2 guardian is gengar", g2 != null and g2.species_id == "gengar")
	if g2:
		# F8: seeded RNG chooses ring; run the real brain dispatch,
		# then require its delayed hostile projectiles, not only a label.
		var f8_moves: Array = p.moves.duplicate(true)
		var f8_passive: String = p.passive_id
		var f8_pos: Vector3 = p.global_position
		p.moves.clear()
		p.passive_id = ""
		p.global_position = g2.global_position + Vector3(8, 0, 0)
		w.set("_boss_t", 0.0)
		w.set("_boss_last", "")
		w.set("_boss_hold_t", 0.0)
		var brng: RandomNumberGenerator = w.get("_bless_rng")
		var f8_rng_state := brng.state
		var seed_ring := 0
		for candidate in range(100):
			brng.seed = candidate
			if brng.randi_range(0, 4) == 1:
				seed_ring = candidate
				break
		brng.seed = seed_ring
		w.call("_boss_tick", 0.02)
		var dispatched := String(w.get("_boss_last")) == "ring" and float(w.get("_boss_t")) > 0.0
		var shots_before: int = (w.get("_hostiles") as Array).size()
		await _c211_wait_disarmed(w, p, 0.6)
		var shots_after: int = (w.get("_hostiles") as Array).size()
		_c9_check("c23b2 F8: zone2 gengar brain dispatches generic ring and fires",
			dispatched and shots_after >= shots_before + 14,
			"move=%s shots=%s->%s" % [w.get("_boss_last"), shots_before, shots_after])
		brng.state = f8_rng_state
		p.moves = f8_moves
		p.passive_id = f8_passive
		p.global_position = f8_pos
		g2.queue_free()

	w.set("guardian", null)
	await _c9_cleanup_run()
	GameProfile.data = snap
	GameProfile.save_profile()

func _c22_phase() -> void:
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	var w = _world
	var ok := await _c9_start_run("bulbasaur")
	_c9_check("c22: run boots", ok)
	if not ok:
		GameProfile.data = snap
		GameProfile.save_profile()
		return
	var p = w.get("player")
	var pid0: String = p.passive_id
	# ---- N6: chestCost clamps luck at 0 ----
	p.set("luck", 0.0)
	var c_luck0: int = w.call("_chest_cost")
	p.set("luck", -400.0)
	var c_neg: int = w.call("_chest_cost")
	p.set("luck", -100000.0)
	var c_neg2: int = w.call("_chest_cost")
	p.set("luck", 400.0)
	var c_pos: int = w.call("_chest_cost")
	p.set("luck", 0.0)
	_c9_check("c22 N6: negative luck never raises the chest price",
		c_neg == c_luck0 and c_neg2 == c_luck0,
		"luck0=" + str(c_luck0) + " neg=" + str(c_neg) + " neg2=" + str(c_neg2))
	_c9_check("c22 N6: positive luck still discounts", c_pos < c_luck0,
		"pos=" + str(c_pos) + " base=" + str(c_luck0))
	# ---- ditto populate + clone modal ----
	var st1: Dictionary = (w.get("_inter_state") as Dictionary).get(1, {})
	var ditto1: Dictionary = {}
	var ditto_count := 0
	for pr in (st1.get("props", []) as Array):
		if String((pr as Dictionary)["kind"]) == "ditto":
			ditto_count += 1
			ditto1 = pr
	_c9_check("c22 ditto: populate places exactly one ditto (zone 1)",
		ditto_count == 1, "n=" + str(ditto_count))
	if not ditto1.is_empty():
		_c9_check("c22 ditto: empty inventory refuses without consuming",
			p.items.is_empty())
		w.call("_interact_prop", ditto1)
		_c9_check("c22 ditto: empty inventory opens no modal, prop unspent",
			not bool(w.get("_choice_open")) and not bool(ditto1["used"]))
		p.add_item("secret-key")
		w.call("_interact_prop", ditto1)
		_c9_check("c22 ditto: the clone picker opens with items held",
			bool(w.get("_choice_open")))
		w.call("_choice_pick", 0)
		_c9_check("c22 ditto: the pick copies the item and spends the prop",
			p.item_count("secret-key") == 2 and bool(ditto1["used"]),
			"count=" + str(p.item_count("secret-key")) + " used=" + str(bool(ditto1["used"])))
		# Zone 2's ditto + a maxed item: the pick is denied
		# and the picker stays open (the bundle's Máx. card).
		w.call("_build_interactables", 2)
		var st2: Dictionary = (w.get("_inter_state") as Dictionary).get(2, {})
		var ditto2: Dictionary = {}
		for pr in (st2.get("props", []) as Array):
			if String((pr as Dictionary)["kind"]) == "ditto":
				ditto2 = pr
		_c9_check("c22 ditto: zone 2 also populates a ditto", not ditto2.is_empty())
		if not ditto2.is_empty():
			w.call("_interact_prop", ditto2)
			_c9_check("c22 ditto: picker opens for the maxed item", bool(w.get("_choice_open")))
			w.call("_choice_pick", 0)
			_c9_check("c22 ditto: a maxed pick is denied, picker stays open, prop unspent",
				bool(w.get("_choice_open")) and p.item_count("secret-key") == 2
				and not bool(ditto2["used"]))
			w.call("_choice_close", true)
			_c9_check("c22 ditto: cancel closes without spending the prop",
				not bool(w.get("_choice_open")) and not bool(ditto2["used"]))
		p.remove_item("secret-key")
		p.remove_item("secret-key")
	# ---- imposter: the 30 s type copy ----
	p.passive_id = "imposter"
	var r1 = w.call("_spawn_enemy_at", "rattata", p.global_position + Vector3(3, 0, 0), 40000.0, false, 1.0)
	var copied1 := await _c9_wait(func() -> bool: return p.types() == ["normal"], 600)
	_c9_check("c22 imposter: the tick copies the nearest enemy's types", copied1,
		"types=" + str(p.types()))
	if is_instance_valid(r1):
		r1.queue_free()
	var c1 = w.call("_spawn_enemy_at", "charmander", p.global_position + Vector3(5, 0, 0), 40000.0, false, 1.0)
	(w.get("_ptick_next") as Dictionary)[p.get_instance_id()] = 0.0
	var copied2 := await _c9_wait(func() -> bool: return p.types() == ["fire"], 600)
	_c9_check("c22 imposter: the next tick re-copies from the new nearest", copied2,
		"types=" + str(p.types()))
	if is_instance_valid(c1):
		c1.queue_free()
	p.passive_id = pid0
	p.types_override.clear()
	await _c9_frames(2)
	# ---- boss stage truth: gengar / marowak carry NO mech ----
	for sp22 in ["gengar", "marowak"]:
		var ge = w.call("_spawn_enemy_at", sp22, p.global_position + Vector3(20, 0, 0), 10.0, true, 2.6)
		w.set("guardian", ge)
		w.call("_boss_reset")
		_c9_check("c22 boss: stage " + sp22 + " has no db mech (tower classes are mode-gated)",
			String(w.get("_boss_mech")) == "", "mech=" + String(w.get("_boss_mech")))
		w.set("guardian", null)
		if is_instance_valid(ge):
			ge.queue_free()
	await _c9_frames(2)
	# ---- boss mech blocks on a real summoned guardian ----
	await _c21_settle_modals(w)
	w.set("zone", 1)
	w.set("state", "playing")
	w.set("boss_spawned", false)
	w.summon_guardian()
	await _c21_wait(w, 1.0)
	var g = w.get("guardian")
	_c9_check("c22 boss: guardian summoned for the mech blocks", g != null and g.is_inside_tree())
	if g == null:
		await _c9_cleanup_run()
		GameProfile.data = snap
		GameProfile.save_profile()
		return
	var php_max: float = p.max_hp
	p.max_hp = 200000.0
	p.hp = 200000.0
	p.moves.clear()
	# ---- starmie: the reflecting path ----
	w.set("_boss_mech", "starmie")
	w.set("_boss_mech_data", {"dizzy": 0.0, "path": [], "run": {}})
	p.global_position = g.global_position + Vector3(30, 0, 0)
	var pc: Vector3 = p.global_position
	var gpos0: Vector3 = g.global_position
	w.call("_boss_mech_cast")
	w.set("_boss_t", 99.0)  # the brain must not re-cast mid-run
	var sdata: Dictionary = w.get("_boss_mech_data")
	var path: Array = sdata.get("path", [])
	_c9_check("c22 starmie: the path has a start + 4 reflected legs", path.size() == 5,
		"n=" + str(path.size()))
	var on_circle := path.size() == 5
	for i in range(1, path.size()):
		var wp: Vector2 = path[i]
		var dd := Vector2(wp.x - pc.x, wp.y - pc.z).length()
		on_circle = on_circle and dd > 14.9 and dd < 15.1
	_c9_check("c22 starmie: every leg endpoint lies on the r15 circle", on_circle)
	if path.size() == 5:
		var sd0: Vector2 = path[0]
		_c9_check("c22 starmie: the start clamps onto the r14 circle",
			absf(Vector2(sd0.x - pc.x, sd0.y - pc.z).length() - 14.0) < 0.1)
	var dizzy_seen := false
	for i in range(40):
		await _c211_wait_disarmed(w, p, 0.25)
		if float((w.get("_boss_mech_data") as Dictionary).get("dizzy", 0.0)) > 0.0:
			dizzy_seen = true
			break
	_c9_check("c22 starmie: the run ends in the 2.5 s dizzy window", dizzy_seen)
	_c9_check("c22 starmie: the body travelled the path",
		g.global_position.distance_to(gpos0) > 3.0,
		"moved=" + str(g.global_position.distance_to(gpos0)))
	if dizzy_seen:
		_c9_check("c22 starmie: dizzy opens the core (hitMul x1.8)",
			absf(w.call("boss_hit_mul", g) - 1.8) < 0.001)
	# ---- dewgong: slides leave bursting ice trails ----
	w.set("_boss_mech", "dewgong")
	w.set("_boss_mech_data", {"slide": {}, "trails": [], "pending": 0})
	p.global_position = g.global_position + Vector3(10, 0, 0)
	w.call("_boss_mech_cast")
	var trails_seen := false
	for i in range(28):
		await _c211_wait_disarmed(w, p, 0.25)
		if not ((w.get("_boss_mech_data") as Dictionary).get("trails", []) as Array).is_empty():
			trails_seen = true
			break
	_c9_check("c22 dewgong: a slide leaves an ice trail segment", trails_seen)
	if trails_seen:
		var tr: Dictionary = ((w.get("_boss_mech_data") as Dictionary)["trails"] as Array)[0]
		var ta := Vector2(float(tr["ax"]), float(tr["az"]))
		var tb := Vector2(float(tr["bx"]), float(tr["bz"]))
		_c9_check("c22 dewgong: the trail spans the slide (length > 5)",
			ta.distance_to(tb) > 5.0, "len=" + str(ta.distance_to(tb)))
		var mid := ta.lerp(tb, 0.5)
		p.global_position = Vector3(mid.x, p.global_position.y, mid.y)
		var slip_seen := false
		var frozen_seen := false
		for i in range(20):
			await _c211_wait_disarmed(w, p, 0.2)
			if p.arena_slip > 0.5:
				slip_seen = true
			if p.pstat_t("frozen") > 0.0:
				frozen_seen = true
			if slip_seen and frozen_seen:
				break
		_c9_check("c22 dewgong: standing on the trail slips (arenaSlip)", slip_seen)
		_c9_check("c22 dewgong: the trail burst freezes the player on it", frozen_seen)
	await _c9_frames(2)
	# ---- lapras: object pillars, blockable pump, surf ----
	w.set("_boss_mech", "lapras")
	w.set("_boss_mech_data", {"pillars": [], "wave": {}})
	p.global_position = g.global_position + Vector3(12, 0, 0)
	w.set("_boss_t", 99.0)
	w.call("_boss_mech_cast")
	var pillars_seen := false
	for i in range(24):
		await _c211_wait_disarmed(w, p, 0.25)
		if ((w.get("_boss_mech_data") as Dictionary).get("pillars", []) as Array).size() == 5:
			pillars_seen = true
			break
	_c9_check("c22 lapras: five ice pillars rain onto the ring", pillars_seen)
	if pillars_seen:
		var ldata: Dictionary = w.get("_boss_mech_data")
		var prec: Dictionary = (ldata["pillars"] as Array)[0]
		var pe = prec["e"]
		_c9_check("c22 lapras: a pillar is a real hp body (1.2% of boss maxHp)",
			bool(pe.get("is_object")) and absf(float(pe.max_hp) - g.max_hp * 0.012) < 2.0,
			"hp=" + str(pe.max_hp) + " boss=" + str(g.max_hp))
		var object_pos: Vector3 = pe.global_position
		var object_types: Array = p.types_override.duplicate()
		pe.global_position = p.global_position + Vector3(0.5, 0, 0)
		_c9_check("c23b2 F6: actual ice pillar participates in within query",
			(w.call("_ptick_enemies_within", p.global_position, 1.0) as Array).has(pe))
		w.call("_ptick_fire", p, p.species_id, "imposter", true)
		_c9_check("c23b2 F6: imposter can copy actual ice pillar types",
			not pe.types.is_empty() and p.types() == pe.types, "types=" + str(p.types()))
		p.types_override = object_types
		pe.global_position = object_pos
		# Move pillar 0 onto the boss->player line: the pump
		# must be blocked by it.
		var line_mid: Vector3 = g.global_position.lerp(p.global_position, 0.5)
		pe.global_position = Vector3(line_mid.x, pe.global_position.y, line_mid.z)
		prec["x"] = line_mid.x
		prec["z"] = line_mid.z
		for e in get_tree().get_nodes_in_group("enemies"):
			if e != g and e != pe and not (ldata["pillars"] as Array).any(func(r): return r["e"] == e):
				e.queue_free()
		await _c9_frames(3)
		p.hp = p.max_hp
		var hp_block: float = p.hp
		w.call("_boss_lapras_pump")
		await _c211_wait_disarmed(w, p, 1.6)
		_c9_check("c22 lapras: a pillar on the line blocks the hydro pump",
			p.hp >= hp_block - 0.01, "hp " + str(hp_block) + "->" + str(p.hp))
		# Clear the pillars + the pending surf: the pump lands.
		for r in (ldata["pillars"] as Array):
			if is_instance_valid(r["e"]):
				(r["e"] as Node).queue_free()
		ldata["wave"] = {}
		await _c211_wait_disarmed(w, p, 0.4)
		_c9_check("c22 lapras: destroyed pillars leave the field",
			((w.get("_boss_mech_data") as Dictionary).get("pillars", []) as Array).is_empty())
		p.hp = p.max_hp
		var hp_open: float = p.hp
		w.call("_boss_lapras_pump")
		await _c211_wait_disarmed(w, p, 1.6)
		_c9_check("c22 lapras: unblocked, the pump strikes (x1.8)",
			p.hp < hp_open - 1.0, "hp " + str(hp_open) + "->" + str(p.hp))
	# ---- hypno: the pendulum builds drowsy -> sleep -> dream eater ----
	w.set("_boss_mech", "hypno")
	w.set("_boss_mech_data", {"swing": {}, "drowsy": 0.0, "dtick": 0.0})
	p.global_position = g.global_position + Vector3(8, 0, 0)
	p.hp = p.max_hp
	g.set_physics_process(false)  # isolate dream strike from contact iframes
	p.invulnerable = false
	p.evasion = 0.0
	p.shield = 0.0
	p.overheal = 0.0
	p.set("_invuln_t", 0.0)
	g.hp = g.max_hp * 0.5  # F4: leave room for the full 4% heal.
	var ghp_cast: float = g.hp
	var php_cast: float = p.hp
	w.set("_boss_t", 99.0)
	w.call("_boss_mech_cast")
	var slept := false
	for i in range(56):
		await _c211_wait_disarmed(w, p, 0.25)
		if p.pstat_t("sleep") > 0.0:
			slept = true
			break
		if (w.get("_boss_mech_data") as Dictionary).get("swing", {}).is_empty() and i > 8:
			w.call("_boss_mech_cast")  # a fresh 5 s swing
	_c9_check("c22 hypno: standing in the pendulum beam falls asleep", slept)
	if slept:
		_c9_check("c22 hypno: sleep blocks movement", p.status_move_blocked())
		await _c211_wait_disarmed(w, p, 1.2)
		_c9_check("c22 hypno: dream eater teleports in and feeds",
			g.global_position.distance_to(p.global_position) < 5.0
			and p.hp < php_cast,
			"gdist=" + str(g.global_position.distance_to(p.global_position))
			+ " ghp " + str(ghp_cast) + "->" + str(g.hp)
			+ " php " + str(php_cast) + "->" + str(p.hp))
	# F4: isolate the delayed strike from ambient contact/defense rolls.
	# Keep the real helper and timer callback; no simulated heal.
	var dream_timers: Array = (w.get("_timers") as Array).duplicate()
	w.set("_timers", [])
	g.hp = g.max_hp * 0.5
	var dream_hp: float = g.hp
	p.hp = p.max_hp
	p.invulnerable = false
	p.evasion = 0.0
	p.guard_t = 99.0
	p.shield = 0.0
	p.overheal = 0.0
	p.set("_invuln_t", 0.0)
	w.call("_boss_hypno_dream_eat")
	w.call("_timers_tick", 0.81)
	_c9_check("c23b2 F4: isolated dream strike actually damages player", p.hp < p.max_hp)
	_c9_check("c23b2 F4: dream eater heals exactly 4% independently",
		absf(g.hp - dream_hp - g.max_hp * 0.04) < 0.01,
		"hp=%s->%s max=%s" % [dream_hp, g.hp, g.max_hp])
	w.set("_timers", dream_timers)
	g.set_physics_process(true)
	# ---- cloyster: the shell snap binds ----
	w.set("_boss_mech", "cloyster")
	w.set("_boss_mech_data", {"open": true, "phase": 0.05})
	p.global_position = g.global_position + Vector3(2.5, 0, 0)
	await _c211_wait_disarmed(w, p, 0.6)
	_c9_check("c22 cloyster: the closing snap binds the player (1 s)",
		p.pstat_t("bound") > 0.0, "bound=" + str(p.pstat_t("bound")))
	w.set("_boss_mech", "")
	w.set("_boss_mech_data", {})
	p.max_hp = php_max
	p.hp = minf(p.hp, p.max_hp)
	if is_instance_valid(g):
		g.queue_free()
	w.set("guardian", null)
	w.set("state", "playing")
	await _c9_frames(3)
	# ---- golden meowth event ----
	w.set("_event_done", [])
	w.set("_event_kind", "meowth")
	w.set("_event_left", 25.0)
	w.call("_event_spawn_meowth")
	var me = w.get("_event_meowth")
	_c9_check("c22 meowth: the golden meowth spawns as a treasure body",
		me != null and is_instance_valid(me) and bool(me.get("treasure"))
		and absf(float(me.speed) - 7.4) < 0.01,
		"speed=" + (str(me.speed) if me else "null"))
	if me != null and is_instance_valid(me):
		_c9_check("c22 meowth: treasure HP is the x9 event body",
			absf(float(me.max_hp) - Enemy.base_hp("meowth") * w.call("_spawn_mult") * 9.0) < 1.0,
			"hp=" + str(me.max_hp))
		_c9_check("c22 meowth: the maps can mark the treasure",
			w.call("event_marker_pos") != null)
		# Test radial fleeing inside its 18 u steering threshold;
		# a random event spawn near 18 u legitimately switches to orbit.
		me.global_position = p.global_position + Vector3(6.0, 0.0, 0.0)
		me.global_position.y = w.height_at(me.global_position.x, me.global_position.z)
		var d0: float = me.global_position.distance_to(p.global_position)
		await _c211_wait_disarmed(w, p, 1.0)
		var d1: float = me.global_position.distance_to(p.global_position)
		_c9_check("c22 meowth: it flees the player", d1 > d0 + 1.5,
			"d " + str(d0) + "->" + str(d1))
		var gm: float = float(p.gold_mult)
		var hit_coin := int(ceil((2.0 + 1.0 * 2.0) * gm))
		var gold0 := _c23_pickup_value(w, 1)
		me.take_damage(1.0, "normal")
		_c9_check("c22 meowth: a hit spawns a coin entity",
			absf(_c23_pickup_value(w, 1) - (gold0 + hit_coin)) < 0.01,
			"gold " + str(gold0) + "->" + str(w.get("gold")) + " want+" + str(hit_coin))
		me.take_damage(1.0, "normal")
		_c9_check("c22 meowth: the coin drip respects its 0.16 s cooldown",
			absf(_c23_pickup_value(w, 1) - (gold0 + hit_coin)) < 0.01)
		w.set("_event_coin_cd", 0.0)
		var fountain := 30 * int(ceil((4.0 + 1.0 * 4.0) * gm))
		var gold_k := _c23_pickup_value(w, 1)
		var drip := floorf(float(w.get("pickups").gold_frac) + 0.2 * gm)
		me.take_damage(1000000.0, "normal")
		# The fountain rides on top of the standard kill
		# drip (0.2 x gold_mult, _award_kill) + the killing
		# blow's own coin.
		_c9_check("c22 meowth: the kill pays the 30-coin fountain and ends the event",
			absf(_c23_pickup_value(w, 1) - (gold_k + hit_coin + fountain + drip)) < 0.01
			and String(w.get("_event_kind")) == "" and w.get("_event_meowth") == null,
			"gold " + str(gold_k) + "->" + str(w.get("gold"))
			+ " want+" + str(hit_coin + fountain) + "+drip")
	# escape path: the clock runs out, no fountain
	w.set("_event_kind", "meowth")
	w.set("_event_left", 25.0)
	w.call("_event_spawn_meowth")
	var me2 = w.get("_event_meowth")
	_c9_check("c22 meowth: a second golden meowth can spawn", me2 != null and is_instance_valid(me2))
	if me2 != null and is_instance_valid(me2):
		var gold_e := float(w.get("gold"))
		w.set("_event_left", 0.05)
		var escaped := await _c9_wait(func() -> bool: return w.get("_event_meowth") == null, 240)
		_c9_check("c22 meowth: timeout escapes with no fountain",
			escaped and absf(float(w.get("gold")) - gold_e) < 0.01
			and String(w.get("_event_kind")) == "",
			"gold " + str(gold_e) + "->" + str(w.get("gold")))
	# ---- fog: blinding envelope + bundle spawn internals ----
	w.set("_event_kind", "fog")
	w.set("_event_k", 0.4)
	_c9_check("c22 fog: below k=0.5 the maps still see", not w.call("event_blind"))
	w.set("_event_k", 0.6)
	_c9_check("c22 fog: past k=0.5 the maps are blinded (sx.blind)", bool(w.call("event_blind")))
	w.set("_event_kind", "storm")
	_c9_check("c22 fog: only fog blinds", not w.call("event_blind"))
	w.set("_event_kind", "fog")
	w.set("_event_left", 40.0)
	w.set("_event_spawned_n", 0)
	w.set("_event_spawned", [])
	w.set("_event_spawn_t", 0.01)
	await _c211_wait_disarmed(w, p, 0.4)
	_c9_check("c22 fog: the event spawns batches of 3+zone",
		int(w.get("_event_spawned_n")) == 4, "n=" + str(w.get("_event_spawned_n")))
	var fog_xp := true
	for fe in (w.get("_event_spawned") as Array):
		if is_instance_valid(fe):
			fog_xp = fog_xp and absf(float(fe.get("xp_mult")) - 2.0) < 0.01
	_c9_check("c22 fog: fog spawns carry double XP", fog_xp)
	var flying_ok := not (w.get("_event_spawned") as Array).is_empty()
	for fe in (w.get("_event_spawned") as Array):
		flying_ok = flying_ok and is_instance_valid(fe) and (int(fe.flag) & 16) != 0
	_c9_check("c23b2 fog: every event spawn carries Flying=16", flying_ok)

	w.set("_event_spawned_n", 30)
	w.set("_event_spawn_t", 0.01)
	await _c211_wait_disarmed(w, p, 0.4)
	_c9_check("c22 fog: the spawn cap (30) holds", int(w.get("_event_spawned_n")) == 30)
	for fe in (w.get("_event_spawned") as Array):
		if is_instance_valid(fe):
			(fe as Node).queue_free()
	w.set("_event_kind", "eclipse")
	w.set("_event_left", 35.0)
	w.set("_event_spawned", [])
	w.set("_event_spawned_n", 0)
	w.set("_event_spawn_t", 0.0)
	w.set("elapsed", 120.0)
	w.call("_event_tick", 0.02)
	var elites: Array = w.get("_event_spawned")
	_c9_check("c23b2 eclipse: first spawn elite radius and body scale 1.35",
		not elites.is_empty() and int(elites[0].flag) == 1
		and absf(elites[0].radius - 0.55 * 1.35) < 0.0001
		and absf(elites[0].body_height - float(ModelRig.SPECIES.get(elites[0].species_id, {}).get("height", 1.0)) * 1.35) < 0.0001,
		"radius=" + str(elites[0].radius if not elites.is_empty() else -1))
	if not elites.is_empty():
		var er = elites[0].rig
		await _c9_wait(func() -> bool: return is_instance_valid(er) and er.fitted, 600)
		var ecfg: Dictionary = ModelRig.SPECIES[elites[0].species_id]
		_c9_check("c23b2 eclipse: fitted model itself has scale 1.35",
			er.fitted and ecfg.has("native")
			and absf(er._base_scale.x - float(ecfg["height"]) * 1.35 / float(ecfg["native"])) < 0.0001,
			"species=%s scale=%s" % [elites[0].species_id, er._base_scale.x])
	_c9_check("c23b2 eclipse: other event spawns keep normal radius",
		elites.size() == 4 and absf(elites[1].radius - 0.55) < 0.0001)
	for ee in elites:
		if is_instance_valid(ee):
			ee.queue_free()
	w.set("_event_kind", "")
	w.set("_event_k", 0.0)
	await _c9_frames(2)

	await _c9_cleanup_run()
	GameProfile.data = snap
	GameProfile.save_profile()

## P1.2: complete Magikarp's roster challenge (runs >= 25) through
## 25 REAL runs (start -> lethal damage -> _finish_run), then prove
## the league encounter pool is global: magikarp is in NO zone's
## wild pool, so only the global leagueReady pool can produce it.
func _c9_league_phase() -> void:
	var runs0 := int(GameProfile.counter_value("runs"))
	for i in range(25):
		var ok := await _c9_start_run("bulbasaur")
		if not ok:
			_c9_check("league: run %d boots" % (i + 1), false, "player never fitted")
			return
		var p = _world.get("player")
		p.invulnerable = false
		# Lethal damage can be DODGED (the evasion roll) — repeat
		# until the run actually ends.
		var dead := false
		for att in range(30):
			p.set("_invuln_t", 0.0)
			p.take_damage(99999.0)
			dead = await _c9_wait(func() -> bool: return String(_world.get("state")) == "dead", 60)
			if dead:
				break
		if not dead:
			_c9_check("league: run %d finishes" % (i + 1), false, "state=" + String(_world.get("state")))
			return
		await _c9_cleanup_run()
	_c9_check("league: 25 real runs counted", int(GameProfile.counter_value("runs")) >= runs0 + 25,
		"runs=" + str(GameProfile.counter_value("runs")))
	_c9_check("league: magikarp challenge complete via runs", bool(GameProfile.challenge_done("magikarp")))
	# Roster kit + passive data reach unlocked species (P1.2 tail).
	var entry: Dictionary = GameData.roster_entry(129)
	_c9_check("league: magikarp kit == roster kit[4]",
		GameData.kit("magikarp") == (entry.get("kit", []) as Array),
		"kit=" + str(GameData.kit("magikarp")))
	_c9_check("league: passive mods load from abilities data",
		not (GameData.passive_mods("swift-swim") as Array).is_empty(),
		"mods=" + str(GameData.passive_mods("swift-swim")))
	# Encounter: isolate the eligible family to Magikarp, so a fresh
	# save and RNG order cannot turn a global-pool regression into a lottery.
	# A zone-filtered implementation still cannot spawn Magikarp.
	var ok2 := await _c9_start_run("bulbasaur")
	if not ok2:
		_c9_check("league: encounter run boots", false)
		return
	var p2 = _world.get("player")
	p2.invulnerable = true
	p2.moves.clear()
	var old_league: Array = GameProfile.data.get("league", []).duplicate()
	var magikarp_family := int(GameData.species("magikarp").get("family", -1))
	var isolated_league: Array = []
	for species in GameData.roster_species_keys():
		var family := int(GameData.species(String(species)).get("family", -1))
		if family != magikarp_family and not isolated_league.has(family):
			isolated_league.append(family)
	GameProfile.data["league"] = isolated_league
	var seen := {}
	for t in range(8):
		_world._spawn_league()
		await _c9_frames(3)
		for e in get_tree().get_nodes_in_group("enemies"):
			if int(e.get("mode")) == 2:  # Enemy.MODE_LEAGUE
				seen[String(e.get("species_id"))] = true
				e.queue_free()
		_world.set("_league_e", null)
		if seen.has("magikarp"):
			break
	GameProfile.data["league"] = old_league
	GameProfile.save_profile()
	_c9_check("league: GLOBAL pool spawns magikarp (in no zone pool)", seen.has("magikarp"),
		"seen=" + str(seen.keys()))
	# leave the run alive for the guardian phase when running all

## P1.3 + counter flush: guardian rewards through the real kill
## path, chest opening, and the lifetime counter merge at run end.
func _c9_guardian_phase() -> void:
	if String(_world.get("state")) != "playing":
		var ok := await _c9_start_run("bulbasaur")
		if not ok:
			_c9_check("guardian: run boots", false)
			return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	# Status counting through the real take_damage ailment path.
	var pos: Vector3 = p.global_position + Vector3(3.0, 0, 0)
	pos.y = w.height_at(pos.x, pos.z)
	var dummy = w._spawn_enemy_at("rattata", pos, 50.0, false, 1.0)
	await _c9_wait(func() -> bool: return dummy != null and dummy.rig != null and dummy.rig.fitted, 1800)
	dummy.take_damage(1.0, "fire", "burn", 100.0)
	_c9_check("guardian: burn application counted in-run",
		float((w.get("run_counts") as Dictionary).get("burned", 0)) >= 1.0,
		"run_counts=" + str(w.get("run_counts")))
	dummy.queue_free()
	await _c9_frames(2)
	# Guardian through the real summon + damage path.
	w.summon_guardian()
	var g = w.get("guardian")
	var gok := await _c9_wait(func() -> bool: return g != null and g.rig != null and g.rig.fitted, 3600)
	if not gok:
		_c9_check("guardian: summon + fit", false)
		return
	var gold0 := float(w.get("gold"))
	var lvl0: int = p.level + p.pending_levels
	var roars: int = g.roars
	# Cycle 14: the Eb damage cap banks at 3x capRate and refills at
	# capRate/s, so no single blow can one-shot the guardian — the
	# kill flows THROUGH the cap in a bounded hit-until-dead loop
	# (the cycle-9 assertion intent is unchanged).
	var guardian_chest: Dictionary = {}
	var guardian_chest_pos: Variant = null
	var guard_frames := 0
	var gold_blow := 0.0
	var chest_blow := 0
	while g.hp > 0.0 and guard_frames < 7200:
		# Cycle 19 harness pacing, second trap (found by the
		# fixed loop): the gold window must be the killing
		# blow itself. Gold read on both sides of the fatal
		# take_damage — same synchronous call, so no ambient
		# wild-kill coin can land inside the measurement;
		# a whole-loop window collects them (delta 103.2 /
		# 141 against exact 100 / 140 in the wild).
		var pre_gold := _c23_pickup_value(w, 1)
		var pre_chests: int = (w.get("_chests") as Array).size()
		g.take_damage(g.max_hp * 0.2, "")
		if g.hp <= 0.0:
			gold_blow = _c23_pickup_value(w, 1) - pre_gold
			chest_blow = (w.get("_chests") as Array).size() - pre_chests
			# F3: capture before ANY awaited frame can auto-open it.
			if chest_blow > 0:
				guardian_chest = (w.get("_chests") as Array)[pre_chests]
				guardian_chest_pos = guardian_chest["node"].global_position
				p.global_position = guardian_chest_pos + Vector3(8, 0, 0)
				p.global_position.y = w.height_at(p.global_position.x, p.global_position.z)
				p.set("_vel", Vector3.ZERO)
				p.reset_physics_interpolation()

		await _c9_frames(1)
		# Cycle 19 harness pacing (root-caused in cycle 18):
		# XP earned mid-loop (the player's auto-fire clears
		# nearby wild spawns) opens a level-up draft, and in
		# draft the world clock — the guardian's cap refill
		# included — is frozen BY DESIGN, so an unserviced
		# loop can never kill through the cap. Service the
		# draft through the real pick path (the function
		# the card buttons call); assertions unchanged.
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		guard_frames += 1
	_c9_check("guardian: killed through the damage cap", g.hp <= 0.0,
		"frames=" + str(guard_frames))
	_c9_check("guardian: boss-kill hitstop 0.5 engaged", float(w.get("_hitstop_t")) > 0.4,
		"hitstop_t=" + str(w.get("_hitstop_t")))
	# Cycle 20: the coin value is wB = ceil(5 x stage x gold)
	# — NO shiny factor exists (DIFF §7 correction: Be() is a
	# perk ladder with no gold consumer; the factor cycle 19
	# asserted here was invented and is removed).
	var want_gold := 20 * int(ceil(5.0 * 1.0 * p.gold_mult))
	_c9_check("guardian: coin entities == 20 x ceil(5 x stage x gold)",
		absf(gold_blow - float(want_gold)) < 0.01,
		"blow_delta=" + str(gold_blow) + " want=" + str(want_gold))
	_c9_check("guardian: chests == 1 + roars",
		chest_blow == 1 + roars,
		"spawned=" + str(chest_blow) + " roars=" + str(roars))
	_c9_check("guardian: candy entity waits for pickup",
		_c23_pickup_value(w, 6) >= 1.0,
		"lvl delta=" + str((p.level + p.pending_levels) - lvl0))
	print("F3DBG before settle count=", GameProfile.counter_value("chests"), " boxes=", _c23b2_chest_marks(w))
	await _c9_settle_drafts()
	print("F3DBG after settle count=", GameProfile.counter_value("chests"), " boxes=", _c23b2_chest_marks(w))
	_c9_check("c23b2 F3: captured guardian chest survives draft settle unopened",
		guardian_chest_pos != null and not bool(guardian_chest.get("opened", true)))
	# Open the captured reward by walking onto it (real proximity path).
	var cps: Array = [guardian_chest_pos] if guardian_chest_pos != null else []
	if not cps.is_empty():
		var cp: Vector3 = cps[0]
		var chests_before := int(GameProfile.counter_value("chests"))
		p.global_position = Vector3(cp.x, w.height_at(cp.x, cp.z), cp.z)
		p.reset_physics_interpolation()
		var opened := false
		for wi in range(900):
			await get_tree().physics_frame
			if String(w.get("state")) == "draft":
				w._apply_draft_option(0)  # the world clock pauses in draft
			# 'chests' is a lifetime counter: count_event writes it
			# straight to the profile (like dodges/gold).
			if int(GameProfile.counter_value("chests")) > chests_before:
				opened = true
				break
		print("F3DBG after walk count=", GameProfile.counter_value("chests"), " boxes=", _c23b2_chest_marks(w))
		_c9_check("guardian: chest opens on walk-over + counts", opened)
		_c9_check("c23b2 F3: captured reward itself is marked opened", bool(guardian_chest.get("opened", false)))
	else:
		_c9_check("guardian: chest exists to open", false)
	# End the run: lifetime flush must carry 'burned' across.
	# (Repeated hits: a single one can be evasion-dodged.)
	p.invulnerable = false
	var dead := false
	for att in range(30):
		p.set("_invuln_t", 0.0)
		p.take_damage(99999.0)
		dead = await _c9_wait(func() -> bool: return String(w.get("state")) == "dead", 60)
		if dead:
			break
	_c9_check("guardian: run ends", dead)
	_c9_check("guardian: lifetime 'burned' flushed at run end",
		int(GameProfile.counter_value("burned")) >= 1,
		"burned=" + str(GameProfile.counter_value("burned")))
	await _c9_cleanup_run()

func _c23b2_chest_marks(w: Node) -> Array:
	var result: Array = []
	for c in (w.get("_chests") as Array):
		result.append({"opened": c.get("opened"), "valid": is_instance_valid(c.get("node"))})
	return result

## P1.1 + P2 ally: slam through combat.hit (STAB x1.25, damage and
## physical multipliers, slamStat) with crit pinned off as a
## fixture; knockback + hitstop channels; a real key-driven dive
## slam; ally power recomputed live + typed AoE land.
func _c9_slam_phase() -> void:
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("slam: run boots", false)
		return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()  # no auto-attacks polluting damage deltas
	var pos: Vector3 = p.global_position + Vector3(2.5, 0, 0)
	pos.y = w.height_at(pos.x, pos.z)
	var e = w._spawn_enemy_at("rattata", pos, 50.0, false, 1.0)
	await _c9_wait(func() -> bool: return e != null and e.rig != null and e.rig.fitted, 1800)
	e.max_hp = 10000.0
	e.hp = 10000.0
	p.crit_chance = 0.0  # fixture: one deterministic pipeline reading
	var hp0: float = e.hp
	w.player_slam(p.global_position, 8.0, true)  # fallH 8 -> o = 1
	var dealt: float = hp0 - e.hp
	var eff: float = GameData.type_mult("grass", e.types)
	var expected: float = (12.0 + 1.5 * float(p.level)) * float(w.SLAM_STAGE_MULT[0]) \
		* p.slam_mult * 3.0 * p.damage_mult * p.phys * 1.25 * eff
	_c9_check("slam: damage == bundle pipeline value (STAB incl.)",
		absf(dealt - expected) <= maxf(1.0, expected * 0.03),
		"dealt=" + str(dealt) + " expected=" + str(expected))
	_c9_check("slam: hitstop engaged on hit", float(w.get("_hitstop_t")) > 0.03,
		"hitstop_t=" + str(w.get("_hitstop_t")))
	_c9_check("slam: knockback channel applied (3+3o)",
		(e.get("_kb_vel") as Vector3).length() > 2.0,
		"kb=" + str(e.get("_kb_vel")))
	# Real dive: jump with the space key, dash with shift at the
	# apex, land — the slam must fire through the gameplay path.
	e.queue_free()
	await _c9_frames(2)
	# 'slams' is counted via count_event -> the profile counter.
	var slams0 := int(GameProfile.counter_value("slams"))
	# Primer touch early: latches the touch layer visible so the
	# dash BUTTON can take the dive input later (a synthetic
	# KEY_SHIFT does not satisfy is_key_pressed(KEY_SHIFT) — it
	# tracks the left/right physical keys).
	_c9_touch(Vector2(250, 520), true)
	for i in range(4):
		await get_tree().process_frame
	_c9_touch(Vector2(250, 520), false)
	for i in range(4):
		await get_tree().process_frame
	# Hold the key until the state machine confirms the jump —
	# synthetic key events flush on rendered frames, which are
	# far slower than physics frames under software rendering.
	_c9_key(KEY_SPACE, true)
	var airborne := await _c9_wait(func() -> bool: return not bool(p.get("_grounded")), 900)
	_c9_key(KEY_SPACE, false)
	var apex := airborne and await _c9_wait(func() -> bool:
		return float(p.get("_vy")) < 3.0 \
			and p.global_position.y - w.height_at(p.global_position.x, p.global_position.z) > 1.3, 1200)
	if apex:
		var tc = w.get("touch_controls")
		var dc: Vector2 = tc.debug_button_center("dash")
		# Delivered through the dash area's gui_input signal
		# (see _c9_gui_touch: the headless viewport does no GUI
		# picking for synthetic events; the primer above still
		# latches the layer through the real _input path).
		var dash_area: Control = null
		# Cycle 18: _buttons became a kind->rec Dictionary.
		var dash_rec: Dictionary = (tc.get("_buttons") as Dictionary).get("dash", {})
		dash_area = dash_rec.get("area") as Control
		_c9_gui_touch(dash_area, dc, true)
		await _c9_frames(10)
		_c9_gui_touch(dash_area, dc, false)
		var slammed := await _c9_wait(func() -> bool:
			return int(GameProfile.counter_value("slams")) > slams0, 1800)
		_c9_check("slam: real dive (jump key -> dash button) fires a slam", slammed)
	else:
		_c9_check("slam: real dive reaches apex", false, "vy/height never qualified")
	# Ally: live power + typed AoE.
	var mk_foe := func(off: Vector3) -> Node:
		var fp: Vector3 = p.global_position + off
		fp.y = w.height_at(fp.x, fp.z)
		var f = w._spawn_enemy_at("rattata", fp, 50.0, false, 1.0)
		f.max_hp = 5000.0
		f.hp = 5000.0
		return f
	var foe1 = mk_foe.call(Vector3(6.0, 0, 0))
	var foe2 = mk_foe.call(Vector3(6.8, 0, 0.8))
	var far = mk_foe.call(Vector3(20.0, 0, 0))
	var apos: Vector3 = p.global_position + Vector3(5.4, 0, 0)
	apos.y = w.height_at(apos.x, apos.z)
	var ally = w._spawn_enemy_at("bulbasaur", apos, 50.0, false, 1.0)
	await _c9_wait(func() -> bool: return ally != null and ally.rig != null and ally.rig.fitted, 1800)
	ally.make_ally()
	var pow0: float = ally.ally_power_now()
	p.level += 5  # fixture: the ally must track the CURRENT level
	var pow1: float = ally.ally_power_now()
	p.level -= 5
	_c9_check("ally: power recomputed live at current level", pow1 > pow0 * 1.15,
		"pow0=" + str(pow0) + " pow1(+5lv)=" + str(pow1))
	var h1: float = foe1.hp
	var h2: float = foe2.hp
	var hf: float = far.hp
	w.ally_land(ally)
	var a_expected: float = pow0 * p.damage_mult * p.phys * 1.25 * GameData.type_mult("grass", foe1.types)
	_c9_check("ally: land AoE hits both in-radius foes, spares far foe",
		foe1.hp < h1 and foe2.hp < h2 and far.hp >= hf,
		"d1=" + str(h1 - foe1.hp) + " d2=" + str(h2 - foe2.hp) + " far=" + str(hf - far.hp))
	_c9_check("ally: land damage == typed pipeline value",
		absf((h1 - foe1.hp) - a_expected) <= maxf(1.0, a_expected * 0.03),
		"dealt=" + str(h1 - foe1.hp) + " expected=" + str(a_expected))
	await _c9_cleanup_run()

## Hotfix (cycle 11 attack feel): the player's AUTO-ATTACK through
## the real chain — zero input events of any kind. A real enemy is
## pinned inside strike range (fixture pinning, positions only);
## the move must fire on cooldown by itself, each hit must remove
## exactly the pipeline damage (crit pinned off as a fixture), and
## the rig's lunge at the fire moment must thrust TOWARD the target
## (the cycle-11 build thrust away: fwd was -basis.z while every
## GLB faces +Z). A second case pins the enemy one terrace step
## below the player: still inside the horizontal strike range, it
## must be hit (the old 3D-distance targeting gate could never
## acquire it). Mutation sensitivity: zeroing _roll_damage fails
## the damage checks; flipping the lunge sign fails the motion
## check (wrong-way max forward offset is the +0.10 anticipation).
func _c9_attack_phase() -> void:
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("attack: run boots", false)
		return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	p.crit_chance = 0.0  # fixture: deterministic pipeline readings
	var anchor: Vector3 = p.global_position + Vector3(2.3, 0, 0)
	anchor.y = w.height_at(anchor.x, anchor.z)
	var e = w._spawn_enemy_at("rattata", anchor, 1.0, false, 1.0)
	await _c9_wait(func() -> bool: return e != null and e.rig != null and e.rig.fitted, 1800)
	e.max_hp = 100000.0
	e.hp = 100000.0
	var p_anchor: Vector3 = p.global_position
	var mv: Dictionary = p.moves[0]
	var mtype := String(GameData.move(String(mv["key"])).get("type", ""))
	var expected: float = p.move_damage(mv) * GameData.type_mult(mtype, e.types)
	# --- case 1: flat, in range, zero input ----------------------
	# Fixture isolation: existing wild spawns are cleared once and
	# the world's spawner is held shut via its own _spawn_t — a
	# wandering wild enemy is NEARER than the pinned target and
	# would legitimately steal the strike's aim for a tick, making
	# "hits on the pinned target" undercount real fires.
	for oe in get_tree().get_nodes_in_group("enemies"):
		if oe != e:
			oe.queue_free()
	await _c9_frames(3)
	e.max_hp = 100000.0
	e.hp = 100000.0
	var fires := 0
	var hits := 0
	var hp_prev: float = e.hp
	# Cycle 15 fixture fix: cd_prev baselines from the move's
	# CURRENT cd_t, not 0.0. A cast that completed during the
	# setup waits (its damage already dealt and erased by the
	# hp reset above) otherwise reads as a phantom fire at
	# sample 0 whose hit can never be counted — whether the
	# phantom appears depends on the cast-cycle phase at loop
	# entry, which scene growth shifted. With both trackers
	# baselined at the same instant, every counted fire is a
	# cast inside the window and hits == fires stays exact.
	var cd_prev := float(mv.get("cd_t"))
	var fwd_max := 0.0
	var window := 0
	for f in range(420):
		await get_tree().physics_frame
		w.set("_spawn_t", 5.0)
		e.global_position = anchor
		e.set("_kb_vel", Vector3.ZERO)
		p.global_position = p_anchor
		var cd: float = float(mv.get("cd_t"))
		if cd_prev < 0.4 and cd > 0.5:
			fires += 1
			window = 30
		cd_prev = cd
		if float(e.hp) < hp_prev:
			hits += 1
			hp_prev = float(e.hp)
		if window > 0:
			window -= 1
			var off: Vector3 = p.rig.model.position - p.rig.base_pos
			var fwd: Vector3 = p.rig.transform.basis.z
			fwd.y = 0.0
			if fwd.length() > 0.01:
				fwd_max = maxf(fwd_max, off.dot(fwd.normalized()))
	var total: float = 100000.0 - float(e.hp)
	_c9_check("attack: auto-fire triggers with zero input", fires >= 3,
		"fires=" + str(fires))
	_c9_check("attack: every fire lands a hit", hits >= 3 and hits == fires,
		"hits=" + str(hits) + " fires=" + str(fires))
	_c9_check("attack: damage == hits x pipeline value",
		absf(total - hits * expected) <= maxf(1.0, hits * expected * 0.03),
		"total=" + str(total) + " hits=" + str(hits) + " expected/hit=" + str(expected))
	_c9_check("attack: lunge thrusts TOWARD the target (>= 0.25 u)",
		fwd_max >= 0.25, "fwd_max=" + str(fwd_max))
	# --- case 2: enemy one terrace step below --------------------
	# Scan the zone for a real terrace edge: an upper point A and a
	# point B 2.3 u away at least 3.5 u lower (one 4.6 step, net of
	# the riser smoothing), neither in a pond. The pair relocates:
	# player pinned at A, enemy pinned at B. Pre-fix, the 3D gate
	# sqrt(2.3^2 + 3.5^2) ~= 4.2 > 3.6 could never acquire B.
	var up_anchor := Vector3.ZERO
	var step_anchor := Vector3.ZERO
	var found := false
	var gx := -60.0
	while gx <= 60.0 and not found:
		var gz := -60.0
		while gz <= 60.0 and not found:
			var a := Vector3(p_anchor.x + gx, 0, p_anchor.z + gz)
			a.y = w.height_at(a.x, a.z)
			if absf(w.surface_at(a.x, a.z) - a.y) < 0.01:
				for ai in range(8):
					var ang := TAU * float(ai) / 8.0
					var b := Vector3(a.x + cos(ang) * 2.3, 0, a.z + sin(ang) * 2.3)
					b.y = w.height_at(b.x, b.z)
					if a.y - b.y >= 3.5 and absf(w.surface_at(b.x, b.z) - b.y) < 0.01:
						up_anchor = a
						step_anchor = b
						found = true
						break
			gz += 3.0
		gx += 3.0
	if found:
		p.global_position = up_anchor
		p.reset_physics_interpolation()
		e.max_hp = 100000.0
		e.hp = 100000.0
		var hp2: float = e.hp
		var dropped := false
		for f in range(300):
			await get_tree().physics_frame
			w.set("_spawn_t", 5.0)
			for oe in get_tree().get_nodes_in_group("enemies"):
				if oe != e:
					oe.queue_free()
			e.global_position = step_anchor
			e.set("_kb_vel", Vector3.ZERO)
			p.global_position = up_anchor
			if float(e.hp) < hp2:
				dropped = true
				break
		_c9_check("attack: target one terrace below is hit (horizontal gate)",
			dropped, "dy=" + str(up_anchor.y - step_anchor.y))
	else:
		print("C9 SKIP attack: no terrace-step point in zone")
	await _c9_cleanup_run()

## Cycle 13: the ultimate, end to end through the real paths.
## Charge rules are asserted on SYNCHRONOUS blocks (event ->
## read, no frames between, so passive accrual cannot blur the
## deltas): passive rate, kill credits (plain/elite/alpha/boss),
## the killRoom throttle, slot-8 exclusion (combat_hit slot 8
## AND a real burn-DoT kill), hurt credit. Firing is driven
## through the actual HUD button (gui_input signal with a
## synthetic press) and through the real KeyR input path; cast
## damage is collected drop-by-drop while the target is pinned
## and compared against the combat pipeline value. Mutations:
## BASE_DMG 40 -> 0 zeroes every cast drop; onKill boss .2 -> 0
## zeroes the boss credit.
func _c9_ult_phase() -> void:
	# ---------------- Bulbasaur: controller + charge rules ------
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("ult: run boots", false)
		return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	p.crit_chance = 0.0  # fixture: deterministic pipeline readings
	var ult = w.get("ult")
	_c9_check("ult: controller exists per run", ult != null)
	_c9_check("ult: bulbasaur def name/duration (form 0)",
		ult.ult_name() == "Furious Roots" and absf(ult.cast_dur() - 1.6) < 0.001,
		"name=" + ult.ult_name() + " dur=" + str(ult.cast_dur()))
	# Approved UI: single-language label; definition identity is still checked above.
	#
	# the check's intent stands: the REAL def name is shown.
	_c9_check("ult: HUD label shows the real def name",
		(w.get("_ult_name_label") as Label).text == Ult.display_name("Furious Roots"),
		"label=" + (w.get("_ult_name_label") as Label).text)
	w.set_base_weather("clear")  # fixture: exact pipeline readings
	# Passive gain: 9.5 s of update == +0.1 x rate, synchronously.
	var c0: float = ult.charge
	ult.update(9.5)
	_c9_check("ult: passive charge == dt/95 x rate",
		absf(ult.charge - minf(1.0, c0 + 0.1 * ult.rate())) < 0.0001,
		"charge=" + str(ult.charge) + " from=" + str(c0))
	# Kill credits: five fitted rattata, killed synchronously.
	var foes: Array = []
	for i in range(6):
		var fp: Vector3 = p.global_position + Vector3(4.0 + float(i) * 1.5, 0, 3.0)
		fp.y = w.height_at(fp.x, fp.z)
		var f = w._spawn_enemy_at("rattata", fp, 50.0, false, 1.0)
		foes.append(f)
	for f in foes:
		await _c9_wait(func() -> bool: return f != null and f.rig != null and f.rig.fitted, 1800)
	ult.charge = 0.0
	ult.kill_room = Ult.ROOM_CAP
	var before: float
	before = ult.charge
	foes[0].take_damage(99999.0, "normal")
	_c9_check("ult: plain kill == +min(.004, room)",
		absf(ult.charge - before - 0.004) < 0.000001, "charge=" + str(ult.charge))
	before = ult.charge
	foes[1].take_damage(99999.0, "normal")
	_c9_check("ult: second plain kill == +.004, room drained",
		absf(ult.charge - before - 0.004) < 0.000001
			and absf(ult.kill_room - (Ult.ROOM_CAP - 0.008)) < 0.000001,
		"charge=" + str(ult.charge) + " room=" + str(ult.kill_room))
	foes[2].flag = 1
	before = ult.charge
	foes[2].take_damage(99999.0, "normal")
	_c9_check("ult: elite kill == +.03",
		absf(ult.charge - before - 0.03) < 0.000001, "charge=" + str(ult.charge))
	foes[3].flag = 2
	foes[3].max_hp = 10000.0
	foes[3].hp = 10000.0
	before = ult.charge
	# An alpha DOWNs instead of dying: the kill (and its credit)
	# lands when the downed window expires — force the lethal
	# path's second stage directly via the window timer.
	foes[3].take_damage(99999.0, "normal")
	foes[3].set("down_t", 0.01)
	var alpha_ok := await _c9_wait(func() -> bool:
		return ult.charge - before >= 0.079, 600)
	# Range, not exact: a render frame of passive gain (<= ~.004)
	# may land between the read and the credit.
	_c9_check("ult: alpha kill == +.08",
		alpha_ok and ult.charge - before <= 0.09,
		"delta=" + str(ult.charge - before))
	foes[4].flag = 4
	before = ult.charge
	foes[4].take_damage(99999.0, "normal")
	_c9_check("ult: boss-flag kill == +.2",
		absf(ult.charge - before - 0.2) < 0.000001, "charge=" + str(ult.charge))
	# Slot 8: an ult-attributed kill earns NOTHING.
	before = ult.charge
	w.combat_hit(foes[5], 99999.0, "normal", "physical", [], {"slot": 8})
	_c9_check("ult: slot-8 kill == +0 (no refund)",
		absf(ult.charge - before) < 0.000001 and int(foes[5].get("last_hit_slot")) == 8,
		"charge=" + str(ult.charge) + " slot=" + str(foes[5].get("last_hit_slot")))
	# The kill sequence pays real XP (boss flag x60): a level-up
	# draft may have opened, and opening a draft PAUSES the world
	# (running = false by design). Settle it through the world's
	# own close path before any segment that needs the world
	# clock or the ult trigger (both require the play state).
	var settle := func() -> void:
		p.pending_levels = 0
		p.xp = 0.0
		if String(w.get("state")) == "draft":
			w._close_draft()
	settle.call()
	# DoT kill: burn applied for real, HP fixtured to 3 — the
	# fixed 4.0/s status tick lands the kill within a second.
	var dp: Vector3 = p.global_position + Vector3(-4.0, 0, 3.0)
	dp.y = w.height_at(dp.x, dp.z)
	var dot_e = w._spawn_enemy_at("rattata", dp, 50.0, false, 1.0)
	await _c9_wait(func() -> bool: return dot_e != null and dot_e.rig != null and dot_e.rig.fitted, 1800)
	dot_e.max_hp = 1000.0
	dot_e.hp = 1000.0
	dot_e.take_damage(1.0, "fire", "burn", 100.0)
	_c9_check("ult: burn applied for the DoT kill",
		String(dot_e.get("status_kind")) == "burn",
		"status=" + String(dot_e.get("status_kind")))
	dot_e.hp = 3.0
	before = ult.charge
	var dot_seen := {"slot": -1}
	var dot_dead := await _c9_wait(func() -> bool:
		if not is_instance_valid(dot_e):
			return false
		if float(dot_e.get("hp")) <= 0.0:
			dot_seen["slot"] = int(dot_e.get("last_hit_slot"))
			return true
		return false, 900)
	_c9_check("ult: burn DoT kill carries slot 8",
		dot_dead and int(dot_seen["slot"]) == 8,
		"dead=" + str(dot_dead) + " slot=" + str(dot_seen["slot"]))
	_c9_check("ult: DoT kill adds no kill credit (passive drift only)",
		ult.charge - before < 0.006, "delta=" + str(ult.charge - before))
	# Hurt credit: real take_damage, evasion pinned off and the
	# phase's invulnerable fixture lifted for this one hit; the
	# HP delta is ground truth for the fraction.
	p.evasion = 0.0
	p.invulnerable = false
	p.set("_invuln_t", 0.0)
	var hp0: float = p.hp
	before = ult.charge
	p.take_damage(20.0)
	var frac: float = (hp0 - p.hp) / p.max_hp
	_c9_check("ult: hurt credit == .35 x damage fraction x rate",
		frac > 0.0 and absf(ult.charge - before - 0.35 * frac * ult.rate()) < 0.0001,
		"delta=" + str(ult.charge - before) + " want=" + str(0.35 * frac * ult.rate()))
	p.hp = p.max_hp
	p.evasion = 0.04
	p.invulnerable = true
	settle.call()
	# ---------------- fire through the real button --------------
	var root_pos: Vector3 = p.global_position + Vector3(1.0, 0, 0)
	root_pos.y = w.height_at(root_pos.x, root_pos.z)
	var foe = w._spawn_enemy_at("rattata", root_pos, 50.0, false, 1.0)
	await _c9_wait(func() -> bool: return foe != null and foe.rig != null and foe.rig.fitted, 1800)
	foe.max_hp = 100000.0
	foe.hp = 100000.0
	var cnt0 := int(GameProfile.counter_value("ultimates"))
	ult.charge = 1.0  # fixture: full bar (accumulation proven above)
	var gauge = w.get("_ult_circle")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gauge.gui_input.emit(ev)  # the real signal path -> pressed -> latch
	ult.update(0.016)         # consumes the latch -> fire()
	_c9_check("ult: BUTTON fires the ult (uses/counter/charge)",
		ult.uses == 1 and int(GameProfile.counter_value("ultimates")) == cnt0 + 1
			and ult.charge == 0.0,
		"uses=" + str(ult.uses) + " counter=" + str(GameProfile.counter_value("ultimates")))
	_c9_check("ult: cast pose held on the rig (ultPoseT .6)",
		float(p.rig.ult_pose_value()) > 0.5, "pose=" + str(p.rig.ult_pose_value()))
	_c9_check("ult: cast iframes == active + .6",
		float(p.get("_invuln_t")) > 2.0 and ult.active > 1.0,
		"iframes=" + str(p.get("_invuln_t")) + " active=" + str(ult.active))
	# While active, charge gains are blocked — a kill right now
	# (synchronous, no updates between) must add nothing.
	var blk_pos: Vector3 = p.global_position + Vector3(-3.0, 0, -3.0)
	blk_pos.y = w.height_at(blk_pos.x, blk_pos.z)
	var blk = w._spawn_enemy_at("rattata", blk_pos, 50.0, false, 1.0)
	blk.take_damage(99999.0, "normal")
	_c9_check("ult: add() blocked while active", ult.charge == 0.0,
		"charge=" + str(ult.charge))
	blk.queue_free()
	# Roots land: collect drops while the target stays pinned.
	var ctx_dmg: float = 40.0 * (1.0 + 0.1 * float(p.level)) * (1.0 + 0.15 * float(ult.tier()))
	var hooks := GameData.passive_hooks(p.passive_id)
	var tb: Dictionary = hooks.get("typeBoost", {})
	var boost: float = 1.0 + float(tb.get("grass", 0.0))
	var single: float = ctx_dmg * 1.1 * p.damage_mult * p.spec * 1.25 \
		* w.weather_damage_mul("grass") * GameData.type_mult("grass", foe.types) * boost
	var first_drop := -1.0
	var rooted := false
	var prev_hp: float = foe.hp
	for i in range(160):
		ult.update(0.05)
		foe.global_position = root_pos
		if float(foe.hp) < prev_hp:
			if first_drop < 0.0:
				first_drop = prev_hp - float(foe.hp)
			prev_hp = float(foe.hp)
		if String(foe.get("status_kind")) == "root":
			rooted = true
		if first_drop > 0.0 and i > 60:
			break
	var ratio := first_drop / maxf(single, 0.001)
	_c9_check("ult: roots land (first drop == k x pipeline, k in 1..3)",
		first_drop > 0.0 and absf(ratio - roundf(ratio)) < 0.03
			and roundf(ratio) >= 1.0 and roundf(ratio) <= 3.0,
		"drop=" + str(first_drop) + " single=" + str(single) + " k=" + str(ratio))
	_c9_check("ult: root status applied (2 s movement block)",
		rooted, "status=" + String(foe.get("status_kind")))
	_c9_check("ult: fissures spawned == 6 at tier 0",
		ult.fissures_spawned == 6, "fissures=" + str(ult.fissures_spawned))
	# Deny path: press R without a full bar.
	settle.call()
	var deny0: int = ult.deny_count
	var uses0: int = ult.uses
	ult.charge = 0.5
	_c9_key(KEY_R, true)
	# The trigger poll runs on render frames (World._process);
	# wait until one consumes the edge and records the deny.
	var denied := await _c9_wait(func() -> bool: return ult.deny_count > deny0, 240)
	_c9_key(KEY_R, false)
	_c9_check("ult: R without charge denies (no cast)",
		denied and ult.uses == uses0,
		"deny=" + str(ult.deny_count) + " uses=" + str(ult.uses))
	# Keyboard path: let active expire synchronously, refill,
	# then the real KeyR edge (consumed by World._process).
	settle.call()
	for i in range(30):
		ult.update(0.1)
	ult.charge = 1.0
	_c9_key(KEY_R, true)
	var key_fired := await _c9_wait(func() -> bool: return ult.uses == uses0 + 1, 240)
	_c9_key(KEY_R, false)
	_c9_check("ult: KeyR fires through the real input path", key_fired,
		"uses=" + str(ult.uses))
	_c9_check("ult: counter incremented again",
		int(GameProfile.counter_value("ultimates")) == cnt0 + 2,
		"counter=" + str(GameProfile.counter_value("ultimates")))
	# autoUlt: setting on, full bar, enemy in 16 -> self-fires.
	settle.call()
	for i in range(30):
		ult.update(0.1)
	GameProfile.set_setting("autoUlt", true)
	ult.charge = 1.0
	var auto_fired := await _c9_wait(func() -> bool: return ult.uses == uses0 + 2, 240)
	GameProfile.set_setting("autoUlt", false)
	_c9_check("ult: autoUlt fires when ready + enemy near", auto_fired,
		"uses=" + str(ult.uses))
	await _c9_cleanup_run()
	# ---------------- Charmander: ring blast exact value ---------
	var ok2 := await _c9_start_run("charmander")
	if not ok2:
		_c9_check("ult: charmander run boots", false)
		return
	var p2 = w.get("player")
	p2.invulnerable = true
	p2.moves.clear()
	p2.crit_chance = 0.0
	var ult2 = w.get("ult")
	_c9_check("ult: charmander def name/duration",
		ult2.ult_name() == "Rising Blaze" and absf(ult2.cast_dur() - 1.2) < 0.001,
		"name=" + ult2.ult_name())
	w.set_base_weather("clear")
	var ring_pos: Vector3 = p2.global_position + Vector3(3.0, 0, 0)
	ring_pos.y = w.height_at(ring_pos.x, ring_pos.z)
	var foe2 = w._spawn_enemy_at("rattata", ring_pos, 50.0, false, 1.0)
	await _c9_wait(func() -> bool: return foe2 != null and foe2.rig != null and foe2.rig.fitted, 1800)
	foe2.max_hp = 100000.0
	foe2.hp = 100000.0
	ult2.charge = 1.0
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = true
	(w.get("_ult_circle") as Control).gui_input.emit(ev2)
	ult2.update(0.016)
	var ctx2: float = 40.0 * (1.0 + 0.1 * float(p2.level)) * (1.0 + 0.15 * float(ult2.tier()))
	var hooks2 := GameData.passive_hooks(p2.passive_id)
	var tb2: Dictionary = hooks2.get("typeBoost", {})
	var single2: float = ctx2 * 1.3 * p2.damage_mult * p2.spec * 1.25 \
		* w.weather_damage_mul("fire") * GameData.type_mult("fire", foe2.types) \
		* (1.0 + float(tb2.get("fire", 0.0)))
	var first2 := -1.0
	var prev2: float = foe2.hp
	for i in range(40):
		ult2.update(0.05)
		foe2.global_position = ring_pos
		if float(foe2.hp) < prev2:
			first2 = prev2 - float(foe2.hp)
			break
	_c9_check("ult: blaze ring lands == 1.3 x pipeline exactly",
		first2 > 0.0 and absf(first2 - single2) <= maxf(1.0, single2 * 0.03),
		"drop=" + str(first2) + " expected=" + str(single2))
	_c9_check("ult: ring leaves 8 burning ground zones",
		ult2.zones_spawned == 8, "zones=" + str(ult2.zones_spawned))
	await _c9_cleanup_run()
	# ---------------- Squirtle: whirlpool ticks + final wave ----
	var ok3 := await _c9_start_run("squirtle")
	if not ok3:
		_c9_check("ult: squirtle run boots", false)
		return
	var p3 = w.get("player")
	p3.invulnerable = true
	p3.moves.clear()
	p3.crit_chance = 0.0
	var ult3 = w.get("ult")
	_c9_check("ult: squirtle def name/duration",
		ult3.ult_name() == "Shell Whirlpool" and absf(ult3.cast_dur() - 2.4) < 0.001,
		"name=" + ult3.ult_name())
	w.set_base_weather("clear")
	var pool_pos: Vector3 = p3.global_position + Vector3(3.0, 0, 0)
	pool_pos.y = w.height_at(pool_pos.x, pool_pos.z)
	var foe3 = w._spawn_enemy_at("rattata", pool_pos, 50.0, false, 1.0)
	await _c9_wait(func() -> bool: return foe3 != null and foe3.rig != null and foe3.rig.fitted, 1800)
	foe3.max_hp = 100000.0
	foe3.hp = 100000.0
	ult3.charge = 1.0
	var ev3 := InputEventMouseButton.new()
	ev3.button_index = MOUSE_BUTTON_LEFT
	ev3.pressed = true
	(w.get("_ult_circle") as Control).gui_input.emit(ev3)
	ult3.update(0.016)
	var ctx3: float = 40.0 * (1.0 + 0.1 * float(p3.level)) * (1.0 + 0.15 * float(ult3.tier()))
	var hooks3 := GameData.passive_hooks(p3.passive_id)
	var tb3: Dictionary = hooks3.get("typeBoost", {})
	var pipe3: float = ctx3 * p3.damage_mult * p3.spec * 1.25 \
		* w.weather_damage_mul("water") * GameData.type_mult("water", foe3.types) \
		* (1.0 + float(tb3.get("water", 0.0)))
	var drops: Array = []
	var drag_max := 0.0
	var prev3: float = foe3.hp
	for i in range(90):
		ult3.update(0.05)
		foe3.global_position = pool_pos
		var to_p: Vector3 = p3.global_position - foe3.global_position
		to_p.y = 0.0
		if to_p.length() > 0.01:
			drag_max = maxf(drag_max,
				(foe3.get("_kb_vel") as Vector3).dot(to_p.normalized()))
		if float(foe3.hp) < prev3:
			drops.append(prev3 - float(foe3.hp))
			prev3 = float(foe3.hp)
	var tick_ok := false
	var wave_ok := false
	for d in drops:
		if absf(float(d) - pipe3 * 0.32) <= maxf(1.0, pipe3 * 0.32 * 0.03):
			tick_ok = true
		if absf(float(d) - pipe3 * 1.4) <= maxf(1.0, pipe3 * 1.4 * 0.03):
			wave_ok = true
	_c9_check("ult: whirlpool ticks == .32 x pipeline", tick_ok,
		"drops=" + str(drops) + " tick=" + str(pipe3 * 0.32))
	_c9_check("ult: whirlpool drag pulls toward the player", drag_max > 3.0,
		"drag_max=" + str(drag_max))
	_c9_check("ult: final wave lands == 1.4 x pipeline", wave_ok,
		"drops=" + str(drops) + " wave=" + str(pipe3 * 1.4))
	await _c9_cleanup_run()

## P0: die with the Lab revive owned -> the rig must stand back up
## (no latched faint), then MOVE via the touch joystick and TAKE A
## HIT with the hurt flash firing. Frame evidence is saved.
func _c9_revive_phase() -> void:
	# Cycle 19 harness hermeticity: this phase's fixture
	# precondition is an UNBOUGHT revive, but it never
	# restored its own purchase, so the resident profile
	# carries revive:1 (maxed) from past runs and the buy
	# check can never pass in an "all" run. Snapshot the
	# profile, clear the row for the phase, restore at the
	# end — the boost/ui2/c19 pattern. The buy still goes
	# through the real lab_buy and the revive still fires
	# in-run; assertions unchanged.
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	var lab_fixture: Dictionary = (GameProfile.data.get("lab", {}) as Dictionary).duplicate()
	lab_fixture.erase("revive")
	GameProfile.data["lab"] = lab_fixture
	GameProfile.save_profile()
	GameProfile.add_stardust(6000)  # fixture funding via the award API
	_c9_check("revive: lab revive purchasable", bool(GameProfile.lab_buy("revive")))
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("revive: run boots", false)
		GameProfile.data = snap
		GameProfile.save_profile()
		return
	var w = _world
	var p = w.get("player")
	p.moves.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _c9_frames(10)
	_snap("c9_revive_before")
	p.invulnerable = false
	# Lethal: faint plays, then revive fires. Repeat past evasion
	# dodges until the revive is consumed.
	for att in range(30):
		p.set("_invuln_t", 0.0)
		p.take_damage(99999.0)
		if bool(w.get("revive_used")):
			break
		await _c9_frames(10)
	await _c9_frames(5)
	_c9_check("revive: player alive after lethal hit", p.hp > 0.0, "hp=" + str(p.hp))
	_c9_check("revive: faint latch cleared (_faint_t == -1)",
		float(p.rig.get("_faint_t")) == -1.0, "_faint_t=" + str(p.rig.get("_faint_t")))
	_c9_check("revive: model upright again",
		absf(p.rig.model.rotation.x) < 0.05 and absf(p.rig.model.rotation.z) < 0.05,
		"rot=" + str(p.rig.model.rotation))
	_snap("c9_revive_after")
	# Move with the touch joystick (press + drag up, hold,
	# release). Events are spaced by RENDERED frames (input flush
	# cadence) and the hold is measured in physics frames — a
	# real-time second under software rendering is only a few
	# frames and proved nothing (run 3: moved=0).
	var pos0: Vector3 = p.global_position
	# Primer touch: the world's _input latches _touch_forced on the
	# first InputEventScreenTouch and only THEN shows the touch
	# layer — the primer itself is swallowed by the still-hidden
	# joystick zone (this is also how a real first touch behaves).
	_c9_touch(Vector2(250, 520), true)
	for i in range(4):
		await get_tree().process_frame
	_c9_touch(Vector2(250, 520), false)
	for i in range(6):
		await get_tree().process_frame
	# The press/drag/release go through the zone's gui_input
	# signal (see _c9_gui_touch: the headless viewport does no
	# GUI picking for synthetic events).
	var zone := (w.get("touch_controls") as Control).get("_joy_zone") as Control
	_c9_gui_touch(zone, Vector2(250, 520), true)
	for i in range(6):
		await get_tree().process_frame
	_c9_gui_touch(zone, Vector2(250, 520), true, Vector2(250, 400))
	for i in range(6):
		await get_tree().process_frame
	var tvec: Vector2 = w.get_touch_move()
	await _c9_frames(90)
	_c9_gui_touch(zone, Vector2(250, 400), false)
	var moved: float = p.global_position.distance_to(pos0)
	_c9_check("revive: touch-joystick movement works after revive", moved > 1.2,
		"moved=" + str(moved) + " touch_vec=" + str(tvec))
	_snap("c9_revive_moved")
	# Take a hit: hurt flash + 0.45 s iframes + damageFlash overlay.
	# Repeat past evasion dodges (the lethal loop's idiom): a
	# dodged hit sets _invuln_t = 0.25 and produces no flash —
	# a single-shot attempt is a coin flip on the evasion stat.
	for att2 in range(30):
		p.set("_invuln_t", 0.0)
		p.take_damage(5.0)
		if float(w.get("_dmg_flash")) > 0.5:
			break
	_c9_check("revive: hurt flash fires after revive (not swallowed)",
		p.rig.flash_value() > 0.5, "flash=" + str(p.rig.flash_value()))
	_c9_check("revive: post-hurt iframes == 0.45 s", float(p.get("_invuln_t")) >= 0.4,
		"iframes=" + str(p.get("_invuln_t")))
	_c9_check("revive: ui.damageFlash fired", float(w.get("_dmg_flash")) > 0.5,
		"dmg_flash=" + str(w.get("_dmg_flash")))
	await _c9_cleanup_run()
	GameProfile.data = snap
	GameProfile.save_profile()

## ------------------------------------------------------------ cycle 14
## Shrine phase: interactables exist per populate, altar tiers
## follow tw(), the totem roars through the REAL E-interact chain,
## a wave altar charges by presence and pays a blessing whose pick
## applies its exact mod, and the roar-buffed guardian carries the
## exact HP/damage/cap numbers and pays 1 + roars chests.

func _c14_stat(p, stat: String) -> float:
	match stat:
		"damage": return p.damage_mult
		"attackSpeed": return p.atk_speed
		"maxHp": return p.max_hp
		"moveSpeed": return p.speed_mult
		"critChance": return p.crit_chance
		"area": return p.area_mult
		"xpGain": return p.xp_mult
		"regen": return p.regen
		"armor": return p.armor
		"luck": return p.luck
		"duration": return p.duration_mult
		"statusChance": return p.status_chance_mult
	return -1.0

## Hold E until the world consumes the edge (its interact chain
## samples on render frames, which lag physics frames headless —
## the ult phase's KeyR lesson). Returns when run_roars reaches
## `want` or the wait expires.
func _c14_press_e(w, want: int) -> void:
	_c9_key(KEY_E, true)
	await _c9_wait(func() -> bool: return int(w.get("run_roars")) >= want, 240)
	_c9_key(KEY_E, false)
	# The release must be SAMPLED too, or the world's _e_prev stays
	# latched and the next press has no edge — give render frames
	# a long window to observe the key-up.
	await _c9_frames(45)

func _c14_teleport(p, x: float, z: float) -> void:
	p.global_position = Vector3(x, _world.height_at(x, z), z)
	p.reset_physics_interpolation()

func _c9_shrine_phase() -> void:
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("shrine: run boots", false)
		return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	w.set_base_weather("clear")
	var st: Dictionary = (w.get("_inter_state") as Dictionary).get(1, {})
	var altars: Array = st.get("altars", [])
	var tot: Dictionary = st.get("totem", {})
	_c9_check("shrine: zone 1 populates 5 altars + 1 totem",
		altars.size() == 5 and not tot.is_empty(),
		"altars=" + str(altars.size()))
	var tiers: Array = []
	for a in altars:
		tiers.append(int(a["tier"]))
	tiers.sort()
	_c9_check("shrine: tier multiset == tw() [0,0,1,1,2|3]",
		tiers.size() == 5 and tiers[0] == 0 and tiers[1] == 0 and tiers[2] == 1
			and tiers[3] == 1 and (tiers[4] == 2 or tiers[4] == 3),
		"tiers=" + str(tiers))
	# --- totem roars through the real interact chain ---
	_c14_teleport(p, float(tot["x"]) + 2.0, float(tot["z"]))
	await _c9_frames(3)
	for n in range(1, 4):
		await _c14_press_e(w, n)
		_c9_check("shrine: roar %d lands via E" % n, int(w.get("run_roars")) == n,
			"run_roars=" + str(w.get("run_roars")))
	_c9_check("shrine: totem used at 3 roars", bool(tot["used"]))
	_c9_key(KEY_E, true)
	await _c9_frames(30)
	_c9_key(KEY_E, false)
	await _c9_frames(2)
	_c9_check("shrine: 4th press blocked (totem used)", int(w.get("run_roars")) == 3,
		"run_roars=" + str(w.get("run_roars")))
	_c9_check("shrine: totem prompt shows the resting label",
		"沉睡" in (w.get("_prompt") as Label).text,
		"prompt=" + (w.get("_prompt") as Label).text)
	# --- tier-0 altar: charge growth + drain decay ---
	var a0: Dictionary = {}
	var aw: Dictionary = {}
	for a in altars:
		if int(a["tier"]) == 0 and a0.is_empty():
			a0 = a
		if int(a["tier"]) >= 2:
			aw = a
	_c14_teleport(p, float(a0["x"]), float(a0["z"]))
	await _c9_frames(120)
	var grown := float(a0["charge"])
	_c9_check("shrine: presence charges the altar (t0: ~120f/8s)",
		grown > 0.08 and grown < 0.55, "charge=" + str(grown))
	_c14_teleport(p, float(a0["x"]) + 40.0, float(a0["z"]))
	await _c9_frames(150)
	_c9_check("shrine: charge drains after the 1.2 s grace",
		float(a0["charge"]) < grown - 0.05,
		"charge=" + str(float(a0["charge"])) + " from=" + str(grown))
	# --- wave altar: full charge, waves spawn, blessing pays ---
	if int(aw["tier"]) == 3:
		w.set("elapsed", 95.0)  # fixture: pass the 90 s seal
	# Fixture: clear the field and hold the ambient spawner so any
	# enemy near the altar during the charge is a WAVE spawn.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _c9_frames(2)
	w.set("_spawn_t", 1e9)
	var want_offers := 4 if int(aw["tier"]) == 3 else 3
	var want_picks := 2 if int(aw["tier"]) == 3 else 1
	_c14_teleport(p, float(aw["x"]), float(aw["z"]))
	var wave_seen := 0
	var opened := false
	for i in range(7200):
		await get_tree().physics_frame
		var near := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			var d: Vector3 = e.global_position - Vector3(float(aw["x"]), 0, float(aw["z"]))
			d.y = 0.0
			if d.length() < 14.0:
				near += 1
		wave_seen = maxi(wave_seen, near)
		if String(w.get("state")) == "blessing":
			opened = true
			break
	_c9_check("shrine: wave altar completes and opens the blessing", opened,
		"state=" + String(w.get("state")) + " charge=" + str(float(aw["charge"])))
	_c9_check("shrine: horde waves spawned around the altar", wave_seen >= 4,
		"max near=" + str(wave_seen))
	_c9_check("shrine: altar marked used", bool(aw["used"]))
	var offers: Array = w.get("_blessing_offers")
	_c9_check("shrine: offer count == ZC.offers", offers.size() == want_offers,
		"offers=" + str(offers.size()) + " want=" + str(want_offers))
	for pick_i in range(want_picks):
		var offer: Dictionary = (w.get("_blessing_offers") as Array)[0].duplicate(true)
		var mod: Dictionary = (offer["mods"] as Array)[0]
		var stat := String(mod["stat"])
		var before := _c14_stat(p, stat)
		w._apply_blessing_offer(0)
		var after := _c14_stat(p, stat)
		var want := before
		if mod.has("mul"):
			want = before * float(mod["mul"])
		if mod.has("add"):
			want = before + float(mod["add"])
		_c9_check("shrine: pick %d applies its exact mod (%s)" % [pick_i + 1, stat],
			absf(after - want) < 0.001,
			"before=" + str(before) + " after=" + str(after) + " want=" + str(want))
		if pick_i + 1 < want_picks:
			_c9_check("shrine: modal stays open for pick 2 with one fewer offer",
				String(w.get("state")) == "blessing" and (w.get("_blessing_offers") as Array).size() == want_offers - 1)
	_c9_check("shrine: blessing closes back into play",
		String(w.get("state")) == "playing" and bool(w.get("running")))
	_c9_check("shrine: temp mod persists on the player",
		(p.get("temp_mods") as Array).size() == want_picks,
		"temp_mods=" + str((p.get("temp_mods") as Array).size()))
	# --- roar-buffed guardian: exact numbers, then the kill ---
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _c9_frames(2)
	var _shrine_pre_n := get_tree().get_nodes_in_group("enemies").size()
	w.summon_guardian()
	var _shrine_group_n := get_tree().get_nodes_in_group("enemies").size() - _shrine_pre_n
	var g = w.get("guardian")
	var gok := await _c9_wait(func() -> bool: return g != null and g.rig != null and g.rig.fitted, 3600)
	if not gok:
		_c9_check("shrine: guardian summons", false)
		await _c9_cleanup_run()
		return
	_c9_check("shrine: guardian carries the shrine roars", int(g.roars) == 3,
		"roars=" + str(g.roars))
	_c9_check("shrine: escorts == 2 + roars", _shrine_group_n == 6,
		"enemies=" + str(_shrine_group_n))
	var o := 1.9  # 1 + .3 x 3 roars
	var formula: float = Enemy.base_hp(g.species_id) * w._hp_curve(1, maxf(2.5, w._eff_minutes())) * 0.8 * 70.0 * o
	_c9_check("shrine: guardian HP == formula x (1+.3 roars), meter empty",
		absf(g.max_hp - formula) < formula * 0.0001,
		"hp=" + str(g.max_hp) + " want=" + str(formula))
	_c9_check("shrine: capRate == HP / (25 x roar mult)",
		absf(g.cap_rate - g.max_hp / (25.0 * o)) < 0.001,
		"cap=" + str(g.cap_rate))
	_c9_check("shrine: fightSecs == 40 x roar mult", absf(g.fight_secs - 40.0 * o) < 0.001,
		"secs=" + str(g.fight_secs))
	var frames := 0
	var chest_blow := 0
	while g.hp > 0.0 and frames < 9000:
		# Measure only the synchronous killing blow; timed supply chests
		# can legitimately arrive during this long cap-limited fight.
		var pre_chests: int = (w.get("_chests") as Array).size()
		g.take_damage(g.max_hp * 0.2, "")
		if g.hp <= 0.0:
			chest_blow = (w.get("_chests") as Array).size() - pre_chests
		await _c9_frames(1)
		frames += 1
	_c9_check("shrine: roar guardian killed through the cap", g.hp <= 0.0,
		"frames=" + str(frames))
	_c9_check("shrine: chests == 1 + roars after the kill",
		chest_blow == 4,
		"spawned=" + str(chest_blow))
	w.set("_spawn_t", 0.5)  # spawner fixture released
	await _c9_settle_drafts()
	await _c9_cleanup_run()

## Bossscale phase: the combat meter's window-best + p85, the
## formula-floor HP with an empty meter, the budget raise capped
## at 4x, and the Eb cap's bank/refill/exhaust arithmetic — all
## through combat_hit / summon_guardian / take_damage.
func _c9_bossscale_phase() -> void:
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("bossscale: run boots", false)
		return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	p.crit_chance = 0.0  # fixture: deterministic pipeline readings
	w.set_base_weather("clear")
	# --- meter: one real combat_hit, window best, then p85 dps ---
	var pos: Vector3 = p.global_position + Vector3(3.0, 0, 0)
	pos.y = w.height_at(pos.x, pos.z)
	var dummy = w._spawn_enemy_at("rattata", pos, 500.0, false, 1.0)
	await _c9_wait(func() -> bool: return dummy != null and dummy.rig != null and dummy.rig.fitted, 1800)
	var dealt: float = w.combat_hit(dummy, 50.0, "normal", "physical", [], {})
	_c9_check("bossscale: meter window best == the hit's dealt",
		absf(float(w.get("_meter_best")) - dealt) < 0.0001,
		"best=" + str(w.get("_meter_best")) + " dealt=" + str(dealt))
	await _c9_wait(func() -> bool: return w.meter_dps() > 0.0, 300)
	_c9_check("bossscale: meter dps == the single window sample (p85)",
		absf(w.meter_dps() - dealt) < 0.0001,
		"dps=" + str(w.meter_dps()) + " dealt=" + str(dealt))
	dummy.queue_free()
	await _c9_frames(2)
	# --- formula floor: budget (dps x 40) below the formula ---
	var formula1 := 0.0
	var _boss_pre_n := get_tree().get_nodes_in_group("enemies").size()
	w.summon_guardian()
	var _boss_group_n := get_tree().get_nodes_in_group("enemies").size() - _boss_pre_n
	var g = w.get("guardian")
	var gok := await _c9_wait(func() -> bool: return g != null and g.rig != null and g.rig.fitted, 3600)
	if not gok:
		_c9_check("bossscale: guardian summons", false)
		await _c9_cleanup_run()
		return
	formula1 = Enemy.base_hp(g.species_id) * w._hp_curve(1, maxf(2.5, w._eff_minutes())) * 0.8 * 70.0
	_c9_check("bossscale: precondition budget < formula",
		w.meter_dps() * 40.0 < formula1,
		"budget=" + str(w.meter_dps() * 40.0) + " formula=" + str(formula1))
	_c9_check("bossscale: HP == formula floor (no roars, budget short)",
		absf(g.max_hp - formula1) < formula1 * 0.0001,
		"hp=" + str(g.max_hp) + " want=" + str(formula1))
	_c9_check("bossscale: capRate == HP/25, fightSecs == 40, roars == 0",
		absf(g.cap_rate - g.max_hp / 25.0) < 0.001 and absf(g.fight_secs - 40.0) < 0.001 and int(g.roars) == 0,
		"cap=" + str(g.cap_rate) + " secs=" + str(g.fight_secs))
	_c9_check("bossscale: escorts == 2 (no roars)", _boss_group_n == 3,
		"enemies=" + str(_boss_group_n))
	await _c9_cleanup_run()
	# --- budget raise: a fat meter sample pushes HP to the 4x cap ---
	ok = await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("bossscale: run 2 boots", false)
		return
	p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	p.crit_chance = 0.0
	w.set_base_weather("clear")
	pos = p.global_position + Vector3(3.0, 0, 0)
	pos.y = w.height_at(pos.x, pos.z)
	dummy = w._spawn_enemy_at("rattata", pos, 5000.0, false, 1.0)
	await _c9_wait(func() -> bool: return dummy != null and dummy.rig != null and dummy.rig.fitted, 1800)
	w.combat_hit(dummy, 5000.0, "normal", "physical", [], {})
	await _c9_wait(func() -> bool: return w.meter_dps() > 0.0, 300)
	dummy.queue_free()
	await _c9_frames(2)
	w.summon_guardian()
	g = w.get("guardian")
	gok = await _c9_wait(func() -> bool: return g != null and g.rig != null and g.rig.fitted, 3600)
	if not gok:
		_c9_check("bossscale: guardian 2 summons", false)
		await _c9_cleanup_run()
		return
	var formula2: float = Enemy.base_hp(g.species_id) * w._hp_curve(1, maxf(2.5, w._eff_minutes())) * 0.8 * 70.0
	_c9_check("bossscale: precondition budget > 4x formula",
		w.meter_dps() * 40.0 > formula2 * 4.0,
		"budget=" + str(w.meter_dps() * 40.0) + " 4x=" + str(formula2 * 4.0))
	_c9_check("bossscale: HP raised to exactly 4x formula (Tb cap)",
		absf(g.max_hp - formula2 * 4.0) < formula2 * 0.0004,
		"hp=" + str(g.max_hp) + " want=" + str(formula2 * 4.0))
	# --- cap bank: full drain, zero refill same-frame, timed refill ---
	var rate: float = g.cap_rate
	var d1: float = g.take_damage(rate * 6.0, "")
	_c9_check("bossscale: first blow drains exactly the 3x bank",
		absf(d1 - rate * 3.0) < rate * 0.001, "dealt=" + str(d1) + " bank=" + str(rate * 3.0))
	var d2: float = g.take_damage(rate * 6.0, "")
	_c9_check("bossscale: same-frame second blow deals 0 (bank empty)",
		d2 == 0.0, "dealt=" + str(d2))
	await _c9_frames(65)
	var d3: float = g.take_damage(rate * 6.0, "")
	_c9_check("bossscale: bank refills at capRate/s",
		d3 > rate * 0.7 and d3 < rate * 1.5, "dealt=" + str(d3) + " rate=" + str(rate))
	# --- exhaust: past 2x fightSecs the damage taken doubles ---
	await _c9_frames(200)  # bank refills to full
	g.set("_fight_t", 2.0 * g.fight_secs + 20.0)
	var d4: float = g.take_damage(rate, "")
	_c9_check("bossscale: exhaust at +20 s over == x2 damage taken",
		absf(d4 - rate * 2.0) < rate * 0.16, "dealt=" + str(d4) + " want=" + str(rate * 2.0))
	await _c9_cleanup_run()

## Wet phase: the parallel wet timer through the real combat_hit
## status path, decay, the electrocute reaction (consume + chain
## + x1.5 + 0.25 s gate), freeze consuming wet, the Squirtle
## ult's wave applying it, and timed rain soaking.
func _c9_wet_phase() -> void:
	var ok := await _c9_start_run("squirtle")
	if not ok:
		_c9_check("wet: run boots", false)
		return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	p.crit_chance = 0.0  # fixture: deterministic pipeline readings
	w.set_base_weather("clear")
	var pin := func(off: Vector3, mult: float):
		var pp: Vector3 = p.global_position + off
		pp.y = w.height_at(pp.x, pp.z)
		return w._spawn_enemy_at("rattata", pp, mult, false, 1.0)
	# --- A: application is parallel, counted once ---
	var e1 = pin.call(Vector3(3.0, 0, 0), 200.0)
	await _c9_wait(func() -> bool: return e1 != null and e1.rig != null and e1.rig.fitted, 1800)
	w.combat_hit(e1, 10.0, "water", "special", [], {"status": "wet", "status_chance": 100.0})
	_c9_check("wet: combat_hit applies wet == 5 s (duration x1)",
		e1.wet_t > 4.9, "wet_t=" + str(e1.wet_t))
	_c9_check("wet: the single status slot stays empty (parallel)",
		String(e1.status_kind) == "", "kind=" + String(e1.status_kind))
	var soaked0 := int((w.get("run_counts") as Dictionary).get("soaked", 0))
	_c9_check("wet: 'soaked' counted on first application", soaked0 >= 1,
		"soaked=" + str(soaked0))
	w.combat_hit(e1, 10.0, "water", "special", [], {"status": "wet", "status_chance": 100.0})
	_c9_check("wet: 'soaked' counts once per enemy",
		int((w.get("run_counts") as Dictionary).get("soaked", 0)) == soaked0)
	# --- B: decay ---
	await _c9_frames(60)
	_c9_check("wet: wet decays in real time", e1.wet_t > 3.6 and e1.wet_t < 4.4,
		"wet_t=" + str(e1.wet_t))
	e1.queue_free()
	# --- C: electrocute ---
	var dry = pin.call(Vector3(-3.0, 0, 0), 200.0)
	var prim = pin.call(Vector3(3.0, 0, 0), 200.0)
	var chain = pin.call(Vector3(5.0, 0, 2.0), 200.0)
	var bystander = pin.call(Vector3(5.0, 0, -2.0), 200.0)
	for e in [dry, prim, chain, bystander]:
		await _c9_wait(func() -> bool: return e != null and e.rig != null and e.rig.fitted, 1800)
	var ctrl: float = w.combat_hit(dry, 40.0, "electric", "special", [], {})
	w.combat_hit(prim, 10.0, "water", "special", [], {"status": "wet", "status_chance": 100.0})
	w.combat_hit(chain, 10.0, "water", "special", [], {"status": "wet", "status_chance": 100.0})
	var chain_hp0: float = chain.hp
	var by_hp0: float = bystander.hp
	var dealt_a: float = w.combat_hit(prim, 40.0, "electric", "special", [], {})
	_c9_check("wet: electrocuted primary takes x1.5",
		absf(dealt_a - ctrl * 1.5) < ctrl * 0.001,
		"dealt=" + str(dealt_a) + " want=" + str(ctrl * 1.5))
	_c9_check("wet: primary wet consumed", prim.wet_t == 0.0, "wet_t=" + str(prim.wet_t))
	_c9_check("wet: chain target takes packet x .8",
		absf((chain_hp0 - chain.hp) - ctrl * 0.8) < ctrl * 0.01,
		"chain dealt=" + str(chain_hp0 - chain.hp) + " want=" + str(ctrl * 0.8))
	_c9_check("wet: chain target keeps its wet", chain.wet_t > 4.0,
		"wet_t=" + str(chain.wet_t))
	_c9_check("wet: dry bystander untouched", bystander.hp == by_hp0)
	_c9_check("wet: reactions counted",
		int((w.get("run_counts") as Dictionary).get("reactions", 0)) >= 1)
	var gated: float = w.combat_hit(chain, 40.0, "electric", "special", [], {})
	_c9_check("wet: 0.25 s gate blocks an immediate re-reaction",
		chain.wet_t > 4.0 and absf(gated - ctrl) < ctrl * 0.001,
		"wet_t=" + str(chain.wet_t) + " dealt=" + str(gated))
	await _c9_frames(24)
	var dealt_b: float = w.combat_hit(chain, 40.0, "electric", "special", [], {})
	_c9_check("wet: reaction fires again past the gate (x1.5, consumed)",
		absf(dealt_b - ctrl * 1.5) < ctrl * 0.001 and chain.wet_t == 0.0,
		"dealt=" + str(dealt_b) + " wet_t=" + str(chain.wet_t))
	for e in [dry, prim, chain, bystander]:
		e.queue_free()
	await _c9_frames(2)
	# --- D: freeze consumes wet ---
	var e4 = pin.call(Vector3(3.0, 0, 0), 200.0)
	await _c9_wait(func() -> bool: return e4 != null and e4.rig != null and e4.rig.fitted, 1800)
	w.combat_hit(e4, 10.0, "water", "special", [], {"status": "wet", "status_chance": 100.0})
	w.combat_hit(e4, 10.0, "ice", "special", [], {"status": "freeze", "status_chance": 100.0})
	_c9_check("wet: freeze lands and consumes the wet",
		String(e4.status_kind) == "freeze" and e4.wet_t == 0.0,
		"kind=" + String(e4.status_kind) + " wet_t=" + str(e4.wet_t))
	e4.queue_free()
	# --- F: the Squirtle ult's final wave applies wet (chance 1) ---
	var e6 = pin.call(Vector3(4.0, 0, 0), 500.0)
	await _c9_wait(func() -> bool: return e6 != null and e6.rig != null and e6.rig.fitted, 1800)
	var ult = w.get("ult")
	ult.charge = 1.0
	var e6_hp0: float = e6.hp
	# The trigger poll runs on render frames — hold R until it
	# consumes the edge (the ult phase's proven pattern).
	_c9_key(KEY_R, true)
	var fired := await _c9_wait(func() -> bool: return int(ult.uses) == 1, 240)
	_c9_key(KEY_R, false)
	_c9_check("wet: ult fired via the real KeyR path", fired,
		"uses=" + str(ult.uses) + " charge=" + str(ult.charge) + " active=" + str(ult.active))
	var wet_seen := false
	for i in range(400):
		await get_tree().physics_frame
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		if e6.wet_t > 0.0:
			wet_seen = true
			break
	_c9_check("wet: Shell Whirlpool's wave soaks its target", wet_seen,
		"wet_t=" + str(e6.wet_t) + " hp=" + str(e6.hp) + "/" + str(e6_hp0)
		+ " dist=" + str(p.global_position.distance_to(e6.global_position)))
	e6.queue_free()
	# The poll can exit on the whirlpool's FIRST tick — wait out
	# the whole cast (repeater 2.2 s + wave .9 s) before the rain
	# segment, or leftover ticks soak the rain pin early and its
	# 'soaked' count lands before the baseline read.
	await _c9_frames(300)
	# --- E: timed rain soaks nearby enemies ---
	var e5 = pin.call(Vector3(10.0, 0, 0), 200.0)
	await _c9_wait(func() -> bool: return e5 != null and e5.rig != null and e5.rig.fitted, 1800)
	var soaked1 := int((w.get("run_counts") as Dictionary).get("soaked", 0))
	w.set_weather("rain", 30.0)
	# Cycle 21.1: poll with draft settling (the whirlpool
	# segment's pattern above). A plain _c9_wait leaves a
	# draft opened by the whirlpool kill's XP unhandled for
	# the whole window, and while a draft owns the screen
	# the world's weather block is gated on running=false —
	# the timed rain then never arms and wet_t stays 0 (the
	# C21.1 confirming-suite failure; the phase passes
	# standalone back-to-back). The assertion is unchanged.
	var rain_ok := false
	for i in range(900):
		await get_tree().physics_frame
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		if e5.wet_t > 1.5:
			rain_ok = true
			break
	_c9_check("wet: timed rain applies wet = max(wet, 2)", rain_ok,
		"wet_t=" + str(e5.wet_t))
	_c9_check("wet: timed rain counts 'soaked'",
		int((w.get("run_counts") as Dictionary).get("soaked", 0)) > soaked1)
	await _c9_cleanup_run()

## ------------------------------------------------------------ cycle 15
## React phase: the five reactions Cycle 15 ported (steam /
## wildfire / shatter / gas / mind) through the real combat_hit
## pipeline, against pinned control hits on plain enemies of
## the same species — exact multipliers, side-effect sets,
## radius in/out pins, gas stack arithmetic, and the per-key
## 0.25 s gate (blocked, then re-fired after the wet phase's
## proven 24-frame wait). Pins get speed 0 so radii are read
## at spawn geometry; all reads are synchronous with the hit.

func _c9_react_phase() -> void:
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("react: run boots", false)
		return
	var w = _world
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	p.crit_chance = 0.0  # fixture: deterministic pipeline readings
	w.set_base_weather("clear")
	var pin := func(off: Vector3) -> Enemy:
		var pp: Vector3 = p.global_position + off
		pp.y = w.height_at(pp.x, pp.z)
		var e = w._spawn_enemy_at("rattata", pp, 200.0, false, 1.0)
		e.speed = 0.0
		return e
	var ctrl = pin.call(Vector3(-4.0, 0, -4.0))
	await _c9_wait(func() -> bool: return ctrl != null and ctrl.rig != null and ctrl.rig.fitted, 1800)
	var reactions := func() -> int: return int((w.get("run_counts") as Dictionary).get("reactions", 0))
	# --- steam: burn + water -> x1.4, confuse/root splash 6u ---
	var prim = pin.call(Vector3(3.0, 0, 0))
	var in6 = pin.call(Vector3(6.0, 0, 0))
	var out6 = pin.call(Vector3(11.5, 0, 0))
	for e in [prim, in6, out6]:
		await _c9_wait(func() -> bool: return e != null and e.rig != null and e.rig.fitted, 1800)
	w.combat_hit(prim, 10.0, "fire", "special", [], {"status": "burn", "status_chance": 100.0})
	var ctrl_w: float = w.combat_hit(ctrl, 40.0, "water", "special", [], {})
	var dealt_s: float = w.combat_hit(prim, 40.0, "water", "special", [], {})
	_c9_check("react: steam boosts the water hit x1.4",
		absf(dealt_s - ctrl_w * 1.4) < ctrl_w * 0.001,
		"dealt=" + str(dealt_s) + " want=" + str(ctrl_w * 1.4))
	_c9_check("react: steam consumes the primary's burn",
		String(prim.status_kind) == "", "kind=" + String(prim.status_kind))
	_c9_check("react: steam confuse == 2.5 x resist on the primary",
		prim.confuse_t > 2.4 and prim.confuse_t < 2.51, "confuse_t=" + str(prim.confuse_t))
	_c9_check("react: steam root == 2 x resist on the primary",
		prim.root_t > 1.9 and prim.root_t < 2.01, "root_t=" + str(prim.root_t))
	_c9_check("react: steam splashes a bystander inside 6u",
		in6.confuse_t > 2.4 and in6.root_t > 1.9,
		"confuse=" + str(in6.confuse_t) + " root=" + str(in6.root_t))
	_c9_check("react: steam leaves a bystander outside 6u alone",
		out6.confuse_t == 0.0 and out6.root_t == 0.0)
	_c9_check("react: 'confused' counted (countOnce channel)",
		int((w.get("run_counts") as Dictionary).get("confused", 0)) >= 2)
	# --- the 0.25 s per-key gate: blocked, then re-fires ---
	# Cycle 19 harness pacing (root-caused in cycle 18): the
	# gate runs on the world run clock, so "immediate" must
	# mean the same synchronous stretch as a fresh fire —
	# the old shape waited out a second enemy's rig fit
	# between the priming fire and the blocked hit, and at
	# llvmpipe pacing that wait pushes run_time past the
	# 0.25 s window, so the gate LEGITIMATELY expires and
	# both checks fail on a correct game. The gate pair now
	# re-primes on `prim` itself: burn re-applied and the
	# blocked hit lands in the same call stack as the first
	# steam above (zero frames in between), then the
	# re-fire rides the normal 24-frame wait. Assertions
	# (blocked = x1 + burn kept; re-fire = x1.4 + consumed)
	# are unchanged, and the reaction count below still
	# expects exactly two steams.
	w.combat_hit(prim, 10.0, "fire", "special", [], {"status": "burn", "status_chance": 100.0})
	var gated: float = w.combat_hit(prim, 40.0, "water", "special", [], {})
	_c9_check("react: gate blocks an immediate second steam (burn kept, x1)",
		String(prim.status_kind) == "burn" and absf(gated - ctrl_w) < ctrl_w * 0.001,
		"dealt=" + str(gated) + " want=" + str(ctrl_w))
	await _c9_frames(24)
	var refire: float = w.combat_hit(prim, 40.0, "water", "special", [], {})
	_c9_check("react: steam fires again past the gate (x1.4, consumed)",
		absf(refire - ctrl_w * 1.4) < ctrl_w * 0.001 and String(prim.status_kind) == "",
		"dealt=" + str(refire))
	for e in [prim, in6, out6]:
		e.queue_free()
	await _c9_frames(2)
	# --- wildfire: burn + grass -> x1.3, burn spreads 7u ---
	var wprim = pin.call(Vector3(3.0, 0, 0))
	var in7 = pin.call(Vector3(7.0, 0, 0))
	var out7 = pin.call(Vector3(12.5, 0, 0))
	for e in [wprim, in7, out7]:
		await _c9_wait(func() -> bool: return e != null and e.rig != null and e.rig.fitted, 1800)
	w.combat_hit(wprim, 10.0, "fire", "special", [], {"status": "burn", "status_chance": 100.0})
	var ctrl_g: float = w.combat_hit(ctrl, 40.0, "grass", "special", [], {})
	var dealt_w: float = w.combat_hit(wprim, 40.0, "grass", "special", [], {})
	_c9_check("react: wildfire boosts the grass hit x1.3",
		absf(dealt_w - ctrl_g * 1.3) < ctrl_g * 0.001,
		"dealt=" + str(dealt_w) + " want=" + str(ctrl_g * 1.3))
	_c9_check("react: wildfire does NOT consume the primary's burn",
		String(wprim.status_kind) == "burn", "kind=" + String(wprim.status_kind))
	_c9_check("react: wildfire ignites a dry bystander inside 7u",
		String(in7.status_kind) == "burn", "kind=" + String(in7.status_kind))
	_c9_check("react: wildfire leaves a bystander outside 7u dry",
		String(out7.status_kind) == "", "kind=" + String(out7.status_kind))
	for e in [wprim, in7, out7]:
		e.queue_free()
	await _c9_frames(2)
	# --- shatter: frozen + fighting -> x2.6 (x1.2 folded), chain x.7 in 5u ---
	var sprim = pin.call(Vector3(3.0, 0, 0))
	var in5 = pin.call(Vector3(6.0, 0, 0))
	var out5 = pin.call(Vector3(10.5, 0, 0))
	for e in [sprim, in5, out5]:
		await _c9_wait(func() -> bool: return e != null and e.rig != null and e.rig.fitted, 1800)
	w.combat_hit(sprim, 10.0, "ice", "special", [], {"status": "freeze", "status_chance": 100.0})
	var ctrl_f: float = w.combat_hit(ctrl, 40.0, "fighting", "physical", [], {})
	var in5_hp0: float = in5.hp
	var out5_hp0: float = out5.hp
	var dealt_sh: float = w.combat_hit(sprim, 40.0, "fighting", "physical", [], {})
	_c9_check("react: shatter boosts x2.6 with the frozen x1.2 folded in",
		absf(dealt_sh - ctrl_f * 2.6 * 1.2) < ctrl_f * 0.001,
		"dealt=" + str(dealt_sh) + " want=" + str(ctrl_f * 2.6 * 1.2))
	_c9_check("react: shatter consumes the freeze",
		String(sprim.status_kind) == "", "kind=" + String(sprim.status_kind))
	_c9_check("react: shatter chain hits inside 5u at packet x .7",
		absf((in5_hp0 - in5.hp) - ctrl_f * 0.7) < ctrl_f * 0.01,
		"chain=" + str(in5_hp0 - in5.hp) + " want=" + str(ctrl_f * 0.7))
	_c9_check("react: shatter chain skips outside 5u", out5.hp == out5_hp0)
	for e in [sprim, in5, out5]:
		e.queue_free()
	await _c9_frames(2)
	# --- gas: poison stacks + fire -> x(1.4+.1r), chain x(.5+.12r) ---
	var gprim = pin.call(Vector3(3.0, 0, 0))
	var gin = pin.call(Vector3(6.0, 0, 0))
	var gout = pin.call(Vector3(11.5, 0, 0))
	for e in [gprim, gin, gout]:
		await _c9_wait(func() -> bool: return e != null and e.rig != null and e.rig.fitted, 1800)
	for i in range(3):
		w.combat_hit(gprim, 10.0, "normal", "physical", [], {"status": "poison", "status_chance": 100.0})
	_c9_check("react: three poison applications stack to 3",
		gprim.poison_stacks == 3, "stacks=" + str(gprim.poison_stacks))
	var ctrl_fire: float = w.combat_hit(ctrl, 40.0, "fire", "special", [], {})
	var gin_hp0: float = gin.hp
	var gout_hp0: float = gout.hp
	var dealt_g: float = w.combat_hit(gprim, 40.0, "fire", "special", [], {})
	_c9_check("react: gas boosts x(1.4 + .1 x stacks=3) == x1.7",
		absf(dealt_g - ctrl_fire * 1.7) < ctrl_fire * 0.001,
		"dealt=" + str(dealt_g) + " want=" + str(ctrl_fire * 1.7))
	_c9_check("react: gas consumes poison and stacks",
		String(gprim.status_kind) == "" and gprim.poison_stacks == 0,
		"kind=" + String(gprim.status_kind) + " stacks=" + str(gprim.poison_stacks))
	_c9_check("react: gas chain hits inside 6u at packet x (.5+.12x3) and poisons",
		absf((gin_hp0 - gin.hp) - ctrl_fire * 0.86) < ctrl_fire * 0.01
			and String(gin.status_kind) == "poison" and gin.poison_stacks == 1,
		"chain=" + str(gin_hp0 - gin.hp) + " want=" + str(ctrl_fire * 0.86))
	_c9_check("react: gas chain skips outside 6u", gout.hp == gout_hp0)
	for e in [gprim, gin, gout]:
		e.queue_free()
	await _c9_frames(2)
	# --- mind collapse: paralyze + psychic -> x1.6, confuse 4x ---
	var mprim = pin.call(Vector3(3.0, 0, 0))
	await _c9_wait(func() -> bool: return mprim != null and mprim.rig != null and mprim.rig.fitted, 1800)
	w.combat_hit(mprim, 10.0, "electric", "special", [], {"status": "paralysis", "status_chance": 100.0})
	var ctrl_p: float = w.combat_hit(ctrl, 40.0, "psychic", "special", [], {})
	var dealt_m: float = w.combat_hit(mprim, 40.0, "psychic", "special", [], {})
	_c9_check("react: mind collapse boosts the psychic hit x1.6",
		absf(dealt_m - ctrl_p * 1.6) < ctrl_p * 0.001,
		"dealt=" + str(dealt_m) + " want=" + str(ctrl_p * 1.6))
	_c9_check("react: mind consumes paralysis, confuse == 4 x resist",
		String(mprim.status_kind) == "" and mprim.confuse_t > 3.9 and mprim.confuse_t < 4.01,
		"kind=" + String(mprim.status_kind) + " confuse_t=" + str(mprim.confuse_t))
	mprim.queue_free()
	ctrl.queue_free()
	_c9_check("react: six reactions counted (steam x2, wildfire, shatter, gas, mind)",
		reactions.call() == 6, "reactions=" + str(reactions.call()))
	await _c9_cleanup_run()

## Comet phase: the event timer spawns a tier-4 altar in the
## 25-40u band; its 60 s life burns ONLY at zero charge (the
## burn-out band), charging freezes the burn, draining
## resumes it; a burnt-out comet pays nothing and blocks
## respawn; a completed comet pays a tier-4 blessing
## (min tier 1, 3 offers, 1 pick). Three runs, one per arc.

func _c9_comet_phase() -> void:
	var w = _world
	# --- run 1: spawn band + life band semantics ---
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("comet: run 1 boots", false)
		return
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	w.set_base_weather("clear")
	# The timer ticks live from the _E = 75.0 start; _c9_start_run itself
	# consumes a few frames before this read (observed 0.12 s), so the
	# tolerance is 0.75 s -- a wrong constant (range 100-140, retry 10,
	# or a missing init) is still caught.
	_c9_check("comet: timer starts at _E == 75 s",
		absf(float(w.get("_comet_t")) - 75.0) < 0.75, "t=" + str(float(w.get("_comet_t"))))
	w.set("_comet_t", 0.01)
	var spawned := await _c9_wait(func() -> bool: return not (w.get("_comet") as Dictionary).is_empty(), 600)
	_c9_check("comet: altar spawns when the timer fires", spawned)
	if not spawned:
		await _c9_cleanup_run()
		return
	var a: Dictionary = w.get("_comet")
	_c9_check("comet: tier 4 with 60 s life",
		int(a["tier"]) == 4 and absf(float(a["life"]) - 60.0) < 1.0,
		"tier=" + str(int(a["tier"])) + " life=" + str(float(a["life"])))
	var pflat := Vector2(p.global_position.x, p.global_position.z)
	var dist := pflat.distance_to(Vector2(float(a["x"]), float(a["z"])))
	_c9_check("comet: spawn lands in the 25-40u band (>= 18 retry floor)",
		dist >= 17.5 and dist <= 41.0, "dist=" + str(dist))
	# Life burns at zero charge while the player stays away.
	var life0: float = a["life"]
	await _c9_frames(150)
	_c9_check("comet: life burns down at zero charge",
		float(a["life"]) < life0 - 1.5, "life=" + str(float(a["life"])) + " from=" + str(life0))
	# Charging freezes the burn.
	_c14_teleport(p, float(a["x"]), float(a["z"]))
	var charged := await _c9_wait(func() -> bool: return float(a["charge"]) > 0.03, 600)
	_c9_check("comet: standing in the circle charges it", charged,
		"charge=" + str(float(a["charge"])))
	var life1: float = a["life"]
	await _c9_frames(150)
	_c9_check("comet: life is frozen while charge > 0",
		float(a["life"]) == life1, "life=" + str(float(a["life"])) + " was=" + str(life1))
	# Leaving drains the charge; at zero the burn resumes.
	_c14_teleport(p, float(a["x"]) + 60.0, float(a["z"]))
	var resumed := await _c9_wait(func() -> bool: return float(a["life"]) < life1 - 0.3, 900)
	_c9_check("comet: burn resumes once the charge drains to 0", resumed,
		"life=" + str(float(a["life"])) + " was=" + str(life1))
	await _c9_cleanup_run()
	# --- run 2: burn-out pays nothing ---
	ok = await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("comet: run 2 boots", false)
		return
	p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	w.set_base_weather("clear")
	w.set("_comet_t", 0.01)
	spawned = await _c9_wait(func() -> bool: return not (w.get("_comet") as Dictionary).is_empty(), 600)
	if not spawned:
		_c9_check("comet: run 2 spawn", false)
		await _c9_cleanup_run()
		return
	a = w.get("_comet")
	# Snapshot the blessing channels: in a full-suite run, earlier
	# phases can leave residue in the queue/offers arrays, so the
	# burn-out invariant is NO GROWTH across the burn-out window
	# (plus no modal opening), not absolute emptiness.
	var q0 := (w.get("_blessing_queue") as Array).size()
	var o0 := (w.get("_blessing_offers") as Array).size()
	a["life"] = 0.05  # fixture: the last breath of the mined 60 s
	var burnt := await _c9_wait(func() -> bool: return bool(a["used"]), 300)
	_c9_check("comet: burn-out marks the altar used", burnt)
	_c9_check("comet: burn-out pays no blessing",
		String(w.get("state")) == "playing"
			and (w.get("_blessing_queue") as Array).size() == q0
			and (w.get("_blessing_offers") as Array).size() == o0,
		"state=" + String(w.get("state")) + " queue=" + str((w.get("_blessing_queue") as Array).size())
			+ " offers=" + str((w.get("_blessing_offers") as Array).size()))
	_c9_check("comet: a spent comet blocks respawn (ref persists)",
		not (w.get("_comet") as Dictionary).is_empty())
	await _c9_cleanup_run()
	# --- run 3: completion pays the tier-4 blessing ---
	ok = await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("comet: run 3 boots", false)
		return
	p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	w.set_base_weather("clear")
	w.set("_comet_t", 0.01)
	spawned = await _c9_wait(func() -> bool: return not (w.get("_comet") as Dictionary).is_empty(), 600)
	if not spawned:
		_c9_check("comet: run 3 spawn", false)
		await _c9_cleanup_run()
		return
	a = w.get("_comet")
	var opened := false
	for i in range(3600):
		await get_tree().physics_frame
		_c14_teleport(p, float(a["x"]), float(a["z"]))
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		if String(w.get("state")) == "blessing":
			opened = true
			break
	_c9_check("comet: a full charge opens the blessing", opened,
		"state=" + String(w.get("state")) + " charge=" + str(float(a["charge"])))
	_c9_check("comet: altar marked used after completion", bool(a["used"]))
	var offers: Array = w.get("_blessing_offers")
	var min_rar := 99
	for o in offers:
		min_rar = mini(min_rar, int(o["rarity"]))
	_c9_check("comet: payout == 3 offers at min tier 1 (ZC tier 4)",
		offers.size() == 3 and min_rar >= 1,
		"offers=" + str(offers.size()) + " min_rarity=" + str(min_rar))
	if opened:
		w._apply_blessing_offer(0)
		_c9_check("comet: blessing pick returns to play",
			String(w.get("state")) == "playing")
	await _c9_cleanup_run()

## Props phase: the Cycle 15 populate kinds end-to-end.
## Run 1 walks the economy kinds in dependency order (greed
## before the XP-priced cage, modal kinds settled before
## timer kinds), with the berry driven through the REAL
## E-interact chain; run 2 covers the egg's team-cap
## fallback, the Porygon trade (persistence + exact
## recompiled mods), and the slots cost curve + one spin's
## observable prize signature.

func _c15_vit_total(w) -> int:
	var p = w.get("player")
	var s := 0
	for k in (p.get("vit_levels") as Dictionary).keys():
		s += int(p.vit_levels[k])
	return s

## Cycle 21: total item stacks the player holds.
func _c21_item_total(w) -> int:
	var p = w.get("player")
	var s := 0
	for v in (p.get("items") as Dictionary).values():
		s += int(v)
	return s

func _c9_props_phase() -> void:
	var w = _world
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("props: run 1 boots", false)
		return
	var p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	w.set_base_weather("clear")
	var st: Dictionary = (w.get("_inter_state") as Dictionary).get(1, {})
	var props: Array = st.get("props", [])
	var find_prop := func(kind: String, nth: int) -> Dictionary:
		var n := 0
		for pr in props:
			if String(pr["kind"]) == kind:
				if n == nth:
					return pr
				n += 1
		return {}
	var counts: Dictionary = {}
	for pr in props:
		counts[String(pr["kind"])] = int(counts.get(String(pr["kind"]), 0)) + 1
	var want_counts := {"fossil": 1, "greed": 1, "challenge": 2, "cursed": 1, "porygon": 1, "nest": 1,
		"meowth": 1, "ditto": 1, "snorlax": 2, "slots": 2, "freechest": 3, "cursedchest": 2, "cage": 2, "magnet": 2,
		"berry": 5, "chest": 14, "rock": 14}
	var counts_ok := props.size() == 55 and counts.size() == 17
	for k in want_counts.keys():
		if int(counts.get(k, 0)) != int(want_counts[k]):
			counts_ok = false
	_c9_check("props: zone 1 populates all 55 props (17 kinds, fossil added C24)", counts_ok,
		"counts=" + str(counts))
	var run_count := func(cname: String) -> int: return int((w.get("run_counts") as Dictionary).get(cname, 0))
	# C23 magnet writer: a real prop consumes once and sets five seconds.
	var magnet: Dictionary = find_prop.call("magnet", 0)
	w._interact_prop(magnet)
	_c9_check("c23 pickups: magnet prop sets magnetAll=5", bool(magnet["used"]) and is_equal_approx(float(w.get("pickups").magnet_all),5.0))
	# --- berry through the real E chain ---
	var berry: Dictionary = find_prop.call("berry", 0)
	p.hp = p.max_hp * 0.4
	_c14_teleport(p, float(berry["x"]) + 1.5, float(berry["z"]))
	await _c9_frames(3)
	_c9_key(KEY_E, true)
	var berry_ok := await _c9_wait(func() -> bool: return bool(berry["used"]), 240)
	_c9_key(KEY_E, false)
	await _c9_frames(45)
	_c9_check("props: berry eaten via the real E chain", berry_ok)
	_c9_check("props: berry heals 50% x heal_mult (capped)",
		absf(p.hp - minf(p.max_hp, p.max_hp * 0.4 + p.max_hp * 0.5 * float(p.get("heal_mult")))) < 1.0,
		"hp=" + str(p.hp) + " max=" + str(p.max_hp))
	_c9_check("props: 'berries' counted", run_count.call("berries") == 1)
	# --- rock ---
	var rock: Dictionary = find_prop.call("rock", 0)
	p.hp = p.max_hp
	var gold0: float = w.get("gold")
	w._interact_prop(rock)
	var rock_gain: float = float(w.get("gold")) - gold0
	_c9_check("props: rock pays round(range(6,14) x max(stage, VC/90)) == [6,14] at VC 18",
		rock_gain >= 6.0 and rock_gain <= 14.0 and bool(rock["used"]),
		"gain=" + str(rock_gain))
	_c9_check("props: 'rocks' counted", run_count.call("rocks") == 1)
	# --- greed ---
	var greed: Dictionary = find_prop.call("greed", 0)
	var xp0: float = p.xp_mult
	var gm0: float = p.gold_mult
	w._interact_prop(greed)
	_c9_check("props: greed lands difficulty x1.2 / xp x1.25 / gold x1.25",
		absf(float(p.get("difficulty_mult")) - 1.2) < 0.001
			and absf(p.xp_mult - xp0 * 1.25) < 0.001 and absf(p.gold_mult - gm0 * 1.25) < 0.001,
		"diff=" + str(float(p.get("difficulty_mult"))) + " xp=" + str(p.xp_mult) + " gold=" + str(p.gold_mult))
	# --- cursed (delayed item roll at floor 2, cycle 21) ---
	var cursed: Dictionary = find_prop.call("cursed", 0)
	var cit0 := _c21_item_total(w)
	w._interact_prop(cursed)
	_c9_check("props: cursed lands enemyAmount x1.15 and difficulty x1.1 (on greed's 1.2)",
		absf(float(p.get("enemy_amount_mult")) - 1.15) < 0.001
			and absf(float(p.get("difficulty_mult")) - 1.32) < 0.001,
		"amt=" + str(float(p.get("enemy_amount_mult"))) + " diff=" + str(float(p.get("difficulty_mult"))))
	_c9_check("props: 'curses' counted", run_count.call("curses") >= 1)
	var cursed_modal := await _c9_wait(func() -> bool: return bool(w.get("_choice_open")), 600)
	if cursed_modal:
		w._choice_pick(0)
		await _c9_frames(2)
	_c9_check("props: cursed pays its delayed item (floor 2 roll, modal taken)",
		cursed_modal and _c21_item_total(w) == cit0 + 1,
		"items=" + str(_c21_item_total(w)))
	_c211_dbg("props post-cursed")
	# --- snorlax x2: either branch, exact effect per branch ---
	for si in range(2):
		var snor: Dictionary = find_prop.call("snorlax", si)
		var g0: float = w.get("gold")
		var blessed := false
		w._interact_prop(snor)
		await _c9_frames(3)
		if String(w.get("state")) == "blessing":
			blessed = true
			w._apply_blessing_offer(0)
		elif not (w.get("_blessing_queue") as Array).is_empty():
			blessed = true
		var gd: float = float(w.get("gold")) - g0
		_c9_check("props: snorlax %d resolves (blessing XOR 30 gold)" % (si + 1),
			bool(snor["used"]) and (blessed != (gd == 30.0)),
			"blessed=" + str(blessed) + " gold_delta=" + str(gd))
	_c211_dbg("props post-snorlax")
	# --- cage: deny poor, then pay 20+10 for half a level of XP ---
	var cage: Dictionary = find_prop.call("cage", 0)
	w.set("gold", 5.0)
	w._interact_prop(cage)
	_c9_check("props: cage denies when gold < cost (not used)",
		not bool(cage["used"]) and float(w.get("gold")) == 5.0)
	p.set("level", 40)  # fixture: xp_next large enough that half of it cannot cross
	var cxp0: float = p.xp
	var cnext: float = p.xp_next()
	var cmult: float = p.xp_mult
	w.set("gold", 1000.0)
	w._interact_prop(cage)
	_c9_check("props: cage charges 20 + stage x 10 == 30",
		absf(float(w.get("gold")) - 970.0) < 0.01 and bool(cage["used"]),
		"gold=" + str(float(w.get("gold"))))
	_c9_check("props: cage pays xpNext x .5 (xpGain applied)",
		absf((p.xp - cxp0) - cnext * 0.5 * cmult) < 0.5,
		"delta=" + str(p.xp - cxp0) + " want=" + str(cnext * 0.5 * cmult))
	_c9_check("props: the freed species' rig hides",
		not (cage["data"]["rig"] as Node3D).visible)
	# --- paid chest: cost curve, pick, then sell on a second ---
	_c9_check("props: BC(0) == 1 and BC(1) == 1.22 + 35/30",
		w._bc(0) == 1.0 and absf(w._bc(1) - (1.22 + 35.0 / 30.0)) < 0.000000001,
		"bc1=" + str(w._bc(1)))
	var luck_factor := 1.0 - minf(0.25, float(p.get("luck")) / 400.0)
	var nug_factor := 1.0 - minf(0.4, 0.08 * float(p.call("item_count", "big-nugget")))
	_c9_check("props: chest cost == round(18 x BC(bought) x luck x nugget)",
		w._chest_cost() == int(round(18.0 * w._bc(0) * luck_factor * nug_factor)),
		"cost=" + str(w._chest_cost()))
	var chest1: Dictionary = find_prop.call("chest", 0)
	w.set("gold", 10000.0)
	var cit1 := _c21_item_total(w)
	w._interact_prop(chest1)
	_c9_check("props: paid chest opens the choice modal and counts the purchase",
		String(w.get("state")) == "choice" and int(w.get("_chests_bought")) == 1,
		"state=" + String(w.get("state")) + " bought=" + str(int(w.get("_chests_bought"))))
	w._choice_pick(0)
	_c211_dbg("props post-chest1-pick")
	_c9_check("props: chest pick grants exactly one item and closes (C21)",
		_c21_item_total(w) == cit1 + 1 and String(w.get("state")) == "playing",
		"items=" + str(_c21_item_total(w)))
	# luck/nugget factors are recomputed live: the chest-1 item
	# pick may itself have granted luck or a nugget, and the
	# game prices off the CURRENT state.
	_c9_check("props: cost after one purchase == round(18 x BC(1) x discounts)",
		w._chest_cost() == int(round(18.0 * w._bc(1)
			* (1.0 - minf(0.25, float(p.get("luck")) / 400.0))
			* (1.0 - minf(0.4, 0.08 * float(p.call("item_count", "big-nugget")))))),
		"cost=" + str(w._chest_cost()))
	var chest2: Dictionary = find_prop.call("chest", 1)
	w._interact_prop(chest2)
	# g1 is read AFTER the open: opening chest 2 charges its cost first,
	# so the sell delta is measured from the post-charge balance.
	var g1: float = w.get("gold")
	var foot_text := (w.get("_choice_foot") as Button).text
	var sell_want := -1
	var parts := foot_text.split(" ")
	for tok in parts:
		if String(tok).is_valid_int():
			sell_want = int(tok)
	w._choice_close(true)
	_c9_check("props: sell-all pays the footer's qC minimum",
		sell_want > 0 and absf((float(w.get("gold")) - g1) - float(sell_want)) < 0.01,
		"delta=" + str(float(w.get("gold")) - g1) + " want=" + str(sell_want))
	# --- freechest (cycle 21: an item modal, floor 1) ---
	var free1: Dictionary = find_prop.call("freechest", 0)
	var cit2 := _c21_item_total(w)
	w._interact_prop(free1)
	var free_modal := bool(w.get("_choice_open"))
	if free_modal:
		w._choice_pick(0)
		await _c9_frames(2)
	_c9_check("props: freechest grants one item via the modal (floor 1)",
		free_modal and _c21_item_total(w) == cit2 + 1 and bool(free1["used"]),
		"items=" + str(_c21_item_total(w)))
	# --- cursed chest: mod + item modal + ghost ambush ---
	var cchest: Dictionary = find_prop.call("cursedchest", 0)
	var diff0: float = p.get("difficulty_mult")
	var cit3 := _c21_item_total(w)
	w._interact_prop(cchest)
	var cc_modal := bool(w.get("_choice_open"))
	if cc_modal:
		w._choice_pick(0)
		await _c9_frames(2)
	_c9_check("props: cursed chest adds difficulty x1.05 and grants an item",
		absf(float(p.get("difficulty_mult")) - diff0 * 1.05) < 0.001
			and cc_modal and _c21_item_total(w) == cit3 + 1,
		"diff=" + str(float(p.get("difficulty_mult"))))
	await _c9_frames(60)
	var ghosts := 0
	var ghost_elites := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if String(e.get("species_id")) in ["gastly", "haunter", "gengar"]:
			ghosts += 1
			if int(e.get("flag")) == 1:
				ghost_elites += 1
	_c9_check("props: cursed chest ambush == 4 + 2 x stage ghosts, first Elite",
		ghosts == 6 and ghost_elites == 1, "ghosts=" + str(ghosts) + " elites=" + str(ghost_elites))
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _c9_frames(2)
	# --- challenge: full wave, completion, free chest spawns ---
	var chal: Dictionary = find_prop.call("challenge", 0)
	var props_n0 := props.size()
	_c211_dbg("props pre-challenge")
	w._interact_prop(chal)
	_c9_check("props: challenge starts used with spawns pending",
		bool(chal["used"]) and int(chal["data"]["pending"]) > 0,
		"pending=" + str(int(chal["data"]["pending"])))
	var spawned_all := await _c9_wait(func() -> bool: return int(chal["data"]["pending"]) == 0, 900)
	_c211_dbg("props post-challenge-wait")
	_c9_check("props: challenge wave fully spawns (8 + 3 x stage == 11)",
		spawned_all and (chal["data"]["wave"] as Array).size() == 11,
		"wave=" + str((chal["data"]["wave"] as Array).size()))
	var welites := 0
	for e in chal["data"]["wave"]:
		if int(e.get("flag")) == 1:
			welites += 1
	_c9_check("props: challenge's first 1 + floor(stage/2) are Elite",
		welites == 1, "elites=" + str(welites))
	for e in chal["data"]["wave"]:
		if is_instance_valid(e):
			e.take_damage(1000000000.0, "")
	var chal_done := false
	for i in range(400):
		await get_tree().physics_frame
		if String(w.get("state")) == "draft":
			w._apply_draft_option(0)
		if bool(chal["data"].get("done", false)):
			chal_done = true
			break
	_c9_check("props: challenge completes when the wave dies", chal_done)
	_c9_check("props: 'challenges' counted", run_count.call("challenges") == 1)
	_c9_check("props: completion spawns a free chest at +(2.5, 2.5)",
		props.size() == props_n0 + 1 and String(props[props.size() - 1]["kind"]) == "freechest"
			and absf(float(props[props.size() - 1]["x"]) - (float(chal["x"]) + 2.5)) < 0.6
			and absf(float(props[props.size() - 1]["z"]) - (float(chal["z"]) + 2.5)) < 0.6,
		"props=" + str(props.size()))
	# --- nest: carry, deny second touch, hatch recruits ---
	var nest: Dictionary = find_prop.call("nest", 0)
	w._interact_prop(nest)
	_c9_check("props: nest hands over an egg (need == 200 at stage 1)",
		not (w.get("_egg") as Dictionary).is_empty() and int((w.get("_egg") as Dictionary)["need"]) == 200,
		"egg=" + str(w.get("_egg")))
	var egg_from := int((w.get("_egg") as Dictionary)["from"])
	w._interact_prop(nest)
	_c9_check("props: a second nest touch is denied while carrying",
		int((w.get("_egg") as Dictionary).get("from", -1)) == egg_from)
	w.set("kills", egg_from + 200)
	var hatched := await _c9_wait(func() -> bool:
		return (w.get("_egg") as Dictionary).is_empty() and get_tree().get_nodes_in_group("allies").size() >= 1, 600)
	_c211_dbg("props post-hatch-wait")
	_c9_check("props: egg hatches at dp kills into a recruited ally", hatched,
		"allies=" + str(get_tree().get_nodes_in_group("allies").size()))
	_c9_check("props: 'eggs' counted", run_count.call("eggs") == 1)
	await _c9_cleanup_run()
	# ================= run 2: egg cap fallback, porygon, slots ================
	ok = await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("props: run 2 boots", false)
		return
	p = w.get("player")
	p.invulnerable = true
	p.moves.clear()
	w.set_base_weather("clear")
	st = (w.get("_inter_state") as Dictionary).get(1, {})
	props = st.get("props", [])
	# --- egg fallback: team at cap -> the hatch pays a chest roll ---
	var nest2: Dictionary = find_prop.call("nest", 0)
	w._interact_prop(nest2)
	var cap := int(w.call("_team_cap"))
	while get_tree().get_nodes_in_group("allies").size() < cap:
		var ally = w._spawn_enemy_at("rattata", p.global_position + Vector3(2.0, 0, 2.0), 1.0, false, 1.0)
		ally.make_ally()
	# Cycle 21.1: the C15-era version of this check waited
	# for a VITAMIN total to grow — since C21 the fallback
	# pays a real item roll (_chest_roll_single), which
	# opens the take-or-sell modal and grants nothing until
	# the card is taken. Measure items, and take the card
	# through the real pick path.
	var items_fb := _c21_item_total(w)
	var egg2: Dictionary = w.get("_egg")
	w.set("kills", int(egg2["from"]) + int(egg2["need"]))
	var fb_modal := await _c9_wait(func() -> bool:
		return (w.get("_egg") as Dictionary).is_empty() and bool(w.get("_choice_open")), 600)
	if fb_modal:
		w._choice_pick(0)
		await _c9_frames(2)
	_c211_dbg("props post-fallback-wait")
	_c9_check("props: at team cap the hatch falls back to a chest roll",
		fb_modal and _c21_item_total(w) == items_fb + 1
			and get_tree().get_nodes_in_group("allies").size() == cap,
		"allies=" + str(get_tree().get_nodes_in_group("allies").size()) + " cap=" + str(cap)
			+ " items=" + str(_c21_item_total(w)))
	for a2 in get_tree().get_nodes_in_group("allies"):
		a2.queue_free()
	await _c9_frames(2)
	# --- porygon: offers persist, pick applies gain+loss exactly ---
	var pory: Dictionary = find_prop.call("porygon", 0)
	w._interact_prop(pory)
	_c9_check("props: porygon opens the trade modal with 3 offers",
		String(w.get("state")) == "choice" and (pory["data"]["offers"] as Array).size() == 3,
		"state=" + String(w.get("state")))
	var sig := ""
	for o in pory["data"]["offers"]:
		sig += String(o["gain"]["stat"]) + "/" + String(o["loss"]["stat"]) + ";"
	w._choice_close(true)
	_c9_check("props: leaving the trade keeps it unused",
		not bool(pory["used"]) and String(w.get("state")) == "playing")
	w._interact_prop(pory)
	var sig2 := ""
	for o in pory["data"]["offers"]:
		sig2 += String(o["gain"]["stat"]) + "/" + String(o["loss"]["stat"]) + ";"
	_c9_check("props: offers persist across opens", sig == sig2, sig + " vs " + sig2)
	var offer0: Dictionary = (pory["data"]["offers"] as Array)[0]
	var gstat := String(offer0["gain"]["stat"])
	var lstat := String(offer0["loss"]["stat"])
	var g_before := _c14_stat(p, gstat)
	var l_before := _c14_stat(p, lstat)
	w._choice_pick(0)
	_c9_check("props: the trade is one-shot and lands in recompiled_mods",
		bool(pory["used"]) and (p.get("recompiled_mods") as Array).size() == 2)
	var gmod: Dictionary = offer0["gain"]["gain"]
	var lmod: Dictionary = offer0["loss"]["loss"]
	var g_want := g_before
	var l_want := l_before
	if gmod.has("mul"):
		g_want = g_before * float(gmod["mul"])
	if gmod.has("add"):
		g_want = g_before + float(gmod["add"])
	if lmod.has("mul"):
		l_want = l_before * float(lmod["mul"])
	if lmod.has("add"):
		l_want = l_before + float(lmod["add"])
	_c9_check("props: gain applies exactly (%s)" % gstat,
		absf(_c14_stat(p, gstat) - g_want) < 0.002,
		"before=" + str(g_before) + " after=" + str(_c14_stat(p, gstat)) + " want=" + str(g_want))
	_c9_check("props: loss applies exactly (%s)" % lstat,
		absf(_c14_stat(p, lstat) - l_want) < 0.002,
		"before=" + str(l_before) + " after=" + str(_c14_stat(p, lstat)) + " want=" + str(l_want))
	# --- slots: cost curve, deny, one spin's prize signature ---
	var slots: Dictionary = find_prop.call("slots", 0)
	_c9_check("props: slots cost at 0 spins == 40 (WC(2) == 1 at stage 1)",
		w._slots_cost() == 40, "cost=" + str(w._slots_cost()))
	w.set("_slot_spins", 10)
	_c9_check("props: slots cost scales x1.08 per spin (86 at 10)",
		w._slots_cost() == int(round(40.0 * pow(1.08, 10.0))),
		"cost=" + str(w._slots_cost()))
	w.set("_slot_spins", 0)
	w.set("gold", 0.0)
	w._interact_prop(slots)
	_c9_check("props: slots denies when gold < cost (no spin consumed)",
		int(w.get("_slot_spins")) == 0)
	w.set("gold", 10000.0)
	p.hp = p.max_hp * 0.5
	var sg0: float = w.get("gold")
	var svit0 := _c21_item_total(w)
	var sdiff0: float = p.get("difficulty_mult")
	var shp0: float = p.hp
	var near0 := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d3: Vector3 = e.global_position - Vector3(float(slots["x"]), 0, float(slots["z"]))
		d3.y = 0.0
		if d3.length() < 9.0:
			near0 += 1
	w._interact_prop(slots)
	await _c9_frames(45)  # the voltorb ambush rides a 0.3 s later
	var sgd: float = float(w.get("gold")) - sg0
	var near1 := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var d3: Vector3 = e.global_position - Vector3(float(slots["x"]), 0, float(slots["z"]))
		d3.y = 0.0
		if d3.length() < 9.0:
			near1 += 1
	# Cycle 21: item prizes arrive as modals (queued rolls
	# drain on close) — take every card, then count items.
	for di in range(8):
		if bool(w.get("_choice_open")):
			w._choice_pick(0)
			await _c9_frames(2)
		await _c9_settle_drafts()
		if not bool(w.get("_choice_open")) and (w.get("_pending_item_rolls") as Array).is_empty():
			break
	var svit: int = _c21_item_total(w) - svit0
	var sig_seven := svit == 3 and sgd == -40.0
	var sig_pikachu := svit == 1 and sgd == -40.0 and absf(p.hp - shp0) < 1.0
	var sig_berry: bool = svit == 1 and sgd == -40.0 and float(p.hp) > shp0 + 1.0
	var sig_meowth := sgd == 60.0
	var sig_gengar := sgd == -40.0 and svit == 0 and absf(float(p.get("difficulty_mult")) - sdiff0 * 1.05) < 0.001
	var sig_voltorb := sgd == -40.0 and svit == 0 and near1 - near0 >= 4
	var sig_none := sgd == -40.0 and svit == 0 and absf(float(p.get("difficulty_mult")) - sdiff0) < 0.001 and near1 - near0 < 4
	var sigs := [sig_seven, sig_pikachu, sig_berry, sig_meowth, sig_gengar, sig_voltorb, sig_none]
	var sig_hits := 0
	for s in sigs:
		if s:
			sig_hits += 1
	_c9_check("props: one spin consumes the cost and resolves to exactly one prize signature",
		int(w.get("_slot_spins")) == 1 and int(w.get("_slot_spent")) == 40 and sig_hits == 1,
		"sigs=" + str(sigs) + " gd=" + str(sgd) + " vit=" + str(svit))
	await _c9_cleanup_run()

# ------------------------------------------------------------ cycle 16
## Audio layer: buses, volume law, settings application,
## hidden-mute, the music director, and event->play wiring
## counted through real flows (kills, ult, guardian, chest,
## run end). Waveform quality is NOT asserted; counts and
## stream existence/lengths are.
func _c16_c16_pump(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _c16_pump(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

## Level-ups under any kill can open the draft modal (state
## "draft"), which gates ult.update and summon_guardian;
## resolve open modals through the real pick paths.
func _c16_settle() -> void:
	# Cycle 18: widened 8 -> 60 — the draft's 600 ms input
	# guard (bundle modal()) makes the first picks no-ops;
	# the settle must outlast it in wall time.
	for i in range(60):
		var st := String(_world.get("state"))
		if st == "draft":
			_world.call("_apply_draft_option", 0)
		elif st == "blessing":
			_world.call("_apply_blessing_offer", 0)
		else:
			break
		await get_tree().process_frame

func _c16_sliders(n: Node, out: Array) -> void:
	if n is HSlider:
		out.append(n)
	for c in n.get_children():
		_c16_sliders(c, out)

## Cycle 18: audio sliders only (setting_key meta), returned
## in [master, music, sfx, cries] order.
func _c18_audio_sliders(n: Node, out: Array) -> void:
	var all: Array = []
	_c16_sliders(n, all)
	var by_key: Dictionary = {}
	for s in all:
		var k := String((s as HSlider).get_meta("setting_key", ""))
		if k != "":
			by_key[k] = s
	for k in ["master", "music", "sfx", "cries"]:
		if by_key.has(k):
			out.append(by_key[k])

func _c9_audio_phase() -> void:
	var A = _world.get("audio")
	_c9_check("audio: engine exists", A != null)
	if A == null:
		return
	# Buses + the bundle's volume law from the CURRENT settings.
	for bn in ["Music", "SFX", "Cries", "Kit"]:
		_c9_check("audio: bus %s exists" % bn, AudioServer.get_bus_index(bn) >= 0)
	var sfx_i := AudioServer.get_bus_index("SFX")
	var mus_i := AudioServer.get_bus_index("Music")
	var cry_i := AudioServer.get_bus_index("Cries")
	_c9_check("audio: sfx bus = setting x .55", absf(db_to_linear(AudioServer.get_bus_volume_db(sfx_i)) - float(GameProfile.setting("sfx")) * 0.55) < 0.02,
		"lin=" + str(db_to_linear(AudioServer.get_bus_volume_db(sfx_i))))
	_c9_check("audio: music bus = setting x .32", absf(db_to_linear(AudioServer.get_bus_volume_db(mus_i)) - float(GameProfile.setting("music")) * 0.32) < 0.02,
		"lin=" + str(db_to_linear(AudioServer.get_bus_volume_db(mus_i))))
	_c9_check("audio: cries bus = setting x .45", absf(db_to_linear(AudioServer.get_bus_volume_db(cry_i)) - float(GameProfile.setting("cries")) * 0.45) < 0.02,
		"lin=" + str(db_to_linear(AudioServer.get_bus_volume_db(cry_i))))
	_c9_check("audio: voice pool is the bundle's 26", int(A.call("sfx_voice_count")) == 26,
		"n=" + str(A.call("sfx_voice_count")))
	# Cycle 21.1: in a full-suite run this phase is NOT at
	# boot — the previous phase's run track is still loaded
	# and the music director only re-asserts on its 0.5 s
	# cadence (state is already "menu" after cleanup). Wait
	# for the director to settle, exactly like this phase's
	# own "director back to menu track" check below; the
	# assertion itself is unchanged.
	var boot_menu := false
	for i in range(150):
		await get_tree().process_frame
		if String(A.get("current_track")) == "menu":
			boot_menu = true
			break
	_c9_check("audio: menu track playing at boot", boot_menu and int(A.call("count_of", "track:menu")) >= 1,
		"track=" + String(A.get("current_track")))
	_c9_check("audio: buffers render non-silent", float(A.call("stream_length", "coin")) > 0.05 and float(A.call("stream_length", "boom")) > 0.3,
		"coin=" + str(A.call("stream_length", "coin")))
	var sdata: PackedByteArray = (A.call("stream_for", "boom") as AudioStreamWAV).data
	var loud := false
	for b in sdata:
		if b != 128:
			loud = true
			break
	_c9_check("audio: boom buffer has signal", loud)
	_c9_check("audio: boss loop is the bundle's 8.96 s", absf(float(A.call("stream_length", "track:boss")) - 8.97) < 0.2,
		"len=" + str(A.call("stream_length", "track:boss")))
	# Settings apply live (music slider to zero and back).
	var mus0 := float(GameProfile.setting("music"))
	GameProfile.set_setting("music", 0.0)
	_world.call("_apply_audio_settings")
	await _c16_pump(6)
	_c9_check("audio: music=0 silences the music bus", db_to_linear(AudioServer.get_bus_volume_db(mus_i)) < 0.001,
		"lin=" + str(db_to_linear(AudioServer.get_bus_volume_db(mus_i))))
	GameProfile.set_setting("music", mus0)
	_world.call("_apply_audio_settings")
	# Hidden mute: (unfocused && muteHidden) ramps the master.
	var mh0 := bool(GameProfile.setting("muteHidden"))
	GameProfile.set_setting("muteHidden", true)
	_world.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _c16_pump(50)
	_c9_check("audio: focus-out + muteHidden mutes master", db_to_linear(AudioServer.get_bus_volume_db(0)) < 0.05,
		"lin=" + str(db_to_linear(AudioServer.get_bus_volume_db(0))))
	_world.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	var restored := false
	for i in range(600):
		await get_tree().process_frame
		if absf(float(A.get("_master_eff")) - float(GameProfile.setting("master"))) < 0.05:
			restored = true
			break
	_c9_check("audio: focus-in restores master", restored,
		"eff=" + str(A.get("_master_eff")) + " lin=" + str(db_to_linear(AudioServer.get_bus_volume_db(0))) + " mute=" + str(A.get("_hidden_mute")) + " focused=" + str(_world.get("_window_focused")))
	GameProfile.set_setting("muteHidden", mh0)
	_world.call("_apply_audio_settings")
	# ok() throttle: five same-frame hit() calls land ONE play.
	A.call("hit", 1.0)  # pre-warm the buffer render
	await _c16_pump(10)
	var hn0 := int(A.call("count_of", "hit_neutral"))
	for i in range(5):
		A.call("hit", 1.0)
	_c9_check("audio: hit throttle .035 admits 1 of 5", int(A.call("count_of", "hit_neutral")) - hn0 == 1,
		"delta=" + str(int(A.call("count_of", "hit_neutral")) - hn0))
	# ---- run flow wiring
	var ok := await _c9_start_run("bulbasaur")
	_c9_check("audio: run starts", ok)
	if not ok:
		return
	var run_track := String(_world.get("_run_music"))
	var on_run := false
	for i in range(150):
		await get_tree().process_frame
		if String(A.get("current_track")) == run_track:
			on_run = true
			break
	_c9_check("audio: director plays the drawn run track", on_run and run_track.begins_with("ingame"),
		"track=" + String(A.get("current_track")) + " run=" + run_track + " state=" + String(_world.get("state")) + " mt=" + str(_world.get("_music_t")))
	var p = _world.get("player")
	# Typed hits: fire vs a grass enemy = super, water = weak.
	var foe = _world.call("_spawn_enemy_at", "bulbasaur", p.global_position + Vector3(3, 0, 0), 50.0)
	var hs0 := int(A.call("count_of", "hit_super"))
	foe.call("take_damage", 5.0, "fire")
	# hit() shares one ok('hit', .035) gate across variants (the
	# bundle's strike-level throttle) — space the two strikes
	# by >35 ms of real time, like a real attack cadence. The
	# resisted strike lands on a SECOND foe parked far outside
	# the player's auto-fire reach, so no ambient player strike
	# can consume the gate in between.
	# Remove foe1 from the player's auto-fire reach (a corpse
	# draws no strikes): its own death hit stamps the gate,
	# then the 60 ms wait lets the gate expire.
	foe.call("take_damage", 999999.0, "normal")
	var foe2 = _world.call("_spawn_enemy_at", "bulbasaur", p.global_position + Vector3(25, 0, 0), 50.0)
	var tw := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tw < 60:
		await get_tree().process_frame
	# Snapshot AFTER the wait, synchronously before the strike:
	# ambient hits during the wait (foe1 is in the player's
	# auto-fire reach) may legitimately consume the shared gate
	# and add weak counts of their own — neither may pollute
	# the baseline, and no frame passes between snapshot and
	# strike, so nothing can consume the gate in between.
	var hw0 := int(A.call("count_of", "hit_weak"))
	var dealt2 = foe2.call("take_damage", 5.0, "water")
	await _c16_pump(4)
	_c9_check("audio: super-effective hit sound", int(A.call("count_of", "hit_super")) > hs0)
	_c9_check("audio: resisted hit sound", int(A.call("count_of", "hit_weak")) > hw0,
		"dealt=" + str(dealt2) + " types=" + str(foe2.get("types")) + " eff=" + str(GameData.type_mult("water", foe2.get("types"))))
	# Direct-API probe isolates the engine path from the enemy
	# path (same 60 ms gate spacing).
	var tw2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tw2 < 60:
		await get_tree().process_frame
	var hw1 := int(A.call("count_of", "hit_weak"))
	A.call("hit", 0.5)
	_c9_check("audio: direct hit(0.5) plays weak", int(A.call("count_of", "hit_weak")) > hw1,
		"weak=" + str(A.call("count_of", "hit_weak")))
	# Kills play pop/streak; collected XP entities play the XP ladder.
	var pop0 := int(A.call("count_of", "pop"))
	var xp0 := int(A.call("count_of", "xp"))
	var st0 := int(A.call("count_of", "streak"))
	# The two kills are spaced by ~60 ms of REAL time (the
	# pop/xp ok() gates are .03/.035 s) but only a frame or two
	# of GAME time, so the 1.5 s chain window cannot lapse —
	# llvmpipe frames can each carry >1 s of game time.
	var m1 = _world.call("_spawn_enemy_at", "rattata", p.global_position + Vector3(2, 0, 1), 0.01)
	var m2 = _world.call("_spawn_enemy_at", "rattata", p.global_position + Vector3(3, 0, 1), 0.01)
	m1.call("take_damage", 99999.0, "normal")
	_c23_collect_last_xp(_world, p)
	var tk := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tk < 60:
		await get_tree().process_frame
	m2.call("take_damage", 99999.0, "normal")
	_c23_collect_last_xp(_world, p)
	await _c16_pump(24)
	_c9_check("audio: kills play pop and collected entities play xp", int(A.call("count_of", "pop")) >= pop0 + 2 and int(A.call("count_of", "xp")) >= xp0 + 2,
		"pop=" + str(A.call("count_of", "pop")) + " xp=" + str(A.call("count_of", "xp")))
	_c9_check("audio: chained kills play streak", int(A.call("count_of", "streak")) > st0)
	# Player hurt / dodge (evasion is a labelled fixture).
	var hurt0 := int(A.call("count_of", "hurt"))
	var dg0 := int(A.call("count_of", "dodge"))
	p.set("evasion", 0.0)
	p.set("_invuln_t", 0.0)
	p.call("take_damage", 5.0)
	_c9_check("audio: landed hit on player plays hurt", int(A.call("count_of", "hurt")) > hurt0)
	p.set("evasion", 1.0)
	p.set("_invuln_t", 0.0)
	p.call("take_damage", 5.0)
	_c9_check("audio: dodged hit plays dodge", int(A.call("count_of", "dodge")) > dg0)
	p.call("recalc")
	# Ult: fire ducks + casts; pressing empty denies.
	await _c16_settle()
	var u = _world.get("ult")
	u.set("charge", 1.0)
	var duck0 := int(A.get("duck_count"))
	var sg0 := int(A.call("count_of", "shot_grass"))
	u.call("press_button")
	await _c16_pump(30)
	_c9_check("audio: ult fire ducks the music", int(A.get("duck_count")) > duck0)
	_c9_check("audio: roots ult casts shot(grass)", int(A.call("count_of", "shot_grass")) > sg0)
	await _c16_settle()
	var dn0 := int(A.call("count_of", "deny"))
	u.call("press_button")
	await _c16_pump(12)
	_c9_check("audio: ult press while spent denies", int(A.call("count_of", "deny")) > dn0)
	# Guardian: intro sounds, boss track, death boom + coin.
	# The boom/coin baselines are taken BEFORE the summon: the
	# guardian may fall to the player's own DPS during the
	# boss-track wait, which is still a real guardian death.
	# Fixture (labelled): the player enters the boss section at
	# full HP and invulnerable — earlier sections trade blows
	# with the player, and a mid-section death would end the
	# run (and freeze the cap clock) before the kill loop.
	await _c16_settle()
	p.set("hp", p.get("max_hp"))
	p.set("invulnerable", true)
	var bs0 := int(A.call("count_of", "boss_start"))
	var bo0 := int(A.call("count_of", "boom"))
	var co0 := int(A.call("count_of", "coin"))
	_world.call("summon_guardian")
	await _c16_pump(10)
	var g = _world.get("guardian")
	_c9_check("audio: guardian spawn plays boss_start + cry", int(A.call("count_of", "boss_start")) > bs0 and int(A.call("count_of", "cry:" + String(g.get("species_id")))) >= 1)
	var on_boss := false
	for i in range(150):
		await get_tree().process_frame
		if String(A.get("current_track")) == "boss":
			on_boss = true
			break
	_c9_check("audio: director switches to boss track", on_boss,
		"track=" + String(A.get("current_track")) + " state=" + String(_world.get("state")))
	# Kill the guardian through the REAL killed-signal path.
	# The Eb cap arithmetic itself is the bossscale phase's
	# verified claim; here the claim is the death SOUNDS, so
	# the HP is fixtured to 1 (the standing e.hp= idiom) and
	# the blow still flows through take_damage -> cap -> death
	# -> _on_guardian_killed. (A full bank-drain loop here
	# stalled >9 min: the cap clock only ticks while the world
	# runs unfrozen, and boss-fight hitstop starves it.)
	var g2 = _world.get("guardian")
	var gf := 0
	var reward_coin: Dictionary = {}
	if g2 != null and is_instance_valid(g2) and float(g2.get("hp")) > 0.0:
		g2.set("hp", 1.0)
		while is_instance_valid(g2) and float(g2.get("hp")) > 0.0 and gf < 600:
			g2.call("take_damage", 5.0, "")
			if float(g2.get("hp")) <= 0.0:
				# Capture an entity created by this synchronous guardian kill,
				# before physics frames can add unrelated ambient drops.
				var pool = _world.get("pickups")
				for ci in range(pool.entries.size()-1,-1,-1):
					if int(pool.entries[ci].kind)==1:
						reward_coin = pool.entries[ci]
						break
			await get_tree().physics_frame
			gf += 1
	_c9_check("audio: guardian death immediately plays boom", int(A.call("count_of", "boom")) > bo0,
		"boom=" + str(A.call("count_of", "boom")) + "/" + str(bo0) + " frames=" + str(gf))
	await _c16_pump(30)
	# Collection must use the real entity tick, not a direct audio call.
	# A coin naturally collected during the wait has already used this path.
	if not reward_coin.is_empty():
		_c23_collect_pickup(_world, p, reward_coin)
	_c9_check("audio: guardian reward collection plays coin", int(A.call("count_of", "coin")) > co0,
		"coin=" + str(A.call("count_of", "coin")) + "/" + str(co0))
	var back := false
	for i in range(150):
		await get_tree().process_frame
		if String(A.get("current_track")) == run_track:
			back = true
			break
	_c9_check("audio: director returns to run track", back,
		"track=" + String(A.get("current_track")) + " run=" + run_track)
	p.set("invulnerable", false)
	# Chest + run end.
	await _c16_settle()
	var ch0 := int(A.call("count_of", "chest"))
	_world.call("_spawn_chest", p.global_position + Vector3(3, 0, 0))
	var chests: Array = _world.get("_chests")
	_world.call("_open_chest", chests[chests.size() - 1])
	_c9_check("audio: chest opens with chest()", int(A.call("count_of", "chest")) > ch0)
	var df0 := int(A.call("count_of", "defeat"))
	_world.call("_finish_run", false)
	_c9_check("audio: defeat stinger on run end", int(A.call("count_of", "defeat")) > df0)
	var menu_back := false
	for i in range(150):
		await get_tree().process_frame
		if String(A.get("current_track")) == "menu":
			menu_back = true
			break
	_c9_check("audio: director back to menu track", menu_back,
		"track=" + String(A.get("current_track")))

## Daily shop (cycle 16): the bundle's fixed stardust catalog,
## per-day quotas, +50% intra-day price escalation, the bag cap
## and the wA error ladder — driven through Profile's real API
## with an injected clock, then through the real panel button.
## The resident profile is snapshotted and restored.
func _c9_shop_phase() -> void:
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	var expect := [["rare-candy", 150, 4], ["lucky-egg", 250, 4], ["amulet-coin", 250, 4],
		["honey", 450, 3], ["shiny-stone", 900, 2], ["master-ball", 1800, 1]]
	var cat_ok := GameProfile.SHOP_ITEMS.size() == 6
	for i in range(expect.size()):
		var it: Dictionary = GameProfile.SHOP_ITEMS[i]
		cat_ok = cat_ok and String(it["id"]) == String(expect[i][0]) and int(it["price"]) == int(expect[i][1]) and int(it["daily"]) == int(expect[i][2])
	_c9_check("shop: catalog matches the bundle (6 items)", cat_ok)
	var anchor := GameProfile._shop_anchor_unix()
	_c9_check("shop: day numbering (anchor=1, +1d=2, -1s=0)",
		int(GameProfile.shop_day_number(anchor)) == 1 and int(GameProfile.shop_day_number(anchor + 86400.0)) == 2 and int(GameProfile.shop_day_number(anchor - 1.0)) == 0)
	_c9_check("shop: reset countdown", int(GameProfile.shop_seconds_to_reset(anchor + 1000.0)) == 85400,
		"s=" + str(GameProfile.shop_seconds_to_reset(anchor + 1000.0)))
	var fake := anchor + 3.0 * 86400.0 + 3600.0  # day 4, 01:00 UTC
	GameProfile.add_stardust(100000)
	# Cycle 21.1 fixture hermeticity: the counts below are
	# absolute (bag == 1 after one buy, == 4 at quota, == 9
	# at cap), so the phase must start from an EMPTY bag —
	# a resident profile with a stocked bag (the NUC
	# resident) failed every one of them in the C21.1
	# instrumented suite while the empty-bag VM resident
	# passed. The phase snapshot restores the resident bag.
	GameProfile.data["bag"] = {}
	GameProfile.data["shop"] = {"day": int(GameProfile.shop_day_number(fake)), "n": {}}
	GameProfile.save_profile()
	var sd0 := GameProfile.stardust()
	var err := String(GameProfile.shop_buy("rare-candy", fake))
	_c9_check("shop: first buy succeeds at base price", err == "" and GameProfile.stardust() == sd0 - 150 and GameProfile.bag_count("rare-candy") == 1,
		"err=" + err + " sd=" + str(GameProfile.stardust()))
	_c9_check("shop: price escalates +50% per same-day buy", int(GameProfile.shop_price("rare-candy", fake)) == 225,
		"p=" + str(GameProfile.shop_price("rare-candy", fake)))
	for k in range(3):
		GameProfile.shop_buy("rare-candy", fake)
	_c9_check("shop: quota fills at the daily cap", GameProfile.bag_count("rare-candy") == 4)
	var sd_full := GameProfile.stardust()
	err = String(GameProfile.shop_buy("rare-candy", fake))
	_c9_check("shop: 5th buy is soldout, no charge", err == "soldout" and GameProfile.stardust() == sd_full, "err=" + err)
	# Bag cap: honey 3/day across three fake days -> 9 = cap.
	for d in range(3):
		var fd := fake + float(d) * 86400.0
		for k in range(3):
			GameProfile.shop_buy("honey", fd)
	_c9_check("shop: honey bag reaches the cap of 9", GameProfile.bag_count("honey") == 9,
		"bag=" + str(GameProfile.bag_count("honey")))
	err = String(GameProfile.shop_buy("honey", fake + 3.0 * 86400.0))
	_c9_check("shop: next-day buy at cap is bagfull", err == "bagfull", "err=" + err)
	GameProfile.data["stardust"] = 0
	GameProfile.save_profile()
	err = String(GameProfile.shop_buy("master-ball", fake + 4.0 * 86400.0))
	_c9_check("shop: empty purse is poor", err == "poor", "err=" + err)
	err = String(GameProfile.shop_buy("nope", fake))
	_c9_check("shop: unknown id rejected", err == "unknown", "err=" + err)
	# Persistence + sanitization.
	var f := FileAccess.open("user://GameProfile.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	_c9_check("shop: bag + shop day persisted to disk", int((parsed.get("bag", {}) as Dictionary).get("honey", 0)) == 9 and int((parsed.get("shop", {}) as Dictionary).get("day", 0)) == 6,
		"shop=" + str(parsed.get("shop", {})))
	GameProfile.data["shop"] = {"bogus": true}
	GameProfile.save_profile()
	# Cold-load simulation: load_profile() is _loaded-guarded,
	# so reset the guard to re-run the real sanitize path.
	GameProfile._loaded = false
	GameProfile.load_profile()
	_c9_check("shop: malformed shop state is sanitized on load", not GameProfile.data.has("shop"))
	# The real panel: six rows, buying through the actual button.
	GameProfile.data["shop"] = {"day": int(GameProfile.shop_day_number(GameProfile.shop_now())), "n": {}}
	GameProfile.add_stardust(500)
	GameProfile.save_profile()
	_world.call("_refresh_shop")
	_world.get("_shop_panel").visible = true
	var btns: Array = []
	for row in _world.get("_shop_list").get_children():
		for c in row.get_children():
			if c is Button:
				btns.append(c)
	_c9_check("shop: panel builds six buy buttons", btns.size() == 6, "n=" + str(btns.size()))
	_c9_check("shop: countdown names the UTC reset", String(_world.get("_shop_countdown").text).contains("UTC"))
	var bag0 := GameProfile.bag_count("rare-candy")
	var pw0 := int(_world.get("audio").call("count_of", "power"))
	if btns.size() == 6:
		(btns[0] as Button).pressed.emit()
		await _c16_pump(4)
		_c9_check("shop: panel buy moves the bag + plays power()", GameProfile.bag_count("rare-candy") == bag0 + 1 and int(_world.get("audio").call("count_of", "power")) > pw0,
			"bag=" + str(GameProfile.bag_count("rare-candy")))
	_world.get("_shop_panel").visible = false
	# Sound panel: the master slider drives the setting + bus.
	# Cycle 18: the panel is now the 6-section settings screen —
	# the four AUDIO sliders are collected by their setting_key
	# meta (the 界面/图形 sections carry their own sliders; the
	# assertion keeps its original strength on the audio set).
	_world.get("_sound_panel").visible = true
	_world.call("_settings_show_tab", "sound")
	var sliders: Array = []
	_c18_audio_sliders(_world.get("_sound_panel"), sliders)
	_c9_check("shop: sound panel has the bundle's four sliders", sliders.size() == 4, "n=" + str(sliders.size()))
	if sliders.size() == 4:
		(sliders[0] as HSlider).value = 0.25
		await _c16_pump(10)
		_c9_check("shop: master slider writes setting + bus", absf(float(GameProfile.setting("master")) - 0.25) < 0.001 and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.25) < 0.03,
			"set=" + str(GameProfile.setting("master")) + " lin=" + str(db_to_linear(AudioServer.get_bus_volume_db(0))))
		(sliders[0] as HSlider).value = 0.8
		await _c16_pump(10)
	_world.get("_sound_panel").visible = false
	# Restore the resident profile byte-for-byte in content.
	GameProfile.data = snap
	GameProfile.save_profile()
	_world.call("_apply_audio_settings")


# ------------------------------------------------------------------
# Cycle 18: the bag bring-in, end to end through the REAL path:
# shop_buy -> profile bag -> loadout toggles -> run start spend
# -> combat/run effects (bundle Ye table / applyBoosts @1444306 /
# spend-at-start @1580295 / Dn slots news Xe). The multiplier
# checks are RATIO checks against a no-boost baseline run, so
# passive/vitamin contributions cancel out.
# ------------------------------------------------------------------
func _c18_boost_phase() -> void:
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	_c9_cleanup_run()
	await _c9_frames(5)
	_c9_check("boost: lucky-egg desc is the bundle's +25% XP",
		String(GameProfile.SHOP_ITEMS[1]["desc"]).contains("25%"),
		String(GameProfile.SHOP_ITEMS[1]["desc"]))
	_c9_check("boost: amulet-coin desc is the bundle's +50% gold",
		String(GameProfile.SHOP_ITEMS[2]["desc"]).contains("50%"),
		String(GameProfile.SHOP_ITEMS[2]["desc"]))
	_c9_check("boost: master-ball desc is the sure first capture",
		String(GameProfile.SHOP_ITEMS[5]["desc"]).contains("必定成功"),
		String(GameProfile.SHOP_ITEMS[5]["desc"]))
	var anchor := GameProfile._shop_anchor_unix()
	var fake := anchor + 30.0 * 86400.0 + 3600.0  # a fresh fake day
	GameProfile.add_stardust(100000)
	# Cycle 21.1 fixture hermeticity (same resident-bag
	# family as the shop phase): the stocking checks assert
	# bag_count == 1 per item and the slots check asserts
	# the pre-buy width 2, so start from an empty bag and
	# an unbought Lab bag row; the snapshot restores both.
	GameProfile.data["bag"] = {}
	var boost_lab: Dictionary = (GameProfile.data.get("lab", {}) as Dictionary).duplicate()
	boost_lab.erase("bag")
	GameProfile.data["lab"] = boost_lab
	GameProfile.data["shop"] = {"day": int(GameProfile.shop_day_number(fake)), "n": {}}
	GameProfile.save_profile()
	for id in ["lucky-egg", "rare-candy", "master-ball", "honey", "shiny-stone", "amulet-coin"]:
		var err := String(GameProfile.shop_buy(id, fake))
		_c9_check("boost: shop_buy stocks the bag (" + id + ")",
			err == "" and GameProfile.bag_count(id) == 1, "err=" + err)
	_c9_check("boost: bag slots = 2 before the Lab row", GameProfile.bag_slots() == 2,
		"slots=" + str(GameProfile.bag_slots()))
	# Baseline run (no boosts) for the multiplier ratios.
	_world.start_game("bulbasaur")
	await _c9_frames(10)
	var p = _world.get("player")
	var xp0 := float(p.get("xp_mult"))
	var gold0 := float(p.get("gold_mult"))
	_c9_cleanup_run()
	await _c9_frames(5)
	# The loadout path: toggle egg + coin; a 3rd toggle hits the cap.
	_world.call("_open_loadout", "bulbasaur")
	await _c9_frames(5)
	_c9_check("boost: loadout opens from the menu",
		bool((_world.get("_loadout_panel") as Control).visible))
	_world.call("_loadout_toggle_boost", "lucky-egg")
	_world.call("_loadout_toggle_boost", "amulet-coin")
	_world.call("_loadout_toggle_boost", "rare-candy")
	_c9_check("boost: the cap refuses a 3rd boost",
		(_world.get("_ls_boosts") as Array).size() == 2,
		"n=" + str((_world.get("_ls_boosts") as Array).size()))
	_world.call("_loadout_start")
	await _c9_frames(10)
	p = _world.get("player")
	_c9_check("boost: run started through the loadout",
		String(_world.get("state")) == "playing" and p != null)
	_c9_check("boost: egg + coin spent at start",
		GameProfile.bag_count("lucky-egg") == 0 and GameProfile.bag_count("amulet-coin") == 0)
	_c9_check("boost: the refused candy stays in the bag",
		GameProfile.bag_count("rare-candy") == 1)
	_c9_check("boost: xp_mult = baseline x1.25 (lucky-egg)",
		absf(float(p.get("xp_mult")) - xp0 * 1.25) < 0.001,
		"xp=" + str(p.get("xp_mult")) + " base=" + str(xp0))
	_c9_check("boost: gold_mult = baseline x1.5 (amulet-coin)",
		absf(float(p.get("gold_mult")) - gold0 * 1.5) < 0.001,
		"gold=" + str(p.get("gold_mult")) + " base=" + str(gold0))
	_c9_cleanup_run()
	await _c9_frames(5)
	# Candy + master-ball + honey + shiny, started directly.
	_world.start_game("bulbasaur", ["rare-candy", "master-ball", "honey", "shiny-stone"])
	await _c9_frames(10)
	p = _world.get("player")
	_c9_check("boost: candy spent, run starts at level 3",
		GameProfile.bag_count("rare-candy") == 0 and int(p.get("level")) == 3,
		"lv=" + str(p.get("level")))
	await _c9_settle_drafts()
	_c9_check("boost: candy's 2 drafts settled through the real draft flow",
		int(p.get("pending_levels")) == 0 and int(p.get("level")) == 3,
		"pend=" + str(p.get("pending_levels")))
	_c9_check("boost: honey arms the extra alpha at t=240",
		absf(float(_world.get("_honey_at")) - 240.0) < 0.01,
		"at=" + str(_world.get("_honey_at")))
	var sat := float(_world.get("_shiny_at"))
	_c9_check("boost: shiny window rolled inside [40, 150]",
		sat >= 40.0 and sat <= 150.0, "at=" + str(sat))
	# Master ball: down an alpha and throw through the real path.
	_world.call("_spawn_alpha")
	await _c9_frames(30)
	var alpha: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if int(e.get("flag")) == 2:
			alpha = e
	_c9_check("boost: alpha spawned for the master-ball throw", alpha != null)
	if alpha != null:
		var att := 0
		while not bool(alpha.get("is_downed")) and att < 40:
			alpha.call("take_damage", 99999.0)
			att += 1
		_c9_check("boost: alpha downed", bool(alpha.get("is_downed")))
		_world.call("_throw_ball", alpha)
		await _c9_frames(5)
		_c9_check("boost: master ball makes the first capture sure",
			int(alpha.get("mode")) == 3, "mode=" + str(alpha.get("mode")))
		_c9_check("boost: master ball is consumed by the throw",
			not bool(_world.get("_master_ball")))
	# Honey event: push the zone clock past both schedules.
	# Cycle 20.1 (audit N15): the bundle runs ONE encounter
	# state machine — a shiny whose fire moment lands
	# during an active league encounter is LOST (spawnShiny
	# early-return). The jump to 241 also crosses
	# _league_spawn_at, whose auto-spawn would occupy the
	# encounter slot and eat the stone's shiny before the
	# assertions below. This segment asserts the stone /
	# honey schedules, so the league channel is closed
	# first — the state the game itself reaches when no
	# ready species remain.
	_world.set("_league_done", true)
	_world.set("elapsed", 241.0)
	await _c9_frames(20)
	_c9_check("boost: honey's extra alpha event fired + consumed",
		float(_world.get("_honey_at")) < 0.0)
	var se = _world.get("_shiny_e")
	_c9_check("boost: shiny encounter spawned on the league chassis",
		se != null and bool(se.get("shiny")) and int(se.get("mode")) == 2,
		"se=" + str(se))
	if se != null:
		var att2 := 0
		while not bool(se.get("is_weakened")) and att2 < 40:
			se.call("take_damage", 99999.0)
			att2 += 1
		var sp_key := String(se.get("species_id"))
		var caught := false
		for t in range(12):
			_world.call("_throw_ball", se)
			await _c9_frames(4)
			if (GameProfile.data.get("shinies", []) as Array).has(sp_key):
				caught = true
				break
			if is_instance_valid(se) and not bool(se.get("is_weakened")):
				var att3 := 0
				while is_instance_valid(se) and not bool(se.get("is_weakened")) and att3 < 40:
					se.call("take_damage", 99999.0)
					att3 += 1
		_c9_check("boost: shiny captured + recorded in the shiny dex", caught,
			"shinies=" + str(GameProfile.data.get("shinies", [])))
	_c9_cleanup_run()
	await _c9_frames(5)
	# The Lab 'bag' row's consumer: buying it widens the cap.
	GameProfile.add_stardust(100000)
	var lok := GameProfile.lab_buy("bag")
	_c9_check("boost: Lab bag row buys and slots become 3",
		lok and GameProfile.bag_slots() == 3, "ok=" + str(lok))
	GameProfile.data = snap
	GameProfile.save_profile()

# ------------------------------------------------------------------
# Cycle 18: UI round 2 — pause freeze, settings driving the
# adaptation layer, mini boss bars, goal card, party row, the
# big map + pins + fog, and the sectioned results screen fed
# by a REAL run + finish. All state changes go through the
# same functions the buttons/keys call.
# ------------------------------------------------------------------
func _c18_labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n)
	for c in n.get_children():
		_c18_labels(c, out)

func _c18_sliders_by_key(n: Node, key: String) -> HSlider:
	if n is HSlider and String((n as HSlider).get_meta("setting_key", "")) == key:
		return n as HSlider
	for c in n.get_children():
		var r := _c18_sliders_by_key(c, key)
		if r != null:
			return r
	return null

func _c18_ui2_phase() -> void:
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	_c9_cleanup_run()
	await _c9_frames(5)
	# Loadout from the menu: a locked tile shows its detail
	# but cannot become the hero.
	_world.call("_open_loadout", "bulbasaur")
	await _c9_frames(5)
	var grid = _world.get("_ls_grid")
	var locked_tile: Button = null
	for c in grid.get_children():
		if (c as Button).text.begins_with("锁"):
			locked_tile = c as Button
			break
	_c9_check("ui2: loadout grid has locked tiles", locked_tile != null)
	if locked_tile != null:
		locked_tile.pressed.emit()
		await _c9_frames(5)
		_c9_check("ui2: locked tile is view-only (hero unchanged)",
			String(_world.get("_ls_hero")) == "bulbasaur",
			"hero=" + String(_world.get("_ls_hero")))
		var labels: Array = []
		_c18_labels(_world.get("_ls_detail"), labels)
		var has_cond := false
		for l in labels:
			if (l as Label).text.contains("解锁条件"):
				has_cond = true
		_c9_check("ui2: locked detail shows the challenge progress", has_cond)
	_world.call("_loadout_start")
	await _c9_frames(15)
	var p = _world.get("player")
	_c9_check("ui2: run live after loadout start",
		String(_world.get("state")) == "playing" and p != null)
	# Pause: opens, freezes the world clock + the player, Esc resumes.
	var pos0: Vector3 = p.global_position
	_world.call("_open_pause")
	await _c9_frames(5)
	_c9_check("ui2: pause opens through the pause channel",
		String(_world.get("state")) == "pause" and not bool(_world.get("running"))
		and bool((_world.get("_pause_panel") as Control).visible))
	var el0 := float(_world.get("elapsed"))
	await _c9_frames(40)
	_c9_check("ui2: world clock frozen while paused",
		absf(float(_world.get("elapsed")) - el0) < 0.0001,
		"el=" + str(_world.get("elapsed")) + " el0=" + str(el0))
	_c9_check("ui2: player frozen while paused",
		p.global_position.distance_to(pos0) < 0.01,
		"d=" + str(p.global_position.distance_to(pos0)))
	_c9_key(KEY_ESCAPE, true)
	_c9_key(KEY_ESCAPE, false)
	# Cycle 19 pacing: the queued key event is dispatched
	# on an input/render frame, and _c9_frames counts
	# PHYSICS frames — in a long "all" process a handful of
	# physics frames can elapse with no input dispatch at
	# llvmpipe pacing (the same trap as the c19 scrim).
	# Wait for the asserted state; assertion unchanged.
	var esc_ok := await _c9_wait(func() -> bool:
		return String(_world.get("state")) == "playing" and bool(_world.get("running")), 900)
	_c9_check("ui2: Esc resumes the run", esc_ok,
		"state=" + String(_world.get("state")) + " pre=" + String(_world.get("_pre_pause_state"))
		+ " peek=" + String(_world.get("_pause_peek_return"))
		+ " pend=" + str(p.get("pending_levels")) + " lv=" + str(p.get("level"))
		+ " bars=" + str((_world.get("_mini_bars") as Array).size()))
	# Draft guard + two-step banish (audit §4.7/§4.1): the
	# modal swallows picks for 600 ms after opening; banish
	# targets on the first press and commits on the second.
	_world.call("_open_draft")
	_c9_check("ui2: draft guard is up right after opening",
		bool(_world.call("_draft_swallowed")))
	_world.call("_apply_draft_option", 0)
	_c9_check("ui2: a pick inside the guard window is swallowed",
		String(_world.get("state")) == "draft")
	var guard_lifted := await _c9_wait(func() -> bool:
		return not bool(_world.call("_draft_swallowed")), 3000)
	_c9_check("ui2: draft guard lifts", guard_lifted)
	var opts0 := (_world.get("_draft_options") as Array).size()
	var ban0 := int(_world.get("banishes_left"))
	_world.call("_draft_toggle_banish")
	_world.call("_banish_press", 0)
	_c9_check("ui2: first banish press only targets",
		int(_world.get("_draft_banish_target")) == 0
		and (_world.get("_draft_options") as Array).size() == opts0
		and int(_world.get("banishes_left")) == ban0,
		"target=" + str(_world.get("_draft_banish_target")))
	_world.call("_banish_press", 0)
	_c9_check("ui2: second press commits the banish",
		int(_world.get("banishes_left")) == ban0 - 1
		and ((_world.get("_draft_options") as Array).size() == opts0 - 1
			or String(_world.get("state")) != "draft"),
		"left=" + str(_world.get("banishes_left")))
	if String(_world.get("state")) == "draft":
		_world.call("_apply_draft_option", 0)
	# Cycle 19 pacing: same condition-wait as the Esc check
	# (the close lands through the modal's own tick).
	var draft_closed := await _c9_wait(func() -> bool:
		return String(_world.get("state")) == "playing", 900)
	_c9_check("ui2: draft closed back into the run", draft_closed,
		"state=" + String(_world.get("state")) + " pend=" + str(p.get("pending_levels")))
	# Settings: hudScale drives the scaler; hudOpacity the root.
	_world.call("_open_settings")
	_world.call("_settings_show_tab", "hud")
	await _c9_frames(5)
	var hs := _c18_sliders_by_key(_world.get("_sound_panel"), "hudScale")
	_c9_check("ui2: hudScale slider exists", hs != null)
	if hs != null:
		hs.value = 1.2
		await _c9_frames(5)
		var expect_s := float(_world.call("_kr")) * 1.2
		_c9_check("ui2: hudScale drives HUD node scale",
			absf((_world.get("_boss_card") as Control).scale.x - expect_s) < 0.02,
			"scale=" + str((_world.get("_boss_card") as Control).scale.x) + " want=" + str(expect_s))
	var ho := _c18_sliders_by_key(_world.get("_sound_panel"), "hudOpacity")
	if ho != null:
		ho.value = 0.5
		await _c9_frames(5)
		_c9_check("ui2: hudOpacity drives the HUD root alpha",
			absf((_world.get("_hud_root") as Control).modulate.a - 0.5) < 0.02,
			"a=" + str((_world.get("_hud_root") as Control).modulate.a))
		ho.value = 1.0
	if hs != null:
		hs.value = 1.0
		await _c9_frames(3)
	# touchScale drives the touch cluster sizes.
	_world.call("_settings_show_tab", "controls")
	await _c9_frames(3)
	var ts := _c18_sliders_by_key(_world.get("_sound_panel"), "touchScale")
	_c9_check("ui2: touchScale slider exists", ts != null)
	_world.call("debug_show_touch")
	await _c9_frames(5)
	if ts != null:
		ts.value = 1.5
		await _c9_frames(5)
		var tc = _world.get("touch_controls")
		_c9_check("ui2: touchScale resizes the interact button",
			absf(tc.debug_button_size("interact").x - 144.0) < 2.0,
			"size=" + str(tc.debug_button_size("interact")))
		ts.value = 1.0
		await _c9_frames(3)
	_world.call("_close_settings")
	_c9_check("ui2: cluster ult gauge exists and mirrors charge",
		(_world.get("touch_controls").get("ult_gauge")) != null)
	# Mini boss bar + goal card in the live run.
	_world.call("_spawn_alpha")
	# Cycle 19 pacing: the bar's visibility is driven by the
	# HUD tick (_process); 40 physics frames can contain no
	# tick on a heavy in-suite scene. Condition-wait.
	var bar_shown := await _c9_wait(func() -> bool:
		var bs: Array = _world.get("_mini_bars")
		return (bs.size() > 0 and bool((bs[0]["panel"] as Control).visible)
			and String((bs[0]["name"] as Label).text) != ""), 900)
	var bars: Array = _world.get("_mini_bars")
	_c9_check("ui2: mini boss bar shows the alpha", bar_shown,
		"name=" + (String((bars[0]["name"] as Label).text) if bars.size() > 0 else "<none>"))
	var expect_goal := ""
	for key in GameProfile.challenge_order():
		if not GameProfile.challenge_done(key) and not GameProfile.in_league(
				int(GameData.species(key).get("family", 0))):
			expect_goal = key
			break
	_c9_check("ui2: goal card tracks the next challenge",
		bool((_world.get("_goal_card") as Control).visible) == (expect_goal != "")
		and (expect_goal == "" or String(_world.get("_goal_species")) == expect_goal),
		"goal=" + String(_world.get("_goal_species")) + " want=" + expect_goal)
	# Party row: capture that alpha through the real throw loop.
	var alpha2: Node = bars[0]["key"]
	var ally_ok := false
	for t in range(20):
		if not is_instance_valid(alpha2):
			break
		var att := 0
		while is_instance_valid(alpha2) and not bool(alpha2.get("is_downed")) and att < 40:
			alpha2.call("take_damage", 99999.0)
			att += 1
		if not is_instance_valid(alpha2) or not bool(alpha2.get("is_downed")):
			break
		_world.call("_throw_ball", alpha2)
		await _c9_frames(4)
		if is_instance_valid(alpha2) and int(alpha2.get("mode")) == 3:
			ally_ok = true
			break
	_c9_check("ui2: alpha captured through real throws", ally_ok)
	_world.call("_refresh_hud")
	await _c9_frames(5)
	_c9_check("ui2: party row shows the new ally",
		(_world.get("_party_row") as Container).get_child_count() == 1,
		"n=" + str((_world.get("_party_row") as Container).get_child_count()))
	# Big map: fog marked, pin place/remove, close restores.
	_world.call("open_big_map")
	# Cycle 19 pacing: condition-wait (see the Esc check).
	var map_ok := await _c9_wait(func() -> bool:
		return String(_world.get("state")) == "bigmap" and not bool(_world.get("running")), 900)
	_c9_check("ui2: big map opens + pauses", map_ok,
		"state=" + String(_world.get("state")))
	var fog: PackedByteArray = _world.get("_fog")
	var visited := 0
	for v in fog:
		if v > 0:
			visited += 1
	_c9_check("ui2: fog has the player's ground marked", visited > 0, "cells=" + str(visited))
	_world.call("_bigmap_click", Vector2(295, 295))
	_c9_check("ui2: pin placed", (_world.get("_map_pins") as Array).size() == 1)
	_world.call("_bigmap_click", Vector2(295, 295))
	_c9_check("ui2: clicking the pin removes it", (_world.get("_map_pins") as Array).size() == 0)
	_world.call("_close_big_map")
	var map_closed := await _c9_wait(func() -> bool:
		return String(_world.get("state")) == "playing" and bool(_world.get("running")), 900)
	_c9_check("ui2: big map close restores the run", map_closed,
		"state=" + String(_world.get("state")))
	# Wallet failure state (store checklist): a failed
	# balance read must be VISIBLE with a retry affordance,
	# never a silent "…". Drive the real failure entry.
	var wal = _world.get("wallet")
	wal.set("address", "11111111111111111111111111111111")
	wal.call("_fail_balance", "网络错误")
	await _c9_frames(2)
	var wbal := _world.get("_wallet_balance") as Label
	var wretry := _world.get("_wallet_retry") as Button
	_c9_check("ui2: wallet failure is visible with retry",
		wretry != null and wretry.visible and wbal != null
		and wbal.text.contains("读取失败"),
		"bal=" + (wbal.text if wbal else "<none>"))
	wal.call("disconnect_wallet")
	await _c9_frames(2)
	_c9_check("ui2: wallet retry hides after disconnect",
		wretry != null and not wretry.visible)
	# Results: deal real move damage, then finish for real.
	_world.call("_spawn_enemy_at", "caterpie", _world.call("_ring_pos", 3.0, 4.0), 1.0)
	var got_dmg := await _c9_wait(func() -> bool:
		return not (_world.get("run_move_dmg") as Dictionary).is_empty(), 900)
	_c9_check("ui2: move damage attributed during play", got_dmg,
		"dmg=" + str(_world.get("run_move_dmg")))
	for att4 in range(60):
		if String(_world.get("state")) == "dead":
			break
		if _world.get("player") != null:
			(_world.get("player") as Node).call("take_damage", 99999.0)
		await _c9_frames(6)
	_c9_check("ui2: run finished (dead state)", String(_world.get("state")) == "dead",
		"state=" + String(_world.get("state")))
	await _c9_frames(5)
	_c9_check("ui2: results panel visible",
		bool((_world.get("_result_panel") as Control).visible))
	var rlabels: Array = []
	_c18_labels(_world.get("_result_box"), rlabels)
	var has_dust := false
	var has_moves := false
	for l in rlabels:
		if (l as Label).text.contains("萤尘 +"):
			has_dust = true
		if (l as Label).text == "招式伤害":
			has_moves = true
	_c9_check("ui2: results carry the payout chip + move section", has_dust and has_moves)
	_c9_check("ui2: one damage bar per attributed move",
		_c18_frac_count(_world.get("_result_box")) == mini((_world.get("run_move_dmg") as Dictionary).size(), 8),
		"bars=" + str(_c18_frac_count(_world.get("_result_box"))))
	_c9_cleanup_run()
	GameProfile.data = snap
	GameProfile.save_profile()

# ------------------------------------------------------------------
# Cycle 19 built the UI polish assertions below (token
# contrast, Lab MAX chip, fixed shop buttons, scrim +
# banner discipline, the Tab team-view peek, the icon move
# slot) and the archive group. Its SHINY half asserted the
# first mining pass's rules; cycle 20 rewrites that half to
# the TRUE bundle rules (DIFF §7 correction): the Be()
# perk ladder (no gold factor exists), the probability
# stage roll, the horde-pool pick, the zl hue rotation,
# HP x2.5, the 120/150 s flee clock and the +120/+50
# Stardust capture grants. Profile state is snapshotted
# and restored like ui2 does.

func _c19_labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append(n)
	for ch in n.get_children():
		_c19_labels(ch, out)

## Cycle 20: tally N production director rolls on the live
## world; returns [successes, windows_ok]. A success is a
## finite _shiny_at whose offset from the stage clock
## (frozen while this synchronous loop runs) sits inside
## [40, 420]; a failure must be exactly INF.
func _c20_roll_tally(w, n: int) -> Array:
	var t0 := float(w.get("elapsed"))
	var hits := 0
	var ok := true
	for i in range(n):
		w._roll_shiny_director()
		var at := float(w.get("_shiny_at"))
		if is_inf(at):
			continue
		hits += 1
		var off := at - t0
		if off < 39.0 or off > 421.0:
			ok = false
	return [hits, ok]

## Cycle 20: saturation-weighted circular mean-hue delta
## (in turns of the hue circle) from texture a to texture
## b, sampled on a stride over the shared pixel grid;
## -1 when either side has no saturated pixels to measure.
func _c20_tex_hue_delta(ta: Texture2D, tb: Texture2D) -> float:
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

## Cycle 21: item inventory keystone + zone 2/4 truths.
## Drives the REAL flows: add_item/recalc, the Gx roll +
## rollChestItem modals, altar charge/drain, ice-heal in
## take_damage, guardian summon under the modelled filter.
func _c21_phase() -> void:
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	var w = _world
	# --- data: the mined def set ---
	_c9_check("c21: items.json carries the 126 mined defs",
		GameData.item_keys().size() == 126)
	_c9_check("c21: secret-key / ice-heal defs match the bundle",
		GameData.item_rarity("secret-key") == 1 and GameData.item_max("secret-key") == 2
		and GameData.item_rarity("ice-heal") == 1 and GameData.item_max("ice-heal") == 3)
	var charms := 0
	for k in GameData.item_keys():
		if GameData.CHARM_TYPES.has(String(k)):
			charms += 1
	_c9_check("c21: 18 type charms in the def set", charms == 18, "n=" + str(charms))
	# --- zone truths (inventory #4) ---
	_c9_check("c21: zone 2 is Torre Lavanda with the mined trio",
		String(w.call("zone_def", 2)["tiles"]) == "graveyard" and String(w.call("zone_def", 2)["en"]) == "Lavender Tower"
		and String(w.call("zone_def", 2)["cn"]) == "雾钟塔"
		and (w.call("zone_def", 2)["guardians"] as Array) == ["gengar", "weezing", "hypno"])
	_c9_check("c21: zone 4 is Isla Volcán with the mined trio",
		String(w.call("zone_def", 4)["tiles"]) == "volcano" and String(w.call("zone_def", 4)["en"]) == "Volcano Island"
		and String(w.call("zone_def", 4)["cn"]) == "火山岛"
		and (w.call("zone_def", 4)["guardians"] as Array) == ["magmar", "rapidash", "charizard"])
	_c9_check("c21: archive rejects vitamin-era keys, accepts def keys",
		not GameProfile.archive_item("protein", true))
	# --- a live run for the item flows ---
	var ok := await _c9_start_run("bulbasaur")
	_c9_check("c21: run boots", ok)
	if not ok:
		GameProfile.data = snap
		GameProfile.save_profile()
		return
	var p = w.get("player")
	# guardian summon under the modelled-only filter
	w.set("zone", 2)
	w.set("state", "playing")
	w.set("boss_spawned", false)
	w.summon_guardian()
	var g2 = w.get("guardian")
	_c9_check("c21: zone 2 guardian is a modelled species (gengar)",
		g2 != null and String(g2.species_id) == "gengar",
		"got=" + (String(g2.species_id) if g2 else "none"))
	if g2:
		g2.queue_free()
	w.set("guardian", null)
	w.set("zone", 4)
	w.set("state", "playing")
	w.set("boss_spawned", false)
	w.summon_guardian()
	var g4 = w.get("guardian")
	_c9_check("c21: zone 4 guardian is modelled (magmar or charizard)",
		g4 != null and String(g4.species_id) in ["magmar", "charizard"],
		"got=" + (String(g4.species_id) if g4 else "none"))
	if g4:
		g4.queue_free()
	w.set("guardian", null)
	w.set("zone", 1)
	w.set("state", "playing")
	# --- add_item: caps, folds, specials ---
	_c9_check("c21: vit/move caps are the bundle base without items",
		p.vit_cap() == 10 and p.move_cap() == 8)
	var added := 0
	for i in range(12):
		if p.add_item("leftovers"):
			added += 1
	_c9_check("c21: add_item refuses past the def max (leftovers 10)",
		added == 10 and p.item_count("leftovers") == 10, "added=" + str(added))
	_c9_check("c21: maxed items leave the roll pool",
		not (w.call("_item_pool_keys") as Array).has("leftovers"))
	var phys0 := float(p.phys)
	p.add_item("choice-band")
	_c9_check("c21: item mods fold in recalc (choice-band physical x1.35)",
		absf(float(p.phys) - phys0 * 1.35) < 0.0001,
		"phys=" + str(p.phys))
	p.add_item("charcoal")
	_c9_check("c21: charm folds typeBoost fire 1.3",
		absf(float(p.type_boost.get("fire", 0.0)) - 1.3) < 0.0001,
		"tb=" + str(p.type_boost))
	p.add_item("tm-case")
	p.add_item("max-ether")
	_c9_check("c21: tm-case / max-ether raise the caps by 2",
		p.move_cap() == 10 and p.vit_cap() == 12)
	p.add_item("max-revive")
	_c9_check("c21: max-revive grants a revive charge", p.revives == 1)
	# Cycle 21.1 fixture hermeticity: _team_cap() = 2 + Lab
	# party + ss-ticket stacks, and the Lab party row is
	# RESIDENT-profile state (the VM resident owns it, the
	# NUC resident does not — the same check read 3->4 on
	# the VM and 2->3 on the NUC in the C21 closing runs).
	# Isolate the row for this one assertion (the c19
	# archive fixture's pattern), restore it right after.
	var party_lab_snap: Dictionary = (GameProfile.data.get("lab", {}) as Dictionary).duplicate()
	var lab_no_party: Dictionary = party_lab_snap.duplicate()
	lab_no_party.erase("party")
	GameProfile.data["lab"] = lab_no_party
	_c9_check("c21: ss-ticket raises the team cap",
		int(w.call("_team_cap")) == 2 and p.add_item("ss-ticket")
		and int(w.call("_team_cap")) == 3)
	GameProfile.data["lab"] = party_lab_snap
	var teeth0 := int(w.call("_slots_cost"))
	p.add_item("gold-teeth")
	_c9_check("c21: gold-teeth discounts the slots cost by 8%",
		absf(float(w.call("_slots_cost")) - round(float(teeth0) * 0.92)) <= 1.0,
		"cost=" + str(w.call("_slots_cost")) + " base=" + str(teeth0))
	var arm0 := float(p.armor)
	var hp0 := float(p.max_hp)
	p.add_item("eviolite")
	_c9_check("c21: eviolite on an evolvable species (armor x1.5, hp x1.25)",
		absf(float(p.armor) - arm0 * 1.5) < 0.001 and absf(float(p.max_hp) - round(hp0 * 1.25)) < 0.51,
		"armor=" + str(p.armor) + " hp=" + str(p.max_hp))
	var lvl0 := int(p.level)
	p.add_item("rare-candy")
	# The first level opens a draft; the +.3 s level lands
	# once play resumes (the world timer gates on play
	# states, like the bundle's), so settle while waiting.
	var lv_ok := false
	for i in range(60):
		await _c9_settle_drafts()
		if int(p.level) >= lvl0 + 2:
			lv_ok = true
			break
		await _c9_frames(15)
	_c9_check("c21: rare-candy grants two levels (one immediate, one at .3 s)", lv_ok,
		"lvl=" + str(p.level) + " from=" + str(lvl0))
	await _c9_settle_drafts()
	# --- Gx: floor >= 3 with no high rarity available -> null ---
	for k in GameData.item_keys():
		var key := String(k)
		if GameData.item_rarity(key) >= 3:
			while p.add_item(key):
				pass
	_c9_check("c21: Gx returns null at floor 3 when rarities 3-4 are maxed",
		String(w.call("_roll_item_key", 3)) == "")
	_c9_check("c21: Gx still rolls lower floors", String(w.call("_roll_item_key", 0)) != "")
	# --- rollChestItem modal: take path, then sell path ---
	_c211_dbg("c21 pre-rolls")
	var items0 := 0
	for v in p.items.values():
		items0 += int(v)
	w.call("_roll_chest_item", 0, 1)
	await _c9_frames(2)
	_c9_check("c21: single roll opens the item modal",
		bool(w.get("_choice_open")) and (w.get("_choice_opts_box") as Control).get_child_count() == 1)
	w.call("_choice_pick", 0)
	await _c9_frames(2)
	var items1 := 0
	for v in p.items.values():
		items1 += int(v)
	_c9_check("c21: taking the card adds exactly one item", items1 == items0 + 1,
		"items=" + str(items1) + " from=" + str(items0))
	var gold0 := float(w.get("gold"))
	w.call("_roll_chest_item", 0, 1)
	await _c9_frames(2)
	w.call("_choice_close", true)
	await _c9_frames(2)
	_c9_check("c21: selling from the modal pays gold", float(w.get("gold")) > gold0,
		"gold=" + str(w.get("gold")))
	# --- multi roll: three distinct cards, pick one ---
	_c211_dbg("c21 pre-triple")
	w.call("_roll_chest_item", 0, 3)
	await _c9_frames(2)
	_c211_dbg("c21 post-triple-call")
	_c9_check("c21: triple roll shows three cards",
		bool(w.get("_choice_open")) and (w.get("_choice_opts_box") as Control).get_child_count() == 3,
		"cards=" + str((w.get("_choice_opts_box") as Control).get_child_count()))
	w.call("_choice_pick", 1)
	await _c9_frames(2)
	var items2 := 0
	for v in p.items.values():
		items2 += int(v)
	_c9_check("c21: picking from the triple adds one item", items2 == items1 + 1)
	# --- secret-key altar math ---
	var a := {"tier": 0, "sealed": false, "woke": true, "used": false,
		"x": 0.0, "z": 0.0, "charge": 0.5, "out_t": 2.0, "warned": false,
		"wave_t": 0.0, "wave_n": 0, "comet": false}
	var far := Vector3(100, 0, 100)
	w.call("_altar_update", a, far, 1.0)
	var drain_plain := 0.5 - float(a["charge"])
	a["charge"] = 0.5
	a["out_t"] = 2.0
	p.add_item("secret-key")
	w.call("_altar_update", a, far, 1.0)
	var drain_key := 0.5 - float(a["charge"])
	_c9_check("c21: secret-key halves the altar drain",
		absf(drain_plain - 1.0 / 6.0) < 0.001 and absf(drain_key - 1.0 / 12.0) < 0.001,
		"plain=" + str(drain_plain) + " key=" + str(drain_key))
	a["charge"] = 0.5
	w.call("_altar_update", a, Vector3(0, 0, 0), 1.0)
	var gain_key := float(a["charge"]) - 0.5
	p.remove_item("secret-key")
	a["charge"] = 0.5
	w.call("_altar_update", a, Vector3(0, 0, 0), 1.0)
	var gain_plain := float(a["charge"]) - 0.5
	_c9_check("c21: secret-key speeds the altar charge by 1.3x",
		absf(gain_plain - 0.125) < 0.001 and absf(gain_key - 0.125 * 1.3) < 0.001,
		"plain=" + str(gain_plain) + " key=" + str(gain_key))
	# --- ice-heal shatter in take_damage ---
	var pp: Vector3 = p.global_position
	var e2 = w.call("_spawn_enemy_at", "rattata", pp + Vector3(4, 0, 0), 40.0)
	var e1 = w.call("_spawn_enemy_at", "rattata", pp + Vector3(5.5, 0, 0), 40.0)
	e2.apply_status("freeze", 30.0)
	var h0 := float(e2.hp)
	e2.take_damage(50.0, "normal")
	var drop_ctrl := h0 - float(e2.hp)
	_c9_check("c21: frozen control hit is x1.2", absf(drop_ctrl - 60.0) < 0.01,
		"drop=" + str(drop_ctrl))
	p.add_item("ice-heal")
	e2.status_t = 0.0
	e2.status_kind = ""
	e1.apply_status("freeze", 30.0)
	var h1 := float(e1.hp)
	e1.take_damage(50.0, "normal")
	var drop_ice := h1 - float(e1.hp)
	_c9_check("c21: ice-heal shatter is x1.2 x1.6 and clears the freeze",
		absf(drop_ice - 96.0) < 0.01 and String(e1.status_kind) == "",
		"drop=" + str(drop_ice) + " status=" + String(e1.status_kind))
	_c9_check("c21: the shatter splash freezes a neighbour",
		String(e2.status_kind) == "freeze" and float(e2.status_t) > 0.0,
		"status=" + String(e2.status_kind))
	e1.queue_free()
	e2.queue_free()
	# --- next-ball price (inventory #5): HUD + big-nugget ---
	w.call("_refresh_hud")
	_c9_check("c21: HUD next-ball price equals chestCost",
		(w.get("_ball_price_label") as Label).text == str(int(w.call("_chest_cost"))),
		"label=" + (w.get("_ball_price_label") as Label).text + " cost=" + str(w.call("_chest_cost")))
	var cost_plain := int(w.call("_chest_cost"))
	p.add_item("big-nugget")
	var cost_nug := int(w.call("_chest_cost"))
	_c9_check("c21: big-nugget cuts the ball price by 8%",
		absf(float(cost_nug) - round(float(cost_plain) * 0.92)) <= 1.0,
		"plain=" + str(cost_plain) + " nug=" + str(cost_nug))
	p.remove_item("big-nugget")
	w.set("gold", 0.0)
	_c9_check("c21: chest label shows the insufficient-funds state",
		String(w.call("_prop_label", {"kind": "chest", "used": false, "data": {}})).contains("金币不足"))
	w.set("gold", 100000.0)
	_c9_check("c21: chest label hides it when affordable",
		not String(w.call("_prop_label", {"kind": "chest", "used": false, "data": {}})).contains("金币不足"))
	# --- Meowth shop (inventory #3) ---
	_c9_check("c21: reroll cost at zero rerolls (0.5 x Qx0 x WC x teeth)",
		int(w.call("_shop_reroll_cost")) == int(round(0.5 * 80.0 * 0.92)),
		"cost=" + str(w.call("_shop_reroll_cost")))
	w.set("_shop_buys", [0, 0, 4])
	w.set("_chests_bought", 0)
	_c9_check("c21: shopHeat skips the free buys then applies $x[rarity]",
		absf(float(w.call("_shop_heat")) - 2.0) < 0.0001,
		"heat=" + str(w.call("_shop_heat")))
	_c9_check("c21: shop price = Qx x WC(2.2) x heat x teeth",
		int(w.call("_shop_price", "leftovers")) == int(round(130.0 * 2.0 * 0.92)),
		"price=" + str(w.call("_shop_price", "leftovers")))
	w.set("_shop_buys", [])
	await _c21_settle_modals(w)  # _open_shop captures its return state; it must be "playing"
	_c211_dbg("c21 pre-shop-open")
	w.call("_open_shop")
	await _c9_frames(2)
	_c9_check("c21: shop opens with four distinct stock entries",
		bool(w.get("_shop_open")) and String(w.get("state")) == "shop"
		and ((w.get("_shop") as Dictionary).get("stock", []) as Array).size() == 4,
		"stock=" + str(((w.get("_shop") as Dictionary).get("stock", []) as Array).size()))
	var stock0: Array = (w.get("_shop") as Dictionary).get("stock", [])
	var buy_key := String(stock0[0]["key"])
	var buy_price := int(stock0[0]["price"])
	var held0: int = p.item_count(buy_key)
	var gold_b := float(w.get("gold"))
	w.call("_shop_buy", 0)
	_c9_check("c21: buying deducts the price and grants the item",
		absf(float(w.get("gold")) - (gold_b - float(buy_price))) < 0.01
		and p.item_count(buy_key) == held0 + 1
		and bool(((w.get("_shop") as Dictionary).get("stock", [])[0] as Dictionary)["sold"]),
		"gold=" + str(w.get("gold")))
	var rr_cost := int(w.call("_shop_reroll_cost"))
	var gold_r := float(w.get("gold"))
	w.call("_shop_reroll")
	_c9_check("c21: reroll charges and restocks",
		absf(float(w.get("gold")) - (gold_r - float(rr_cost))) < 0.01
		and int(w.get("_shop_rerolls_run")) == 1
		and ((w.get("_shop") as Dictionary).get("stock", []) as Array).size() == 4)
	var left0: int = p.item_count("leftovers")
	var gold_s := float(w.get("gold"))
	w.call("_shop_sell", "leftovers")
	w.call("_shop_sell", "leftovers")
	_c9_check("c21: two-tap sell removes one stack at qC(rarity 1)",
		p.item_count("leftovers") == left0 - 1
		and absf(float(w.get("gold")) - (gold_s + float(w.call("_sell_value", 1)))) < 0.01,
		"gold=" + str(w.get("gold")))
	w.call("_shop_close")
	_c9_check("c21: shop close returns to play", String(w.get("state")) == "playing")
	print("C21DBG post-shop: running=", w.get("running"), " rt=", w.get("run_time"))
	_c211_dbg("c21 post-shop")
	# --- dowsing-machine populate (spare zone, then restore) ---
	# Earlier genuine random item rolls may already have granted this item.
	var dowsing_before: int = p.item_count("dowsing-machine")
	while p.item_count("dowsing-machine") > 0:
		p.remove_item("dowsing-machine")
	p.add_item("dowsing-machine")
	w.call("_build_interactables", 3)
	var st3: Dictionary = (w.get("_inter_state") as Dictionary).get(3, {})
	var fc := 0
	for pr in (st3.get("props", []) as Array):
		if String((pr as Dictionary)["kind"]) == "chest":
			fc += 1
	_c9_check("c21: dowsing adds an altar and two paid chests",
		(st3.get("altars", []) as Array).size() == 6 and fc == 16,
		"altars=" + str((st3.get("altars", []) as Array).size()) + " chest=" + str(fc))
	p.remove_item("dowsing-machine")
	for di in range(dowsing_before):
		p.add_item("dowsing-machine")
	w.call("_build_interactables", 3)
	# ---- boss brain (item 5): the phase never leaves zone 1,
	# whose trio is scyther/pinsir (signature kits) + nidoking
	# (no kit); summon_guardian shuffles the draw, so the
	# assertions are species-agnostic or kit-conditional.
	await _c21_settle_modals(w)  # summon_guardian's gate is state == "playing"
	print("C21DBG pre-boss: running=", w.get("running"), " rt=", w.get("run_time"),
		" state=", w.get("state"))
	w.call("summon_guardian")
	await _c21_wait(w, 1.2)
	var g3 = w.get("guardian")
	_c9_check("c21 boss: a zone-1 guardian is summoned", g3 != null and g3.is_inside_tree())
	_c9_check("c21 boss: the draw is a zone-1 trio species",
		g3 != null and g3.species_id in ["scyther", "pinsir", "nidoking"],
		"sp=" + (g3.species_id if g3 else "null"))
	_c9_check("c21 boss: no zone-1 species carries a db mech",
		String(w.get("_boss_mech")) == "", "mech=" + String(w.get("_boss_mech")))
	var g3_kit: bool = g3 != null and g3.species_id in ["scyther", "pinsir"]
	if g3 == null:
		await _c9_cleanup_run()
		GameProfile.data = snap
		GameProfile.save_profile()
		return
	# Keep the observation window combat-free: the guardian
	# chases, so park the player across the map — a dead
	# guardian announces nothing and cannot enrage.
	w.player.global_position = g3.global_position + Vector3(90, 0, 90)
	var saw_move := false
	var saw_cast := false
	for i in range(80):
		await _c21_wait(w, 0.25)
		if String(w.get("_boss_move_name")) != "":
			saw_move = true
		if not (w.get("_boss_pools") as Array).is_empty() or not (w.get("_hostiles") as Array).is_empty() \
				or not String(w.get("_boss_move_name")).is_empty():
			saw_cast = true
		if saw_move and saw_cast:
			break
	_c9_check("c21 boss: the cycle announces a move (say)", saw_move)
	print("C21DBG post-say: running=", w.get("running"), " rt=", w.get("run_time"),
		" state=", w.get("state"))
	g3.hp = g3.max_hp * 0.49
	await _c21_wait(w, 0.8)
	_c9_check("c21 boss: enrage fires below 50% HP", bool(w.get("_boss_enraged")))
	_c9_check("c21 boss: bar tag shows the rage state", "狂怒" in (w.get("_boss_tag_label") as Label).text)
	var tk_arr: Array = w.get("_boss_ticks")
	var tk_all_vis: bool = tk_arr.size() == 2
	var tk_any_vis := false
	for tk in tk_arr:
		tk_all_vis = tk_all_vis and (tk as Control).visible
		tk_any_vis = tk_any_vis or (tk as Control).visible
	_c9_check("c21 boss: phase ticks visible only for a kit boss",
		(g3_kit and tk_all_vis) or (not g3_kit and not tk_any_vis),
		"kit=" + str(g3_kit) + " ticks=" + str(tk_arr.size()) + " any_vis=" + str(tk_any_vis))
	# Kingler guard: frontal 0.15 / back 1.6.
	w.set("_boss_mech", "kingler")
	w.set("_boss_mech_data", {"guard_t": 5.0, "counter_cd": 99.0, "facing": Vector2(1, 0)})
	w.player.global_position = g3.global_position + Vector3(6, 0, 0)
	_c9_check("c21 boss: kingler guard blocks frontal hits (x0.15)", absf(w.call("boss_hit_mul", g3) - 0.15) < 0.001)
	w.player.global_position = g3.global_position + Vector3(-6, 0, 0)
	_c9_check("c21 boss: kingler guard exposes the back (x1.6)", absf(w.call("boss_hit_mul", g3) - 1.6) < 0.001)
	# Cloyster shell phases.
	w.set("_boss_mech", "cloyster")
	w.set("_boss_mech_data", {"open": false, "phase": 99.0})
	_c9_check("c21 boss: cloyster closed shell takes x0.1", absf(w.call("boss_hit_mul", g3) - 0.1) < 0.001)
	w.set("_boss_mech_data", {"open": true, "phase": 99.0})
	_c9_check("c21 boss: cloyster open takes x1.9", absf(w.call("boss_hit_mul", g3) - 1.9) < 0.001)
	w.set("_boss_mech", "")
	print("C21DBG pre-takeover: running=", w.get("running"), " rt=", w.get("run_time"),
		" state=", w.get("state"))
	# ---- shiny boss takeover (item 6) ----
	g3.call("_die_real")
	await _wait_sim(w, 0.6)
	# The kill queues levels and opens the draft (running =
	# false). Settle through the real pick path BEFORE any
	# state stomp — stomping state to "playing" over an open
	# draft leaves running false and freezes the world clock
	# for every later block (found cycle 21, passive starvation).
	await _c21_settle_modals(w)
	if w.get("_takeover_e") == null:
		w.set("state", "playing")  # summon_guardian's gate
		w.call("summon_guardian")
		await _wait_sim(w, 0.8)
		var g6 = w.get("guardian")
		if g6 != null:
			g6.shiny = true
			g6.call("_die_real")
		await _wait_sim(w, 0.6)
		await _c21_settle_modals(w)  # same modal hazard as above
	var tk = w.get("_takeover_e")
	_c9_check("c21 shiny: a defeated shiny guardian rises as a takeover target",
		tk != null and is_instance_valid(tk) and tk.is_weakened)
	if tk != null and is_instance_valid(tk):
		var sd0: int = GameProfile.stardust()
		w.player.global_position = tk.global_position + Vector3(1.5, 0, 0)
		w.call("_throw_ball", tk)
		await _wait_sim(w, 0.4)
		_c9_check("c21 shiny: the takeover throw is guaranteed (stardust paid)",
			GameProfile.stardust() > sd0 and w.get("_takeover_e") == null,
			"sd " + str(sd0) + "->" + str(GameProfile.stardust()))
	# Consume the portal deliberately at this block boundary.
	# Left live under the player's feet, its deferred zone
	# switch can fire mid-phase and wipe the field (in the
	# first live-world run it freed the ekans and both
	# tentacle targets). The remaining blocks are
	# zone-agnostic, so advancing here is safe.
	if w.get("portal_node") != null:
		w.call("_on_portal_entered")
		await _c21_wait(w, 1.5)
		await _c21_settle_modals(w)
	print("C21DBG post-takeover: state=", w.get("state"), " running=", w.get("running"),
		" choice=", w.get("_choice_open"), " rt=", w.get("run_time"))
	_c211_dbg("c21 post-takeover-x")
	print("C211DBG draftvis=", (w.get("_draft_panel") as Control).visible,
		" draftopts=", (w.get("_draft_options") as Array).size(),
		" pre_draft=", w.get("_pre_draft_state"),
		" shop_open=", w.get("_shop_open"),
		" portal_null=", w.get("portal_node") == null,
		" switch_pending=", w.get("_switch_pending"),
		" pausevis=", (w.get("_pause_panel") as Control).visible,
		" bigmapvis=", (w.get("_bigmap_panel") as Control).visible)
	# ---- stage events (item 6) ----
	await _c21_settle_modals(w)
	w.set("state", "playing")
	# Cycle 22: the event kind list grew to four with
	# the golden meowth (bundle truth) — the fixture's
	# unique-remainder premise names it done as well.
	w.set("_event_done", ["fog", "storm", "meowth"])
	w.set("_zone_t", 999.0)
	w.set("_event_try_t", 0.0)
	w.call("_event_tick", 0.016)
	_c9_check("c21 event: scheduler starts the remaining kind (eclipse)",
		String(w.get("_event_kind")) == "eclipse")
	_c9_check("c21 event: the eclipse look lands on the fog",
		(w.get("_env") as Environment).fog_light_color == Color(0.224, 0.184, 0.263))
	w.set("_event_left", 0.001)
	w.call("_event_tick", 0.05)
	_c9_check("c21 event: expiry restores the zone look",
		String(w.get("_event_kind")) == "" and (w.get("_env") as Environment).fog_light_color == (w.get("_zone_fog_base") as Color))
	print("C21DBG post-event: state=", w.get("state"), " running=", w.get("running"),
		" choice=", w.get("_choice_open"), " rt=", w.get("run_time"))
	# The takeover capture fields a boss-tier ally that hunts
	# anything within 26 u — in the first live-world run it
	# melted the ekans and every tick target before their
	# windows could run. Retire the in-run allies for the
	# remaining lab blocks (fixture teardown; ally behaviour
	# itself is covered by the capture phases).
	for ally_node in w.get_tree().get_nodes_in_group("allies"):
		(ally_node as Node).queue_free()
	await _c9_frames(2)
	# ---- ekans (item 7) ----
	_c9_check("c21 ekans: in SPECIES and the roster pool", ModelRig.SPECIES.has("ekans")
		and GameData.roster_species_keys().has("ekans"))
	# Cycle 21.1 fixture: at 40x (~1.1k HP) the item-loaded
	# player's ambient DPS melts the ekans before its async
	# rig fit lands (freed before the check on BOTH hosts'
	# closing standalones; the starters rig, where the
	# player is disarmed, fits it fine). Disarm the player
	# for the ekans + passive lab (the props/audio phases'
	# p.moves.clear() pattern — with no moves, the passive
	# ticks below are the ONLY damage source left, which
	# keeps their hp<max assertions tick-specific), ride
	# 4000x through the fit window, and retire the subject
	# right after the check so it cannot become the
	# passive blocks' nearest target.
	p.moves.clear()
	var ek = w.call("_spawn_enemy_at", "ekans", w.player.global_position + Vector3(6, 0, 0), 4000.0, false, 1.0)
	await _wait_sim(w, 1.5)
	_c9_check("c21 ekans: spawns and the geometry fit lands",
		ek != null and is_instance_valid(ek) and ek.rig != null and ek.rig.fitted)
	if ek != null and is_instance_valid(ek):
		ek.queue_free()
	await _c9_frames(2)
	print("C21DBG pre-passive: state=", w.get("state"), " running=", w.get("running"),
		" choice=", w.get("_choice_open"), " rt=", w.get("run_time"))
	# ---- passive backlog I (item 8) ----
	await _c21_settle_modals(w)  # ticks only run in the gated play states
	# Cycle 21.3 RIDER (pre-specified by Cycle 21.2): the
	# takeover segment can strand running=false (its
	# C21DBG trail froze run_time at 12.776 in-suite),
	# which starves EVERY tick passive below behind a
	# fixture-sequencing state, not a game fault. The
	# passive block's precondition is a live run —
	# re-assert it here, at the block entry only.
	if not bool(w.get("running")):
		print("C213DBG passive entry: running stranded false — re-asserting")
		w.set("running", true)
	var saved_passive: String = p.passive_id
	var saved_crit: float = p.crit_chance
	p.crit_chance = -1.0
	# tentacles: two nearest within 7 m take the F_ hit.
	# Cycle 21.1 fixture (all passive blocks below): the
	# subjects ride 40000x HP — at the C21 400x the
	# item-loaded player's ambient DPS killed every subject
	# inside its window on both hosts (closing standalones:
	# hp -1/-1, status=freed), so the ticks were never the
	# thing measured. Each subject is retired after its
	# own check so the next block's nearest/in-range pick
	# cannot land on a survivor.
	p.hp = p.max_hp  # the tick carrier must stay alive through every window
	p.passive_id = "tentacles"
	var t1 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + Vector3(2, 0, 0), 40000.0, false, 1.0)
	var t2 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + Vector3(-2, 0, 0), 40000.0, false, 1.0)
	await _c211_wait_disarmed(w, p, 4.5)
	print("C21DBG passive: state=", w.get("state"), " run_time=", w.get("run_time"),
		" pid=", p.passive_id, " pendlv=", p.get("pending_levels"),
		" php=", p.hp, "/", p.max_hp, " ptick=", str(w.get("_ptick_next")),
		" t1pos=", (t1.global_position if is_instance_valid(t1) else Vector3.ZERO),
		" t2pos=", (t2.global_position if is_instance_valid(t2) else Vector3.ZERO),
		" ppos=", p.global_position,
		" near7=", (w.call("_ptick_enemies_within", p.global_position, 7.0) as Array).size())
	_c9_check("c21 passive tentacles: both neighbours were whipped",
		is_instance_valid(t1) and is_instance_valid(t2)
		and t1.hp < t1.max_hp and t2.hp < t2.max_hp,
		"hp " + str(t1.hp if is_instance_valid(t1) else -1.0)
		+ "/" + str(t2.hp if is_instance_valid(t2) else -1.0))
	if is_instance_valid(t1):
		t1.queue_free()
	if is_instance_valid(t2):
		t2.queue_free()
	await _c9_frames(2)
	# arena-trap: damage inside 4.5 m (+ root procs at 80%).
	p.hp = p.max_hp
	p.passive_id = "arena-trap"
	var a1 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + Vector3(1, 0, 1), 40000.0, false, 1.0)
	await _c211_wait_disarmed(w, p, 4.5)
	print("C21DBG arena: state=", w.get("state"), " php=", p.hp,
		" a1pos=", (a1.global_position if is_instance_valid(a1) else Vector3.ZERO),
		" ppos=", p.global_position,
		" a1hp=", (a1.hp if is_instance_valid(a1) else -1.0),
		" pid=", p.passive_id, " rt=", w.get("run_time"), " ptick=", str(w.get("_ptick_next")),
		" running=", w.get("running"), " hitstop=", w.get("_hitstop_t"),
		" bless=", w.get("_blessing_open"), " pendlv=", p.get("pending_levels"),
		" choice=", w.get("_choice_open"))
	_c9_check("c21 passive arena-trap: the tremor damages",
		is_instance_valid(a1) and a1.hp < a1.max_hp)
	if is_instance_valid(a1):
		a1.queue_free()
	await _c9_frames(2)
	# serpent-glare: the enemy in front is paralyzed.
	p.hp = p.max_hp
	p.passive_id = "serpent-glare"
	var gfy: float = (p.rig.rotation.y if p.rig else 0.0)
	var gfdir := Vector3(sin(gfy), 0, cos(gfy))
	var s1 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + gfdir * 4.0, 40000.0, false, 1.0)
	# Cycle 21.2 (audit N7): instrumented wait — the
	# confirming-suite red (status="") could not tell
	# "subject out of the cone at the tick" from "tick
	# did not land"; GLAREDBG prints now record the
	# subject position, dot, and facing source per tick.
	await _c212_glare_wait(w, p, s1, 6.5)
	_c9_check("c21 passive serpent-glare: front enemy paralyzed",
		is_instance_valid(s1) and s1.status_kind == "paralyze",
		"status=" + (s1.status_kind if is_instance_valid(s1) else "freed"))
	if is_instance_valid(s1):
		s1.queue_free()
	await _c9_frames(2)
	# intimidate: charm lands and out_dmg drops 40%.
	p.hp = p.max_hp
	p.passive_id = "intimidate"
	var i1 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + Vector3(2, 0, 2), 40000.0, false, 1.0)
	await _c211_wait_disarmed(w, p, 5.5)
	_c9_check("c21 passive intimidate: charm cuts outgoing damage 40%",
		is_instance_valid(i1) and i1.status_kind == "charm"
		and absf(i1.out_dmg() - i1.dmg * 0.6) < 0.01,
		"status=" + (i1.status_kind if is_instance_valid(i1) else "freed"))
	if is_instance_valid(i1):
		i1.queue_free()
	await _c9_frames(2)
	# static: the nearest enemy takes the discharge.
	p.hp = p.max_hp
	p.passive_id = "static"
	var d1 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + Vector3(3, 0, 0), 40000.0, false, 1.0)
	# Cycle 21.1: static is the one single-target passive
	# (nearest enemy, 5 s period, ~1 tick per window) — an
	# ambient wild enemy standing nearer than the subject
	# absorbs the only discharge and the check flakes
	# (NUC standalone: tentacles/arena ticks landed while
	# static's subject stayed untouched). Isolate the
	# subject so "nearest" is deterministic; the assertion
	# is unchanged.
	for e in w.get_tree().get_nodes_in_group("enemies"):
		if e != d1 and is_instance_valid(e):
			(e as Node).queue_free()
	await _c9_frames(2)
	await _c211_wait_disarmed(w, p, 6.5)
	print("C22DBG static: pid=", p.passive_id, " pendlv=", p.get("pending_levels"),
		" ptick=", str(w.get("_ptick_next")), " state=", w.get("state"),
		" running=", w.get("running"), " rt=", w.get("run_time"))
	_c9_check("c21 passive static: discharge hits the nearest",
		is_instance_valid(d1) and d1.hp < d1.max_hp)
	if is_instance_valid(d1):
		d1.queue_free()
	await _c9_frames(2)
	# beacon: paralyzed targets take +25% from the carrier.
	var b1 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + Vector3(2, 0, 0), 4000.0, false, 1.0)
	var b2 = w.call("_spawn_enemy_at", "rattata", w.player.global_position + Vector3(-2, 0, 0), 4000.0, false, 1.0)
	p.passive_id = ""
	var dealt_a: float = w.call("combat_hit", b1, 100.0, "electric", "special", ["water"], {})
	p.passive_id = "beacon"
	b2.apply_status("paralyze", 5.0)
	var dealt_b: float = w.call("combat_hit", b2, 100.0, "electric", "special", ["water"], {})
	_c9_check("c21 passive beacon: paralyzed target takes +25%",
		dealt_a > 0.0 and absf(dealt_b / dealt_a - 1.25) < 0.02,
		"a=" + str(dealt_a) + " b=" + str(dealt_b))
	p.passive_id = saved_passive
	p.crit_chance = saved_crit
	await _c9_cleanup_run()
	GameProfile.data = snap
	GameProfile.save_profile()

func _c19_phase() -> void:
	var snap: Dictionary = JSON.parse_string(JSON.stringify(GameProfile.data))
	var w = _world
	# --- Cycle 20: the TRUE shiny ladder (DIFF §7 correction;
	# cycle 19's Be gold factor asserted an invented rule).
	# Rungs on n UNIQUE shiny species owned. ---
	GameProfile.data["shinies"] = []
	GameProfile.data["shiny_bond"] = false
	GameProfile.save_profile()
	_c9_check("c20: ladder is empty at zero shinies",
		GameProfile.shiny_luck_bonus() == 0.0 and GameProfile.shiny_xp_bonus() == 0.0
		and GameProfile.shiny_damage_bonus() == 0.0 and not GameProfile.has_shiny_charm()
		and GameProfile.shiny_rate() == 1.0 and GameProfile.shiny_flee_time() == 120.0
		and not GameProfile.shiny_bond_unlocked())
	GameProfile.record_shiny("c20fake01")
	_c9_check("c20: no rung at one shiny (the first rung is n=2)",
		GameProfile.shiny_luck_bonus() == 0.0 and GameProfile.shiny_xp_bonus() == 0.0)
	GameProfile.record_shiny("c20fake02")
	_c9_check("c20: n=2 grants +3 Luck, rate still 1",
		GameProfile.shiny_luck_bonus() == 3.0 and GameProfile.shiny_rate() == 1.0)
	GameProfile.record_shiny("c20fake03")
	GameProfile.record_shiny("c20fake04")
	_c9_check("c20: n=4 grants +4% XP (charm not yet)",
		absf(GameProfile.shiny_xp_bonus() - 0.04) < 0.0001 and not GameProfile.has_shiny_charm())
	GameProfile.record_shiny("c20fake05")
	GameProfile.record_shiny("c20fake06")
	_c9_check("c20: n=6 grants the Shiny Charm (rate 1.5, flee 150)",
		GameProfile.has_shiny_charm() and GameProfile.shiny_rate() == 1.5
		and GameProfile.shiny_flee_time() == 150.0)
	for i in range(7, 11):
		GameProfile.record_shiny("c20fake%02d" % i)
	_c9_check("c20: n=10 grants +3% damage",
		absf(GameProfile.shiny_damage_bonus() - 0.03) < 0.0001,
		"n=" + str(GameProfile.shiny_count()))
	for i in range(11, 16):
		GameProfile.record_shiny("c20fake%02d" % i)
	_c9_check("c20: n=15 records the shiny-ally (Bond 2) unlock",
		GameProfile.shiny_bond_unlocked() and GameProfile.shiny_count() == 15)
	# --- Cycle 20.1 (audit N2): counter_value("birds") on
	# a FLOAT-LOADED GameProfile. JSON numbers load as floats
	# and Array.has() is type-strict: the shipped .has(int)
	# read 0 for birds joined in prior sessions, so the
	# legendary challenge goal birds>=3 (roster) could
	# never complete. Seed the profile FILE with float
	# league entries, force a real disk load, assert the
	# counter, then put the phase's live dict back. ---
	var pre_birds: Dictionary = GameProfile.data
	var seed_f := FileAccess.open(GameProfile.PATH, FileAccess.WRITE)
	seed_f.store_string(JSON.stringify({"league": [144.0, 145.0, 146.0]}))
	seed_f.close()
	GameProfile._loaded = false
	GameProfile.data = {}
	GameProfile.load_profile()
	_c9_check("c20: birds counter counts float-loaded league entries (N2)",
		absf(GameProfile.counter_value("birds") - 3.0) < 0.001,
		"birds=" + str(GameProfile.counter_value("birds"))
		+ " league=" + str(GameProfile.data.get("league", [])))
	GameProfile.data = pre_birds
	GameProfile._loaded = true
	GameProfile.save_profile()
	# --- The rungs land in the REAL stat pipeline (the
	# labStats consumer = player.recalc): boot a run on an
	# empty dex, take baselines, then re-record rungs and
	# watch the player's stats move by exactly the rungs. ---
	GameProfile.data["shinies"] = []
	GameProfile.data["shiny_bond"] = false
	# Cycle 20.2 (re-audit N10 evidence gap): seed the Lab
	# dmg/xp bases ABOVE zero before the baselines below
	# are read. At Lab 0 both bases are exactly 1.0, where
	# the additive rung (+0.04 / +0.03 summed into the stat
	# block) and a x1.04 / x1.03 fold are numerically
	# IDENTICAL — the C20.1 logs therefore did not prove
	# the additive composition. At Lab 2 the compositions
	# differ by 0.004 (xp) and 0.0024 x o (dmg), outside
	# the 0.001 assertion tolerances. The phase snapshot
	# restores the resident Lab afterwards.
	var lab_seed: Dictionary = GameProfile.data.get("lab", {})
	lab_seed["dmg"] = maxi(int(lab_seed.get("dmg", 0)), 2)
	lab_seed["xp"] = maxi(int(lab_seed.get("xp", 0)), 2)
	GameProfile.data["lab"] = lab_seed
	GameProfile.save_profile()
	var ok := await _c9_start_run("bulbasaur")
	if not ok:
		_c9_check("c20: run boots", false)
		GameProfile.data = snap
		GameProfile.save_profile()
		return
	var p = w.get("player")
	p.invulnerable = true
	var luck0 := float(p.get("luck"))
	var xp0 := float(p.get("xp_mult"))
	var dmg0 := float(p.get("damage_mult"))
	GameProfile.record_shiny("c20fake01")
	GameProfile.record_shiny("c20fake02")
	p.recalc()
	_c9_check("c20: recalc applies the +3 Luck rung",
		absf(float(p.get("luck")) - (luck0 + 3.0)) < 0.001,
		"luck=" + str(p.get("luck")) + " base=" + str(luck0))
	GameProfile.record_shiny("c20fake03")
	GameProfile.record_shiny("c20fake04")
	p.recalc()
	# Cycle 20.1 (audit N10): labStats ADDS the rungs —
	# xp_mult grows by +0.04, NOT x1.04 (the x1.04 fold
	# would read xp0 * 1.04 here and fail).
	_c9_check("c20: recalc applies the +4% XP rung (additive, N10)",
		absf(float(p.get("xp_mult")) - (xp0 + 0.04)) < 0.001,
		"xp=" + str(p.get("xp_mult")) + " base=" + str(xp0))
	for i in range(5, 11):
		GameProfile.record_shiny("c20fake%02d" % i)
	p.recalc()
	# Additive damage: dmg = o * (1 + 0.04*lab + 0.03), so
	# the delta over the baseline dmg0 = o * (1 + 0.04*lab)
	# is 0.03 * dmg0 / (1 + 0.04*lab) — a x1.03 fold would
	# overshoot by 0.03 * 0.04 * lab * o and fail.
	var dmg_want := dmg0 + 0.03 * dmg0 / (1.0 + 0.04 * float(GameProfile.lab_level("dmg")))
	_c9_check("c20: recalc applies the +3% damage rung (additive, N10)",
		absf(float(p.get("damage_mult")) - dmg_want) < 0.001,
		"dmg=" + str(p.get("damage_mult")) + " base=" + str(dmg0) + " want=" + str(dmg_want))
	await _c9_settle_drafts()
	# --- The stage director is a PROBABILITY roll (bundle
	# @1048868): P = (0.08 + min(0.08, luck/1000)) x shinyRate.
	# Three configs separate the base rate, the luck term
	# and the charm multiplier; every window is asserted. ---
	GameProfile.data["shinies"] = []
	GameProfile.save_profile()
	p.recalc()
	var la := float(p.get("luck"))
	var pa := (0.08 + minf(0.08, la / 1000.0)) * 1.0
	var ra := _c20_roll_tally(w, 600)
	_c9_check("c20: director base roll matches P=(0.08+luck term)",
		absf(float(ra[0]) / 600.0 - pa) < 0.045 and bool(ra[1]),
		"hits=" + str(ra[0]) + " p=" + str(pa) + " luck=" + str(la))
	p.temp_mods.append({"stat": "luck", "add": 1000.0})
	p.recalc()
	var rb := _c20_roll_tally(w, 600)
	_c9_check("c20: luck term caps the roll at P=0.16",
		absf(float(rb[0]) / 600.0 - 0.16) < 0.055 and bool(rb[1]),
		"hits=" + str(rb[0]))
	for i in range(1, 7):
		GameProfile.record_shiny("c20fake%02d" % i)
	var rc := _c20_roll_tally(w, 600)
	_c9_check("c20: Shiny Charm multiplies the roll (P=0.24)",
		absf(float(rc[0]) / 600.0 - 0.24) < 0.06 and bool(rc[1]),
		"hits=" + str(rc[0]))
	p.temp_mods.clear()
	p.recalc()
	# --- The spawn pick (production function, synthetic
	# pools): the id-25 fallback, the not-yet-shiny family
	# preference, captureRate weights. ---
	GameProfile.data["shinies"] = []
	GameProfile.save_profile()
	_c9_check("c20: pick falls back to dex 25 on an empty pool",
		String(w._pick_shiny_species([])) == String(GameData.species_by_id(25).get("key", "")),
		"pick=" + String(w._pick_shiny_species([])))
	GameProfile.data["shinies"] = ["rattata"]
	GameProfile.save_profile()
	var pref_ok := true
	for i in range(12):
		if String(w._pick_shiny_species(["rattata", "pidgey"])) == "rattata":
			pref_ok = false
	_c9_check("c20: pick prefers families not yet shiny-caught", pref_ok)
	GameProfile.data["shinies"] = []
	GameProfile.save_profile()
	# Cycle 20.1 (audit N16): band tightened to the BUNDLE
	# weights — Cx(255) = 1.0, Cx(45) = 0.30, so caterpie
	# wins 76.9% (600 picks: mean 461.5, sigma 10.3). The
	# clamp cycle 20 shipped (maxf(0.15, cr/255): bulbasaur
	# 0.176, win rate 85.0%, mean 510) falls outside.
	var hi := 0
	for i in range(600):
		if String(w._pick_shiny_species(["caterpie", "bulbasaur"])) == "caterpie":
			hi += 1
	_c9_check("c20: pick is captureRate-weighted (255 vs 45)",
		hi >= 425 and hi <= 490, "hi=" + str(hi))
	# Cycle 20.1 (audit N16/N9): the weight FLOOR separates
	# the bundle's linear lift from the clamp directly.
	# Snorlax (cr 25, modelled) weighs Cx = 0.15 + 0.85 *
	# 25/255 = 0.2333 in the bundle but 0.15 under the
	# clamp, so caterpie (Cx = 1.0) wins 81.1% vs 87.0%
	# of picks — 1000 production picks put the two means
	# (811 vs 870) more than 4 sigma apart each way.
	var lo := 0
	for i in range(1000):
		if String(w._pick_shiny_species(["snorlax", "caterpie"])) == "caterpie":
			lo += 1
	_c9_check("c20: pick weight floor is the bundle linear lift (cr 25, N16)",
		lo >= 770 and lo <= 845, "lo=" + str(lo))
	# --- The encounter itself, on a stone-guaranteed
	# stage 1: the stone min()s even a FAILED roll into
	# [40,150] (min(∞, x) is finite) — asserted, not
	# assumed, since the roll above fails most stages. ---
	_c9_cleanup_run()
	await _c9_frames(5)
	GameProfile.data["bag"] = {"shiny-stone": 1}
	GameProfile.save_profile()
	_world.start_game("bulbasaur", ["shiny-stone"])
	var ok2 := await _c9_wait(func() -> bool:
		var pl = _world.get("player")
		return pl != null and pl.rig != null and pl.rig.fitted, 3600)
	_c9_check("c20: stone run boots", ok2)
	p = _world.get("player")
	p.invulnerable = true
	var sat := float(w.get("_shiny_at"))
	_c9_check("c20: stone guarantees a stage-1 shiny window",
		sat >= 40.0 and sat <= 150.0, "at=" + str(sat))
	# C24 source correction: idle/done is checked before shinyAt is
	# consumed. A live capture encounter defers a due shiny.
	var le = w._spawn_enemy_at("rattata", w._ring_pos(25.0, 45.0), w._spawn_mult() * 0.8)
	le.set("mode", 2)  # Enemy.MODE_LEAGUE
	w.set("_league_e", le)
	w.set("_league_escape", 150.0)
	w.set("elapsed", 200.0)
	await _c9_frames(12)
	_c9_check("c24: shiny fire waits while a league encounter is active",
		w.get("_shiny_e") == null and not bool(w.get("_shiny_spawned")) and float(w.get("_shiny_at")) == sat,
		"shiny_e=" + str(w.get("_shiny_e")) + " latched=" + str(w.get("_shiny_spawned")))
	# Remove the staged encounter and close the league
	# channel for the rest of this run (the state the game
	# itself reaches when no ready species remain), then
	# retain the due stone window for the encounter flow.
	if is_instance_valid(le):
		le.capture_remove()
	w.set("_league_e", null)
	w.set("_league_done", true)
	w.set("elapsed", 200.0)
	var spawned := await _c9_wait(func() -> bool:
		return w.get("_shiny_e") != null, 1800)
	_c9_check("c20: director fires the guaranteed shiny", spawned)
	var se = w.get("_shiny_e")
	if se != null:
		_c9_check("c20: shiny rides the league chassis, latched",
			bool(se.get("shiny")) and int(se.get("mode")) == 2
			and bool(w.get("_shiny_spawned")))
		_c9_check("c20: flee clock starts at 120 s (no charm)",
			float(w.get("_shiny_escape")) > 115.0 and float(w.get("_shiny_escape")) <= 120.0,
			"esc=" + str(w.get("_shiny_escape")))
		var sp_key := String(se.get("species_id"))
		_c9_check("c20: zone-1 pick is a captureRate-255 species (seed-math precondition)",
			int(GameData.species(sp_key).get("captureRate", 0)) == 255,
			"sp=" + sp_key)
		# Weaken it NOW (synchronous, before any frame can
		# decay the window): the weak window opens at 10 s.
		var att0 := 0
		while is_instance_valid(se) and not bool(se.get("is_weakened")) and att0 < 40:
			se.call("take_damage", 99999.0)
			att0 += 1
		_c9_check("c20: weak window opens at 10 s",
			is_instance_valid(se) and bool(se.get("is_weakened"))
			and float(se.get("weak_t")) > 9.9 and float(se.get("weak_t")) <= 10.0,
			"weak_t=" + str(se.get("weak_t")) if is_instance_valid(se) else "freed")
		# Comparison spawn of the same species through the
		# same pipeline (for the HP / scale / hue reads).
		var npos: Vector3 = p.global_position + Vector3(-4.0, 0, -4.0)
		npos.y = w.height_at(npos.x, npos.z)
		var norm = w._spawn_enemy_at(sp_key, npos, w._spawn_mult())
		await _c9_wait(func() -> bool:
			return se.rig != null and se.rig.fitted, 1800)
		await _c9_wait(func() -> bool:
			return norm != null and norm.rig != null and norm.rig.fitted, 1800)
		_c9_check("c20: shiny HP is x2.5 the pipeline spawn",
			absf(float(se.get("max_hp")) / maxf(float(norm.get("max_hp")), 0.001) - 2.5) < 0.08,
			"hp=" + str(se.get("max_hp")) + " norm=" + str(norm.get("max_hp")))
		var ratio := 0.0
		if norm != null and norm.rig != null and norm.rig.model != null \
				and se.rig != null and se.rig.model != null:
			ratio = se.rig.model.scale.x / maxf(norm.rig.model.scale.x, 0.0001)
		_c9_check("c20: shiny scale is 1.25x", absf(ratio - 1.25) < 0.02,
			"ratio=" + str(ratio))
		# The variant is the zl(id) hue rotation (main
		# @125961). The rigs carry their colour in TEXTURES
		# (the tint bases are the gray calibration colour).
		# Cycle 21.1 adjudication: the old form kept only the
		# LAST textured pair's circular-mean hue delta and
		# demanded |dh - zl| < 0.05 — but a Rodrigues rotation
		# does not shift every palette's mean hue by zl: for
		# narrow palettes the true delta deviates by ~0.1
		# (probe evidence, Test/out/c211_shinyprobe_ubantu.log:
		# pidgey Eye1 dh_sim=0.6181 at zl=0.7176, digit-exact
		# with the C21.1 in-suite failure reading, while its
		# Body1 reads 0.7209; sandshrew's Eye would fail the
		# same tolerance at 0.073 — whether the old check
		# passed was luck of the director's species draw and
		# material order). The assertion now verifies the
		# SAME property per pair against the operator's true
		# output: each shiny texture must be pixel-identical
		# to the production rotation of the normal texture,
		# each saturated tint base must equal the production
		# rotation of the normal base, and at least one
		# rotation must visibly move pixels (the compressed-
		# fallback path cannot pass vacuously). The operator
		# itself is pinned per-channel by the known-colour
		# probe check below. No emission may be added (the
		# gold wash is gone).
		var dex_id := int(GameData.species(sp_key).get("id", 0))
		var zl := ModelRig.shiny_hue_shift(dex_id)
		var sfm: Array = se.rig.get("_flash_mats")
		var nfm: Array = norm.rig.get("_flash_mats")
		var emis_ok := sfm.size() == nfm.size() and sfm.size() > 0
		var tint_compared := 0
		var tint_ok := true
		var tex_compared := 0
		var tex_ok := true
		var tex_moved := false
		var hue_dh := -1.0
		for i in range(mini(sfm.size(), nfm.size())):
			var sm := sfm[i]["mat"] as StandardMaterial3D
			var nm := nfm[i]["mat"] as StandardMaterial3D
			if bool(sm.emission_enabled) != bool(nm.emission_enabled):
				emis_ok = false
			var sb: Color = sfm[i]["base"]
			var nb: Color = nfm[i]["base"]
			if nb.s > 0.08:
				tint_compared += 1
				var eb: Color = ModelRig._hue_rotate_color(nb, zl)
				if absf(sb.r - eb.r) > 0.01 or absf(sb.g - eb.g) > 0.01 \
						or absf(sb.b - eb.b) > 0.01:
					tint_ok = false
			if nm.albedo_texture != null and sm.albedo_texture != null:
				tex_compared += 1
				var dh := _c20_tex_hue_delta(nm.albedo_texture, sm.albedo_texture)
				if dh >= 0.0:
					hue_dh = dh
				var exp_tex: Texture2D = ModelRig._hue_rotate_texture(nm.albedo_texture, zl)
				var got_img := sm.albedo_texture.get_image()
				var exp_img := exp_tex.get_image()
				if got_img == null or exp_img == null or got_img.get_size() != exp_img.get_size():
					tex_ok = false
				else:
					if got_img.is_compressed():
						got_img.decompress()
					if exp_img.is_compressed():
						exp_img.decompress()
					got_img.convert(Image.FORMAT_RGBA8)
					exp_img.convert(Image.FORMAT_RGBA8)
					if got_img.get_data() != exp_img.get_data():
						tex_ok = false
					var n_img := nm.albedo_texture.get_image()
					if n_img != null:
						if n_img.is_compressed():
							n_img.decompress()
						n_img.convert(Image.FORMAT_RGBA8)
						if exp_img.get_data() != n_img.get_data():
							tex_moved = true
		_c9_check("c20: shiny variant is the zl hue rotation (texture + tint)",
			tex_compared > 0 and tex_ok and tex_moved and tint_ok,
			"zl=" + str(zl) + " dh=" + str(hue_dh) + " tex=" + str(tex_compared) + " tint=" + str(tint_compared))
		_c9_check("c20: shiny adds no gold emission", emis_ok)
		# Cycle 20.1 (C20 audit, claim 5): the mean-hue check
		# above CANNOT distinguish the bundle's hueShift
		# operator (Rodrigues rotation about the equal-weight
		# gray axis, main @114320) from the CSS luminance
		# matrix — both move the mean hue by ~zl. This probe
		# pushes KNOWN colours through the production texture
		# path and compares per-channel against the Rodrigues
		# formula recomputed here from the GLSL: for pure red
		# at this zl the two operators differ by >0.08 in one
		# channel, far outside the 0.03 byte tolerance, so a
		# CSS-matrix build FAILS this check.
		var probe_img := Image.create(3, 1, false, Image.FORMAT_RGBA8)
		probe_img.set_pixel(0, 0, Color(1, 0, 0))
		probe_img.set_pixel(1, 0, Color(0, 1, 0))
		probe_img.set_pixel(2, 0, Color(0.25, 0.5, 0.75))
		var rot_tex := ModelRig._hue_rotate_texture(
			ImageTexture.create_from_image(probe_img), zl)
		var rot_img := rot_tex.get_image()
		rot_img.convert(Image.FORMAT_RGBA8)
		var hang := zl * TAU
		var hca := cos(hang)
		var hsa := sin(hang)
		var hq := 0.5773502691896258
		var kax := Vector3(hq, hq, hq)
		var op_ok := true
		var op_detail := ""
		for x in range(3):
			var src := probe_img.get_pixel(x, 0)
			var v := Vector3(src.r, src.g, src.b)
			var rot := v * hca + kax.cross(v) * hsa + kax * kax.dot(v) * (1.0 - hca)
			var got := rot_img.get_pixel(x, 0)
			op_detail += " [" + str(got.r) + "," + str(got.g) + "," + str(got.b) + "]"
			if absf(got.r - clampf(rot.x, 0.0, 1.0)) > 0.03 \
					or absf(got.g - clampf(rot.y, 0.0, 1.0)) > 0.03 \
					or absf(got.b - clampf(rot.z, 0.0, 1.0)) > 0.03:
				op_ok = false
		_c9_check("c20: hue operator is the bundle hueShift (Rodrigues), not the CSS matrix",
			op_ok, "zl=" + str(zl) + " px=" + op_detail)
		if norm != null:
			norm.queue_free()
		# Throw odds on the shiny (the league formula):
		# chance0 = 0.55 + 255/255 x 0.35 = 0.90 for a pool
		# species. A seed-hunted first randf >= 0.90 forces a
		# REAL failed throw through the production function
		# (the world _rng is re-seeded; nothing else draws
		# from it inside the synchronous throw).
		var probe := RandomNumberGenerator.new()
		var seed_fail := 0
		var seed_sure := 0
		for s in range(1, 200000):
			probe.seed = s
			var r := probe.randf()
			if seed_fail == 0 and r >= 0.90:
				seed_fail = s
			if seed_sure == 0 and r >= 0.985:
				seed_sure = s
			if seed_fail != 0 and seed_sure != 0:
				break
		var dust0 := GameProfile.stardust()
		# League state BEFORE the capture, normalised to
		# ints: JSON loads numbers as floats and Array.has()
		# is type-strict, so a raw has(family) read is blind
		# on a loaded profile (the resident league already
		# holds family 16 — a naive check passes vacuously).
		# join_league's three write channels are all watched:
		# the league array (guarded by in_league), the
		# captured dict and the captures counter (unguarded).
		var league_before: Array = []
		for x in (GameProfile.data.get("league", []) as Array):
			league_before.append(int(x))
		var captures_before := GameProfile.counter_value("captures")
		var captured_keys_before: Array = (GameProfile.data.get("captured", {}) as Dictionary).keys()
		captured_keys_before.sort()
		w._rng.seed = seed_fail
		w._throw_ball(se)
		_c9_check("c20: a failed throw lands on the shiny (seeded roll)",
			is_instance_valid(se) and int(se.get("capture_attempts")) == 1
			and w.get("_shiny_e") == se,
			"att=" + str(se.get("capture_attempts")) if is_instance_valid(se) else "freed")
		_c9_check("c20: break-out re-weakens with a 6 s window",
			is_instance_valid(se) and bool(se.get("is_weakened"))
			and absf(float(se.get("weak_t")) - 6.0) < 0.05,
			"weak_t=" + str(se.get("weak_t")) if is_instance_valid(se) else "freed")
		# Second throw: attempts=1 makes chance 1.10 >= 1, so
		# a seed-hunted randf of 0.985 (past the 0.97 cap) can
		# only succeed through the sure-capture clause.
		w._rng.seed = seed_sure
		w._throw_ball(se)
		_c9_check("c20: second throw is a sure capture (chance >= 1 clause)",
			w.get("_shiny_e") == null)
		_c9_check("c20: shiny capture grants +120 Stardust (new species)",
			GameProfile.stardust() - dust0 == 120,
			"delta=" + str(GameProfile.stardust() - dust0))
		_c9_check("c20: shiny captured + recorded in the shiny dex",
			(GameProfile.data.get("shinies", []) as Array).has(sp_key),
			"shinies=" + str(GameProfile.data.get("shinies", [])))
		var league_after: Array = []
		for x in (GameProfile.data.get("league", []) as Array):
			league_after.append(int(x))
		var captured_keys_after: Array = (GameProfile.data.get("captured", {}) as Dictionary).keys()
		captured_keys_after.sort()
		_c9_check("c20: shiny capture does NOT join the league",
			league_after == league_before
			and GameProfile.counter_value("captures") == captures_before
			and captured_keys_after == captured_keys_before,
			"league=" + str(league_after) + " captures=" + str(GameProfile.counter_value("captures")))
		# Weak-window expiry: a fresh shiny left weakened
		# recovers to 40% HP and roams when the window ends;
		# then the escape clock (shortened via the accepted
		# clock-set idiom) flees it through the real tick.
		w._spawn_shiny()
		var se2 = w.get("_shiny_e")
		_c9_check("c20: second shiny spawns for the recovery check", se2 != null)
		if se2 != null:
			var att := 0
			while is_instance_valid(se2) and not bool(se2.get("is_weakened")) and att < 40:
				se2.call("take_damage", 99999.0)
				att += 1
			var full2 := float(se2.get("max_hp"))
			var recovered := false
			for i in range(1500):
				if String(w.get("state")) == "draft":
					w._apply_draft_option(0)
				await _c9_frames(1)
				if not is_instance_valid(se2) or not bool(se2.get("is_weakened")):
					recovered = is_instance_valid(se2)
					break
			_c9_check("c20: weak window expires on its own", recovered)
			if is_instance_valid(se2):
				_c9_check("c20: expiry recovers the shiny to 40% HP",
					absf(float(se2.get("hp")) - full2 * 0.4) < 1.5,
					"hp=" + str(se2.get("hp")) + " max=" + str(full2))
				w.set("_shiny_escape", 0.05)
				var fled := await _c9_wait(func() -> bool:
					return w.get("_shiny_e") == null, 900)
				_c9_check("c20: escape clock flees the shiny", fled)
		# Repeat capture grant: fill the shiny dex with
		# every modelled species, so ANY further shiny is a
		# repeat (and the Charm is on: flee clock 150 s).
		var all_keys: Array = []
		for k in GameData.roster_species_keys():
			all_keys.append(String(k))
		GameProfile.data["shinies"] = all_keys
		GameProfile.save_profile()
		w._spawn_shiny()
		var se3 = w.get("_shiny_e")
		_c9_check("c20: third shiny spawns for the repeat check", se3 != null)
		if se3 != null:
			_c9_check("c20: flee clock is 150 s with the Shiny Charm",
				absf(float(w.get("_shiny_escape")) - 150.0) < 0.01,
				"esc=" + str(w.get("_shiny_escape")))
			var att3 := 0
			while is_instance_valid(se3) and not bool(se3.get("is_weakened")) and att3 < 40:
				se3.call("take_damage", 99999.0)
				att3 += 1
			var dust1 := GameProfile.stardust()
			var n_before := GameProfile.shiny_count()
			for t in range(12):
				if not is_instance_valid(se3) or w.get("_shiny_e") != se3:
					break
				w.call("_throw_ball", se3)
				await _c9_frames(4)
				if not is_instance_valid(se3) or w.get("_shiny_e") != se3:
					break
				if not bool(se3.get("is_weakened")):
					var att4 := 0
					while is_instance_valid(se3) and not bool(se3.get("is_weakened")) and att4 < 40:
						se3.call("take_damage", 99999.0)
						att4 += 1
			# C24 captured shinies now remain alive as allies. Settle the
			# explicit swap rather than repeatedly throwing at a captured node.
			if bool(w.get("_choice_open")) and w.get("_pending_shiny_ally") == se3:
				w._choice_pick(0)
			_c9_check("c20: repeat capture grants +50 Stardust, dex unchanged",
				GameProfile.stardust() - dust1 == 50 and GameProfile.shiny_count() == n_before,
				"delta=" + str(GameProfile.stardust() - dust1) + " n=" + str(GameProfile.shiny_count()))
	# --- Guardian coins: plain wB, NO shiny factor. The
	# shiny dex is FULL here — if any Be-style gold factor
	# still fed wB, the killing blow would overpay. ---
	w.summon_guardian()
	var g = w.get("guardian")
	var gok := await _c9_wait(func() -> bool:
		return g != null and g.rig != null and g.rig.fitted, 3600)
	if gok:
		var gf := 0
		var gold_blow := 0.0
		while g.hp > 0.0 and gf < 7200:
			# Killing-blow window (see the guardian phase):
			# ambient wild-kill coins stay outside it.
			var pre_gold := _c23_pickup_value(w, 1)
			g.take_damage(g.max_hp * 0.2, "")
			if g.hp <= 0.0:
				gold_blow = _c23_pickup_value(w, 1) - pre_gold
			await _c9_frames(1)
			if String(w.get("state")) == "draft":
				w._apply_draft_option(0)
			gf += 1
		var want := 20 * int(ceil(5.0 * 1.0 * p.gold_mult))
		_c9_check("c20: guardian coin entities pay plain wB (no shiny factor)",
			absf(gold_blow - float(want)) < 0.01,
			"blow_delta=" + str(gold_blow) + " want=" + str(want))
		await _c9_settle_drafts()
	else:
		_c9_check("c20: guardian summons for the coin check", false)
	# --- UI polish assertions ---
	_c9_check("c19: rarity r0 no longer collides with water",
		UiTheme.rarity_color(0) != UiTheme.type_color("water"))
	_c9_check("c19: chip text flips to ink on light faces only",
		UiTheme.readable_fg(UiTheme.type_color("normal")) == UiTheme.INK_SOFT
		and UiTheme.readable_fg(UiTheme.type_color("dragon")) == UiTheme.WHITE)
	_c9_check("c19: move slot shows the first move's type icon",
		String((w.get("_move_slot_icon") as UiIcon).icon)
			== String(w.call("_type_icon", String(GameData.move(String(p.moves[0]["key"])).get("type", "")))),
		"icon=" + String((w.get("_move_slot_icon") as UiIcon).icon))
	# Lab MAX chip (real buy to max through the Lab API).
	GameProfile.add_stardust(100000)
	GameProfile.lab_buy("bag")
	w.call("_refresh_lab")
	var lab_labels: Array = []
	_c19_labels(w.get("_lab_list"), lab_labels)
	var has_max := false
	for l in lab_labels:
		if (l as Label).text == "已满":
			has_max = true
	_c9_check("c19: MAXed lab row shows the 已满 chip", has_max)
	# Shop buttons: one fixed width. (In an "all" run the
	# shop phase already refreshed this list: rows from the
	# previous refresh are queue_free'd but still in the
	# tree until frame end — count LIVE buttons only.)
	w.call("_refresh_shop")
	var widths_ok := true
	var n_btns := 0
	var stack: Array = [w.get("_shop_list")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_queued_for_deletion():
			continue
		if n is Button:
			n_btns += 1
			if absf((n as Button).custom_minimum_size.x - 148.0) > 0.5:
				widths_ok = false
		for ch in n.get_children():
			stack.append(ch)
	_c9_check("c19: shop buy buttons share one width", widths_ok and n_btns == 6,
		"n=" + str(n_btns))
	# --- Archive (cycle 19; the second mining pass reversed
	# the dead-code read — a live player feature, built). ---
	# Fixture determinism (the phase snapshot restores all
	# of this at the end): archive row unbought, no shelved
	# items, no presets — whatever the resident profile had.
	var lab_fx: Dictionary = (GameProfile.data.get("lab", {}) as Dictionary).duplicate()
	lab_fx.erase("archive")
	GameProfile.data["lab"] = lab_fx
	GameProfile.data["items_off"] = []
	GameProfile.data["archive_presets"] = []
	GameProfile.data["archive_preset_active"] = -1
	GameProfile.save_profile()
	# Cycle 21: the archive domain is the item-def set —
	# these checks moved from vitamin keys to def keys.
	_c9_check("c19: archive locked at lab level 0",
		GameProfile.archive_capacity() == 0
		and not GameProfile.archive_item("leftovers", true))
	_c9_check("c19: archive lab row buys to capacity 5",
		GameProfile.lab_buy("archive") and GameProfile.archive_capacity() == 5)
	_c9_check("c19: archive + unarchive round-trip",
		GameProfile.archive_item("leftovers", true) and GameProfile.is_archived("leftovers")
		and not GameProfile.item_in_pool("leftovers")
		and GameProfile.archive_item("leftovers", false) and GameProfile.item_in_pool("leftovers"))
	for k in ["leftovers", "scope-lens", "kings-rock", "metal-coat", "charcoal"]:
		GameProfile.archive_item(String(k), true)
	_c9_check("c19: archive refuses past capacity",
		not GameProfile.archive_item("amulet-coin", true)
		and GameProfile.archived_items().size() == 5)
	var pool: Array = w.call("_item_pool_keys")
	var maxed := 0
	var hp_now = w.get("player")
	if hp_now:
		for dk in GameData.item_keys():
			if int(hp_now.call("item_count", String(dk))) >= GameData.item_max(String(dk)):
				maxed += 1
	_c9_check("c19: chest pool excludes the archived five",
		pool.size() == 126 - 5 - maxed and not pool.has("leftovers") and pool.has("amulet-coin"),
		"pool=" + str(pool.size()) + " maxed=" + str(maxed))
	_c9_check("c19: preset saves the current archive",
		GameProfile.archive_preset_save("c19预设")
		and GameProfile.archive_presets().size() == 1)
	for k in GameProfile.archived_items():
		GameProfile.archive_item(String(k), false)
	var missed := GameProfile.archive_preset_apply(0)
	_c9_check("c19: preset apply restores the archived set",
		missed == 0 and GameProfile.archived_items().size() == 5
		and GameProfile.archive_preset_active() == 0,
		"missed=" + str(missed))
	w.call("_lab_set_mode", "items")
	var ilabels: Array = []
	_c19_labels(w.get("_lab_items_list"), ilabels)
	var has_counter := false
	for l in ilabels:
		if (l as Label).text.begins_with("档案 5/5"):
			has_counter = true
	_c9_check("c19: lab items tab shows the 档案 5/5 counter", has_counter)
	w.call("_lab_set_mode", "upgrades")
	# Scrim + banner discipline around a real draft.
	# Cycle 19 pacing note: the scrim/banner alphas are
	# driven from the world's _process (render frames),
	# while _c9_frames counts PHYSICS frames — at llvmpipe
	# pacing several physics frames fit inside one render
	# frame, so these three checks WAIT FOR THE CONDITION
	# instead of counting frames. Assertions unchanged.
	# C23 pickup/supply rewards can leave a real chest choice open.
	await _c21_settle_modals(w)
	w.call("_open_draft")
	var scrim_up := await _c9_wait(func() -> bool:
		return bool((w.get("_modal_scrim") as Control).visible), 900)
	_c9_check("c19: scrim up while a modal is open", scrim_up,
		"state=" + String(w.get("state")) + " draft_vis="
		+ str(bool((w.get("_draft_panel") as Control).visible))
		+ " any_modal=" + str(bool(w.call("_any_modal_open"))))
	w.call("show_banner", "c19 banner probe", 5.0)
	var suppressed := await _c9_wait(func() -> bool:
		return (absf((w.get("_banner") as Label).modulate.a) < 0.01
			and absf((w.get("_banner_back") as Control).modulate.a) < 0.01), 900)
	_c9_check("c19: banner suppressed behind the modal", suppressed)
	# Tab team-view peek: pause over the draft, back to it.
	w.call("_open_team_view")
	await _c9_frames(3)
	_c9_check("c19: team view peeks over the draft",
		String(w.get("state")) == "pause"
		and String(w.get("_pause_peek_return")) == "draft"
		and not bool((w.get("_draft_panel") as Control).visible))
	w.call("_close_pause")
	await _c9_frames(3)
	_c9_check("c19: closing the peek returns to the draft",
		String(w.get("state")) == "draft"
		and bool((w.get("_draft_panel") as Control).visible)
		and not bool(w.get("running")))
	# Settle ALL pending drafts (a long run chains level-ups;
	# one pick is not necessarily the last draft).
	await _c9_settle_drafts()
	# Cycle 21.1: in a full-suite run the ambient field can
	# re-level the player DURING the wait below (an ally or
	# auto-fire kill lands XP, a fresh draft opens, and the
	# banner is then suppressed behind that modal until its
	# 5 s timer burns out — the C21 closing run's state=
	# draft / banner_t=-0.05). Settle-and-reshow until the
	# banner is actually up with no modal owning the
	# screen. NOTE the play state here can legitimately be
	# "portal": this phase opened its draft directly over
	# the state the live run was in, and _close_draft
	# returns there — banners show in portal state too.
	# Cycle 21.1 adjudication (the NUC suite2 failure,
	# state=portal / banner_t=4.34): the old wait's first
	# poll ran synchronously right after show_banner and
	# read the alpha show_banner ITSELF had just forced to
	# 1.0 — a vacuous sample, taken before the world's
	# _process could re-assert the modal-suppression snap;
	# the check then hinged on the scrim bit alone, and
	# the nearly-full timer (4.34 of 5.0) is the fingerprint
	# of that instant exit. The wait below samples a STEADY
	# state: at least 2 process frames after show_banner
	# (so the alphas read are the ones _process asserted),
	# with ALL conjuncts in one sample — banner + backing
	# at alpha 1, no modal open, scrim hidden. The probe
	# line names any modal still owning the screen. The
	# assertion itself (banner genuinely visible in a play
	# state, no modal) is the original one, unchanged.
	var modal_names := func() -> String:
		var names: Array = []
		for pv in [["draft", "_draft_panel"], ["blessing", "_blessing_panel"],
				["choice", "_choice_panel"], ["pause", "_pause_panel"],
				["bigmap", "_bigmap_panel"], ["result", "_result_panel"],
				["lab", "_lab_panel"], ["shop", "_shop_panel"],
				["sound", "_sound_panel"], ["wallet", "_wallet_panel"],
				["unlock", "_unlock_panel"], ["loadout", "_loadout_panel"]]:
			var pn = w.get(String(pv[1]))
			if pn != null and (pn as Control).visible:
				names.append(String(pv[0]))
		if names.is_empty():
			return "none"
		return ",".join(PackedStringArray(names))
	var shown := false
	var show_frame := 0
	for attempt in range(6):
		# Resolve both actual reward choices and level drafts; the banner
		# must still meet every original steady-state visibility conjunct.
		await _c21_settle_modals(w)
		if String(w.get("state")) not in ["playing", "guardian", "portal"]:
			await _c9_frames(5)
			continue
		show_frame = Engine.get_process_frames()
		w.call("show_banner", "c19 banner probe", 5.0)
		shown = await _c9_wait(func() -> bool:
			if Engine.get_process_frames() < show_frame + 2:
				return false
			return (absf((w.get("_banner") as Label).modulate.a - 1.0) < 0.01
				and absf((w.get("_banner_back") as Control).modulate.a - 1.0) < 0.01
				and not bool(w.call("_any_modal_open"))
				and not bool((w.get("_modal_scrim") as Control).visible)), 240)
		print("C19 BANNER PROBE attempt=", attempt, " shown=", shown,
			" state=", String(w.get("state")),
			" modals=", modal_names.call(),
			" banner_t=", w.get("_banner_t"))
		if shown and String(w.get("state")) in ["playing", "guardian", "portal"]:
			break
		shown = false
	_c9_check("c19: banner + backing show in play",
		shown and String(w.get("state")) in ["playing", "guardian", "portal"],
		"state=" + String(w.get("state")) + " banner_t=" + str(w.get("_banner_t"))
		+ " modals=" + modal_names.call()
		+ " scrim=" + str(bool((w.get("_modal_scrim") as Control).visible))
		+ " a_banner=" + str((w.get("_banner") as Label).modulate.a)
		+ " a_back=" + str((w.get("_banner_back") as Control).modulate.a))
	await _c9_cleanup_run()
	GameProfile.data = snap
	GameProfile.save_profile()

func _c18_frac_count(n: Node) -> int:
	var c := 0
	if n.has_meta("frac"):
		c += 1
	for ch in n.get_children():
		c += _c18_frac_count(ch)
	return c

## C23: run real brain under accelerated cadence, never mute its timer.
func _c23_phase() -> void:
	var snap: Dictionary = GameProfile.data.duplicate(true)
	var w = _world
	GameProfile.data["biomes"] = {"forest":1}
	var ok := await _c9_start_run("bulbasaur", 2)
	_c9_check("c23: run boots", ok)
	if not ok:
		return
	_c9_check("c23 setup clamps requested tier to biome cap", int(w.get("run_tier")) == 1)
	w.set("run_tier",0)
	var p = w.get("player")
	_c9_check("c23 ladder: 17-row data hook exists", w.has_method("tier_value"))
	if w.has_method("tier_value"):
		var expected := {"hp": [1,1.4,1.9], "dmg": [1,1.42,1.96], "speed": [1,1.08,1.16], "amount": [1,1.3,1.6], "kills": [1,1.25,1.5], "level": [1,1.5,1.8], "cap": [1,1.15,1.3], "elite": [0,.04,.08], "events": [1,1.2,1.4], "early": [0,15,30], "tele": [1,.92,.85], "fury": [.5,.55,.6], "escorts": [0,1,2], "wound": [4,5,6], "strike": [1,1.2,1.4], "late": [1,1.12,1.25], "alphaCap1": [.15,.25,.25]}
		for t in range(3):
			w.set("run_tier", t)
			for row in expected:
				_c9_check("c23 row %s tier%d" % [row,t], absf(float(w.call("tier_value",row))-float(expected[row][t])) < .00001)
			w.set("elapsed", 20.0)
			w.set("zone", 2)
			var e = w.call("_spawn_enemy_at", "rattata", Vector3.ZERO, 1.0)
			_c9_check("c23 spawn hp tier%d" % t, absf(e.max_hp / Enemy.base_hp("rattata") - float(expected.hp[t])) < .001)
			_c9_check("c23 spawn speed tier%d" % t, absf(e.speed / Enemy.base_speed("rattata") - float(expected.speed[t])) < .001)
			var dmg_ratio: float = e.dmg / Enemy.base_dmg("rattata")
			_c9_check("c23 spawn damage+late tier%d" % t, absf(dmg_ratio - (1.0+20.0/60.0*.13)*float(w.STAGE_DMG[1])*float(expected.dmg[t])*float(expected.late[t])) < .001)
			e.queue_free()
			_c9_check("c23 name tier%d" % t, w.call("tier_name") == ["Normal","Difícil","Pesadilla"][t])
			w.set("elapsed", 0.0)
			w.set("zone", 1)
			_c9_check("c23 cap consumer tier%d" % t, int(w.call("_enemy_cap")) == int(round(10.0*float(expected.cap[t]))))
			w.set("_spawn_t",0.0)
			w.set("_swarm",false)
			w.set("_hitstop_t",0.0)
			p.pending_levels = 0
			w.call("_process",.001)
			_c9_check("c23 amount consumer tier%d" % t, absf(float(w.get("_spawn_t"))-.9/(p.difficulty_mult*p.enemy_amount_mult*float(expected.amount[t]))) < .001)
			w.set("elapsed",90.0)
			var roll_seed := 0
			for candidate in range(10000):
				seed(candidate)
				randf()
				var roll := randf()
				if roll > .04 and roll < .05:
					roll_seed = candidate
					break
			seed(roll_seed)
			w.call("_spawn_enemy")
			var elite_e = get_tree().get_nodes_in_group("enemies")[-1]
			_c9_check("c23 elite consumer tier%d" % t, int(elite_e.flag) == (0 if t == 0 else 1))
			p.xp = 0.0
			p.gain_xp(1.0)
			_c9_check("c23 XP consumer tier%d" % t, absf(p.xp-p.xp_mult*(1.0+t*.15)) < .001)
			w.set("kills", 1)
			w.set("run_time", 0.0)
			w.set("damage_dealt", 0.0)
			w.set("bosses", 0)
			w.set("zone", 1)
			_c9_check("c23 score tier%d" % t, int(w.call("run_score", false)) == 2+t)
			_c9_check("c23 early floor tier%d" % t, float(w.call("tier_timeline_time",70.0)) == maxf(60,70-float(expected.early[t])))
		w.set("run_tier", 1)
		w.set("kills", 0)
		w.set("run_time", 1.0/3.0)
		_c9_check("c23 score rounds before multiplier, preserves half point", float(w.call("run_score", false)) == 1.5)
		w.set("run_tier", 0)
	GameProfile.data.erase("biomes")
	GameProfile.data["counters"] = {"tier_forest":1}
	GameProfile.save_profile()
	GameProfile._loaded = false
	GameProfile.load_profile()
	_c9_check("c23 legacy normal clear migrates as one, not two", GameProfile.biome_tier("forest") == 1 and GameProfile.biome_tier_cap("forest") == 1)
	GameProfile.reset_all()
	_c9_check("c23 reset biomes unlocks initial forest", GameProfile.biome_unlocked("forest") and not GameProfile.biome_unlocked("graveyard"))
	GameProfile.data["biomes"] = {"forest":0}
	_c9_check("c23 biomes: unlocked uncleared cap zero", GameProfile.biome_unlocked("forest") and GameProfile.biome_tier_cap("forest") == 0 and not GameProfile.biome_unlocked("graveyard"))
	GameProfile.record_biome_clear("forest",0)
	_c9_check("c23 biomes: normal clear opens hard and next biome", GameProfile.biome_tier_cap("forest") == 1 and GameProfile.biome_unlocked("graveyard") and GameProfile.counter_value("tier_forest") == 1)
	GameProfile.record_biome_clear("forest",2)
	GameProfile.record_biome_clear("forest",0)
	_c9_check("c23 biomes: highest clear survives lower clear", GameProfile.biome_tier("forest") == 3 and GameProfile.biome_tier_cap("forest") == 2 and GameProfile.counter_value("hard") == 1 and GameProfile.counter_value("night") == 1)
	w.set("zone", 1)
	w.set("boss_spawned", false)
	w.summon_guardian()
	var g = w.get("guardian")
	p.moves.clear()
	p.invulnerable = true
	p.global_position = g.global_position + Vector3(4,0,0)
	# Exercise existing event batch consumer and fury/tele/escort consumers.
	for t in range(3):
		w.set("run_tier",t)
		w.set("_event_kind","fog")
		w.set("_event_left",20.0)
		w.set("_event_spawned_n",0)
		w.set("_event_spawn_t",0.0)
		w.call("_event_tick",.01)
		_c9_check("c23 events consumer tier%d" % t, int(w.get("_event_spawned_n")) == [4,5,6][t])
		w.set("_event_kind", "")
		w.set("_boss_mech", "starmie")
		w.set("_boss_mech_data", {"run":{},"path":[],"dizzy":0.0})
		w.set("_timers",[])
		w.call("_boss_mech_cast")
		var timers: Array = w.get("_timers")
		_c9_check("c23 tele consumer tier%d" % t, not timers.is_empty() and absf(float(timers[-1].t)-1.2*[1.0,.92,.85][t]) < .001)
		w.set("_timers",[])
		w.set("_boss_mech_data",{})
		w.set("_boss_mech", "")
		w.set("_boss_enraged",false)
		g.hp = g.max_hp * ([.5,.55,.6][t]-.001)
		w.set("_boss_t",10.0)
		w.call("_boss_tick",.01)
		_c9_check("c23 fury consumer tier%d" % t, bool(w.get("_boss_enraged")))
		g.hp = g.max_hp
		w.set("_boss_escorts",[])
		w.set("run_roars",0)
		w.call("_boss_call_escorts")
		_c9_check("c23 escorts consumer tier%d" % t, (w.get("_boss_escorts") as Array).size() == 3+t)
	w.set("run_tier",0)
	w.set("_boss_mech", "")
	w.set("_boss_enraged", false)
	w.set("_boss_call_t", 999.0)
	for sample in [[0.0,4.0,0.0],[12.0,4.0,0.0],[22.0,4.0,.2],[32.0,4.0,.4],[99.0,30.0,0.0]]:
		p.set("no_hit_t", sample[0])
		p.global_position = g.global_position + Vector3(sample[1],0,0)
		w.set("_boss_t", 10.0)
		w.call("_boss_tick", .1)
		var consumed := 10.0-float(w.get("_boss_t"))
		_c9_check("c23 impatient edge state %s dist%s" % [sample[0],sample[1]], bool(w.get("_boss_impatient")) == (float(sample[2]) > 0.0))
		_c9_check("c23 impatience clock %s dist%s" % [sample[0],sample[1]], absf(consumed-.1*(1.0+sample[2])) < .00001, "consumed="+str(consumed))
	p.set("no_hit_t",22.0)
	g.hp -= 1.0
	w.set("_boss_t",10.0)
	p.global_position = g.global_position + Vector3(4,0,0)
	w.call("_boss_tick",.1)
	_c9_check("c23 boss taking damage does not reset player clock", p.no_hit_t == 22.0 and absf(float(w.get("_boss_t"))-9.88)<.0001)
	w.set("running",true)
	w.set("_hitstop_t",0.0)
	p.no_hit_t = 7.0
	p.call("_physics_process",.1)
	_c9_check("c23 player clock accumulates live time", absf(p.no_hit_t-7.1)<.001)
	w.set("running",false)
	p.call("_physics_process",.1)
	_c9_check("c23 player clock pauses with simulation", absf(p.no_hit_t-7.1)<.001)
	w.set("running",true)
	p.invulnerable = true
	p.take_damage(1.0)
	p.hurt_fixed(1.0)
	_c9_check("c23 ignored hits preserve clock", absf(p.no_hit_t-7.1)<.001)
	p.invulnerable = false
	p.evasion = 0.0
	p.hp = p.max_hp
	p.set("no_hit_t", 25.0)
	p.set("_invuln_t", 0.0)
	p.take_damage(1.0)
	_c9_check("c23 landed normal hit resets player clock", p.get("no_hit_t") == 0.0)
	p.set("no_hit_t", 25.0)
	p.hurt_fixed(1.0)
	_c9_check("c23 fixed hit resets player clock", p.get("no_hit_t") == 0.0)
	# Deterministic long path + live expired brain: it must not dispatch
	# a generic or signature move during run OR full dizzy window.
	for rage in [false,true]:
		w.set("_boss_mech", "starmie")
		w.set("_boss_enraged", rage)
		w.set("_boss_sig_next", true)
		w.set("_boss_far_t", 0.0)
		w.set("_boss_t", 0.0)
		w.set("_boss_mech_data", {"run":{"k":0,"s":0.0,"hit":false}, "path":[Vector2(g.position.x,g.position.z),Vector2(g.position.x+20,g.position.z)], "dizzy":0.0})
		p.global_position = g.global_position + Vector3(3,0,0)
		p.set("no_hit_t", 32.0)
		p.invulnerable = true
		w.call("_boss_tick", .1)
		_c9_check("c23 F1 live brain preserves run rage="+str(rage), bool(w.get("_boss_sig_next")) and int((w.get("_boss_mech_data") as Dictionary).get("run",{}).get("k",-1)) == 0)
		w.set("_boss_mech_data", {"run":{}, "path":[], "dizzy":2.5})
		w.set("_boss_t", 0.0)
		w.set("_boss_sig_next", true)
		w.call("_boss_tick", .1)
		_c9_check("c23 F1 live brain preserves dizzy rage="+str(rage), bool(w.get("_boss_sig_next")) and float((w.get("_boss_mech_data") as Dictionary).get("dizzy",0)) > 2.3)
		w.set("_boss_mech_data", {"run":{}, "path":[], "dizzy":0.0,"pending":true})
		w.set("_boss_t", 0.0)
		w.set("_boss_sig_next", true)
		w.call("_boss_tick", .1)
		_c9_check("c23 F1 live brain preserves windup rage="+str(rage), bool(w.get("_boss_sig_next")))
		w.set("_boss_mech_data", {"run":{}, "path":[], "dizzy":0.0,"pending":false})
		w.call("_boss_tick", .1)
		_c9_check("c23 F1 brain resumes after occupancy rage="+str(rage), not bool(w.get("_boss_sig_next")))
	# Full actual cast -> windup -> 4/6 legs -> 2.5s dizzy with
	# the brain ticking at maximum close-range impatience throughout.
	for rage in [false,true]:
		w.set("_timers", [])
		w.set("_boss_enraged", rage)
		w.set("_boss_far_t", 0.0)
		w.set("_boss_call_t", 999.0)
		w.set("_boss_sig_next", true)
		w.set("_boss_mech_data", {"run":{}, "path":[], "dizzy":0.0})
		p.set("no_hit_t", 32.0)
		p.global_position = g.global_position + Vector3(4,0,0)
		w.call("_boss_mech_cast")
		w.set("_boss_t", 0.0)  # expired, never silenced
		var seen_dizzy := false
		var held := true
		var dizzy_seconds := 0.0
		for frame in range(1000):
			var before_dizzy := float((w.get("_boss_mech_data") as Dictionary).get("dizzy",0))
			w.call("_timers_tick", .02)
			w.call("_boss_tick", .02)
			var data: Dictionary = w.get("_boss_mech_data")
			# A new dispatch is legal on the exact frame dizzy expires.
			if seen_dizzy and before_dizzy > 0.0 and before_dizzy <= .020001:
				break
			if float(data.get("dizzy",0)) > 0:
				seen_dizzy = true
				dizzy_seconds += .02
			var busy := bool(data.get("pending",false)) or not (data.get("run",{}) as Dictionary).is_empty() or float(data.get("dizzy",0)) > 0
			if busy:
				held = held and bool(w.get("_boss_sig_next"))
			elif seen_dizzy:
				break
		_c9_check("c23 F1 full cast reaches complete dizzy rage="+str(rage), seen_dizzy and dizzy_seconds >= 2.46 and held, "dizzy_seconds="+str(dizzy_seconds))
	w.set("run_tier",1)
	w.set("gold",100.0)
	var dust_before := GameProfile.stardust()
	w.call("_finish_run",false)
	_c9_check("c23 stardust consumer tier1", GameProfile.stardust()-dust_before == 7)
	await _c9_cleanup_run()
	GameProfile.data = snap
	GameProfile.save_profile()

## C23: pending entity value, used by payment checks before walk-over collection.
func _c23_pickup_value(w: Node, kind: int) -> float:
	var pool = w.get("pickups")
	if pool == null:
		return 0.0
	var total := 0.0
	for e in pool.entries:
		if int(e.kind) == kind:
			total += float(e.value)
	return total

func _c23_collect_last_xp(w: Node, p: Node3D) -> void:
	var pool = w.get("pickups")
	for i in range(pool.entries.size()-1,-1,-1):
		var e: Dictionary = pool.entries[i]
		if int(e.kind)==0:
			_c23_collect_pickup(w,p,e)
			return

func _c23_collect_pickup(w: Node, p: Node3D, e: Dictionary) -> void:
	var pool = w.get("pickups")
	if pool == null or not pool.entries.has(e) or not is_instance_valid(e.node):
		return
	e.age = 1.0
	e.node.position = p.global_position+Vector3(0,0.7,0)
	pool.tick(0.001)
