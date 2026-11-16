extends Node

const STARTING_SCENE := "res://game/stations/campament/campament.tscn"

func _ready() -> void:
	get_window().title = "Five Nights on Mars"
	_start_direct_scene.call_deferred()

func _start_direct_scene() -> void:
	# Running a world scene directly in Godot should still start a day.
	if get_tree().current_scene != null and not get_tree().has_group("main_menu"):
		start_game()

func enter_game() -> Error:
	_reset_rover_progress()
	var tree := get_tree()
	var error := tree.change_scene_to_file(STARTING_SCENE)
	if error == OK:
		tree.scene_changed.connect(start_game, CONNECT_ONE_SHOT)
	return error

func start_game() -> void:
	# Events owns the daily plan and reacts to TaskExecution.day_started.
	TaskExecution.start_day()


# Cada partida nueva (menú principal o "Reiniciar") empieza sin muestras descubiertas
# y con el rover en la base. El progreso de muestras solo dura una partida.
func _reset_rover_progress() -> void:
	SampleDiscoverySave.new().clear()
	RoverSampleDiscoveryBridge.clear_unreported()
	RoverExpeditionController.reset_run_state()
