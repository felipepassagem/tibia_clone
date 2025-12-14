extends CharacterBody2D

@export var anim_path: NodePath
@onready var anim: AnimatedSprite2D = get_node_or_null(anim_path) as AnimatedSprite2D
@onready var movement: Node = find_child("Movement", true, false)


@export var player_visual_path: NodePath
@export var remote_to_visual_path: NodePath

@onready var player_visual: Node2D = get_node_or_null(player_visual_path) as Node2D
@onready var remote_to_visual: RemoteTransform2D = get_node_or_null(remote_to_visual_path) as RemoteTransform2D

@export var floor_manager_path: NodePath
@onready var floor_manager: FloorManager = get_node_or_null(floor_manager_path)

@export var fov_controller_path: NodePath
@onready var fov_controller: FovController = get_node_or_null(fov_controller_path)

const TILE_SIZE := 32
@export var tiles_per_second := 6.0
const DIAG_FACTOR := 0.5 # 1/sqrt(2) pra não ficar mais rápido na diagonal
@export var speed_mult: float = 1.0 

var is_moving := false
var target_position := Vector2.ZERO
var is_facing_up = false
var is_facing_down = false
var is_facing_left = false
var is_facing_right = false
var last_dir: Vector2 = Vector2.DOWN


# =========================
# FLOORS / COLLISION
# =========================
@export var current_floor: int = 0        # andar lógico: 0, -1, +1...
var current_floor_index: int = -1         # índice dentro de floors (ordenado por z_index)
#var floors: Array = []                    # lista de floors encontrados (Nodes)

const FLOOR_LAYER_BIT_BASE := 15          # 15 => 1<<15 (Layer 16)
const FLOOR00_Z := 1000
const FLOOR_Z_STEP := 100

# =========================
# FOV (cruz)
# =========================
const FOV_OFFSETS := [
	Vector2i(0, 0),   # centro (player)
	Vector2i(0, -1),  # norte
	Vector2i(0, 1),   # sul
	Vector2i(-1, 0),  # oeste
	Vector2i(1, 0),   # leste
]

# Cache simples para evitar toggles repetidos
var _floors_above_hidden: bool = false


# ============================================================
# READY / PROCESS
# ============================================================

func _ready() -> void:
	print("[PHY] player layer=", collision_layer, " mask=", collision_mask)

	# pega Movement 1 vez e injeta o player 1 vez
	var m: Node = find_child("Movement", true, false)
	if m != null and m.has_method("set_player"):
		m.set_player(self)
	else:
		print("[PLAYER] ERRO: Movement não encontrado ou sem set_player")

	_ensure_anim_ref()
	_anim_play_idle(last_dir)

	if anim == null:
		print("[PLAYER] AVISO: anim_path não definido ou Anim não encontrado.")
	else:
		print("[PLAYER] Anim OK -> ", anim.name)

	# alinha no grid
	global_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	target_position = global_position

	# floors (fonte única: FloorManager)
	if floor_manager == null:
		return

	floor_manager.refresh_floors()

	# sincroniza floor lógico pelo z atual do player
	_sync_floor_from_z()

	# garante visual no floor correto (y-sort) + remote_path ok
	floor_manager.ensure_visual_on_current_floor(self, player_visual, remote_to_visual)

	# aplica colisão do andar detectado + aplica mask física do andar
	var idx := floor_manager.get_floor_index_for_global_z(get_global_z())
	if idx != -1:
		var floor_ci := floor_manager.get_floors()[idx] as CanvasItem
		current_floor = floor_manager.z_to_floor_logical(floor_ci.z_index)

		floor_manager.apply_collision_for_floor(self, current_floor)
		_apply_collision_mask_for_floor(current_floor) # ✅ ESSENCIAL

	else:
		print("[PLAYER] AVISO: não consegui detectar floor inicial pelo z_index=", z_index)

	# atualiza visibilidade pelo FOV (se existir controller)
	if fov_controller != null:
		fov_controller.update_visibility(self)
		
func get_input_dir8() -> Vector2:
	var x := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	var y := int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))
	return Vector2(x, y)

func get_effective_tps() -> float:
	return tiles_per_second * speed_mult
	
