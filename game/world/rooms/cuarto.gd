extends Node2D


@onready var mapa: TileMapLayer = $TileMapLayer
@onready var camara: Camera2D = $player/Camera2D

func _ready() -> void:
	var rect := mapa.get_used_rect()
	var tam := mapa.tile_set.tile_size
	
	camara.limit_left = rect.position.x * tam.x
	camara.limit_top = rect.position.y * tam.y
	camara.limit_right = rect.position.x * tam.x
	camara.limit_bottom = rect.position.y * tam.y
