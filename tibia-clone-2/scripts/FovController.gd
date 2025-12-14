extends Node
class_name FovController

const TileQuery = preload("res://scripts/TileQuery.gd")

@export var floor_manager_path: NodePath = NodePath("../FloorManager")
@onready var floor_manager: FloorManager = get_node_or_null(floor_manager_path)

# Opcional: se quiser setar no Inspector como fallback (não é mais obrigatório)
@export var player_visual_path: NodePath
@onready var _fallback_player_visual: Node2D = get_node_or_null(player_visual_path) as Node2D

const FOV_OFFSETS := [
	Vector2i(0, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

# ============================================================
# DEBUG
# ============================================================

func debug_fov(player_ci: CanvasItem) -> void:
	if floor_manager == null:
		return

	var floors := floor_manager.get_floors()
	if floors.is_empty():
		return

	var idx := floor_manager.get_floor_index_for_global_z(player_ci.z_index)
	if idx == -1:
		return

	var floor_node: Node = floors[idx] as Node
	var tms := TileQuery.get_tilemaps_in_floor(floor_node)
	if tms.is_empty():
		return

	var ref: Node = tms[0]
	var center := TileQuery.center_cell_for_tm(ref, player_ci.global_position)

	var cells: Array = []
	for off in FOV_OFFSETS:
		cells.append(center + off)

# ============================================================
# INTERNAL HELPERS
# ============================================================

func _resolve_player_visual(p: Node) -> Node2D:
	# 1) Se o player tiver RemoteTransform2D, tenta achar o alvo do remote_path.
	var rt: RemoteTransform2D = p.get_node_or_null("RemoteToVisual") as RemoteTransform2D
	if rt != null and String(rt.remote_path) != "":
		var target := rt.get_node_or_null(rt.remote_path)
		if target != null and target is Node2D:
			return target as Node2D

	# 2) Fallback opcional do Inspector
	return _fallback_player_visual


func has_tile_above_in_fov(p_ci: CanvasItem) -> bool:
	if floor_manager == null:
		return false

	var floors := floor_manager.get_floors()
	if floors.is_empty():
		return false

	var idx := floor_manager.get_floor_index_for_global_z(p_ci.z_index)
	if idx == -1:
		return false

	var floor_node: Node = floors[idx] as Node
	var tms := TileQuery.get_tilemaps_in_floor(floor_node)
	if tms.is_empty():
		return false

	# tilemap de referência
	var ref: Node = tms[0]
	var center: Vector2i = TileQuery.center_cell_for_tm(ref, p_ci.global_position)
	var current_floor_z := (floors[idx] as CanvasItem).z_index

	for off in FOV_OFFSETS:
		var cell: Vector2i = center + off

		# procura qualquer tile acima em qualquer floor acima
		for f in floors:
			var ci := f as CanvasItem
			if ci.z_index <= current_floor_z:
				continue

			var tms_above := TileQuery.get_tilemaps_in_floor(ci as Node)
			for tm in tms_above:
				if TileQuery.cell_has_any_tile(tm, cell):
					return true

	return false

# ============================================================
# PUBLIC API
# ============================================================

func update_visibility(player: Node) -> void:
	var p_ci := player as CanvasItem
	if p_ci == null or floor_manager == null:
		return

	var pv := _resolve_player_visual(player)

	var has_above := has_tile_above_in_fov(p_ci)

	# Se tem tile acima no FOV, esconde floors acima.
	floor_manager.set_floors_above_visible_by_player(p_ci, not has_above, pv)
