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
	# Reserve room for fixed HUD, frames and per-panel readouts.
	var fit := minf(screen.x * 0.94 / (bounds.size.x + 16.0), screen.y * 0.74 / (bounds.size.y + 40.0))
	zoom = Vector2.ONE * fit
	offset = Vector2.ZERO
	force_update_scroll()
