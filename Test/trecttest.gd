extends Node2D

func _ready() -> void:
	await get_tree().process_frame
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2(396, 96)
	b.size = Vector2(396, 96)
	b.position = Vector2(60, 60)
	add_child(b)
	var pt := TextureRect.new()
	pt.texture = load("res://assets/portraits/bulbasaur.png")
	pt.position = Vector2(8, 8)
	pt.size = Vector2(80, 80)
	pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pt)
	print("TRECT tex size=", pt.texture.get_size(), " rect=", pt.size,
		" global=", pt.get_global_rect())
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/trect.png")
	print("TRECT saved")
	get_tree().quit()
