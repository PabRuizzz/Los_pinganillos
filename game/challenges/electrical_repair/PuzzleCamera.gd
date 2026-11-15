extends Camera2D
## Match the board framing to the HUD's design space, independently of window size.

@export var auto_frame_board := true
@export_node_path("Control") var board_path := NodePath("../Board")

func _ready() -> void:
	get_viewport().size_changed.connect(fit_board)
	fit_board.call_deferred()

func fit_board() -> void:
	if not auto_frame_board:
		return
	var board := get_node_or_null(board_path) as Control
	if board == null:
		return
	var view_size := get_viewport_rect().size
	var factor := minf(view_size.x / 940.0, view_size.y / 1180.0)
	global_position = board.get_global_transform() * (board.size / 2.0)
	zoom = Vector2.ONE * factor * 0.9 # Leave room for the external power boxes.
	offset = Vector2.ZERO
	force_update_scroll()

