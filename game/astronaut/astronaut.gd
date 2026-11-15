extends CharacterBody2D

@export var speed:= 200.0
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta):
		var direction:= Input.get_vector("ui_left","ui_right","ui_up","ui_down")
		velocity = direction * speed
		move_and_slide()
		
		if direction.x < 0:
			anim.flip_h = true
		elif direction.x > 0:
			anim.flip_h = false
			
		if direction != Vector2.ZERO:
			anim.play("run_right")
		else:
			anim.play("idle_right")



func _ready() -> void:
	# Apply arrival before movement. The root now matches the collision center.
	set_physics_process(false)
	_aplicar_spawn.call_deferred()

func _aplicar_spawn() -> void:
	var tree := get_tree()
	if tree.has_meta("spawn_destino"):
		var nombre := str(tree.get_meta("spawn_destino"))
		tree.remove_meta("spawn_destino")
		var escena := tree.current_scene
		var spawn: Node = null
		if escena != null and not nombre.is_empty():
			spawn = escena.get_node_or_null(NodePath(nombre))
			if spawn == null:
				spawn = escena.find_child(nombre, true, false)
		if spawn is Marker2D:
			velocity = Vector2.ZERO
			global_position = spawn.global_position
			$Camera2D.reset_smoothing()
			$Camera2D.force_update_scroll()
		else:
			push_error("No existe el Marker2D de llegada: " + nombre)
	if tree.has_meta("door_transition_pending"):
		tree.remove_meta("door_transition_pending")
	set_physics_process(true)
