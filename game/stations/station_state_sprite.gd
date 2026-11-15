extends Sprite2D

# Cambia la imagen del sprite según el estado de una estación
# (OPERATIVO / DEGRADADO / AVERIADO en StationCost).
# Se puede usar en cualquier estación: elige "station" y asigna las tres texturas
# desde el Inspector. Si falta alguna textura, se deja la que ya tenía el sprite.

@export_enum("energy_plant", "life_support", "water_station", "greenhouse") var station := "energy_plant"
@export var texture_operativo: Texture2D
@export var texture_degradado: Texture2D
@export var texture_averiado: Texture2D

var _shown_state := ""


func _ready():
	_update()


# Los estados cambian sin señal (eventos, tareas, noche), así que revisamos cada frame.
# Solo se cambia la textura cuando el estado es distinto al que se muestra.
func _process(_delta):
	_update()


func _update():
	var state = StationCost.get_state(station)
	if state == _shown_state:
		return
	_shown_state = state

	var new_texture: Texture2D = null
	match state:
		"OPERATIVO":
			new_texture = texture_operativo
		"DEGRADADO":
			new_texture = texture_degradado
		"AVERIADO":
			new_texture = texture_averiado
	if new_texture != null:
		texture = new_texture
