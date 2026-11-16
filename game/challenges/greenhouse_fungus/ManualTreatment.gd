extends Control

signal completed

@export var plant_number := 1
@onready var spots := $Spots.get_children()
var remaining := 0

func _ready() -> void:
	$Title.text = "Treating Plant %d" % plant_number
	remaining = spots.size()
	for spot: Button in spots:
		spot.pressed.connect(_remove_spot.bind(spot))
	_update_counter()

func _remove_spot(spot: Button) -> void:
	if spot.disabled:
		return
	spot.disabled = true
	spot.hide()
	remaining -= 1
	_update_counter()
	if remaining == 0:
		completed.emit()

func _update_counter() -> void:
	$Counter.text = "Fungal spots left: %d" % remaining
