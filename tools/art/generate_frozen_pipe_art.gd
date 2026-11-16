extends SceneTree
## Dibuja con código el arte provisional del minijuego "Tubería congelada".
##   godot --headless --path . --script res://tools/art/generate_frozen_pipe_art.gd
##
## Pixel art a baja resolución, ampliado sin suavizar (vecino más cercano), con la
## paleta del juego: contorno ciruela oscuro, metal mauve, acentos cobre, cian y hielo.
## Escribe los PNG en game/challenges/frozen_pipe/assets/. Es arte provisional: se puede
## reemplazar por arte final desde el Inspector sin tocar la lógica del minijuego.

const OUT_DIR := "res://game/challenges/frozen_pipe/assets/"

# Paleta
const OUTLINE := Color8(42, 26, 46)
const PIPE := [Color8(196, 178, 190), Color8(150, 128, 145), Color8(104, 84, 102), Color8(74, 58, 76)]   # metal viejo mauve
const NEW := [Color8(236, 234, 242), Color8(192, 188, 202), Color8(142, 138, 154), Color8(104, 100, 118)] # repuesto plateado
const COPPER := [Color8(244, 168, 104), Color8(208, 112, 60), Color8(150, 72, 40), Color8(110, 52, 34)]
const RED := [Color8(244, 118, 86), Color8(204, 66, 48), Color8(144, 40, 34), Color8(100, 28, 28)]
const CYAN := Color8(86, 220, 236)
const CYAN_DARK := Color8(36, 120, 140)
const ICE := [Color8(244, 252, 255), Color8(204, 238, 252), Color8(150, 212, 242), Color8(98, 168, 214)]
const WALL := Color8(92, 70, 88)
const WALL_LIGHT := Color8(104, 80, 99)
const WALL_DARK := Color8(76, 58, 74)
const BEAM := Color8(62, 46, 62)
const AMBER := Color8(244, 184, 84)

# Luz desde arriba a la izquierda
const LIGHT := Vector2(-0.55, -0.83)

var img: Image
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	draw_pipe()
	draw_piece("spare_straight", _straight)
	draw_piece("spare_curve", _curve)
	draw_piece("spare_valve", _valve)
	draw_piece("spare_joint", _joint)
	draw_piece("spare_elbow", _elbow)
	draw_screw()
	draw_background()
	print("FROZEN PIPE ART: listo en ", OUT_DIR)
	quit()


# ---------------------------------------------------------------- utilidades

func new_image(w: int, h: int) -> void:
	img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))


func save(name: String, scale: int) -> void:
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
	if err != OK:
		push_error("No se pudo guardar " + name)


