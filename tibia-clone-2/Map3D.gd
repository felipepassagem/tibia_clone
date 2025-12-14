extends Node2D
# class_name Map3D

# Nome dos floors na ordem lógica do Z
# índice 0 → FloorB01 (baixo)
# índice 1 → Floor00  (nível 0)
# índice 2 → Floor01  (cima)
var floor_names: Array[String] = [
	"FloorB01",
	"Floor00",
	"Floor01",
]

# Tamanho máximo do mapa lógico (em células / SQMs)
@export var width: int = 128
@export var height: int = 128

# map[z][x][y] = Dictionary com informações da célula
var map: Array = []


func _ready() -> void:
	_init_empty_map()


func _init_empty_map() -> void:
	map.resize(floor_names.size())

	for z in range(floor_names.size()):
		map[z] = []
		map[z].resize(width)
		for x in range(width):
			map[z][x] = []
			map[z][x].resize(height)
			for y in range(height):
				map[z][x][y] = {
					"ground_id": -1,
					"object_id": -1,
					"flags": {
						"walkable": true,
						"stairs_up": false,
						"stairs_down": false,
					}
				}


# ---------- HELPERS BÁSICOS ----------

func get_floor_index(floor_name: String) -> int:
	# Retorna 0,1,2... ou -1 se não achar
	return floor_names.find(floor_name)


func is_inside(z: int, x: int, y: int) -> bool:
	if z < 0 or z >= floor_names.size():
		return false
	if x < 0 or x >= width or y < 0 or y >= height:
		return false
	return true


func get_cell(z: int, x: int, y: int) -> Dictionary:
	if not is_inside(z, x, y):
		return {}
	return map[z][x][y]


func set_cell(z: int, x: int, y: int, data: Dictionary) -> void:
	if not is_inside(z, x, y):
		return
	map[z][x][y] = data


func get_flags(z: int, x: int, y: int) -> Dictionary:
	if not is_inside(z, x, y):
		return {}
	return map[z][x][y]["flags"]


func set_flag(z: int, x: int, y: int, flag_name: String, value: bool) -> void:
	if not is_inside(z, x, y):
		return
	map[z][x][y]["flags"][flag_name] = value


func is_walkable(z: int, x: int, y: int) -> bool:
	if not is_inside(z, x, y):
		return false
	return map[z][x][y]["flags"]["walkable"]


func set_walkable(z: int, x: int, y: int, value: bool) -> void:
	if not is_inside(z, x, y):
		return
	map[z][x][y]["flags"]["walkable"] = value


# ---------- CARREGAR FLAGS A PARTIR DOS FLOORS / TILEMAPS ----------

func load_from_floors(floors_root: Node2D) -> void:
	# reseta o mapa lógico
	_init_empty_map()

	var child_count: int = floors_root.get_child_count()

	for i in range(child_count):
		var floor_node := floors_root.get_child(i) as Node2D
		if floor_node == null:
			continue

		var floor_name: String = floor_node.name

		# descobre o z lógico correto a partir da lista floor_names
		var z: int = get_floor_index(floor_name)
		if z == -1:
			continue  # esse floor não está na lista floor_names

		for child in floor_node.get_children():
			if child is TileMapLayer:
				var tm := child as TileMapLayer
				for cell in tm.get_used_cells():
					_read_tile_flags_from_tilemap(z, tm, cell)


func _read_tile_flags_from_tilemap(z: int, tilemap: TileMapLayer, cell: Vector2i) -> void:
	if not is_inside(z, cell.x, cell.y):
		return

	var tile_data := tilemap.get_cell_tile_data(cell)
	if tile_data == null:
		return

	# Aqui você pode ler custom_data do tileset e popular flags:
	# ex:
	# if tile_data.has_custom_data("walkable"):
	#     var w = tile_data.get_custom_data("walkable")
	#     if w is bool:
	#         set_walkable(z, cell.x, cell.y, w)
