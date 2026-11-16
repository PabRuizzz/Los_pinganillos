extends SceneTree
## Valida el ciclo de vida de las expediciones del rover.
##   godot --headless --path . --script res://tools/test_rover_expedition.gd
##
## Todo el estado que toca (día simulado, recursos, estado del rover) vive en memoria
## de este proceso. No lee ni escribe ningún archivo de progreso del jugador.

# Los autoloads aún no existen cuando se compila este script (--script), así que la
# escena, el controlador y los autoloads se obtienen en tiempo de ejecución.
const MARS_PATH := "res://game/stations/mars/mars.tscn"
const CONTROLLER_PATH := "res://game/systems/rover_expedition/rover_expedition_controller.gd"
const AVAILABLE := 0
const ON_EXPEDITION := 1

var sim: Node    # autoload SimulationTime
var tasks: Node  # autoload TaskExecution

const TEST_DISCOVERY_SAVE := "user://test_isolated_sample_discovery.cfg"
var failures := 0
var mars: Node
var controller: Node
var station: Node2D
var player: CharacterBody2D
var started: Array = []
var returned: Array = []
var state_changes: Array = []


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func physics_frames(n: int) -> void:
	for i in n:
		await physics_frame


## Carga mars.tscn como lo hace una puerta (escena nueva) y conecta las señales
## antes de que el controlador entre al árbol, para no perder ninguna emisión.
func load_mars() -> void:
	if mars != null:
		mars.queue_free()
		await process_frame
	mars = load(MARS_PATH).instantiate()
	controller = mars.get_node("RoverExpeditionController")
	station = mars.get_node("YSortObjects/RoverStation")
	player = mars.get_node("YSortObjects/player")
	controller.expedition_started.connect(func(dep: int, ret: int): started.append([dep, ret]))
	controller.expedition_returned.connect(func(dep: int, day: int): returned.append([dep, day]))
	controller.expedition_state_changed.connect(func(s: int): state_changes.append(s))
	root.add_child(mars)
	current_scene = mars
	player.set_physics_process(false)
	await physics_frames(3)


func press_interact(frames: int) -> void:
	Input.action_press("interact")
	await physics_frames(frames)
	Input.action_release("interact")
	await physics_frames(2)


func stand_at_station() -> void:
	player.global_position = station.global_position + Vector2(0, 20)
	await physics_frames(3)


