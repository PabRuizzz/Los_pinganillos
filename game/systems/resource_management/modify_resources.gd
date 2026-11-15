extends Node

signal resources_changed
#Maximo de comida
const MAX_RESOURCE = 100
#Recursos base
var energy = 60
var water = 50
var food = 50
var oxygen = 100
#Este script es autoload, esta disponible golbalmente siempre 
#Cuando se manda a llamar cada funcion, se modifica los recursos
func modify_energy(cantidad):
	energy = clampi(energy + cantidad, 0, MAX_RESOURCE) #clampi no permite que la cantidad sea menor que 0 y mayor que 100
	resources_changed.emit()


func modify_water(cantidad):
	water = clampi(water + cantidad, 0, MAX_RESOURCE)
	resources_changed.emit()


func modify_food(cantidad):
	food = clampi(food + cantidad, 0, MAX_RESOURCE)
	resources_changed.emit()

func modify_oxygen(cantidad):
	oxygen = clampi(oxygen + cantidad, 0, MAX_RESOURCE)
	resources_changed.emit()


# Aplica la producción/consumo diario de cada estación según su estado actual
# (valores de StationCost). TaskExecution.finish_day() lo llama una vez por día.
func apply_daily_station_changes():
	# 1. Planta de energía (modifica energía)
	var estado_energia = StationCost.energy_plant_state
	var cambio_energia = StationCost.station_costs["energy_plant"][estado_energia]["energy"]
	modify_energy(cambio_energia)

	# 2. Soporte vital (modifica energía)
	var estado_soporte = StationCost.life_support_state
	var cambio_soporte = StationCost.station_costs["life_support"][estado_soporte]["energy"]
	modify_energy(cambio_soporte)

	# 3. Estación de agua (modifica agua)
	var estado_agua = StationCost.water_station_state
	var cambio_agua = StationCost.station_costs["water_station"][estado_agua]["water"]
	modify_water(cambio_agua)

	# 4. Invernadero (modifica comida)
	var estado_comida = StationCost.greenhouse_state
	var cambio_comida = StationCost.station_costs["greenhouse"][estado_comida]["food"]
	modify_food(cambio_comida)
