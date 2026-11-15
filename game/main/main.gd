extends Node2D

# Probabilidad de que ocurra un evento al iniciar el dia
@export_range(0.0, 1.0) var event_chance := 1


func _ready():
	TaskExecution.start_day()
	# La alerta es autoload, asi que ya esta conectada a Events
	Events.trigger_random_event(event_chance)
