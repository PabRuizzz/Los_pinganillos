extends Node2D

signal state_changed
enum State { HIDDEN, FOUND, REPAIRED }
var state: State = State.HIDDEN

func _ready() -> void:
	_refresh()

func discover() -> bool:
	if state != State.HIDDEN:
		return false
	state = State.FOUND
	_refresh()
	state_changed.emit()
	return true

func patch() -> bool:
	if state != State.FOUND:
		return false
	state = State.REPAIRED
	_refresh()
	state_changed.emit()
	return true

func _refresh() -> void:
	$Visual.visible = state != State.HIDDEN
	$Visual/Placeholder.color = Color.ORANGE if state == State.FOUND else Color.SEA_GREEN
	$Visual/Symbol.text = "!" if state == State.FOUND else "OK"
