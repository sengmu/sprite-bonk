extends Node3D
## C23 pack §2. Lightweight pickup pool; visual meshes share resources.
const KINDS := ["xp", "coin", "heal", "magnet", "bomb", "repel", "candy", "chestkey", "tm-swords", "tm-agility", "tm-iron", "tm-thunder", "tm-payday"]
const CAPACITY := 2500
var world: Node
var entries: Array = []
var magnet_all := 0.0
var keys := 0
var gold_frac := 0.0
var powerup_at := 0.0
var bomb_at := 0.0
var xp_chain := 0
var xp_chain_t := 0.0
var coin_sum := 0.0
var coin_t := 0.0
var consolidate_t := 0.0
var harvest_t := 0.0
var supply_at := 0.0
var mesh: SphereMesh
var materials: Array = []
func lifetime(kind: int) -> float:
	return 60.0 if kind == 2 else (120.0 if kind in [3,4,5] else INF)
func clear() -> void:
	for e in entries:
		e.node.queue_free()
	entries.clear()
	magnet_all = 0.0
	keys = 0
	gold_frac = 0.0
	powerup_at = 0.0
	bomb_at = 0.0
	xp_chain = 0
	xp_chain_t = 0.0
	coin_sum = 0.0
	coin_t = 0.0
	harvest_t = 0.0
	supply_at = randf_range(55.0, 75.0)
func spawn(kind: int, pos: Vector3, value := 1.0) -> int:
	if kind < 0 or kind >= KINDS.size():
		return -1
	var same_count := 0
	for e in entries:
		if int(e.kind)==kind: same_count += 1
	if kind <= 1 and same_count > (500 if kind == 0 else 200):
		var nearest := -1
		var best := 16.0
		var farthest := -1
		var far_d := -1.0
		var player_pos: Vector3 = world.player.global_position if world and world.player else pos
		for i in range(entries.size()):
			var e: Dictionary = entries[i]
			if int(e.kind) != kind or e.attracted:
				continue
			var at: Vector3 = e.node.position
			var d := Vector2(at.x-pos.x,at.z-pos.z).length_squared()
			if d < best:
				best = d
				nearest = i
			var pd := Vector2(at.x-player_pos.x,at.z-player_pos.z).length_squared()
			if pd > far_d:
				far_d = pd
				farthest = i
		if nearest >= 0:
			entries[nearest].value += value
			return nearest
		if farthest >= 0 and (entries.size()>1800 or far_d>3600.0):
			var recycled: Dictionary = entries[farthest]
			recycled.value += value
			recycled.node.position = pos+Vector3(0,0.6,0)
			recycled.age = 0.0
			var launch_angle := randf()*TAU
			var launch_speed := randf_range(1.0,3.5)
			recycled.vel = Vector3(cos(launch_angle)*launch_speed,randf_range(4.0,7.0),sin(launch_angle)*launch_speed)
			recycled.floor = (world.height_at(pos.x,pos.z) if world else pos.y)+0.6
			recycled.rest = false
			recycled.attracted = false
			return farthest
	if entries.size() >= CAPACITY:
		return -1
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = 0.18
		mesh.height = 0.36
		mesh.radial_segments = 8
		mesh.rings = 4
		for i in range(13):
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = [Color(0.35,0.9,1),Color(1,0.8,0.1),Color(1,0.25,0.4),Color(0.6,0.5,1),Color(1,0.35,0.1),Color(0.2,1,0.7),Color(1,0.55,0.9),Color(1,1,0.5),Color(1,0.4,0.3),Color(0.9,0.4,1),Color(0.7,0.8,0.9),Color(1,1,0.2),Color(1,0.8,0.3)][i]
			materials.append(mat)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = materials[kind]
	add_child(node)
	node.position = pos+Vector3(0,0.6,0)
	var a := randf() * TAU
	var speed := randf_range(1.0, 3.5)
	entries.append({"kind":kind,"value":value,"node":node,"vel":Vector3(cos(a)*speed,randf_range(4.0,7.0),sin(a)*speed),"floor":(world.height_at(pos.x,pos.z) if world else pos.y)+0.6,"age":0.0,"attracted":false,"rest":false})
	return entries.size()-1
