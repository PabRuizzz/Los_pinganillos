extends Node

# Oxigeno en tiempo real:
# - Afuera de la base (escenas en el grupo "exterior") baja poco a poco.
# - Adentro se regenera, siempre que el soporte vital no este AVERIADO.
# - Si baja de LOW_LEVEL se avisa una vez; si llega a 0 se acaba la partida.
#
# Para marcar una escena como exterior: selecciona su nodo raiz,
# pestaña Node -> Groups y agrega el grupo "exterior".

signal oxygen_low       # el oxigeno bajo de LOW_LEVEL
signal oxygen_depleted  # el oxigeno llego a 0

const EXTERIOR_GROUP = "exterior"

# Unidades de oxigeno por segundo
const DRAIN_RATE = 2    # afuera: de 100 a 0 en ~100 s
const REGEN_RATE = 2.5    # adentro: de 0 a 100 en ~40 s

const LOW_LEVEL = 25.0

var _low_warned = false
var _depleted = false


func _process(delta):
	if not TaskExecution.day_active or _depleted:
		return

	if is_outside():
		_change_oxygen(-DRAIN_RATE * delta)
	elif StationCost.life_support_state != "AVERIADO":
		_change_oxygen(REGEN_RATE * delta)

	_check_levels()


func is_outside() -> bool:
	var scene = get_tree().current_scene
	return scene != null and scene.is_in_group(EXTERIOR_GROUP)


# Tambien revisa el oxigeno que quitan los eventos (perdida de presion, tormenta).
func _check_levels():
	if Resources.oxygen <= 0:
		_depleted = true
		oxygen_depleted.emit()
	elif Resources.oxygen < LOW_LEVEL and not _low_warned:
		_low_warned = true
		oxygen_low.emit()
	elif Resources.oxygen >= LOW_LEVEL:
		# Al recuperarse, se puede volver a avisar la proxima vez
		_low_warned = false


# Se usa float (no modify_oxygen, que redondea a entero) para que
# los cambios pequeños de cada frame no se pierdan.
func _change_oxygen(amount: float):
	Resources.oxygen = clampf(Resources.oxygen + amount, 0.0, Resources.MAX_RESOURCE)
