extends Node

var energy_plant_state = "AVERIADO"
var life_support_state = "OPERATIVO"
var water_station_state = "OPERATIVO"
var greenhouse_state = "OPERATIVO"

var station_costs = {
	"energy_plant": {

		"maintenance": {
			"time": 120
		},
		
		"repair": {
			"time": 240
		},
		
		"OPERATIVO": {
			"energy": 1
		},
		
		"DEGRADADO": {
			"energy": -2
		},
		
		"AVERIADO": {
			"energy": -8
		}
	},
	
	"life_support": {
		"maintenance": {
			"time": 120
		},

		"repair": {
			"time": 240
		},
		
		"OPERATIVO": {
			"energy": 0
		},
		
		"DEGRADADO": {
			"energy": -1
		},
		
		"AVERIADO": {
			"energy": -2
		}
	},
	
	"water_station": {
		"maintenance": {
			"time": 120
		},

		"repair": {
			"time": 240
		},
		
		"OPERATIVO": {
			"water": -1
		},
		
		"DEGRADADO": {
			"water": -3
		},
		
		"AVERIADO": {
			"water": -6
		}
	},
	
	"greenhouse": {
		"maintenance": {
			"time": 120
		},

		"repair": {
			"time": 240
		},
		
		"OPERATIVO": {
			"food": 1
		},
		
		"DEGRADADO": {
			"food": -2
		},
		
		"AVERIADO": {
			"food": -6
		}
	}
}
