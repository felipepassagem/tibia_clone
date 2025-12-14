#extends CharacterBody2D
#
## ============================================================
## CONSTANTES GLOBAIS
## ============================================================
#const TILE_SIZE := 32
#const FLOOR_BASE := 1000
#const FLOOR_STEP := 100
#
## FATORES PARA Y-SORT (Ajustar se necessário para a profundidade)
#const Y_SORT_FACTOR := 2.0
#const X_SORT_FACTOR := 0.25
#
## FLAGS DE COLISÃO (Devem estar configuradas no Custom Data do seu TileSet)
#const BLOCK_FLAGS := ["is_wall", "is_window", "is_water"]
#const WALK_FLAGS := ["is_walkable"]
#
## ============================================================
## PROPRIEDADES DE MOVIMENTO E ESTADO
## ============================================================
## MOVIMENTO
#@export var base_speed: float = 4.0 # Velocidade em SQM por segundo
#@export var speed_multiplier: float = 1.0 # Multiplicador de velocidade
#
## FLOORS (Andares)
#@export var start_floor_name: String = "Floor00"
#var floors_root: Node2D
#var current_floor: Node2D
#
## ANIMAÇÃO E ESTADO
#@onready var anim: AnimatedSprite2D = $Anim
#@onready var editor_z: int = z_index
#var last_dir := Vector2.DOWN
#
#var is_moving := false
#var target_position := Vector2.ZERO
#
## ============================================================
## READY
## ============================================================
#func _ready():
	## Arredonda a posição inicial para alinhar ao grid (se não estiver alinhada)
	#target_position = global_position.snapped(Vector2(TILE_SIZE, TILE_SIZE))
	#global_position = target_position
#
	#floors_root = get_tree().current_scene.get_node_or_null("Floors") as Node2D
	#if floors_root == null:
		#push_error("❌ Player: nó 'Floors' não encontrado.")
		#set_process(false)
		#set_physics_process(false)
		#return
#
	#current_floor = floors_root.get_node_or_null(start_floor_name)
	#if current_floor == null:
		#push_error("❌ Player: Floor '%s' não encontrado." % start_floor_name)
		#set_process(false)
		#set_physics_process(false)
		#return
#
	#print("✅ Player entrou no floor: ", current_floor.name)
	#
	## Mover player para o YSort correto na inicialização
	#var ysort := current_floor.get_node_or_null("YSort")
	#if ysort and get_parent() != ysort:
		#if self.get_parent():
			#self.get_parent().remove_child(self)
		#ysort.add_child(self)
	#
	#_update_z()
#
## ============================================================
## LOOP PRINCIPAL
## ============================================================
#func _physics_process(delta: float) -> void:
	#_handle_floor_change()
	#_handle_input()
	#_move(delta)
	#_update_z()
#
## ============================================================
## MUDAR DE ANDAR
## ============================================================
#func _handle_floor_change() -> void:
	#if is_moving: return # Impede mudança enquanto move
#
	#if Input.is_action_just_pressed("ui_page_up"):
		#_change_floor(1)
	#elif Input.is_action_just_pressed("ui_page_down"):
		#_change_floor(-1)
#
#func _change_floor(offset: int):
	#var idx := _get_floor_index(current_floor.name)
	#var new_name := _get_floor_name_from_index(idx + offset)
	#var new_floor := floors_root.get_node_or_null(new_name)
#
	#if new_floor == null:
		#print("⚠ Floor inexistente: ", new_name)
		#return
#
	#print("🔄 Mudando para floor:", new_name)
	#
	#is_moving = false
	#global_position = target_position
	#
	#current_floor = new_floor
	#start_floor_name = new_name
#
	## Mover player para o YSort correto
	#var ysort := new_floor.get_node_or_null("YSort")
	#if ysort:
		#if self.get_parent():
			#self.get_parent().remove_child(self)
		#ysort.add_child(self)
#
	#_update_z()
	## floors_root.update_visibility_fov(start_floor_name, _get_player_cell())
#
#func _get_floor_index(n: String) -> int:
	#if n.begins_with("FloorB"): 
		#return -int(n.substr(6))
	#return int(n.substr(5))
#
#func _get_floor_name_from_index(idx: int) -> String:
	#if idx < 0:
		#return "FloorB%02d" % abs(idx)
	#return "Floor%02d" % idx
#
## ============================================================
## INPUT DO JOGADOR
## ============================================================
#func _handle_input() -> void:
	#if is_moving:
		#return
#
	#var input_x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	#var input_y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	#
	#var dir := Vector2(input_x, input_y)
	#
	#if dir == Vector2.ZERO:
		#_play_idle_anim()
		#return
#
	#dir = dir.sign()
	#
	## >>> ROTACIONAR APENAS (Mantém a lógica de SHIFT)
	#if Input.is_key_pressed(KEY_SHIFT):
		#_rotate_facing(dir)
		#return
#
	## >>> COLISÃO
	#if not _can_walk(dir):
		#print("🚫 BLOQUEADO na direção:", dir)
		#_rotate_facing(dir)
		#return
#
	## >>> MOVIMENTO
	#last_dir = dir
	#_rotate_facing(dir)
	#_play_walk_anim()
#
	#target_position = global_position + dir * TILE_SIZE
	#is_moving = true
	#print("▶ Movimento iniciado →", target_position)
#
## ============================================================
## MOVIMENTO E ANIMAÇÃO
## ============================================================
#func _is_diagonal(v: Vector2) -> bool:
	#return abs(v.x) > 0.0 and abs(v.y) > 0.0
