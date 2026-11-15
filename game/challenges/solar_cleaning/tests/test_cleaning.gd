extends SceneTree

const Scene = preload("res://game/challenges/solar_cleaning/solar_cleaning.tscn")
var failures := 0
var victories := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func mouse(game: Node, point: Vector2, pressed: bool, motion := false) -> void:
	var event: InputEventMouse
	if motion:
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event = move
	else:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		event = button
	event.position = game.stage.get_global_transform_with_canvas() * point
	root.push_input(event, true)

func _run() -> void:
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.cleaning_completed.connect(func(): victories += 1)
	check(game.panels.size() == 6, "Exactly six panels are required")
	for panel in game.panels:
		check(panel.states.size() == 100 and panel.clean_count == 0, "Each panel must start with 100 dirty cells")
		check(panel.get_node("Cells").get_child_count() == 100, "Grid cells must be saved editable scene instances")
		check(panel.has_node("Artwork"), "Each panel needs an artwork slot")
	var panel = game.panels[0]
	check(panel.clean_circle(Vector2(-100, -100), 5) == 0, "A circle outside the panel must not clean")
	check(panel.clean_circle(Vector2(12, 8), 1) == 1, "A small circle should clean one cell")
	check(panel.get_node("Cells").get_child(0).clean, "The visual cell must match the logical state")
	check(panel.clean_circle(Vector2(12, 8), 1) == 0 and panel.clean_count == 1, "Repeated contact must not count twice")
	panel.reset()
	check(panel.clean_circle(Vector2(-2, -2), 2.5) == 0, "Circle bounding-box overlap alone must not clean a corner")
	check(panel.clean_circle(Vector2(-2, -2), 3) == 1, "True circle-corner intersection should clean")
	game.reset()
	mouse(game, Vector2(60, 110), false, true)
	check(panel.clean_count == 0, "Hover without left mouse must not clean")
	mouse(game, Vector2(30, 110), true)
	check(panel.clean_count > 0 and game.spray.spraying, "Press should start cleaning")
	mouse(game, Vector2(220, 110), true, true)
	for x in 10:
		check(panel.is_clean_at(Vector2i(x, 1)), "Fast dragging must clean the whole traversed row")
	mouse(game, Vector2(220, 110), false)
	var count: int = panel.clean_count
	mouse(game, Vector2(120, 210), false, true)
	check(not game.spray.spraying and panel.clean_count == count, "Release must stop cleaning")
	game.reset()
	mouse(game, Vector2(260, 265), true)
	for p in game.panels:
		check(p.clean_count == 0, "The gap between panels must not count as surface")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.spray.spraying, "Focus loss must stop water")
	# 89 cells on every panel: 89%, no completion. Then exactly 90 on each.
	game.reset()
	for p in game.panels:
		for index in 89:
			p.clean_circle((Vector2(index % 10, index / 10) + Vector2(0.5, 0.5)) * p.cell_size, 1)
	check(not game.completed and victories == 0, "89 percent must not win")
	for i in 5:
		var p = game.panels[i]
		p.clean_circle(Vector2(9.5, 8.5) * p.cell_size, 1)
	check(not game.completed, "All six panels must reach the threshold")
	game.panels[5].clean_circle(Vector2(9.5, 8.5) * panel.cell_size, 1)
	check(game.completed and victories == 1, "Exactly 90 percent on each panel must win once")
	game._update_progress()
	check(victories == 1, "Completion must not emit twice")
	mouse(game, Vector2(20, 230), true)
	check(not game.spray.spraying, "Water must stay off after completion")
	game.reset()
	for p in game.panels:
		check(p.clean_count == 0, "Reset must dirty every panel")
	# Scale changes must preserve the cursor collision coordinates.
	for dimensions in [Vector2(1280, 720), Vector2(800, 600), Vector2(900, 1100)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = Vector2i(dimensions)
		game._layout()
		game.get_node("Camera2D").fit_panels()
		game.reset()
		mouse(game, game.panels[5].position + Vector2(120, 80), true)
		check(game.panels[5].clean_count > 0 and game.panels[0].clean_count == 0, "Scaled input must clean the targeted panel only")
		mouse(game, Vector2.ZERO, false)
	var camera = game.get_node("Camera2D")
	camera.auto_frame_panels = false
	var hud_transform: Transform2D = game.status.get_global_transform_with_canvas()
	for zoom_value in [0.7, 1.0, 1.5]:
		camera.position = Vector2(450, 300)
		camera.zoom = Vector2.ONE * zoom_value
		camera.force_update_scroll()
		game.reset()
		mouse(game, game.panels[1].position + Vector2(120, 80), true)
		check(game.panels[1].clean_count > 0 and game.panels[0].clean_count == 0, "Cleaning must follow camera pan and zoom")
		check(game.status.get_global_transform_with_canvas().is_equal_approx(hud_transform), "HUD must not move with camera")
		mouse(game, Vector2.ZERO, false)
	game.reset()
	var moved_panel = game.panels[0]
	moved_panel.rotation = 0.2
	moved_panel.scale = Vector2(0.8, 1.1)
	var center: Vector2 = game.stage.to_local(moved_panel.get_global_transform() * (moved_panel.size / 2.0))
	mouse(game, center, true)
	check(moved_panel.clean_count > 0, "Rotated and scaled panel nodes must remain cleanable")
	mouse(game, Vector2.ZERO, false)
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	moved_panel.get_node("Artwork").texture = texture
	game.reset()
	check(moved_panel.get_node("Artwork").texture == texture, "Restart must preserve frontend artwork")
	check(moved_panel.get_node("Cells").get_child(0).reveal_panel_artwork, "Clean cells must reveal the panel image")
	game.queue_free()
	await process_frame
	print("SOLAR CLEANING: circle geometry, dirty/clean states, hold/release, fast motion, six panels, 89/90 percent, focus, restart, resize. Failures: ", failures)
	quit(0 if failures == 0 else 1)
