extends SceneTree
## Valida el sistema de descubrimiento de muestras del rover.
##   godot --headless --path . --script res://tools/test_sample_discovery.gd
##
## Usa un archivo de guardado propio: no lee, borra ni sobrescribe el progreso real.

const TEST_SAVE := "user://test_sample_discovery.cfg"
const SAMPLES_DIR := "res://data/rock_samples/"
const IMAGES_DIR := "res://assets/science/rock_samples/"

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func new_system() -> SampleDiscovery:
	var system := SampleDiscovery.new()
	system.save_path = TEST_SAVE
	return system


func hash_dir(dir: String) -> Dictionary:
	var result := {}
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".import"):
			continue
		result[dir + file] = FileAccess.get_md5(dir + file)
	return result


func run_checks() -> void:
	var real_save := SampleDiscoverySave.DEFAULT_PATH
	var real_save_before := FileAccess.get_md5(real_save) if FileAccess.file_exists(real_save) else ""
	var originals := hash_dir(SAMPLES_DIR)
	originals.merge(hash_dir(IMAGES_DIR))

	SampleDiscoverySave.new(TEST_SAVE).clear()

	# 1. Partida nueva sin descubrimientos.
	var system := new_system()
	var total := system.get_total_count()
	check(total > 1, "El catálogo necesita al menos 2 muestras para la prueba")
	check(system.get_discovered_count() == 0, "Una partida nueva no debe tener descubrimientos")
	check(system.get_remaining_count() == total, "Al empezar deben quedar todas las muestras")
	check(system.has_undiscovered_samples(), "Al empezar debe haber muestras por descubrir")

	# 2-3. Una expedición entrega una muestra del catálogo y queda registrada.
	var emitted: Array[RockSampleData] = []
	system.sample_discovered.connect(func(s: RockSampleData): emitted.append(s))
	var first := system.complete_expedition()
	check(first is RockSampleData, "complete_expedition debe devolver una RockSampleData")
	check(first != null and system.catalog.get_by_id(first.sample_id) == first, "La muestra no pertenece al catálogo")
	check(first != null and system.is_discovered(first.sample_id), "La muestra no quedó registrada")
	check(system.get_discovered_count() == 1 and system.get_remaining_count() == total - 1, "Contadores incorrectos tras 1 expedición")
	check(emitted.size() == 1 and emitted[0] == first, "La señal sample_discovered no entregó la muestra")

	# 4. La siguiente expedición no repite muestra.
	var second := system.complete_expedition()
	check(second != null and second != first, "La segunda expedición repitió la muestra")

	# 5. El progreso persiste al "cerrar y reabrir" (instancia nueva leyendo el archivo).
	system.free()
	var reopened := new_system()
	check(reopened.get_discovered_count() == 2, "No se recuperaron los descubrimientos guardados")
	check(reopened.is_discovered(first.sample_id) and reopened.is_discovered(second.sample_id), "Faltan IDs tras reabrir")

	# 6. Completar el catálogo sin duplicados y avisar al terminar.
	var completed := [false]
	reopened.catalog_completed.connect(func(): completed[0] = true)
	var seen := {first.sample_id: true, second.sample_id: true}
	while reopened.has_undiscovered_samples():
		var sample := reopened.complete_expedition()
		check(sample != null and not seen.has(sample.sample_id), "Se repitió una muestra antes de completar el catálogo")
		if sample == null:
			break
		seen[sample.sample_id] = true
	check(seen.size() == total, "No se descubrieron todas las muestras")
	check(completed[0], "No se emitió catalog_completed")
	check(reopened.is_catalog_complete() and reopened.get_remaining_count() == 0, "El catálogo debería estar completo")
	check(reopened.complete_expedition() == null, "Con el catálogo completo debe devolver null, no un duplicado")
	check(reopened.get_discovered_count() == total, "Se registraron duplicados")
	var saved := SampleDiscoverySave.new(TEST_SAVE).load_ids()
	check(saved.size() == total, "El archivo guarda %d IDs, se esperaban %d" % [saved.size(), total])
	reopened.free()

	# 7. Fichas, imágenes y progreso real sin cambios.
	var after := hash_dir(SAMPLES_DIR)
	after.merge(hash_dir(IMAGES_DIR))
	check(after == originals, "Se modificó un .tres o una imagen original")
	var real_save_after := FileAccess.get_md5(real_save) if FileAccess.file_exists(real_save) else ""
	check(real_save_after == real_save_before, "Se tocó el progreso real del jugador")

	SampleDiscoverySave.new(TEST_SAVE).clear()
	print("SAMPLE DISCOVERY CHECKS: %d muestras; failures: %d" % [total, failures])
	quit(0 if failures == 0 else 1)
