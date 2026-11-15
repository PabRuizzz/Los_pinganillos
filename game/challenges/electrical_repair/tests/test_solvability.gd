extends SceneTree

const Generator = preload("res://game/challenges/electrical_repair/PuzzleGenerator.gd")
const GameScene = preload("res://game/challenges/electrical_repair/electrical_repair.tscn")
var failures := 0
var minimum_inventory := 64
var maximum_inventory := 0
var completed_games := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var generator = Generator.new()
	var rng := RandomNumberGenerator.new()
	for seed_value in 10000:
		rng.seed = seed_value
		var puzzle: Dictionary = generator.generate(rng, 8, 8)
		check(not puzzle.is_empty(), "Generation failed: seed %d" % seed_value)
		if puzzle.is_empty():
			continue
		check(generator.has_valid_solution(puzzle), "Invalid solution: seed %d" % seed_value)
		check(puzzle.targets.size() == 1, "Generated level must have exactly one exit")
		var exit_port: Dictionary = puzzle.targets[0]
		check(int(exit_port.side) == Generator.OPPOSITE[Generator.SIDES.find(int(puzzle.source.side))], "Exit must face the opposite edge")
		var start: Vector2i = puzzle.source.cell
		var end: Vector2i = exit_port.cell
		if int(puzzle.source.side) in [1, 4]:
			check(absi(start.y - end.y) == 7, "North/south endpoints must lie on opposite rows")
		else:
			check(absi(start.x - end.x) == 7, "East/west endpoints must lie on opposite columns")
		minimum_inventory = mini(minimum_inventory, puzzle.solution.size())
		maximum_inventory = maxi(maximum_inventory, puzzle.solution.size())
		# Every witness edge must be reciprocal, or a declared external port.
		var ports: Dictionary = {puzzle.source.cell: puzzle.source.side}
		for terminal in puzzle.targets:
			ports[terminal.cell] = terminal.side
		for coordinate in puzzle.solution:
			for i in 4:
				if (int(puzzle.solution[coordinate]) & Generator.SIDES[i]) == 0:
					continue
				var neighbor: Vector2i = coordinate + Generator.DIRECTIONS[i]
				var reciprocal: bool = (int(puzzle.solution.get(neighbor, 0)) & Generator.OPPOSITE[i]) != 0
				check(reciprocal or int(ports.get(coordinate, 0)) == Generator.SIDES[i], "Dangling witness edge: seed %d" % seed_value)
		if seed_value % 2000 == 0:
			print("Validated generated puzzles: ", seed_value)
	# Reject deliberately damaged inventories and blocked solutions.
	rng.seed = 42
	var good: Dictionary = generator.generate(rng)
	var bad: Dictionary = good.duplicate(true)
	bad.pieces[bad.pieces.find(0)] = 15
	check(not generator.has_valid_solution(bad), "Extra piece must be rejected")
	bad = good.duplicate(true)
	for i in bad.pieces.size():
		if bad.pieces[i] != 0:
			bad.pieces[i] = 0
			break
	check(not generator.has_valid_solution(bad), "Missing piece must be rejected")
	bad = good.duplicate(true)
	bad.blocked[bad.source.cell] = true
	check(not generator.has_valid_solution(bad), "Blocked source must be rejected")
	# Reconstruct 200 solutions through the actual Board and its placement signals.
	var game = GameScene.instantiate()
	game.puzzle_seed = 0
	root.add_child(game)
	await process_frame
	for seed_value in 200:
		game.puzzle_seed = seed_value
		game.start_new_puzzle()
		var board = game.board
		check(not game.completed, "Starting shuffle must be unsolved")
		for coordinate in game.puzzle.solution:
			var wanted: int = game.puzzle.solution[coordinate]
			var target = board.cells[coordinate]
			if target.is_occupied and target.occupant.connections == wanted:
				continue
			var candidate: Control = null
			for piece in board.pieces:
				if piece.connections == wanted and int(game.puzzle.solution.get(piece.cell.coordinates, 0)) != wanted:
					candidate = piece
					break
			check(candidate != null, "No legal solving move: seed %d" % seed_value)
			if candidate == null:
				break
			board._start_drag(candidate)
			board._finish_drag(target)
			check(target.occupant == candidate, "Legal move failed: seed %d" % seed_value)
			if game.completed:
				break
		check(game.completed and board.locked, "Could not win: seed %d" % seed_value)
		if game.completed:
			completed_games += 1
		for coordinate in game.puzzle.blocked:
			check(not board.cells[coordinate].is_occupied, "Solving occupied an obstacle")
		await process_frame
	game.queue_free()
	await process_frame
	print("SOLVABILITY: 10000 generated puzzles; ", completed_games, "/200 games solved through legal moves; inventory range ", minimum_inventory, "..", maximum_inventory, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
