class_name StationMinigame
extends Node
## Abre el minijuego de una estación al pulsar E y lo integra con TaskExecution.
##
## Es la lógica que antes tenía energy_station.gd, generalizada para cualquier
## estación. Se pone como hijo de un StationInteraction (o se asigna en `interaction`).
##
## Según el estado de la estación en StationCost (<station_id>_state):
##   DEGRADADO -> tarea "maintenance" -> maintenance_minigame
##   AVERIADO  -> tarea "repair"      -> repair_minigame
##   OPERATIVO -> no abre nada (muestra operational_message en la consola)
## Excepción: si hay activo un evento de repair_events, se abre siempre la reparación
## (el evento solo se resuelve con la tarea "repair" de esta estación).
##
## El tiempo y los recursos los decide TaskExecution con los valores de StationCost:
## la tarea empieza al abrir el minijuego (sin descontar tiempo), se termina con
## TaskExecution.finish_task() al completarlo (descuenta el tiempo una sola vez) y se
## cancela sin costo si el jugador sale con Esc.
##
## El minijuego se abre dentro de la escena actual, sin cambiar de escena: el día, el
## tiempo restante, la posición del jugador y el estado del rover no se tocan. Mientras
## está abierto se oculta el mundo, se congela al jugador y se bloquean todas las
## estaciones. Al terminar o salir se restaura todo.
##
## El minijuego debe emitir una de estas señales al completarse: completed,
## cleaning_completed o puzzle_completed. Si su raíz es un Control (sin Camera2D) se
## muestra en una CanvasLayer; si es un Node2D se usa su Camera2D.

## Se abrió el minijuego. task_name es "maintenance" o "repair".
signal minigame_opened(task_name: String, minigame: Node)
## Se cerró el minijuego. completed es false si el jugador salió con Esc.
signal minigame_closed(completed: bool)

const COMPLETION_SIGNALS: Array[StringName] = [&"completed", &"cleaning_completed", &"puzzle_completed"]

## Área de interacción de la estación. Si se deja vacío se usa el nodo padre.
@export var interaction: StationInteraction
## Clave de la estación en StationCost.station_costs (p. ej. "energy_plant").
@export var station_id := ""
## Minijuego de mantenimiento (estación DEGRADADO). Puede quedar vacío si aún no
## existe: entonces E solo avisa en la consola, sin iniciar la tarea.
@export var maintenance_minigame: PackedScene
## Minijuego de reparación (estación AVERIADO). Puede quedar vacío, igual que el anterior.
@export var repair_minigame: PackedScene
## Mensaje de consola cuando la estación está OPERATIVO.
@export var operational_message := "La estación funciona correctamente"
## Eventos (valores de Events.EventTypes) que se resuelven reparando esta estación.
## Mientras uno de ellos está activo, E abre repair_minigame con la tarea "repair",
## aunque la estación esté DEGRADADO. Ej.: la estación de agua usa [4]
## (CONGELAMIENTO_TUBERIAS), porque las tuberías congeladas se arreglan reparando.
@export var repair_events: Array[int] = []

## Raíz del minijuego abierto, o null.
var active_minigame: Node = null
var _host: Node = null
var _previous_camera: Camera2D = null
var _frozen_player: CharacterBody2D = null
var _hidden_world_nodes: Array[CanvasItem] = []


func _ready() -> void:
	if interaction == null and get_parent() is StationInteraction:
		interaction = get_parent()
	if interaction == null:
		push_error("StationMinigame %s: falta el StationInteraction" % get_path())
		return
	interaction.interaction_requested.connect(interact)


func _physics_process(_delta: float) -> void:
	if active_minigame != null and Input.is_action_just_pressed("ui_cancel"):
		TaskExecution.cancel_task()  # sin esto la tarea queda "ocupada" y E deja de funcionar
		close_minigame(false)


func is_minigame_open() -> bool:
	return active_minigame != null


## Estado actual de la estación en StationCost ("OPERATIVO", "DEGRADADO" o "AVERIADO").
func get_station_state() -> String:
	return str(StationCost.get(station_id + "_state"))


func interact() -> void:
	if active_minigame != null:
		print("Ya hay un minijuego abierto")
		return

	# Si corres esta escena sola (F6), GameFlow no ha iniciado el día.
	if not TaskExecution.day_active:
		print("Día no iniciado: llamando a TaskExecution.start_day()")
		TaskExecution.start_day()

	if _active_event_needs_repair():
		_start("repair", repair_minigame)
		return

	match get_station_state():
		"DEGRADADO":
			_start("maintenance", maintenance_minigame)
		"AVERIADO":
			_start("repair", repair_minigame)
		"OPERATIVO":
			print(operational_message)
		_:
			print("ERROR: Estado de estación desconocido: ", get_station_state())