func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func opaque(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5


func rect(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			px(x, y, c)


## Bloque con biselado: fila superior clara, inferior oscura y contorno.
func block(x0: int, y0: int, x1: int, y1: int, pal: Array) -> void:
	rect(x0, y0, x1, y1, OUTLINE)
	rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, pal[1])
	rect(x0 + 1, y0 + 1, x1 - 1, y0 + 1, pal[0])
	rect(x0 + 1, y1 - 1, x1 - 1, y1 - 1, pal[2])


func shade(pal: Array, s: float) -> Color:
	if s > 0.5:
		return pal[0]
	if s > -0.15:
		return pal[1]
	if s > -0.6:
		return pal[2]
	return pal[3]


## Tubo grueso a lo largo de una polilínea, con sombreado cilíndrico y contorno.
## caps=false deja los extremos cortados en recto (para unirse con otro sprite).
func tube(points: Array, radius: float, pal: Array, caps := true) -> void:
	var samples: Array[Vector2] = []
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var steps := maxi(1, int(a.distance_to(b) * 4.0))
		for k in steps + 1:
			samples.append(a.lerp(b, float(k) / steps))
	var first: Vector2 = points[0]
	var last: Vector2 = points[points.size() - 1]
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2(x + 0.5, y + 0.5)
			var best := samples[0]
			var best_d := INF
			for s in samples:
				var d := p.distance_squared_to(s)
				if d < best_d:
					best_d = d
					best = s
			if not caps and (best.is_equal_approx(first) or best.is_equal_approx(last)):
				# Más allá del extremo: no dibujar tapa redonda.
				var dir: Vector2 = (points[1] - first).normalized() if best.is_equal_approx(first) else (last - points[points.size() - 2]).normalized()
				var along := (p - best).dot(dir)
				if (best.is_equal_approx(first) and along < 0.0) or (best.is_equal_approx(last) and along > 0.0):
					var side := absf((p - best).cross(dir))
					if side <= radius:
						px(x, y, shade(pal, (p - best - dir * along).normalized().dot(LIGHT) * side / radius))
					elif side <= radius + 1.0:
						px(x, y, OUTLINE)
					continue
			var d := sqrt(best_d)
			if d <= radius:
				var v := (p - best) / radius
				px(x, y, shade(pal, v.dot(LIGHT) * 1.2))
			elif d <= radius + 1.0:
				px(x, y, OUTLINE)


func circle(cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(int(cy - r - 1), int(cy + r + 2)):
		for x in range(int(cx - r - 1), int(cx + r + 2)):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy)) <= r:
				px(x, y, c)


## Escarcha: aclara píxeles opacos con probabilidad, como un velo de hielo.
func frost(x0: int, y0: int, x1: int, y1: int, chance: float) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if opaque(x, y) and img.get_pixel(x, y) != OUTLINE and rng.randf() < chance:
				px(x, y, ICE[rng.randi_range(0, 2)])


func icicle(x: int, y: int, length: int) -> void:
	for i in length:
		var w := 2 if i < length - 2 else 1
		for dx in w:
			px(x + dx, y + i, ICE[1] if dx == 0 else ICE[2])
		px(x - 1, y + i, OUTLINE)
		px(x + w, y + i, OUTLINE)
	px(x, y + length, OUTLINE)


# ---------------------------------------------------------------- tubo congelado

func draw_pipe() -> void:
	rng.seed = 7
	new_image(100, 30)
	var yc := 15.5
	tube([Vector2(-3, yc), Vector2(94, yc)], 6.5, PIPE, false)

	# Abrazaderas de cobre con pernos
	for cx in [20, 62]:
		block(cx - 2, 6, cx + 2, 25, COPPER)
		px(cx, 8, COPPER[3])
		px(cx, 23, COPPER[3])

	# Ventanita cian de inspección
	rect(37, 13, 48, 18, OUTLINE)
	rect(38, 14, 47, 17, CYAN_DARK)
	rect(38, 14, 47, 14, CYAN)
	rect(39, 15, 41, 15, ICE[0])

	# Extremo derecho roto: borde irregular, boca oscura con hielo dentro
	var jag := [0, 2, 1, 3, 0, 2, 4, 1, 0, 3, 1, 2, 0, 1, 3]
	for y in range(8, 24):
		var cut: int = 93 - jag[(y - 8) % jag.size()]
		for x in range(cut + 1, 100):
			px(x, y, Color(0, 0, 0, 0))
		px(cut, y, OUTLINE)
		px(cut - 1, y, PIPE[3])
	# Boca: hueco oscuro con un tapón de hielo
	for y in range(11, 21):
		px(91, y, OUTLINE)
	rect(86, 12, 90, 19, ICE[2])
	rect(87, 12, 89, 15, ICE[1])
	px(88, 13, ICE[0])
	for y in range(12, 20):
		px(85, y, ICE[3])

	# Escarcha sobre la mitad superior y la abrazadera, más densa hacia la rotura
	frost(0, 7, 92, 13, 0.32)
	frost(60, 7, 92, 24, 0.18)
	for x in range(0, 92):
		if opaque(x, 9) and rng.randf() < 0.55:
			px(x, 9, ICE[0])
	# Carámbanos bajo el tubo
	for i in [[10, 23, 5], [31, 23, 4], [53, 23, 6], [75, 23, 4], [84, 22, 3]]:
		icicle(i[0], i[1], i[2])
	save("pipe_frozen", 3)