func run_checks() -> void:
	# DaySummary pausa el juego al terminar cada día hasta pulsar "Siguiente día":
	# en las pruebas se cierra solo en el siguiente frame.
	process_frame.connect(func():
		var summary = root.get_node_or_null("DaySummary")
		if summary != null and summary.root_control.visible:
			summary.root_control.visible = false
			paused = false)
	# Aislamiento: desde la Fase 5 el regreso del rover descubre una muestra. Cualquier
	# SampleDiscovery que entre al árbol (antes de su _ready) usa un archivo de prueba,
	# nunca el progreso real del jugador.
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	node_added.connect(func(node: Node):
		if node is SampleDiscovery:
			node.save_path = TEST_DISCOVERY_SAVE)
	var discovery_save := SampleDiscoverySave.DEFAULT_PATH
	var save_before := FileAccess.get_md5(discovery_save) if FileAccess.file_exists(discovery_save) else ""
	var cue: Label

	sim = root.get_node("SimulationTime")
	tasks = root.get_node("TaskExecution")
	sim.day = 1
	tasks.start_day()  # finish_day solo actúa con el día activo
	await load_mars()
	controller.reset()
	state_changes.clear()
	cue = station.get_node("InteractionArea/InteractCue")

	# 1. Rover nuevo: disponible.
	check(controller.is_available() and not controller.is_on_expedition(), "Un rover nuevo debe estar AVAILABLE")
	check(controller.get_state() == AVAILABLE, "get_state debe ser AVAILABLE")
	check(controller.can_start_expedition(), "Debe poder iniciar una expedición")
	check(controller.get_departure_day() == -1 and controller.get_return_day() == -1, "Sin expedición no debe haber días registrados")
	check(station.interaction_enabled, "La estación debe permitir interactuar con el rover disponible")

	# 11. La interacción existente sigue funcionando: fuera de rango, E no hace nada.
	player.global_position = station.global_position + Vector2(0, 200)
	await physics_frames(3)
	await press_interact(3)
	check(started.is_empty() and controller.is_available(), "E fuera de rango no debe iniciar una expedición")

	# 2-4. E en rango inicia la expedición (una sola vez aunque se mantenga pulsada).
	await stand_at_station()
	check(station.is_player_near() and cue.visible, "La estación debe detectar al jugador y mostrar [E]")
	await press_interact(8)
	check(started.size() == 1, "Una pulsación debe iniciar una expedición (fueron %d)" % started.size())
	check(controller.is_on_expedition() and not controller.is_available(), "El estado debe ser ON_EXPEDITION")
	check(controller.get_departure_day() == 1, "El día de salida debe ser 1")
	check(controller.get_return_day() == 2, "El día de regreso debe ser exactamente salida + 1")
	check(started == [[1, 2]], "expedition_started debe entregar (1, 2)")
	check(state_changes == [ON_EXPEDITION], "expedition_state_changed debe emitirse una vez al salir")

	# 10. Con el rover fuera no se puede iniciar otra.
	check(not station.interaction_enabled and not cue.visible, "La estación debe desactivarse con el rover fuera")
	check(station.is_player_near(), "La detección de proximidad debe seguir funcionando")
	await press_interact(3)
	check(started.size() == 1, "E no debe iniciar otra expedición con el rover fuera")
	check(not controller.can_start_expedition() and not controller.start_expedition(), "start_expedition debe devolver false con el rover fuera")
	check(controller.get_departure_day() == 1 and controller.get_return_day() == 2, "Un intento fallido no debe cambiar los días")

	# 5. No vuelve el mismo día: ni con el paso de frames ni si se avisa sin cambio de día.
	await physics_frames(30)
	tasks.day_finished.emit()
	check(controller.is_on_expedition() and returned.is_empty(), "El rover no debe volver el día de salida")

	# 6-9. El paso real al día siguiente (tasks.finish_day) lo trae de vuelta.
	tasks.finish_day()
	check(sim.day == 2, "finish_day debe avanzar al día 2")
	check(returned == [[1, 2]], "expedition_returned debe emitirse una vez con (1, 2): %s" % str(returned))
	check(controller.is_available() and controller.get_departure_day() == -1 and controller.get_return_day() == -1, "El rover debe quedar disponible y sin días registrados")
	check(station.interaction_enabled and cue.visible, "La estación debe reactivarse al volver el rover")

	# 7. Más cambios de día no repiten el regreso.
	tasks.finish_day()
	tasks.finish_day()
	check(returned.size() == 1, "expedition_returned se emitió %d veces" % returned.size())
	check(controller.is_available(), "El rover debe seguir disponible")

	# Interactuar justo después del regreso inicia otra expedición con el día actual.
	await press_interact(3)
	check(started.size() == 2 and started[1] == [4, 5], "La segunda expedición debe ser (4, 5): %s" % str(started))

	# El estado sobrevive a un cambio de escena (el juego recarga mars.tscn en cada puerta).
	await load_mars()
	check(controller.is_on_expedition() and controller.get_return_day() == 5, "El estado se perdió al recargar la escena")
	check(not station.interaction_enabled, "La estación recargada debe seguir desactivada")
	check(returned.size() == 1, "Recargar la escena el mismo día no debe hacer volver al rover")

	# Si el día cambia con Marte descargado, el regreso se resuelve una vez al volver.
	mars.queue_free()
	mars = null
	await process_frame
	tasks.finish_day()
	tasks.finish_day()  # varios días: no se queda atascado ni se duplica
	check(sim.day == 6, "Se esperaba el día 6")
	await load_mars()
	check(returned.size() == 2 and returned[1] == [4, 6], "El regreso pendiente debe emitirse una vez con (4, 6): %s" % str(returned))
	check(controller.is_available() and station.interaction_enabled, "El rover debe estar disponible tras el regreso pendiente")
	await load_mars()
	check(returned.size() == 2, "Recargar otra vez no debe repetir el regreso")

	# Sin estación asignada, el controlador funciona solo.
	var solo: Node = load(CONTROLLER_PATH).new()
	root.add_child(solo)
	await process_frame
	check(solo.start_expedition() and solo.get_departure_day() == 6 and solo.get_return_day() == 7, "start_expedition directo debe funcionar")
	check(controller.is_on_expedition(), "Todos los controladores deben compartir el estado del rover")
	solo.queue_free()

	# Reinicio de partida (el día vuelve a 1): el rover no se queda atascado fuera.
	sim.day = 1
	await load_mars()
	check(controller.is_available() and station.interaction_enabled, "Tras reiniciar la partida el rover debe estar disponible")
	check(returned.size() == 2, "Reiniciar la partida no debe emitir expedition_returned")

	# Nada de esto toca el progreso de descubrimientos.
	var save_after := FileAccess.get_md5(discovery_save) if FileAccess.file_exists(discovery_save) else ""
	check(save_after == save_before, "Se tocó el archivo de descubrimientos del jugador")

	print("ROVER EXPEDITION CHECKS: failures: %d" % failures)
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	quit(0 if failures == 0 else 1)