func tick(dt: float) -> void:
	if world == null or world.player == null:
		return
	var p = world.player
	magnet_all = maxf(0.0, magnet_all-dt)
	xp_chain_t -= dt
	coin_t -= dt
	if coin_t <= 0.0 and coin_sum > 0.0:
		world.spawn_floater(p.global_position+Vector3(0,2.2,0), "+%d 金币" % int(coin_sum), Color(1,0.85,0.3))
		coin_sum = 0.0
	p.tick_buffs(dt)
	if world.run_time >= supply_at:
		supply_at = world.run_time + randf_range(70.0,95.0)
		if String(world.get("_event_kind")) != "mewtwo":
			supply_drop()
	if p.passive_id == "harvest":
		harvest_t += dt
		if harvest_t >= 15.0:
			harvest_t -= 15.0
			spawn(2,p.global_position+Vector3(1,0,0))
	for i in range(entries.size()-1,-1,-1):
		var e: Dictionary = entries[i]
		e.age = float(e.age)+dt
		var life := lifetime(int(e.kind))
		if float(e.age) >= life:
			_remove(i)
			continue
		var node: Node3D = e.node
		node.visible = life-float(e.age)>8.0 or int(float(e.age)*8.0)%2==0
		var target: Vector3 = p.global_position+Vector3(0,0.7,0)
		var dist := node.position.distance_to(target)
		if float(e.age)>0.35 and (dist<p.pickup_range or (magnet_all>0.0 and int(e.kind)<=1)):
			e.attracted = true
			e.rest = false
		if e.attracted:
			if dist<0.9:
				collect(int(e.kind),float(e.value))
				_remove(i)
				continue
			e.vel = (e.vel as Vector3).lerp((target-node.position).normalized()*(16.0+float(e.age)*6.0),minf(1.0,dt*9.0))
		elif not e.rest:
			e.vel.y -= 20.0*dt
			e.vel.x *= exp(-3.0*dt)
			e.vel.z *= exp(-3.0*dt)
		if not e.rest:
			node.position += (e.vel as Vector3)*dt
			if not e.attracted and node.position.y<=float(e.floor):
				node.position.y = float(e.floor)
				e.vel.y = absf(e.vel.y)*0.3
				if e.vel.y<1.0 and e.vel.x*e.vel.x+e.vel.z*e.vel.z<0.04:
					e.rest = true
					e.vel = Vector3.ZERO
	consolidate_t += dt
	if consolidate_t>=1.2:
		consolidate_t = 0.0
		consolidate()
func _remove(i: int) -> void:
	entries[i].node.queue_free()
	entries.remove_at(i)
func consolidate() -> void:
	if entries.size()<=260:
		return
	var cells := {}
	for e in entries:
		var k := int(e.kind)
		if k>1 or e.attracted or float(e.age)<1.0:
			continue
		var pos: Vector3 = e.node.position
		var key := "%d:%d:%d" % [k,int(floor(pos.x/3.5)),int(floor(pos.z/3.5))]
		if not cells.has(key): cells[key] = []
		cells[key].append(e)
	var removed := []
	for cell in cells.values():
		var kind := int(cell[0].kind)
		if cell.size()<=(240 if kind==0 else 100):
			continue
		var kept: Dictionary = cell[0]
		for i in range(1,cell.size()):
			kept.value += float(cell[i].value)
			removed.append(cell[i])
	for i in range(entries.size()-1,-1,-1):
		if removed.has(entries[i]): _remove(i)
