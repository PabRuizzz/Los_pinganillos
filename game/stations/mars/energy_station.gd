
extends Area2D

const CLEANING_SCENE = preload("res://game/challenges/solar_cleaning/solar_cleaning.tscn")
const REPAIR_SCENE = preload("res://game/challenges/electrical_repair/electrical_repair.tscn")

var player_near := false
var active_minigame: Node = null
var previous_camera: Camera2D = null
var frozen_player: CharacterBody2D = null
var hidden_world_nodes: Array[CanvasItem] = []


func _ready():
	print("ENERGY STATION INICIADA")
	print("Monitoring: ", monitoring)
	print("Collision Mask: ", get_collision_mask())
	print("Collision Shape: ", $CollisionShape2D.shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_refresh_player_proximity()


func _physics_process(_delta):
	if active_minigame != null:
		if Input.is_action_just_pressed("ui_cancel"):
			print("Minijuego cerrado con Esc")
			close_minigame()
		return

	_refresh_player_proximity()

	if player_near:
		if Input.is_action_just_pressed("interact"):
			print("PRESIONASTE E")
			interact()


func _on_body_entered(body: Node2D):
	print("2. OBJETO DETECTADO: ", body.name)
	print("¿Es CharacterBody2D?: ", body is CharacterBody2D)
	print("¿Está en grupo player?: ", body.is_in_group("player"))

	if _is_player(body):
		player_near = true
		print("3. JUGADOR DETECTADO")


func _on_body_exited(body: Node2D):
	print("OBJETO SALIÓ: ", body.name)
	_refresh_player_proximity()


func _refresh_player_proximity() -> void:
	var was_near = player_near
	player_near = false

	for body in get_overlapping_bodies():
		if _is_player(body):
			player_near = true
			break

	if was_near != player_near:
		print("Proximidad del jugador: ", player_near)


func _is_player(body: Node) -> bool:
	return body is CharacterBody2D and body.is_in_group("player")


func interact():
	if active_minigame != null:
		print("Ya hay un minijuego abierto")
		return

	print("5. INTERACTUANDO CON ENERGY STATION")
	print("Estado: ", StationCost.energy_plant_state)

	match StationCost.energy_plant_state:
		"DEGRADADO":
			open_cleaning_minigame()

		"AVERIADO":
			open_repair_minigame()

		"OPERATIVO":
			print("Los paneles solares funcionan correctamente")

		_:
			print("ERROR: Estado de estación desconocido")


func open_cleaning_minigame():
	print("6. ABRIENDO MINIJUEGO DE LIMPIEZA")

	active_minigame = CLEANING_SCENE.instantiate()

	if not active_minigame.has_signal("cleaning_completed"):
		print("ERROR: No existe cleaning_completed")
		active_minigame.queue_free()
		active_minigame = null
		return

	active_minigame.connect(
		"cleaning_completed",
		Callable(self, "_on_minigame_completed")
	)

	open_minigame()


func open_repair_minigame():
	print("6. ABRIENDO MINIJUEGO DE REPARACIÓN")

	active_minigame = REPAIR_SCENE.instantiate()

	if not active_minigame.has_signal("puzzle_completed"):
		print("ERROR: No existe puzzle_completed")
		active_minigame.queue_free()
		active_minigame = null
		return

	active_minigame.connect(
		"puzzle_completed",
		Callable(self, "_on_minigame_completed")
	)

	open_minigame()


func open_minigame():
	previous_camera = get_viewport().get_camera_2d()

	print("Cámara anterior: ", previous_camera)

	get_tree().current_scene.add_child(active_minigame)
	_set_player_frozen(true)
	_set_world_hidden(true)

	var minigame_camera = active_minigame.get_node_or_null("Camera2D")

	if minigame_camera:
		minigame_camera.make_current()
		print("Cámara del minijuego activada")
	else:
		print("ADVERTENCIA: No se encontró Camera2D")


func _on_minigame_completed(_arg1 = null, _arg2 = null):
	print("7. MINIJUEGO COMPLETADO")

	StationCost.energy_plant_state = "OPERATIVO"

	print("Nuevo estado: ", StationCost.energy_plant_state)

	close_minigame()


func close_minigame():
	if active_minigame:
		active_minigame.queue_free()
		active_minigame = null

	if is_instance_valid(previous_camera):
		previous_camera.make_current()
		print("Cámara anterior restaurada")

	previous_camera = null
	_set_player_frozen(false)
	_set_world_hidden(false)


## Oculta el mapa de Marte mientras el minijuego está abierto. El fondo del
## minijuego (Backdrop, CanvasLayer layer = -1) se dibuja DETRÁS del mundo,
## así que sin esto el mapa, los sprites y el jugador se ven encima del fondo.
func _set_world_hidden(hide_world: bool) -> void:
	if hide_world:
		hidden_world_nodes.clear()
		for child in get_tree().current_scene.get_children():
			if child == active_minigame:
				continue
			if child is CanvasItem and child.visible:
				child.visible = false
				hidden_world_nodes.append(child)
	else:
		for node in hidden_world_nodes:
			if is_instance_valid(node):
				node.visible = true
		hidden_world_nodes.clear()


func _set_player_frozen(frozen: bool) -> void:
	if frozen:
		for body in get_overlapping_bodies():
			if _is_player(body):
				frozen_player = body
				break
		if frozen_player:
			frozen_player.velocity = Vector2.ZERO
			frozen_player.set_physics_process(false)
	elif is_instance_valid(frozen_player):
		frozen_player.set_physics_process(true)
		frozen_player = null
