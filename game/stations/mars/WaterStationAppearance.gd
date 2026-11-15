extends Sprite2D

@export var frozen_texture: Texture2D
@onready var normal_texture: Texture2D = texture

func _ready() -> void:
	_update_texture()

func _process(_delta: float) -> void:
	_update_texture()

func _update_texture() -> void:
	# Read the current event so the sprite also syncs when entering from an interior.
	var is_frozen := Events.actual_EventType == Events.EventTypes.CONGELAMIENTO_TUBERIAS
	var state_texture := frozen_texture if is_frozen else normal_texture
	if state_texture != null and texture != state_texture:
		texture = state_texture
