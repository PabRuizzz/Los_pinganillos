extends SceneTree

const Generator = preload("res://game/challenges/electrical_repair/PuzzleGenerator.gd")
const Validator = preload("res://game/challenges/electrical_repair/ConnectionValidator.gd")
const Piece = preload("res://game/challenges/electrical_repair/PipePiece.gd")
const PuzzleScene = preload("res://game/challenges/electrical_repair/electrical_repair.tscn")

var failures := 0
var victories := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var generator = Generator.new()
	var validator = Validator.new()
	var rng := RandomNumberGenerator.new()
	var seen_types: Dictionary = {}
	var seen_layouts: Dictionary = {}
	for seed_value in 1000:
		rng.seed = seed_value
		var data: Dictionary = generator.generate(rng, 8, 8)
		check(data.pieces.size() == 64, "Board must have 64 slots")
		check(data.solution.size() >= 10, "Solution must contain at least 10 pieces")
		var pending: Dictionary = data.blocked.duplicate()
		var groups := 0
		while not pending.is_empty():
			var queue: Array = [pending.keys()[0]]
			pending.erase(queue[0])
			var head := 0
			while head < queue.size():
				var coordinate: Vector2i = queue[head]
				head += 1
				check(not data.solution.has(coordinate), "Solution must avoid obstacles")
				check(data.pieces[coordinate.y * 8 + coordinate.x] == 0, "Shuffled pieces must avoid obstacles")
				for direction in Generator.DIRECTIONS:
					var neighbor: Vector2i = coordinate + direction
					if pending.has(neighbor):
						pending.erase(neighbor)
						queue.append(neighbor)
			check(queue.size() >= 2 and queue.size() <= 5, "Blocked component must have 2 to 5 cells")
			groups += 1
		check(groups == 2, "Expected two separated obstacle groups")
		check(not data.blocked.has(data.source.cell), "Start must be free")
		check(validator.validate(data.solution, data.source, data.targets, 10).complete, "Minimum-piece solution must win")
		check(data.targets.size() == 1, "Exactly one exit is required")
		check(int(data.targets[0].side) == Generator.OPPOSITE[Generator.SIDES.find(int(data.source.side))], "Exit must be on the opposite border")
		check(validator.validate(data.solution, data.source, data.targets).complete, "Generated solution is disconnected: %d" % seed_value)
		var expected: Array = data.solution.values()
		var actual: Array = []
		for mask in data.pieces:
			if mask != 0:
				actual.append(mask)
		for mask in expected:
			check(Piece.TYPES.has(mask), "Unsupported connection mask")
			seen_types[mask] = true
		expected.sort()
		actual.sort()
		check(expected == actual, "Shuffle changed the exact piece inventory")
		seen_layouts[hash(data.solution)] = true
		var broken: Dictionary = data.solution.duplicate()
		broken.erase(data.source.cell)
		check(not validator.validate(broken, data.source, data.targets).complete, "Missing source must fail")
		for target in data.targets:
			broken = data.solution.duplicate()
			broken[target.cell] = int(broken[target.cell]) & ~int(target.side)
			check(not validator.validate(broken, data.source, data.targets).complete, "Every target must have an outward port")
	check(seen_types.size() == 6, "A single route uses straights and the four corners")
	check(seen_layouts.size() > 950, "Generated routes should vary")
	# Adjacent cables must agree on the connecting edge.
	var source := {"cell": Vector2i(0, 0), "side": 8}
	var targets := [{"cell": Vector2i(1, 0), "side": 2}]
	check(not validator.validate({Vector2i(0, 0): 10, Vector2i(1, 0): 3}, source, targets).complete, "One-way adjacency must not conduct")
	check(validator.validate({Vector2i(0, 0): 10, Vector2i(1, 0): 10}, source, targets).complete, "Reciprocal adjacency should conduct")
	check(not validator.validate({Vector2i(0, 0): 10, Vector2i(1, 0): 10}, source, targets, 10).complete, "Short circuits must not meet the 10-piece minimum")
	var game = PuzzleScene.instantiate()
	game.puzzle_seed = 42
	root.add_child(game)
	await process_frame
	check(game.get_node("Board/Cells").get_child_count() == 64, "Editor scene must contain all 64 cell nodes")
	check(not game.get_node("Board/PreviewPieces").visible, "Editor samples must be hidden during play")
	var original_position: Vector2 = game.board.position
	game.board.position += Vector2(45, -25)
	game._layout()
	game.start_new_puzzle()
	check(game.board.position == original_position + Vector2(45, -25), "Editor layout changes must survive layout and restart")
	game.board.position = original_position
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	var sample = load("res://game/challenges/electrical_repair/pieces/Cross.tscn").instantiate()
	var artwork: TextureRect = sample.get_node("Artwork")
	artwork.texture = texture
	sample.configure(15, 80)
	root.add_child(sample)
	await process_frame
	check(artwork.texture == texture and artwork.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Artwork must survive configuration without intercepting dragging")
	sample.queue_free()
	game.puzzle_completed.connect(func(_moves: int, _seed_value: int): victories += 1)
	for seed_value in 50:
		game.puzzle_seed = seed_value
		game.start_new_puzzle()
		check(not game.completed, "Puzzle must start unsolved")
	game.puzzle_seed = 42
	game.start_new_puzzle()
	var board = game.board
	var first = board.pieces[0]
	var second = board.pieces[1]
	var origin = first.cell
	var other = second.cell
	board._start_drag(first)
	board._finish_drag(other)
	check(first.cell == other and second.cell == origin, "Occupied drop must swap both pieces")
	check(other.occupant == first and origin.occupant == second, "Swap occupancy must match piece references")
	check(game.moves == 1, "Successful swap should emit one move")
	var empty: Control = null
	for cell in board.cells.values():
		if not cell.is_occupied and not cell.blocked:
			empty = cell
			break
	board._start_drag(first)
	board._finish_drag(empty)
	check(first.cell == empty and not other.is_occupied, "Empty drop must free the old slot")
	board._start_drag(first)
	first.position = Vector2(-500, -500)
	board._finish_drag(null)
	check(first.cell == empty and first.position == empty.position + Vector2.ONE * 5.0, "Outside drop must return to origin")
	check(game.moves == 2, "Invalid drop must not count as a move")
	var blocked_cell = board.cells[game.puzzle.blocked.keys()[0]]
	board._start_drag(first)
	board._finish_drag(blocked_cell)
	check(first.cell == empty and not blocked_cell.is_occupied, "Blocked drop must return to origin")
	check(game.moves == 2, "Blocked drop must not count as a move")
	board._start_drag(first)
	board.cancel_drag()
	check(board.dragged == null and first.mouse_filter == Control.MOUSE_FILTER_STOP, "Cancel must restore hitbox")
	board.set_debug_hitboxes(true)
	check(first.debug_hitbox and empty.debug_hitbox, "Debug should cover cells and pieces")
	var camera: Camera2D = game.get_node("Camera2D")
	var initial_camera_position := camera.position
	var initial_zoom := camera.zoom
	var hud_transform: Transform2D = game.status_label.get_global_transform_with_canvas()
	for zoom_value in [0.7, 1.2, 1.8]:
		camera.position = initial_camera_position + Vector2(85, -45)
		camera.zoom = Vector2.ONE * zoom_value
		camera.force_update_scroll()
		await process_frame
		for cell in board.cells.values():
			var screen_center: Vector2 = cell.get_global_transform_with_canvas() * (cell.size / 2.0)
			check(board.cell_at(screen_center) == cell, "Hitboxes must follow camera pan and zoom")
		check(game.status_label.get_global_transform_with_canvas().is_equal_approx(hud_transform), "Camera must not move the HUD")
		var target: Control = null
		for cell in board.cells.values():
			if not cell.blocked and not cell.is_occupied:
				target = cell
				break
		var from: Vector2 = first.get_global_transform_with_canvas() * (first.size / 2.0)
		var to: Vector2 = target.get_global_transform_with_canvas() * (target.size / 2.0)
		var motion := InputEventMouseMotion.new()
		motion.position = from
		root.push_input(motion, true)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = from
		root.push_input(press, true)
		check(board.dragged == first, "Mouse press must pick the piece through camera transform")
		motion = InputEventMouseMotion.new()
		motion.position = to
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = to
		root.push_input(release, true)
		check(first.cell == target, "Mouse release must place at the camera-transformed destination")
	camera.position = initial_camera_position
	camera.zoom = initial_zoom
	camera.force_update_scroll()
	game._layout()
	check(camera.position == initial_camera_position and camera.zoom == initial_zoom, "HUD layout must preserve camera settings")
	# Arrange the known solution using only legal moves/swaps.
	for coordinate in game.puzzle.solution:
		var wanted: int = game.puzzle.solution[coordinate]
		var cell = board.cells[coordinate]
		if cell.is_occupied and cell.occupant.connections == wanted:
			continue
		var candidate: Control = null
		for piece in board.pieces:
			if piece.connections == wanted and int(game.puzzle.solution.get(piece.cell.coordinates, 0)) != wanted:
				candidate = piece
				break
		check(candidate != null, "Exact inventory must allow restoring solution")
		if candidate != null:
			board._start_drag(candidate)
			board._finish_drag(cell)
		if game.completed:
			break
	check(game.completed and board.locked, "Legal solving moves must trigger victory")
	check(victories == 1, "Victory signal must fire exactly once")
	game._validate()
	check(victories == 1, "Repeated validation must not repeat victory")
	game.start_new_puzzle()
	check(not game.completed and not board.locked and game.moves == 0, "Restart must reset state")
	game.queue_free()
	await process_frame
	# Real viewport resizing, including wide, small and portrait embedded views.
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	root.add_child(view)
	var framed = PuzzleScene.instantiate()
	framed.puzzle_seed = 42
	view.add_child(framed)
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(900, 1100), Vector2i(2560, 1440)]:
		view.size = dimensions
		await process_frame
		await process_frame
		var frame_transform: Transform2D = framed.board.get_global_transform_with_canvas()
		var center: Vector2 = frame_transform * (framed.board.size / 2.0)
		check(center.distance_to(Vector2(dimensions) / 2.0) < 1.0, "Auto camera must center the board after resizing")
		var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
		for corner in [Vector2(-35, -35), Vector2(675, 675)]:
			check(screen.has_point(frame_transform * corner), "Board and terminal markers must fit in the viewport")
		for label_path in ["Interface/HUD/Content/Title", "Interface/HUD/Content/NewCircuit", "Interface/HUD/Content/DebugHitboxes"]:
			var control: Control = framed.get_node(label_path)
			var transform := control.get_global_transform_with_canvas()
			check(screen.has_point(transform * Vector2.ZERO) and screen.has_point(transform * control.size), "HUD must fit after resize")
	var manual_camera = framed.get_node("Camera2D")
	manual_camera.auto_frame_board = false
	manual_camera.position = Vector2(700, 600)
	manual_camera.zoom = Vector2(0.9, 0.9)
	view.size = Vector2i(1024, 768)
	await process_frame
	check(manual_camera.position == Vector2(700, 600) and manual_camera.zoom == Vector2(0.9, 0.9), "Manual camera settings must survive resizing")
	view.queue_free()
	await process_frame
	print("Puzzle checks: 1000 seeds, obstacles, camera pan/zoom, mouse dragging, fixed HUD, swaps, victory, restart. Failures: ", failures)
	quit(0 if failures == 0 else 1)
