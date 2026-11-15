
extends Control

# Escena del juego que ya existe.
const GAME_SCENE := "res://game/main/main.tscn"



# Referencias a los botones.
@onready var start_button: Button = $MenuPanel/MenuButtons/startbutton
@onready var exit_button: Button = $MenuPanel/MenuButtons/ExitButton
@onready var title_label: Label = $Titulo
@onready var glitch_band_a: ColorRect = $GlitchBandA
@onready var glitch_band_b: ColorRect = $GlitchBandB

var _glitch_targets: Array = []
var _original_texts: Dictionary = {}


func _ready() -> void:

	# Conectar las señales de los botones.
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	start_button.grab_focus()
	_glitch_targets = [title_label, start_button, exit_button]
	for target in _glitch_targets:
		_original_texts[target] = target.text
	_glitch_loop()


func _glitch_loop() -> void:
	await get_tree().create_timer(0.18).timeout
	await _play_glitch_burst(3, true)
	while is_inside_tree():
		await get_tree().create_timer(randf_range(2.8, 5.2)).timeout
		await _play_glitch_burst(randi_range(2, 4))


func _play_glitch_burst(strikes: int, touch_all_targets: bool = false) -> void:
	for strike in range(strikes):
		if not is_inside_tree():
			return

		var target_index := strike % _glitch_targets.size() if touch_all_targets else randi_range(0, _glitch_targets.size() - 1)
		var target = _glitch_targets[target_index]
		var original_text: String = _original_texts[target]
		var original_modulate: Color = target.modulate
		target.text = _get_glitched_text(target, original_text)
		target.modulate = Color(1.0, 0.84, 0.58, 1.0)
		target.scale = Vector2(1.012, 0.99)
		_show_glitch_bands(target)
		await get_tree().create_timer(randf_range(0.045, 0.09)).timeout

		target.text = original_text
		target.modulate = original_modulate
		target.scale = Vector2.ONE
		glitch_band_a.visible = false
		glitch_band_b.visible = false
		await get_tree().create_timer(randf_range(0.035, 0.075)).timeout


func _get_glitched_text(target: Control, original_text: String) -> String:
	if target == title_label:
		return ["F1VE NIGHTS\nAT MARS", "FIVE N1GHTS\nAT MARS", "FIVE NIGHTS\nAT M∆RS"][randi_range(0, 2)]
	if target == start_button:
		return ["IN1CIAR", "INIC|AR", "INICIAR"][randi_range(0, 2)]
	return ["SA|IR", "S4LIR", "SALIR"][randi_range(0, 2)]


func _show_glitch_bands(target: Control) -> void:
	var text_y := target.global_position.y + randf_range(6.0, maxf(8.0, target.size.y - 6.0))
	glitch_band_a.position = Vector2(target.global_position.x + randf_range(-12.0, 170.0), text_y)
	glitch_band_a.size = Vector2(randf_range(45.0, 260.0), randf_range(1.0, 3.5))
	glitch_band_a.visible = true
	glitch_band_b.position = glitch_band_a.position + Vector2(randf_range(110.0, 300.0), randf_range(-5.0, 5.0))
	glitch_band_b.size = Vector2(randf_range(35.0, 150.0), randf_range(1.0, 2.5))
	glitch_band_b.visible = randf() > 0.45


# Iniciar el juego.
func _on_start_pressed() -> void:

	var error := get_tree().change_scene_to_file(GAME_SCENE)

	if error != OK:
		push_error("No se pudo cargar la escena principal.")


# Salir del videojuego.
func _on_exit_pressed() -> void:

	get_tree().quit()
