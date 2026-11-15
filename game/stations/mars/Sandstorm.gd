extends CanvasLayer

@onready var dust: ColorRect = $Dust
var intensity := 0.0

func _process(delta: float) -> void:
	# The exterior stays loaded behind station minigames.
	if get_tree().has_group("minigame"):
		hide()
		intensity = 0.0
		return

	var active := Events.actual_EventType == Events.EventTypes.TORMENTA_ARENA
	intensity = move_toward(intensity, 1.0 if active else 0.0, delta * 2.8)
	visible = intensity > 0.0
	if visible:
		dust.modulate.a = intensity
