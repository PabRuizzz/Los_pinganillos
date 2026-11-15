extends CanvasLayer

# Pantalla de fin de partida. Pausa el juego y permite reiniciar.
# Esta escena es autoload y funciona aunque el juego este en pausa
# (process_mode = Always en el nodo raiz).

# Autoloads cuyas variables vuelven a su valor inicial al reiniciar
const AUTOLOADS_TO_RESET = ["Resources", "SimulationTime", "StationCost", "TaskExecution", "Events", "Oxygen"]

# Días que hay que completar para ganar la misión
@export var dias_para_ganar := 5

# Apariencia de cada pantalla (se cambia desde el Inspector)
@export_group("Éxito")
@export var color_exito := Color(0.4, 1.0, 0.5)
@export var imagen_exito: Texture2D
@export var boton_exito := "Jugar de nuevo"
@export_group("Derrota")
@export var color_derrota := Color(1.0, 0.35, 0.35)
@export var imagen_derrota: Texture2D
@export var boton_derrota := "Reiniciar"

@onready var root_control: Control = $Root
@onready var title: Label = %Title
@onready var message: Label = %Message
@onready var restart_button: Button = %RestartButton
@onready var artwork: TextureRect = $Root/Center/VBox/Artwork


func _ready():
	root_control.visible = false
	restart_button.pressed.connect(restart_game)
	Oxygen.oxygen_depleted.connect(_on_oxygen_depleted)
	TaskExecution.day_finished.connect(_on_day_finished)


func _on_oxygen_depleted():
	show_defeat("Te quedaste sin oxígeno", "Sobreviviste %d día(s) en Marte." % SimulationTime.day)


# Al terminar el día, SimulationTime.day ya avanzó al siguiente,
# así que los días completados son day - 1.
func _on_day_finished():
	var dias_completados = SimulationTime.day - 1

	# Primero la derrota: si te quedas sin recursos el último día, no ganas.
	if Resources.energy <= 0 or Resources.food <= 0 or Resources.water <= 0:
		show_defeat("Sin recursos", "La base se quedó sin recursos tras %d día(s)." % dias_completados)
	elif dias_completados >= dias_para_ganar:
		show_victory("¡Misión cumplida!", "Sobreviviste %d días en Marte." % dias_completados)


func show_victory(t: String, m: String):
	_show(t, m, color_exito, imagen_exito, boton_exito)


func show_defeat(t: String, m: String):
	_show(t, m, color_derrota, imagen_derrota, boton_derrota)


# Se mantiene por compatibilidad: muestra la pantalla de derrota.
func show_game_over(t: String, m: String):
	show_defeat(t, m)


func _show(t: String, m: String, color: Color, imagen: Texture2D, texto_boton: String):
	if root_control.visible:
		return # ya hay una pantalla final abierta
	title.text = t
	title.add_theme_color_override("font_color", color)
	message.text = m
	restart_button.text = texto_boton
	artwork.texture = imagen
	artwork.visible = imagen != null
	root_control.visible = true
	get_tree().paused = true


func restart_game():
	for autoload_name in AUTOLOADS_TO_RESET:
		_reset_variables(get_node("/root/" + autoload_name))

	root_control.visible = false
	Alert.clear_alerts()  # vacía también las alertas en espera
	get_tree().paused = false
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	# Los autoloads no vuelven a ejecutar _ready, así que arrancamos la partida a mano
	GameFlow.start_game.call_deferred()


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
