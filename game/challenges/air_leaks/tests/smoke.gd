extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = point
	root.push_input(event, true)

func drag(patch: Control, target: Vector2) -> void:
	mouse(patch.get_global_transform_with_canvas() * (patch.size / 2.0), true)
	var motion := InputEventMouseMotion.new()
	motion.position = target
	root.push_input(motion, true)
	mouse(target, false)

func run() -> void:
	var game = load("res://game/challenges/air_leaks/air_leaks.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var count := [0]
	game.completed.connect(func(): count[0] += 1)
	var first = game.patches[0]
	# Hidden leaks reject patches and do not become discovered by a drop.
	drag(first, game.leaks[0].get_global_transform_with_canvas().origin)
	await first.animation.finished
	assert(not first.used and first.position == first.home)
	assert(game.leaks[0].state == game.leaks[0].State.HIDDEN)
	drag(first, Vector2.ZERO)
	await first.animation.finished
	assert(not first.used and first.position == first.home)
	for i in 3:
		var leak = game.leaks[i]
		var point: Vector2 = leak.get_global_transform_with_canvas().origin
		mouse(point, true)
		mouse(point, false)
		assert(leak.state == leak.State.FOUND)
		drag(game.patches[i], point)
		assert(game.patches[i].used)
		assert(leak.state == leak.State.REPAIRED)
	assert(game.finished and count[0] == 1)
	assert(not game.detector.scanning)
	game.queue_free()
	await process_frame
	print("PASS: invalid drops return, hidden leaks reject patches, three mouse drags complete once")
	quit()
