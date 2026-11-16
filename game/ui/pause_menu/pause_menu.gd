extends CanvasLayer

# Menú de pausa con la misma estética de monitor que el resto de pantallas.
# Se abre y cierra con ESC (acción "ui_cancel").
#
# No se abre si:
# - hay un minijuego abierto (ahí ESC cierra el minijuego), o
# - otra pantalla ya pausó el juego (fin de día, victoria o derrota).
#
# Es autoload y funciona con el juego en pausa (process_mode = Always).
# Todo lo visual se edita en pause_menu.tscn.

signal resumed

@onready var root_control: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var monitor: Control = $Root/Monitor

@onready var subtitle: Label = %Subtitle
@onready var event_label: Label = %EventLabel

@onready var energy_row = %EnergyRow
@onready var water_row = %WaterRow
@onready var food_row = %FoodRow
@onready var oxygen_row = %OxygenRow
@onready var energy_plant_row = %EnergyPlantRow
@onready var life_support_row = %LifeSupportRow
@onready var water_station_row = %WaterStationRow
@onready var greenhouse_row = %GreenhouseRow

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton

var _confirming_restart := false
var _tween: Tween


func _ready():
	root_control.visible = false
	resume_button.pressed.connect(resume)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(func(): get_tree().quit())
	# En web no se puede cerrar el juego
	quit_button.visible = not OS.has_feature("web")


# _unhandled_input: si un minijuego usa ESC en _input y lo marca como manejado, aquí no llega
func _unhandled_input(event: InputEvent):
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if is_open():
		resume()
		get_viewport().set_input_as_handled()
	elif can_pause():
		open()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return root_control.visible


func can_pause() -> bool:
	return not get_tree().paused \
		and TaskExecution.current_task == "" \
		and get_tree().current_scene != null \
		and not get_tree().has_group("main_menu") \
		and not get_tree().has_group("minigame")


func open():
	if is_open():
		return
	_fill()
	_reset_restart_button()
	root_control.visible = true
	get_tree().paused = true

	if _tween:
		_tween.kill()
	dim.modulate.a = 0.0
	monitor.modulate.a = 0.0
	monitor.scale = Vector2(0.94, 0.94)
	_tween = _new_tween()
	_tween.tween_property(dim, "modulate:a", 1.0, 0.15)
	_tween.parallel().tween_property(monitor, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(monitor, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	resume_button.grab_focus()


func resume():
	if not is_open():
		return
	if _tween:
		_tween.kill()
	_tween = _new_tween()
	_tween.tween_property(dim, "modulate:a", 0.0, 0.12)
	_tween.parallel().tween_property(monitor, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(func():
		root_control.visible = false
		get_tree().paused = false
		resumed.emit()
	)


# ---------- Datos ----------

func _fill():
	var minutes = SimulationTime.tiempo_jornada
	subtitle.text = "DAY %d · %d:%02d H LEFT" % [SimulationTime.day, floori(minutes / 60.0), minutes % 60]

	if Events.actual_EventType != Events.EventTypes.NONE:
		event_label.text = "ACTIVE EVENT: %s" % Events.EVENT_INFO[Events.actual_EventType][0].to_upper()
		event_label.add_theme_color_override("font_color", Color(1, 0.62, 0.2))
	else:
		event_label.text = "NO ACTIVE EVENTS"
		event_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5))

	energy_row.set_value(Resources.energy)
	water_row.set_value(Resources.water)
	food_row.set_value(Resources.food)
	oxygen_row.set_value(int(Resources.oxygen))

	energy_plant_row.set_state(StationCost.energy_plant_state)
	life_support_row.set_state(StationCost.life_support_state)
	water_station_row.set_state(StationCost.water_station_state)
	greenhouse_row.set_state(StationCost.greenhouse_state)


# ---------- Reiniciar (con confirmación) ----------

func _on_restart_pressed():
	if not _confirming_restart:
		_confirming_restart = true
		restart_button.text = "RESTART? PROGRESS WILL BE LOST"
		return
	root_control.visible = false
	GameOver.restart_game()


func _reset_restart_button():
	_confirming_restart = false
	restart_button.text = "RESTART"


func _new_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
