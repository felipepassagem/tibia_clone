extends Node
class_name FovController

const TileQuery = preload("res://scripts/TileQuery.gd")

@export var floor_manager_path: NodePath = NodePath("../FloorManager")
@onready var floor_manager: Node = get_node_or_null(floor_manager_path)

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
#
## ============================================================
## DEBUG
## ============================================================
#func update_visibility(player: Node) -> void:
	#var p_ci := player as CanvasItem
	#if p_ci == null or floor_manager == null:
		#return
#
	#var pv := _resolve_player_visual(player)
#
	#var block_z := _first_blocking_floor_z(p_ci)
	#var floors := floor_manager.get_floors()
	#if floors.is_empty():
		#return

	## garante que o floor do visual nunca suma
	#var visual_floor: CanvasItem = null
	#if pv != null and pv.get_parent() is CanvasItem:
		#visual_floor = pv.get_parent() as CanvasItem
#
	#for f in floors:
		#var ci := f as CanvasItem
#
		## se encontrou um bloqueio: esconde esse floor e todos acima
		#if block_z != -1 and ci.z_index >= block_z:
			#if visual_floor != null and ci == visual_floor:
				#ci.visible = true
			#else:
				#ci.visible = false
		#else:
			#ci.visible = true
#
	#if pv != null:
		#pv.visible = true
		#if visual_floor != null:
			#visual_floor.visible = true


#func _resolve_player_visual(p: Node) -> Node2D:
	#return _resolve_player_visual(p)
#func debug_fov(player_ci: CanvasItem) -> void:
	#if floor_manager == null:
		#return
#
	#var floors := floor_manager.get_floors()
	#if floors.is_empty():
		#return
#
	#var idx := floor_manager.get_floor_index_for_global_z(player_ci.z_index)
	#if idx == -1:
		#return
#
	#var floor_node: Node = floors[idx] as Node
	#var tms := TileQuery.get_tilemaps_in_floor(floor_node)
	#if tms.is_empty():
		#return
#
	#var ref: Node = tms[0]
	#var center := TileQuery.center_cell_for_tm(ref, player_ci.global_position)
#
	#var cells: Array = []
	#for off in FOV_OFFSETS:
		#cells.append(center + off)
#
## ============================================================
## INTERNAL HELPERS
## ============================================================
#
#func _resolve_player_visual(p: Node) -> Node2D:
	#
	## 1) Se o player tiver RemoteTransform2D, tenta achar o alvo do remote_path.
	#var rt: RemoteTransform2D = p.get_node_or_null("RemoteToVisual") as RemoteTransform2D
	#if rt != null and String(rt.remote_path) != "":
		#var target := rt.get_node_or_null(rt.remote_path)
		#if target != null and target is Node2D:
			#return target as Node2D
#
	## 2) Fallback opcional do Inspector
	#return _fallback_player_visual
#
#
#func has_tile_above_in_fov(p_ci: CanvasItem) -> bool:
	#if floor_manager == null:
		#return false
#
	#var floors := floor_manager.get_floors()
	#if floors.is_empty():
		#return false
#
	#var idx := floor_manager.get_floor_index_for_global_z(p_ci.z_index)
	#if idx == -1:
		#return false
#
	#var floor_node: Node = floors[idx] as Node
	#var tms := TileQuery.get_tilemaps_in_floor(floor_node)
	#if tms.is_empty():
		#return false
#
	## tilemap de referência
	#var ref: Node = tms[0]
	#var center: Vector2i = TileQuery.center_cell_for_tm(ref, p_ci.global_position)
	#var current_floor_z := (floors[idx] as CanvasItem).z_index
#
	#for off in FOV_OFFSETS:
		#var cell: Vector2i = center + off
#
		## procura qualquer tile acima em qualquer floor acima
		#for f in floors:
			#var ci := f as CanvasItem
			#if ci.z_index <= current_floor_z:
				#continue
#
			#var tms_above := TileQuery.get_tilemaps_in_floor(ci as Node)
			#for tm in tms_above:
				#if TileQuery.cell_has_any_tile(tm, cell):
					#return true
#
	#return false
#
## ============================================================
## PUBLIC API
## ============================================================
#
#func _first_blocking_floor_z(player_ci: CanvasItem) -> int:
	#if floor_manager == null:
		#return -1
#
	#var floors: Array = floor_manager.get_floors()
	#if floors.is_empty():
		#return -1
