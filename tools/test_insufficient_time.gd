extends SceneTree
## Valida el aviso "Tiempo insuficiente": TaskExecution rechaza la tarea sin descontar
## tiempo y Alert lo muestra con el tiempo necesario y el disponible.
##   godot --headless --path . --script res://tools/test_insufficient_time.gd
##
## Todo el estado vive en memoria (autoloads); no se toca el progreso del jugador.
## Los autoloads se obtienen en tiempo de ejecución porque aún no existen cuando se
## compila este script (--script).

const MARS := "res://game/stations/mars/mars.tscn"
const GREENHOUSE := "res://game/stations/greenhouse/greenhouse.tscn"
const CAMP := "res://game/stations/campament/campament.tscn"
const TEST_DISCOVERY_SAVE := "user://test_isolated_sample_discovery.cfg"

var failures := 0
var sim: Node
var tasks: Node
var costs: Node
var events: Node
var alert: CanvasLayer
var player: CharacterBody2D
var rejected: Array = []


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func go_to(path: String) -> Node:
	check(change_scene_to_file(path) == OK, "No carga " + path)
	await process_frame
	await frames(4)
	player = current_scene.find_child("player", true, false)
	player.set_physics_process(false)
	return current_scene


func press(action: String, hold := 2) -> void:
	Input.action_press(action)
	await frames(hold)
	Input.action_release(action)
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


## Oculta la alerta actual para que la siguiente se lea desde cero.
func reset_alert() -> void:
	alert.clear_alerts()  # incluye la alerta de la tormenta inicial y las que esperan
	alert.title.text = ""
	alert.message.text = ""
	rejected.clear()


func alert_says(required: String, available: String) -> bool:
	return alert.panel.visible and alert.title.text == "Tiempo insuficiente" \
		and alert.message.text.contains(required) and alert.message.text.contains(available)


## Pulsa E en una estación con el tiempo indicado y comprueba que se rechaza.
func check_station_rejects(station: Area2D, state_var: String, state: String, station_id: String, task: String, available: int) -> void:
	var label := "%s (%s)" % [station.name, task]
	reset_alert()
	costs.set(state_var, state)
	sim.tiempo_jornada = available
	var day: int = sim.day
	player.global_position = station.to_global(station.get_node("CollisionShape2D").position)
	await frames(3)
	check(station.is_player_near(), "%s: el jugador debe estar en rango" % label)
	await press("interact")
	var required: int = costs.station_costs[station_id][task]["time"]
	check(rejected == [[station_id, task, required, available]], "%s: debe avisar con (%d, %d): %s" % [label, required, available, str(rejected)])
	check(alert_says(alert.format_time(required), alert.format_time(available)), "%s: la alerta debe decir %s y %s ('%s')" % [label, alert.format_time(required), alert.format_time(available), alert.message.text])
	check(tasks.current_task == "" and sim.tiempo_jornada == available and sim.day == day, "%s: no debe iniciar la tarea, descontar tiempo ni cambiar de día" % label)
	check(station.get_node("Minigame").active_minigame == null, "%s: no debe abrir el minijuego" % label)
	costs.set(state_var, "OPERATIVO")


