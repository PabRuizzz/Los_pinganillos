extends SceneTree
## Valida el botón "Terminar día" del HUD y TaskExecution.request_end_day().
##   godot --headless --path . --script res://tools/test_end_day.gd
##
## Todo el estado que toca vive en memoria de este proceso (autoloads). No lee ni
## escribe archivos de progreso del jugador. Los autoloads se obtienen en tiempo de
## ejecución porque aún no existen cuando se compila este script (--script).

const MAIN := "res://game/main/main.tscn"
const MARS := "res://game/stations/mars/mars.tscn"
const GREENHOUSE := "res://game/stations/greenhouse/greenhouse.tscn"

const TEST_DISCOVERY_SAVE := "user://test_isolated_sample_discovery.cfg"
var failures := 0
var sim: Node
var tasks: Node
var res: Node
var costs: Node
var events: Node
var hud: CanvasLayer

var end_button: Button
var confirm_box: Control
var yes_button: Button
var no_button: Button
var hint: Label

var started_days: Array = []
var finished_count := 0
var log: Array = []
var events_started := 0
var planned_events := true


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func go_to(path: String) -> void:
	check(change_scene_to_file(path) == OK, "No carga " + path)
	await frames(4)


## Clic real del ratón sobre un control (pasa por el sistema de entrada de la GUI).
func click(control: Control) -> void:
	var pos := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		root.push_input(ev, true)
	await frames(2)


func clear_events() -> void:
	events.actual_EventType = 0
	# Estado del sistema de eventos planeados (main): cola, estaciones clave y espera
	events.queue.clear()
	events.key_stations.clear()
	events.damaged_stations.clear()
	events.escalated = false
	events._next_event_token += 1  # anula un "siguiente evento" que estuviera esperando
	events.battery_active = false
	events.pipe_timer_active = false
	events.fungus_timer_active = false
	for station in ["energy_plant_state", "life_support_state", "water_station_state", "greenhouse_state"]:
		costs.set(station, "OPERATIVO")


func resources() -> Array:
	return [res.energy, res.water, res.food]

## Cambio de recursos al terminar el día con los estados actuales (valores de StationCost,
## así la prueba sigue valiendo si el equipo reajusta el balance).
func daily_delta() -> Array:
	var c: Dictionary = costs.station_costs
	return [
		c["energy_plant"][costs.energy_plant_state].get("energy", 0) + c["life_support"][costs.life_support_state].get("energy", 0),
		c["water_station"][costs.water_station_state].get("water", 0),
		c["greenhouse"][costs.greenhouse_state].get("food", 0),
	]


## Energía que cuesta una tarea (StationCost); se descuenta al terminarla.
func task_energy(station: String, task: String) -> int:
	return costs.station_costs[station][task].get("energy", 0)


## Suma por recurso respetando los límites de Resources (0..MAX_RESOURCE).
func plus(a: Array, b: Array) -> Array:
	var out := []
	for i in a.size():
		out.append(clampi(a[i] + b[i], 0, res.MAX_RESOURCE))
	return out