#
	#var idx: int = floor_manager.get_floor_index_for_global_z(player_ci.z_index)
	#if idx == -1:
		#return -1
#
	## floor atual
	#var floor_node: Node = floors[idx] as Node
	#var tms := TileQuery.get_tilemaps_in_floor(floor_node)
	#if tms.is_empty():
		#return -1
#
	## célula do player (referência pelo primeiro tilemap do andar)
	#var ref: Node = tms[0]
	#var cell: Vector2i = TileQuery.center_cell_for_tm(ref, player_ci.global_position)
#
	## procura o PRIMEIRO floor acima que tenha qualquer tile nessa célula
	#for i in range(idx + 1, floors.size()):
		#var ci := floors[i] as CanvasItem
		#var tms_above := TileQuery.get_tilemaps_in_floor(ci as Node)
#
		#for tm in tms_above:
			#if TileQuery.cell_has_any_tile(tm, cell):
				#return ci.z_index
#
	#return -1
#func update_visibility(player: Node) -> void:
	##return
	#var p_ci := player as CanvasItem
	#if p_ci == null or floor_manager == null:
		#return
#
	#var pv := _resolve_player_visual(player)
#
	#var has_above := has_tile_above_in_fov(p_ci)
#
	## Se tem tile acima no FOV, esconde floors acima.
	#floor_manager.set_floors_above_visible_by_player(p_ci, not has_above, pv)
	#
#func debug_is_wall_around_player(player: Node) -> void:
	#if floor_manager == null:
		#print("[FOV] FloorManager NULL")
		#return
#
	#var p_ci := player as CanvasItem
	#if p_ci == null:
		#print("[FOV] player não é CanvasItem")
		#return
#
	#var floors := floor_manager.get_floors()
	#if floors.is_empty():
		#print("[FOV] floors vazio")
		#return
#
	## mesmo "global_z" (floor.z + player.z)
	#var parent_floor := p_ci.get_parent() as CanvasItem
	#var global_z: int = (parent_floor.z_index if parent_floor else 0) + p_ci.z_index
#
	#var idx := floor_manager.get_floor_index_for_global_z(global_z)
	#if idx == -1:
		#print("[FOV] idx=-1 para global_z=", global_z)
		#return
#
	#var floor_node: Node = floors[idx] as Node
	#var tms: Array = TileQuery.get_tilemaps_in_floor(floor_node)
	#if tms.is_empty():
		#print("[FOV] sem tilemaps no floor atual")
		#return
#
	## tilemap de referência pra achar a célula do player
	#var ref: Node = tms[0]
	#var center: Vector2i = TileQuery.center_cell_for_tm(ref, p_ci.global_position)
#
	#print("[FOV][L] floor=", (floors[idx] as CanvasItem).name, " global_z=", global_z, " center=", center)
#
	## offsets 3x3 (inclui centro)
	#for oy in [-1, 0, 1]:
		#for ox in [-1, 0, 1]:
			#var off: Vector2i = Vector2i(ox, oy)
			#var cell: Vector2i = center + off
#
			#var hit_wall: bool = false
			#for tm in tms:
				#var td := _get_tiledata(tm, cell)
				#if td != null and td.get_custom_data("is_wall") == true:
					#hit_wall = true
					#break
#
			#print("(", ox, ", ", oy, "), is_wall == ", hit_wall)
#
#
#func _get_tiledata(tm: Node, cell: Vector2i) -> TileData:
	#if tm is TileMap:
		#return (tm as TileMap).get_cell_tile_data(0, cell)
	## TileMapLayer (Godot 4)
	#return tm.get_cell_tile_data(cell)
#
			#
#func test_hide_floors_by_3x3(player: Node) -> void:
	#if floor_manager == null:
		#return
#
	#var p_ci := player as CanvasItem
	#if p_ci == null:
		#return
#
	#var pv := _resolve_player_visual(player)
#
	#var floors := floor_manager.get_floors()
	#if floors.is_empty():
		#return
#
	## floor atual via global_z (floor.z + player.z)
	#var parent_floor := p_ci.get_parent() as CanvasItem
	#var global_z: int = (parent_floor.z_index if parent_floor else 0) + p_ci.z_index
	#var idx := floor_manager.get_floor_index_for_global_z(global_z)
	#if idx == -1:
		#return
#
	#var current_floor_ci := floors[idx] as CanvasItem
	#var current_floor_z := current_floor_ci.z_index
