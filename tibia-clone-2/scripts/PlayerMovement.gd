extends Node
class_name PlayerMovement

var player: CharacterBody2D

func set_player(p: CharacterBody2D) -> void:
	player = p
	
func _ready() -> void:
	#player = get_parent() as CharacterBody2D
	if player == null:
		player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D
	print("[MOVEMENT] player resolved =", player)

func tick_physics(delta: float) -> void:
	if player == null:
		return
	#if player == null:
		#print("[MOVEMENT] player NULL (parent não é CharacterBody2D)")
		#return

	# Se Shift está sendo usado para rotacionar, não anda (mantém seu comportamento)
	if Input.is_action_pressed("ui_shift"):
		player.velocity = Vector2.ZERO
		player.move_and_slide()
		return

	# Se está em movimento, continua andando até o tile alvo
	if player.is_moving:
		_move_towards_target(delta)
		return

	# Se não está em movimento, tenta iniciar um novo passo (agora com diagonal)
	var dir := _get_input_direction_8()
	#print("[MOVEMENT] input dir =", dir)
	if dir != Vector2.ZERO:
		_start_step(dir)
		
#func _physics_process(delta: float) -> void:
	#var m = get_node_or_null("Movement")
	#if m == null:
		##print("[PLAYER] Movement NULL no physics")
		#return

	#if not m.has_method("tick_physics"):
		##print("[PLAYER] Movement sem tick_physics. Script errado/anexado?")
		#return
#
	#m.tick_physics(delta)

# ----------------------------
# INPUT DIR (8 direções)
# ----------------------------
func _get_input_direction_8() -> Vector2:
	var x := int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	var y := int(Input.is_action_pressed("ui_down"))  - int(Input.is_action_pressed("ui_up"))

	var dir := Vector2(x, y)

	# normaliza pra grid (-1, 0, 1)
	if dir.x != 0:
		dir.x = sign(dir.x)
	if dir.y != 0:
		dir.y = sign(dir.y)

	return dir

# ----------------------------
# START STEP
# ----------------------------
func _start_step(dir: Vector2) -> void:
	print("[MOVEMENT] start_step dir =", dir)

	var motion: Vector2 = dir * float(player.TILE_SIZE)

	# ✅ movimento deve respeitar colisão física
	if player.test_move(player.global_transform, motion):
		return

	player.target_position = player.global_position + motion

	var face_dir := dir
	if player.has_method("_dir8_to_cardinal"):
		face_dir = player._dir8_to_cardinal(dir)
	else:
		face_dir = _dir8_to_cardinal_local(dir)

	player.last_dir = face_dir
	if player.has_method("set_facing"):
		player.set_facing(face_dir)

	if player.has_method("_anim_play_walk"):
		player._anim_play_walk(face_dir)

	player.is_moving = true


# ----------------------------
# MOVE TOWARDS TARGET
# ----------------------------
func _move_towards_target(delta: float) -> void:
	print("[MOVEMENT] moving | pos =", player.global_position, " -> ", player.target_position)
	var to_target: Vector2 = player.target_position - player.global_position
	var is_diagonal: bool = (to_target.x != 0.0 and to_target.y != 0.0)

	var step_px: float
	if player.has_method("get_pixels_per_second"):
		step_px = player.get_pixels_per_second(is_diagonal) * delta
	else:
		var tps: float = player.tiles_per_second * player.speed_mult
		var base: float = float(player.TILE_SIZE) * tps
		step_px = base * (player.DIAG_FACTOR if is_diagonal else 1.0) * delta

	if to_target.length() <= step_px:
		player.global_position = player.target_position
		player.is_moving = false

		if player.has_method("_anim_play_idle"):
			player._anim_play_idle(player.last_dir)

		#if player.fov_controller != null:
			#player.fov_controller.update_visibility(player)

		return  # ✅ obrigatório

	player.global_position += to_target.normalized() * step_px


# ----------------------------
# fallback local (caso você remova do Player)
# ----------------------------
func _dir8_to_cardinal_local(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.DOWN

	if dir.x != 0 and dir.y == 0:
		return Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	if dir.y != 0 and dir.x == 0:
		return Vector2.DOWN if dir.y > 0 else Vector2.UP

	# diagonal -> eixo dominante
	if abs(dir.x) >= abs(dir.y):
		return Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	else:
		return Vector2.DOWN if dir.y > 0 else Vector2.UP
