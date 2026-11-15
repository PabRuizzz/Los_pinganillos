extends SceneTree
## Valida el invernadero (Marte) y el soporte vital (interior del campamento):
## colisión, rango, indicador [E] y minijuegos.
##   godot --headless --path . --script res://tools/test_greenhouse_life_support.gd
##
## Todo el estado vive en memoria (autoloads); no se toca el progreso del jugador.
## Los scripts que usan autoloads se tratan sin tipo porque los autoloads aún no
## existen cuando se compila este script (--script).

const MARS := "res://game/stations/mars/mars.tscn"
const CAMP := "res://game/stations/campament/campament.tscn"
const AIR_LEAKS := "res://game/challenges/air_leaks/air_leaks.tscn"
const TEST_DISCOVERY_SAVE := "user://test_isolated_sample_discovery.cfg"

var failures := 0
var sim: Node
var tasks: Node
var costs: Node
var events: Node
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


func go_to(path: String) -> Node:
	check(change_scene_to_file(path) == OK, "No carga " + path)
	await process_frame
	await frames(4)
	player = current_scene.find_child("player", true, false)
	player.set_physics_process(false)  # lo movemos desde la prueba
	return current_scene


func place(pos: Vector2) -> void:
	player.global_position = pos
	await frames(3)


## Mueve al jugador con física real y devuelve dónde se detuvo.
func walk(from: Vector2, velocity: Vector2, steps: int) -> Vector2:
	await place(from)
	for i in steps:
		player.velocity = velocity
		player.move_and_slide()
		await physics_frame
	return player.global_position


## Borde del colisionador del jugador (no depende de dónde esté su origen).
func collider_rect() -> Rect2:
	var shape := player.get_node("CollisionShape2D") as CollisionShape2D
	var size := (shape.shape as RectangleShape2D).size
	return Rect2(player.global_position + shape.position - size / 2.0, size)


func press(action: String, hold := 2) -> void:
	Input.action_press(action)
	await frames(hold)
	Input.action_release(action)
	await frames(2)


func minigames_open() -> Array:
	return current_scene.find_children("*", "", true, false).filter(func(n): return n.scene_file_path == AIR_LEAKS and not n.is_queued_for_deletion())


