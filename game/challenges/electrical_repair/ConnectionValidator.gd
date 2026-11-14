extends RefCounted
## Pure BFS, independent of scene nodes; only reciprocal cable edges conduct.

const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const SIDES := [1, 2, 4, 8]
const OPPOSITE := [4, 8, 1, 2]

func validate(masks: Dictionary, source: Dictionary, targets: Array, minimum_pieces: int = 1) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = []
	var start: Vector2i = source.cell
	if (int(masks.get(start, 0)) & int(source.side)) != 0:
		queue.append(start)
		visited[start] = true
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var mask := int(masks.get(current, 0))
		for i in 4:
			var neighbor: Vector2i = current + DIRECTIONS[i]
			if (mask & SIDES[i]) == 0 or visited.has(neighbor):
				continue
			if (int(masks.get(neighbor, 0)) & OPPOSITE[i]) != 0:
				visited[neighbor] = true
				queue.append(neighbor)
	var reached := 0
	for target in targets:
		if visited.has(target.cell) and (int(masks.get(target.cell, 0)) & int(target.side)) != 0:
			reached += 1
	return {"complete": not targets.is_empty() and reached == targets.size() and visited.size() >= minimum_pieces, "reached": reached, "energized": visited}
