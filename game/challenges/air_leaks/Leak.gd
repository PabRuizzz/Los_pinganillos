extends Node2D

signal state_changed
enum State { HIDDEN, FOUND, REPAIRED }
var state: State = State.HIDDEN
var airflow_tween: Tween

func _ready() -> void:
	_refresh()

func discover() -> bool:
	if state != State.HIDDEN:
		return false
	state = State.FOUND
	_refresh()
	var reveal := create_tween()
	$Visual.scale = Vector2.ONE * 0.72
	reveal.tween_property($Visual, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	airflow_tween = create_tween().set_loops()
	airflow_tween.tween_property($Visual/Airflow, "modulate:a", 0.32, 0.45)
	airflow_tween.tween_property($Visual/Airflow, "modulate:a", 1.0, 0.45)
	state_changed.emit()
	return true

func patch() -> bool:
	if state != State.FOUND:
		return false
	state = State.REPAIRED
	if airflow_tween:
		airflow_tween.kill()
	set_drop_preview(false)
	_refresh()
	state_changed.emit()
	return true

func _refresh() -> void:
	$Visual.visible = state == State.FOUND

func set_drop_preview(active: bool) -> void:
	$Visual/DropRing.visible = active
	$Visual/Artwork.modulate = Color(1.3, 1.2, 1.05) if active else Color.WHITE