func clear_events() -> void:
	events.actual_EventType = 0
	events.battery_active = false
	events.pipe_timer_active = false
	events.fungus_timer_active = false
	for station in ["energy_plant_state", "life_support_state", "water_station_state", "greenhouse_state"]:
		costs.set(station, "OPERATIVO")



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

	# ======================= INVERNADERO (Marte) =======================
	var mars := await go_to(MARS)
	if not tasks.day_active:
		tasks.start_day()
	clear_events()
	started_days = 0
	var day: int = sim.day
	var greenhouse_art: Node2D = mars.get_node("greenhouse")
	var station: Area2D = mars.get_node("GreenhouseStation")
	var cue: Control = station.get_node("InteractCue")
	var range_pos := station.global_position

	# 1. La colisión del invernadero bloquea su base.
	var stop := await walk(Vector2(-60, -120), Vector2(0, -200), 60)
	var top := collider_rect().position.y
	check(top > -215.0 and top < -195.0, "El invernadero debe detener al jugador en su base (borde superior y=%.1f)" % top)
	stop = await walk(Vector2(-20, -540), Vector2(0, 200), 60)
	var bottom := collider_rect().end.y
	check(bottom < -465.0, "Desde atrás no se debe poder entrar al invernadero (borde inferior y=%.1f)" % bottom)
	# 3. Se puede rodear: por delante y por los dos lados.
	stop = await walk(Vector2(-230, -180), Vector2(200, 0), 120)
	check(stop.x > 140.0, "Por delante del invernadero se debe poder pasar (x=%.1f)" % stop.x)
	stop = await walk(Vector2(-205, -160), Vector2(0, -200), 130)
	check(stop.y < -480.0, "Por el lado izquierdo se debe poder rodear (y=%.1f)" % stop.y)
	stop = await walk(Vector2(150, -160), Vector2(0, -200), 130)
	check(stop.y < -480.0, "Por el lado derecho se debe poder rodear (y=%.1f)" % stop.y)

	# 11. Orden de dibujo: la colisión cubre el edificio, así que el jugador nunca queda
	# detrás de él, y el invernadero se dibuja antes que los objetos con orden Y.
	check(greenhouse_art.get_index() < mars.get_node("YSortObjects").get_index(), "El invernadero debe dibujarse antes que YSortObjects")

	# 4-6. Indicador y rango; la puerta no está dentro del rango.
	var door_rect: Rect2
	var door: Area2D = mars.get_node("hitbox/StaticBody2D/puerta")
	var door_shape: CollisionShape2D = door.get_node("CollisionShape2D")
	door_rect = Rect2(door_shape.to_global(door_shape.shape.get_rect().position), door_shape.shape.get_rect().size * door_shape.global_scale)
	var range_shape: CollisionShape2D = station.get_node("CollisionShape2D")
	var range_rect := Rect2(range_shape.to_global(range_shape.shape.get_rect().position), range_shape.shape.get_rect().size * range_shape.global_scale)
	check(not range_rect.intersects(door_rect), "El rango del invernadero no debe tocar la puerta (%s / %s)" % [range_rect, door_rect])
	await place(range_pos + Vector2(0, 150))
	check(not cue.visible and not station.is_player_near(), "Invernadero: lejos no debe verse [E]")
	costs.greenhouse_state = "DEGRADADO"
	var presses := [0]
	station.interaction_requested.connect(func(): presses[0] += 1)
	await press("interact")
	check(presses[0] == 0, "Invernadero: E fuera de rango no debe hacer nada")
	await place(range_pos + Vector2(0, 5))
	check(station.is_player_near() and cue.visible, "Invernadero: dentro del rango debe verse [E]")
	check(cue.get_theme_font_size("font_size") == 44 and cue.text == "[E]" and cue.scale == Vector2(0.3, 0.3), "Invernadero: debe usar el mismo indicador que el rover")

	# 7-8. E dentro del rango: una interacción por pulsación; sin minijuego, no inicia tarea.
	var time_before: int = sim.tiempo_jornada
	await press("interact", 8)
	check(presses[0] == 1, "Invernadero: mantener E debe interactuar una vez (fueron %d)" % presses[0])
	check(tasks.current_task == "" and sim.tiempo_jornada == time_before, "Invernadero: sin minijuego no debe iniciar tarea ni descontar tiempo")
	check(station.get_node("Minigame").maintenance_minigame == null and station.get_node("Minigame").repair_minigame == null, "Invernadero: no debe tener minijuegos asignados (no existe ninguno)")
	await place(range_pos + Vector2(0, 150))
	check(not cue.visible, "Invernadero: al salir del rango [E] debe ocultarse")
	costs.greenhouse_state = "OPERATIVO"

	# ===================== SOPORTE VITAL (campamento) =====================
	var camp := await go_to(CAMP)
	clear_events()
	var life: Area2D = camp.get_node("LifeSupportStation")
	var life_cue: Control = life.get_node("InteractCue")
	var launcher: Node = life.get_node("Minigame")
	var life_pos := life.global_position
	var machine: CollisionShape2D = camp.get_node("hitbox/life_support")
	var machine_rect := Rect2(machine.global_position - machine.shape.size / 2.0, machine.shape.size)

	# 2. La máquina bloquea al jugador.
	stop = await walk(life_pos + Vector2(0, 50), Vector2(0, -200), 60)
	top = collider_rect().position.y
	check(absf(top - machine_rect.end.y) < 2.0, "El soporte vital debe detener al jugador en su base (borde superior y=%.1f, base %.1f)" % [top, machine_rect.end.y])
	# 3. La puerta interior de la sala (hueco del muro divisorio, y 183-240) no queda
	# bloqueada por la máquina: se puede entrar caminando desde la sala central.
	stop = await walk(Vector2(395, 212), Vector2(200, 0), 40)
	check(collider_rect().position.x > 433.0, "La máquina no debe bloquear la entrada a la sala (x=%.1f)" % stop.x)
	stop = await walk(stop, Vector2(0, 200), 20)
	check(stop.y > 250.0, "Desde la entrada se debe poder bajar a la sala (y=%.1f)" % stop.y)
	# Se puede pasar por delante.
	stop = await walk(Vector2(450, 300), Vector2(200, 0), 50)
	check(stop.x > 570.0, "Se debe poder pasar por delante del soporte vital (x=%.1f)" % stop.x)

	# 4-6. Indicador y rango.
	await place(life_pos + Vector2(-150, 50))
	check(not life_cue.visible, "Soporte vital: lejos no debe verse [E]")
	costs.life_support_state = "AVERIADO"
	await press("interact")
	check(minigames_open().is_empty() and tasks.current_task == "", "Soporte vital: E fuera de rango no debe hacer nada")
	await place(life_pos + Vector2(0, 5))
	check(life.is_player_near() and life_cue.visible, "Soporte vital: dentro del rango debe verse [E]")

	# 7-10. AVERIADO: mantener E abre UNA vez las fugas de aire con la tarea de reparación.
	time_before = sim.tiempo_jornada
	await press("interact", 8)
	var opened := minigames_open()
	check(opened.size() == 1, "Soporte vital: debe abrir un solo minijuego de fugas de aire (abiertos: %d)" % opened.size())
	check(tasks.current_station == "life_support" and tasks.current_task == "repair", "Soporte vital: debe iniciar la reparación")
	check(sim.tiempo_jornada == time_before, "Abrir el minijuego no descuenta tiempo")
	await press("interact", 4)
	check(minigames_open().size() == 1, "E con el minijuego abierto no debe abrir otro")
	var minigame: Node = launcher.active_minigame
	suppress_follow_up_event()
	minigame.emit_signal("completed")
	minigame.emit_signal("completed")
	await frames(3)
	var cost: int = costs.station_costs["life_support"]["repair"]["time"]
	check(sim.tiempo_jornada == time_before - cost, "La reparación debe descontar %d min una vez (quedan %d)" % [cost, sim.tiempo_jornada])
	check(costs.life_support_state == "OPERATIVO" and tasks.current_task == "", "El soporte vital debe quedar OPERATIVO")
	check(current_scene == camp and minigames_open().is_empty() and player.is_physics_processing(), "Debe volver al campamento con el jugador libre")
	check(camp.get_node("TileMapLayer").visible, "El campamento debe volver a verse")

	# Esc: sale sin costo.
	costs.life_support_state = "AVERIADO"
	player.set_physics_process(false)
	await place(life_pos + Vector2(0, 5))
	time_before = sim.tiempo_jornada
	await press("interact")
	check(minigames_open().size() == 1, "Debe volver a abrir las fugas de aire")
	await press("ui_cancel")
	await frames(2)
	check(minigames_open().is_empty() and tasks.current_task == "" and sim.tiempo_jornada == time_before, "Esc debe cerrar sin descontar tiempo")

	# DEGRADADO: no hay minijuego de mantenimiento todavía (pendiente).
	player.set_physics_process(false)
	await place(life_pos + Vector2(0, 5))
	costs.life_support_state = "DEGRADADO"
	await press("interact")
	check(minigames_open().is_empty() and tasks.current_task == "" and sim.tiempo_jornada == time_before, "DEGRADADO: sin minijuego de mantenimiento no debe iniciar tarea")
	costs.life_support_state = "OPERATIVO"
	await press("interact")
	check(minigames_open().is_empty() and tasks.current_task == "", "OPERATIVO: no debe abrir nada")

	# Pérdida de presión: el evento deja el soporte vital AVERIADO y la reparación lo resuelve.
	# (Al resolver un evento, Events puede lanzar otro al azar con un 30 %, así que se
	# comprueba la señal event_resolved y no que no quede ningún evento activo.)
	clear_events()
	sim.reset_daily_time()
	var pressure_loss: int = events.EventTypes.PERDIDA_PRESION
	var resolved := []
	events.event_resolved.connect(func(type): resolved.append(type))
	events.trigger_event(pressure_loss)
	check(costs.life_support_state == "AVERIADO", "Pérdida de presión debe averiar el soporte vital")
	await press("interact")
	check(minigames_open().size() == 1, "Con pérdida de presión, E debe abrir las fugas de aire")
	suppress_follow_up_event()
	launcher.active_minigame.emit_signal("completed")
	await frames(3)
	check(resolved == [pressure_loss] and events.actual_EventType == 0 and costs.life_support_state == "OPERATIVO", "Reparar las fugas debe resolver la pérdida de presión: %s" % str(resolved))

	# --- Las transiciones y minijuegos no cambian el día.
	check(sim.day == day and started_days == 0, "Nada de esto debe cambiar de día")
	SampleDiscoverySave.new(TEST_DISCOVERY_SAVE).clear()
	print("GREENHOUSE & LIFE SUPPORT CHECKS: failures: %d" % failures)
	quit(0 if failures == 0 else 1)
