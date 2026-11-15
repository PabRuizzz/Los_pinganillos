extends Control

signal completed
enum Difficulty { FACIL, NORMAL }
@export var difficulty: Difficulty = Difficulty.NORMAL
@onready var content: Control = $Content
@onready var repair = $Content/RepairPhase
var finished := false

func _ready() -> void:
	repair.repaired.connect(_complete)
	resized.connect(_layout)
	_layout()
	$Content/Result.hide()
	repair.start(4 if difficulty == Difficulty.FACIL else 5)

func _layout() -> void:
	var factor := minf(size.x / 1000.0, size.y / 680.0)
	content.scale = Vector2.ONE * factor
	content.position = (size - Vector2(960, 640) * factor) / 2.0

func _complete() -> void:
	if finished:
		return
	finished = true
	$Content/Result.text = "¡Las dos tuberías están reparadas!"
	$Content/Result.show()
	completed.emit()
