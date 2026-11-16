extends SceneTree
## Valida la interacción común con E (StationInteraction) y la apertura de minijuegos
## de las estaciones de Marte (StationMinigame).
##   godot --headless --path . --script res://tools/test_station_interaction.gd
##
## Todo el estado vive en memoria (autoloads). Cualquier SampleDiscovery usa un archivo
## de prueba, nunca el progreso real. Los scripts que usan autoloads se tratan sin tipo
## porque los autoloads aún no existen cuando se compila este script (--script).

const MARS := "res://game/stations/mars/mars.tscn"
const TEST_DISCOVERY_SAVE := "user://test_isolated_sample_discovery.cfg"
const INTERACTION_SCRIPT := "res://game/systems/station_interaction/station_interaction.gd"
const STATIONS := {
	"EnergyStation": {
		"state": "energy_plant_state",
		"maintenance": "res://game/challenges/solar_cleaning/solar_cleaning.tscn",
		"repair": "res://game/challenges/electrical_repair/electrical_repair.tscn",
	},
	"WaterStation": {
		"state": "water_station_state",
		"maintenance": "res://game/challenges/water_pumping/water_pumping.tscn",
		"repair": "res://game/challenges/water_pumping/water_pumping.tscn",
	},
}

var failures := 0
var sim: Node
var tasks: Node
var costs: Node
var events: Node
var mars: Node
var player: CharacterBody2D
var started_days := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func place(pos: Vector2) -> void:
	player.global_position = pos
	await frames(3)


func press(action: String, hold_frames := 2) -> void:
	Input.action_press(action)
	await frames(hold_frames)
	Input.action_release(action)
	await frames(2)


func clear_events() -> void:
	events.actual_EventType = 0
	events.battery_active = false
	events.pipe_timer_active = false
	events.fungus_timer_active = false
	for station in ["energy_plant_state", "life_support_state", "water_station_state", "greenhouse_state"]:
		costs.set(station, "OPERATIVO")


## Nodos de minijuego abiertos ahora mismo en la escena (para detectar duplicados).
func open_minigames() -> Array:
	var found := []
	for path in ["maintenance", "repair"]:
		for station in STATIONS.values():
			for node in mars.find_children("*", "", true, false):
				if node.scene_file_path == station[path] and not node.is_queued_for_deletion():
					if node not in found:
						found.append(node)
	return found


func complete(minigame: Node) -> void:
	if minigame.has_signal("puzzle_completed"):
		minigame.emit_signal("puzzle_completed", 0, 0)
	elif minigame.has_signal("cleaning_completed"):
		minigame.emit_signal("cleaning_completed")
	else:
		minigame.emit_signal("completed")


func cue_bottom_center(cue: Control) -> Vector2:
	var rect := cue.get_global_rect()
	return Vector2(rect.position.x + rect.size.x / 2.0, rect.end.y)



## Fija la semilla para que el próximo randf() no lance el evento encadenado del 30 %
## que Events tira al resolver una reparación (así la prueba es determinista).
func suppress_follow_up_event() -> void:
	var s := 0
	while true:
		seed(s)
		if randf() >= 0.3:
			break
		s += 1
	seed(s)

