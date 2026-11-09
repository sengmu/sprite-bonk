extends SceneTree
# Behavioral cost/commit/deferral checks; supports an isolated mutant script.
var checks := 0
var fails := 0

class TestPlayer extends RefCounted:
	var temp_mods: Array = []
	var max_hp := 200.0
	var hp := 200.0
	func recalc() -> void:
		max_hp = 200.0
		for mod in temp_mods:
			if mod.stat == "maxHp": max_hp *= float(mod.mul)
		hp = minf(hp,max_hp)

class TestWorld extends RefCounted:
	var player = TestPlayer.new()
	var run_counts := {}
	var timers: Array = []
	var rewards: Array = []
	var opts: Array = []
	var pick: Callable
	var cancel: Callable
	func clear() -> void:
		timers.clear()
		pick = Callable()
		cancel = Callable()
	func _prop_set_used(prop: Dictionary) -> void: prop.used = true
	func count_run_event(key: String) -> void: run_counts[key] = int(run_counts.get(key,0))+1
	func _later(delay: float, callback: Callable) -> void: timers.append({"t":delay,"fn":callback})
	func _roll_chest_item(tier: int, count: int) -> void: rewards.append(["item",tier,count])
	func offer_blessing(title: String, tier: int, count: int, picks: int, power: float = 1.0) -> void:
		rewards.append(["blessing",title,tier,count,picks,power])
	func _choice_show(_title: String, _sub: String, options: Array, _foot: String, on_pick: Callable, on_cancel: Callable) -> void:
		opts = options
		pick = on_pick
		cancel = on_cancel

func ck(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		print("FAIL ",label)

func _initialize() -> void:
	var path := OS.get_environment("C24_FOSSILS_SCRIPT")
	if path.is_empty(): path = "res://scripts/fossils.gd"
	if not ResourceLoader.exists(path):
		ck(false,"fossil implementation exists")
		finish()
		return
	var f = load(path)
	var rows: Array = f.offers()
	ck(rows.size()==2,"only two buildable offers; amber is gated")
	ck(rows[0].key=="helix" and rows[0].species==138 and rows[0].cost==.15,"helix proven identity/cost")
	ck(rows[1].key=="dome" and rows[1].species==140 and rows[1].cost==.2,"dome proven identity/cost")
	ck(f.DATA.amber.species==142 and f.DATA.amber.cost==.25 and not f.DATA.amber.buildable,"amber metadata only")
	var w := TestWorld.new()
	var prop := {"used":false,"data":{}}
	f.open(w,prop)
	ck(w.opts.size()==2,"modal contains helix/dome only")
	w.cancel.call()
	ck(not prop.used and w.player.temp_mods.is_empty() and w.timers.is_empty(),"cancel never charges or consumes")
	ck(not f.choose(w,prop,"amber"),"amber rejected even by direct handler")
	ck(not f.choose(w,prop,"unknown"),"unknown key rejected")
	ck(not prop.used and w.run_counts.is_empty(),"blocked choices have no side effects")
	w.pick.call(0)
	ck(prop.used,"pick consumes prop immediately")
	ck(is_equal_approx(w.player.max_hp,170.0) and is_equal_approx(w.player.hp,170.0),"helix immediately costs 15 percent and clamps hp")
	ck(w.run_counts.get("fossil_helix",0)==1,"helix run counter")
	ck(w.rewards.is_empty() and w.timers.size()==1 and w.timers[0].t==.8,"reward delayed exactly .8 seconds")
	ck(not f.choose(w,prop,"dome") and w.player.temp_mods.size()==1,"one use guards repeated dispatch")
	w.timers[0].fn.call()
	ck(w.rewards==[["item",3,2]],"helix calls epic floor3 two-choice item flow")
	w.clear()
	w = TestWorld.new()
	prop = {"used":false,"data":{}}
	ck(f.choose(w,prop,"dome"),"dome commits")
	ck(is_equal_approx(w.player.max_hp,160.0),"dome immediate 20 percent cost")
	ck(w.run_counts.get("fossil_dome",0)==1,"dome run counter")
	ck(w.rewards.is_empty() and w.timers.size()==1 and w.timers[0].t==.8,"dome reward delayed .8 seconds")
	w.timers[0].fn.call()
	var reward: Array = w.rewards[0]
	ck(reward[0]=="blessing" and reward[2]==4 and reward[3]==3 and reward[4]==1 and reward[5]==1.5,"dome legendary3 choose1 power1.5")
	# Cost lands in the actual Player.recalc temp-mod pipeline.
	var old_data := Profile.data.duplicate(true)
	var old_loaded := Profile._loaded
	Profile._loaded = true
	Profile.data = {"lab":{},"shinies":[],"counters":{}}
	var p = load("res://scripts/player.gd").new()
	p.species_id = "bulbasaur"
	p.base_species = "bulbasaur"
	p.recalc()
	var base_hp: float = p.max_hp
	p.hp = base_hp
	w.clear()
	w = TestWorld.new()
	w.player = p
	ck(f.choose(w,{"used":false,"data":{}},"helix"),"real player accepts helix")
	ck(is_equal_approx(p.max_hp,base_hp*.85),"real Player.recalc helix .85")
	p.recalc()
	ck(is_equal_approx(p.max_hp,base_hp*.85),"real recalc does not accumulate sacrifice")
	ck(f.choose(w,{"used":false,"data":{}},"dome"),"next-stage dome stacks")
	ck(is_equal_approx(p.max_hp,base_hp*.85*.8),"real cost mods stack multiplicatively")
	w.clear()
	p.free()
	# A new run restores cached object state without reconstructing its mesh.
	var helix := Node3D.new()
	var dome_node := Node3D.new()
	helix.position = Vector3(-.85,1.35,0)
	helix.rotation.y = 2.0
	dome_node.visible = false
	f.reset_visual({"data":{"fossil_carvings":{"helix":helix,"dome":dome_node}}})
	ck(is_equal_approx(helix.position.y,.45) and helix.rotation==Vector3.ZERO and dome_node.visible,"cached props restore at new run")
	helix.free()
	dome_node.free()
	Profile.data = old_data
	Profile._loaded = old_loaded
	finish()

func finish() -> void:
	print("C24 FOSSILS SUMMARY checks=%d fails=%d" % [checks,fails])
	quit(0 if fails==0 else 1)
