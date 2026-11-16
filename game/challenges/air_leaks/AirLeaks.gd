extends Control

signal completed
enum Difficulty { FACIL, NORMAL }
@export var difficulty: Difficulty = Difficulty.NORMAL
var click_radius := 24.0
var dragged: Control
var preview_leak: Node2D
var drag_pointer := -2 # -2: none, -1: mouse, >= 0: touch.
var finished := false
var touch_id := -1
const PANEL_DESIGN_SIZE := Vector2(900, 400)
var leak_locations: Array[Vector2] = []
var installed_patches: Dictionary = {}
@onready var content: Control = $Content
@onready var patches := [$Content/Patch1, $Content/Patch2, $Content/Patch3]
@onready var habitat: Control = $Content/Habitat
@onready var detector = $Content/Habitat/Detector
@onready var leaks := [$Content/Habitat/Leak1, $Content/Habitat/Leak2, $Content/Habitat/Leak3]

func _ready() -> void:
	resized.connect(_layout)
	_layout()
	click_radius = 40.0 if difficulty == Difficulty.FACIL else 24.0
	detector.detection_range = 500.0 if difficulty == Difficulty.FACIL else 260.0
	detector.lock_radius = click_radius
	detector.targets = leaks
	detector.reading_changed.connect(_show_reading)
	habitat.gui_input.connect(_habitat_input)
	habitat.mouse_exited.connect(_hide_detector)
	$ReactionTimer.timeout.connect(_clear_reaction)
	# Six separated regions, shuffled without replacement, with random local jitter.
	var positions: Array[Vector2] = []
	for panel: Control in $Content/Habitat/Panels.get_children():
		var center := panel.get_rect().get_center()
		var jitter := Vector2(randf_range(-10, 10), randf_range(-10, 10))
		positions.append((center + jitter) / PANEL_DESIGN_SIZE)
	positions.shuffle()
	for i in leaks.size():
		leak_locations.append(positions[i])
		leaks[i].position = positions[i] * habitat.size
		leaks[i].state_changed.connect(_update_status)
	_update_status()

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var factor := minf(size.x / 960.0, size.y / 640.0)
	content.scale = Vector2.ONE * factor
	content.size = size / factor
	for patch in patches:
		var home: Vector2 = patch.tray_offset + Vector2(content.size.x / 2.0, content.size.y - 640.0)
		patch.set_home(home, patch != dragged)
	for i in leak_locations.size():
		var leak = leaks[i]
		leak.position = leak_locations[i] * habitat.size
		if installed_patches.has(leak):
			installed_patches[leak].attach_to(leak.get_global_transform_with_canvas().origin)


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
	detector.show()
	detector.scanning = true

func _hide_detector() -> void:
	detector.stop()
	detector.hide()

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
		if candidate.discover():
			# Reveal the X immediately instead of covering it with the sensor.
			_hide_detector()
		_update_status()
		$Content/Reaction.text = "Leak found. Drag a patch onto it."
	else:
		$Content/Reaction.text = "No unsealed leak here."
	$ReactionTimer.start()

func _update_status() -> void:
	var repaired := 0
	for leak in leaks:
		if leak.state == leak.State.REPAIRED:
			repaired += 1
	$Content/Counter.text = "Leaks sealed · %d/3" % repaired
	if repaired == 3 and not finished:
		finished = true
		_hide_detector()
		$ReactionTimer.stop()
		$Content/Reaction.text = "Habitat sealed"
		completed.emit()

func _show_reading(strength: float) -> void:
	$Content/Reading.text = "Detector signal: %d%%" % roundi(strength * 100.0)

func _clear_reaction() -> void:
	if not finished:
		$Content/Reaction.text = "Scan the wall and click where you suspect a leak."

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
		_move_patch(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_patch(event.position, event.index)
		elif drag_pointer == event.index:
			_drop_patch(event.position, event.canceled)
	elif event is InputEventScreenDrag and drag_pointer == event.index:
		_move_patch(event.position)
	if is_instance_valid(dragged):
		get_viewport().set_input_as_handled()

func _begin_patch(point: Vector2, pointer: int) -> void:
	if is_instance_valid(dragged):
		return
	for patch in patches:
		if not patch.used and patch.contains_point(point):
			dragged = patch
			drag_pointer = pointer
			_hide_detector()
			patch.begin_drag(point)
			return

func _patch_target(point: Vector2) -> Node2D:
	var local_point := habitat.get_global_transform_with_canvas().affine_inverse() * point
	for leak in leaks:
		if leak.state == leak.State.FOUND and local_point.distance_to(leak.position) <= click_radius:
			return leak
	return null

func _set_drop_preview(leak: Node2D) -> void:
	if preview_leak == leak:
		return
	if is_instance_valid(preview_leak):
		preview_leak.set_drop_preview(false)
	preview_leak = leak
	if is_instance_valid(preview_leak):
		preview_leak.set_drop_preview(true)

func _move_patch(point: Vector2) -> void:
	dragged.move_drag(point)
	_set_drop_preview(_patch_target(point))

func _drop_patch(point: Vector2, cancel := false) -> void:
	if not is_instance_valid(dragged):
		return
	var patch = dragged
	dragged = null
	drag_pointer = -2
	var leak := _patch_target(point) if not cancel else null
	_set_drop_preview(null)
	if leak != null:
		patch.attach_to(leak.get_global_transform_with_canvas().origin)
		installed_patches[leak] = patch
		leak.patch()
		get_viewport().set_input_as_handled()
		return
	patch.return_home()
	$Content/Reaction.text = "Place the patch over a marked leak."
	$ReactionTimer.start()
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(dragged):
		_drop_patch(Vector2.ZERO, true)
