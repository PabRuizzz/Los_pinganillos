extends Node2D

# Probabilidad de que ocurra un evento al iniciar el dia
@export_range(0.0, 1.0) var event_chance := 1


func _ready():
	# Events lanza el evento al iniciar cada dia (day_started), no solo el primero.
	# La alerta es autoload, asi que ya esta conectada a Events
	Events.day_start_event_chance = event_chance
	TaskExecution.start_day()