func run_checks() -> void:
	sim = root.get_node("SimulationTime")
	tasks = root.get_node("TaskExecution")
	costs = root.get_node("StationCost")
	events = root.get_node("Events")
	alert = root.get_node("Alert")
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	node_added.connect(func(node: Node):
		if node is SampleDiscovery:
			node.save_path = TEST_DISCOVERY_SAVE)
	tasks.insufficient_time.connect(func(station, task, required, available): rejected.append([station, task, required, available]))

	await go_to(MARS)
	if not tasks.day_active:
		tasks.start_day()
	clear_events()
	var repair_cost: int = costs.station_costs["energy_plant"]["repair"]["time"]       # 240
	var maintenance_cost: int = costs.station_costs["energy_plant"]["maintenance"]["time"]  # 120

	# --- 1, 6. Con el tiempo justo, la tarea empieza y no hay aviso.
	reset_alert()
	sim.tiempo_jornada = repair_cost
	check(tasks.start_task("energy_plant", "repair"), "Con el tiempo justo la tarea debe empezar")
	check(rejected.is_empty() and not alert.panel.visible, "Con el tiempo justo no debe haber aviso")
	tasks.cancel_task()
	check(sim.tiempo_jornada == repair_cost, "Cancelar no debe descontar tiempo")

	# --- 2-5. Un minuto menos: se rechaza y avisa con los minutos reales.
	reset_alert()
	sim.tiempo_jornada = repair_cost - 1
	var day: int = sim.day
	check(not tasks.start_task("energy_plant", "repair"), "Con un minuto menos la tarea debe rechazarse")
	check(rejected == [["energy_plant", "repair", repair_cost, repair_cost - 1]], "La señal debe traer el costo y el tiempo disponibles reales: %s" % str(rejected))
	check(alert_says("4:00 h", "3:59 h"), "La alerta debe decir 4:00 h y 3:59 h: '%s'" % alert.message.text)
	check(tasks.current_task == "" and sim.tiempo_jornada == repair_cost - 1 and sim.day == day and tasks.day_active, "El rechazo no descuenta tiempo ni termina el día")

	# --- 7. Sin tiempo: se rechaza.
	reset_alert()
	sim.tiempo_jornada = 0
	check(not tasks.start_task("energy_plant", "maintenance"), "Sin tiempo la tarea debe rechazarse")
	check(alert_says("2:00 h", "0:00 h"), "La alerta debe decir 2:00 h y 0:00 h: '%s'" % alert.message.text)
	check(sim.day == day and tasks.day_active, "Quedarse sin tiempo al intentar una tarea no termina el día")

	# --- Día inactivo: no empieza y no avisa de tiempo.
	reset_alert()
	sim.tiempo_jornada = 480
	tasks.day_active = false
	check(not tasks.start_task("energy_plant", "maintenance") and rejected.is_empty(), "Con el día inactivo no debe empezar ni avisar de tiempo")
	tasks.day_active = true

	# --- Tarea más larga que un día entero: explica el máximo.
	reset_alert()
	costs.station_costs["energy_plant"]["repair"]["time"] = 600
	check(not tasks.start_task("energy_plant", "repair"), "Una tarea más larga que el día debe rechazarse")
	check(alert.message.text.contains("10:00 h") and alert.message.text.contains("8:00 h") and alert.message.text.contains("un día"), "Debe explicar que el día solo tiene 8:00 h: '%s'" % alert.message.text)
	costs.station_costs["energy_plant"]["repair"]["time"] = repair_cost

	# --- 9. Intentos repetidos: la misma alerta no se reinicia ni se duplica.
	reset_alert()
	sim.tiempo_jornada = 100
	tasks.start_task("energy_plant", "repair")
	await frames(30)
	var bar_after_first: float = alert.time_bar.value
	tasks.start_task("energy_plant", "repair")
	tasks.start_task("energy_plant", "repair")
	await frames(2)
	check(bar_after_first < 100.0 and alert.time_bar.value <= bar_after_first, "Repetir el intento no debe reiniciar la alerta (barra %.1f -> %.1f)" % [bar_after_first, alert.time_bar.value])
	check(alert.find_children("*", "PanelContainer", false, false).size() == 1, "Debe haber una sola alerta")
	# Con otros números sí se actualiza.
	sim.tiempo_jornada = 90
	tasks.start_task("energy_plant", "repair")
	check(alert_says("4:00 h", "1:30 h"), "Con otros minutos la alerta debe actualizarse: '%s'" % alert.message.text)

	# --- 8. Todas las estaciones con tareas, pulsando E de verdad.
	var mars := current_scene
	await check_station_rejects(mars.get_node("EnergyStation"), "energy_plant_state", "DEGRADADO", "energy_plant", "maintenance", 100)
	await check_station_rejects(mars.get_node("EnergyStation"), "energy_plant_state", "AVERIADO", "energy_plant", "repair", 200)
	await check_station_rejects(mars.get_node("WaterStation"), "water_station_state", "DEGRADADO", "water_station", "maintenance", 60)
	await check_station_rejects(mars.get_node("WaterStation"), "water_station_state", "AVERIADO", "water_station", "repair", 239)
	var greenhouse := await go_to(GREENHOUSE)
	await check_station_rejects(greenhouse.get_node("PlantsStation"), "greenhouse_state", "DEGRADADO", "greenhouse", "maintenance", 119)
	await check_station_rejects(greenhouse.get_node("PlantsStation"), "greenhouse_state", "AVERIADO", "greenhouse", "repair", 30)
	var camp := await go_to(CAMP)
	await check_station_rejects(camp.get_node("LifeSupportStation"), "life_support_state", "AVERIADO", "life_support", "repair", 120)

	# --- 10. Con tiempo suficiente la estación abre el minijuego; cancelar no cobra.
	var life: Area2D = camp.get_node("LifeSupportStation")
	reset_alert()
	sim.tiempo_jornada = 480
	costs.life_support_state = "AVERIADO"
	player.global_position = life.to_global(life.get_node("CollisionShape2D").position)
	await frames(3)
	await press("interact")
	check(life.get_node("Minigame").active_minigame != null and rejected.is_empty(), "Con tiempo suficiente debe abrir el minijuego sin aviso")
	await press("ui_cancel")
	await frames(2)
	check(tasks.current_task == "" and sim.tiempo_jornada == 480, "Salir con Esc no descuenta tiempo")
	costs.life_support_state = "OPERATIVO"

	# --- 11. Fin automático: una tarea con el tiempo justo agota la jornada y pasa el día.
	reset_alert()
	day = sim.day
	sim.tiempo_jornada = maintenance_cost
	check(tasks.start_task("energy_plant", "maintenance"), "Con el tiempo justo la última tarea debe empezar")
	tasks.finish_task()
	check(sim.day == day + 1 and sim.tiempo_jornada == 480 and rejected.is_empty(), "Agotar la jornada debe pasar al día siguiente sin aviso de tiempo")

	# --- 12. El botón Terminar día sigue funcionando (con poco tiempo, sin aviso).
	sim.tiempo_jornada = 30
	day = sim.day
	check(tasks.request_end_day() and sim.day == day + 1 and sim.tiempo_jornada == 480, "Terminar el día a mano debe seguir funcionando")
	check(rejected.is_empty(), "Terminar el día no debe mostrar el aviso de tiempo")

	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	print("INSUFFICIENT TIME CHECKS: failures: %d" % failures)
	quit(0 if failures == 0 else 1)
