extends RefCounted
## Build a random spanning tree, retain only root-to-target paths, then add
## external terminal ports. All retained cells therefore have 2..4 connections.

const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SIDES := [1, 2, 4, 8]
const OPPOSITE := [4, 8, 1, 2]
const MINIMUM_PIECES := 10
const Validator = preload("res://game/challenges/electrical_repair/ConnectionValidator.gd")
const VALID_MASKS := [10, 5, 3, 9, 6, 12, 7, 11, 13, 14, 15]

func generate(rng: RandomNumberGenerator, width: int = 8, height: int = 8) -> Dictionary:
	assert(width >= 6 and height >= 6)
	for attempt in 1000:
		var puzzle := _generate_candidate(rng, width, height)
		if not puzzle.is_empty() and has_valid_solution(puzzle):
			return puzzle
	push_error("Could not generate a puzzle with the requested constraints")
	return {}

func has_valid_solution(puzzle: Dictionary) -> bool:
	# A connected witness plus an identical piece inventory proves solvability:
	# every pair of playable slots can be swapped without rotation or sliding.
	var solution: Dictionary = puzzle.solution
	var blocked: Dictionary = puzzle.blocked
	var width: int = puzzle.width
	var height: int = puzzle.height
	if puzzle.pieces.size() != width * height or solution.size() < MINIMUM_PIECES:
		return false
	var expected: Array[int] = []
	var actual: Array[int] = []
	for coordinate in solution:
		if coordinate.x < 0 or coordinate.y < 0 or coordinate.x >= width or coordinate.y >= height:
			return false
		if blocked.has(coordinate) or not VALID_MASKS.has(solution[coordinate]):
			return false
		expected.append(solution[coordinate])
	for index in puzzle.pieces.size():
		var mask: int = puzzle.pieces[index]
		if mask == 0:
			continue
		var coordinate := Vector2i(index % width, index / width)
		if blocked.has(coordinate) or not VALID_MASKS.has(mask):
			return false
		actual.append(mask)
	expected.sort()
	actual.sort()
	if expected != actual:
		return false
	var result: Dictionary = Validator.new().validate(solution, puzzle.source, puzzle.targets, MINIMUM_PIECES)
	return result.complete and result.energized.size() == solution.size()

func _generate_candidate(rng: RandomNumberGenerator, width: int, height: int) -> Dictionary:
	var blocked := _generate_obstacles(rng, width, height)
	if blocked.is_empty():
		return {}
	var boundary: Array[Dictionary] = []
	# Exclude corners so every terminal has an unambiguous outward port.
	for x in range(1, width - 1):
		boundary.append({"cell": Vector2i(x, 0), "side": 1})
		boundary.append({"cell": Vector2i(x, height - 1), "side": 4})
	for y in range(1, height - 1):
		boundary.append({"cell": Vector2i(0, y), "side": 8})
		boundary.append({"cell": Vector2i(width - 1, y), "side": 2})
	shuffle(boundary, rng)
	var source: Dictionary = boundary.pop_back()
	var opposite_side: int = OPPOSITE[SIDES.find(int(source.side))]
	var opposite_boundary: Array[Dictionary] = []
	for terminal in boundary:
		if terminal.side == opposite_side:
			opposite_boundary.append(terminal)
	var targets: Array[Dictionary] = []
	targets.append(opposite_boundary[rng.randi_range(0, opposite_boundary.size() - 1)])
	var root: Vector2i = source.cell
	var parents: Dictionary = {root: root}
	var frontier: Array[Vector2i] = [root]
	while not frontier.is_empty():
		var index := rng.randi_range(0, frontier.size() - 1)
		var current := frontier[index]
		var candidates: Array[Vector2i] = []
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if neighbor.x >= 0 and neighbor.x < width and neighbor.y >= 0 and neighbor.y < height and not parents.has(neighbor) and not blocked.has(neighbor):
				candidates.append(neighbor)
		if candidates.is_empty():
			frontier.remove_at(index)
		else:
			var next := candidates[rng.randi_range(0, candidates.size() - 1)]
			parents[next] = current
			frontier.append(next)
	var solution: Dictionary = {}
	for target in targets:
		if not parents.has(target.cell):
			return {}
		var current: Vector2i = target.cell
		while current != root:
			var parent: Vector2i = parents[current]
			var direction_index := DIRECTIONS.find(parent - current)
			solution[current] = int(solution.get(current, 0)) | SIDES[direction_index]
			solution[parent] = int(solution.get(parent, 0)) | OPPOSITE[direction_index]
			current = parent
		solution[target.cell] = int(solution[target.cell]) | int(target.side)
	solution[root] = int(solution[root]) | int(source.side)
	if solution.size() < MINIMUM_PIECES or solution.size() >= width * height - blocked.size():
		return {}
	var pieces: Array[int] = []
	var playable: Array[int] = []
	var inventory: Array[int] = []
	for y in height:
		for x in width:
			pieces.append(0)
			if not blocked.has(Vector2i(x, y)):
				playable.append(y * width + x)
				inventory.append(int(solution.get(Vector2i(x, y), 0)))
	shuffle(inventory, rng)
	for i in playable.size():
		pieces[playable[i]] = inventory[i]
	# Leave the start empty so a shuffle can never be solved on arrival.
	var start_index := root.y * width + root.x
	if pieces[start_index] != 0:
		for index in playable:
			if pieces[index] == 0:
				pieces[index] = pieces[start_index]
				pieces[start_index] = 0
				break
	return {"source": source, "targets": targets, "solution": solution, "pieces": pieces, "width": width, "height": height, "blocked": blocked, "minimum_pieces": MINIMUM_PIECES}

func _generate_obstacles(rng: RandomNumberGenerator, width: int, height: int) -> Dictionary:
	var blocked: Dictionary = {}
	# Two separate orthogonally connected groups, leaving border ports free.
	for group_index in 2:
		var available: Array[Vector2i] = []
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var coordinate := Vector2i(x, y)
				var separated := not blocked.has(coordinate)
				for direction in DIRECTIONS:
					if blocked.has(coordinate + direction):
						separated = false
				if separated:
					available.append(coordinate)
		if available.is_empty():
			return {}
		var group: Array[Vector2i] = [available[rng.randi_range(0, available.size() - 1)]]
		var group_size := rng.randi_range(2, 5)
		while group.size() < group_size:
			var candidates: Array[Vector2i] = []
			for coordinate in group:
				for direction in DIRECTIONS:
					var neighbor: Vector2i = coordinate + direction
					if available.has(neighbor) and not group.has(neighbor) and not candidates.has(neighbor):
						candidates.append(neighbor)
			if candidates.is_empty():
				return {}
			group.append(candidates[rng.randi_range(0, candidates.size() - 1)])
		for coordinate in group:
			blocked[coordinate] = true
	return blocked

func shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary = values[i]
		values[i] = values[j]
		values[j] = temporary
