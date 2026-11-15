extends Node

# Eventos planeados: cada día trae dos eventos SEGUIDOS (nunca dos a la vez).
# El primero empieza al iniciar el día y el segundo en cuanto resuelves el primero.
#
# Reglas:
# - Un evento se resuelve cuando sus estaciones clave vuelven a OPERATIVO
#   (con mantenimiento si están DEGRADADAS o reparación si están AVERIADAS).
#   Los daños colaterales (p. ej. agua e invernadero en la tormenta) NO hace falta
#   arreglarlos para resolver el evento: el jugador decide si gasta tiempo en ellos.
# - Hongos y tuberías tienen un reloj en tiempo real: si se acaba, escalan
#   y arreglarlos cuesta más (reparación en vez de mantenimiento, o dos reparaciones).
# - Si el día termina con el evento sin resolver, sus estaciones DEGRADADAS pasan a
#   AVERIADO, y el evento y lo que faltaba de la cola pasan al día siguiente,
#   antes de los eventos planeados para ese día.

enum EventTypes {
	NONE,
	TORMENTA_ARENA,
	PERDIDA_PRESION,
	FALTA_ENERGIA,
	CONGELAMIENTO_TUBERIAS,
	HONGOS_INVERNADERO
}

# ---------- Plan de la partida (editar aquí para cambiar la dificultad) ----------

const PLAN = {
	1: [EventTypes.FALTA_ENERGIA, EventTypes.HONGOS_INVERNADERO],
	2: [EventTypes.HONGOS_INVERNADERO, EventTypes.CONGELAMIENTO_TUBERIAS],
	3: [EventTypes.CONGELAMIENTO_TUBERIAS, EventTypes.PERDIDA_PRESION],
	4: [EventTypes.TORMENTA_ARENA, EventTypes.HONGOS_INVERNADERO],
	5: [EventTypes.PERDIDA_PRESION, EventTypes.TORMENTA_ARENA],
}

# Segundos (reales) entre resolver un evento y que empiece el siguiente,
# para que se alcance a leer la alerta de "Event resolved".
const NEXT_EVENT_DELAY = 5.0

# Tiempo real antes de que hongos / tuberías escalen
const FUNGUS_TIME_LIMIT = 120.0
const PIPE_TIME_LIMIT = 120.0

# Unidades por segundo (real)
const BATTERY_DRAIN_RATE = 0.5   # batería de emergencia: 100 -> 0 en 200 s
const OXYGEN_DRAIN_RATE = 0.4    # oxígeno sin soporte vital: 100 -> 0 en 250 s

# Título y mensaje de la alerta de cada evento
const EVENT_INFO = {
	EventTypes.TORMENTA_ARENA: ["Sandstorm", "The power plant is down. The emergency battery is active."],
	EventTypes.PERDIDA_PRESION: ["Pressure Loss", "Life support has failed. Oxygen is dropping."],
	EventTypes.FALTA_ENERGIA: ["Power Shortage", "The power plant is degraded. Perform maintenance."],
	EventTypes.CONGELAMIENTO_TUBERIAS: ["Frozen Pipes", "Repair the water station within two minutes or the greenhouse will fail too."],
	EventTypes.HONGOS_INVERNADERO: ["Greenhouse Fungus", "Service the greenhouse within two minutes or it will fail."],
}

signal event_started(type: EventTypes, title: String, message: String)
signal event_resolved(type: EventTypes)

# ---------- Estado ----------

var actual_EventType: EventTypes = EventTypes.NONE
# Eventos que faltan por salir (lo pendiente de días anteriores va primero)
var queue: Array = []
# Estaciones que hay que dejar OPERATIVAS para resolver el evento activo
var key_stations: Array = []
# Todas las estaciones que dañó el evento activo (clave + colaterales)
var damaged_stations: Array = []
# El evento activo ya escaló (se acabó su reloj o pasó una noche sin resolverse)
var escalated = false

# Tormenta: batería de emergencia
var emergency_battery = 100.0
var battery_active = false

# Relojes de tuberías y hongos
var pipe_timer = PIPE_TIME_LIMIT
var pipe_timer_active = false
var fungus_timer = FUNGUS_TIME_LIMIT
var fungus_timer_active = false

# Evita que una espera vieja (de antes de reiniciar) lance un evento
var _next_event_token = 0


func _ready():
	TaskExecution.day_started.connect(_on_day_started)
	TaskExecution.task_finished.connect(_on_task_finished)
	TaskExecution.day_finished.connect(_on_day_finished)


# ---------- Flujo del día ----------

func _on_day_started(day):
	queue.append_array(PLAN.get(day, []))
	if actual_EventType == EventTypes.NONE:
		_start_next_event()


func _on_task_finished(_station, _task_name, _time_spent):
	if actual_EventType == EventTypes.NONE:
		return
	if _is_resolved():
		_resolve_active_event()


# Noche: lo que quedó sin resolver empeora y se queda para mañana
func _on_day_finished():
	if actual_EventType == EventTypes.NONE:
		return
	for station in damaged_stations:
		if StationCost.get_state(station) == "DEGRADADO":
			StationCost.set_state(station, "AVERIADO")
	_escalate()


