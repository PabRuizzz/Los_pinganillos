extends CanvasLayer

# Tarjeta en la esquina superior derecha con el evento activo:
# que hay que reparar y su contador (bateria, tiempo restante u oxigeno).
# Se muestra sola cuando hay un evento y se oculta al resolverlo.
# Los estilos estan en la escena; aqui solo se cambian textos y colores.

@export var warning_color := Color(1.0, 0.62, 0.2)  # naranja: hay tiempo
@export var danger_color := Color(1.0, 0.33, 0.33)  # rojo: queda poco
# Por debajo de esta fraccion del contador se pone en rojo y parpadea
@export_range(0.0, 1.0) var danger_threshold := 0.3

@onready var card: PanelContainer = $Card
@onready var icon: PanelContainer = $Card/VBox/Header/Icon
@onready var artwork: TextureRect = $Card/VBox/Header/Icon/Artwork
@onready var icon_label: Label = $Card/VBox/Header/Icon/IconLabel
@onready var caption: Label = $Card/VBox/Header/HeaderTexts/Caption
@onready var event_name: Label = $Card/VBox/Header/HeaderTexts/EventName
@onready var objective: Label = $Card/VBox/Objective
@onready var counter: VBoxContainer = $Card/VBox/Counter
@onready var counter_name: Label = $Card/VBox/Counter/CounterRow/CounterName
@onready var counter_value: Label = $Card/VBox/Counter/CounterRow/CounterValue
@onready var counter_bar: ProgressBar = $Card/VBox/Counter/CounterBar

var _card_style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _bar_style: StyleBoxFlat
var _rest_x := 0.0
var _shown_event = Events.EventTypes.NONE
var _tween: Tween
var _pulse_time := 0.0


func _ready():
	card.visible = false
	_rest_x = card.offset_left
	_card_style = _own_style(card, "panel")
	_icon_style = _own_style(icon, "panel")
	_bar_style = _own_style(counter_bar, "fill")


func _process(delta):
	var current = Events.actual_EventType
	if current != _shown_event:
		_shown_event = current
		if current == Events.EventTypes.NONE:
			_hide_card()
		else:
			_show_card()

	if current != Events.EventTypes.NONE:
		_update_card(current, delta)


# ---------- Contenido de cada evento ----------

func _update_card(type, delta):
	event_name.text = Events.EVENT_INFO[type][0]
	icon_label.visible = artwork.texture == null

	# ratio = cuanto le queda al contador (1 = lleno, 0 = vacio). -1 = sin contador.
	var ratio := -1.0
	match type:
		Events.EventTypes.TORMENTA_ARENA:
			objective.text = "Repara la planta de energía"
			if Events.battery_active:
				ratio = Events.emergency_battery / 100.0
				_set_counter("Batería de emergencia", "%d %%" % ceili(Events.emergency_battery), ratio)
			else:
				ratio = float(Resources.oxygen) / Resources.MAX_RESOURCE
				_set_counter("Batería agotada · Oxígeno", "%d %%" % int(Resources.oxygen), ratio)

		Events.EventTypes.PERDIDA_PRESION:
			objective.text = "Repara el soporte vital"
			ratio = float(Resources.oxygen) / Resources.MAX_RESOURCE
			_set_counter("Oxígeno", "%d %%" % int(Resources.oxygen), ratio)

		Events.EventTypes.FALTA_ENERGIA:
			objective.text = "Repara la planta de energía para recuperar el invernadero"

		Events.EventTypes.CONGELAMIENTO_TUBERIAS:
			objective.text = "Repara la estación de agua"
			ratio = Events.pipe_timer / Events.PIPE_TIME_LIMIT
			var label = "Congelamiento total en" if Events.pipe_timer_active else "Tuberías congeladas"
			_set_counter(label, _format_time(Events.pipe_timer), ratio)

		Events.EventTypes.HONGOS_INVERNADERO:
			objective.text = "Repara el invernadero"
			ratio = Events.fungus_timer / Events.FUNGUS_TIME_LIMIT
			var label = "La plaga se extiende en" if Events.fungus_timer_active else "Plaga extendida"
			_set_counter(label, _format_time(Events.fungus_timer), ratio)

	counter.visible = ratio >= 0.0
	_apply_urgency(ratio, delta)


func _set_counter(label: String, value: String, ratio: float):
	counter_name.text = label
	counter_value.text = value
	counter_bar.value = clampf(ratio, 0.0, 1.0) * 100.0


# 95.3 s -> "1:36"
func _format_time(seconds: float) -> String:
	var s = ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]


# Naranja mientras hay margen; rojo y parpadeando cuando queda poco
func _apply_urgency(ratio: float, delta: float):
	var urgent = ratio >= 0.0 and ratio < danger_threshold
	var color = danger_color if urgent else warning_color

	_card_style.border_color = color
	_icon_style.bg_color = Color(color, 0.18)
	_bar_style.bg_color = color
	icon_label.add_theme_color_override("font_color", color)
	caption.add_theme_color_override("font_color", color)
	caption.text = "¡URGENTE!" if urgent else "EVENTO ACTIVO"

	if urgent:
		_pulse_time += delta
		counter_value.modulate.a = 0.55 + 0.45 * absf(cos(_pulse_time * 4.0))
	else:
		_pulse_time = 0.0
		counter_value.modulate.a = 1.0


# ---------- Animaciones ----------

func _show_card():
	if _tween:
		_tween.kill()
	card.visible = true
	card.modulate.a = 0.0
	# Se anima offset_left/right (relativos al borde derecho) para no depender del tamaño de pantalla
	var width = card.offset_right - card.offset_left
	card.offset_left = _rest_x + 60.0
	card.offset_right = card.offset_left + width
	_tween = create_tween()
	_tween.tween_property(card, "modulate:a", 1.0, 0.25)
	_tween.parallel().tween_property(card, "offset_left", _rest_x, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(card, "offset_right", _rest_x + width, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_card():
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(card, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(func(): card.visible = false)


func _own_style(node: Control, style_name: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = node.get_theme_stylebox(style_name).duplicate()
	node.add_theme_stylebox_override(style_name, style)
	return style
