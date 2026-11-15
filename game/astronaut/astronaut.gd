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



func _ready():
	call_deferred("_aplicar_spawn")

func _aplicar_spawn():
	if get_tree().has_meta("spawn_destino"):
		var nombre = get_tree().get_meta("spawn_destino")
		var escena = get_tree().current_scene
		var spawn = escena.find_child(nombre, true, false)

		if spawn != null:
			velocity = Vector2.ZERO
			set_deferred("global_position", spawn.global_position)

			await get_tree().physics_frame

			print("MARKER: ", spawn.global_position)
			print("PLAYER: ", global_position)

		get_tree().remove_meta("spawn_destino")
