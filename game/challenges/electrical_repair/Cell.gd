@tool
extends Control
## A board slot owns occupancy and its own rectangular mouse hitbox.

var coordinates := Vector2i.ZERO
var occupant: Control = null
var debug_hitbox := false
var terminal_side := 0
var terminal_label := ""
var is_source := false
var highlighted := false
@export var blocked := false:
	set(value):
		blocked = value
		queue_redraw()

var is_occupied: bool:
	get:
		return is_instance_valid(occupant)

func configure(coords: Vector2i, cell_size: float) -> void:
	coordinates = coords
	position = Vector2(coords) * cell_size
	size = Vector2.ONE * cell_size
	mouse_filter = Control.MOUSE_FILTER_STOP

# Point is in viewport coordinates; includes Camera2D pan, zoom and rotation.
func contains_global(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * point)

func _draw() -> void:
	var base := Color("192637") if (coordinates.x + coordinates.y) % 2 == 0 else Color("1c2b3d")
	if blocked:
		base = Color("36303b")
	if highlighted:
		base = Color("344d65")
	draw_rect(Rect2(Vector2.ZERO, size), base)
	draw_rect(Rect2(Vector2.ZERO, size), Color("50647b"), false, 1.0)
	if blocked:
		var margin := Vector2.ONE * 24.0
		draw_line(margin, size - margin, Color("b57680"), 3.0, true)
		draw_line(Vector2(size.x - margin.x, margin.y), Vector2(margin.x, size.y - margin.y), Color("b57680"), 3.0, true)
	if terminal_side != 0:
		var center := size / 2.0
		var direction := Vector2.ZERO
		match terminal_side:
			1: direction = Vector2.UP
			2: direction = Vector2.RIGHT
			4: direction = Vector2.DOWN
			8: direction = Vector2.LEFT
		var color := Color("56e0b5") if is_source else Color("ffcb75")
		var edge := center + direction * size.x * 0.5
		draw_line(edge - direction * 14.0, edge + direction * 12.0, color, 6.0, true)
		draw_circle(edge + direction * 18.0, 14.0, color)
		draw_string(ThemeDB.fallback_font, edge + direction * 18.0 + Vector2(-5, 6), terminal_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("101722"))
	if debug_hitbox:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("5bd9ff"), false, 2.0)