func run_checks() -> void:
	# Aislamiento: desde la Fase 5 el regreso del rover descubre una muestra. Cualquier
	# SampleDiscovery que entre al árbol (antes de su _ready) usa un archivo de prueba,
	# nunca el progreso real del jugador.
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	node_added.connect(func(node: Node):
		if node is SampleDiscovery:
			node.save_path = TEST_DISCOVERY_SAVE)
	sim = root.get_node("SimulationTime")
	tasks = root.get_node("TaskExecution")
	res = root.get_node("Resources")
	costs = root.get_node("StationCost")
	events = root.get_node("Events")
	hud = root.get_node("HUD")

	tasks.day_started.connect(func(day): started_days.append(day); log.append("day_started"))
	tasks.day_finished.connect(func(): finished_count += 1; log.append("day_finished"))
	sim.day_advanced.connect(func(_day): log.append("day_advanced"))
	events.event_started.connect(func(_t, _title, _msg): events_started += 1)
	# DaySummary pausa el juego al terminar cada día hasta pulsar "Siguiente día":
	# en las pruebas se cierra solo en el siguiente frame.
	process_frame.connect(func():
		var summary = root.get_node_or_null("DaySummary")
		if summary != null and summary.root_control.visible:
			summary.root_control.visible = false
			paused = false)
	# Los eventos planeados de cada día (Events.PLAN) cambian las estaciones: mientras
	# planned_events sea false, se anulan justo después de empezar el día.
	tasks.day_started.connect(func(_d):
		if not planned_events:
			clear_events())

	# --- 1. El HUD existente tiene el botón (y la confirmación, oculta).
	end_button = hud.get_node_or_null("%EndDayButton")
	confirm_box = hud.get_node_or_null("%EndDayConfirm")
	yes_button = hud.get_node_or_null("%ConfirmEndDayButton")
	no_button = hud.get_node_or_null("%CancelEndDayButton")
	hint = hud.get_node_or_null("%EndDayHint")
	check(end_button != null and confirm_box != null and yes_button != null and no_button != null and hint != null, "Faltan nodos del botón Terminar día en el HUD")
	if end_button == null:
		quit(1)
		return
	check(end_button.text == "Terminar día", "El botón debe decir 'Terminar día'")
	check(end_button.focus_mode == Control.FOCUS_NONE and yes_button.focus_mode == Control.FOCUS_NONE, "Los botones no deben tomar el foco del teclado (las flechas mueven al jugador)")

	# --- Sin día activo: botón apagado y petición rechazada.
	# El autoload GameFlow inicia el día 1 al arrancar; se desactiva a mano para
	# probar el estado "sin día" (como antes de arrancar o tras el fin de partida).
	await frames(2)
	tasks.day_active = false
	started_days.clear()
	await frames(2)
	check(not tasks.day_active and end_button.disabled, "Sin día activo el botón debe estar apagado")
	check(not tasks.can_end_day() and not tasks.request_end_day(), "request_end_day debe rechazarse sin día activo")
	check(sim.day == 1 and finished_count == 0, "Una petición rechazada no debe cambiar el día")

	# --- Partida nueva, sin azar: base operativa y recursos conocidos.
	# main.gd ya no inicia el día (lo hace GameFlow al arrancar), así que se inicia aquí.
	await go_to(MAIN)
	tasks.start_day()
	planned_events = false
	clear_events()
	res.energy = 50
	res.water = 50
	res.food = 50
	await frames(2)
	check(tasks.day_active and not end_button.disabled and end_button.visible and not confirm_box.visible, "Con el día activo el botón debe estar encendido")

	# --- Cancelar la confirmación no termina el día.
	await click(end_button)
	check(confirm_box.visible and not end_button.visible, "El clic debe pedir confirmación")
	check(hud.get_node("%ConfirmLabel").text == "¿Terminar el día 1?", "La confirmación debe nombrar el día actual")
	check(sim.day == 1, "Pedir confirmación no termina el día")
	await click(no_button)
	check(not confirm_box.visible and end_button.visible and sim.day == 1 and finished_count == 0, "'No' debe cerrar la confirmación sin terminar el día")

	# --- 2-6. Terminar el día con los 480 minutos intactos. El rover está fuera.
	await go_to(MARS)
	var rover: Node = current_scene.get_node("RoverExpeditionController")
	var rover_returns: Array = []
	rover.reset()
	rover.expedition_returned.connect(func(dep: int, day: int): rover_returns.append([dep, day]))
	check(rover.start_expedition(), "El rover debe poder salir el día 1")
	check(sim.tiempo_jornada == 480, "La jornada debe estar completa")
	log.clear()
	var expected := plus(resources(), daily_delta())
	await click(end_button)
	await click(yes_button)
	check(sim.day == 2 and finished_count == 1, "Confirmar debe pasar al día 2 una sola vez (día %d, day_finished=%d)" % [sim.day, finished_count])
	check(log == ["day_advanced", "day_finished", "day_started"], "Debe usar la misma secuencia de fin de día: %s" % str(log))
	check(resources() == expected, "Los recursos diarios deben aplicarse una vez: %s (esperado %s)" % [str(resources()), str(expected)])
	check(sim.tiempo_jornada == 480 and tasks.day_active and started_days == [1, 2], "El día 2 debe empezar con la jornada completa")
	check(not confirm_box.visible and end_button.visible and not end_button.disabled, "El HUD debe volver al botón normal")
	check(hud.get_node("%DayLabel").text == "Día 2" and hud.get_node("%TimeLabel").text == "Tiempo restante: 8:00 h", "El HUD debe mostrar el día nuevo y la jornada completa")

	# --- 8. El rover volvió una vez al empezar el día 2.
	check(rover_returns == [[1, 2]] and rover.is_available(), "El rover debe volver una vez: %s" % str(rover_returns))

	# --- 10. Clics repetidos no avanzan más días.
	await click(end_button)
	var before := finished_count
	expected = plus(resources(), daily_delta())
	yes_button.pressed.emit()
	yes_button.pressed.emit()
	yes_button.pressed.emit()
	await frames(2)
	check(sim.day == 3 and finished_count == before + 1, "Tres clics en 'Sí' deben terminar un solo día (día %d)" % sim.day)
	check(resources() == expected, "Los recursos no deben aplicarse dos veces: %s (esperado %s)" % [str(resources()), str(expected)])

	# --- 9. Con una tarea en curso no se puede terminar el día.
	check(tasks.start_task("energy_plant", "maintenance"), "Debe poder iniciar una tarea")
	await frames(2)
	check(end_button.disabled and hint.visible, "Con una tarea en curso el botón debe apagarse y explicar por qué")
	await click(end_button)
	check(not confirm_box.visible, "Un botón apagado no debe abrir la confirmación")
	check(not tasks.request_end_day(), "request_end_day debe rechazarse con una tarea en curso")
	check(sim.day == 3 and tasks.current_task == "maintenance" and sim.tiempo_jornada == 480, "La tarea en curso no debe interrumpirse ni perderse")

	# Si la tarea empieza con la confirmación abierta, la confirmación se cierra.
	tasks.cancel_task()
	await frames(2)
	await click(end_button)
	check(confirm_box.visible, "La confirmación debe abrirse sin tarea en curso")
	tasks.start_task("energy_plant", "maintenance")
	await frames(2)
	check(not confirm_box.visible, "Iniciar una tarea debe cerrar la confirmación")
	yes_button.pressed.emit()
	check(sim.day == 3, "Una confirmación cerrada no debe terminar el día")

	# --- Terminar la tarea deja 360 minutos; terminar el día con poco tiempo también vale.
	tasks.finish_task()
	tasks.start_task("energy_plant", "maintenance"); tasks.finish_task()
	tasks.start_task("energy_plant", "maintenance"); tasks.finish_task()
	check(sim.tiempo_jornada == 120 and sim.day == 3, "Deberían quedar 120 minutos del día 3")
	await frames(2)
	expected = plus(resources(), daily_delta())
	await click(end_button)
	await click(yes_button)
	check(sim.day == 4 and sim.tiempo_jornada == 480 and resources() == expected, "Terminar con 120 minutos restantes debe pasar al día 4: %s (esperado %s)" % [str(resources()), str(expected)])

	# --- 11. El fin automático al agotar la jornada sigue funcionando...
	before = finished_count
	# Cuatro mantenimientos (cada uno cobra su energía) y luego los recursos del día.
	expected = plus(plus(resources(), [-4 * task_energy("energy_plant", "maintenance"), 0, 0]), daily_delta())
	for i in 3:
		tasks.start_task("energy_plant", "maintenance"); tasks.finish_task()
	await frames(2)
	await click(end_button)  # confirmación abierta para el día 4
	check(confirm_box.visible, "La confirmación del día 4 debe estar abierta")
	tasks.start_task("energy_plant", "maintenance")
	tasks.finish_task()  # agota la jornada: el día 4 termina solo
	check(sim.day == 5 and finished_count == before + 1, "Agotar la jornada debe terminar el día automáticamente")
	# ...y una confirmación abierta para el día anterior no termina también el nuevo.
	check(not confirm_box.visible, "La confirmación del día anterior debe cerrarse al cambiar el día")
	yes_button.pressed.emit()
	await frames(2)
	check(sim.day == 5 and finished_count == before + 1, "El fin automático y el botón no deben sumar dos días")
	check(resources() == expected, "Recursos tras el día 4: %s (esperado %s)" % [str(resources()), str(expected)])

	# --- 12. Cambiar de escena no repite transiciones ni altera el botón.
	var days_before := started_days.duplicate()
	await go_to(GREENHOUSE)
	await go_to(MARS)
	check(sim.day == 5 and started_days == days_before and resources() == expected, "Cambiar de escena repitió una transición de día")
	check(not end_button.disabled and end_button.visible, "El botón debe seguir disponible tras cambiar de escena")
	check(current_scene.get_node("RoverExpeditionController").is_available() and rover_returns.size() == 1, "El rover no debe volver dos veces")

	# --- 7. Terminar el día con el botón también arranca los eventos pendientes del día
	# siguiente (Events.queue: lo pendiente pasa a mañana, antes de lo planeado).
	clear_events()
	planned_events = true
	events.queue.append(events.EventTypes.HONGOS_INVERNADERO)
	events_started = 0
	await click(end_button)
	await click(yes_button)
	check(sim.day == 6 and events_started == 1 and events.actual_EventType == events.EventTypes.HONGOS_INVERNADERO, "Terminar el día con el botón debe arrancar el evento pendiente del día siguiente")
	planned_events = false
	clear_events()

	# --- Con el juego en pausa (fin de partida) el botón se apaga.
	paused = true
	await frames(2)
	check(end_button.disabled, "Con el juego en pausa el botón debe estar apagado")
	paused = false

	print("END DAY CHECKS: failures: %d" % failures)
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	quit(0 if failures == 0 else 1)
