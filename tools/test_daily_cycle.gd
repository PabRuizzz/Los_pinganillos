extends SceneTree
## Valida el ciclo diario completo (inicio de día, tareas, fin de día, día siguiente).
##   godot --headless --path . --script res://tools/test_daily_cycle.gd
##
## Todo el estado que toca vive en memoria de este proceso (autoloads). No lee ni
## escribe archivos de progreso del jugador.
##
## Los autoloads aún no existen cuando se compila este script (--script), así que se
## obtienen en tiempo de ejecución con root.get_node().

const MAIN := "res://game/main/main.tscn"
const MARS := "res://game/stations/mars/mars.tscn"
const ROOM := "res://game/world/rooms/cuarto1.tscn"
const GREENHOUSE := "res://game/stations/greenhouse/greenhouse.tscn"

var failures := 0
var sim: Node        # SimulationTime
var tasks: Node      # TaskExecution
var res: Node        # Resources
var costs: Node      # StationCost
var events: Node     # Events

var log: Array = []            # orden de las señales del ciclo
var started_days: Array = []
var advanced_days: Array = []
var finished_count := 0
var exhausted_count := 0
var time_changed_count := 0
var task_finished_log: Array = []
var events_started := 0
var snapshot_at_day_finished := {}


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func go_to(path: String) -> void:
	check(change_scene_to_file(path) == OK, "No carga " + path)
	await process_frame
	await process_frame
	await frames(2)


func key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Deja la base sin evento activo y con todas las estaciones operativas.
func clear_events() -> void:
	events.actual_EventType = 0
	events.battery_active = false
	events.pipe_timer_active = false
	events.fungus_timer_active = false
	for station in ["energy_plant_state", "life_support_state", "water_station_state", "greenhouse_state"]:
		costs.set(station, "OPERATIVO")


func set_resources(energy: int, water: int, food: int) -> void:
	res.energy = energy
	res.water = water
	res.food = food
	res.oxygen = 100


func do_maintenance() -> bool:
	if not tasks.start_task("energy_plant", "maintenance"):
		return false
	tasks.finish_task()
	return true


