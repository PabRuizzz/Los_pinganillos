class_name AlertMessage
extends RefCounted
## Contenido de una alerta en pantalla (solo datos; Alert la dibuja).

## Texto principal (p. ej. "Tiempo insuficiente").
var title: String
## Explicación corta para el jugador.
var message: String
## Segundos que la alerta queda en pantalla.
var duration: float
## Tipo visual: valor de Alert.Kind (WARNING, DANGER, SUCCESS, INFO).
var kind: int
## Agrupa avisos del mismo tipo (p. ej. "insufficient_time"): una alerta nueva con la
## misma clave actualiza la que ya está en pantalla o en espera en vez de acumularse.
## Vacío = cada alerta es independiente (eventos).
var key: String


func _init(p_title := "", p_message := "", p_duration := 20.0, p_kind := 0, p_key := "") -> void:
	title = p_title
	message = p_message
	duration = p_duration
	kind = p_kind
	key = p_key


func same_text_as(other: AlertMessage) -> bool:
	return other != null and title == other.title and message == other.message
