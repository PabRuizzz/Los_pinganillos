extends Node

signal task_started(station, task_name)
signal task_finished(station, task_name, time_spent)
signal day_finished

var current_station = ""
var current_task = ""
var current_task_time_cost = 0
var day_active = false

func start_day():
	# Reiniciamos el tiempo en el Autoload de tiempo
	SimulationTime.tiempo_jornada = SimulationTime.MAX_JOURNEY_TIME
	SimulationTime.simulation_time_changed.emit()
	
	day_active = true
	current_station = ""
	current_task = ""
	current_task_time_cost = 0
	Resources.oxygen = 100


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


func finish_day():
	day_active = false
	SimulationTime.day += 1

	# 1. Planta de energía (modifica energía)
	var estado_energia = StationCost.energy_plant_state
	var cambio_energia = StationCost.station_costs["energy_plant"][estado_energia]["energy"]
	Resources.modify_energy(cambio_energia)

	# 2. Soporte vital (modifica energía)
	var estado_soporte = StationCost.life_support_state
	var cambio_soporte = StationCost.station_costs["life_support"][estado_soporte]["energy"]
	Resources.modify_energy(cambio_soporte)

	# 3. Estación de agua (modifica agua)
	var estado_agua = StationCost.water_station_state
	var cambio_agua = StationCost.station_costs["water_station"][estado_agua]["water"]
	Resources.modify_water(cambio_agua)

	# 4. Invernadero (modifica comida)
	var estado_comida = StationCost.greenhouse_state
	var cambio_comida = StationCost.station_costs["greenhouse"][estado_comida]["food"]
	Resources.modify_food(cambio_comida)

	day_finished.emit()
