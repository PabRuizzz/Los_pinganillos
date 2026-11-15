extends CanvasLayer

# Pantalla de fin de partida. Pausa el juego y permite reiniciar.
# Esta escena es autoload y funciona aunque el juego este en pausa
# (process_mode = Always en el nodo raiz).

# Autoloads cuyas variables vuelven a su valor inicial al reiniciar
const AUTOLOADS_TO_RESET = ["Resources", "SimulationTime", "StationCost", "TaskExecution", "Events", "Oxygen"]

@onready var root_control: Control = $Root
@onready var title: Label = %Title
@onready var message: Label = %Message
@onready var restart_button: Button = %RestartButton


func _ready():
	root_control.visible = false
	restart_button.pressed.connect(restart_game)
	Oxygen.oxygen_depleted.connect(_on_oxygen_depleted)


func _on_oxygen_depleted():
	show_game_over("Te quedaste sin oxígeno", "Sobreviviste %d día(s) en Marte." % SimulationTime.day)


func show_game_over(t: String, m: String):
	title.text = t
	message.text = m
	root_control.visible = true
	get_tree().paused = true


func restart_game():
	for autoload_name in AUTOLOADS_TO_RESET:
		_reset_variables(get_node("/root/" + autoload_name))

	root_control.visible = false
	Alert.panel.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))


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
