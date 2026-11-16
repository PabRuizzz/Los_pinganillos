extends Button

@export var left_plant: int
@export var right_plant: int
var closed := false

func show_state(risk: bool, locked: bool) -> void:
	text = "CLOSED" if closed else "CLOSE"
	disabled = locked
	$Line.color = Color("ffc078") if risk and not closed else Color("76c5b1") if closed else Color("9d8995")
	$Gate.visible = closed
