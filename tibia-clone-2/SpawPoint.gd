extends Node
class_name SpawnPoint

@export var player_path: NodePath               # arraste o Player da cena aqui (recomendado)
@export var floor_manager_path: NodePath        # arraste o FloorManager aqui

@export var spawn_floor_logical: int = -1        # 0, 1, -1...
@export var spawn_cell: Vector2i = Vector2i(20, 12)

@export var tile_size: int = 32                 # igual ao do Player

func _ready() -> void:
	call_deferred("_spawn_now")

func _spawn_now() -> void:
	var player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D
	if player == null:
		player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D
	if player == null:
		print("[SPAWN] Player não encontrado")
		return

	var fm: FloorManager = get_node_or_null(floor_manager_path) as FloorManager
	if fm == null:
		fm = get_tree().current_scene.find_child("FloorManager", true, false) as FloorManager
	if fm == null:
		print("[SPAWN] FloorManager não encontrado")
		return

	# garante lista de floors carregada
	fm.refresh_floors()
	var floors: Array = fm.get_floors()
	if floors.is_empty():
		print("[SPAWN] floors vazio")
		return

	# acha o floor_node pelo logical
	var target_floor_node: Node2D = null
	for f in floors:
		var ci := f as CanvasItem
		if ci != null and fm.z_to_floor_logical(ci.z_index) == spawn_floor_logical:
			target_floor_node = ci as Node2D
			break

	if target_floor_node == null:
		print("[SPAWN] floor logical não encontrado:", spawn_floor_logical)
		return

	# converte cell -> world usando o offset real do floor (position do FloorXX)
	var local_pos := Vector2(spawn_cell.x * tile_size, spawn_cell.y * tile_size)
	var world_pos := target_floor_node.to_global(local_pos)

	# aplica no player
	player.global_position = world_pos.snapped(Vector2(tile_size, tile_size))
	player.target_position = player.global_position
	player.is_moving = false

	# padroniza z_index do player para o z do floor (se você usa isso como referência)
	player.z_index = (target_floor_node as CanvasItem).z_index

	# atualiza floor lógico no player (se existir)
	player.set("current_floor", spawn_floor_logical)

	# colisão do andar + move o PlayerVisual pro floor correto
	fm.apply_collision_for_floor(player, spawn_floor_logical)

	var pv: Node2D = player.get("player_visual") as Node2D
	var rt: RemoteTransform2D = player.get("remote_to_visual") as RemoteTransform2D
	fm.ensure_visual_on_current_floor(player, pv, rt)

	print("[SPAWN] ok -> floor=", spawn_floor_logical, " cell=", spawn_cell, " world=", player.global_position)
