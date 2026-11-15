extends Control

const DESIGN_SIZE := Vector2(1980, 1280)
@onready var content: Control = $Content

# Referencias a los botones.
@onready var start_button: Button = $Content/MenuPanel/MenuButtons/startbutton
@onready var exit_button: Button = $Content/MenuPanel/MenuButtons/ExitButton
@onready var title_label: Label = $Content/TitleBlock/Titulo
@onready var glitch_band_a: ColorRect = $Content/GlitchBandA
@onready var glitch_band_b: ColorRect = $Content/GlitchBandB

var _glitch_targets: Array[Control] = []


func _ready() -> void:
	resized.connect(_layout)
	_layout()
	exit_button.visible = not OS.has_feature("web")

	# Conectar las señales de los botones.
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	start_button.grab_focus()
	_glitch_targets = [title_label, start_button, exit_button]
	if not exit_button.visible:
		_glitch_targets.erase(exit_button)
	_glitch_loop()


func _layout() -> void:
	var factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	content.scale = Vector2.ONE * factor
	content.position = (size - DESIGN_SIZE * factor) / 2.0

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
		var target := _glitch_targets[target_index]
		var original_modulate: Color = target.modulate
		target.modulate = Color(1.0, 0.84, 0.58, 1.0)
		_show_glitch_bands(target)
		await get_tree().create_timer(randf_range(0.045, 0.09)).timeout

		target.modulate = original_modulate
		glitch_band_a.visible = false
		glitch_band_b.visible = false
		await get_tree().create_timer(randf_range(0.035, 0.075)).timeout


func _show_glitch_bands(target: Control) -> void:
	var origin := content.get_global_transform().affine_inverse() * target.global_position
	var text_y := origin.y + randf_range(6.0, maxf(8.0, target.size.y - 6.0))
	glitch_band_a.position = Vector2(origin.x + randf_range(-12.0, 170.0), text_y)
	glitch_band_a.size = Vector2(randf_range(45.0, 260.0), randf_range(1.0, 3.5))
	glitch_band_a.visible = true
	glitch_band_b.position = glitch_band_a.position + Vector2(randf_range(110.0, 300.0), randf_range(-5.0, 5.0))
	glitch_band_b.size = Vector2(randf_range(35.0, 150.0), randf_range(1.0, 2.5))
	glitch_band_b.visible = randf() > 0.45


# Iniciar el juego.
func _on_start_pressed() -> void:

	var error := GameFlow.enter_game()

	if error != OK:
		push_error("No se pudo cargar la escena principal.")


# Salir del videojuego.
func _on_exit_pressed() -> void:

	get_tree().quit()
