extends Control

signal piece_placed


const PIECE_SCENES := {
	10: preload("res://game/challenges/electrical_repair/pieces/Horizontal.tscn"),
	5: preload("res://game/challenges/electrical_repair/pieces/Vertical.tscn"),
	3: preload("res://game/challenges/electrical_repair/pieces/NorthEast.tscn"),
	9: preload("res://game/challenges/electrical_repair/pieces/NorthWest.tscn"),
	6: preload("res://game/challenges/electrical_repair/pieces/SouthEast.tscn"),
	12: preload("res://game/challenges/electrical_repair/pieces/SouthWest.tscn"),
	7: preload("res://game/challenges/electrical_repair/pieces/T_East.tscn"),
	11: preload("res://game/challenges/electrical_repair/pieces/T_North.tscn"),
	13: preload("res://game/challenges/electrical_repair/pieces/T_West.tscn"),
	14: preload("res://game/challenges/electrical_repair/pieces/T_South.tscn"),
	15: preload("res://game/challenges/electrical_repair/pieces/Cross.tscn"),
}

var cells: Dictionary = {}
var pieces: Array[Control] = []
var cell_size := 80.0
var dragged: Control = null
var drag_offset := Vector2.ZERO
var hovered: Control = null
var debug_hitboxes := false
var locked := false

func build(puzzle: Dictionary) -> void:
	cancel_drag()
	for child in $Pieces.get_children():
		$Pieces.remove_child(child)
		child.queue_free()
	cells.clear()
	pieces.clear()
	locked = false
	$PreviewPieces.hide()
	size = Vector2(puzzle.width, puzzle.height) * cell_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for y in int(puzzle.height):
		for x in int(puzzle.width):
			var coordinate := Vector2i(x, y)
			var cell = $Cells.get_node("Cell_%d_%d" % [x, y])
			cell.occupant = null
			cell.terminal_side = 0
			cell.highlighted = false
			cell.tooltip_text = ""
			cell.configure(coordinate, cell_size)
			cell.blocked = puzzle.get("blocked", {}).has(coordinate)
			if cell.blocked:
				cell.tooltip_text = "Blocked tile: cannot hold cables"
			cell.debug_hitbox = debug_hitboxes
			cell.queue_redraw()
			cells[coordinate] = cell
	mark_terminal(puzzle.source, "I", true)
	for i in puzzle.targets.size():
		mark_terminal(puzzle.targets[i], str(i + 1), false)
	for y in int(puzzle.height):
		for x in int(puzzle.width):
			var mask: int = puzzle.pieces[y * int(puzzle.width) + x]
			if mask == 0 or cells[Vector2i(x, y)].blocked:
				continue
			var piece = PIECE_SCENES[mask].instantiate()
			piece.configure(mask, cell_size)
			piece.debug_hitbox = debug_hitboxes
			piece.drag_requested.connect(_start_drag)
			$Pieces.add_child(piece)
			pieces.append(piece)
			_place(piece, cells[Vector2i(x, y)])

func mark_terminal(terminal: Dictionary, label: String, source: bool) -> void:
	var cell = cells[terminal.cell]
	cell.terminal_side = terminal.side
	cell.terminal_label = label
	cell.is_source = source
	cell.queue_redraw()

func get_masks() -> Dictionary:
	var masks: Dictionary = {}
	for coordinate in cells:
		var cell = cells[coordinate]
		if cell.is_occupied and not cell.blocked:
			masks[coordinate] = cell.occupant.connections
	return masks

func show_connections(energized: Dictionary) -> void:
	for piece in pieces:
		piece.energized = energized.has(piece.cell.coordinates)
		piece.queue_redraw()

func set_debug_hitboxes(enabled: bool) -> void:
	debug_hitboxes = enabled
	for cell in cells.values():
		cell.debug_hitbox = enabled
		cell.queue_redraw()
	for piece in pieces:
		piece.debug_hitbox = enabled
		piece.queue_redraw()

func cell_at(viewport_point: Vector2) -> Control:
	for cell in cells.values():
		if cell.contains_global(viewport_point):
			return cell
	return null

func _start_drag(piece: Control) -> void:
	if locked or is_instance_valid(dragged):
		return
	dragged = piece
	drag_offset = get_local_mouse_position() - piece.position
	piece.dragging = true
	piece.z_index = 10
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piece.queue_redraw()

func _process(_delta: float) -> void:
	if not is_instance_valid(dragged):
		return
	dragged.position = get_local_mouse_position() - drag_offset
	var target := cell_at(get_viewport().get_mouse_position())
	if target != hovered:
		_clear_hover()
		hovered = target
		if is_instance_valid(hovered) and not hovered.blocked:
			hovered.highlighted = true
			hovered.queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(dragged):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(cell_at(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_drag()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_drag()

func _place(piece: Control, cell: Control) -> void:
	assert(not cell.blocked, "Blocked cells cannot hold pieces")
	cell.occupant = piece
	piece.cell = cell
	piece.position = cell.position + Vector2.ONE * 5.0

func _finish_drag(target: Control) -> void:
	var piece = dragged
	var origin = piece.cell
	var moved: bool = is_instance_valid(target) and not target.blocked and target != origin
	if moved:
		var displaced = target.occupant
		origin.occupant = null
		if is_instance_valid(displaced):
			_place(displaced, origin)
		_place(piece, target)
	else:
		_place(piece, origin)
	piece.dragging = false
	piece.z_index = 0
	piece.mouse_filter = Control.MOUSE_FILTER_STOP
	piece.queue_redraw()
	dragged = null
	_clear_hover()
	if moved:
		piece_placed.emit()

func cancel_drag() -> void:
	if is_instance_valid(dragged):
		_finish_drag(null)

func _clear_hover() -> void:
	if is_instance_valid(hovered):
		hovered.highlighted = false
		hovered.queue_redraw()
	hovered = null