func run_checks() -> void:
	sim = root.get_node("SimulationTime")
	tasks = root.get_node("TaskExecution")
	costs = root.get_node("StationCost")
	events = root.get_node("Events")
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	node_added.connect(func(node: Node):
		if node is SampleDiscovery:
			node.save_path = TEST_DISCOVERY_SAVE)
	tasks.day_started.connect(func(_d): started_days += 1)

	check(change_scene_to_file(MARS) == OK, "mars.tscn no carga")
	await process_frame
	await frames(4)
	mars = current_scene
	player = mars.get_node("YSortObjects/player")
	if not tasks.day_active:
		tasks.start_day()
	clear_events()
	started_days = 0
	var day: int = sim.day
	var lock_owner: GDScript = load(INTERACTION_SCRIPT)

	# --- La estación del rover usa el mismo componente y su indicador no se movió.
	var rover: Node2D = mars.get_node("YSortObjects/RoverStation")
	var rover_area: Area2D = rover.get_node("InteractionArea")
	check(rover_area.get_script() == lock_owner, "La estación del rover debe usar StationInteraction")
	var rover_cue: Control = rover_area.get_node("InteractCue")
	check(rover_cue.position == Vector2(-15, -150) and rover_cue.scale == Vector2(0.3, 0.3), "El indicador del rover debe conservar su posición y tamaño")

	for station_name in STATIONS:
		var info: Dictionary = STATIONS[station_name]
		var area: Area2D = mars.get_node(station_name)
		var launcher: Node = area.get_node("Minigame")
		var cue: Control = area.get_node("InteractCue")
		var in_range := area.to_global(area.get_node("CollisionShape2D").position)
		var far := in_range + Vector2(-280, 0)  # de lado: las áreas de energía están apiladas en vertical
		check(area.get_script() == lock_owner, "%s debe usar StationInteraction" % station_name)
		check(area.is_visible_in_tree(), "%s debe estar visible para mostrar su indicador" % station_name)
		check(cue.text == rover_cue.text and cue.scale == rover_cue.scale and cue.get_theme_font_size("font_size") == rover_cue.get_theme_font_size("font_size"), "%s debe usar el mismo indicador [E] que el rover" % station_name)

		# 1-3. Indicador y rango.
		await place(far)
		check(not area.is_player_near() and not cue.visible, "%s: fuera de rango no debe verse [E]" % station_name)
		costs.set(info.state, "DEGRADADO")
		await press("interact")
		check(open_minigames().is_empty() and tasks.current_task == "", "%s: E fuera de rango no debe abrir nada" % station_name)
		await place(in_range)
		check(area.is_player_near() and cue.visible, "%s: dentro del rango debe verse [E]" % station_name)
		var nearest := Vector2.INF
		for child in area.get_children():
			if child is Marker2D and child.global_position.distance_to(player.global_position) < nearest.distance_to(player.global_position):
				nearest = child.global_position
		check(nearest != Vector2.INF and cue_bottom_center(cue).distance_to(nearest) < 1.0, "%s: [E] debe colocarse sobre su marcador más cercano" % station_name)
		await place(far)
		check(not cue.visible, "%s: al salir del rango [E] debe ocultarse" % station_name)

		# 7. Desactivada: ni indicador ni interacción.
		await place(in_range)
		area.set_interaction_enabled(false)
		await frames(2)
		check(not cue.visible, "%s: desactivada no debe mostrar [E]" % station_name)
		await press("interact")
		check(open_minigames().is_empty(), "%s: desactivada no debe abrir el minijuego" % station_name)
		area.set_interaction_enabled(true)
		await frames(2)

		# 4-5, 9-10. DEGRADADO: mantener E abre UN minijuego de mantenimiento.
		var time_before: int = sim.tiempo_jornada
		await press("interact", 8)
		var opened := open_minigames()
		check(opened.size() == 1 and opened[0].scene_file_path == info.maintenance, "%s: debe abrir un solo minijuego de mantenimiento (%s)" % [station_name, str(opened.map(func(n): return n.scene_file_path))])
		check(tasks.current_station == costs.station_costs.keys()[costs.station_costs.keys().find(launcher.station_id)] and tasks.current_task == "maintenance", "%s: debe iniciar la tarea de mantenimiento" % station_name)
		check(sim.tiempo_jornada == time_before, "%s: abrir el minijuego no descuenta tiempo" % station_name)
		check(lock_owner.locked and not cue.visible, "%s: con el minijuego abierto las estaciones se bloquean" % station_name)
		check(not mars.get_node("YSortObjects").visible and not player.is_physics_processing(), "%s: el mundo se oculta y el jugador se congela" % station_name)
		await press("interact", 4)
		check(open_minigames().size() == 1, "%s: E con el minijuego abierto no debe abrir otro" % station_name)

		# 8, 10. Completar: tiempo descontado una vez, vuelta a Marte sin cambiar de escena.
		var minigame: Node = launcher.active_minigame
		complete(minigame)
		complete(minigame)
		await frames(3)
		var cost: int = costs.station_costs[launcher.station_id]["maintenance"]["time"]
		check(sim.tiempo_jornada == time_before - cost, "%s: el mantenimiento debe descontar %d min una vez (quedan %d)" % [station_name, cost, sim.tiempo_jornada])
		check(tasks.current_task == "" and costs.get(info.state) == "OPERATIVO", "%s: la tarea termina y la estación queda OPERATIVO" % station_name)
		check(open_minigames().is_empty() and launcher.active_minigame == null, "%s: el minijuego debe cerrarse" % station_name)
		check(current_scene == mars and mars.get_node("YSortObjects").visible and player.is_physics_processing(), "%s: debe volver a Marte con el mundo visible y el jugador libre" % station_name)
		check(not lock_owner.locked and cue.visible, "%s: tras cerrar, las estaciones se desbloquean" % station_name)
		check(sim.day == day and started_days == 0, "%s: el minijuego no debe cambiar de día" % station_name)

		# AVERIADO: abre la reparación; Esc sale sin costo.
		costs.set(info.state, "AVERIADO")
		time_before = sim.tiempo_jornada
		await press("interact")
		opened = open_minigames()
		check(opened.size() == 1 and opened[0].scene_file_path == info.repair, "%s: AVERIADO debe abrir el minijuego de reparación" % station_name)
		check(tasks.current_task == "repair", "%s: debe iniciar la tarea de reparación" % station_name)
		await press("ui_cancel")
		await frames(2)
		check(open_minigames().is_empty() and tasks.current_task == "" and sim.tiempo_jornada == time_before, "%s: Esc debe cerrar sin descontar tiempo" % station_name)
		check(costs.get(info.state) == "AVERIADO", "%s: salir con Esc no repara la estación" % station_name)

		# OPERATIVO: no abre nada.
		costs.set(info.state, "OPERATIVO")
		await press("interact")
		check(open_minigames().is_empty() and tasks.current_task == "", "%s: OPERATIVO no debe abrir minijuego" % station_name)
		await place(far)

	# --- Tuberías congeladas: la estación queda AVERIADO y abre el bombeo como
	# reparación; completarlo resuelve el evento.
	clear_events()
	var frozen: int = events.EventTypes.CONGELAMIENTO_TUBERIAS
	var water: Area2D = mars.get_node("WaterStation")
	var water_launcher: Node = water.get_node("Minigame")
	# (Al resolver un evento, Events puede lanzar otro al azar con un 30 %: se comprueba
	# la señal event_resolved y no que no quede ningún evento activo.)
	var resolved := []
	events.event_resolved.connect(func(type): resolved.append(type))
	events.trigger_event(frozen)
	check(events.actual_EventType == frozen and costs.water_station_state == "AVERIADO", "El evento debe dejar la estación de agua AVERIADO")
	# Las pruebas anteriores gastaron 240 min; con jornada completa la reparación (240)
	# no agota el día y se puede comprobar el descuento exacto.
	sim.reset_daily_time()
	var event_time: int = sim.tiempo_jornada
	await place(water.to_global(water.get_node("CollisionShape2D").position))
	await press("interact")
	var event_open := open_minigames()
	check(event_open.size() == 1 and event_open[0].scene_file_path == STATIONS.WaterStation.repair, "Con tuberías congeladas, E debe abrir el bombeo de agua")
	check(tasks.current_task == "repair", "Debe iniciar la tarea de reparación (no la de mantenimiento)")
	suppress_follow_up_event()
	complete(water_launcher.active_minigame)
	await frames(3)
	var repair_cost: int = costs.station_costs["water_station"]["repair"]["time"]
	check(sim.tiempo_jornada == event_time - repair_cost, "La reparación debe descontar %d min una vez (quedan %d)" % [repair_cost, sim.tiempo_jornada])
	check(resolved == [frozen] and events.actual_EventType != frozen, "Completar la reparación debe resolver el evento: %s" % str(resolved))
	check(events.actual_EventType == 0 and not events.pipe_timer_active and costs.water_station_state == "OPERATIVO", "La estación de agua debe quedar OPERATIVO y sin evento")
	clear_events()
	# Sin el evento, DEGRADADO vuelve a abrir el bombeo.
	costs.water_station_state = "DEGRADADO"
	await press("interact")
	event_open = open_minigames()
	check(event_open.size() == 1 and event_open[0].scene_file_path == STATIONS.WaterStation.maintenance, "Sin evento, DEGRADADO debe abrir el bombeo")
	await press("ui_cancel")
	costs.water_station_state = "OPERATIVO"
	await place(water.to_global(water.get_node("CollisionShape2D").position) + Vector2(-280, 0))

	# --- 6. Áreas solapadas: solo responde la más cercana.
	var energy: Area2D = mars.get_node("EnergyStation")
	var energy_cue: Control = energy.get_node("InteractCue")
	var energy_pos := energy.to_global(energy.get_node("CollisionShape2D").position)
	var extra: Area2D = lock_owner.new()
	extra.name = "OverlapProbe"
	extra.collision_layer = 4
	extra.collision_mask = 3
	var circle := CollisionShape2D.new()
	circle.shape = CircleShape2D.new()
	circle.shape.radius = 400.0
	extra.add_child(circle)
	var extra_presses := [0]
	extra.interaction_requested.connect(func(): extra_presses[0] += 1)
	mars.add_child(extra)
	extra.global_position = energy_pos + Vector2(300, 0)
	costs.energy_plant_state = "DEGRADADO"
	await place(energy_pos)
	check(energy.is_player_near() and extra.is_player_near(), "Las dos áreas deben detectar al jugador")
	check(energy_cue.visible and not extra.get_node("InteractCue").visible, "Solo la estación más cercana debe mostrar [E]")
	await press("interact", 6)
	check(open_minigames().size() == 1 and extra_presses[0] == 0, "Una pulsación con áreas solapadas debe activar solo la más cercana")
	await press("ui_cancel")
	# Al cerrar, el jugador recupera su física y se separa del colisionador del panel;
	# se le congela y se vuelve a colocar para comparar distancias exactas.
	player.set_physics_process(false)
	await place(energy_pos)
	extra.global_position = energy_pos + Vector2(0, 10)
	await frames(3)
	check(not energy_cue.visible and extra.get_node("InteractCue").visible, "Al acercarse a la otra, el [E] debe cambiar de estación")
	await press("interact", 6)
	check(extra_presses[0] == 1 and open_minigames().is_empty() and tasks.current_task == "", "Ahora solo debe responder la otra área")
	extra.queue_free()
	await frames(2)

	check(sim.day == day and started_days == 0, "Las interacciones no deben cambiar de día")
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	print("STATION INTERACTION CHECKS: failures: %d" % failures)
	quit(0 if failures == 0 else 1)
