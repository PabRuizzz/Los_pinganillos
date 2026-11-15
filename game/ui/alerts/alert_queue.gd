class_name AlertQueue
extends RefCounted
## Cola de alertas: decide cuál se muestra y en qué orden (sin dibujar nada).
##
## - Se muestran de una en una, en el orden en que llegan (los eventos nunca se
##   reemplazan por avisos posteriores).
## - Una alerta idéntica a la que está en pantalla o en espera se descarta.
## - Una alerta con la misma `key` que la que está en pantalla o en espera la
##   actualiza (p. ej. el aviso de tiempo con otros minutos) en vez de acumularse.

## Resultado de push().
enum PushResult { QUEUED, UPDATED_CURRENT, UPDATED_PENDING, DUPLICATE }

## Alerta en pantalla, o null.
var current: AlertMessage = null
var _pending: Array[AlertMessage] = []


func push(alert: AlertMessage) -> PushResult:
	if alert.same_text_as(current):
		return PushResult.DUPLICATE
	for waiting in _pending:
		if alert.same_text_as(waiting):
			return PushResult.DUPLICATE
	if alert.key != "":
		if current != null and current.key == alert.key:
			current.title = alert.title
			current.message = alert.message
			return PushResult.UPDATED_CURRENT
		for waiting in _pending:
			if waiting.key == alert.key:
				waiting.title = alert.title
				waiting.message = alert.message
				return PushResult.UPDATED_PENDING
	_pending.append(alert)
	return PushResult.QUEUED


## Pasa a la siguiente alerta en espera (o null si no hay) y la marca como actual.
func advance() -> AlertMessage:
	current = null if _pending.is_empty() else _pending.pop_front()
	return current


## Cierra la alerta actual sin pasar a la siguiente.
func finish_current() -> void:
	current = null


func pending_count() -> int:
	return _pending.size()


func pending() -> Array[AlertMessage]:
	return _pending.duplicate()


func clear() -> void:
	current = null
	_pending.clear()
