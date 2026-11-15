class_name RoverStation
extends Node2D
## Estación de control del rover (objeto físico del mundo, no una pantalla de UI).
##
## El origen del nodo raíz es el punto de contacto con el suelo (centro inferior de la
## plataforma): YSortObjects ordena por esa posición, así que el jugador queda detrás
## de la estación cuando está por encima de ese punto y delante cuando está por debajo.
## El sprite (Visual) va desplazado hacia arriba respecto a la raíz.
##
## Interacción: el hijo InteractionArea es un StationInteraction (el componente común
## de todas las estaciones: detección, indicador "[E]" y acción "interact"). Este
## script solo reenvía sus señales y conserva la API de la estación.
## Esta escena no lanza expediciones ni descubre muestras: solo emite
## interaction_requested. RoverExpeditionController se conecta a esa señal y desactiva
## la interacción (set_interaction_enabled) mientras el rover está fuera.

signal player_entered_range
signal player_exited_range
## El jugador pulsó "interact" (E) dentro del rango. Una pulsación = una emisión.
signal interaction_requested

@export var interaction_enabled := true: set = set_interaction_enabled

@onready var interaction_area: StationInteraction = $InteractionArea
## Indicador "[E]" sobre la estación (lo controla InteractionArea).
@onready var interact_cue: Label = $InteractionArea/InteractCue

## true mientras el astronauta está en el rango de interacción.
var player_near: bool:
	get:
		return interaction_area != null and interaction_area.player_near


func _ready() -> void:
	interaction_area.interaction_enabled = interaction_enabled
	interaction_area.player_entered_range.connect(player_entered_range.emit)
	interaction_area.player_exited_range.connect(player_exited_range.emit)
	interaction_area.interaction_requested.connect(_on_area_interaction_requested)


func is_player_near() -> bool:
	return player_near


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if interaction_area != null:
		interaction_area.set_interaction_enabled(enabled)


func interact() -> void:
	interaction_area.interact()


func _on_area_interaction_requested() -> void:
	if interaction_requested.get_connections().is_empty():
		print("Estación del rover: interacción detectada (sin controlador de expediciones conectado)")
	interaction_requested.emit()