## Inicia la tarea y abre su minijuego. Si la estación todavía no tiene minijuego
## para esa tarea, solo lo avisa: no inicia la tarea ni descuenta tiempo.
func _start(task_name: String, scene: PackedScene) -> void:
	if scene == null:
		print("%s: todavía no hay minijuego de '%s' (pendiente)" % [station_id, task_name])
		return
	if _try_start_task(task_name):
		open_minigame(scene, task_name)


func open_minigame(scene: PackedScene, task_name: String) -> void:
	if scene == null:
		push_error("StationMinigame %s: no hay minijuego para '%s'" % [station_id, task_name])
		TaskExecution.cancel_task()
		return
	var minigame := scene.instantiate()
	var completion := _find_completion_signal(minigame)
	if completion == &"":
		push_error("El minijuego %s no tiene señal de fin (%s)" % [scene.resource_path, COMPLETION_SIGNALS])
		minigame.free()
		TaskExecution.cancel_task()
		return
	minigame.connect(completion, _on_minigame_completed)
	active_minigame = minigame

	_previous_camera = get_viewport().get_camera_2d()
	if minigame is Control:
		var layer := CanvasLayer.new()
		layer.name = "MinigameLayer"
		layer.add_child(minigame)
		_host = layer
	else:
		_host = minigame
	get_tree().current_scene.add_child(_host)

	StationInteraction.locked = true
	_set_player_frozen(true)
	_set_world_hidden(true)

	if not minigame is Control:
		var minigame_camera := minigame.get_node_or_null("Camera2D") as Camera2D
		if minigame_camera:
			minigame_camera.make_current()
		else:
			print("ADVERTENCIA: No se encontró Camera2D")
	minigame_opened.emit(task_name, minigame)


func close_minigame(completed: bool) -> void:
	if active_minigame == null:
		return
	active_minigame = null
	if is_instance_valid(_host):
		_host.queue_free()
	_host = null

	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	_previous_camera = null
	_set_player_frozen(false)
	_set_world_hidden(false)
	StationInteraction.locked = false
	minigame_closed.emit(completed)


func _active_event_needs_repair() -> bool:
	return int(Events.actual_EventType) in repair_events


func _try_start_task(task_name: String) -> bool:
	if TaskExecution.start_task(station_id, task_name):
		return true
	# Explica en la consola por qué no se pudo iniciar
	if TaskExecution.current_task != "":
		print("No se puede iniciar: ya hay una tarea en curso (", TaskExecution.current_station, "/", TaskExecution.current_task, ")")
	elif StationCost.station_costs[station_id][task_name]["time"] > SimulationTime.tiempo_jornada:
		print("No se puede iniciar: no queda tiempo en la jornada (", SimulationTime.tiempo_jornada, ")")
	else:
		print("No se puede iniciar la tarea: faltan recursos")
	return false


## Se ignora si llega con el minijuego ya cerrado: así el tiempo se descuenta una vez.
func _on_minigame_completed(_arg1 = null, _arg2 = null) -> void:
	if active_minigame == null:
		return
	TaskExecution.finish_task()
	close_minigame(true)


func _find_completion_signal(minigame: Node) -> StringName:
	for signal_name in COMPLETION_SIGNALS:
		if minigame.has_signal(signal_name):
			return signal_name
	return &""


## Oculta el mapa mientras el minijuego está abierto. El fondo de algunos minijuegos
## (Backdrop, CanvasLayer layer = -1) se dibuja DETRÁS del mundo, así que sin esto el
## mapa, los sprites y el jugador se verían encima del fondo.
func _set_world_hidden(hide_world: bool) -> void:
	if hide_world:
		_hidden_world_nodes.clear()
		for child in get_tree().current_scene.get_children():
			if child == _host:
				continue
			if child is CanvasItem and child.visible:
				child.visible = false
				_hidden_world_nodes.append(child)
	else:
		for node in _hidden_world_nodes:
			if is_instance_valid(node):
				node.visible = true
		_hidden_world_nodes.clear()


func _set_player_frozen(frozen: bool) -> void:
	if frozen:
		_frozen_player = interaction.get_player() as CharacterBody2D
		if _frozen_player:
			_frozen_player.velocity = Vector2.ZERO
			_frozen_player.set_physics_process(false)
	elif is_instance_valid(_frozen_player):
		_frozen_player.set_physics_process(true)
		_frozen_player = null
