extends CanvasLayer

# Alerta en pantalla. Entra deslizandose desde arriba, muestra una barra
# con el tiempo que le queda y sale con un desvanecido.
#
# Todas las alertas pasan por show_alert() y entran en una cola (AlertQueue): se
# muestran de una en una, en orden, y al terminar una aparece la siguiente. Los
# avisos repetidos no se acumulan. Mientras la capa está oculta (el HUD la esconde
# durante los minijuegos) la cola se pausa, así ninguna alerta caduca sin verse.
# Este autoload vive entre escenas, así que la cola no se pierde al cambiar de escena.
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
var _queue := AlertQueue.new()


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
	TaskExecution.insufficient_time.connect(_on_insufficient_time)
	TaskExecution.insufficient_energy.connect(_on_insufficient_energy)
	visibility_changed.connect(_on_visibility_changed)


func _on_event_started(_type, event_title: String, event_message: String):
	show_alert(event_title, event_message, 20.0, Kind.WARNING)


func _on_event_resolved(_type):
	show_alert("Evento resuelto", "La estación volvió a operar.", 4.0, Kind.SUCCESS)


func _on_oxygen_low():
	show_alert("Oxígeno bajo", "Regresa a la base para recuperar oxígeno.", 6.0, Kind.DANGER)


# Una tarea no pudo empezar porque no queda tiempo en la jornada. Los minutos vienen
# de TaskExecution (costo de StationCost y tiempo restante de SimulationTime).
func _on_insufficient_time(_station, _task_name, required: int, available: int):
	var m: String
	if required > SimulationTime.MAX_JOURNEY_TIME:
		m = "Esta tarea dura %s y un día solo tiene %s." % [format_time(required), format_time(SimulationTime.MAX_JOURNEY_TIME)]
	else:
		m = "Necesitas %s y te quedan %s.\nTermina el día o elige una tarea más corta." % [format_time(required), format_time(available)]
	show_alert("Tiempo insuficiente", m, 6.0, Kind.WARNING, "insufficient_time")


# Una tarea no pudo empezar porque no hay energía suficiente (costo "energy" de la
# tarea en StationCost frente a Resources.energy).
func _on_insufficient_energy(_station, _task_name, required: int, available: int):
	var m := "Necesitas %d de energía y tienes %d.\nRepara la planta de energía o elige otra tarea." % [required, available]
	show_alert("Energía insuficiente", m, 6.0, Kind.WARNING, "insufficient_energy")


# Tiempo simulado con el mismo formato que el HUD: 240 -> "4:00 h".
static func format_time(minutes: int) -> String:
	return "%d:%02d h" % [floori(minutes / 60.0), minutes % 60]


# Punto de entrada único para mostrar una alerta: la pone en la cola.
# key agrupa avisos del mismo tipo (ver AlertMessage.key); vacío para eventos.
func show_alert(t: String, m: String, duration := 20.0, kind := Kind.WARNING, key := ""):
	var result := _queue.push(AlertMessage.new(t, m, duration, kind, key))
	if result == AlertQueue.PushResult.UPDATED_CURRENT:
		# Mismo tipo de aviso con otros valores: se actualiza sin reiniciar la animación.
		title.text = _queue.current.title
		message.text = _queue.current.message
	elif result == AlertQueue.PushResult.QUEUED and _queue.current == null:
		_show_next()


## Alerta en pantalla ahora mismo (o null).
func get_current_alert() -> AlertMessage:
	return _queue.current


## Cuántas alertas esperan su turno.
func get_pending_count() -> int:
	return _queue.pending_count()


## Vacía la cola y oculta la alerta (p. ej. al reiniciar la partida).
func clear_alerts():
	_queue.clear()
	if _tween:
		_tween.kill()
		_tween = null
	panel.visible = false


func _show_next():
	var next := _queue.advance()
	if next == null:
		return
	_present(next)
	if not visible and _tween:
		_tween.pause()


func _present(alert: AlertMessage):
	title.text = alert.title
	message.text = alert.message
	_apply_kind(alert.kind)

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
	_tween.parallel().tween_property(time_bar, "value", 0.0, alert.duration)
	# Salida y siguiente alerta de la cola
	_tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	_tween.tween_callback(_on_alert_finished)


func _on_alert_finished():
	panel.visible = false
	_queue.finish_current()
	_tween = null
	_show_next()


# Oculta (minijuego abierto): la alerta actual se congela y la cola espera.
func _on_visibility_changed():
	if _tween == null:
		return
	if visible:
		_tween.play()
	else:
		_tween.pause()


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
