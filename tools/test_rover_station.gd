extends SceneTree
## Valida la estación del rover dentro de mars.tscn (orden Y, colisión e interacción).
##   godot --path . --script res://tools/test_rover_station.gd             (con ventana: incluye la prueba visual del orden Y)
##   godot --headless --path . --script res://tools/test_rover_station.gd  (sin ventana: omite la comparación de píxeles)
##
## No toca el progreso de descubrimientos del jugador.

const MARS := "res://game/stations/mars/mars.tscn"
const STATION_POS := Vector2(40, 230)

var failures := 0
var player: CharacterBody2D
var station: Node2D


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func physics_frames(n: int) -> void:
	for i in n:
		await physics_frame


## Mueve al jugador con move_and_slide (física real) y devuelve dónde se detuvo.
func walk(from: Vector2, velocity: Vector2, frames: int) -> Vector2:
	player.global_position = from
	await physics_frames(2)
	for i in frames:
		player.velocity = velocity
		player.move_and_slide()
		await physics_frame
	return player.global_position


func run_checks() -> void:
	check(change_scene_to_file(MARS) == OK, "mars.tscn no carga")
	await process_frame
	await process_frame
	var mars := current_scene

	# Jerarquía y orden Y.
	var ysort := mars.get_node_or_null("YSortObjects") as Node2D
	station = mars.get_node_or_null("YSortObjects/RoverStation")
	player = mars.get_node_or_null("YSortObjects/player")
	var tiles := mars.get_node_or_null("TileMapLayer") as TileMapLayer
	check(ysort != null and ysort.y_sort_enabled, "YSortObjects debe existir con y_sort_enabled")
	check(station != null and player != null, "El jugador y la estación deben ser hermanos dentro de YSortObjects")
	check(tiles != null and tiles.get_parent() == mars and not tiles.y_sort_enabled, "El TileMapLayer debe quedar fuera del grupo Y-sort")
	check(tiles != null and ysort != null and tiles.get_index() < ysort.get_index() and tiles.z_index <= ysort.z_index, "El terreno debe dibujarse antes que los objetos")
	if station == null or player == null:
		finish()
		return
	check(station.position == STATION_POS, "La estación no está en su posición configurada")
	var sprite := station.get_node("Visual/Sprite2D") as Sprite2D
	check(sprite.texture != null and sprite.scale == Vector2(0.125, 0.125), "Sprite o escala de la estación incorrectos")
	check(not station.y_sort_enabled, "La estación debe ordenarse como una unidad (por su raíz)")
	var art_bottom := station.to_local(sprite.to_global(Vector2(512 - 32, 0))).y  # borde inferior de la plataforma en el arte
	check(absf(art_bottom) <= 2.0, "La raíz no está en el punto de contacto con el suelo (desfase %.1f px)" % art_bottom)

	player.set_physics_process(false)  # sin entrada de teclado: lo movemos desde la prueba

	# Colisión: la plataforma bloquea, lo decorativo no.
	var stop := await walk(STATION_POS + Vector2(0, 80), Vector2(0, -200), 60)
	check(stop.y > STATION_POS.y + 20, "El jugador atravesó la plataforma desde abajo (y=%.1f)" % stop.y)
	stop = await walk(STATION_POS + Vector2(-120, -10), Vector2(200, 0), 60)
	check(stop.x < STATION_POS.x - 50, "El jugador atravesó la plataforma desde un lado (x=%.1f)" % stop.x)
	stop = await walk(STATION_POS + Vector2(-120, -40), Vector2(200, 0), 60)
	check(stop.x > STATION_POS.x + 60, "Algo decorativo bloquea el paso por detrás de la plataforma (x=%.1f)" % stop.x)
	stop = await walk(STATION_POS + Vector2(-90, 50), Vector2(0, -200), 60)
	check(stop.y < STATION_POS.y - 60, "El lateral de la estación no deja rodearla (y=%.1f)" % stop.y)

	# Interacción.
	var events := {"requested": 0, "entered": 0, "exited": 0}
	station.interaction_requested.connect(func(): events.requested += 1)
	station.player_entered_range.connect(func(): events.entered += 1)
	station.player_exited_range.connect(func(): events.exited += 1)

	player.global_position = STATION_POS + Vector2(0, 160)
	await physics_frames(3)
	check(not station.is_player_near(), "Detecta al jugador fuera de rango")
	var cue := station.get_node("InteractCue") as Label
	check(cue != null and not cue.visible, "El indicador [E] debe estar oculto fuera de rango")
	await press_interact(6)
	check(events.requested == 0, "Interactuó fuera de rango")

	player.global_position = STATION_POS + Vector2(0, 20)
	await physics_frames(3)
	check(station.is_player_near() and events.entered == 1, "No detecta al jugador dentro del rango")
	check(cue.visible, "El indicador [E] debe verse dentro del rango")
	await press_interact(6)  # mantener E varios frames = una sola interacción
	check(events.requested == 1, "Una pulsación debe interactuar una vez (fueron %d)" % events.requested)
	# Desde la Fase 4 la primera pulsación envía el rover y la estación se desactiva:
	# con el rover fuera, E no hace nada; al volver, E interactúa otra vez.
	var controller := mars.get_node("RoverExpeditionController")
	check(controller.is_on_expedition() and not cue.visible, "La primera pulsación debe enviar el rover y ocultar [E]")
	await press_interact(2)
	check(events.requested == 1, "No debe interactuar con el rover fuera")
	controller.reset()
	await press_interact(2)
	check(events.requested == 2, "Una segunda pulsación debe volver a interactuar")
	controller.reset()

	player.global_position = STATION_POS + Vector2(0, 160)
	await physics_frames(3)
	check(not station.is_player_near() and events.exited == 1, "No deja de detectar al salir del rango")
	check(not cue.visible, "El indicador [E] debe ocultarse al salir del rango")
	await press_interact(2)
	check(events.requested == 2, "Interactuó después de salir del rango")

	# Orden Y visual (necesita ventana).
	if DisplayServer.get_name() == "headless":
		print("Prueba visual del orden Y omitida (modo headless)")
	else:
		await check_y_sort_pixels()

	finish()


