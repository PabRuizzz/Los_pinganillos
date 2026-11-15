extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func travel(door_path: String) -> void:
	var door = current_scene.get_node(door_path)
	var marker_name: String = door.nombre_spawn
	var destination: String = door.cuarto_destino
	door._on_body_entered(current_scene.get_node("player"))
	await scene_changed
	await physics_frame
	await physics_frame
	assert(current_scene.scene_file_path == destination)
	var player = current_scene.get_node("player")
	var marker = current_scene.find_child(marker_name, true, false)
	assert(marker is Marker2D)
	assert(player.global_position.is_equal_approx(marker.global_position))
	assert(player.get_node("CollisionShape2D").global_position.is_equal_approx(marker.global_position))
	assert(not has_meta("spawn_destino") and not has_meta("door_transition_pending"))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.transform = player.get_node("CollisionShape2D").global_transform
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var hits = player.get_world_2d().direct_space_state.intersect_shape(query)
	assert(hits.is_empty(), "Spawn inside solid collision: " + destination)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query):
		assert(not hit.collider.has_method("_change_scene"), "Arrival overlaps a door")
	print("PASS arrival: ", destination, " / ", marker_name, " at ", player.global_position)

func run() -> void:
	change_scene_to_file("res://game/stations/mars/mars.tscn")
	await scene_changed
	await physics_frame
	await travel("hitbox/StaticBody2D/puerta")
	await travel("puerta")
	await travel("hitbox/StaticBody2D/puerta2")
	await travel("puerta")
	change_scene_to_file("res://game/world/rooms/cuarto1.tscn")
	await scene_changed
	await physics_frame
	await travel("puerta")
	await travel("puerta")
	await travel("puerta")
	await travel("puerta2")
	await travel("puerta2")
	print("PASS: all configured door routes; centered collision, clear arrivals and consumed metadata")
	quit()