func _dir8_to_cardinal(dir: Vector2) -> Vector2:
	# Se já é cardinal, mantém
	if dir == Vector2.ZERO:
		return last_dir
	if dir.x != 0 and dir.y == 0:
		return Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	if dir.y != 0 and dir.x == 0:
		return Vector2.DOWN if dir.y > 0 else Vector2.UP

	# Diagonal: escolhe eixo dominante para anim/facing
	if abs(dir.x) >= abs(dir.y):
		return Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if dir.y > 0 else Vector2.UP
func get_pixels_per_second(is_diagonal: bool) -> float:
	var px := TILE_SIZE * get_effective_tps()
	return px * (DIAG_FACTOR if is_diagonal else 1.0)
	
func _anim_play_walk(dir: Vector2) -> void:
	_ensure_anim_ref()
	if anim == null:
		return
	
	#print("[ANIM] play walk -> ", " | current=", anim.animation, " | playing=", anim.is_playing())

	var name := ""
	if dir == Vector2.DOWN:
		name = "walk_down"
	elif dir == Vector2.UP:
		name = "walk_up"
	elif dir == Vector2.LEFT:
		name = "walk_left"
	elif dir == Vector2.RIGHT:
		name = "walk_right"

	if name != "" and anim.animation != name:
		anim.play(name)


func _anim_play_idle(dir: Vector2) -> void:
	_ensure_anim_ref()
	if anim == null:
		return

	var name := ""
	if dir == Vector2.DOWN:
		name = "idle_down"
	elif dir == Vector2.UP:
		name = "idle_up"
	elif dir == Vector2.LEFT:
		name = "idle_left"
	elif dir == Vector2.RIGHT:
		name = "idle_right"

	if name != "" and anim.animation != name:
		anim.play(name)
func _ensure_anim_ref() -> void:
	if anim != null and is_instance_valid(anim):
		return

	if player_visual == null:
		return

	anim = player_visual.get_node_or_null("Anim") as AnimatedSprite2D
	if anim == null:
		print("[ANIM] ERRO: não achei PlayerVisual/Anim")
	else:
		print("[ANIM] OK: usando Anim do PlayerVisual -> ", anim.get_path())

func _physics_process(delta: float) -> void:
	if movement != null and movement.has_method("tick_physics"):
		movement.tick_physics(delta)


func set_facing(dir: Vector2) -> void:
	# reset
	is_facing_up = false
	is_facing_down = false
	is_facing_left = false
	is_facing_right = false

	last_dir = dir

	match dir:
		Vector2.UP: is_facing_up = true
		Vector2.DOWN: is_facing_down = true
		Vector2.LEFT: is_facing_left = true
		Vector2.RIGHT: is_facing_right = true

		
func _process(_delta):
	if is_moving:
		return

	if Input.is_action_pressed("ui_shift"):
		if Input.is_action_just_pressed("ui_up"):
			rotate_in_place(Vector2.UP)
		elif Input.is_action_just_pressed("ui_down"):
			rotate_in_place(Vector2.DOWN)
		elif Input.is_action_just_pressed("ui_left"):
			rotate_in_place(Vector2.LEFT)
		elif Input.is_action_just_pressed("ui_right"):
			rotate_in_place(Vector2.RIGHT)
			
func _get_floors() -> Array:
	if floor_manager == null:
		#print("[Player] ERRO: FloorManager não definido")
		return []
	return floor_manager.get_floors()
# ============================================================
# INPUT
# ============================================================
func rotate_in_place(dir: Vector2):
	if dir == last_dir:
		return

	# reset flags
	is_facing_up = false
	is_facing_down = false
	is_facing_left = false
	is_facing_right = false
	
	last_dir = dir
	set_facing(dir)

	match dir:
		Vector2.UP:
			is_facing_up = true
			anim.play("idle_up")
		Vector2.DOWN:
			is_facing_down = true
			anim.play("idle_down")
		Vector2.LEFT:
			is_facing_left = true
			anim.play("idle_left")
		Vector2.RIGHT:
			is_facing_right = true
			anim.play("idle_right")
		
	
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_P:
				_debug()
			KEY_PAGEDOWN:
				print("[INPUT] PgDown -> descer andar")
				change_floor(-1)
			KEY_PAGEUP:
				print("[INPUT] PgUp -> subir andar")
				change_floor(+1)


# ============================================================
# MOVIMENTO
# ============================================================
#