func run_checks() -> void:
	sim = root.get_node("SimulationTime")
	tasks = root.get_node("TaskExecution")
	res = root.get_node("Resources")
	costs = root.get_node("StationCost")
	events = root.get_node("Events")

	tasks.day_started.connect(func(day): started_days.append(day); log.append("day_started"))
	tasks.day_finished.connect(func():
		finished_count += 1
		log.append("day_finished")
		snapshot_at_day_finished = {"day": sim.day, "time": sim.tiempo_jornada, "energy": res.energy, "water": res.water, "food": res.food, "active": tasks.day_active})
	tasks.task_finished.connect(func(station, task, spent): task_finished_log.append([station, task, spent]))
	sim.day_advanced.connect(func(day): advanced_days.append(day); log.append("day_advanced"))
	sim.work_budget_exhausted.connect(func(): exhausted_count += 1; log.append("work_budget_exhausted"))
	sim.simulation_time_changed.connect(func(): time_changed_count += 1)
	events.event_started.connect(func(_t, _title, _msg): events_started += 1)

	# --- 1-2. Partida nueva (main.tscn, como al abrir el juego).
	check(not tasks.day_active, "Antes de main.tscn el día no debe estar activo")
	await go_to(MAIN)
	check(sim.day == 1, "Una partida nueva empieza en el día 1")
	check(sim.MAX_JOURNEY_TIME == 480 and sim.tiempo_jornada == 480, "La jornada debe empezar con 480 minutos")
	check(sim.get_elapsed_time() == 0 and not sim.is_work_budget_exhausted(), "Al empezar no hay tiempo usado")
	check(tasks.day_active and started_days == [1], "day_started debe emitirse una vez con el día 1: %s" % str(started_days))
	check(events_started == 1 and events.actual_EventType != 0, "main.gd (event_chance = 1) debe lanzar un evento al iniciar el día 1")
	tasks.start_day()
	check(started_days == [1], "start_day con el día activo no debe reiniciar la jornada")

	# A partir de aquí, sin eventos al azar: base operativa y recursos conocidos.
	events.day_start_event_chance = 0.0
	clear_events()
	set_resources(50, 50, 50)

	# --- 3. Una tarea descuenta su tiempo exactamente una vez.
	time_changed_count = 0
	check(tasks.start_task("energy_plant", "maintenance"), "Debe poder iniciar el mantenimiento")
	check(sim.tiempo_jornada == 480, "Iniciar una tarea no descuenta tiempo todavía")
	check(not tasks.start_task("greenhouse", "maintenance"), "No se puede iniciar otra tarea con una en curso")
	tasks.finish_task()
	check(sim.tiempo_jornada == 360 and sim.get_elapsed_time() == 120, "El mantenimiento debe costar 120 minutos (quedan %d)" % sim.tiempo_jornada)
	tasks.finish_task()
	tasks.finish_task()
	check(sim.tiempo_jornada == 360 and task_finished_log.size() == 1, "finish_task repetido no debe volver a descontar tiempo")
	check(time_changed_count == 1, "simulation_time_changed debe emitirse una vez por tarea (fueron %d)" % time_changed_count)
	tasks.start_task("energy_plant", "maintenance")
	tasks.cancel_task()
	check(sim.tiempo_jornada == 360 and tasks.current_task == "", "Cancelar una tarea no descuenta tiempo")
	check(not tasks.start_task("no_existe", "maintenance") and not tasks.start_task("energy_plant", "no_existe"), "Tareas inválidas deben rechazarse")

	# --- 10 y 4. Cambiar de escena conserva el día; moverse no consume tiempo.
	for path in [ROOM, GREENHOUSE, MARS]:
		await go_to(path)
		check(sim.day == 1 and sim.tiempo_jornada == 360, "Cambiar a %s alteró el día o el tiempo" % path)
		check(tasks.day_active and started_days == [1] and finished_count == 0, "Cambiar a %s reinició o terminó el día" % path)
		check([res.energy, res.water, res.food] == [50, 50, 50], "Cambiar a %s aplicó recursos diarios" % path)
	var mars := current_scene
	var player: CharacterBody2D = mars.get_node("YSortObjects/player")
	var from := player.global_position
	key(KEY_RIGHT, true)
	await frames(60)
	key(KEY_RIGHT, false)
	await frames(2)
	check(player.global_position.distance_to(from) > 50.0, "El jugador debería haberse movido")
	check(sim.tiempo_jornada == 360 and sim.day == 1, "Moverse no debe consumir tiempo simulado")

	# --- 13. La estación de energía sigue funcionando con E y Esc.
	var energy_station: Area2D = mars.get_node("EnergyStation")
	costs.energy_plant_state = "DEGRADADO"
	player.global_position = energy_station.to_global(energy_station.get_node("CollisionShape2D").position)
	await frames(3)
	Input.action_press("interact")
	await frames(3)
	Input.action_release("interact")
	await frames(2)
	check(energy_station.active_minigame != null and tasks.current_task == "maintenance", "E en la estación de energía debe abrir el minijuego de mantenimiento")
	Input.action_press("ui_cancel")
	await frames(3)
	Input.action_release("ui_cancel")
	await frames(3)
	check(energy_station.active_minigame == null and tasks.current_task == "", "Esc debe cerrar el minijuego y liberar la tarea")
	check(sim.tiempo_jornada == 360, "Salir del minijuego con Esc no debe consumir tiempo")
	clear_events()

	# --- 11-12 (parte 1). El rover sale hoy.
	var rover: Node = mars.get_node("RoverExpeditionController")
	var rover_returns: Array = []
	rover.reset()
	rover.expedition_returned.connect(func(dep: int, day: int): rover_returns.append([dep, day]))
	check(rover.start_expedition() and rover.get_return_day() == 2, "El rover debe salir el día 1 y volver el 2")

	# --- 5. Sin tiempo suficiente, la tarea no empieza.
	check(do_maintenance() and do_maintenance(), "Deben caber dos mantenimientos más")
	check(sim.tiempo_jornada == 120, "Deberían quedar 120 minutos (quedan %d)" % sim.tiempo_jornada)
	check(not tasks.start_task("energy_plant", "repair"), "Una reparación de 240 no cabe en 120 minutos")
	check(sim.tiempo_jornada == 120 and sim.day == 1 and tasks.current_task == "", "Un intento rechazado no debe cambiar nada")
	check(rover.is_on_expedition() and rover_returns.is_empty(), "El rover no debe volver el día de salida")

	# --- 6-9. Agotar la jornada termina el día una sola vez y empieza el siguiente.
	set_resources(50, 50, 50)
	log.clear()
	check(do_maintenance(), "Debe caber el último mantenimiento")
	check(sim.day == 2 and advanced_days == [2], "Agotar la jornada debe avanzar al día 2: %s" % str(advanced_days))
	check(finished_count == 1 and exhausted_count == 1, "El día debe terminar una sola vez (day_finished=%d, agotado=%d)" % [finished_count, exhausted_count])
	check(log == ["work_budget_exhausted", "day_advanced", "day_finished", "day_started"], "Orden de señales inesperado: %s" % str(log))
	check(started_days == [1, 2] and tasks.day_active, "El día 2 debe empezar solo: %s" % str(started_days))
	check(sim.tiempo_jornada == 480 and sim.get_elapsed_time() == 0, "La jornada debe volver a 480 minutos")
	# Todo OPERATIVO: energía +1 (planta) +0 (soporte), agua -1, comida +1.
	check([res.energy, res.water, res.food] == [51, 49, 51], "Recursos diarios incorrectos: %s" % str([res.energy, res.water, res.food]))
	check(snapshot_at_day_finished == {"day": 2, "time": 0, "energy": 51, "water": 49, "food": 51, "active": false}, "En day_finished el día ya debe ser el nuevo y los recursos estar aplicados: %s" % str(snapshot_at_day_finished))
	check(res.oxygen == 100, "El oxígeno debe reiniciarse al empezar el día")

	# --- 11-12 (parte 2). El rover vuelve una vez, el día esperado.
	check(rover_returns == [[1, 2]] and rover.is_available(), "El rover debe volver una vez al empezar el día 2: %s" % str(rover_returns))

	# --- Cambiar de escena tras el cambio de día no repite nada.
	await go_to(GREENHOUSE)
	await go_to(MARS)
	check(sim.day == 2 and sim.tiempo_jornada == 480 and started_days == [1, 2] and finished_count == 1, "Volver a Marte repitió el inicio o el fin del día")
	check([res.energy, res.water, res.food] == [51, 49, 51], "Volver a Marte volvió a aplicar recursos")
	check(rover_returns.size() == 1 and current_scene.get_node("RoverExpeditionController").is_available(), "Volver a Marte repitió el regreso del rover")

	# --- Terminar el día antes de tiempo: los recursos se aplican igual, una vez.
	costs.greenhouse_state = "AVERIADO"  # comida -6
	check(tasks.start_task("energy_plant", "maintenance"), "Debe poder iniciar una tarea el día 2")
	tasks.finish_day()
	check(sim.day == 3 and finished_count == 2 and started_days == [1, 2, 3], "finish_day directo debe pasar al día 3 una vez")
	check(tasks.current_task == "" and sim.tiempo_jornada == 480, "La tarea en curso se libera sin costo y la jornada se reinicia")
	check([res.energy, res.water, res.food] == [52, 48, 45], "Terminar antes no debe saltarse los recursos: %s" % str([res.energy, res.water, res.food]))
	check(exhausted_count == 1, "work_budget_exhausted no debe emitirse si la jornada no se agotó")

	# --- finish_day no puede ejecutarse con el día inactivo (doble llamada).
	tasks.day_active = false
	tasks.finish_day()
	check(sim.day == 3 and finished_count == 2 and [res.energy, res.water, res.food] == [52, 48, 45], "finish_day con el día inactivo no debe hacer nada")
	tasks.day_active = true

	# --- 13. Evento al iniciar cada día, con la probabilidad de main.gd.
	clear_events()
	events.day_start_event_chance = 1.0
	events_started = 0
	tasks.finish_day()
	check(sim.day == 4 and events_started == 1 and events.actual_EventType != 0, "Con probabilidad 1 debe empezar un evento al iniciar el día 4")
	tasks.finish_day()
	check(events_started == 1, "No debe empezar otro evento mientras hay uno activo")

	print("DAILY CYCLE CHECKS: failures: %d" % failures)
	quit(0 if failures == 0 else 1)
