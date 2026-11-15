class_name RockSampleCatalog
extends Resource
## Lista de todas las muestras que el robot puede encontrar.
##
## Solo contiene datos fijos. El progreso del jugador (qué muestras ya descubrió)
## no se guarda aquí: el sistema que lo use pasa su propia lista de sample_id.

@export var samples: Array[RockSampleData] = []


func get_all() -> Array[RockSampleData]:
	var result: Array[RockSampleData] = []
	for sample in samples:
		if sample != null:
			result.append(sample)
	return result


func get_by_id(sample_id: String) -> RockSampleData:
	for sample in get_all():
		if sample.sample_id == sample_id:
			return sample
	return null


## Muestras cuyo sample_id no está en discovered_ids.
func get_undiscovered(discovered_ids: Array) -> Array[RockSampleData]:
	var result: Array[RockSampleData] = []
	for sample in get_all():
		if not discovered_ids.has(sample.sample_id):
			result.append(sample)
	return result


## Muestra aleatoria. Si se pasa exclude_ids (p. ej. las ya descubiertas),
## elige solo entre las restantes. Devuelve null si no queda ninguna.
func get_random(exclude_ids: Array = []) -> RockSampleData:
	var candidates := get_undiscovered(exclude_ids)
	if candidates.is_empty():
		return null
	return candidates.pick_random()
