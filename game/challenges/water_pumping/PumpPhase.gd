extends Control

signal filled
@export var gain := 0.20
@export var loss := 0.08
# Fraction of the tank lost per second while playing.
@export_range(0.0, 0.2, 0.005) var drain_per_second := 0.03
var active := false
var water := 0.0
var marker := 0.0
var clock := 0.0
var speed := 1.0
var green_width := 0.10
var cooldown := 0.0

func _ready() -> void:
	$PumpButton.pressed.connect(pump)

func start(marker_speed: float, zone_width: float) -> void:
	active = true
	water = 0.0
	clock = 0.0
	marker = 0.0
	cooldown = 0.0
	speed = marker_speed
	green_width = zone_width
	$PumpButton.disabled = false
	$Hint.text = "Pulsa ESPACIO/ENTER o BOMBEAR cuando la LÍNEA cruce el VERDE."
	_refresh()

func _process(delta: float) -> void:
	if not active:
		return
	water = maxf(0.0, water - drain_per_second * delta)
	cooldown = maxf(0.0, cooldown - delta)
	clock = fposmod(clock + delta * speed, 2.0)
	marker = 1.0 - absf(clock - 1.0)
	_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("ui_accept") and not event.is_echo():
		pump()
		get_viewport().set_input_as_handled()

func pump() -> void:
	if not active or cooldown > 0.0:
		return
	cooldown = 0.18 # Prevent duplicate input and unrestricted button spam.
	if absf(marker - 0.5) <= green_width / 2.0:
		water = minf(1.0, water + gain)
		$Hint.text = "¡Acierto! El agua avanza."
	else:
		water = maxf(0.0, water - loss)
		$Hint.text = "Fuera de ritmo. Inténtalo otra vez."
	_refresh()
	if water >= 1.0:
		active = false
		$PumpButton.disabled = true
		filled.emit()

func _refresh() -> void:
	$Tank/Water.position = Vector2.ZERO
	$Tank/Water.size = Vector2($Tank.size.x * water, $Tank.size.y)
	$Tank/Percent.text = "%d%%" % roundi(water * 100.0)
	$Bar/Green.position.x = $Bar.size.x * (0.5 - green_width / 2.0)
	$Bar/Green.size.x = $Bar.size.x * green_width
	$Bar/Marker.position.x = $Bar.size.x * marker - $Bar/Marker.size.x / 2.0
