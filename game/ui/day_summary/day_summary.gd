extends CanvasLayer

# Pantalla de fin de día con forma de monitor.
# - Izquierda: recursos (inicio del día -> fin del día) y estado de las estaciones.
# - Derecha: la muestra que descubrió el rover ese día, con una animación de escaneo.
#
# Es autoload: aparece sola cuando termina un día (TaskExecution.day_finished),
# pausa el juego y se cierra con "Siguiente día".
# No aparece si en ese momento se mostró la pantalla de victoria/derrota.
#
# Todo lo visual (posiciones, imágenes, colores, fuentes) se edita en day_summary.tscn.
# Los datos de las rocas salen de data/rock_samples (RockSampleData).

signal summary_closed

# Si es true, cada día terminado descubre una muestra nueva del catálogo.
# Ponlo en false si prefieres llamar show_summary() tú mismo con la muestra.
@export var discover_sample_each_day := true

# Duración de las partes de la animación (segundos)
@export var intro_time := 0.45
@export var row_stagger := 0.05
@export var scan_time := 1.4

@onready var root_control: Control = $Root
@onready var dim: ColorRect = $Root/Dim
@onready var monitor: Control = $Root/Monitor

@onready var day_title: Label = %DayTitle
@onready var subtitle: Label = %Subtitle
@onready var left_column: VBoxContainer = %Left
@onready var right_column: VBoxContainer = %Right

@onready var energy_row = %EnergyRow
@onready var water_row = %WaterRow
@onready var food_row = %FoodRow
@onready var oxygen_row = %OxygenRow

@onready var energy_plant_row = %EnergyPlantRow
@onready var life_support_row = %LifeSupportRow
@onready var water_station_row = %WaterStationRow
@onready var greenhouse_row = %GreenhouseRow

@onready var scan_status: Label = %ScanStatus
@onready var photo: TextureRect = %Photo
@onready var no_sample_label: Label = %NoSampleLabel
@onready var cover: ColorRect = %Cover
@onready var scan_line: ColorRect = %ScanLine
@onready var sample_name: Label = %SampleName
@onready var sample_meta: Label = %SampleMeta
@onready var description: Label = %Description
@onready var fact_title: Label = %FactTitle
@onready var fact: Label = %Fact

@onready var footer_hint: Label = %FooterHint
@onready var next_button: Button = %NextButton

# Muestras descubiertas en esta partida (la pantalla final las muestra). GameOver la vacía al reiniciar.
var samples_this_run: Array[RockSampleData] = []

var _day_start := {}
var _discovery: SampleDiscovery
var _tween: Tween
var _scan_tween: Tween
var _parts_pending := 0


func _ready():
	root_control.visible = false
	next_button.pressed.connect(close)

	_discovery = SampleDiscovery.new()
	add_child(_discovery)

	TaskExecution.day_started.connect(_on_day_started)
	TaskExecution.day_finished.connect(_on_day_finished)


# Guardamos los recursos al iniciar el día para mostrar cuánto cambiaron
func _on_day_started(_day):
	_day_start = _read_resources()


func _on_day_finished():
	var finished_day = SimulationTime.day - 1
	var sample: RockSampleData = null
	if discover_sample_each_day:
		sample = _pick_sample()
		if sample != null:
			samples_this_run.append(sample)

	# Si el día terminó en victoria o derrota, manda la pantalla final
	# (la muestra de ese día igual cuenta y aparece en su galería)
	if GameOver.root_control.visible:
		return
	# Se leen ahora porque start_day() (justo después) vuelve a llenar el oxígeno
	show_summary(finished_day, sample, _day_start, _read_resources())


# Muestra la pantalla. sample puede ser null (el rover no trajo nada).
func show_summary(day: int, sample: RockSampleData, before := {}, after := {}):
	if after.is_empty():
		after = _read_resources()
	if before.is_empty():
		before = after

	day_title.text = "DÍA %d COMPLETADO" % day
	subtitle.text = "REPORTE DE LA BASE · SOL %d" % day
	footer_hint.text = "Mañana es el día %d." % (day + 1)

	energy_plant_row.set_state(StationCost.energy_plant_state)
	life_support_row.set_state(StationCost.life_support_state)
	water_station_row.set_state(StationCost.water_station_state)
	greenhouse_row.set_state(StationCost.greenhouse_state)

	_fill_sample(sample)

	root_control.visible = true
	get_tree().paused = true
	_play_animation(before, after, sample != null)


