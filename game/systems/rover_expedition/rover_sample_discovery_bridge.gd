class_name RoverSampleDiscoveryBridge
extends Node
## Conecta el regreso del rover con el descubrimiento de muestras (solo lógica, sin UI).
##
## RoverExpeditionController.expedition_returned -> SampleDiscovery.complete_expedition()
##
## Este nodo no elige, guarda ni copia muestras: todo eso lo hace SampleDiscovery.
## Las notificaciones para una futura interfaz son:
## - SampleDiscovery.sample_discovered(sample): muestra nueva (el RockSampleData original,
##   con foto, descripción, dato curioso, créditos y fuente). Notificación principal.
## - SampleDiscovery.catalog_completed: se acaba de descubrir la última muestra.
## - expedition_returned_without_sample (de este nodo): el rover volvió pero ya no
##   quedaban muestras por descubrir.
##
## Orden de inicialización: este nodo se conecta en _ready(). El controlador revisa los
## regresos pendientes (por ejemplo, días que pasaron con Marte descargado) con
## call_deferred desde su _ready(), es decir, después de que TODOS los nodos de la
## escena ejecutaron _ready(). Así este puente ya está conectado sin importar el orden
## de los nodos en el árbol.

## El rover volvió y no trajo muestra porque el catálogo ya estaba completo.
signal expedition_returned_without_sample(departure_day: int, returned_on_day: int)

@export var expedition_controller: RoverExpeditionController
@export var sample_discovery: SampleDiscovery

## Muestras que trajo el rover y que el resumen del día aún no mostró. Es estática
## para que sobreviva a los cambios de escena (Marte se recarga en cada puerta).
static var _unreported: Array[RockSampleData] = []


## Devuelve (y olvida) las muestras que trajo el rover desde la última vez que se
## llamó. La usa DaySummary al terminar el día.
static func take_unreported_samples() -> Array[RockSampleData]:
	var samples := _unreported.duplicate()
	_unreported.clear()
	return samples


func _ready() -> void:
	if expedition_controller == null or sample_discovery == null:
		push_error("RoverSampleDiscoveryBridge: falta asignar expedition_controller o sample_discovery")
		return
	expedition_controller.expedition_returned.connect(_on_expedition_returned)


## Un regreso = como mucho un descubrimiento: el controlador emite expedition_returned
## una sola vez por expedición y aquí se llama a complete_expedition() una sola vez.
func _on_expedition_returned(departure_day: int, returned_on_day: int) -> void:
	var sample := sample_discovery.complete_expedition()
	if sample == null:
		print("Rover: volvió el día %d sin muestra nueva (catálogo completo)" % returned_on_day)
		expedition_returned_without_sample.emit(departure_day, returned_on_day)
		return
	_unreported.append(sample)
	print("Rover: trajo la muestra '%s' (%s) el día %d" % [sample.sample_name, sample.sample_id, returned_on_day])