# ---------------------------------------------------------------- piezas de repuesto

func draw_piece(name: String, painter: Callable) -> void:
	rng.seed = name.hash()
	new_image(44, 24)
	painter.call()
	save(name, 3)


func ring(x: int, y0: int, y1: int) -> void:
	block(x - 1, y0, x + 1, y1, COPPER)


func _straight() -> void:
	tube([Vector2(3, 12), Vector2(41, 12)], 4.0, NEW)
	ring(4, 6, 18)
	ring(39, 6, 18)
	# Remache central para que no parezca un tubo vacío
	rect(20, 9, 23, 9, NEW[0])


func _curve() -> void:
	var pts := [Vector2(2, 7), Vector2(12, 7)]
	for k in range(0, 25):
		var a := PI - PI * k / 24.0
		pts.append(Vector2(22 + 10 * cos(a), 7 + 10 * sin(a)))
	pts.append(Vector2(32, 7))
	pts.append(Vector2(42, 7))
	tube(pts, 3.6, NEW)
	ring(3, 2, 12)
	ring(40, 2, 12)


func _valve() -> void:
	tube([Vector2(3, 16), Vector2(41, 16)], 4.0, NEW)
	ring(4, 10, 22)
	ring(39, 10, 22)
	block(20, 7, 23, 12, NEW)         # vástago
	circle(21.5, 5.0, 5.2, OUTLINE)   # volante rojo
	circle(21.5, 5.0, 4.2, RED[1])
	circle(21.0, 4.0, 2.4, RED[0])
	circle(21.5, 5.0, 2.0, OUTLINE)
	circle(21.5, 5.0, 1.0, NEW[1])
	rect(17, 5, 26, 5, RED[2])          # radios
	rect(21, 1, 22, 9, RED[2])
	circle(21.5, 5.0, 1.0, NEW[0])


func _joint() -> void:
	tube([Vector2(3, 12), Vector2(41, 12)], 4.0, NEW)
	block(13, 5, 30, 19, COPPER)        # manguito
	block(10, 3, 14, 21, COPPER)        # bridas
	block(29, 3, 33, 21, COPPER)
	for bx in [12, 31]:
		for by in [5, 12, 19]:
			px(bx, by, OUTLINE)
			px(bx, by - 1, COPPER[0])
	rect(15, 8, 28, 8, COPPER[0])


func _elbow() -> void:
	tube([Vector2(2, 17), Vector2(17, 17), Vector2(17, 7), Vector2(42, 7)], 3.8, NEW)
	ring(3, 12, 22)
	ring(40, 2, 12)
	block(13, 10, 21, 13, COPPER)       # refuerzo en el tramo vertical


# ---------------------------------------------------------------- tornillo

func draw_screw() -> void:
	new_image(22, 14)
	# Arandela de cobre
	for y in 14:
		for x in 22:
			var q := Vector2((x + 0.5 - 11.0) / 10.5, (y + 0.5 - 7.0) / 6.5)
			var d := q.length()
			if d <= 1.0:
				px(x, y, COPPER[0] if q.y < -0.45 else (COPPER[2] if q.y > 0.5 else COPPER[1]))
			elif d <= 1.18:
				px(x, y, OUTLINE)
	# Cabeza hexagonal plateada
	var hexagon := PackedVector2Array([Vector2(4, 7), Vector2(7.5, 2), Vector2(14.5, 2), Vector2(18, 7), Vector2(14.5, 12), Vector2(7.5, 12)])
	for y in 14:
		for x in 22:
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, hexagon):
				px(x, y, NEW[0] if y < 5 else (NEW[1] if y < 9 else NEW[2]))
	for i in hexagon.size():
		var a := hexagon[i]
		var b := hexagon[(i + 1) % hexagon.size()]
		for k in 20:
			var p := a.lerp(b, k / 19.0)
			px(int(p.x), int(p.y), OUTLINE)
	# Ranura en cruz
	rect(8, 7, 14, 7, NEW[3])
	rect(11, 4, 11, 10, NEW[3])
	save("screw", 3)


