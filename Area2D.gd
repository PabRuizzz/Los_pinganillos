extends Area2D

@export_file("*.tscn") var escena_minijuego: String

var jugador_cerca := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		jugador_cerca = true
		# Aquí puedes mostrar un letrero "Presiona E"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		jugador_cerca = false

func _unhandled_input(event: InputEvent) -> void:
	if jugador_cerca and event.is_action_pressed("interactuar"):
		iniciar_minijuego()

func iniciar_minijuego() -> void:
	get_tree().change_scene_to_file(escena_minijuego)
