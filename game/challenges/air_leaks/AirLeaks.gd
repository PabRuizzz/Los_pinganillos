extends Control

signal completed
enum Difficulty { FACIL, NORMAL }
@export var difficulty: Difficulty = Difficulty.NORMAL
const MIN_SEPARATION := 160.0
var click_radius := 24.0
var dragged: Control
var drag_pointer := -2 # -2: none, -1: mouse, >= 0: touch.
var finished := false
var touch_id := -1
@onready var patches := [$Content/Patch1, $Content/Patch2, $Content/Patch3]
@onready var habitat: Control = $Content/Habitat
@onready var detector = $Content/Habitat/Detector
@onready var leaks := [$Content/Habitat/Leak1, $Content/Habitat/Leak2, $Content/Habitat/Leak3]

func _ready() -> void:
	resized.connect(_layout)
	_layout()
	click_radius = 40.0 if difficulty == Difficulty.FACIL else 24.0
	detector.detection_range = 500.0 if difficulty == Difficulty.FACIL else 260.0
	detector.targets = leaks
	detector.reading_changed.connect(_show_reading)
	habitat.gui_input.connect(_habitat_input)
	$ReactionTimer.timeout.connect(_clear_reaction)
	# Six separated regions, shuffled without replacement, with random local jitter.
	# Minimum possible spacing is 180, greater than MIN_SEPARATION.
	var positions: Array[Vector2] = []
	for y in [100.0, 300.0]:
		for x in [150.0, 450.0, 750.0]:
			positions.append(Vector2(x, y) + Vector2(randf_range(-10, 10), randf_range(-10, 10)))
	positions.shuffle()
	for i in leaks.size():
		leaks[i].position = positions[i]
		leaks[i].state_changed.connect(_update_status)
	_update_status()

func _layout() -> void:
	var factor := minf(size.x / 1000.0, size.y / 680.0)
	$Content.scale = Vector2.ONE * factor
	$Content.position = (size - Vector2(960, 640) * factor) / 2.0

func _habitat_input(event: InputEvent) -> void:
	if finished or is_instance_valid(dragged) or event.device == -1:
		return # Avoid duplicate emulated mouse events after touches.
	if event is InputEventMouseMotion and touch_id == -1:
		_move_detector(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_search(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_search(event.position)
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
	elif event is InputEventScreenDrag and event.index == touch_id:
		_move_detector(event.position)

func _move_detector(point: Vector2) -> void:
	detector.position = point.clamp(Vector2.ZERO, habitat.size)
	detector.scanning = true

func _search(point: Vector2) -> void:
	if finished:
		return
	_move_detector(point)
	var candidate: Node2D
	var distance := click_radius
	for leak in leaks:
		var separation: float = point.distance_to(leak.position)
		if leak.state != leak.State.REPAIRED and separation <= distance:
			candidate = leak
			distance = separation
	if candidate != null:
		candidate.discover()
		_update_status()
		$Content/Reaction.text = "Fuga encontrada. Arrastra un parche sobre ella."
	else:
		$Content/Reaction.text = "Aquí no hay ninguna fuga sin reparar."
	$ReactionTimer.start()

func _update_status() -> void:
	var repaired := 0
	for leak in leaks:
		if leak.state == leak.State.REPAIRED:
			repaired += 1
	$Content/Counter.text = "Fugas reparadas: %d/3" % repaired
	if repaired == 3 and not finished:
		finished = true
		detector.stop()
		$ReactionTimer.stop()
		$Content/Reaction.text = "¡Hábitat sellado!"
		completed.emit()

func _show_reading(strength: float) -> void:
	$Content/Reading.text = "Señal del detector: %d%%" % roundi(strength * 100.0)

func _clear_reaction() -> void:
	if not finished:
		$Content/Reaction.text = "Explora la pared y pulsa donde sospeches una fuga."

# Input positions are viewport coordinates; transform them through the canvas
# so moving/scaling Content never changes the hitboxes.
func _input(event: InputEvent) -> void:
	if finished or event.device == -1:
		return
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
		touch_id = -1
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_patch(event.position, -1)
		elif drag_pointer == -1:
			_drop_patch(event.position)
	elif event is InputEventMouseMotion and drag_pointer == -1:
		dragged.move_drag(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_patch(event.position, event.index)
		elif drag_pointer == event.index:
			_drop_patch(event.position, event.canceled)
	elif event is InputEventScreenDrag and drag_pointer == event.index:
		dragged.move_drag(event.position)
	if is_instance_valid(dragged):
		get_viewport().set_input_as_handled()

func _begin_patch(point: Vector2, pointer: int) -> void:
	if is_instance_valid(dragged):
		return
	for patch in patches:
		if not patch.used and patch.contains_point(point):
			dragged = patch
			drag_pointer = pointer
			detector.stop()
			patch.begin_drag(point)
			return

func _drop_patch(point: Vector2, cancel := false) -> void:
	if not is_instance_valid(dragged):
		return
	var patch = dragged
	dragged = null
	drag_pointer = -2
	var local_point := habitat.get_global_transform_with_canvas().affine_inverse() * point
	if not cancel:
		for leak in leaks:
			if leak.state == leak.State.FOUND and local_point.distance_to(leak.position) <= click_radius:
				patch.attach_to(leak.get_global_transform_with_canvas().origin)
				leak.patch()
				get_viewport().set_input_as_handled()
				return
	patch.return_home()
	$Content/Reaction.text = "Coloca el parche sobre una fuga descubierta."
	$ReactionTimer.start()
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(dragged):
		_drop_patch(Vector2.ZERO, true)
