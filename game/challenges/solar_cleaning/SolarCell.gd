@tool
extends Control
## Reusable visual and hitbox; state changes are owned by SolarPanel.

@export var clean := false:
	set(value):
		clean = value
		_refresh()
var reveal_panel_artwork := false

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	if has_node("DirtyArtwork"):
		$DirtyArtwork.visible = not clean
		$CleanArtwork.visible = clean
	queue_redraw()

func _draw() -> void:
	if not clean:
		draw_rect(Rect2(Vector2.ZERO, size), Color("77604b"))
	elif not reveal_panel_artwork:
		draw_rect(Rect2(Vector2.ZERO, size), Color("347fba"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("263547"), false, 1.0)

func touches_circle(world_center: Vector2, radius: float) -> bool:
	# Exact circle/polygon contact also supports rotated or scaled panels.
	var transform := get_global_transform()
	var polygon := PackedVector2Array([
		transform * Vector2.ZERO, transform * Vector2(size.x, 0),
		transform * size, transform * Vector2(0, size.y)])
	if Geometry2D.is_point_in_polygon(world_center, polygon):
		return true
	for i in 4:
		var nearest := Geometry2D.get_closest_point_to_segment(world_center, polygon[i], polygon[(i + 1) % 4])
		if world_center.distance_squared_to(nearest) <= radius * radius:
			return true
	return false
