class_name SampleDiscovery
extends Node
## Sistema de descubrimiento de muestras del rover (solo lógica, sin interfaz).
##
## - El catálogo (RockSampleCatalog) aporta los datos científicos fijos.
## - Este nodo elige y registra los descubrimientos.
## - SampleDiscoverySave guarda los sample_id descubiertos en user://.
##
## No es un Autoload: se añade como nodo hijo de la estación del rover (o de quien
## lo necesite) y el controlador de expediciones llama a complete_expedition().

## Se emite cuando se descubre una muestra nueva.
signal sample_discovered(sample: RockSampleData)
## Se emite una vez, en el momento en que se descubre la última muestra del catálogo.
signal catalog_completed

const DEFAULT_CATALOG := preload("res://data/rock_samples/rock_sample_catalog.tres")

@export var catalog: RockSampleCatalog = DEFAULT_CATALOG
## Archivo de progreso. Cambiarlo solo para pruebas o varias ranuras de guardado.
@export var save_path: String = SampleDiscoverySave.DEFAULT_PATH

var _store: SampleDiscoverySave
var _discovered_ids: PackedStringArray = PackedStringArray()
var _loaded := false


func _ready() -> void:
	_ensure_loaded()


## Llamar cuando el rover vuelve a la base. Devuelve la muestra nueva,
## o null si ya se descubrió todo el catálogo (ver is_catalog_complete()).
func complete_expedition() -> RockSampleData:
	return discover_random_sample()


## Elige al azar una muestra no descubierta, la registra, la guarda y la devuelve.
## Devuelve null (sin repetir muestras) si no queda ninguna por descubrir.
func discover_random_sample() -> RockSampleData:
	_ensure_loaded()
	var sample := catalog.get_random(Array(_discovered_ids))
	if sample == null:
		return null
	_discovered_ids.append(sample.sample_id)
	_store.save_ids(_discovered_ids)
	sample_discovered.emit(sample)
	if not has_undiscovered_samples():
		catalog_completed.emit()
	return sample


func is_discovered(sample_id: String) -> bool:
	_ensure_loaded()
	return _discovered_ids.has(sample_id)


## Muestras descubiertas, en el orden en que se encontraron.
func get_discovered_samples() -> Array[RockSampleData]:
	_ensure_loaded()
	var result: Array[RockSampleData] = []
	for sample_id in _discovered_ids:
		var sample := catalog.get_by_id(sample_id)
		if sample != null:
			result.append(sample)
	return result


func get_discovered_count() -> int:
	return get_discovered_samples().size()


func has_undiscovered_samples() -> bool:
	return get_remaining_count() > 0


func get_remaining_count() -> int:
	_ensure_loaded()
	return catalog.get_undiscovered(Array(_discovered_ids)).size()


func get_total_count() -> int:
	return catalog.get_all().size()


func is_catalog_complete() -> bool:
	return not has_undiscovered_samples()


## IDs descubiertos (copia). Incluye IDs guardados que ya no estén en el catálogo.
func get_discovered_ids() -> PackedStringArray:
	_ensure_loaded()
	return _discovered_ids.duplicate()


## Borra el progreso de descubrimientos (para una futura opción "Nueva partida").
func reset_progress() -> void:
	_ensure_loaded()
	_discovered_ids.clear()
	_store.clear()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_store = SampleDiscoverySave.new(save_path)
	_discovered_ids = _store.load_ids()
	_loaded = true
