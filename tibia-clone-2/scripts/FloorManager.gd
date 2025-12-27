extends Node
class_name FloorManager

@export var floor00_z: int = 1000
@export var floor_z_step: int = 100
@export var floor_layer_bit_base: int = 15  # 15 => layer 16
@export var floors_root_path: NodePath = NodePath("../Floors")

var floors: Array = []  # Array de CanvasItem (floors)
var _floors_hidden_by_debug := false

func _ready() -> void:
	refresh_floors()
	
func z_to_floor_logical(floor_z: int) -> int:
	return int((floor_z - floor00_z) / floor_z_step)

func floor_to_layer_bit(floor_logical: int) -> int:
	return floor_layer_bit_base + floor_logical

func floor_to_layer_mask(floor_logical: int) -> int:
	var bit := floor_to_layer_bit(floor_logical)
	if bit < 0 or bit > 31:
		#print("[FloorManager] bit fora do limite:", bit, " floor=", floor_logical)
		return 0
	return 1 << bit

func apply_collision_for_floor(player: CharacterBody2D, floor_logical: int) -> void:
	var mask := floor_to_layer_mask(floor_logical)
	if mask == 0:
		return
	player.collision_layer = mask
	player.collision_mask = mask
	#print("[FloorManager] colisão aplicada floor=", floor_logical, " mask=", mask)

func refresh_floors() -> Array:
	floors.clear()

	var floors_root := get_node_or_null(floors_root_path)
	if floors_root == null:
		#print("[FloorManager] ERRO: floors_root_path inválido -> ", floors_root_path)
		return floors

	for child in floors_root.get_children():
		var name_str := String(child.name)
		if name_str.to_lower().begins_with("floor") and (child is CanvasItem):
			floors.append(child)

	# ordena por z_index (baixo -> alto)
	floors.sort_custom(func(a, b):
		return (a as CanvasItem).z_index < (b as CanvasItem).z_index
	)

	#print("[FloorManager] floors carregados: ", floors.size())
	for f in floors:
		var ci := f as CanvasItem
		#print("  - ", ci.name, " z=", ci.z_index)

	return floors
	


func toggle_hide_floors_above_player(player: Node) -> void:
	if floors.is_empty():
		refresh_floors()
	if floors.is_empty():
		return

	var v = player.get("current_floor")
	if v == null:
		print("[DEBUG] Player sem current_floor")
		return

	var player_floor_logical: int = int(v)

	_floors_hidden_by_debug = not _floors_hidden_by_debug

	for f in floors:
		var ci := f as CanvasItem
		var floor_logical := z_to_floor_logical(ci.z_index)

		if floor_logical > player_floor_logical:
			ci.visible = not _floors_hidden_by_debug
		else:
			ci.visible = true



func get_floors() -> Array:
	if floors.is_empty():
		refresh_floors()
	return floors
	
func get_floor_index_for_global_z(global_z: int) -> int:
	if floors.is_empty():
		refresh_floors()
	if floors.is_empty():
		return -1

	var best_idx := -1
	var best_z := -INF

	for i in range(floors.size()):
		var f := floors[i] as CanvasItem
		var z := f.z_index

		if z <= global_z and z > best_z:
			best_z = z
			best_idx = i

	# se global_z estiver abaixo do menor floor, cai no 0
	if best_idx == -1:
		best_idx = 0

	return best_idx


#func get_floor_index_for_global_z(global_z: int) -> int:
	#if floors.is_empty():
		#refresh_floors()
#
	#if floors.is_empty():
		##print("[FloorManager] Nenhum floor carregado")
		#return -1
#
	#var closest_idx := -1
	#var closest_diff := INF
#
	#for i in floors.size():
		#var f := floors[i] as CanvasItem
		#var diff: float = abs(float(f.z_index - global_z))
#
		#if diff < closest_diff:
			#closest_diff = diff
			#closest_idx = i
#
	#if closest_idx == -1:
		#print("[FloorManager] Não foi possível determinar floor para z=", global_z)
	#else:
		#var f := floors[closest_idx] as CanvasItem
		##print("[FloorManager] Floor atual:", f.name, " z=", f.z_index)
#
	#return closest_idx
	
func change_floor_for_player(
	player: CharacterBody2D,
	delta_idx: int,
	player_visual: Node2D,
	remote_to_visual: RemoteTransform2D
) -> int:
	if floors.is_empty():
		refresh_floors()
	if floors.is_empty():
		return -1

	# floor atual vem do player (lógico)
	if not player.has_meta("current_floor") and not ("current_floor" in player):
		# se você não usa meta, assume que existe a variável current_floor no Player.gd
		pass

	var old_logical: int = player.current_floor
	var new_logical: int = old_logical + delta_idx

	# acha os nodes de floor (old/new) pelo logical
	var old_floor: CanvasItem = null
	var new_floor: CanvasItem = null
	for f in floors:
		var ci := f as CanvasItem
		if ci == null: continue
		var fl := z_to_floor_logical(ci.z_index)
		if fl == old_logical: old_floor = ci
		if fl == new_logical: new_floor = ci

	if new_floor == null or old_floor == null:
		return -1

	# compensa o offset visual entre floors (0,0 / -32,-32 / +32,+32...)
	var delta_off: Vector2 = (new_floor as Node2D).global_position - (old_floor as Node2D).global_position
	player.global_position += delta_off
	player.target_position += delta_off  # (assumindo que existe no Player)

	# atualiza referência de floor no player
	player.current_floor = new_logical

	# z do player vira o z do floor (global)
	player.z_index = new_floor.z_index

	# colisão do andar
	apply_collision_for_floor(player, new_logical)

	# mantém pipeline do visual/remote
	ensure_visual_on_current_floor(player, player_visual, remote_to_visual)

	return new_logical

	

