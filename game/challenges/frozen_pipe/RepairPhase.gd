extends Control

signal repaired
@export var seconds_per_screw := 1.5
@export var decay_per_second := 0.2
var active := false
var installed := [false, false]
var requirements: Array = []
var used_pieces: Array = []
var busy := false
var dragged: Control
var pointer := -2 # -2: none; -1: mouse; >= 0: touch index.
var pointer_position := Vector2.ZERO
var drag_offset := Vector2.ZERO
var held_screw := -1
var progress := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var homes: Dictionary = {}
var animation: Tween
@onready var pieces := $Pieces.get_children()
@onready var slots := [$Pipe1, $Pipe2]
@onready var screws := $Pipe1/Screws.get_children() + $Pipe2/Screws.get_children()

func start(piece_count: int) -> void:
	active = true
	installed = [false, false]
	used_pieces.clear()
	var choices := range(clampi(piece_count, 4, 5))
	choices.shuffle()
	requirements = choices.slice(0, 2)
	pointer = -2
	held_screw = -1
	busy = false
	progress = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	for i in pieces.size():
		var piece: Control = pieces[i]
		if not homes.has(piece):
			homes[piece] = piece.position
		piece.position = homes[piece]
		piece.visible = i < piece_count
		piece.modulate = Color.WHITE
	for i in slots.size():
		slots[i].get_node("Screws").hide()
		slots[i].get_node("Gap/Symbol").text = "HUECO\n" + pieces[requirements[i]].get_node("Symbol").text.get_slice("\n", 0)
		slots[i].get_node("Gap/Symbol").show()
	for screw in screws:
		screw.get_node("Progress").value = 0
		screw.get_node("Symbol").text = "+"
	$Hint.text = "Encaja las dos piezas indicadas y mantén pulsados sus 3 tornillos."

func _contains(node: Control, point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, node.size).has_point(
		node.get_global_transform_with_canvas().affine_inverse() * point)

func _input(event: InputEvent) -> void:
	if not active or event.device == -1:
		return # Ignore emulated mouse events following native touches.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position, -1)
		elif pointer == -1:
			_release(event.position)
	elif event is InputEventMouseMotion and pointer == -1:
		_move(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_press(event.position, event.index)
		elif pointer == event.index:
			_release(event.position)
	elif event is InputEventScreenDrag and pointer == event.index:
		_move(event.position)

func _press(point: Vector2, id: int) -> void:
	if pointer != -2 or busy:
		return
	pointer_position = point
	for i in screws.size():
		if installed[i / 3] and progress[i] < 1.0 and _contains(screws[i], point):
			pointer = id
			held_screw = i
			return
	for piece in pieces:
		if piece.visible and not used_pieces.has(piece) and _contains(piece, point):
			pointer = id
			dragged = piece
			dragged.z_index = 5
			drag_offset = $Pieces.get_global_transform_with_canvas().affine_inverse() * point - piece.position
			return

func _move(point: Vector2) -> void:
	pointer_position = point
	if is_instance_valid(dragged):
		dragged.position = $Pieces.get_global_transform_with_canvas().affine_inverse() * point - drag_offset

func _release(point: Vector2, cancel := false) -> void:
	if is_instance_valid(dragged):
		var piece := dragged
		dragged = null
		busy = true
		animation = create_tween()
		var target := -1
		for i in slots.size():
			if not cancel and not installed[i] and piece == pieces[requirements[i]] and _contains(slots[i].get_node("Gap"), point):
				target = i
		if target >= 0:
			installed[target] = true
			used_pieces.append(piece)
			# El arte de la pieza es transparente: se oculta el texto del hueco que tapa.
			slots[target].get_node("Gap/Symbol").hide()
			var gap: Control = slots[target].get_node("Gap")
			var center: Vector2 = gap.get_global_transform_with_canvas() * (gap.size / 2.0)
			var destination: Vector2 = $Pieces.get_global_transform_with_canvas().affine_inverse() * center - piece.size / 2.0
			animation.tween_property(piece, "position", destination, 0.18)
			animation.tween_property(piece, "modulate", Color("71edc2"), 0.12)
			animation.tween_property(piece, "modulate", Color.WHITE, 0.12)
			animation.tween_callback(func():
				slots[target].get_node("Screws").show()
				$Hint.text = "Mantén pulsado cada tornillo. Si sueltas antes, pierde progreso.")
		else:
			animation.tween_property(piece, "position", homes[piece], 0.22).set_trans(Tween.TRANS_SINE)
			animation.tween_property(piece, "position:x", homes[piece].x + 6, 0.05)
			animation.tween_property(piece, "position:x", homes[piece].x - 6, 0.05)
			animation.tween_property(piece, "position", homes[piece], 0.05)
		animation.tween_callback(func():
			piece.z_index = 0
			busy = false)
	pointer = -2
	held_screw = -1

func _process(delta: float) -> void:
	if not active or busy:
		return
	var secured := 0
	for i in screws.size():
		if not installed[i / 3]:
			continue
		if progress[i] < 1.0:
			if held_screw == i and _contains(screws[i], pointer_position):
				progress[i] = minf(1.0, progress[i] + delta / maxf(seconds_per_screw, 0.1))
			else:
				progress[i] = maxf(0.0, progress[i] - delta * decay_per_second)
		screws[i].get_node("Progress").value = progress[i] * 100.0
		if progress[i] >= 1.0:
			secured += 1
			screws[i].get_node("Symbol").text = "OK"
	if secured == 6:
		active = false
		pointer = -2
		held_screw = -1
		repaired.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release(pointer_position, true)
