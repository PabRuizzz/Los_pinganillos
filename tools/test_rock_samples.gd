extends SceneTree
## Valida el catálogo de muestras geológicas.
##   godot --headless --path . --script res://tools/test_rock_samples.gd

const CATALOG_PATH := "res://data/rock_samples/rock_sample_catalog.tres"
const SAMPLES_DIR := "res://data/rock_samples/"

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var catalog = load(CATALOG_PATH)
	check(catalog is RockSampleCatalog, "El catálogo no usa RockSampleCatalog: " + CATALOG_PATH)
	if not catalog is RockSampleCatalog:
		quit(1)
		return

	var samples: Array[RockSampleData] = catalog.get_all()
	check(samples.size() == catalog.samples.size(), "El catálogo tiene entradas vacías")

	var ids := {}
	var catalog_paths := {}
	for sample in samples:
		var label := sample.resource_path
		catalog_paths[sample.resource_path] = true
		check(sample.get_script() == RockSampleData, "No usa rock_sample_data.gd: " + label)
		check(not sample.sample_id.is_empty(), "Falta sample_id: " + label)
		check(not ids.has(sample.sample_id), "sample_id repetido: " + sample.sample_id)
		ids[sample.sample_id] = true
		check(label.get_file().get_basename() == sample.sample_id, "El nombre del archivo no coincide con sample_id: " + label)
		for field in ["sample_name", "rock_type", "location", "rover", "description", "interesting_fact", "image_caption", "image_credit", "image_url", "source_name", "source_url"]:
			check(not str(sample.get(field)).strip_edges().is_empty(), "Campo vacío '%s' en %s" % [field, label])
		check(sample.image_url.begins_with("https://") and sample.source_url.begins_with("https://"), "URL no https en " + label)
		check(sample.sample_image is Texture2D, "No se cargó la imagen de " + label)
		if sample.sample_image is Texture2D:
			check(sample.sample_image.get_width() > 0, "Imagen vacía en " + label)

	# Toda ficha de la carpeta debe estar en el catálogo.
	for file in DirAccess.get_files_at(SAMPLES_DIR):
		var path := SAMPLES_DIR + file
		if not file.ends_with(".tres") or path == CATALOG_PATH:
			continue
		check(catalog_paths.has(path), "Ficha fuera del catálogo: " + path)

	# Funciones auxiliares.
	if not samples.is_empty():
		var first := samples[0]
		check(catalog.get_by_id(first.sample_id) == first, "get_by_id no devuelve la muestra correcta")
		check(catalog.get_by_id("no_existe") == null, "get_by_id debe devolver null si no existe")
		check(catalog.get_undiscovered([first.sample_id]).size() == samples.size() - 1, "get_undiscovered no excluye las descubiertas")
		check(catalog.get_random([first.sample_id]) != first, "get_random devolvió una muestra excluida")
		check(catalog.get_random(ids.keys()) == null, "get_random debe devolver null si ya se descubrieron todas")

	var collected := samples.filter(func(s): return s.is_collected()).size()
	print("ROCK SAMPLE CHECKS: %d muestras (%d recolectadas, %d observadas); failures: %d" % [samples.size(), collected, samples.size() - collected, failures])
	quit(0 if failures == 0 else 1)
