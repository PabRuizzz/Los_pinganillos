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
	events.battery_active = false
	events.pipe_timer_active = false
	events.fungus_timer_active = false
	for station in ["energy_plant_state", "life_support_state", "water_station_state", "greenhouse_state"]:
		costs.set(station, "OPERATIVO")


func resources() -> Array:
	return [res.energy, res.water, res.food]


func run_checks() -> void:
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
	await frames(2)
	check(not tasks.day_active and end_button.disabled, "Sin día activo el botón debe estar apagado")
	check(not tasks.can_end_day() and not tasks.request_end_day(), "request_end_day debe rechazarse sin día activo")
	check(sim.day == 1 and finished_count == 0, "Una petición rechazada no debe cambiar el día")

	# --- Partida nueva, sin azar: base operativa y recursos conocidos.
	await go_to(MAIN)
	events.day_start_event_chance = 0.0
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
	await click(end_button)
	await click(yes_button)
	check(sim.day == 2 and finished_count == 1, "Confirmar debe pasar al día 2 una sola vez (día %d, day_finished=%d)" % [sim.day, finished_count])
	check(log == ["day_advanced", "day_finished", "day_started"], "Debe usar la misma secuencia de fin de día: %s" % str(log))
	check(resources() == [51, 49, 51], "Los recursos diarios deben aplicarse una vez: %s" % str(resources()))
	check(sim.tiempo_jornada == 480 and tasks.day_active and started_days == [1, 2], "El día 2 debe empezar con la jornada completa")
	check(not confirm_box.visible and end_button.visible and not end_button.disabled, "El HUD debe volver al botón normal")
	check(hud.get_node("%DayLabel").text == "Día 2" and hud.get_node("%TimeLabel").text == "Tiempo restante: 8:00 h", "El HUD debe mostrar el día nuevo y la jornada completa")

	# --- 8. El rover volvió una vez al empezar el día 2.
	check(rover_returns == [[1, 2]] and rover.is_available(), "El rover debe volver una vez: %s" % str(rover_returns))

	# --- 10. Clics repetidos no avanzan más días.
	await click(end_button)
	var before := finished_count
	yes_button.pressed.emit()
	yes_button.pressed.emit()
	yes_button.pressed.emit()
	await frames(2)
	check(sim.day == 3 and finished_count == before + 1, "Tres clics en 'Sí' deben terminar un solo día (día %d)" % sim.day)
	check(resources() == [52, 48, 52], "Los recursos no deben aplicarse dos veces: %s" % str(resources()))

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
	await click(end_button)
	await click(yes_button)
	check(sim.day == 4 and sim.tiempo_jornada == 480 and resources() == [53, 47, 53], "Terminar con 120 minutos restantes debe pasar al día 4: %s" % str(resources()))

	# --- 11. El fin automático al agotar la jornada sigue funcionando...
	before = finished_count
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
	check(resources() == [54, 46, 54], "Recursos tras el día 4: %s" % str(resources()))

	# --- 12. Cambiar de escena no repite transiciones ni altera el botón.
	var days_before := started_days.duplicate()
	await go_to(GREENHOUSE)
	await go_to(MARS)
	check(sim.day == 5 and started_days == days_before and resources() == [54, 46, 54], "Cambiar de escena repitió una transición de día")
	check(not end_button.disabled and end_button.visible, "El botón debe seguir disponible tras cambiar de escena")
	check(current_scene.get_node("RoverExpeditionController").is_available() and rover_returns.size() == 1, "El rover no debe volver dos veces")

	# --- 7. Los eventos de inicio de día siguen funcionando al terminar con el botón.
	clear_events()
	events.day_start_event_chance = 1.0
	events_started = 0
	await click(end_button)
	await click(yes_button)
	check(sim.day == 6 and events_started == 1 and events.actual_EventType != 0, "Terminar el día con el botón debe lanzar el evento del día siguiente")

	# --- Con el juego en pausa (fin de partida) el botón se apaga.
	paused = true
	await frames(2)
	check(end_button.disabled, "Con el juego en pausa el botón debe estar apagado")
	paused = false

	print("END DAY CHECKS: failures: %d" % failures)
	quit(0 if failures == 0 else 1)
