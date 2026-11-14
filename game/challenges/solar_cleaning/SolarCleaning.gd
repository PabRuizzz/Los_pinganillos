extends Control
## Independent prototype: six panels, hold left mouse to clean, no timer.

signal cleaning_progress_changed(ratio: float)
signal cleaning_completed

const REQUIRED_RATIO := 0.9
@onready var stage: Control = $Stage
@onready var spray: Node2D = $Stage/WaterSpray
@onready var status: Label = $Stage/Status
var panels: Array[Control] = []
var completed := false
var _last_point := Vector2.ZERO
var _batching := false

func _ready() -> void:
	for panel in $Stage/Panels.get_children():
		panels.append(panel)
		panel.progress_changed.connect(_on_progress)
	resized.connect(_layout)
	_layout()
	reset()

func reset() -> void:
	_stop_spray()
	completed = false
	_batching = true
	for panel in panels:
		panel.reset()
	_batching = false
	_update_progress()

func _layout() -> void:
	var factor := minf(size.x / 900.0, size.y / 610.0)
	stage.scale = Vector2.ONE * factor
	stage.position = (size - Vector2(800, 520) * factor) / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		var point: Vector2 = stage.get_global_transform_with_canvas().affine_inverse() * event.position
		spray.position = point
		spray.visible = Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * event.position)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not completed:
				spray.spraying = true
				_last_point = point
				_clean_segment(point, point)
			else:
				_stop_spray()
		elif event is InputEventMouseMotion and spray.spraying:
			if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				_stop_spray()
			else:
				_clean_segment(_last_point, point)
				_last_point = point
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset()
		elif event.keycode == KEY_ESCAPE:
			_stop_spray()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stop_spray()

func _stop_spray() -> void:
	if is_instance_valid(spray):
		spray.spraying = false

func _clean_segment(from: Vector2, to: Vector2) -> void:
	if not spray.spraying or completed:
		return
	_batching = true
	# Interpolation prevents fast mouse movements from leaving gaps in the spray.
	var steps := maxi(1, ceili(from.distance_to(to) / maxf(spray.radius * 0.5, 1.0)))
	for i in range(steps + 1):
		var point := from.lerp(to, float(i) / steps)
		for panel in panels:
			panel.clean_circle(point - panel.position, spray.radius)
	_batching = false
	_update_progress()

func _on_progress(_clean: int, _total: int) -> void:
	if not _batching:
		_update_progress()

func _update_progress() -> void:
	var total_clean := 0
	var total_cells := 0
	var ready_panels := 0
	var percentages := PackedStringArray()
	for i in panels.size():
		var panel = panels[i]
		total_clean += panel.clean_count
		total_cells += panel.states.size()
		percentages.append("P%d: %d%%" % [i + 1, floori(panel.clean_ratio() * 100.0 + 0.001)])
		if panel.clean_ratio() >= REQUIRED_RATIO:
			ready_panels += 1
	status.text = " · ".join(percentages) + "\n%d/6 paneles al 90%% · R: reiniciar" % ready_panels
	cleaning_progress_changed.emit(float(total_clean) / maxi(total_cells, 1))
	if ready_panels == 6 and not completed:
		completed = true
		_stop_spray()
		status.text = "¡Limpieza completada! Los 6 paneles están al menos al 90%.\nR: reiniciar"
		cleaning_completed.emit()