func close():
	if not root_control.visible:
		return
	if _tween:
		_tween.kill()
	if _scan_tween:
		_scan_tween.kill()
	next_button.disabled = true
	_tween = _new_tween()
	_tween.tween_property(root_control, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(func():
		root_control.visible = false
		get_tree().paused = false
		summary_closed.emit()
	)


# ---------- Datos ----------

func _read_resources() -> Dictionary:
	return {
		"energy": Resources.energy,
		"water": Resources.water,
		"food": Resources.food,
		"oxygen": int(Resources.oxygen),
	}


# Una muestra nueva del catálogo. Si ya se descubrieron todas, repite una al azar
# para que la pantalla nunca quede vacía en partidas repetidas.
func _pick_sample() -> RockSampleData:
	var sample = _discovery.complete_expedition()
	if sample == null and _discovery.catalog != null:
		sample = _discovery.catalog.get_random()
	return sample


func _fill_sample(sample: RockSampleData):
	var has_sample = sample != null
	no_sample_label.visible = not has_sample
	fact_title.visible = has_sample

	if not has_sample:
		photo.texture = null
		sample_name.text = "El rover no trajo muestras"
		sample_meta.text = ""
		description.text = ""
		fact.text = ""
		return

	photo.texture = sample.sample_image
	sample_name.text = sample.sample_name
	var origin = "Recolectada" if sample.is_collected() else "Observada"
	sample_meta.text = "%s · %s · %s · %s" % [sample.rock_type, sample.location, sample.rover, origin]
	description.text = sample.description
	fact.text = sample.interesting_fact


# ---------- Animación ----------

func _new_tween() -> Tween:
	# Corre aunque el juego esté en pausa
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _play_animation(before: Dictionary, after: Dictionary, has_sample: bool):
	if _tween:
		_tween.kill()
	if _scan_tween:
		_scan_tween.kill()
	_parts_pending = 2

	# Estado inicial
	root_control.modulate.a = 1.0
	dim.modulate.a = 0.0
	monitor.modulate.a = 0.0
	monitor.scale = Vector2(0.88, 0.88)
	next_button.disabled = true
	next_button.modulate.a = 0.0
	for node in [day_title, subtitle] + left_column.get_children() + _sample_texts():
		node.modulate.a = 0.0
	scan_status.text = "ANALIZANDO MUESTRA..." if has_sample else "SIN EXPEDICIÓN"
	_set_scan(0.0)
	scan_line.visible = has_sample

	_tween = _new_tween()

	# 1. Se oscurece el fondo y aparece el monitor
	_tween.tween_property(dim, "modulate:a", 1.0, 0.25)
	_tween.parallel().tween_property(monitor, "modulate:a", 1.0, intro_time)
	_tween.parallel().tween_property(monitor, "scale", Vector2.ONE, intro_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Título
	_tween.tween_property(day_title, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(subtitle, "modulate:a", 1.0, 0.2)

	# 3. La columna derecha (escaneo) arranca a la vez que las filas de la izquierda
	_tween.tween_callback(func(): _play_scan(has_sample))

	# 4. Filas de la izquierda una por una (los números cuentan al aparecer)
	var rows = {energy_row: "energy", water_row: "water", food_row: "food", oxygen_row: "oxygen"}
	for node in left_column.get_children():
		_tween.tween_property(node, "modulate:a", 1.0, 0.1)
		if rows.has(node):
			var key = rows[node]
			var row = node
			_tween.parallel().tween_callback(func(): row.set_values(before.get(key, 0), after.get(key, 0)))
		_tween.tween_interval(row_stagger)
	_tween.tween_callback(_on_part_finished)


# Escaneo de la foto de arriba hacia abajo y luego los textos de la muestra
func _play_scan(has_sample: bool):
	if _scan_tween:
		_scan_tween.kill()
	_scan_tween = _new_tween()
	if has_sample:
		_scan_tween.tween_method(_set_scan, 0.0, 1.0, scan_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_scan_tween.tween_callback(func():
			scan_line.visible = false
			scan_status.text = "NUEVO DESCUBRIMIENTO"
		)
	else:
		_scan_tween.tween_method(_set_scan, 0.0, 1.0, 0.3)
	for node in _sample_texts():
		_scan_tween.tween_property(node, "modulate:a", 1.0, 0.15)
	_scan_tween.tween_callback(_on_part_finished)


# El botón aparece cuando terminan las dos columnas
func _on_part_finished():
	_parts_pending -= 1
	if _parts_pending > 0:
		return
	var t = _new_tween()
	t.tween_property(next_button, "modulate:a", 1.0, 0.2)
	t.tween_callback(func():
		next_button.disabled = false
		next_button.grab_focus()
	)


func _sample_texts() -> Array:
	return [sample_name, sample_meta, description, fact_title, fact]


# t = 0: foto cubierta; t = 1: foto descubierta. La línea de escaneo va en el borde.
func _set_scan(t: float):
	cover.anchor_top = t
	scan_line.anchor_top = t
	scan_line.anchor_bottom = t
