extends Node2D
## Standalone entry point. Hosts can listen to puzzle_completed without autoloads.

signal puzzle_started(seed_value: int, destinations: int)
signal puzzle_completed(moves: int, seed_value: int)

const GeneratorScript = preload("res://game/challenges/electrical_repair/PuzzleGenerator.gd")
const ValidatorScript = preload("res://game/challenges/electrical_repair/ConnectionValidator.gd")


@export var puzzle_seed: int = -1 ## -1 = random; nonnegative = reproducible.

var generator = GeneratorScript.new()
var validator = ValidatorScript.new()
var rng := RandomNumberGenerator.new()
@onready var board: Control = $Board
@onready var content: Control = $Interface/HUD/Content
@onready var status_label: Label = $Interface/HUD/Content/Status
@onready var detail_label: Label = $Interface/HUD/Content/Details
var puzzle: Dictionary
var moves := 0
var current_seed: int
var completed := false

func _ready() -> void:
	board.piece_placed.connect(_on_piece_placed)
	$Interface/HUD/Content/DebugHitboxes.toggled.connect(board.set_debug_hitboxes)
	get_viewport().size_changed.connect(_layout)
	_layout()
	start_new_puzzle()

func start_new_puzzle() -> void:
	if puzzle_seed < 0:
		rng.randomize()
	else:
		rng.seed = puzzle_seed
	current_seed = rng.seed
	puzzle = generator.generate(rng, 8, 8)
	if puzzle.is_empty():
		status_label.text = "Could not generate a circuit."
		return
	board.build(puzzle)
	_layout()
	moves = 0
	completed = false
	_validate()
	puzzle_started.emit(current_seed, 1)

func _on_piece_placed() -> void:
	moves += 1
	_validate()

func _validate() -> void:
	var result: Dictionary = validator.validate(board.get_masks(), puzzle.source, puzzle.targets, puzzle.minimum_pieces)
	board.show_connections(result.energized)
	detail_label.text = "%d/%d output · %d cables connected (min. 10) · %d moves" % [result.reached, puzzle.targets.size(), result.energized.size(), moves]
	if result.complete:
		status_label.text = "Circuit complete!"
		status_label.modulate = Color("56e0b5")
		board.locked = true
		if not completed:
			completed = true
			puzzle_completed.emit(moves, current_seed)
	else:
		status_label.text = "Connect I to the output on the opposite side"
		status_label.modulate = Color("e4edf6")

func _layout() -> void:
	if not is_instance_valid(content):
		return
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x / 940.0, viewport_size.y / 1180.0)
	content.scale = Vector2.ONE * factor
	# Scale a fixed design canvas: moving Board or other children in the editor
	# is preserved at runtime instead of being automatically recentered.
	content.position = viewport_size / 2.0 - Vector2(450, 570) * factor
