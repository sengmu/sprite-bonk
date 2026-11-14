## U5 fit probe: does a ScrollContainer report its child's full
## minimum size into get_combined_minimum_size()? The result
## panel's P5 fit scale is dragged down if it does (the scroll
## holds the extended statistics below the fold).
extends SceneTree

func _init() -> void:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var top := Label.new()
	top.text = "top"
	top.custom_minimum_size = Vector2(100, 50)
	vb.add_child(top)
	var sc := ScrollContainer.new()
	vb.add_child(sc)
	var inner := VBoxContainer.new()
	sc.add_child(inner)
	for i in 12:
		var l := Label.new()
		l.text = "row"
		l.custom_minimum_size = Vector2(100, 80)
		inner.add_child(l)
	var btn := Button.new()
	btn.text = "ok"
	btn.custom_minimum_size = Vector2(100, 60)
	vb.add_child(btn)
	root.add_child(panel)
	print("PROBE inner combined min: ", inner.get_combined_minimum_size())
	print("PROBE scroll combined min: ", sc.get_combined_minimum_size())
	print("PROBE vb combined min: ", vb.get_combined_minimum_size())
	print("PROBE panel combined min: ", panel.get_combined_minimum_size())
	quit()
