extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://game/challenges/solar_cleaning/solar_cleaning.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var victories := [0]
	game.cleaning_completed.connect(func(): victories[0] += 1)
	for panel in game.panels:
		assert(panel.states.size() == 400)
		assert(panel.get_node("Cells").get_child_count() == 400)
		assert(panel.get_node("Artwork").texture != null)
		assert(panel.dust_opacity == 0.58)
		# Clean one cell, then test the exact end condition without hundreds of refreshes.
		assert(panel.clean_circle(Vector2(6, 4), 1) == 1)
		assert(not panel.get_node("Cells").get_child(0).get_node("DirtyArtwork").visible)
		panel.states.fill(1)
		panel.states[399] = 0
		panel.clean_count = 399
		panel._refresh_cells()
		panel._update_readout()
		assert(panel.get_node("Readout").text == "99% LIMPIO")
	game._update_progress()
	assert(not game.completed)
	for i in 6:
		game.panels[i].clean_circle(Vector2(234, 156), 1)
		assert(game.completed == (i == 5))
	assert(victories[0] == 1)
	game._update_progress()
	assert(victories[0] == 1)
	game.reset()
	var camera = game.get_node("Camera2D")
	camera.auto_frame_panels = false
	camera.position += Vector2(40, 20)
	camera.zoom *= 1.2
	camera.force_update_scroll()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.panels[5].get_global_transform_with_canvas() * Vector2(120, 80)
	root.push_input(event, true)
	assert(game.panels[5].clean_count > 0 and game.panels[0].clean_count == 0)
	game.queue_free()
	await process_frame
	print("PASS: 400 cells/panel, transparent dust, 100% on all six panels, reset and camera input")
	quit()
