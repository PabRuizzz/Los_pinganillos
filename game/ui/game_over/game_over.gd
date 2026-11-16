extends CanvasLayer

# Pantalla final (victoria o derrota) con la misma estética de monitor que el fin de día.
# - Izquierda: resumen de la misión (días, eventos resueltos, muestras) y recursos finales.
# - Derecha: galería de las muestras que trajo el rover en esta partida
#   (y, si se asigna en el Inspector, una imagen para cada resultado).
# Pausa el juego y permite reiniciar o salir.
# Es autoload y funciona aunque el juego esté en pausa (process_mode = Always).
# Todo lo visual se edita en game_over.tscn.

# Autoloads cuyas variables vuelven a su valor inicial al reiniciar
const AUTOLOADS_TO_RESET = ["Resources", "SimulationTime", "StationCost", "TaskExecution", "Events", "Oxygen"]

const SAMPLE_CARD = preload("res://game/ui/game_over/sample_card.tscn")

# Días que hay que completar para ganar la misión
@export var dias_para_ganar := 5

# Apariencia de cada pantalla (se cambia desde el Inspector)
@export_group("Éxito")
@export var color_exito := Color(0.4, 1.0, 0.5)
@export var imagen_exito: Texture2D
@export var boton_exito := "PLAY AGAIN"
@export var etiqueta_exito := "FINAL TRANSMISSION · MISSION COMPLETE"
@export_group("Derrota")
@export var color_derrota := Color(1.0, 0.35, 0.35)
@export var imagen_derrota: Texture2D
@export var boton_derrota := "TRY AGAIN"
@export var etiqueta_derrota := "SIGNAL LOST · MARS BASE"

@onready var root_control: Control = $Root
@onready var background: ColorRect = $Root/Background
@onready var monitor: Control = $Root/Monitor
@onready var flicker: ColorRect = %Flicker

@onready var status_tag: Label = %StatusTag
@onready var title: Label = %Title
@onready var message: Label = %Message
@onready var header_line: ColorRect = %HeaderLine
@onready var left_column: VBoxContainer = %Left
@onready var right_column: VBoxContainer = %Right

@onready var days_stat = %DaysStat
@onready var events_stat = %EventsStat
@onready var samples_stat = %SamplesStat
@onready var energy_row = %EnergyRow
@onready var water_row = %WaterRow
@onready var food_row = %FoodRow

@onready var artwork_frame: PanelContainer = %ArtworkFrame
@onready var outcome_artwork: TextureRect = %OutcomeArtwork
@onready var samples_grid: GridContainer = %SamplesGrid
@onready var no_samples_label: Label = %NoSamplesLabel

@onready var footer_hint: Label = %FooterHint
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton

# Eventos resueltos en esta partida (se reinicia al reiniciar)
var events_resolved := 0
var _tween: Tween


func _ready():
	root_control.visible = false
	restart_button.pressed.connect(restart_game)
	quit_button.pressed.connect(func(): get_tree().quit())
	# En web no se puede cerrar el juego, así que el botón sobra
	quit_button.visible = not OS.has_feature("web")

	Oxygen.oxygen_depleted.connect(_on_oxygen_depleted)
	TaskExecution.day_finished.connect(_on_day_finished)
	Events.event_resolved.connect(func(_type): events_resolved += 1)


func _on_oxygen_depleted():
	show_defeat("Out of oxygen", "Oxygen ran out on day %d." % SimulationTime.day)


# Al terminar el día, SimulationTime.day ya avanzó al siguiente,
# así que los días completados son day - 1.
func _on_day_finished():
	var dias_completados = SimulationTime.day - 1

	# Primero la derrota: si te quedas sin recursos el último día, no ganas.
	if Resources.energy <= 0 or Resources.food <= 0 or Resources.water <= 0:
		show_defeat("Out of resources", "The base ran out of %s at the end of day %d." % [_depleted_resource(), dias_completados])
	elif dias_completados >= dias_para_ganar:
		show_victory("Mission accomplished!", "The crew survived %d days on Mars." % dias_completados)


func show_victory(t: String, m: String):
	_show(true, t, m)


func show_defeat(t: String, m: String):
	_show(false, t, m)


# Se mantiene por compatibilidad: muestra la pantalla de derrota.
func show_game_over(t: String, m: String):
	show_defeat(t, m)


func _show(victory: bool, t: String, m: String):
	if root_control.visible:
		return # ya hay una pantalla final abierta

	var color = color_exito if victory else color_derrota
	status_tag.text = etiqueta_exito if victory else etiqueta_derrota
	title.text = t.to_upper()
	title.add_theme_color_override("font_color", color)
	header_line.color = Color(color, 0.6)
	message.text = m
	restart_button.text = boton_exito if victory else boton_derrota
	footer_hint.text = "Thanks for playing." if victory else "Unresolved events worsen overnight."

	var imagen = imagen_exito if victory else imagen_derrota
	outcome_artwork.texture = imagen
	artwork_frame.visible = imagen != null

	_fill_stats(victory, color)

	root_control.visible = true
	get_tree().paused = true
	_play_animation(victory)
	# La muestra del último día la agrega DaySummary justo después de esta señal
	_fill_samples.call_deferred()


