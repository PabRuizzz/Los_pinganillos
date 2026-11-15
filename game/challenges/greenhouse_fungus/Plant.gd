extends Button

var infected := false
var spray_tween: Tween

func show_state(uv_on: bool, locked: bool) -> void:
	$Spores.visible = uv_on and infected
	$UVShade.visible = uv_on
	disabled = locked
	if not uv_on:
		$Health.text = "Sin examinar"
	else:
		$Health.text = "Infectada" if infected else "Sana"
	$Health.modulate = Color("ffc58a") if uv_on and infected else Color("a5e5c5")

func show_spray() -> void:
	if spray_tween:
		spray_tween.kill()
	$Spray.modulate.a = 1.0
	$Spray.show()
	spray_tween = create_tween()
	spray_tween.tween_property($Spray, "modulate:a", 0.0, 0.55)
	spray_tween.tween_callback($Spray.hide)
