extends Node

enum Events {
	NONE,
	TORMENTA_ARENA,
	PERDIDA_PRESION,
	FALTA_ENERGIA,
	CONGELAMIENTO_TUBERIAS,
	HONGOS_INVERNADERO
}

var actual_event: Events = Events.NONE

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

func tormenta_arena():
	if actual_event != Events.NONE:
		return

	actual_event = Events.TORMENTA_ARENA

	StationCost.energy_plant_state = "AVERIADO"
	StationCost.life_support_state = "OPERATIVO"
	StationCost.water_station_state = "DEGRADADO"
	StationCost.greenhouse_state = "DEGRADADO"

	emergency_battery = 100.0
	battery_active = true


func perdida_presion():
	if actual_event != Events.NONE:
		return
	actual_event = Events.PERDIDA_PRESION

	StationCost.life_support_state = "AVERIADO"


func falta_energia():
	if actual_event != Events.NONE:
		return
	actual_event = Events.FALTA_ENERGIA

	StationCost.greenhouse_state = "DEGRADADO"


func congelamiento_tuberias():
	if actual_event != Events.NONE:
		return
	actual_event = Events.CONGELAMIENTO_TUBERIAS

	StationCost.water_station_state = "DEGRADADO"
	StationCost.greenhouse_state = "DEGRADADO"

	pipe_timer = PIPE_TIME_LIMIT
	pipe_timer_active = true

func hongos_invernadero():
	if actual_event != Events.NONE:
		return

	actual_event = Events.HONGOS_INVERNADERO

	StationCost.greenhouse_state = "DEGRADADO"

	fungus_timer = FUNGUS_TIME_LIMIT
	fungus_timer_active = true


func _process(delta):
	match actual_event:

		Events.TORMENTA_ARENA:
			procesar_tormenta(delta)

		Events.PERDIDA_PRESION:
			procesar_perdida_presion(delta)

		Events.CONGELAMIENTO_TUBERIAS:
			procesar_congelamiento(delta)
		
		Events.HONGOS_INVERNADERO:
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

	match actual_event:

		Events.TORMENTA_ARENA:
			if station == "energy_plant":
				StationCost.energy_plant_state = "OPERATIVO"
				StationCost.life_support_state = "OPERATIVO"
				battery_active = false
				actual_event = Events.NONE

		Events.PERDIDA_PRESION:
			if station == "life_support":
				StationCost.life_support_state = "OPERATIVO"
				actual_event = Events.NONE

		Events.FALTA_ENERGIA:
			if station == "energy_plant":
				StationCost.greenhouse_state = "OPERATIVO"
				actual_event = Events.NONE

		Events.CONGELAMIENTO_TUBERIAS:
			if station == "water_station":
				StationCost.water_station_state = "OPERATIVO"
				StationCost.greenhouse_state = "OPERATIVO"

				pipe_timer_active = false
				actual_event = Events.NONE
				
		Events.HONGOS_INVERNADERO:
			if station == "greenhouse":
				StationCost.greenhouse_state = "OPERATIVO"
				fungus_timer_active = false
				actual_event = Events.NONE