# ---------- Datos ----------

func _fill_stats(victory: bool, color: Color):
	# Días completos: si el día está activo (muerte por oxígeno) el actual no cuenta
	var days = SimulationTime.day - 1
	days_stat.set_value("%d / %d" % [days, dias_para_ganar], color if victory else Color.WHITE)
	events_stat.set_value(str(events_resolved))
	energy_row.set_value(Resources.energy)
	water_row.set_value(Resources.water)
	food_row.set_value(Resources.food)


func _fill_samples():
	for child in samples_grid.get_children():
		child.queue_free()

	var samples = DaySummary.samples_this_run
	samples_stat.set_value(str(samples.size()))
	no_samples_label.visible = samples.is_empty()

	# Con imagen de resultado queda menos espacio: solo una fila de tarjetas
	var max_cards = 3 if artwork_frame.visible else 6
	for i in mini(samples.size(), max_cards):
		var card = SAMPLE_CARD.instantiate()
		samples_grid.add_child(card)
		card.set_sample(samples[i])
		card.modulate.a = 0.0
		var t = _new_tween()
		t.tween_interval(1.0 + i * 0.12)
		t.tween_property(card, "modulate:a", 1.0, 0.2)


func _depleted_resource() -> String:
	if Resources.energy <= 0:
		return "energy"
	if Resources.water <= 0:
		return "water"
	return "food"


# ---------- Animación ----------

func _new_tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)


func _play_animation(victory: bool):
	if _tween:
		_tween.kill()

	background.modulate.a = 0.0
	monitor.modulate.a = 0.0
	monitor.scale = Vector2(0.88, 0.88) if victory else Vector2.ONE
	flicker.color.a = 0.0
	restart_button.disabled = true
	for node in [status_tag, title, message, header_line] + left_column.get_children() + _right_static() + [restart_button, quit_button, footer_hint]:
		node.modulate.a = 0.0

	_tween = _new_tween()
	_tween.tween_property(background, "modulate:a", 1.0, 0.4)

	if victory:
		# Entrada con rebote
		_tween.parallel().tween_property(monitor, "modulate:a", 1.0, 0.45)
		_tween.parallel().tween_property(monitor, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Señal que se corta: el monitor parpadea en rojo antes de estabilizarse
		for alpha in [0.8, 0.1, 0.9, 0.3, 1.0]:
			_tween.tween_property(monitor, "modulate:a", alpha, 0.06)
		for flash in [0.35, 0.0, 0.2, 0.0]:
			_tween.tween_property(flicker, "color:a", flash, 0.07)

	_tween.tween_property(status_tag, "modulate:a", 1.0, 0.2)
	_tween.tween_property(title, "modulate:a", 1.0, 0.25)
	if victory:
		title.pivot_offset = Vector2(0, title.size.y / 2.0)
		title.scale = Vector2(1.15, 1.15)
		_tween.parallel().tween_property(title, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(message, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(header_line, "modulate:a", 1.0, 0.2)

	for node in left_column.get_children():
		_tween.tween_property(node, "modulate:a", 1.0, 0.08)
		_tween.tween_interval(0.03)
	for node in _right_static():
		_tween.tween_property(node, "modulate:a", 1.0, 0.15)

	_tween.tween_property(footer_hint, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(quit_button, "modulate:a", 1.0, 0.2)
	_tween.parallel().tween_property(restart_button, "modulate:a", 1.0, 0.2)
	_tween.tween_callback(func():
		restart_button.disabled = false
		restart_button.grab_focus()
	)


# Elementos fijos de la columna derecha (las tarjetas se animan aparte)
func _right_static() -> Array:
	return [artwork_frame, right_column.get_node("SamplesTitle"), no_samples_label]


# ---------- Reinicio ----------

func restart_game():
	for autoload_name in AUTOLOADS_TO_RESET:
		_reset_variables(get_node("/root/" + autoload_name))
	events_resolved = 0
	DaySummary.samples_this_run.clear()

	root_control.visible = false
	Alert.clear_alerts()  # vacía también las alertas en espera
	get_tree().paused = false
	var error := GameFlow.enter_game()
	if error != OK:
		push_error("No se pudo abrir el campamento: %s" % error)


# Copia los valores iniciales del script (los que estan en "var x = ...")
# a un autoload ya existente, sin perder sus señales conectadas.
func _reset_variables(node: Node):
	var fresh = node.get_script().new()
	for property in node.get_script().get_script_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value = fresh.get(property.name)
			if value is Array or value is Dictionary:
				value = value.duplicate(true)
			node.set(property.name, value)
	fresh.free()
