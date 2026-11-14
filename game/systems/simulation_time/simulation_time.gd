extends Node

signal simulation_time_changed
const MAX_JOURNEY_TIME = 480
var tiempo_jornada = 480
var day = 1

func modify_time(cantidad):
	tiempo_jornada = clampi(tiempo_jornada + cantidad, 0, MAX_JOURNEY_TIME)
	simulation_time_changed.emit()
