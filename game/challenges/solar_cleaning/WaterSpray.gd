extends Node2D

@export_range(4, 60) var radius := 24.0
var spraying := false:
	set(value):
		spraying = value
		queue_redraw()

func _draw() -> void:
	var color := Color("62dbff") if spraying else Color("e4edf6")
	if spraying:
		draw_circle(Vector2.ZERO, radius, Color(0.3, 0.8, 1.0, 0.18))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, color, 2.0, true)
