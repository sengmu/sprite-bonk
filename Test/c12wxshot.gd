extends Node
## Cycle 12 weather screenshots (standing tool): boots a real run,
## forces each weather state through set_weather, lets the GPU
## particles saturate, and saves one viewport PNG per state to
## Test/out/wx_<state>.png.

func _ready() -> void:
	var w = load("res://scenes/main.tscn").instantiate()
	add_child(w)
	await get_tree().process_frame
	await get_tree().process_frame
	w.start_game("charmander")
	for i in range(30):
		await get_tree().process_frame
	for wx in ["clear", "rain", "sun", "sand", "hail", "fog", "ash"]:
		w.set_weather(String(wx), 999.0)
		# Particles saturate by SIMULATED time: this VM crawls at a
		# few fps under llvmpipe, so give each state a long wall
		# window (on device at 60 fps this is ~2 s of frames).
		var tw := Time.get_ticks_msec()
		while Time.get_ticks_msec() - tw < 25000:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://Test/out/wx_%s.png" % String(wx))
		print("C12WXSHOT ", wx, " saved")
	get_tree().quit()
