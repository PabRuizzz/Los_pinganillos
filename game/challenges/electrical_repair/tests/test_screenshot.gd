extends SceneTree
## Regression fixture transcribed from the user's screenshot.
const GameScene = preload("res://game/challenges/electrical_repair/electrical_repair.tscn")
const Generator = preload("res://game/challenges/electrical_repair/PuzzleGenerator.gd")
const START := [[9,3,6,9,0,3,12,0],[0,-1,-1,0,0,0,5,6],[10,-1,0,-1,0,6,0,3],[0,0,0,-1,-1,-1,0,0],[0,10,10,-1,9,0,5,0],[0,0,0,10,0,12,7,10],[0,6,10,10,10,10,9,0],[0,13,0,10,0,12,0,0]]
const SOLUTION := [[6,10,10,10,10,13,0,0],[5,0,0,0,0,5,0,0],[9,0,0,0,0,3,12,0],[0,0,0,0,0,0,3,12],[0,0,0,0,6,10,10,9],[0,0,0,0,3,12,0,6],[0,0,0,0,0,7,10,9],[0,6,10,10,10,9,0,0]]
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var blocked: Dictionary = {}
	var solution: Dictionary = {}
	var pieces: Array[int] = []
	for y in 8:
		for x in 8:
			var coordinate := Vector2i(x, y)
			if START[y][x] == -1:
				blocked[coordinate] = true
			pieces.append(maxi(START[y][x], 0))
			if SOLUTION[y][x] != 0:
				solution[coordinate] = SOLUTION[y][x]
	var puzzle := {
		"width": 8, "height": 8, "minimum_pieces": 10,
		"blocked": blocked, "solution": solution, "pieces": pieces,
		"source": {"cell": Vector2i(7, 5), "side": 2},
		"targets": [
			{"cell": Vector2i(0, 2), "side": 8},
			{"cell": Vector2i(5, 0), "side": 1},
			{"cell": Vector2i(1, 7), "side": 4}
		]
	}
	check(Generator.new().has_valid_solution(puzzle), "Screenshot inventory must exactly match the proposed solution")
	var game = GameScene.instantiate()
	game.puzzle_seed = 42
	root.add_child(game)
	await process_frame
	game.puzzle = puzzle
	game.board.build(puzzle)
	game.moves = 21
	game.completed = false
	game._validate()
	var before: Dictionary = game.validator.validate(game.board.get_masks(), puzzle.source, puzzle.targets, 10)
	check(before.reached == 1 and before.energized.size() == 10, "Reconstructed board must match screenshot: 1/3 destinations, 10 energized pieces")
	var legal_moves := 0
	for coordinate in solution:
		var wanted: int = solution[coordinate]
		var target = game.board.cells[coordinate]
		if target.is_occupied and target.occupant.connections == wanted:
			continue
		var candidate: Control = null
		for piece in game.board.pieces:
			if piece.connections == wanted and int(solution.get(piece.cell.coordinates, 0)) != wanted:
				candidate = piece
				break
		check(candidate != null, "A required piece is missing")
		if candidate == null:
			break
		game.board._start_drag(candidate)
		game.board._finish_drag(target)
		legal_moves += 1
		check(target.occupant == candidate, "Legal move was rejected")
		if game.completed:
			break
	var after: Dictionary = game.validator.validate(game.board.get_masks(), puzzle.source, puzzle.targets, 10)
	check(game.completed and after.reached == 3 and after.energized.size() == 28, "All 28 pieces must form the completed circuit")
	for coordinate in blocked:
		check(not game.board.cells[coordinate].is_occupied, "Solution occupies a blocked cell")
	print("SCREENSHOT: inventory 28; initial 1/3 and 10 energized; final ", after.reached, "/3 and ", after.energized.size(), " energized; legal moves ", legal_moves, "; failures ", failures)
	if "--capture" in OS.get_cmdline_user_args():
		game.get_node("Interface/HUD/Content/Rules").hide()
		game.get_node("Interface/HUD/Content/Title").text = "Solución de tu tablero"
		game.get_node("Interface/HUD/Content/Instructions").text = "Mismas 28 piezas, sin girarlas ni cambiar los bloqueos."
		game.get_node("Interface/HUD/Content/Legend").text = "Filas 1–8 de arriba abajo · Columnas A–H de izquierda a derecha"
		for i in 8:
			var column := Label.new()
			column.text = String.chr(65 + i)
			column.position = game.board.position + Vector2(i * 80 + 28, -70)
			column.add_theme_font_size_override("font_size", 25)
			column.mouse_filter = Control.MOUSE_FILTER_IGNORE
			game.add_child(column)
			var row := Label.new()
			row.text = str(i + 1)
			row.position = game.board.position + Vector2(-65, i * 80 + 22)
			row.add_theme_font_size_override("font_size", 25)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			game.add_child(row)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/Users/pafer/.codex/visualizations/2026/11/14/01a1daf5-92e8-78a0-a533-67040176684f/solucion-captura.png")
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
