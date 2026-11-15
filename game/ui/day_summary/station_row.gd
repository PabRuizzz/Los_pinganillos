@tool
extends HBoxContainer

# Fila de una estación en la pantalla de fin de día: icono, nombre y estado con su luz.
# El icono y el nombre se asignan desde el Inspector en cada instancia.

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			artwork.texture = value
@export var display_name := "Estación":
	set(value):
		display_name = value
		if is_node_ready():
			name_label.text = value

@export var operativo_color := Color(0.4, 1.0, 0.4)
@export var degradado_color := Color(1.0, 0.85, 0.3)
@export var averiado_color := Color(1.0, 0.35, 0.35)

@onready var artwork: TextureRect = $Artwork
@onready var name_label: Label = $NameLabel
@onready var state_light: ColorRect = $StateLight
@onready var state_label: Label = $StateLabel


func _ready():
	artwork.texture = icon
	name_label.text = display_name


func set_state(state: String):
	var color = operativo_color
	match state:
		"DEGRADADO":
			color = degradado_color
		"AVERIADO":
			color = averiado_color
	state_label.text = state
	state_label.add_theme_color_override("font_color", color)
	state_light.color = color
