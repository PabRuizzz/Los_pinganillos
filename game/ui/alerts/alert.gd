extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var title: Label = $Panel/VBox/Title
@onready var message: Label = $Panel/VBox/Message

# Evita que una alerta vieja oculte a una nueva
var _alert_id := 0


func _ready():
	panel.visible = false
	Events.event_started.connect(_on_event_started)
	Events.event_resolved.connect(_on_event_resolved)
	Oxygen.oxygen_low.connect(_on_oxygen_low)


func _on_oxygen_low():
	show_alert("⚠ Oxígeno bajo", "Regresa a la base para recuperar oxígeno.", 5.0)


func _on_event_started(_type, event_title: String, event_message: String):
	show_alert("⚠ " + event_title, event_message)


func _on_event_resolved(_type):
	show_alert("Evento resuelto", "La estación volvió a operar.", 3.0)


func show_alert(t: String, m: String, duration := 20.0):
	_alert_id += 1
	var my_id = _alert_id
	title.text = t
	message.text = m
	panel.visible = true
	await get_tree().create_timer(duration).timeout
	if my_id == _alert_id:
		panel.visible = false