#
	## tilemaps do andar atual
	#var tms_current := TileQuery.get_tilemaps_in_floor(current_floor_ci as Node)
	#if tms_current.is_empty():
		#return
#
	#var ref: Node = tms_current[0]
	#var center: Vector2i = TileQuery.center_cell_for_tm(ref, p_ci.global_position)
#
	## Vamos achar o menor z acima que deve ser escondido
	#var cut_z := 2147483647 # INF int
#
	#for oy in [-1, 0, 1]:
		#for ox in [-1, 0, 1]:
			#var cell: Vector2i = center + Vector2i(ox, oy)
#
			## 1) Se no andar atual houver is_wall, IGNORA (não dispara esconder)
			#var is_wall_here := false
			#for tm in tms_current:
				#var td := _get_tiledata(tm, cell)
				#if td != null and td.get_custom_data("is_wall") == true:
					#is_wall_here = true
					#break
			#if is_wall_here:
				#continue
#
			## 2) Procura o primeiro floor acima que tenha qualquer tile nessa cell
			#for f in floors:
				#var ci := f as CanvasItem
				#if ci.z_index <= current_floor_z:
					#continue
#
				#var tms_above := TileQuery.get_tilemaps_in_floor(ci as Node)
				#var has_tile := false
				#for tm_above in tms_above:
					#if TileQuery.cell_has_any_tile(tm_above, cell):
						#has_tile = true
						#break
#
				#if has_tile:
					#cut_z = min(cut_z, ci.z_index)
					#break # achou o primeiro acima para essa cell
	## aplica resultado
	#if cut_z == 2147483647:
		## nada acima “bloqueando” -> tudo visível
		#floor_manager.set_floors_visible_from_z(current_floor_z + 1, true, pv)
	#else:
		## esconde do cut_z pra cima
		#floor_manager.set_floors_visible_from_z(cut_z, false, pv)
		
		# =========================
# Helpers
# =========================

#func _resolve_player_visual(p: Node) -> Node2D:
	#var rt: RemoteTransform2D = p.get_node_or_null("RemoteToVisual") as RemoteTransform2D
	#if rt != null and String(rt.remote_path) != "":
		#var target := rt.get_node_or_null(rt.remote_path)
		#if target != null and target is Node2D:
			#return target as Node2D
	#return _fallback_player_visual

#func _cell_for_tm_world(tm: Node, world_pos: Vector2) -> Vector2i:
	## ✅ COMPENSA offsets de cada floor automaticamente
	#var tm2d := tm as Node2D
	#var local_pos: Vector2 = tm2d.to_local(world_pos)
	#return tm.local_to_map(local_pos)

# =========================
# Core (apenas sqm do player)
# =========================

#func has_tile_above_at_player_worldpos(player_ci: CanvasItem) -> bool:
	#if floor_manager == null:
		#return false
#
	#var floors: Array = floor_manager.get_floors()
#
	#if floors.is_empty():
		#return false
#
	## floor atual do player (pelo z global que vocês usam)
	#var idx: int = floor_manager.get_floor_index_for_global_z(player_ci.z_index)
	#if idx == -1:
		#return false
#
	#var current_floor_z: int = (floors[idx] as CanvasItem).z_index
	#var world_pos: Vector2 = player_ci.global_position
#
	## ✅ Procura qualquer tile diretamente acima (mesma posição no mundo),
	## varrendo todos os floors acima do atual.
	#for f in floors:
		#var ci := f as CanvasItem
		#if ci.z_index <= current_floor_z:
			#continue
#
		#var tms_above := TileQuery.get_tilemaps_in_floor(ci as Node)
		#for tm in tms_above:
			#var cell_above: Vector2i = _cell_for_tm_world(tm, world_pos)
#
			#if TileQuery.cell_has_any_tile(tm, cell_above):
				## achou um tile acima -> deve esconder floors acima do player
				#return true
#
	#return false

# =========================
# Public API
# =========================

#func update_visibility(player: Node) -> void:
	#var p_ci := player as CanvasItem
	#if p_ci == null or floor_manager == null:
		#return
#
	#var pv := _resolve_player_visual(player)
#
	#var has_above := has_tile_above_at_player_worldpos(p_ci)
#
	## Se tem algo acima -> esconder floors acima
	## Se não tem -> mostrar
	#floor_manager.set_floors_above_visible_by_player(p_ci, not has_above, pv)
