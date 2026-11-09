extends SceneTree
var checks := 0
var fails := 0
class FakePlayer extends Node3D:
	var pickup_range := 6.0
	var powerup_mult := 2.0
	var gold_mult := 1.0
	var max_hp := 100.0
	var hp := 50.0
	var xp := 0.0
	var level := 0
	var passive_id := ""
	var buffs := {}
	func gain_xp(v: float) -> void: xp += v
	func leech_heal(v: float) -> void: hp += v
	func gain_level() -> void: level += 1
	func add_buff(k: String, t: float) -> void: buffs[k] = t
	func tick_buffs(_dt: float) -> void: pass
class FakeWorld extends Node3D:
	const BOUND := 168.0
	var player: FakePlayer
	var gold := 0.0
	var keys := 0
	var gold_count := 0.0
	var berries := 0
	var run_time := 0.0
	var zone := 1
	var audio = null
	var _event_kind := ""
	var running := true
	func height_at(_x: float, _z: float) -> float: return 0.0
	func count_gold_pickup(v: float) -> void: gold_count += v
	func count_run_event(_key: String) -> void: berries += 1
	func spawn_floater(_p: Vector3, _t: String, _c: Color) -> void: pass
	func _toughness_now() -> float: return 1.0
	func _luck_mult() -> float: return 1.0
class FakeEnemy extends Node3D:
	var hp := 1000.0
	var max_hp := 1000.0
	var flag := 0
	var is_guardian := false
	var is_downed := false
	var is_weakened := false
	var is_object := false
	var weight := 1.0
	var xp_mult := 1.0
	var stun := 0.0
	var para := false
	var knock := 0.0
	func pickup_fixed_damage(v: float) -> void: hp -= v
	func pickup_stun(v: float, t := false) -> void:
		stun = maxf(stun,v)
		para = t
	func apply_knockback(_pos: Vector3, v: float) -> void: knock = v
	func xp_value(_t: float) -> float: return 7.0
