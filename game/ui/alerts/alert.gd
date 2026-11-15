extends CanvasLayer

# Alerta en pantalla. Entra deslizandose desde arriba, muestra una barra
# con el tiempo que le queda y sale con un desvanecido.
# Los estilos (fondo, bordes, fuentes) estan en la escena y se editan desde el Inspector;
# este script solo cambia el color de acento segun el tipo de alerta.

enum Kind { WARNING, DANGER, SUCCESS, INFO }

@export var warning_color := Color(1.0, 0.62, 0.2)   # naranja: evento nuevo
@export var danger_color := Color(1.0, 0.33, 0.33)   # rojo: peligro inmediato
@export var success_color := Color(0.35, 0.85, 0.5)  # verde: problema resuelto
@export var info_color := Color(0.4, 0.7, 1.0)       # azul: informativo

@onready var panel: PanelContainer = $Panel
@onready var icon: PanelContainer = $Panel/VBox/Content/Icon
@onready var artwork: TextureRect = $Panel/VBox/Content/Icon/Artwork
@onready var icon_label: Label = $Panel/VBox/Content/Icon/IconLabel
@onready var title: Label = $Panel/VBox/Content/Texts/Title
@onready var message: Label = $Panel/VBox/Content/Texts/Message
@onready var time_bar: ProgressBar = $Panel/VBox/TimeBar

var _card_style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _bar_style: StyleBoxFlat
var _rest_y := 0.0
var _tween: Tween


func _ready():
	panel.visible = false
	_rest_y = panel.offset_top

	# Copias propias de los estilos para poder cambiarles el color sin tocar el recurso original
	_card_style = _own_style(panel, "panel")
	_icon_style = _own_style(icon, "panel")
	_bar_style = _own_style(time_bar, "fill")

	Events.event_started.connect(_on_event_started)
	Events.event_resolved.connect(_on_event_resolved)
	Oxygen.oxygen_low.connect(_on_oxygen_low)


func _on_event_started(_type, event_title: String, event_message: String):
	show_alert(event_title, event_message, 20.0, Kind.WARNING)


func _on_event_resolved(_type):
	show_alert("Evento resuelto", "La estación volvió a operar.", 4.0, Kind.SUCCESS)


func _on_oxygen_low():
	show_alert("Oxígeno bajo", "Regresa a la base para recuperar oxígeno.", 6.0, Kind.DANGER)


func show_alert(t: String, m: String, duration := 20.0, kind := Kind.WARNING):
	title.text = t
	message.text = m
	_apply_kind(kind)

	if _tween:
		_tween.kill()

	panel.visible = true
	panel.modulate.a = 0.0
	panel.position.y = _rest_y - 40.0
	time_bar.value = 100.0

	_tween = create_tween()
	# Entrada: aparece y baja con un pequeño rebote
	_tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	_tween.parallel().tween_property(panel, "position:y", _rest_y, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# La barra se vacia mientras la alerta esta visible
	_tween.parallel().tween_property(time_bar, "value", 0.0, duration)
	# Salida
	_tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func(): panel.visible = false)


func _apply_kind(kind: Kind):
	var color: Color
	var glyph: String
	match kind:
		Kind.DANGER:
			color = danger_color
			glyph = "!"
		Kind.SUCCESS:
			color = success_color
			glyph = "✓"
		Kind.INFO:
			color = info_color
			glyph = "i"
		_:
			color = warning_color
			glyph = "!"

	_card_style.border_color = color
	_icon_style.bg_color = Color(color, 0.18)
	_bar_style.bg_color = color
	icon_label.add_theme_color_override("font_color", color)
	icon_label.text = glyph
	# Si frontend asigna una imagen en Artwork, se usa en lugar del simbolo
	icon_label.visible = artwork.texture == null


func _own_style(node: Control, style_name: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = node.get_theme_stylebox(style_name).duplicate()
	node.add_theme_stylebox_override(style_name, style)
	return style
