extends Node2D

# Marte es la escena de inicio del juego (run/main_scene), asi que aqui empieza
# el primer dia, igual que hacia main.gd. mars.tscn se vuelve a cargar cada vez que
# el jugador cruza una puerta: si el dia ya esta activo no se hace nada, para no
# reiniciar la jornada ni lanzar otro evento.

# Probabilidad de que ocurra un evento al iniciar cada dia (mismo valor que main.gd)
@export_range(0.0, 1.0) var event_chance := 1.0


func _ready():
	if TaskExecution.day_active:
		return
	# Events lanza el evento al iniciar cada dia (day_started).
	Events.day_start_event_chance = event_chance
	TaskExecution.start_day()
