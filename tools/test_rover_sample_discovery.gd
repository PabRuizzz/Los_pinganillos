extends SceneTree
## Valida la Fase 5: el regreso del rover descubre una muestra del catálogo.
##   godot --headless --path . --script res://tools/test_rover_sample_discovery.gd
##
## Usa un archivo de descubrimientos propio (TEST_SAVE) y comprueba que el progreso
## real del jugador y las fichas .tres no cambian. Los autoloads se obtienen en tiempo
## de ejecución porque aún no existen cuando se compila este script (--script).

const MARS_PATH := "res://game/stations/mars/mars.tscn"
const TEST_SAVE := "user://test_rover_sample_discovery.cfg"
const SAMPLES_DIR := "res://data/rock_samples/"
const IMAGES_DIR := "res://assets/science/rock_samples/"

var failures := 0
var sim: Node
var tasks: Node

var mars: Node
var controller: Node
var discovery: SampleDiscovery
var bridge: Node
var station: Node

var discovered: Array[RockSampleData] = []   # sample_discovered de todas las instancias
var returns: Array = []                      # expedition_returned
var empty_returns: Array = []                # expedition_returned_without_sample
var completed_count := 0                     # catalog_completed


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(n: int) -> void:
	for i in n:
		await process_frame


## Crea una instancia de Marte con sus nodos de integración nuevos (como al cruzar una
## puerta). Las señales se conectan antes de add_child para no perder ninguna emisión.
## bridge_first coloca el puente antes que el controlador en el árbol.
func make_mars(bridge_first := false) -> Node:
	var scene: Node = load(MARS_PATH).instantiate()
	var d: SampleDiscovery = scene.get_node("SampleDiscovery")
	var c: Node = scene.get_node("RoverExpeditionController")
	var b: Node = scene.get_node("RoverSampleDiscoveryBridge")
	d.save_path = TEST_SAVE
	if bridge_first:
		scene.move_child(b, 0)
	d.sample_discovered.connect(func(s: RockSampleData): discovered.append(s))
	d.catalog_completed.connect(func(): completed_count += 1)
	c.expedition_returned.connect(func(dep: int, day: int): returns.append([dep, day]))
	b.expedition_returned_without_sample.connect(func(dep: int, day: int): empty_returns.append([dep, day]))
	scene.get_node("YSortObjects/player").set_physics_process(false)
	return scene


func load_mars(bridge_first := false) -> void:
	unload_mars()
	await frames(1)
	mars = make_mars(bridge_first)
	controller = mars.get_node("RoverExpeditionController")
	discovery = mars.get_node("SampleDiscovery")
	bridge = mars.get_node("RoverSampleDiscoveryBridge")
	station = mars.get_node("YSortObjects/RoverStation")
	root.add_child(mars)
	current_scene = mars
	await frames(3)


func unload_mars() -> void:
	if mars != null:
		mars.queue_free()
		mars = null


func saved_ids() -> PackedStringArray:
	return SampleDiscoverySave.new(TEST_SAVE).load_ids()


func hash_dir(dir: String) -> Dictionary:
	var result := {}
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".import"):
			result[dir + file] = FileAccess.get_md5(dir + file)
	return result


