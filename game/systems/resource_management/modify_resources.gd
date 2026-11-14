extends Node

signal resources_changed
#Maximo de comida
const MAX_RESOURCE = 100
#Recursos base
var energy = 60
var water = 60
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
