extends Control

signal completed

const TREATMENT_SCENE := preload("res://game/challenges/greenhouse_fungus/ManualTreatment.tscn")

@onready var content: Control = $Content
@onready var plants := $Content/Plants.get_children()
@onready var routes := $Content/Routes.get_children()
@onready var uv_button: Button = $Content/UV
@onready var status: Label = $Content/Status
@onready var feedback: Label = $Content/Feedback

var uv_on := false
var finished := false
var treatment: Control

func _ready() -> void:
	resized.connect(_layout)
	_layout()
	# Begin with a localized outbreak in one of the two middle planters.
	plants[randi_range(1, 2)].infected = true
	for plant in plants:
		plant.pressed.connect(_open_treatment.bind(plant))
	for route in routes:
		route.pressed.connect(_toggle_barrier.bind(route))
	uv_button.toggled.connect(_toggle_uv)
	_refresh()

func _layout() -> void:
	var factor := minf(size.x / 1120.0, size.y / 630.0)
	content.scale = Vector2.ONE * factor
	content.position = (size - Vector2(1120, 630) * factor) / 2.0
	if is_instance_valid(treatment):
		treatment.scale = content.scale
		treatment.position = content.position

func _toggle_uv(enabled: bool) -> void:
	uv_on = enabled
	if uv_on:
		feedback.text = "Close the barriers on amber paths before treating an infected plant."
	else:
		feedback.text = "Turn on the UV light to reveal fungus and spread routes."
	_refresh()

func _toggle_barrier(route: Button) -> void:
	if finished:
		return
	route.closed = not route.closed
	feedback.text = "Barrier closed." if route.closed else "Barrier opened."
	_refresh()

func _open_treatment(plant: Button) -> void:
	if finished or is_instance_valid(treatment):
		return
	if not uv_on:
		feedback.text = "Turn on the UV light to find the fungus."
		return
	if not plant.infected:
		feedback.text = "This plant is healthy."
		return

	treatment = TREATMENT_SCENE.instantiate()
	treatment.plant_number = plants.find(plant) + 1
	treatment.completed.connect(_finish_treatment.bind(plant), CONNECT_ONE_SHOT)
	content.hide()
	add_child(treatment)
	_layout()

func _finish_treatment(plant: Button) -> void:
	# Only the treated plant can shed spores during this visit.
	var exposed: Array[Button] = []
	for route in routes:
		if route.closed:
			continue
		var left: Button = plants[route.left_plant]
		var right: Button = plants[route.right_plant]
		if left == plant and not right.infected:
			exposed.append(right)
		elif right == plant and not left.infected:
			exposed.append(left)
	for neighbor in exposed:
		neighbor.infected = true

	plant.infected = false
	treatment.hide()
	treatment.queue_free()
	treatment = null
	content.show()
	plant.show_spray()
	feedback.text = "Plant treated." if exposed.is_empty() else "Plant treated. The fungus spread along open paths."
	if plants.all(func(item): return not item.infected):
		finished = true
		feedback.text = "Outbreak contained. All plants are healthy."
	_refresh()
	if finished:
		completed.emit()

func _open_neighbors() -> Array[Button]:
	var exposed: Array[Button] = []
	for route in routes:
		if route.closed:
			continue
		var left: Button = plants[route.left_plant]
		var right: Button = plants[route.right_plant]
		if left.infected != right.infected:
			var neighbor := right if left.infected else left
			if not exposed.has(neighbor):
				exposed.append(neighbor)
	return exposed

func _refresh() -> void:
	var infected_count := 0
	for plant in plants:
		if plant.infected:
			infected_count += 1
		plant.show_state(uv_on, finished)
	for route in routes:
		var connects_blight: bool = plants[route.left_plant].infected != plants[route.right_plant].infected
		route.show_state(uv_on and connects_blight, finished)
	uv_button.text = "UV LIGHT  ·  ON" if uv_on else "TURN ON UV LIGHT"
	uv_button.disabled = finished
	if not uv_on:
		status.text = "Infection not yet scanned"
	elif infected_count == 0:
		status.text = "4/4 plants healthy"
	else:
		status.text = "%d/4 healthy  ·  %s" % [plants.size() - infected_count,
			"Outbreak contained" if _open_neighbors().is_empty() else "Fungus can spread"]
