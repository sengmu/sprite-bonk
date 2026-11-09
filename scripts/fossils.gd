class_name Fossils
extends RefCounted
## C24 pack §6; amber is deliberately metadata-only, with no visual or recruit path.
const DATA := {
	"helix":{"species":138,"species_key":"omanyte","cost":.15,"color":"4a9ad8","name":"螺旋化石","tag":"物品","boon":"从两件史诗或更高品质物品中选择一件","buildable":true},
	"dome":{"species":140,"species_key":"kabuto","cost":.20,"color":"b07a3a","name":"甲壳化石","tag":"祝福","boon":"从三项传说祝福中选择一项（效果 ×1.5）","buildable":true},
	"amber":{"species":142,"species_key":"aerodactyl","cost":.25,"color":"ff9a2a","name":"古老琥珀","tag":"队友","boon":"模型未定版：仅数据占位","buildable":false},
}

static func offers() -> Array:
	var out: Array = []
	for key in ["helix","dome"]:
		var row: Dictionary = DATA[key].duplicate(true)
		row["key"] = key
		out.append(row)
	return out

static func open(world, prop: Dictionary) -> void:
	if bool(prop.get("used",false)): return
	var rows := offers()
	var labels: Array = []
	for row in rows:
		labels.append("%s · %s\n%s\n最大生命 −%d%%" % [row.name,row.tag,row.boon,int(round(float(row.cost)*100))])
	world._choice_show("化石遗迹","遗迹只回应一次；离开不消耗。",labels,"离开",
		func(index: int) -> void:
			if index>=0 and index<rows.size(): choose(world,prop,String(rows[index].key)),
		func() -> void: pass)

static func choose(world, prop: Dictionary, key: String) -> bool:
	if bool(prop.get("used",false)) or not DATA.has(key) or not bool(DATA[key].buildable): return false
	world._prop_set_used(prop)
	world.player.temp_mods.append({"stat":"maxHp","mul":1.0-float(DATA[key].cost)})
	world.player.recalc()
	world.count_run_event("fossil_"+key)
	animate(world,prop,key)
	world._later(.8,func() -> void:
		if key=="helix":
			world._roll_chest_item(3,2)
		else:
			world.offer_blessing("甲壳化石的远古祝福",4,3,1,1.5))
	return true

## Port visual: archaeological stone carvings of the two fossil objects.
## These are not replacement Pokémon models; amber creates no node at all.
static func build_visual(world, root: Node3D, dim: Array) -> Dictionary:
	var stone = world._prop_mat(Color("747078"))
	world._prop_box(root,Vector3(3.3,.35,1.65),stone,Vector3(0,.18,0))
	var carvings := {}
	for key in ["helix","dome"]:
		var carving := Node3D.new()
		carving.name = "Helix" if key=="helix" else "Dome"
		root.add_child(carving)
		carving.position = Vector3(-.85 if key=="helix" else .85,.45,0)
		var mat = world._prop_mat(Color(DATA[key].color),.35)
		if key=="helix":
			# A stone spiral, cut from shrinking ring sections.
			for i in range(4):
				var ring := TorusMesh.new()
				ring.inner_radius = .09+float(i)*.09
				ring.outer_radius = .17+float(i)*.09
				ring.rings = 24
				ring.ring_segments = 6
				world._prop_mesh(carving,ring,mat,Vector3(0,.22-float(i)*.045,0))
		else:
			world._prop_sphere(carving,.57,mat,Vector3(0,.14,0),.4)
			for i in range(3):
				world._prop_box(carving,Vector3(.055,.05,.82),stone,Vector3(float(i-1)*.24,.37,0))
		dim.append([mat,mat.albedo_color,.35])
		carvings[key] = carving
	return {"fossil_carvings":carvings}

static func animate(world, prop: Dictionary, key: String) -> void:
	var carvings: Dictionary = prop.get("data",{}).get("fossil_carvings",{})
	if carvings.is_empty(): return
	var chosen: Node3D = carvings[key]
	var tween := chosen.create_tween().set_parallel(true)
	prop["data"]["fossil_tween"] = tween
	tween.tween_property(chosen,"position:y",chosen.position.y+.9,1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(chosen,"rotation:y",chosen.rotation.y+TAU,1.1)
	world._later(.5,func() -> void: world.audio.cry(String(DATA[key].species_key)))
	world._later(.6,func() -> void:
		for other in carvings:
			if other!=key and is_instance_valid(carvings[other]): carvings[other].visible=false)

static func reset_visual(prop: Dictionary) -> void:
	var data: Dictionary = prop.get("data",{})
	var tween: Tween = data.get("fossil_tween")
	if tween and tween.is_valid(): tween.kill()
	data.erase("fossil_tween")
	for key in data.get("fossil_carvings",{}):
		var carving: Node3D = data.fossil_carvings[key]
		if is_instance_valid(carving):
			carving.position = Vector3(-.85 if key=="helix" else .85,.45,0)
			carving.rotation = Vector3.ZERO
			carving.visible = true