func _start_next_event():
	_next_event_token += 1
	if actual_EventType != EventTypes.NONE or queue.is_empty():
		return
	trigger_event(queue.pop_front())


# Inicia un evento concreto y avisa a la UI
func trigger_event(type: EventTypes):
	if actual_EventType != EventTypes.NONE or not EVENT_INFO.has(type):
		return

	actual_EventType = type
	escalated = false
	key_stations = []
	damaged_stations = []

	match type:
		EventTypes.FALTA_ENERGIA:
			_damage("energy_plant", "DEGRADADO", true)

		EventTypes.HONGOS_INVERNADERO:
			_damage("greenhouse", "DEGRADADO", true)
			fungus_timer = FUNGUS_TIME_LIMIT
			fungus_timer_active = true

		EventTypes.CONGELAMIENTO_TUBERIAS:
			_damage("water_station", "AVERIADO", true)
			_damage("greenhouse", "DEGRADADO", false)
			pipe_timer = PIPE_TIME_LIMIT
			pipe_timer_active = true

		EventTypes.PERDIDA_PRESION:
			_damage("life_support", "AVERIADO", true)

		EventTypes.TORMENTA_ARENA:
			_damage("energy_plant", "AVERIADO", true)
			_damage("water_station", "DEGRADADO", false)
			_damage("greenhouse", "DEGRADADO", false)
			emergency_battery = 100.0
			battery_active = true

	var info = EVENT_INFO[type]
	event_started.emit(type, info[0], info[1])

	# Por seguridad: si sus estaciones clave ya están OPERATIVAS, se cierra solo
	if _is_resolved():
		_resolve_active_event()


# Empeora una estación (nunca la mejora) y la anota en el evento activo
func _damage(station: String, state: String, is_key: bool):
	var order = ["OPERATIVO", "DEGRADADO", "AVERIADO"]
	if order.find(state) > order.find(StationCost.get_state(station)):
		StationCost.set_state(station, state)
	if station not in damaged_stations:
		damaged_stations.append(station)
	if is_key and station not in key_stations:
		key_stations.append(station)


func _is_resolved() -> bool:
	for station in key_stations:
		if StationCost.get_state(station) != "OPERATIVO":
			return false
	return true


func _resolve_active_event():
	var resolved = actual_EventType

	match resolved:
		EventTypes.CONGELAMIENTO_TUBERIAS:
			# A tiempo: reparar el agua descongela también el invernadero
			if not escalated and StationCost.greenhouse_state == "DEGRADADO":
				StationCost.greenhouse_state = "OPERATIVO"
		EventTypes.TORMENTA_ARENA:
			# Con la planta reparada vuelve la energía al soporte vital
			StationCost.life_support_state = "OPERATIVO"

	actual_EventType = EventTypes.NONE
	key_stations = []
	damaged_stations = []
	escalated = false
	battery_active = false
	pipe_timer_active = false
	fungus_timer_active = false

	event_resolved.emit(resolved)

	# El siguiente evento llega tras una pausa corta (se detiene si el juego está en pausa)
	_next_event_token += 1
	var token = _next_event_token
	get_tree().create_timer(NEXT_EVENT_DELAY, false).timeout.connect(func():
		if token == _next_event_token and TaskExecution.day_active:
			_start_next_event()
	)


# El evento activo empeora: ahora cuesta más resolverlo
func _escalate():
	if escalated:
		return
	escalated = true

	match actual_EventType:
		EventTypes.HONGOS_INVERNADERO:
			fungus_timer = 0.0
			fungus_timer_active = false
			StationCost.greenhouse_state = "AVERIADO"

		EventTypes.CONGELAMIENTO_TUBERIAS:
			pipe_timer = 0.0
			pipe_timer_active = false
			# El invernadero se congela: ya no basta con reparar el agua
			StationCost.greenhouse_state = "AVERIADO"
			if "greenhouse" not in key_stations:
				key_stations.append("greenhouse")


# ---------- Tiempo real ----------

func _process(delta):
	if not TaskExecution.day_active:
		return

	match actual_EventType:
		EventTypes.TORMENTA_ARENA:
			_process_storm(delta)
		EventTypes.PERDIDA_PRESION:
			_drain_oxygen(delta)
		EventTypes.CONGELAMIENTO_TUBERIAS:
			if pipe_timer_active:
				pipe_timer -= delta
				if pipe_timer <= 0:
					_escalate()
		EventTypes.HONGOS_INVERNADERO:
			if fungus_timer_active:
				fungus_timer -= delta
				if fungus_timer <= 0:
					_escalate()


func _process_storm(delta):
	if battery_active:
		emergency_battery -= BATTERY_DRAIN_RATE * delta
		if emergency_battery <= 0:
			emergency_battery = 0
			battery_active = false
			# Sin batería el soporte vital se apaga (y deja de regenerar oxígeno)
			StationCost.life_support_state = "AVERIADO"
	else:
		_drain_oxygen(delta)


func _drain_oxygen(delta):
	Resources.oxygen = maxf(Resources.oxygen - OXYGEN_DRAIN_RATE * delta, 0.0)