func press_interact(frames: int) -> void:
	Input.action_press("interact")
	await physics_frames(frames)
	Input.action_release("interact")
	await physics_frames(2)


## Compara capturas: detrás de la plataforma el torso del jugador queda oculto;
## delante de ella se ve encima de la estación.
func check_y_sort_pixels() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(3, 3)
	cam.global_position = STATION_POS + Vector2(0, -40)
	current_scene.add_child(cam)
	cam.make_current()

	var behind_feet := STATION_POS + Vector2(0, -24)  # justo encima de la colisión: alcanzable caminando
	var front_feet := STATION_POS + Vector2(0, 33)    # por debajo del punto de contacto
	var baseline := await capture_at(STATION_POS + Vector2(400, 300))
	var behind := await capture_at(behind_feet)
	var front := await capture_at(front_feet)
	# Torso del jugador (sobre la estación en ambos casos), en píxeles de la captura.
	var diff_behind := differing_pixels(baseline, behind, torso_rect(behind_feet, behind))
	var diff_front := differing_pixels(baseline, front, torso_rect(front_feet, front))
	check(diff_behind < 20, "El jugador se ve encima de la estación estando detrás (%d píxeles distintos)" % diff_behind)
	check(diff_front > 200, "El jugador no se ve delante de la estación estando debajo (%d píxeles distintos)" % diff_front)
	behind.save_png("user://rover_ysort_behind.png")
	front.save_png("user://rover_ysort_front.png")
	print("Orden Y: detrás=%d px distintos, delante=%d px distintos (capturas en user://rover_ysort_*.png)" % [diff_behind, diff_front])


func capture_at(pos: Vector2) -> Image:
	player.global_position = pos
	await process_frame
	await RenderingServer.frame_post_draw
	return current_scene.get_viewport().get_texture().get_image()


func torso_rect(feet: Vector2, image: Image) -> Rect2i:
	var vp := current_scene.get_viewport()
	var screen := vp.get_final_transform() * vp.get_canvas_transform() * (feet + Vector2(0, -40))
	var half := Vector2i(12, 12)
	return Rect2i(Vector2i(screen) - half, half * 2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))


func differing_pixels(a: Image, b: Image, rect: Rect2i) -> int:
	var n := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)) == false:
				n += 1
	return n


func finish() -> void:
	print("ROVER STATION CHECKS: failures: %d" % failures)
	quit(0 if failures == 0 else 1)