func ck(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ", label)
func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var path := OS.get_environment("C23_PICKUPS_SCRIPT")
	if path.is_empty(): path = "res://scripts/pickups.gd"
	ck(ResourceLoader.exists(path), "pickup manager exists")
	if ResourceLoader.exists(path):
		var script = load(path)
		var m = script.new()
		root.add_child(m)
		ck(m.KINDS.size() == 13, "13 pickup kinds")
		ck(m.lifetime(0) == INF and m.lifetime(1) == INF, "xp/coin infinite")
		ck(m.lifetime(2) == 60.0 and m.lifetime(3) == 120.0 and m.lifetime(5) == 120.0, "expiry exact")
		ck(m.lifetime(6) == INF and m.lifetime(12) == INF, "candy/TMs infinite")
		var a: int = m.spawn(0, Vector3.ZERO, 3.0)
		ck(a == 0 and m.entries.size() == 1 and m.entries[0].value == 3.0, "spawn preserves value")
		ck(m.entries[0].vel.y >= 4.0 and m.entries[0].vel.y <= 7.0, "launch vy")
		m.entries[0].age = 0.5
		m.entries[0].attracted = false
		for i in range(501):
			m.spawn(0, Vector3.ZERO, 1.0)
		var count: int = m.entries.size()
		m.spawn(0, Vector3.ZERO, 9.0)
		ck(m.entries.size() == count, "xp merge threshold")
		var total := 0.0
		for e in m.entries:
			total += float(e.value)
		ck(total == 513.0, "merge conserves values")
		m.clear()
		ck(m.entries.is_empty(), "clear entries")
		var w := FakeWorld.new()
		root.add_child(w)
		var p := FakePlayer.new()
		w.add_child(p)
		w.player = p
		m.world = w
		m.supply_at = INF
		m.collect(0,7.0)
		ck(p.xp == 7.0 and m.xp_chain_t == 0.45,"XP dispatch + chain window")
		m.collect(1,9.0)
		ck(w.gold == 9.0 and w.gold_count == 9.0 and m.coin_t == 0.4,"coin dispatch + batch window")
		m.collect(2)
		ck(p.hp == 75.0 and w.berries == 1,"heal quarter maxHP + berries")
		m.collect(3)
		ck(m.magnet_all == 8.0,"magnet scales powerup")
		m.collect(6)
		m.collect(7)
		ck(p.level == 1 and w.keys == 1,"candy and reserved key")
		for kind in [8,9,10,12]: m.collect(kind)
		ck(p.buffs["tm-swords"]==20.0 and p.buffs["tm-agility"]==20.0 and p.buffs["tm-iron"]==16.0 and p.buffs["tm-payday"]==30.0,"TM durations scale powerup")
		m.clear()
		m.supply_at = INF
		m.spawn(2,Vector3(20,0,0))
		m.entries[0].age = 59.99
		m.tick(0.02)
		ck(m.entries.is_empty(),"heal expires at sixty seconds")
		m.spawn(0,Vector3(20,0.6,0),2.0)
		m.entries[0].age = 0.34
		m.entries[0].vel = Vector3.ZERO
		m.entries[0].rest = true
		m.tick(0.001)
		ck(not m.entries[0].attracted,"attraction waits age .35")
		m.magnet_all = 4.0
		m.tick(0.02)
		ck(m.entries[0].attracted and m.entries[0].vel.x<0.0,"global magnet attracts distant xp")
		m.clear()
		m.supply_at = INF
		m.spawn(2,Vector3(20,0.6,0))
		m.entries[0].age = 1.0
		m.entries[0].rest = true
		m.magnet_all = 4.0
		m.tick(0.01)
		ck(not m.entries[0].attracted,"magnet excludes heal")
		m.entries[0].node.position = Vector3(5,0.6,0)
		m.tick(0.01)
		ck(m.entries[0].attracted,"rest pickup reactivates within range")
		m.entries[0].node.position = Vector3(0.1,0.6,0)
		m.tick(0.01)
		ck(m.entries.is_empty() and w.berries==2,"collect radius .9 dispatch")
		var normal := FakeEnemy.new()
		var boss := FakeEnemy.new()
		var far := FakeEnemy.new()
		var obj := FakeEnemy.new()
		for e in [normal,boss,far,obj]:
			w.add_child(e)
			e.add_to_group("enemies")
		normal.position = Vector3(10,0,0)
		boss.position = Vector3(12,0,0)
		boss.is_guardian = true
		boss.flag = 4
		far.position = Vector3(29,0,0)
		obj.is_object = true
		m.nuke()
		ck(normal.hp == 1000.0-1e9 and boss.hp==920.0 and far.hp==1000.0 and obj.hp==1000.0,"bomb 28u fixed 1e9/8% skips Objects")
		ck(boss.knock==6.0,"bomb knock six")
		normal.hp = 1000.0
		m.repel()
		ck(normal.knock==40.0 and normal.stun==1.5 and boss.knock==2.0 and is_equal_approx(boss.stun,0.075),"repel 20u resistance and raw stun")
		ck(far.stun==0.0,"repel excludes beyond twenty")
		m.collect(11)
		ck(normal.stun==8.0 and boss.stun==8.0 and far.stun==8.0,"thunder radius forty scales duration/resistance")
		m.clear()
		m.supply_at = INF
		m.powerup_at = INF
		for i in range(5): m.drops(normal)
		var coins := 0.0
		var xp_total := 0.0
		for e in m.entries:
			if e.kind==1: coins += e.value
			if e.kind==0: xp_total += e.value
		ck(coins==1.0 and xp_total==35.0 and w.gold==9.0,"kill rewards spawn entities; fractional gold retained")
		m.clear()
		m.supply_at = INF
		m.powerup_at = INF
		normal.weight = 5.0
		m.drops(normal)
		ck(m.entries.size()>=2 and m.entries[1].kind==1 and m.entries[1].value==1.0,"weighted gold drip")
		m.clear()
		m.supply_at = INF
		m.powerup_at = INF
		normal.flag = 2
		m.drops(normal)
		var candy_count := 0
		for e in m.entries:
			if e.kind==6: candy_count += 1
		ck(candy_count==1,"alpha candy drop")
		m.clear()
		m.supply_at = INF
		for i in range(501):
			m.spawn(0,Vector3(100+float(i)*5.0,0,0))
		var recycle_count: int = m.entries.size()
		# Build a far-away eligible pool without merging into a nearby slot.
		for e in m.entries:
			e.node.position = Vector3(100,0.6,0)
			e.rest = true
		m.spawn(0,Vector3.ZERO,5.0)
		ck(m.entries.size()==recycle_count,"distant recycle avoids new slot")
		var recycled := false
		for e in m.entries:
			if e.node.position.x==0.0:
				recycled = Vector2(e.vel.x,e.vel.z).length()>=1.0 and Vector2(e.vel.x,e.vel.z).length()<=3.5 and e.vel.y>=4.0 and e.vel.y<=7.0 and not e.rest and e.age==0.0
		ck(recycled,"recycle resets launch/rest/age")
		m.clear()
		m.supply_at = INF
		for i in range(261): m.spawn(0,Vector3.ZERO)
		for e in m.entries: e.age = 1.0
		m.consolidate()
		ck(m.entries.size()==1 and m.entries[0].value==261.0,"consolidate 3.5 grid preserves total")
		m.clear()
		m.supply_at = INF
		for i in range(241): m.spawn(0,Vector3.ZERO)
		for i in range(20): m.spawn(2,Vector3.ZERO)
		for e in m.entries:
			e.age = 1.0
			if e.kind==0: e.attracted = true
		m.consolidate()
		ck(m.entries.size()==261,"consolidate excludes attracted xp threshold")
		var real_enemy = load("res://scripts/enemy.gd").new()
		w.add_child(real_enemy)
		real_enemy.set_physics_process(false)
		real_enemy.world = w
		real_enemy.target = p
		real_enemy.position = Vector3(10,0,0)
		real_enemy.pickup_stun(1.5)
		real_enemy.apply_knockback(p.global_position,40.0)
		real_enemy._physics_process(0.1)
		ck(is_equal_approx(real_enemy.position.x,14.0),"repel physical impulse integrates during pickup stun")
		ck(is_equal_approx(real_enemy._kb_vel.x,40.0*exp(-0.7)),"repel impulse decays during pickup stun")
		ck(real_enemy.pickup_stun_t>1.3 and real_enemy._touch_cd<0.0,"pickup stun blocks autonomous contact while impulse moves")
		real_enemy.position = Vector3(10,0,0)
		real_enemy._kb_vel = Vector3(40,0,0)
		real_enemy.root_t = 1.0
		real_enemy._physics_process(0.1)
		ck(real_enemy.position.x==10.0 and real_enemy._kb_vel.x==40.0,"existing root gate remains unchanged when pickup stun overlaps")
		real_enemy.queue_free()
		m.clear()
		m.queue_free()
		w.queue_free()
	print("PICKUPS SUMMARY checks=%d fails=%d" % [checks, fails])
	quit(1 if fails else 0)
