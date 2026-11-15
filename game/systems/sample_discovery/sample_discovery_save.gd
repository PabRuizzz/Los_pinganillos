class_name SampleDiscoverySave
extends RefCounted
## Guarda y carga los sample_id que el jugador ya descubrió.
##
## Solo persiste identificadores (String), nunca copias de RockSampleData.
## Usa un ConfigFile en user:// para que el progreso sobreviva al cerrar el juego.

const DEFAULT_PATH := "user://sample_discovery.cfg"
const SECTION := "progress"
const KEY_IDS := "discovered_ids"

var path: String


func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path


## Devuelve los IDs guardados, o una lista vacía si aún no hay partida guardada.
func load_ids() -> PackedStringArray:
	if not FileAccess.file_exists(path):
		return PackedStringArray()
	var config := ConfigFile.new()
	var err := config.load(path)
	if err != OK:
		push_error("SampleDiscoverySave: no se pudo leer %s (error %d)" % [path, err])
		return PackedStringArray()
	var value = config.get_value(SECTION, KEY_IDS, PackedStringArray())
	if value is PackedStringArray:
		return value
	if value is Array:
		return PackedStringArray(value)
	return PackedStringArray()


func save_ids(ids: PackedStringArray) -> Error:
	var config := ConfigFile.new()
	config.set_value(SECTION, KEY_IDS, ids)
	var err := config.save(path)
	if err != OK:
		push_error("SampleDiscoverySave: no se pudo guardar %s (error %d)" % [path, err])
	return err


## Borra el progreso guardado (útil para "Nueva partida" o pruebas con una ruta propia).
func clear() -> Error:
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
