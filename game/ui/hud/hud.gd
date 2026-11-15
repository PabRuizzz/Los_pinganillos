extends CanvasLayer

# HUD simple: dia, tiempo restante, recursos y estado de los sistemas.
# Cada valor es un Label propio para que frontend pueda moverlo o cambiarle estilo.

# Colores por estado (se pueden cambiar desde el Inspector)
@export var color_operativo := Color(0.4, 1.0, 0.4)
@export var color_degradado := Color(1.0, 0.85, 0.3)
@export var color_averiado := Color(1.0, 0.35, 0.35)

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


# Los estados y el oxigeno cambian sin señal, asi que actualizamos cada frame.
func _process(_delta):
	day_label.text = "Día %d" % SimulationTime.day
	time_label.text = "Tiempo restante: %s" % _format_hours(SimulationTime.tiempo_jornada)

	energy_label.text = "Energía: %d" % Resources.energy
	water_label.text = "Agua: %d" % Resources.water
	food_label.text = "Comida: %d" % Resources.food
	oxygen_label.text = "Oxígeno: %d" % int(Resources.oxygen)

	_show_state(energy_plant_label, "Planta de energía", StationCost.energy_plant_state)
	_show_state(life_support_label, "Soporte vital", StationCost.life_support_state)
	_show_state(water_station_label, "Estación de agua", StationCost.water_station_state)
	_show_state(greenhouse_label, "Invernadero", StationCost.greenhouse_state)


# 480 minutos -> "8:00 h"
func _format_hours(minutes: int) -> String:
	return "%d:%02d h" % [minutes / 60, minutes % 60]


func _show_state(label: Label, station_name: String, state: String):
	label.text = "%s: %s" % [station_name, state]
	match state:
		"OPERATIVO":
			label.modulate = color_operativo
		"DEGRADADO":
			label.modulate = color_degradado
		"AVERIADO":
			label.modulate = color_averiado
