@tool
extends HBoxContainer

# Fila de un recurso en la pantalla de fin de día: icono, nombre, valor y cambio del día.
# El icono y el nombre se asignan desde el Inspector en cada instancia.

@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			artwork.texture = value
@export var display_name := "Recurso":
	set(value):
		display_name = value
		if is_node_ready():
			name_label.text = value

@export var up_color := Color(0.45, 1.0, 0.55)
@export var down_color := Color(1.0, 0.4, 0.4)
@export var same_color := Color(0.7, 0.75, 0.85)

@onready var artwork: TextureRect = $Artwork
@onready var name_label: Label = $NameLabel
@onready var value_label: Label = $ValueLabel
@onready var delta_label: Label = $DeltaLabel


func _ready():
	artwork.texture = icon
	name_label.text = display_name


# Muestra "antes -> después" y el cambio con color. El número cuenta hacia arriba/abajo.
func set_values(before: int, after: int, count_time := 0.6) -> Tween:
	var delta = after - before
	delta_label.text = "%+d" % delta if delta != 0 else "±0"
	delta_label.add_theme_color_override("font_color", up_color if delta > 0 else (down_color if delta < 0 else same_color))
	value_label.text = str(before)

	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(v: float): value_label.text = str(roundi(v)), float(before), float(after), count_time)
	return tween