# ---------------------------------------------------------------- fondo

func draw_background() -> void:
	rng.seed = 42
	var w := 320
	var h := 180
	new_image(w, h)
	img.fill(WALL)
	# Paneles grandes y discretos
	for x in range(0, w, 40):
		rect(x, 14, x, h - 15, WALL_DARK)
		rect(x + 1, 14, x + 1, h - 15, WALL_LIGHT)
	for y in [62, 118]:
		rect(0, y, w - 1, y, WALL_DARK)
		rect(0, y + 1, w - 1, y + 1, WALL_LIGHT)
	# Pátina muy suave
	for i in 900:
		px(rng.randi_range(0, w - 1), rng.randi_range(14, h - 15), WALL_LIGHT if rng.randf() < 0.5 else WALL_DARK)

	# Vigas superior e inferior con pernos y luces cian
	for band in [[0, 13], [h - 14, h - 1]]:
		rect(0, band[0], w - 1, band[1], BEAM)
		rect(0, band[0] if band[0] > 0 else band[1], w - 1, band[0] if band[0] > 0 else band[1], OUTLINE)
		for x in range(10, w, 20):
			px(x, band[0] + 6, COPPER[1])
			px(x, band[0] + 5, COPPER[0])
		for lx in [64, 224]:
			rect(lx, band[0] + 5, lx + 32, band[0] + 7, CYAN_DARK)
			rect(lx, band[0] + 5, lx + 32, band[0] + 5, CYAN)
		rect(150, band[0] + 6, 170, band[0] + 6, AMBER)

	# Tubos de cobre por los bordes laterales
	tube([Vector2(7, 14), Vector2(7, h - 14)], 2.5, COPPER, false)
	tube([Vector2(w - 8, 14), Vector2(w - 8, h - 14)], 2.5, COPPER, false)
	for y in range(30, h - 20, 34):
		block(3, y, 11, y + 3, PIPE)
		block(w - 12, y, w - 4, y + 3, PIPE)

	# Rejilla de ventilación escarchada arriba a la izquierda
	block(20, 18, 50, 36, PIPE)
	for y in range(21, 35, 3):
		rect(23, y, 47, y, OUTLINE)
		rect(23, y + 1, 47, y + 1, PIPE[2])
	frost(20, 18, 50, 36, 0.45)

	# Blindaje de cobre en las esquinas
	for c in [[0, 0], [w - 20, 0], [0, h - 20], [w - 20, h - 20]]:
		block(c[0], c[1], c[0] + 19, c[1] + 19, COPPER)
		rect(c[0] + 4, c[1] + 4, c[0] + 15, c[1] + 15, COPPER[2])
		rect(c[0] + 5, c[1] + 5, c[0] + 14, c[1] + 14, COPPER[1])

	# Escarcha entrando desde las esquinas y por la viga superior (centro despejado)
	for y in h:
		for x in w:
			var dx := mini(x, w - 1 - x)
			var dy := mini(y, h - 1 - y)
			var d := sqrt(float(dx * dx + dy * dy))
			var chance := clampf(1.0 - d / 48.0, 0.0, 1.0)
			chance = chance * chance * 0.85
			if y > 12 and y < 22:
				chance = maxf(chance, 0.10)
			if rng.randf() < chance:
				var c := img.get_pixel(x, y)
				px(x, y, c.lerp(ICE[1], 0.65))
	save("frozen_pipe_background", 6)
