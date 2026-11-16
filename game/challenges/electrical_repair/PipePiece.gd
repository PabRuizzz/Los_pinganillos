@tool
extends Control
## Bits: N=1, E=2, S=4, W=8. Every piece has a separate Control hitbox.

signal drag_requested(piece: Control)

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const TYPES := {
	10: "Horizontal cable", 5: "Vertical cable",
	3: "Up-right bend", 9: "Up-left bend",
	6: "Down-right bend", 12: "Down-left bend",
	7: "Right-facing T", 11: "Up-facing T", 13: "Left-facing T", 14: "Down-facing T",
	15: "Cross"
}

@export_flags("Norte", "Este", "Sur", "Oeste") var connections := 10:
	set(value):
		connections = value
		queue_redraw()
var cell: Control = null
var energized := false
var dragging := false
var debug_hitbox := false
var _last_texture: Texture2D

func _ready() -> void:
	var artwork := get_node_or_null("Artwork")
	if artwork != null:
		artwork.item_rect_changed.connect(queue_redraw)

	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var artwork := get_node_or_null("Artwork")
		if artwork != null and artwork.texture != _last_texture:
			_last_texture = artwork.texture
			queue_redraw()

func configure(mask: int, cell_size: float) -> void:
	connections = mask
	size = Vector2.ONE * (cell_size - 10.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = TYPES.get(mask, "Cable")

func connects(side: int) -> bool:
	return (connections & side) != 0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_requested.emit(self)
		accept_event()

func _draw() -> void:
	var center := size / 2.0
	var color := Color("56e0b5") if energized else Color("d4e3f1")
	if dragging:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.5, 0.7, 0.25))
	var artwork := get_node_or_null("Artwork")
	var draw_lines: bool = artwork == null or artwork.texture == null
	for entry in [[NORTH, Vector2.UP], [EAST, Vector2.RIGHT], [SOUTH, Vector2.DOWN], [WEST, Vector2.LEFT]]:
		if draw_lines and connects(entry[0]):
			draw_line(center, center + entry[1] * (size.x / 2.0 + 5.0), color, 5.0, true)
	if draw_lines:
		draw_circle(center, 4.0, color)
	else:
		artwork.modulate = color if energized else Color.WHITE
	if debug_hitbox:
		draw_rect(Rect2(Vector2.ZERO, size), Color("ff75ce"), false, 2.0)
