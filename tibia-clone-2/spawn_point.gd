extends Node

@export var player_scene: PackedScene
@export var spawn_tile: Vector2i = Vector2i(10, 10)
@export var spawn_floor_z: int = 0
@export var tile_size: int = 32

@export var entities_path: NodePath
@onready var entities: Node2D = get_node(entities_path)

func _ready() -> void:
	spawn_player()

func spawn_player() -> void:
	if player_scene == null:
		push_error("Player scene não definida")
		return

	var player = player_scene.instantiate()
	entities.add_child(player)

	# posição inicial (por enquanto só x/y)
	player.global_position = Vector2(
		spawn_tile.x * tile_size,
		spawn_tile.y * tile_size
	)

	# floor lógico (guardamos, mesmo que ainda não use)
	if player.has_variable("current_floor"):
		player.current_floor = spawn_floor_z

	print("[SPAWN] Player em tile=", spawn_tile, " floor=", spawn_floor_z)
