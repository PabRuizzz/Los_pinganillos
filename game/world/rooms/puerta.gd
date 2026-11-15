extends Area2D

@export_file("*.tscn") var cuarto_destino: String
@export var nombre_spawn: String

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is CharacterBody2D:
		get_tree().set_meta("spawn_destino", nombre_spawn)
		get_tree().change_scene_to_file.call_deferred(cuarto_destino)
