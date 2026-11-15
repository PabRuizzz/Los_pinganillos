extends Node

enum EventTypes {
	NONE,
	TORMENTA_ARENA,
	PERDIDA_PRESION,
	FALTA_ENERGIA,
	CONGELAMIENTO_TUBERIAS,
	HONGOS_INVERNADERO
}

var actual_EventType: EventTypes = EventTypes.NONE

# Bateria de emergencia
var emergency_battery = 100.0
var battery_active = false

# Tiempo para el congelamiento de tuberias
var pipe_timer = 120.0
var pipe_timer_active = false

const BATTERY_DRAIN_RATE = 1.0
const OXYGEN_DRAIN_RATE = 1.0
const WATER_DRAIN_RATE = 1.0
const PIPE_TIME_LIMIT = 120.0
var fungus_timer = 120.0
var fungus_timer_active = false
const FUNGUS_TIME_LIMIT = 120.0

signal event_started(type: EventTypes, title: String, message: String)
signal event_resolved(type: EventTypes)

# Titulo y mensaje que se muestran en la alerta de cada evento
const EVENT_INFO = {
	EventTypes.TORMENTA_ARENA: ["Tormenta de arena", "La planta de energía está averiada. Batería de emergencia activa."],
	EventTypes.PERDIDA_PRESION: ["Pérdida de presión", "El soporte vital falló. El oxígeno está bajando."],
	EventTypes.FALTA_ENERGIA: ["Falta de energía", "El invernadero está degradado. Repara la planta de energía."],
	EventTypes.CONGELAMIENTO_TUBERIAS: ["Tuberías congeladas", "Repara la estación de agua antes de 2 minutos."],
	EventTypes.HONGOS_INVERNADERO: ["Hongos en el invernadero", "Repara el invernadero antes de 2 minutos."],
}


func _ready():
	# Cuando se termina una tarea, revisamos si resolvio el evento activo
	TaskExecution.task_finished.connect(_on_task_finished)


func _on_task_finished(station, task_name, _time_spent):
	var before = actual_EventType
	check_task_completion(station, task_name)
	if before != EventTypes.NONE and actual_EventType == EventTypes.NONE:
		event_resolved.emit(before)


# Inicia un evento concreto y avisa a la UI
func trigger_event(type: EventTypes):
	if actual_EventType != EventTypes.NONE or not EVENT_INFO.has(type):
		return

	match type:
		EventTypes.TORMENTA_ARENA:
			tormenta_arena()
		EventTypes.PERDIDA_PRESION:
			perdida_presion()
		EventTypes.FALTA_ENERGIA:
			falta_energia()
		EventTypes.CONGELAMIENTO_TUBERIAS:
			congelamiento_tuberias()
		EventTypes.HONGOS_INVERNADERO:
			hongos_invernadero()

	var info = EVENT_INFO[type]
	event_started.emit(type, info[0], info[1])


# Con cierta probabilidad inicia un evento al azar
func trigger_random_event(chance := 0.5):
	if randf() < chance:
		trigger_event(EVENT_INFO.keys().pick_random())


func tormenta_arena():
	if actual_EventType != EventTypes.NONE:
		return

	actual_EventType = EventTypes.TORMENTA_ARENA

	StationCost.energy_plant_state = "AVERIADO"
	StationCost.life_support_state = "OPERATIVO"
	StationCost.water_station_state = "DEGRADADO"
	StationCost.greenhouse_state = "DEGRADADO"

	emergency_battery = 100.0
	battery_active = true


func perdida_presion():
	if actual_EventType != EventTypes.NONE:
		return
	actual_EventType = EventTypes.PERDIDA_PRESION

	StationCost.life_support_state = "AVERIADO"


func falta_energia():
	if actual_EventType != EventTypes.NONE:
		return
	actual_EventType = EventTypes.FALTA_ENERGIA

	StationCost.greenhouse_state = "DEGRADADO"


func congelamiento_tuberias():
	if actual_EventType != EventTypes.NONE:
		return
	actual_EventType = EventTypes.CONGELAMIENTO_TUBERIAS

	StationCost.water_station_state = "DEGRADADO"
	StationCost.greenhouse_state = "DEGRADADO"

	pipe_timer = PIPE_TIME_LIMIT
	pipe_timer_active = true

func hongos_invernadero():
	if actual_EventType != EventTypes.NONE:
		return

	actual_EventType = EventTypes.HONGOS_INVERNADERO

	StationCost.greenhouse_state = "DEGRADADO"

	fungus_timer = FUNGUS_TIME_LIMIT
	fungus_timer_active = true


func _process(delta):
	match actual_EventType:

		EventTypes.TORMENTA_ARENA:
			procesar_tormenta(delta)

		EventTypes.PERDIDA_PRESION:
			procesar_perdida_presion(delta)

		EventTypes.CONGELAMIENTO_TUBERIAS:
			procesar_congelamiento(delta)
		
		EventTypes.HONGOS_INVERNADERO:
			procesar_hongos(delta)

func procesar_tormenta(delta):
	if battery_active:
		# Consumimos la energia de emergencia
		emergency_battery -= BATTERY_DRAIN_RATE * delta

		if emergency_battery <= 0:
			emergency_battery = 0
			battery_active = false

			# El soporte vital deja de funcionar
			StationCost.life_support_state = "AVERIADO"

	else:
		# Disminuye el oxigeno cuando falla el soporte vital
		Resources.oxygen -= OXYGEN_DRAIN_RATE * delta
		Resources.oxygen = maxf(Resources.oxygen, 0)


func procesar_perdida_presion(delta):
	# El oxigeno disminuye mientras no se repare el soporte vital
	Resources.oxygen -= OXYGEN_DRAIN_RATE * delta
	Resources.oxygen = maxf(Resources.oxygen, 0)


func procesar_congelamiento(delta):
	if not pipe_timer_active:
		return

	pipe_timer -= delta

	if pipe_timer <= 0:
		pipe_timer = 0
		pipe_timer_active = false

		# El problema empeora si no se repara a tiempo
		StationCost.water_station_state = "AVERIADO"
		StationCost.greenhouse_state = "AVERIADO"

func procesar_hongos(delta):
	if not fungus_timer_active:
		return

	fungus_timer -= delta

	if fungus_timer <= 0:
		fungus_timer = 0
		fungus_timer_active = false

		StationCost.greenhouse_state = "AVERIADO"

func check_task_completion(station: String, task_name: String):
	if task_name != "repair":
		return

	match actual_EventType:

		EventTypes.TORMENTA_ARENA:
			if station == "energy_plant":
				StationCost.energy_plant_state = "OPERATIVO"
				StationCost.life_support_state = "OPERATIVO"
				battery_active = false
				actual_EventType = EventTypes.NONE

		EventTypes.PERDIDA_PRESION:
			if station == "life_support":
				StationCost.life_support_state = "OPERATIVO"
				actual_EventType = EventTypes.NONE

		EventTypes.FALTA_ENERGIA:
			if station == "energy_plant":
				StationCost.greenhouse_state = "OPERATIVO"
				actual_EventType = EventTypes.NONE

		EventTypes.CONGELAMIENTO_TUBERIAS:
			if station == "water_station":
				StationCost.water_station_state = "OPERATIVO"
				StationCost.greenhouse_state = "OPERATIVO"

				pipe_timer_active = false
				actual_EventType = EventTypes.NONE
				
		EventTypes.HONGOS_INVERNADERO:
			if station == "greenhouse":
				StationCost.greenhouse_state = "OPERATIVO"
				fungus_timer_active = false
				actual_EventType = EventTypes.NONE
	trigger_random_event(0.30)
	
