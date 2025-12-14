extends RefCounted
class_name TileQuery

static func get_tilemaps_in_floor(floor_node: Node) -> Array:
	var out: Array = []
	for ch in floor_node.get_children():
		if ch is TileMap:
			out.append(ch)
		elif ch.has_method("get_cell_source_id") and ch.has_method("local_to_map"):
			out.append(ch)
	return out

static func center_cell_for_tm(tm: Node, world_pos: Vector2) -> Vector2i:
	var tm2d := tm as Node2D
	var local_pos := tm2d.to_local(world_pos)
	return tm.local_to_map(local_pos)

static func cell_has_any_tile(tm: Node, cell: Vector2i) -> bool:
	if tm is TileMap:
		return (tm as TileMap).get_cell_source_id(0, cell) != -1
	return tm.get_cell_source_id(cell) != -1

static func cell_is_wall(tm: Node, cell: Vector2i) -> bool:
	var td: TileData
	if tm is TileMap:
		td = (tm as TileMap).get_cell_tile_data(0, cell)
	else:
		td = tm.get_cell_tile_data(cell)

	if td == null:
		return false
	return td.get_custom_data("is_wall") == true
