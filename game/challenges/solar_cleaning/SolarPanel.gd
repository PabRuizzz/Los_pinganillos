@tool
extends Control
## Equal-area grid cells: 0 = dirty, 1 = clean. Artwork stays separate from state.
@export var dust_texture: Texture2D
@export_range(0.0, 1.0) var dust_opacity := 0.58

signal progress_changed(clean_cells: int, total_cells: int)
signal cell_cleaned(coordinates: Vector2i)

const columns := 20
const rows := 20
const cell_size := Vector2(12, 8)
var states := PackedByteArray()
var clean_count := 0

func _ready() -> void:
	reset()

func reset() -> void:
	states.resize(columns * rows)
	states.fill(0)
	clean_count = 0
	size = Vector2(columns, rows) * cell_size
	_refresh_cells()
	queue_redraw()
	_update_readout()
	progress_changed.emit(clean_count, states.size())

func clean_ratio() -> float:
	return float(clean_count) / maxi(states.size(), 1)

func is_clean_at(coordinates: Vector2i) -> bool:
	if coordinates.x < 0 or coordinates.y < 0 or coordinates.x >= columns or coordinates.y >= rows:
		return false
	return states[coordinates.y * columns + coordinates.x] == 1

func clean_circle(center: Vector2, radius: float) -> int:
	if radius <= 0.0:
		return 0
	var changed := 0
	for y in rows:
		for x in columns:
			var index := y * columns + x
			if states[index] == 1:
				continue
			var corner := Vector2(x, y) * cell_size
			var nearest := center.clamp(corner, corner + cell_size)
			if center.distance_squared_to(nearest) <= radius * radius:
				states[index] = 1
				clean_count += 1
				changed += 1
				cell_cleaned.emit(Vector2i(x, y))
	if changed > 0:
		_refresh_cells()
		queue_redraw()
		_update_readout()
		progress_changed.emit(clean_count, states.size())
	return changed

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("b9c5d2"), false, 1.0)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_artwork()

func _sync_artwork() -> void:
	if not has_node("Cells"):
		return
	var has_image: bool = $Artwork.texture != null
	for cell in $Cells.get_children():
		# Each cell reveals a slice of one continuous dust layer.
		if dust_texture != null:
			var atlas = cell.get_node("DirtyArtwork").texture as AtlasTexture
			if atlas == null or atlas.atlas != dust_texture:
				atlas = AtlasTexture.new()
				atlas.atlas = dust_texture
				atlas.region = Rect2(cell.position / size * dust_texture.get_size(), cell.size / size * dust_texture.get_size())
				cell.get_node("DirtyArtwork").texture = atlas
			cell.get_node("DirtyArtwork").modulate = Color(0.82, 0.72, 0.6, dust_opacity)
		if cell.reveal_panel_artwork != has_image:
			cell.reveal_panel_artwork = has_image
			cell.queue_redraw()

func _refresh_cells() -> void:
	_sync_artwork()
	for i in states.size():
		$Cells.get_child(i).clean = states[i] == 1

func clean_world_circle(center: Vector2, radius: float) -> int:
	if radius <= 0:
		return 0
	var changed := 0
	for i in states.size():
		var cell = $Cells.get_child(i)
		if states[i] == 0 and cell.touches_circle(center, radius):
			states[i] = 1
			cell.clean = true
			clean_count += 1
			changed += 1
			cell_cleaned.emit(Vector2i(i % columns, i / columns))
	if changed > 0:
		_update_readout()
		progress_changed.emit(clean_count, states.size())
	return changed

func _update_readout() -> void:
	if has_node("Readout"):
		$Readout.text = "%02d%% LIMPIO" % floori(clean_ratio() * 100.0 + 0.001)
		$Readout.modulate = Color("78e4d0") if clean_count == states.size() else Color("d4e1ec")
