@tool
extends HBoxContainer

# Fila "Nombre ........ valor" del resumen de la misión.

@export var display_name := "Stat":
	set(value):
		display_name = value
		if is_node_ready():
			name_label.text = value

@onready var name_label: Label = $NameLabel
@onready var value_label: Label = $ValueLabel


func _ready():
	name_label.text = display_name


func set_value(text: String, color := Color.WHITE):
	value_label.text = text
	value_label.add_theme_color_override("font_color", color)