func _cell_is_blocked(tm: Node, cell: Vector2i) -> bool:
	var td := _get_tiledata(tm, cell)
	
	if td == null:
		return false # sem tile/sem data -> não bloqueia (ajuste se quiser)

	# Se existir a flag is_walkable e ela for false, bloqueia
	if td.get_custom_data("is_walkable") != null and td.get_custom_data("is_walkable") == false:
		return true

	# Bloqueios clássicos
	if td.get_custom_data("is_wall") == true:
		return true
	if td.get_custom_data("is_window") == true:
		return true
	if td.get_custom_data("is_water") == true:
		return true

	return false


func _world_pos_is_blocked(world_pos: Vector2) -> bool:
	var idx := _get_current_floor_index()
	if idx == -1:
		return false

	var floors := _get_floors()
	if idx < 0 or idx >= floors.size():
		return false

	var floor_node: Node = floors[idx] as Node
	var tms := _get_tilemaps_in_floor(floor_node)

	for tm in tms:
		var tm2d := tm as Node2D
		var local_pos := tm2d.to_local(world_pos)
		var cell: Vector2i = tm.local_to_map(local_pos)

		if _cell_is_blocked(tm, cell):
			return true

	return false


func _can_step(dir: Vector2) -> bool:
	
	var dest := global_position + (dir * TILE_SIZE)
	print("[STEP] dir=", dir, " dest=", dest, " blocked_dest=", _world_pos_is_blocked(dest))
	# Regra 1: se destino bloqueado -> não anda
	if _world_pos_is_blocked(dest):
		return false

	# Regra 2 (anti corner-cutting): só bloqueia diagonal se OS DOIS lados ortogonais estiverem bloqueados
	if dir.x != 0 and dir.y != 0:
		var side_x := global_position + Vector2(dir.x * TILE_SIZE, 0)
		var side_y := global_position + Vector2(0, dir.y * TILE_SIZE)

		var bx := _world_pos_is_blocked(side_x)
		var by := _world_pos_is_blocked(side_y)

		# Se ambos bloqueados, impede “passar pelo canto”
		if bx and by:
			return false

	return true

# ============================================================
# FLOORS DISCOVERY / CURRENT FLOOR
# ============================================================






func _sync_floor_from_z() -> void:
	var idx := _get_current_floor_index()
	if idx == -1:
		return
	var floors := _get_floors()

	var f := floors[idx] as CanvasItem
	if floor_manager == null:
		return
	current_floor = floor_manager.z_to_floor_logical(f.z_index)
	current_floor_index = idx

	print("[_sync_floor_from_z] floor=", f.name, " z_index=", f.z_index, " => current_floor=", current_floor)


# ============================================================
# TILEMAP HELPERS (para FOV)
# ============================================================

func _get_tilemaps_in_floor(floor_node: Node) -> Array:
	var out: Array = []
	for ch in floor_node.get_children():
		if ch is TileMap:
			out.append(ch)
		elif ch.has_method("get_cell_source_id") and ch.has_method("local_to_map"):
			out.append(ch) # TileMapLayer node
	return out


func _cell_has_any_tile(tm: Node, cell: Vector2i) -> bool:
	if tm is TileMap:
		return (tm as TileMap).get_cell_source_id(0, cell) != -1
	return tm.get_cell_source_id(cell) != -1


# ============================================================
# FOV DETECTION (qualquer tile acima)
# ============================================================

func fov_has_any_tile_above() -> bool:
	var floors := _get_floors()
	if floors.is_empty():
		return false

	var idx := _get_current_floor_index()
	if idx == -1:
		return false

	var player_floor := floors[idx] as CanvasItem
	var player_z: int = player_floor.z_index

	# 1) Filtra o FOV pelo is_wall do ANDAR ATUAL
	var fov_offsets := get_filtered_fov_offsets_by_walls()

	# 2) Procura tiles acima APENAS nesses offsets permitidos
	for f in floors:
		var floor_ci := f as CanvasItem
		if floor_ci.z_index <= player_z:
			continue

		var tms := _get_tilemaps_in_floor(floor_ci)
		for tm in tms:
			var center := _center_cell_for_tm(tm)

			for off in fov_offsets:
				var cell: Vector2i = center + off
				if _cell_has_any_tile(tm, cell):
					print("[FOV_HAS] HIT -> floor=", floor_ci.name, " tm=", tm.name, " off=", off, " cell=", cell)
					return true

	return false



