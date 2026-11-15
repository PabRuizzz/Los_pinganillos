extends SceneTree
## Valida la cola de alertas (Alert + AlertQueue).
##   godot --headless --path . --script res://tools/test_alert_queue.gd
##
## Todo el estado vive en memoria (autoloads); no se toca el progreso del jugador.

const MARS := "res://game/stations/mars/mars.tscn"
const GREENHOUSE := "res://game/stations/greenhouse/greenhouse.tscn"
const TEST_DISCOVERY_SAVE := "user://test_isolated_sample_discovery.cfg"
const SHORT := 0.3  # segundos: alertas cortas para poder verlas caducar

var failures := 0
var alert: CanvasLayer
var tasks: Node
var sim: Node
var costs: Node
var res: Node
var events: Node


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame


func current_title() -> String:
	var current = alert.get_current_alert()
	return current.title if current != null else ""


func shown() -> bool:
	return alert.panel.visible and alert.title.text == current_title()


func run_checks() -> void:
	alert = root.get_node("Alert")
	tasks = root.get_node("TaskExecution")
	sim = root.get_node("SimulationTime")
	costs = root.get_node("StationCost")
	res = root.get_node("Resources")
	events = root.get_node("Events")
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	node_added.connect(func(node: Node):
		if node is SampleDiscovery:
			node.save_path = TEST_DISCOVERY_SAVE)
	check(change_scene_to_file(MARS) == OK, "mars.tscn no carga")
	await wait(0.2)
	if not tasks.day_active:
		tasks.start_day()
	alert.clear_alerts()  # la tormenta inicial de GameFlow
	check(alert.get_current_alert() == null and alert.get_pending_count() == 0 and not alert.panel.visible, "clear_alerts debe vaciar todo")

	# --- 1. Una alerta se muestra.
	alert.show_alert("Uno", "Primera alerta", SHORT)
	await process_frame
	check(shown() and current_title() == "Uno" and alert.message.text == "Primera alerta", "Debe mostrarse la primera alerta")

	# --- 2, 8. Dos alertas: la segunda espera y aparece cuando la primera termina.
	alert.show_alert("Dos", "Segunda alerta", SHORT)
	check(current_title() == "Uno" and alert.get_pending_count() == 1, "La segunda debe esperar su turno")
	await wait(SHORT + 0.6)
	check(shown() and current_title() == "Dos" and alert.message.text == "Segunda alerta", "Al terminar la primera debe verse la segunda (actual: '%s')" % current_title())
	await wait(SHORT + 0.6)
	check(alert.get_current_alert() == null and not alert.panel.visible, "Sin más alertas el panel debe ocultarse")

	# --- 3. Un evento no se pierde por un aviso que llega después.
	alert.clear_alerts()
	events.actual_EventType = 0
	events.trigger_event(events.EventTypes.PERDIDA_PRESION)
	var event_title := current_title()
	check(event_title == "Pérdida de presión", "El evento debe mostrarse (actual: '%s')" % event_title)
	sim.tiempo_jornada = 100
	costs.energy_plant_state = "AVERIADO"
	tasks.start_task("energy_plant", "repair")  # 240 min > 100 -> aviso de tiempo
	check(current_title() == event_title and alert.message.text.contains("oxígeno"), "El aviso no debe reemplazar al evento en pantalla")
	check(alert.get_pending_count() == 1, "El aviso debe quedar en espera detrás del evento")

	# --- 4. El aviso de tiempo, cuando le toca, trae los valores reales.
	var waiting: Array = alert._queue.pending()
	check(waiting.size() == 1 and waiting[0].title == "Tiempo insuficiente" and waiting[0].message.contains("4:00 h") and waiting[0].message.contains("1:40 h"), "El aviso de tiempo debe decir 4:00 h y 1:40 h")

	# --- 6. Repetir el mismo aviso o el mismo evento no llena la cola.
	for i in 5:
		tasks.start_task("energy_plant", "repair")
	check(alert.get_pending_count() == 1, "Repetir el aviso no debe acumularlo (en espera: %d)" % alert.get_pending_count())
	sim.tiempo_jornada = 90
	tasks.start_task("energy_plant", "repair")
	waiting = alert._queue.pending()
	check(waiting.size() == 1 and waiting[0].message.contains("1:30 h"), "Un aviso del mismo tipo con otros minutos debe actualizar el que espera")
	alert.show_alert(event_title, alert.message.text, 20.0)
	check(alert.get_pending_count() == 1, "Una alerta idéntica a la actual no debe encolarse")

	# --- 5. Aviso de energía con la validación existente (costo de prueba en memoria).
	var had_energy: bool = costs.station_costs["energy_plant"]["repair"].has("energy")
	costs.station_costs["energy_plant"]["repair"]["energy"] = 30
	var old_energy: int = res.energy
	res.energy = 15
	sim.tiempo_jornada = 480
	var energy_signal := []
	tasks.insufficient_energy.connect(func(st, task, req, avail): energy_signal.append([st, task, req, avail]))
	check(not tasks.start_task("energy_plant", "repair"), "Sin energía suficiente la tarea no debe empezar")
	check(energy_signal == [["energy_plant", "repair", 30, 15]], "La señal de energía debe traer 30 y 15: %s" % str(energy_signal))
	waiting = alert._queue.pending()
	var energy_alert = waiting.filter(func(a): return a.title == "Energía insuficiente")
	check(energy_alert.size() == 1 and energy_alert[0].message.contains("30") and energy_alert[0].message.contains("15"), "El aviso de energía debe decir 30 y 15")
	check(sim.tiempo_jornada == 480 and tasks.current_task == "", "El rechazo por energía no descuenta tiempo")
	if not had_energy:
		costs.station_costs["energy_plant"]["repair"].erase("energy")
	res.energy = old_energy
	# Agua y comida siguen sin aviso (no son costos de actividad).
	check(not tasks.has_signal("insufficient_water") and not tasks.has_signal("insufficient_food"), "No debe haber avisos de agua o comida")

	# --- 7. Varias alertas en el mismo frame: todas entran, en orden, sin duplicados.
	alert.clear_alerts()
	for name in ["A", "B", "C", "B"]:
		alert.show_alert(name, "Alerta " + name, SHORT)
	check(current_title() == "A" and alert.get_pending_count() == 2, "Deben quedar A en pantalla y B, C en espera (en espera: %d)" % alert.get_pending_count())
	var order := [current_title()]
	for i in 2:
		await wait(SHORT + 0.6)
		order.append(current_title())
	check(order == ["A", "B", "C"], "Deben mostrarse en orden A, B, C: %s" % str(order))

	# --- 9. Un cambio de escena no pierde las alertas en espera.
	alert.clear_alerts()
	alert.show_alert("Antes", "Antes del cambio", 1.5)
	alert.show_alert("Después", "Debe sobrevivir al cambio de escena", SHORT)
	check(change_scene_to_file(GREENHOUSE) == OK, "invernadero no carga")
	await wait(0.2)
	check(current_title() == "Antes" and alert.get_pending_count() == 1, "El cambio de escena no debe vaciar la cola")
	await wait(1.5 + 0.6)
	check(current_title() == "Después" and shown(), "La alerta en espera debe mostrarse tras el cambio de escena")

	# --- Oculta (minijuego abierto): la alerta se congela y no caduca sin verse.
	alert.clear_alerts()
	alert.show_alert("Pausa", "No debe caducar oculta", SHORT)
	alert.show_alert("Siguiente", "Espera", SHORT)
	await wait(0.1)
	alert.visible = false
	var bar_before: float = alert.time_bar.value
	await wait(SHORT + 0.6)
	check(current_title() == "Pausa" and absf(alert.time_bar.value - bar_before) < 0.5, "Oculta, la alerta no debe avanzar ni caducar (barra %.1f -> %.1f)" % [bar_before, alert.time_bar.value])
	alert.visible = true
	await wait(SHORT + 0.6)
	check(current_title() == "Siguiente", "Al volver a verse, la cola debe continuar (actual: '%s')" % current_title())

	# --- Reinicio de partida: game_over vacía la cola.
	alert.show_alert("Pendiente", "Se debe borrar al reiniciar", 20.0)
	alert.clear_alerts()
	check(alert.get_current_alert() == null and alert.get_pending_count() == 0 and not alert.panel.visible, "Reiniciar debe vaciar la cola")

	alert.clear_alerts()
	events.actual_EventType = 0
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	print("ALERT QUEUE CHECKS: failures: %d" % failures)
	quit(0 if failures == 0 else 1)
