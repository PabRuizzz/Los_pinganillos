extends Area2D

@export_file("*.tscn") var cuarto_destino: String
@export var nombre_spawn: String

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or get_tree().has_meta("door_transition_pending"):
		return
	if nombre_spawn.is_empty() or not ResourceLoader.exists(cuarto_destino):
		push_error("Puerta sin escena o marcador de destino: " + str(get_path()))
		return
	get_tree().set_meta("door_transition_pending", true)
	body.set_physics_process(false)
	_change_scene.call_deferred(body)

func _change_scene(body: Node2D) -> void:
	var tree := get_tree()
	tree.set_meta("spawn_destino", nombre_spawn)
	var error := tree.change_scene_to_file(cuarto_destino)
	if error != OK:
		tree.remove_meta("spawn_destino")
		tree.remove_meta("door_transition_pending")
		if is_instance_valid(body):
			body.set_physics_process(true)
		push_error("No se pudo abrir: " + cuarto_destino)