func run_checks() -> void:
	sim = root.get_node("SimulationTime")
	tasks = root.get_node("TaskExecution")
	# DaySummary pausa el juego al terminar cada día hasta pulsar "Siguiente día":
	# en las pruebas se cierra solo en el siguiente frame.
	process_frame.connect(func():
		var summary = root.get_node_or_null("DaySummary")
		if summary != null and summary.root_control.visible:
			summary.root_control.visible = false
			paused = false)

	var real_save := SampleDiscoverySave.DEFAULT_PATH
	var real_before := FileAccess.get_md5(real_save) if FileAccess.file_exists(real_save) else ""
	var originals := hash_dir(SAMPLES_DIR)
	originals.merge(hash_dir(IMAGES_DIR))
	SampleDiscoverySave.new(TEST_SAVE).clear()

	sim.day = 1
	tasks.start_day()
	await load_mars()
	controller.reset()
	var catalog: RockSampleCatalog = discovery.catalog
	var total := catalog.get_all().size()
	check(total == 12, "El catálogo debería tener 12 muestras (tiene %d)" % total)
	check(discovery.save_path == TEST_SAVE, "La prueba debe usar su propio archivo de guardado")
	check(SampleDiscovery.new().save_path == "user://sample_discovery.cfg", "La ruta de guardado de producción no debe cambiar")

	# --- 1-7, 9. El rover vuelve con Marte cargado: una muestra nueva.
	check(controller.start_expedition() and controller.get_return_day() == 2, "El rover debe salir el día 1")
	tasks.finish_day()
	await frames(1)
	check(returns == [[1, 2]], "expedition_returned debe emitirse una vez: %s" % str(returns))
	check(discovered.size() == 1, "Un regreso debe descubrir una muestra (fueron %d)" % discovered.size())
	if discovered.size() >= 1:
		var first := discovered[0]
		check(catalog.get_by_id(first.sample_id) == first, "La muestra debe ser el Resource original del catálogo")
		check(saved_ids() == PackedStringArray([first.sample_id]), "El ID debe guardarse: %s" % str(saved_ids()))
		check(discovery.is_discovered(first.sample_id) and discovery.get_discovered_count() == 1, "SampleDiscovery debe registrarla")
		for field in ["sample_id", "sample_name", "rock_type", "location", "description", "interesting_fact", "image_credit", "source_url"]:
			check(not str(first.get(field)).is_empty(), "Falta '%s' en la muestra entregada" % field)
		check(first.sample_image is Texture2D and first.sample_image.get_width() > 0, "La foto debe estar disponible para los oyentes")
	check(controller.is_available() and station.interaction_enabled, "El rover debe quedar disponible y la estación activa")
	check(empty_returns.is_empty(), "No debe avisar de catálogo completo")
	# El resumen del día muestra la muestra que trajo el rover (y no descubre otra por su cuenta).
	var summary: Node = root.get_node("DaySummary")
	check(summary._discovery == null and not summary.discover_sample_each_day, "El resumen del día no debe descubrir muestras propias")
	if discovered.size() >= 1:
		check(summary.samples_this_run == [discovered[0]], "El resumen debe registrar solo la muestra del rover: %s" % str(summary.samples_this_run.map(func(x): return x.sample_id)))
		check(summary.sample_name.text == discovered[0].sample_name, "El resumen debe mostrar la muestra del rover ('%s')" % summary.sample_name.text)
	check(saved_ids().size() == 1, "Solo el rover debe haber guardado una muestra (%d)" % saved_ids().size())

	# --- 10. Recrear Marte el mismo día no repite el descubrimiento.
	await load_mars()
	await load_mars(true)
	check(discovered.size() == 1 and returns.size() == 1, "Recrear la escena no debe repetir el regreso ni el descubrimiento")
	check(discovery.get_discovered_count() == 1, "La escena recreada debe cargar el descubrimiento guardado")

	# --- 8. Sale el rover, el jugador se va de Marte, pasan los días y vuelve.
	check(controller.start_expedition() and controller.get_departure_day() == 2, "El rover debe salir el día 2")
	unload_mars()
	await frames(1)
	tasks.finish_day()   # día 3: el rover vuelve, pero Marte no está cargado
	tasks.finish_day()   # día 4
	check(sim.day == 4 and discovered.size() == 1, "Sin Marte cargado aún no hay descubrimiento")
	# El puente va ANTES que el controlador en el árbol: el orden no debe importar.
	await load_mars(true)
	check(returns.size() == 2 and returns[1] == [2, 4], "El regreso pendiente debe resolverse al entrar a Marte: %s" % str(returns))
	check(discovered.size() == 2 and discovered[1] != discovered[0], "El regreso pendiente debe descubrir una muestra distinta")
	check(saved_ids().size() == 2, "Debe haber 2 IDs guardados: %s" % str(saved_ids()))
	await load_mars()
	check(discovered.size() == 2 and returns.size() == 2, "Volver a entrar no debe repetir el descubrimiento pendiente")

	# --- Dos escenas de Marte vivas a la vez (transición): un solo descubrimiento.
	check(controller.start_expedition(), "El rover debe salir el día 4")
	var second_mars := make_mars()
	root.add_child(second_mars)
	await frames(3)
	tasks.finish_day()
	await frames(1)
	check(returns.size() == 3 and discovered.size() == 3, "Con dos controladores vivos solo debe haber un regreso y un descubrimiento (%d, %d)" % [returns.size(), discovered.size()])
	second_mars.queue_free()
	await frames(1)

	# --- Reinicio del juego: un SampleDiscovery nuevo lee lo guardado.
	var reopened := SampleDiscovery.new()
	reopened.save_path = TEST_SAVE
	check(reopened.get_discovered_count() == 3, "Tras reiniciar deben seguir las 3 muestras descubiertas")
	reopened.free()

	# --- 12. Varias expediciones: todas distintas hasta completar el catálogo.
	await load_mars()
	while discovery.has_undiscovered_samples():
		var before := discovered.size()
		check(controller.start_expedition(), "El rover debe poder salir el día %d" % sim.day)
		tasks.finish_day()
		await frames(1)
		check(discovered.size() == before + 1, "Cada expedición debe descubrir exactamente una muestra")
		if discovered.size() != before + 1:
			break
	var ids := {}
	for s in discovered:
		ids[s.sample_id] = true
	check(discovered.size() == total and ids.size() == total, "Deben descubrirse las %d muestras sin repetir (%d, %d únicas)" % [total, discovered.size(), ids.size()])
	check(completed_count == 1, "catalog_completed debe emitirse una vez (fueron %d)" % completed_count)
	check(saved_ids().size() == total, "El archivo debe guardar %d IDs" % total)

	# --- 11. Catálogo completo: el rover vuelve sin muestra, sin errores ni duplicados.
	var day_before: int = sim.day
	check(controller.start_expedition(), "El rover debe poder salir con el catálogo completo")
	tasks.finish_day()
	await frames(1)
	check(discovered.size() == total and saved_ids().size() == total, "Con el catálogo completo no debe haber más descubrimientos")
	check(empty_returns == [[day_before, day_before + 1]], "Debe avisar expedition_returned_without_sample una vez: %s" % str(empty_returns))
	check(completed_count == 1, "catalog_completed no debe repetirse")
	check(controller.is_available() and station.interaction_enabled, "El rover debe quedar disponible aunque no traiga muestra")
	# Y al recrear la escena tampoco aparece nada.
	await load_mars()
	check(discovered.size() == total and empty_returns.size() == 1, "Recrear la escena con el catálogo completo no debe emitir nada")

	# --- Las fichas, las fotos y el progreso real no cambian.
	var after := hash_dir(SAMPLES_DIR)
	after.merge(hash_dir(IMAGES_DIR))
	check(after == originals, "Se modificó una ficha .tres o una foto")
	var real_after := FileAccess.get_md5(real_save) if FileAccess.file_exists(real_save) else ""
	check(real_after == real_before, "Se tocó el progreso real del jugador")

	unload_mars()
	await frames(1)
	SampleDiscoverySave.new(TEST_SAVE).clear()
	print("ROVER SAMPLE DISCOVERY CHECKS: %d muestras; failures: %d" % [total, failures])
	quit(0 if failures == 0 else 1)
