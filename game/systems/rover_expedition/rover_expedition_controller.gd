class_name RoverExpeditionController
extends Node
## Ciclo de vida de las expediciones del rover (solo lógica, sin interfaz).
##
## - RoverStation: estación física, detección del jugador e interacción (E).
## - Este nodo: estado de la expedición, salida y regreso.
## - SimulationTime / TaskExecution (autoloads existentes): fuente del día simulado.
##
## Una expedición dura UN día simulado: sale el día N y vuelve cuando empieza el N + 1.
## El regreso depende solo de SimulationTime.day; no hay Timer ni reloj propio.
##
## No es un Autoload: es un nodo de mars.tscn. Como el juego recarga mars.tscn cada vez
## que el jugador cruza una puerta, el estado se guarda en variables estáticas para que
## sobreviva a los cambios de escena. Es estado en memoria: se pierde al cerrar el juego.
##
## Fase 5: RoverSampleDiscoveryBridge (nodo hermano en mars.tscn) escucha
## expedition_returned y llama a SampleDiscovery.complete_expedition().
## Este script no descubre muestras.

enum State { AVAILABLE, ON_EXPEDITION }

## El rover salió. return_day = departure_day + EXPEDITION_DURATION_DAYS.
signal expedition_started(departure_day: int, return_day: int)
## El rover volvió a la base. Se emite una sola vez por expedición.
## returned_on_day es el día actual (puede ser mayor que return_day si pasaron varios días).
signal expedition_returned(departure_day: int, returned_on_day: int)
signal expedition_state_changed(new_state: State)

const EXPEDITION_DURATION_DAYS := 1
const NO_DAY := -1

## Estación física que dispara las expediciones. Si se deja vacío, el controlador
## funciona igual pero solo mediante start_expedition().
@export var station: RoverStation

static var _state: State = State.AVAILABLE
static var _departure_day: int = NO_DAY
static var _return_day: int = NO_DAY


func _ready() -> void:
	TaskExecution.day_finished.connect(_on_day_finished)
	if station != null:
		station.interaction_requested.connect(_on_station_interaction_requested)
	_update_station()
	# Diferido: da tiempo a que otros nodos se conecten a las señales antes de
	# resolver un regreso que ocurrió mientras el jugador estaba en otra escena.
	_sync_with_current_day.call_deferred()


func get_state() -> State:
	return _state


func is_available() -> bool:
	return _state == State.AVAILABLE


func is_on_expedition() -> bool:
	return _state == State.ON_EXPEDITION


## Día en que salió el rover, o NO_DAY (-1) si está en la base.
func get_departure_day() -> int:
	return _departure_day


## Día en que se espera su regreso, o NO_DAY (-1) si está en la base.
func get_return_day() -> int:
	return _return_day


func can_start_expedition() -> bool:
	return is_available()


## Envía el rover. Devuelve false (sin cambiar nada) si ya está fuera.
func start_expedition() -> bool:
	if not can_start_expedition():
		return false
	_departure_day = _current_day()
	_return_day = _departure_day + EXPEDITION_DURATION_DAYS
	_set_state(State.ON_EXPEDITION)
	print("Rover: sale de expedición el día %d; vuelve el día %d" % [_departure_day, _return_day])
	expedition_started.emit(_departure_day, _return_day)
	return true


## Borra el estado en memoria (nueva partida o pruebas). No emite expedition_returned.
func reset() -> void:
	_departure_day = NO_DAY
	_return_day = NO_DAY
	_set_state(State.AVAILABLE)


## Deja el rover en la base sin necesitar la escena de Marte (partida nueva).
## Las instancias cargadas después leen este estado en su _ready().
static func reset_run_state() -> void:
	_state = State.AVAILABLE
	_departure_day = NO_DAY
	_return_day = NO_DAY


func _on_station_interaction_requested() -> void:
	start_expedition()


## TaskExecution.finish_day() ya incrementó SimulationTime.day antes de emitir la señal.
func _on_day_finished() -> void:
	_sync_with_current_day()


## Compara el día actual con el de regreso. Se llama al cambiar el día y al cargar
## la escena, así una expedición no puede quedarse atascada.
func _sync_with_current_day() -> void:
	if not is_on_expedition():
		return
	var today := _current_day()
	if today < _departure_day:
		# El día retrocedió: la partida se reinició (pantalla de fin de juego).
		reset()
		return
	if today < _return_day:
		return
	var departed_on := _departure_day
	_departure_day = NO_DAY
	_return_day = NO_DAY
	_set_state(State.AVAILABLE)
	print("Rover: volvió a la base el día %d (salió el día %d)" % [today, departed_on])
	expedition_returned.emit(departed_on, today)


func _set_state(new_state: State) -> void:
	var changed := new_state != _state
	_state = new_state
	_update_station()
	if changed:
		expedition_state_changed.emit(_state)


func _update_station() -> void:
	if station != null:
		station.set_interaction_enabled(is_available())


func _current_day() -> int:
	return SimulationTime.day