# ============================================================
# VISIBILITY TOGGLE (modo simplificado: “olho”)
# ============================================================

func _set_floor_children_visible(floor_node: Node, visible: bool) -> void:
	for ch in floor_node.get_children():
		# NÃO esconder o player (ele é filho do floor)
		if ch == self:
			continue
		if ch is CanvasItem:
			(ch as CanvasItem).visible = visible



func update_fov_floor_visibility() -> void:
	if floor_manager == null:
		return

	var has_above := fov_has_any_tile_above() # continua no Player por enquanto

	# seu z_index do PlayerRoot é o "z global" que estamos usando como referência de andar
	var current_z: int = z_index

	# Regra: se tem qualquer tile acima no FOV -> esconder floors acima
	
	floor_manager.set_floors_above_visible_by_player(self, not has_above, player_visual)

	print("[VIS] has_above=", has_above, " current_z=", current_z)



# ============================================================
# COLLISION LAYERS
# ============================================================


func _cell_is_wall(tm: Node, cell: Vector2i) -> bool:
	var td := _get_tiledata(tm, cell)
	if td == null:
		return false
	return td.get_custom_data("is_wall") == true
	
func debug_center_cells_current_floor() -> void:
	var idx := _get_current_floor_index()
	if idx == -1:
		print("[FOV_WALL] sem floor atual")
		return
		
	var floors := _get_floors()
	if idx < 0 or idx >= floors.size():
		return
		
	var floor_node: Node = floors[idx] as Node
	var tms := _get_tilemaps_in_floor(floor_node)

	print("[FOV_WALL] ---- center_cell por TileMap (andar atual) ----")
	var first: Vector2i = Vector2i(999999, 999999)
	var first_name := ""
	for tm in tms:
		var c := _center_cell_for_tm(tm)
		print("  tm=", tm.name, " center=", c)
		if first_name == "":
			first = c
			first_name = tm.name
		else:
			if c != first:
				print("  [AVISO] center_cell diferente de ", first_name, " -> layers desalinhadas!")
	print("[FOV_WALL] ---------------------------------------------")

func _direction_blocked_by_wall(off: Vector2i) -> bool:
	# off é um dos 4 (N/S/L/O). Centro nunca entra aqui.
	var idx := _get_current_floor_index()
	if idx == -1:
		return false
	var floors := _get_floors()
	if idx < 0 or idx >= floors.size():
		return false
	var floor_node: Node = floors[idx] as Node
	var tms := _get_tilemaps_in_floor(floor_node)

	for tm in tms:
		# calcula a célula do player nesse tilemap específico (mais robusto)
		var tm2d := tm as Node2D
		var local_pos: Vector2 = tm2d.to_local(global_position)
		var center_cell: Vector2i = tm.local_to_map(local_pos)

		var cell: Vector2i = center_cell + off
		if _cell_is_wall(tm, cell):
			print("[FOV_WALL] BLOQUEADO off=", off, " por tm=", tm.name, " cell=", cell)
			return true

	return false
func _center_cell_for_tm(tm: Node) -> Vector2i:
	# Calcula o cell do player NAQUELE tilemap/layer específico
	# (evita erro de desalinhamento entre nodes)
	var tm2d := tm as Node2D
	var local_pos: Vector2 = tm2d.to_local(global_position)
	return tm.local_to_map(local_pos)


func _get_tiledata(tm: Node, cell: Vector2i) -> TileData:
	if tm is TileMap:
		return (tm as TileMap).get_cell_tile_data(0, cell)
	# TileMapLayer node
	return tm.get_cell_tile_data(cell)




# ============================================================
# CHANGE FLOOR (PgUp / PgDown)
# ============================================================

func change_floor(delta: int) -> void:
	if floor_manager == null:
		return

	# tenta mudar de andar (FloorManager ajusta z_index/parent/visual/remote)
	var new_logical := floor_manager.change_floor_for_player(self, delta, player_visual, remote_to_visual)
	if new_logical == -1:
		return

	# fonte única de verdade: recalcula floor atual pelo z_index após a troca
	_sync_floor_from_z()

	# aplica colisão física e regras do andar atual
	_apply_collision_mask_for_floor(current_floor)
	floor_manager.apply_collision_for_floor(self, current_floor)

	# mantém seu fluxo atual (visibilidade/FOV)
	update_fov_floor_visibility()
	if fov_controller != null:
		fov_controller.update_visibility(self)

	print("[FLOOR] changed -> current_floor=", current_floor, " z=", z_index, " mask_layers=", _bits_to_layers(collision_mask))

	

