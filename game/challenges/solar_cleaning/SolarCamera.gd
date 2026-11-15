extends Camera2D

@export var auto_frame_panels := true

func _ready() -> void:
	get_viewport().size_changed.connect(fit_panels)
	fit_panels.call_deferred()

func fit_panels() -> void:
	if not auto_frame_panels:
		return
	var bounds := Rect2()
	var first := true
	for panel in get_node("../World/Panels").get_children():
		var rect: Rect2 = panel.get_global_rect()
		bounds = rect if first else bounds.merge(rect)
		first = false
	if first:
		return
	global_position = bounds.get_center()
	var screen := get_viewport_rect().size
	var factor := minf(screen.x / 900.0, screen.y / 610.0)
	var fit := minf(800.0 / maxf(bounds.size.x, 1), 370.0 / maxf(bounds.size.y, 1))
	zoom = Vector2.ONE * factor * fit
	offset = Vector2.ZERO
	force_update_scroll()
