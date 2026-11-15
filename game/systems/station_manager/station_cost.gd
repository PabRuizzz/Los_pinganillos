extends Node

var energy_plant_state = "OPERATIVO"
var life_support_state = "OPERATIVO"
var water_station_state = "OPERATIVO"
var greenhouse_state = "OPERATIVO"

# Balance de la partida (todo se ajusta aquí):
# - "maintenance" / "repair": minutos de la jornada (480) y energía que cuesta la tarea.
#   La energía se revisa al iniciar la tarea y se descuenta al terminarla.
# - "OPERATIVO" / "DEGRADADO" / "AVERIADO": cambio neto de recursos al terminar el día
#   (ya incluye lo que consume la tripulación).
#   Idea: con todo OPERATIVO te recuperas poco a poco, DEGRADADO es un aviso
#   y una estación AVERIADA vacía su recurso en ~3 días.
var station_costs = {
	"energy_plant": {
		"maintenance": {"time": 120, "energy": 5},
		"repair": {"time": 240, "energy": 10},
		"OPERATIVO": {"energy": 14},
		"DEGRADADO": {"energy": 0},
		"AVERIADO": {"energy": -15},
	},

	"life_support": {
		"maintenance": {"time": 120, "energy": 5},
		"repair": {"time": 240, "energy": 10},
		"OPERATIVO": {"energy": -4},
		"DEGRADADO": {"energy": -8},
		"AVERIADO": {"energy": -12},
	},

	"water_station": {
		"maintenance": {"time": 120, "energy": 5},
		"repair": {"time": 240, "energy": 10},
		"OPERATIVO": {"water": 3},
		"DEGRADADO": {"water": -6},
		"AVERIADO": {"water": -15},
	},

	"greenhouse": {
		"maintenance": {"time": 120, "energy": 5},
		"repair": {"time": 240, "energy": 10},
		"OPERATIVO": {"food": 3},
		"DEGRADADO": {"food": -6},
		"AVERIADO": {"food": -15},
	},
}


func get_state(station: String) -> String:
	match station:
		"energy_plant":
			return energy_plant_state
		"life_support":
			return life_support_state
		"water_station":
			return water_station_state
		"greenhouse":
			return greenhouse_state
	return ""


func set_state(station: String, state: String):
	match station:
		"energy_plant":
			energy_plant_state = state
		"life_support":
			life_support_state = state
		"water_station":
			water_station_state = state
		"greenhouse":
			greenhouse_state = state
