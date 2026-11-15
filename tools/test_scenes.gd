extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run_checks() -> void:
	var expected := {
		"uid://c48fronko4746": "res://game/world/rooms/cuarto1.tscn",
		"uid://jexu5nqaai6d": "res://game/world/rooms/cuarto2.tscn",
		"uid://b6tv63xxtm0pj": "res://game/world/rooms/puerta.tscn",
		"uid://djnjchenqclp2": "res://game/stations/greenhouse/greenhouse.tscn",
		"uid://caqmvqbn661my": "res://game/main/main.gd",
		"uid://bvjydf0kyxvc0": "res://game/stations/greenhouse/greenhouse.gd",
		"uid://fbmnrp4uqmtk": "res://game/stations/power/power_station.gd"
	}
	for uid in expected:
		var id := ResourceUID.text_to_id(uid)
		check(ResourceUID.has_id(id) and ResourceUID.get_id_path(id) == expected[uid], "Wrong UID resolution: " + uid)
	for path in ["res://game/main/main.tscn", "res://game/world/rooms/cuarto1.tscn", "res://game/world/rooms/cuarto2.tscn", "res://game/stations/greenhouse/greenhouse.tscn", "res://game/stations/mars/mars.tscn", "res://game/stations/power/power_station.tscn"]:
		check(change_scene_to_file(path) == OK, "Scene failed to load: " + path)
		await process_frame
		await process_frame
		for door in current_scene.find_children("*", "Area2D", true, false):
			if door.get_script() != load("res://game/world/rooms/puerta.gd"):
				continue
			var target = load(door.cuarto_destino)
			check(target is PackedScene, "Door target cannot load: " + str(door.cuarto_destino))
			if target is PackedScene:
				check(not target.resource_path.contains("-MSI"), "Door resolves to a discarded copy")
		if path.ends_with("cuarto1.tscn"):
			check(current_scene.get_node("puerta2").cuarto_destino == "res://game/stations/greenhouse/greenhouse.tscn", "The original room must keep its greenhouse exit")
	print("SCENE CHECKS: 6 scenes, canonical UID resolution and door targets; failures: ", failures)
	quit(0 if failures == 0 else 1)
