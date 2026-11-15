extends Node2D
## Estación de control del rover (objeto físico del mundo, no una pantalla de UI).
##
## El origen del nodo raíz es el punto de contacto con el suelo (centro inferior de la
## plataforma): YSortObjects ordena por esa posición, así que el jugador queda detrás
## de la estación cuando está por encima de ese punto y delante cuando está por debajo.
## El sprite (Visual) va desplazado hacia arriba respecto a la raíz.
##
## Interacción: igual que EnergyStation (Area2D + grupo "player" + acción "interact").
## Esta escena no lanza expediciones ni descubre muestras: solo emite
## interaction_requested. Un futuro controlador de expediciones se conecta a esa señal
## y, cuando el rover vuelva, llama a SampleDiscovery.complete_expedition().

signal player_entered_range
signal player_exited_range
## El jugador pulsó "interact" (E) dentro del rango. Una pulsación = una emisión.
signal interaction_requested

@export var interaction_enabled := true

@onready var interaction_area: Area2D = $InteractionArea

var player_near := false


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if player_near and interaction_enabled and Input.is_action_just_pressed("interact"):
		interact()


func is_player_near() -> bool:
	return player_near


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled


func interact() -> void:
	if interaction_requested.get_connections().is_empty():
		print("Estación del rover: interacción detectada (las expediciones llegarán en una fase futura)")
	interaction_requested.emit()


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body) and not player_near:
		player_near = true
		player_entered_range.emit()


func _on_body_exited(body: Node2D) -> void:
	if not _is_player(body):
		return
	for other in interaction_area.get_overlapping_bodies():
		if other != body and _is_player(other):
			return
	if player_near:
		player_near = false
		player_exited_range.emit()


func _is_player(body: Node) -> bool:
	return body is CharacterBody2D and body.is_in_group("player")