#
## CORRIGIDO: Adicionada tipagem para resolver erro de inferência
#func _move(delta):
	#if not is_moving:
		#return
#
	#var dir_vec := (target_position - global_position)
	#
	## Tipagem float explícita para evitar o erro de inferência
	#var speed: float = base_speed * speed_multiplier * TILE_SIZE 
	#
	#if _is_diagonal(dir_vec):
		#speed *= 0.7071
#
	## Tipagem float explícita
	#var distance_to_travel: float = speed * delta
	#
	#if dir_vec.length_squared() <= (distance_to_travel * distance_to_travel):
		#global_position = target_position
		#is_moving = false
		#print("■ Chegou no destino:", global_position)
		#_play_idle_anim()
	#else:
		#global_position += dir_vec.normalized() * distance_to_travel
		#
	## floors_root.update_visibility_fov(start_floor_name, _get_player_cell())
#
## -----------------
## Animações
## -----------------
#func _rotate_facing(dir: Vector2):
	#if abs(dir.x) > abs(dir.y):
		#if dir.x > 0: anim.play("idle_right")
		#else: anim.play("idle_left")
	#else:
		#if dir.y > 0: anim.play("idle_down")
		#else: anim.play("idle_up")
	#
	#last_dir = dir
#
#func _play_walk_anim():
	#if abs(last_dir.x) > abs(last_dir.y):
		#if last_dir.x > 0: anim.play("walk_right")
		#else: anim.play("walk_left")
	#else:
		#if last_dir.y > 0: anim.play("walk_down")
		#else: anim.play("walk_up")
#
#func _play_idle_anim():
	#if abs(last_dir.x) > abs(last_dir.y):
		#if last_dir.x > 0: anim.play("idle_right")
		#else: anim.play("idle_left")
	#else:
		#if last_dir.y > 0: anim.play("idle_down")
		#else: anim.play("idle_up")
#
## ============================================================
## COLISÃO / WALKABLE CHECK
## ============================================================
#func _can_walk(dir: Vector2) -> bool:
	#if current_floor == null:
		#return false
#
	#var world := global_position + dir * TILE_SIZE
	#var flags: Array[String] = []
	#var has_tile := false
#
	## CORRIGIDO: O root de colisão é o Floor00 para incluir Walls (irmão do YSort)
	#var collision_root = current_floor 
#
	#print("\n=== CHECK WALK ===")
	#print("Checando destino world:", world)
	#print("Floor:", current_floor.name, "  Root:", collision_root.name)
#
	## Itera sobre todos os filhos de Floor00
	#for child in collision_root.get_children():
		## Verifica se o child é um nó TileMap (ou um nó TileMapLayer interno)
		#if child.has_method("get_cell_source_id"):
			## Acessa o nó TileMap (GroundBase ou Walls, por exemplo)
			#var tm = child
			#
			## As coordenadas de TileMap funcionam melhor com global_position ou Vector2i
			#var local: Vector2 = tm.to_local(world)
			#var cell: Vector2i = tm.local_to_map(local)
			#var src_id: int = tm.get_cell_source_id(cell)
			#var data: TileData = tm.get_cell_tile_data(cell)
#
			#if src_id == -1 and data == null:
				#continue
#
			#has_tile = true
			#print("  -> Layer:", tm.name, "cell:", cell)
#
			#if data != null:
				#for f in BLOCK_FLAGS + WALK_FLAGS:
					#if data.has_custom_data(f) and data.get_custom_data(f) == true:
						#if f not in flags:
							#flags.append(f)
							#print("     Flag:", f)
#
	## ---------------------------------------
	## Regras de Colisão
	## ---------------------------------------
#
	## 1. Se houver uma flag de bloqueio, bloqueia
	#for f in BLOCK_FLAGS:
		#if f in flags:
			#print("Flag de bloqueio '%s' encontrada → BLOQUEADO" % f)
			#return false
#
	## 2. Se não houver bloqueio, e houver tile:
	#if has_tile:
		## Se tiver walkable, pode andar (reforço)
		#for f in WALK_FLAGS:
			#if f in flags:
				#print("Walkable encontrado → pode andar")
				#return true
		#
		## Se tiver tile, mas sem flags (ex: chão simples sem flag customizada),
		## E não tem bloqueio, então PODE ANDAR
		#print("Tile sem flags relevantes, mas sem bloqueio → PODE ANDAR")
		#return true
#
	## 3. Se não tiver tile nenhum (fora do mapa), bloqueia por segurança
	#if not has_tile:
		#print("Nenhum tile encontrado (fora do mapa) → BLOQUEADO")
		#return false
		#
	#return false # Padrão de segurança
## ============================================================
## Z INDEX (Renderização de Profundidade)
## ============================================================
#func _update_z():
	#var idx := _get_floor_index(start_floor_name)
	#var base_z := FLOOR_BASE + idx * FLOOR_STEP
	#
	#var tile_y := global_position.y / TILE_SIZE
	#var tile_x := global_position.x / TILE_SIZE
	#
	#var dyn_z := int((tile_y + 0.5) * Y_SORT_FACTOR + tile_x * X_SORT_FACTOR)
#
	#z_as_relative = false
	#z_index = base_z + editor_z + dyn_z
	#
## ============================================================
## HELPERS
## ============================================================
#func _get_player_cell() -> Vector2i:
	#return Vector2i(
		#int(global_position.x / TILE_SIZE),
		#int(global_position.y / TILE_SIZE)
	#)
