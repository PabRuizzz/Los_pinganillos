@tool
extends Control
## A board slot owns occupancy and its own rectangular mouse hitbox.

@export var blocked_texture: Texture2D
@export var source_texture: Texture2D
@export var target_texture: Texture2D
var default_texture: Texture2D

func _ready() -> void:
	default_texture = $Artwork.texture
	queue_redraw()

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
	if not has_node("Artwork"):
		return
	$Artwork.texture = blocked_texture if blocked else default_texture
	$Artwork.modulate = Color(1.3, 1.45, 1.6) if highlighted else Color.WHITE
	$Terminal.visible = terminal_side != 0
	if terminal_side != 0:
		# Power boxes sit outside the board, with their socket facing its edge.
		var direction := Vector2.ZERO
		match terminal_side:
			1: direction = Vector2.UP
			2: direction = Vector2.RIGHT
			4: direction = Vector2.DOWN
			8: direction = Vector2.LEFT
		$Terminal.texture = source_texture if is_source else target_texture
		$Terminal.size = Vector2(64.0, 50.0)
		$Terminal.pivot_offset = $Terminal.size / 2.0
		var inward_angle := (-direction).angle()
		$Terminal.rotation = inward_angle if is_source else inward_angle - PI
		$Terminal.position = size / 2.0 + direction * (size.x / 2.0 + 34.0) - $Terminal.size / 2.0
	if debug_hitbox:
		$Artwork.modulate.a = 0.5
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("5bd9ff"), false, 2.0)
