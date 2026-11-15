class_name StationInteraction
extends Area2D
## Interacción con E de una estación: detecta al astronauta, muestra el indicador
## "[E]" y avisa cuando el jugador pulsa la acción "interact" dentro del rango.
##
## Es el mismo comportamiento que tenía la estación del rover, extraído para que
## todas las estaciones se sientan iguales. No sabe qué hace la estación: solo emite
## interaction_requested. Quien la usa decide qué pasa (enviar el rover, abrir un
## minijuego con StationMinigame, etc.).
##
## Cómo añadir esta interacción a una estación nueva:
##   1. Añade un Area2D, asígnale este script y dale collision_layer = 4 y
##      collision_mask = 3 (detecta al jugador, que está en las capas 1 y 2).
##   2. Dale uno o más CollisionShape2D que marquen dónde puede pararse el jugador
##      para interactuar (normalmente delante de la estación, no encima).
##   3. Opcional: instancia interact_cue.tscn como hijo "InteractCue" para moverlo en
##      el editor. Si no existe, se crea solo con su posición por defecto.
##   4. Opcional: añade hijos Marker2D si la estación es grande. El indicador se coloca
##      con su borde inferior centrado sobre el marcador más cercano al jugador.
##   5. Conecta interaction_requested a lo que deba hacer la estación. Para abrir un
##      minijuego con su tarea, añade un hijo con StationMinigame.
##
## Si varias áreas se solapan, solo la más cercana al jugador muestra "[E]" y responde,
## así una pulsación nunca activa dos estaciones a la vez.

## El jugador entró en el rango de interacción.
signal player_entered_range
## El jugador salió del rango de interacción.
signal player_exited_range
## El jugador pulsó E (acción "interact") con esta estación enfocada.
## Una pulsación = una emisión, aunque se mantenga la tecla.
signal interaction_requested

const CUE_SCENE := preload("res://game/systems/station_interaction/interact_cue.tscn")
## Color del destello del indicador al pulsar E.
const CUE_FLASH_COLOR := Color(0.3, 1.0, 1.0)

## Si es false, la estación no muestra "[E]" ni responde (p. ej. el rover está fuera
## o hay un minijuego abierto). La detección del jugador sigue funcionando.
@export var interaction_enabled := true: set = set_interaction_enabled

## Bloquea todas las estaciones a la vez (StationMinigame lo activa mientras hay un
## minijuego abierto).
static var locked := false
static var _instances: Array[StationInteraction] = []

## true mientras el astronauta está dentro del área.
var player_near := false

var _player: Node2D = null
var _cue: Control
var _anchors: Array[Marker2D] = []
var _focused := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_cue = get_node_or_null("InteractCue") as Control
	if _cue == null:
		_cue = CUE_SCENE.instantiate()
		add_child(_cue)
	_cue.visible = false
	for child in get_children():
		if child is Marker2D:
			_anchors.append(child)
	_instances.append(self)


func _exit_tree() -> void:
	_instances.erase(self)


func _physics_process(_delta: float) -> void:
	_focused = has_interaction_focus()
	_update_cue()
	if _focused and Input.is_action_just_pressed("interact"):
		interact()


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if is_node_ready():
		_focused = has_interaction_focus()
		_update_cue()


func is_player_near() -> bool:
	return player_near


## El astronauta dentro del área, o null.
func get_player() -> Node2D:
	return _player if player_near else null


## true si esta estación es la que debe responder a E ahora: el jugador está en
## rango, está activada, no hay un bloqueo global y es la más cercana al jugador
## entre las estaciones que lo detectan.
func has_interaction_focus() -> bool:
	if not _can_interact():
		return false
	var my_distance := _distance_to_player()
	for other in _instances:
		if other == self or not other._can_interact() or other._player != _player:
			continue
		var other_distance := other._distance_to_player()
		if other_distance < my_distance or (other_distance == my_distance and _instances.find(other) < _instances.find(self)):
			return false
	return true


## Ejecuta la interacción (lo mismo que pulsar E con la estación enfocada).
func interact() -> void:
	if interaction_requested.get_connections().is_empty():
		print("%s: interacción detectada (no hay nada conectado)" % name)
	_flash_cue()
	interaction_requested.emit()


func _can_interact() -> bool:
	return player_near and interaction_enabled and not locked and is_instance_valid(_player)


func _distance_to_player() -> float:
	return _player.global_position.distance_squared_to(_nearest_anchor_global())


func _nearest_anchor_global() -> Vector2:
	if _anchors.is_empty() or not is_instance_valid(_player):
		return global_position
	var best := _anchors[0]
	for anchor in _anchors:
		if anchor.global_position.distance_squared_to(_player.global_position) < best.global_position.distance_squared_to(_player.global_position):
			best = anchor
	return best.global_position


func _update_cue() -> void:
	if _cue == null:
		return
	_cue.visible = _focused
	if _focused and not _anchors.is_empty():
		var size := _cue.size * _cue.scale
		_cue.global_position = _nearest_anchor_global() - Vector2(size.x / 2.0, size.y)


func _flash_cue() -> void:
	if _cue == null:
		return
	_cue.modulate = CUE_FLASH_COLOR
	create_tween().tween_property(_cue, "modulate", Color.WHITE, 0.4)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body) and not player_near:
		_player = body
		player_near = true
		player_entered_range.emit()


func _on_body_exited(body: Node2D) -> void:
	if body != _player:
		return
	player_near = false
	_player = null
	_focused = false
	_update_cue()
	player_exited_range.emit()


func _is_player(body: Node) -> bool:
	return body is CharacterBody2D and body.is_in_group("player")
