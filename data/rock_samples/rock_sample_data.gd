class_name RockSampleData
extends Resource
## Ficha de una muestra o formación geológica real estudiada por un rover de NASA en Marte.
##
## Cada muestra es un archivo .tres que usa este script. Para añadir una nueva:
## FileSystem > clic derecho en data/rock_samples > Create New > Resource > RockSampleData,
## rellenar los campos en el Inspector y añadirla a rock_sample_catalog.tres.

## COLLECTED: el rover la guardó en un tubo de muestras.
## OBSERVED: el rover solo la fotografió o analizó en el lugar; no hay muestra física.
enum Origin { COLLECTED, OBSERVED }

@export_group("Identificación")
## Identificador único y estable (minúsculas_con_guiones_bajos). El sistema del robot
## lo usa para recordar qué muestras ya se descubrieron, así que no debe cambiar.
@export var sample_id: String
@export var sample_name: String
@export var rock_type: String
@export var location: String
@export var rover: String

@export_group("Procedencia")
@export var origin: Origin = Origin.COLLECTED

@export_group("Información educativa")
@export_multiline var description: String
@export_multiline var interesting_fact: String

@export_group("Imagen")
@export var sample_image: Texture2D
## Qué muestra exactamente la fotografía (cámara, fecha, si es el núcleo, el pozo o la roca de origen).
@export_multiline var image_caption: String
@export var image_credit: String
## URL del archivo original de la fotografía.
@export var image_url: String

@export_group("Fuente científica")
@export var source_name: String
@export var source_url: String


func is_collected() -> bool:
	return origin == Origin.COLLECTED
