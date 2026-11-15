extends Node

# Arranque de la partida: inicia el día y lanza el primer evento.
# Es autoload para que funcione sin importar cuál sea la escena principal
# (las puertas recargan las escenas, así que esto no puede vivir en una de ellas).

# Probabilidad de que ocurra un evento al iniciar la partida (1 = siempre)
const EVENT_CHANCE := 1.0


func _ready():
	# Diferido para que el resto de autoloads (Alert, HUD...) ya estén listos
	start_game.call_deferred()


func start_game():
	TaskExecution.start_day()
	Events.trigger_random_event(EVENT_CHANCE)
