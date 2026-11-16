extends CanvasLayer

# HUD de jornada, recursos y estado de los sistemas.
# Tambien tiene el boton "End Day": pide confirmacion y llama a
# TaskExecution.request_end_day(). El HUD no cambia el dia ni los recursos.
# Cada valor es un Label propio para que frontend pueda moverlo o cambiarle estilo.

# Colores por estado (se pueden cambiar desde el Inspector)
@export var color_operativo := Color(0.4, 1.0, 0.4)
@export var color_degradado := Color(1.0, 0.85, 0.3)
@export var color_averiado := Color(1.0, 0.35, 0.35)

var compact_mode := false
var menu_mode := false

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel

@onready var energy_label: Label = %EnergyLabel
@onready var water_label: Label = %WaterLabel
@onready var food_label: Label = %FoodLabel
@onready var oxygen_label: Label = %OxygenLabel

@onready var energy_plant_label: Label = %EnergyPlantLabel
@onready var life_support_label: Label = %LifeSupportLabel
@onready var water_station_label: Label = %WaterStationLabel
@onready var greenhouse_label: Label = %GreenhouseLabel

@onready var end_day_button: Button = %EndDayButton
@onready var end_day_hint: Label = %EndDayHint
@onready var end_day_confirm: Control = %EndDayConfirm
@onready var confirm_label: Label = %ConfirmLabel
@onready var confirm_end_day_button: Button = %ConfirmEndDayButton
@onready var cancel_end_day_button: Button = %CancelEndDayButton


func _ready():
	end_day_button.pressed.connect(_on_end_day_pressed)
	confirm_end_day_button.pressed.connect(_on_confirm_end_day_pressed)
	cancel_end_day_button.pressed.connect(_close_end_day_confirm)
	# Si el dia cambia (por ejemplo, se agoto la jornada), una confirmacion
	# abierta para el dia anterior ya no vale.
	TaskExecution.day_started.connect(func(_day): _close_end_day_confirm())


# Los estados y el oxigeno cambian sin señal, asi que actualizamos cada frame.
func _process(_delta):
	day_label.text = "Day %d" % SimulationTime.day
	time_label.text = "Time left: %s" % _format_hours(SimulationTime.tiempo_jornada)

	_update_minigame_mode()
	if compact_mode or menu_mode:
		return

	energy_label.text = "Energy: %d" % Resources.energy
	water_label.text = "Water: %d" % Resources.water
	food_label.text = "Food: %d" % Resources.food
	oxygen_label.text = "Oxygen: %d" % int(Resources.oxygen)

	_show_state(energy_plant_label, "Power Plant", StationCost.energy_plant_state)
	_show_state(life_support_label, "Life Support", StationCost.life_support_state)
	_show_state(water_station_label, "Water Station", StationCost.water_station_state)
	_show_state(greenhouse_label, "Greenhouse", StationCost.greenhouse_state)

	_update_end_day()


# También cubre los minijuegos abiertos directamente con F6.
func _update_minigame_mode() -> void:
	var tree := get_tree()
	var in_minigame := tree.has_group("minigame")
	var in_menu := tree.has_group("main_menu")
	if in_minigame == compact_mode and in_menu == menu_mode:
		return
	compact_mode = in_minigame
	menu_mode = in_menu
	var show_details := not (compact_mode or menu_mode)
	visible = not menu_mode
	$Top/Resources.visible = show_details
	$Systems.visible = show_details
	$DayActions.visible = show_details
	EventTracker.visible = show_details
	Alert.visible = show_details
	_close_end_day_confirm()


# El boton solo sirve con el dia activo, sin tarea en curso y sin pausa.
func _update_end_day():
	var can_end = TaskExecution.can_end_day() and not get_tree().paused
	if not can_end:
		end_day_confirm.visible = false
	end_day_button.disabled = not can_end
	end_day_button.visible = not end_day_confirm.visible
	# Explica por que esta apagado cuando hay una tarea en curso
	end_day_hint.visible = TaskExecution.day_active and TaskExecution.current_task != ""


func _on_end_day_pressed():
	if not TaskExecution.can_end_day():
		return
	confirm_label.text = "End day %d?" % SimulationTime.day
	end_day_confirm.visible = true
	end_day_button.visible = false


func _on_confirm_end_day_pressed():
	# Solo vale una confirmacion visible: clics repetidos no terminan mas dias
	if not end_day_confirm.visible:
		return
	_close_end_day_confirm()
	TaskExecution.request_end_day()


func _close_end_day_confirm():
	end_day_confirm.visible = false
	end_day_button.visible = true


# 480 minutos -> "8:00 h"
func _format_hours(minutes: int) -> String:
	return "%d:%02d h" % [floori(minutes / 60.0), minutes % 60]


func _show_state(label: Label, station_name: String, state: String):
	label.text = "%s: %s" % [station_name, StationCost.get_state_label(state)]
	match state:
		"OPERATIVO":
			label.modulate = color_operativo
		"DEGRADADO":
			label.modulate = color_degradado
		"AVERIADO":
			label.modulate = color_averiado