#func ensure_visual_on_current_floor(
	#player: Node,
	#player_visual: Node2D,
	#remote_to_visual: RemoteTransform2D
#) -> void:
	#if player_visual == null or player == null:
		#return
#
	## ✅ z global real do player = floor(z) + z local do player
	#var pf := player.get_parent() as CanvasItem
	#var player_global_z: int = (pf.z_index if pf != null else 0) + int(player.get("z_index"))
#
	#var idx := get_floor_index_for_global_z(player_global_z)
	#if idx == -1:
		#return
#
	#var target_floor: Node = floors[idx] as Node
	#if player_visual.get_parent() == target_floor:
		## ainda garante render correto
		#player_visual.z_index = int(player_visual.global_position.y)
		#return
#
	#var old_global := player_visual.global_position
#
	#var old_parent := player_visual.get_parent()
	#if old_parent != null:
		#old_parent.remove_child(player_visual)
#
	#target_floor.add_child(player_visual)
	#player_visual.global_position = old_global
#
	## ✅ evita ficar “por baixo” do tilemap após trocar de andar
	##player_visual.z_index = int(player_visual.global_position.y)
#
	#if remote_to_visual != null:
		#remote_to_visual.remote_path = player_visual.get_path()
#
	#player_visual.visible = true
	#if target_floor is CanvasItem:
		#(target_floor as CanvasItem).visible = true
		
func ensure_visual_on_current_floor(player: Node, player_visual: Node2D, remote_to_visual: RemoteTransform2D) -> void:
	if player == null or player_visual == null:
		return

	var pf := player.get_parent() as CanvasItem
	var player_global_z: int = (pf.z_index if pf != null else 0) + int(player.get("z_index"))

	var idx := get_floor_index_for_global_z(player_global_z)
	if idx == -1:
		return

	var target_floor: Node = floors[idx] as Node
	if player_visual.get_parent() != target_floor:
		var old_global := player_visual.global_position
		var old_parent := player_visual.get_parent()
		if old_parent != null:
			old_parent.remove_child(player_visual)
		target_floor.add_child(player_visual)
		player_visual.global_position = old_global

	if remote_to_visual != null:
		remote_to_visual.remote_path = player_visual.get_path()

	player_visual.visible = true
	if target_floor is CanvasItem:
		(target_floor as CanvasItem).visible = true


func set_floors_above_visible_by_player(
	player: CanvasItem,
	visible: bool,
	player_visual: Node2D = null
) -> void:
	if floors.is_empty():
		refresh_floors()
	if floors.is_empty():
		return

	# ✅ z global REAL do player (parent floor + z local)
	var parent_floor := player.get_parent() as CanvasItem
	var player_global_z := (parent_floor.z_index if parent_floor != null else 0) + player.z_index

	# garante que o floor do visual nunca fique escondido
	var visual_floor: CanvasItem = null
	if player_visual != null and player_visual.get_parent() is CanvasItem:
		visual_floor = player_visual.get_parent() as CanvasItem

	for f in floors:
		var ci := f as CanvasItem

		# floors acima do player
		if ci.z_index > player_global_z:
			if visual_floor != null and ci == visual_floor:
				ci.visible = true
				continue

			ci.visible = visible
		else:
			# floor atual e abaixo: sempre visíveis
			ci.visible = true

	# garante visual sempre ligado
	if player_visual != null:
		player_visual.visible = true
		if visual_floor != null:
			visual_floor.visible = true


	#print("[FloorManager] floors_above_visible=", visible, " changed=", changed, " current_floor_z=", current_floor_z)


func show_all_floors() -> void:
	if floors.is_empty():
		refresh_floors()
	for f in floors:
		(f as CanvasItem).visible = true
	#print("[FloorManager] show_all_floors()")
	
func get_current_floor_z_for_player(player: CanvasItem) -> int:
	# usa o floor mais próximo do z do player como referência
	var idx := get_floor_index_for_global_z(player.z_index)
	if idx == -1:
		return player.z_index
	return (floors[idx] as CanvasItem).z_index
	
	
func set_floors_visible_from_z(from_floor_z: int, visible: bool, player_visual: Node2D = null) -> void:
	if floors.is_empty():
		refresh_floors()
	if floors.is_empty():
		return

	var visual_floor: CanvasItem = null
	if player_visual != null and player_visual.get_parent() is CanvasItem:
		visual_floor = player_visual.get_parent() as CanvasItem

	for f in floors:
		var ci := f as CanvasItem

		if ci.z_index >= from_floor_z:
			if visual_floor != null and ci == visual_floor:
				ci.visible = true
			else:
				ci.visible = visible
		else:
			ci.visible = true

	if player_visual != null:
		player_visual.visible = true
		if visual_floor != null:
			visual_floor.visible = true
			
