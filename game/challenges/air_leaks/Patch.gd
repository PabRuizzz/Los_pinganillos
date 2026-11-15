extends Control

var used := false
var home := Vector2.ZERO
var tray_offset := Vector2.ZERO
var drag_offset := Vector2.ZERO
var animation: Tween

func _ready() -> void:
	tray_offset = position
	home = position

func set_home(point: Vector2, move_now: bool) -> void:
	home = point
	if move_now and not used:
		if is_instance_valid(animation):
			animation.kill()
		position = home

func contains_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(get_global_transform_with_canvas().affine_inverse() * point)

func begin_drag(point: Vector2) -> void:
	if is_instance_valid(animation):
		animation.kill()
	drag_offset = get_parent().get_global_transform_with_canvas().affine_inverse() * point - position
	z_index = 10

func move_drag(point: Vector2) -> void:
	position = get_parent().get_global_transform_with_canvas().affine_inverse() * point - drag_offset

func return_home() -> void:
	z_index = 0
	animation = create_tween()
	animation.tween_property(self, "position", home, 0.2).set_trans(Tween.TRANS_SINE)

func attach_to(point: Vector2) -> void:
	used = true
	z_index = 1
	position = get_parent().get_global_transform_with_canvas().affine_inverse() * point - size / 2.0
	$LoosePlate.hide()
	$SealedPlate.show()
