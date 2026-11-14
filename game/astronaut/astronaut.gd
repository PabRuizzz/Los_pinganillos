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
