extends Node3D
## Cycle 21: geometry-space probe for ekans.glb — prints the
## file-space vertex AABB (bind positions straight from the
## ArrayMesh surfaces), the node-chain merged AABB at scale 1,
## and the same AABB after rot_x = -PI/2 / +PI/2 (the laid
## pose), so the fit can be derived from geometry instead of
## the render-projection probe (which cannot measure a body
## whose length lies along Z).

func _merged_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			stack.append(c)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh:
				var a: AABB = mi.global_transform * mi.get_aabb()
				if first:
					out = a
					first = false
				else:
					out = out.merge(a)
	return out

func _vertex_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			stack.append(c)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh is ArrayMesh:
				var am := mi.mesh as ArrayMesh
				for s in range(am.get_surface_count()):
					var arrs := am.surface_get_arrays(s)
					var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
					for v in verts:
						if first:
							out = AABB(v, Vector3.ZERO)
							first = false
						else:
							out = out.expand(v)
	return out

func _ready() -> void:
	var ps: PackedScene = load("res://assets/models/ekans.glb")
	var m := ps.instantiate()
	add_child(m)
	print("VERTEX_AABB pos=", _vertex_aabb(m).position, " size=", _vertex_aabb(m).size)
	print("CHAIN_AABB pos=", _merged_aabb(m).position, " size=", _merged_aabb(m).size)
	m.rotation.x = -PI / 2.0
	print("ROTX_-90 CHAIN_AABB pos=", _merged_aabb(m).position, " size=", _merged_aabb(m).size)
	m.rotation.x = PI / 2.0
	print("ROTX_+90 CHAIN_AABB pos=", _merged_aabb(m).position, " size=", _merged_aabb(m).size)
	# Which end is the head? Split the vertex AABB along its
	# long axis (Y) into 6 bins; the head bin carries the eye
	# geometry (denser / wider cross-section).
	var va := _vertex_aabb(m)
	print("LONG_AXIS bins (cross-section area per Y sixth):")
	var stack: Array = [m]
	var verts_all: Array = []
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c in cur.get_children():
			stack.append(c)
		if cur is MeshInstance3D and (cur as MeshInstance3D).mesh is ArrayMesh:
			var am := (cur as MeshInstance3D).mesh as ArrayMesh
			for s in range(am.get_surface_count()):
				var arrs := am.surface_get_arrays(s)
				for v in (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array):
					verts_all.append(v)
	for b in range(6):
		var lo := va.position.z + va.size.z * float(b) / 6.0
		var hi := va.position.z + va.size.z * float(b + 1) / 6.0
		var mn := Vector2(1e9, 1e9)
		var mx := Vector2(-1e9, -1e9)
		var cnt := 0
		for v in verts_all:
			if v.z >= lo and v.z < hi:
				cnt += 1
				mn.x = minf(mn.x, v.x)
				mx.x = maxf(mx.x, v.x)
				mn.y = minf(mn.y, v.y)
				mx.y = maxf(mx.y, v.y)
		print("  bin ", b, " z=[", snappedf(lo, 0.01), ",", snappedf(hi, 0.01), ") n=", cnt,
			" xspan=", snappedf(mx.x - mn.x, 0.001), " yspan=", snappedf(mx.y - mn.y, 0.001))
	get_tree().quit()
