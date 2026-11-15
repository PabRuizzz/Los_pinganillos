extends Node

# Arranque de la partida: inicia el día y lanza el primer evento.
# Es autoload para que funcione sin importar cuál sea la escena principal
# (las puertas recargan las escenas, así que esto no puede vivir en una de ellas).

# Desactiva este interruptor para volver al primer evento aleatorio.
const START_WITH_SANDSTORM := true
const EVENT_CHANCE := 1.0


func _ready():
	# Diferido para que el resto de autoloads (Alert, HUD...) ya estén listos
	start_game.call_deferred()


func start_game():
	TaskExecution.start_day()
	if START_WITH_SANDSTORM:
		Events.trigger_event(Events.EventTypes.TORMENTA_ARENA)
	else:
		Events.trigger_random_event(EVENT_CHANCE)
