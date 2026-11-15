extends Node
## Fuente única del tiempo simulado: día actual y minutos de trabajo que quedan hoy.
## No decide cuándo termina el día (eso lo coordina TaskExecution); solo guarda el
## tiempo y avisa de sus cambios.

## El tiempo de trabajo restante cambió (tarea terminada o jornada reiniciada).
signal simulation_time_changed
## El tiempo de trabajo del día llegó a 0. Se emite una vez, al agotarse.
signal work_budget_exhausted
## El día simulado avanzó. new_day es el día que empieza.
signal day_advanced(new_day: int)

const MAX_JOURNEY_TIME = 480
var tiempo_jornada = 480
var day = 1

func modify_time(cantidad):
	var antes = tiempo_jornada
	tiempo_jornada = clampi(tiempo_jornada + cantidad, 0, MAX_JOURNEY_TIME)
	simulation_time_changed.emit()
	if antes > 0 and tiempo_jornada <= 0:
		work_budget_exhausted.emit()


## Devuelve la jornada a su tiempo completo (inicio de un día).
func reset_daily_time():
	tiempo_jornada = MAX_JOURNEY_TIME
	simulation_time_changed.emit()


## Pasa al día siguiente. Solo debe llamarlo TaskExecution.finish_day().
func advance_day():
	day += 1
	day_advanced.emit(day)


## Minutos de trabajo ya usados hoy.
func get_elapsed_time() -> int:
	return MAX_JOURNEY_TIME - tiempo_jornada


func is_work_budget_exhausted() -> bool:
	return tiempo_jornada <= 0
