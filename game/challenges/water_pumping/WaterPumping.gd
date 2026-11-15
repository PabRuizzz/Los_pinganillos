extends Control

signal completed
enum Difficulty { FACIL, NORMAL }
@export var difficulty: Difficulty = Difficulty.NORMAL
@onready var content: Control = $Content
@onready var pump = $Content/PumpPhase
var finished := false

func _ready() -> void:
	pump.filled.connect(_complete)
	resized.connect(_layout)
	_layout()
	$Content/Result.hide()
	pump.start(0.6 if difficulty == Difficulty.FACIL else 1.0,
		0.16 if difficulty == Difficulty.FACIL else 0.10)

func _layout() -> void:
	var factor := minf(size.x / 1000.0, size.y / 680.0)
	content.scale = Vector2.ONE * factor
	content.position = (size - Vector2(960, 640) * factor) / 2.0

func _complete() -> void:
	if finished:
		return
	finished = true
	$Content/Result.text = "¡Agua circulando!"
	$Content/Result.show()
	completed.emit()
