extends Node

signal task_started(station, task_name)
signal task_finished(station, task_name, time_spent)
# Empezó un día: la jornada está completa y ya se pueden iniciar tareas.
# day es el número del día que empieza (SimulationTime.day).
signal day_started(day)
# Terminó un día. Al emitirse, los recursos diarios ya se aplicaron y
# SimulationTime.day ya es el día NUEVO; la jornada nueva aún no empieza
# (day_started llega justo después).
signal day_finished

var current_station = ""
var current_task = ""
var current_task_time_cost = 0
var day_active = false

# Empieza el día actual (SimulationTime.day). No hace nada si el día ya está
# activo, para que el reinicio diario no pueda ocurrir dos veces.
# Lo llaman main.gd (partida nueva) y finish_day() (día siguiente).
func start_day():
	if day_active:
		return

	# Reiniciamos el tiempo en el Autoload de tiempo
	SimulationTime.reset_daily_time()
	
	day_active = true
	current_station = ""
	current_task = ""
	current_task_time_cost = 0
	Resources.oxygen = 100
	day_started.emit(SimulationTime.day)


func start_task(station: String, task_name: String) -> bool:
	if not day_active or current_task != "":
		return false

	# Verificamos que la estación y la tarea existan para evitar caídas
	if not StationCost.station_costs.has(station) or not StationCost.station_costs[station].has(task_name):
		return false

	var costs = StationCost.station_costs[station][task_name]
	var time_cost = costs["time"]

	# 1. Revisamos si alcanza el tiempo en SimulationTime
	if time_cost > SimulationTime.tiempo_jornada:
		return false

	# 2. Revisamos si alcanzan los recursos en el Autoload Resources
	if Resources.energy < costs.get("energy", 0) or Resources.water < costs.get("water", 0) or Resources.food < costs.get("food", 0):
		return false

	current_station = station
	current_task = task_name
	current_task_time_cost = time_cost

	task_started.emit(current_station, current_task)
	return true


func finish_task():
	if current_task == "":
		return

	var finished_station = current_station
	var finished_name = current_task
	var spent = current_task_time_cost

	# Cambiamos el estado de la estación según la tarea realizada
	update_station_state(finished_station, finished_name)

	current_station = ""
	current_task = ""
	current_task_time_cost = 0

	# Descontamos el tiempo en el Autoload correspondiente
	SimulationTime.modify_time(-spent)
	task_finished.emit(finished_station, finished_name, spent)

	if SimulationTime.tiempo_jornada <= 0:
		finish_day()


# Libera la tarea actual sin aplicar efectos (por ejemplo, si el jugador sale con Esc).
func cancel_task():
	current_station = ""
	current_task = ""
	current_task_time_cost = 0


func update_station_state(station: String, task_name: String):
	var estado_actual = ""

	# Obtenemos el estado actual de la estación
	match station:
		"energy_plant":
			estado_actual = StationCost.energy_plant_state
		"life_support":
			estado_actual = StationCost.life_support_state
		"water_station":
			estado_actual = StationCost.water_station_state
		"greenhouse":
			estado_actual = StationCost.greenhouse_state
		_:
			return

	var nuevo_estado = estado_actual

	# Determinamos el nuevo estado según la tarea
	match task_name:
		"maintenance":
			if estado_actual == "DEGRADADO":
				nuevo_estado = "OPERATIVO"

		"repair":
			nuevo_estado = "OPERATIVO"

	# Guardamos el nuevo estado
	match station:
		"energy_plant":
			StationCost.energy_plant_state = nuevo_estado
		"life_support":
			StationCost.life_support_state = nuevo_estado
		"water_station":
			StationCost.water_station_state = nuevo_estado
		"greenhouse":
			StationCost.greenhouse_state = nuevo_estado


# Se puede terminar el día a petición del jugador solo si el día está activo
# y no hay ninguna tarea en curso (no se interrumpe una actividad a medias).
func can_end_day() -> bool:
	return day_active and current_task == ""


# Petición del jugador (botón "Terminar día" del HUD) para terminar el día antes
# de agotar la jornada. Usa el mismo finish_day() que el fin automático, así que
# los recursos diarios, el rover y los eventos del día siguiente pasan igual.
# Devuelve false, sin cambiar nada, si can_end_day() es false.
func request_end_day() -> bool:
	if not can_end_day():
		return false
	finish_day()
	return true


# Termina el día actual y empieza el siguiente. Se ejecuta una sola vez por día:
# si el día no está activo (ya terminó o nunca empezó) no hace nada.
# Lo llama finish_task() al agotarse la jornada y request_end_day() cuando el
# jugador termina el día antes de tiempo (los recursos diarios se aplican igual,
# no se pueden saltar).
#
# Orden:
#   1. day_active = false           -> no se pueden iniciar más tareas
#   2. se libera la tarea en curso  -> sin efectos ni costo de tiempo
#   3. Resources.apply_daily_station_changes() -> recursos del día que termina
#   4. SimulationTime.advance_day() -> SimulationTime.day ya es el día nuevo
#   5. day_finished                 -> p. ej. el rover revisa si le toca volver
#   6. start_day()                  -> jornada completa, oxígeno, day_started
func finish_day():
	if not day_active:
		return

	day_active = false
	cancel_task()
	Resources.apply_daily_station_changes()
	SimulationTime.advance_day()
	day_finished.emit()
	start_day()