func get_global_z() -> int:
	var pf := get_parent() as CanvasItem
	return (pf.z_index if pf != null else 0) + z_index
	
	
func _apply_collision_mask_for_floor(floor: int) -> void:
	# Floor 0 -> Collision Layer 16
	# Floor -1 -> Collision Layer 15
	# Floor +1 -> Collision Layer 17 ...
	var layer_num: int = 16 + floor  # regra do seu projeto

	# clamp defensivo (layers válidas 1..32)
	layer_num = clamp(layer_num, 1, 32)

	# Godot: Layer 1 = bit 0, Layer 16 = bit 15
	collision_mask = (1 << (layer_num - 1))

	print("[PHY] apply mask | floor=", floor, " layer_num=", layer_num, " mask=", collision_mask)

	
func get_filtered_fov_offsets_by_walls() -> Array:
	var out: Array = []
	out.append(Vector2i(0, 0)) # centro sempre

	var idx := _get_current_floor_index()
	if idx == -1:
		print("[FOV_WALL] floor atual indefinido -> usando só centro")
		return out
		
	var floors := _get_floors()
	if idx < 0 or idx >= floors.size():
		print("[FOV_WALL] idx fora do range:", idx, " size=", floors.size())
		return []
		 
	var floor_node: Node = floors[idx] as Node
	var tms := _get_tilemaps_in_floor(floor_node)

	# Direções
	var dirs := [
		Vector2i(0, -1),
		Vector2i(0,  1),
		Vector2i(-1, 0),
		Vector2i(1,  0)
	]

	for off in dirs:
		var blocked := false

		for tm in tms:
			var center := _center_cell_for_tm(tm)
			var cell: Vector2i = center + off

			if _cell_is_wall(tm, cell):
				blocked = true
				print("[FOV_WALL] BLOQUEOU off=", off, " por tm=", tm.name, " cell=", cell)
				break

		if not blocked:
			out.append(off)
		else:
			print("[FOV_WALL] removendo braço do FOV:", off)

	print("[FOV_WALL] offsets finais:", out)
	return out


	
func _get_current_floor_index() -> int:
	if floor_manager == null:
		return -1
	return floor_manager.get_floor_index_for_global_z(get_global_z())




# ============================================================
# DEBUG
# ============================================================
func _bits_to_layers(bits: int) -> String:
	var arr: Array[String] = []
	for i in range(32):
		if (bits & (1 << i)) != 0:
			arr.append(str(i + 1)) # layer 1..32
	return "[" + ", ".join(arr) + "]"

func _bits_to_bin(bits: int) -> String:
	var s := ""
	for i in range(31, -1, -1):
		s += "1" if (bits & (1 << i)) != 0 else "0"
		if i % 4 == 0 and i != 0:
			s += "_"
	return s

func _debug() -> void:
	var idx := _get_current_floor_index()
	var floor_name := "?"
	var floor_z := 0
	if floor_manager != null:
		var floors := floor_manager.get_floors()
		if idx >= 0 and idx < floors.size():
			var ci := floors[idx] as CanvasItem
			floor_name = ci.name
			floor_z = ci.z_index

	print("\n================ PLAYER DEBUG ================")
	print("Path: ", get_path())
	print("Global pos: ", global_position, " | Target: ", target_position, " | is_moving: ", is_moving)
	print("z_index (player): ", z_index, " | current_floor(logical): ", current_floor,
		  " | current_floor_index: ", idx, " | floor_node: ", floor_name, " | floor_z: ", floor_z)

	print("Facing last_dir: ", last_dir,
		  " | U:", is_facing_up, " D:", is_facing_down, " L:", is_facing_left, " R:", is_facing_right)

	print("Collision LAYER int: ", collision_layer,
		  " | layers: ", _bits_to_layers(collision_layer),
		  " | bin: ", _bits_to_bin(collision_layer))

	print("Collision MASK  int: ", collision_mask,
		  " | layers: ", _bits_to_layers(collision_mask),
		  " | bin: ", _bits_to_bin(collision_mask))

	print("================================================\n")
