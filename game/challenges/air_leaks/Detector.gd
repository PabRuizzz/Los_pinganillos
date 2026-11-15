extends Node2D

signal reading_changed(strength: float)
var targets: Array = []
var detection_range := 260.0
var lock_radius := 24.0
var scanning := false
var elapsed := 0.0
@onready var segments := $Indicator/Segments.get_children()

func _ready() -> void:
	# A short synthesized tone; replace Beep.stream in the Inspector for final audio.
	if $Beep.stream == null:
		var tone := AudioStreamWAV.new()
		tone.format = AudioStreamWAV.FORMAT_16_BITS
		tone.mix_rate = 22050
		var samples := PackedByteArray()
		var count := 1543
		samples.resize(count * 2)
		for i in count:
			var envelope := sin(PI * float(i) / count)
			samples.encode_s16(i * 2, int(sin(TAU * 880.0 * i / 22050.0) * envelope * 7000))
		tone.data = samples
		$Beep.stream = tone

func nearest_distance() -> float:
	var distance := INF
	for leak in targets:
		if leak.state != leak.State.REPAIRED:
			distance = minf(distance, position.distance_to(leak.position))
	return distance

func stop() -> void:
	scanning = false
	$Beep.stop()

func _process(delta: float) -> void:
	if not scanning:
		return
	var distance := nearest_distance()
	if is_inf(distance):
		stop()
		return
	var strength := clampf(1.0 - distance / detection_range, 0.0, 1.0)
	$Indicator.color = Color.DODGER_BLUE.lerp(Color.RED, strength)
	var lit := mini(ceili(strength * segments.size()), segments.size() - 1)
	if distance <= lock_radius:
		lit = segments.size()
	for i in segments.size():
		segments[i].color = Color("effbff") if i < lit else Color("263447")
	reading_changed.emit(strength)
	elapsed += delta
	if elapsed >= lerpf(1.4, 0.12, strength):
		elapsed = 0.0
		$Beep.play()
