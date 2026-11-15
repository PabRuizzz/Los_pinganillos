extends Node

# Arranque de la partida: inicia el día 1. Los eventos los lanza Events
# al empezar cada día, siguiendo su PLAN (game/systems/events/events.gd).
# Es autoload para que funcione sin importar cuál sea la escena principal
# (las puertas recargan las escenas, así que esto no puede vivir en una de ellas).


func _ready():
	# Diferido para que el resto de autoloads (Alert, HUD...) ya estén listos
	start_game.call_deferred()


func start_game():
	TaskExecution.start_day()
