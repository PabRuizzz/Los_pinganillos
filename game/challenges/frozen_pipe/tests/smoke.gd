extends SceneTree

func center(node: Control) -> Vector2:
	return node.get_global_transform_with_canvas() * (node.size / 2.0)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://game/challenges/frozen_pipe/frozen_pipe.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var repair = game.repair
	repair.set_process(false)
	assert(repair.requirements[0] != repair.requirements[1])
	var wrong = repair.pieces[repair.requirements[1]]
	var gap = repair.slots[0].get_node("Gap")
	repair._press(center(wrong), -1)
	repair._release(center(gap))
	await repair.animation.finished
	assert(not repair.installed[0] and wrong.position == repair.homes[wrong])
	var completions := [0]
	game.completed.connect(func(): completions[0] += 1)
	for i in 2:
		var piece = repair.pieces[repair.requirements[i]]
		repair._press(center(piece), i)
		repair._move(center(repair.slots[i].get_node("Gap")))
		repair._release(center(repair.slots[i].get_node("Gap")))
		await repair.animation.finished
		assert(repair.installed[i])
		for j in 3:
			var screw = repair.screws[i * 3 + j]
			repair._press(center(screw), -1)
			repair._process(2.0)
			repair._release(center(screw))
	assert(game.finished and completions[0] == 1)
	assert(not game.has_node("Content/PumpPhase"))
	game.queue_free()
	await process_frame
	var pumping = load("res://game/challenges/water_pumping/water_pumping.tscn").instantiate()
	root.add_child(pumping)
	await process_frame
	var pump = pumping.pump
	pump.set_process(false)
	assert(pump.get_node("Bar/Marker").size.y == 64.0)
	pump.marker = 0.5
	pump.pump()
	assert(pump.water > 0.0)
	var before_drain: float = pump.water
	pump._process(1.0)
	assert(is_equal_approx(pump.water, before_drain - pump.drain_per_second))
	assert(is_equal_approx(pump.get_node("Tank/Water").size.x, pump.get_node("Tank").size.x * pump.water))
	assert(pump.get_node("Tank/Water").position == Vector2.ZERO)
	assert(is_equal_approx(pump.green_width, 0.10))
	assert(not pump.has_node("Flow"))
	var previous: float = pump.water
	pump.cooldown = 0.0
	pump.marker = 0.0
	pump.pump()
	assert(pump.water < previous)
	for i in 6:
		pump.cooldown = 0.0
		pump.marker = 0.5
		pump.pump()
	assert(pumping.finished)
	pump._process(2.0)
	assert(pump.water == 1.0)
	pumping.queue_free()
	await process_frame
	print("PASS: two distinct repairs, wrong drop, screws, independent pumping and completion")
	quit()
