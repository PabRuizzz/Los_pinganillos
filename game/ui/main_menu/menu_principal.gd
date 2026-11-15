
extends Control

# Escena del juego que ya existe.
const GAME_SCENE := "res://game/main/main.tscn"



# Referencias a los botones.
@onready var start_button: Button = $Centro/Botones/startbutton
@onready var exit_button: Button = $Centro/Botones/ExitButton


func _ready() -> void:

	# Conectar las señales de los botones.
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


# Iniciar el juego.
func _on_start_pressed() -> void:

	var error := get_tree().change_scene_to_file(GAME_SCENE)

	if error != OK:
		push_error("No se pudo cargar la escena principal.")


# Salir del videojuego.
func _on_exit_pressed() -> void:

	get_tree().quit()