func collect(kind: int, value := 1.0) -> void:
	var p = world.player
	match kind:
		0:
			p.gain_xp(value)
			xp_chain = xp_chain+1 if xp_chain_t>0.0 else 1
			xp_chain_t = 0.45
			if world.audio: world.audio.xp(mini(xp_chain,15))
		1:
			world.gold += value
			world.count_gold_pickup(value)
			coin_sum += value
			if coin_t<=0.0: coin_t = 0.4
			if world.audio: world.audio.coin()
		2:
			world.count_run_event("berries")
			p.leech_heal(p.max_hp*0.25)
			if world.audio: world.audio.heal()
		3: magnet_all = 4.0*p.powerup_mult
		4: nuke()
		5: repel()
		6: p.gain_level()
		7:
			keys += 1
			world.keys += 1
		8,9,10,12:
			p.add_buff(KINDS[kind],(8.0 if kind==10 else (15.0 if kind==12 else 10.0))*p.powerup_mult)
		11:
			for e in nearby(40.0):
				e.pickup_stun(4.0*p.powerup_mult)
func nearby(radius: float, skip_objects := false) -> Array:
	var found := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.hp<=0.0 or e.is_downed or e.is_weakened or (skip_objects and e.is_object):
			continue
		var d: Vector3 = e.global_position-world.player.global_position
		d.y = 0.0
		if d.length()<=radius:
			found.append(e)
	return found
func resist(e: Node) -> float:
	return 0.05 if e.is_guardian or (int(e.flag)&(4|8192))!=0 else (0.2 if (int(e.flag)&12290)!=0 else 1.0)
func nuke(revive := false) -> void:
	for e in nearby(28.0,true):
		var special: bool = e.is_guardian or (int(e.flag)&12294)!=0
		var amount: float = e.max_hp*0.08 if special else 1e9
		if revive and (e.is_guardian or (int(e.flag)&4)!=0): amount = minf(amount,maxf(0.0,e.hp-1.0))
		e.pickup_fixed_damage(amount)
		e.apply_knockback(world.player.global_position,6.0)
func repel() -> void:
	for e in nearby(20.0):
		var r := resist(e)
		e.apply_knockback(world.player.global_position,40.0*r)
		e.pickup_stun(1.5*r)
func drops(e: Node) -> void:
	var p = world.player
	var pos: Vector3 = e.global_position
	spawn(0,pos,e.xp_value(world._toughness_now())*e.xp_mult)
	if not e.is_guardian:
		gold_frac += 0.2*p.gold_mult*e.weight
		if gold_frac>=1.0:
			var value := floorf(gold_frac)
			gold_frac -= value
			spawn(1,pos,value)
	if (int(e.flag)&(4096|8192))!=0:
		spawn(6,pos)
		var each := ceilf((3.0+world.zone*3.0)*p.gold_mult)
		for i in range(10 if (int(e.flag)&4096)!=0 else 8):
			spawn(1,pos,each)
	if (int(e.flag)&2)!=0:
		spawn(6,pos)
	if randf()<0.006*p.powerup_mult*e.weight:
		spawn(2,pos)
	if world.run_time>=powerup_at and randf()<0.0018*world._luck_mult()*p.powerup_mult*e.weight:
		var pool := [3,5,8,9,10,11,12]
		if world.run_time>=bomb_at: pool.append(4)
		var kind: int = pool[randi()%pool.size()]
		spawn(kind,pos)
		powerup_at = world.run_time+maxf(18.0,40.0/maxf(0.01,p.powerup_mult))
		if kind==4: bomb_at = world.run_time+120.0

func supply_drop() -> void:
	var pos: Vector3 = world.player.global_position
	var a := randf()*TAU
	var radius := randf_range(22.0,38.0)
	pos += Vector3(cos(a)*radius,0,sin(a)*radius)
	pos.x = clampf(pos.x,-world.BOUND+2.0,world.BOUND-2.0)
	pos.z = clampf(pos.z,-world.BOUND+2.0,world.BOUND-2.0)
	if Vector2(pos.x-world.player.global_position.x,pos.z-world.player.global_position.z).length()<15.0:
		return
	pos.y = world.height_at(pos.x,pos.z)
	if randf()<0.65:
		world.spawn_supply_chest(pos,randf()<0.15)
	else:
		spawn([3,5,2,2,4][randi()%5],pos+Vector3(0,16,0))
