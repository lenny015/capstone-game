extends Node2D

var domino_pool: Array = []

const MAX_STACK_LAYERS = 8
const LAYER_OFFSET = Vector2(1.5, 1.5)

var _stack_layers: Array = []
var _pool_size_at_start: int = 0

@onready var main_sprite: Sprite2D = $Sprite2D

@onready var player_hand = get_node("../PlayerHand")
@onready var domino_manager = get_node("../DominoManager")

func _ready():
	if GameState.multiplayer_mode:
		_ready_multiplayer()
	else:
		_ready_singleplayer()

func _ready_singleplayer():
	_generate_all_dominoes()
	GameState.start_game(domino_pool.duplicate())
	for values in GameState.player_hand_data:
		domino_pool.erase(values)
	for values in GameState.opponent_hand_data:
		domino_pool.erase(values)
	call_deferred("_spawn_player_hand")
	call_deferred("_emit_opponent_hand_changed")
	call_deferred("_init_stack")

func _emit_opponent_hand_changed():
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

func _spawn_player_hand():
	for values in GameState.player_hand_data:
		player_hand.add_domino_to_hand_from_values(values[0], values[1])

func _ready_multiplayer():
	print("[Boneyard] _ready_multiplayer — is_host: ", GameState.is_host)
	if GameState.is_host:
		print("[Boneyard] taking HOST branch")
		_generate_all_dominoes()
		GameState.start_game(domino_pool.duplicate())
		for values in GameState.player_hand_data:
			domino_pool.erase(values)
		for values in GameState.opponent_hand_data:
			domino_pool.erase(values)
		call_deferred("_spawn_player_hand")
		call_deferred("_emit_opponent_hand_changed")
		call_deferred("_init_stack")
	else:
		print("[Boneyard] taking GUEST branch")
		await get_tree().process_frame
		await get_tree().process_frame
		rpc_id(1, "guest_scene_ready")

@rpc("authority")
func receive_hand(hand: Array) -> void:
	player_hand.clear_hand()
	GameState.player_hand_data.clear()
	GameState.player_hand_data = hand.duplicate()
	for values in hand:
		player_hand.add_domino_to_hand_from_values(values[0], values[1])
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)
	rpc_id(1, "guest_hand_received")

@rpc("authority")
func receive_opponent_hand_count(host_hand: Array) -> void:
	get_node("../OpponentHand").clear_hand()
	GameState.opponent_hand_data = host_hand.duplicate()
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

func _player_has_valid_move() -> bool:
	return GameState.has_valid_move(
		GameState.Turn.PLAYER,
		domino_manager.head_val,
		domino_manager.tail_val
	)

func _init_stack() -> void:
	print("[Boneyard] _init_stack called — is_host: ", GameState.is_host, " | existing layers: ", _stack_layers.size())
	for layer in _stack_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	_stack_layers.clear()
	_pool_size_at_start = domino_pool.size()
	
	for i in range(MAX_STACK_LAYERS):
		var layer = Sprite2D.new()
		layer.texture = main_sprite.texture
		layer.scale = main_sprite.scale
		layer.position = main_sprite.position + LAYER_OFFSET * (i + 1)
		layer.z_index = main_sprite.z_index - (i + 1)
		var darkness = 1.0 - (float(i + 1) / MAX_STACK_LAYERS) * 0.6
		layer.modulate = Color(darkness, darkness, darkness, 1.0)
		add_child(layer)
		_stack_layers.append(layer)
	print("[Boneyard] _init_stack done — layers created: ", _stack_layers.size(), " | pool_size_at_start: ", _pool_size_at_start)
	_update_stack()

func _update_stack() -> void:
	if _pool_size_at_start == 0:
		return
	var ratio = float(domino_pool.size()) / float(_pool_size_at_start)
	var visible_layers = int(ceil(ratio * MAX_STACK_LAYERS))
	for i in range(_stack_layers.size()):
		_stack_layers[i].visible = i < visible_layers

func _generate_all_dominoes():
	domino_pool.clear()
	for left in range(7):
		for right in range(left, 7):
			domino_pool.append([left, right])
	domino_pool.shuffle()

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not GameState.is_player_turn():
			return
		var space = get_world_2d().direct_space_state
		var params = PhysicsPointQueryParameters2D.new()
		params.position = get_global_mouse_position()
		params.collide_with_areas = true
		params.collision_mask = 2
		var result = space.intersect_point(params)
		if result.size() > 0:
			draw_domino()

func draw_domino():
	if _player_has_valid_move():
		return
	if GameState.multiplayer_mode:
		if not GameState.is_host:
			rpc_id(1, "host_draw_for_player")
			return
		_do_draw(GameState.Turn.PLAYER)
	else:
		if domino_pool.is_empty():
			_check_blocked_singleplayer()
			return
		var values = domino_pool.pop_back()
		GameState.add_to_hand(GameState.Turn.PLAYER, values)
		player_hand.add_domino_to_hand_from_values(values[0], values[1])
		_update_stack()
		if domino_pool.is_empty():
			visible = false
			_check_blocked_singleplayer()

@rpc("any_peer")
func host_draw_for_player() -> void:
	if not GameState.is_host:
		return
	_do_draw(GameState.Turn.OPPONENT)

func _do_draw(turn: GameState.Turn) -> void:
	if domino_pool.is_empty():
		var pip_counts = domino_manager.get_board_pip_counts()
		var blocked = GameState.check_blocked(domino_manager.head_val, domino_manager.tail_val, pip_counts, true)
		if GameState.multiplayer_mode and GameState.is_host:
			if blocked:
				domino_manager._sync_blocked_game_over()
			else:
				get_node("../DominoManager").rpc("sync_turn", GameState.current_turn)
		return
	var values = domino_pool.pop_back()
	if turn == GameState.Turn.PLAYER:
		GameState.add_to_hand(GameState.Turn.PLAYER, values)
		player_hand.add_domino_to_hand_from_values(values[0], values[1])
		rpc("sync_opponent_draw", values)
	else:
		GameState.add_to_hand(GameState.Turn.OPPONENT, values)
		rpc_id(multiplayer.get_remote_sender_id(), "receive_drawn_tile", values)
		GameState.hand_changed.emit(GameState.Turn.OPPONENT)
	_update_stack()
	if GameState.multiplayer_mode and GameState.is_host:
		rpc("sync_stack_update", domino_pool.size())
	if domino_pool.is_empty():
		visible = false
		if GameState.multiplayer_mode:
			rpc("sync_boneyard_empty")
			if GameState.is_host:
				var pip_counts = domino_manager.get_board_pip_counts()
				var blocked = GameState.check_blocked(domino_manager.head_val, domino_manager.tail_val, pip_counts, true)
				if blocked:
					domino_manager._sync_blocked_game_over()
				elif turn == GameState.Turn.PLAYER and not _player_has_valid_move():
					GameState.end_turn()
					var turn_for_guest = GameState.Turn.PLAYER if GameState.current_turn == GameState.Turn.OPPONENT else GameState.Turn.OPPONENT
					domino_manager.rpc("sync_turn", turn_for_guest)

func _check_blocked_singleplayer() -> void:
	var pip_counts = domino_manager.get_board_pip_counts()
	GameState.check_blocked(domino_manager.head_val, domino_manager.tail_val, pip_counts, true)

@rpc("authority")
func receive_drawn_tile(values: Array) -> void:
	GameState.add_to_hand(GameState.Turn.PLAYER, values)
	player_hand.add_domino_to_hand_from_values(values[0], values[1])

@rpc("any_peer")
func sync_opponent_draw(values: Array) -> void:
	GameState.opponent_hand_data.append(values)
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

@rpc("authority")
func sync_boneyard_empty() -> void:
	visible = false
	
@rpc("any_peer")
func guest_scene_ready() -> void:
	if not GameState.is_host:
		return
	
	rpc("receive_hand", GameState.opponent_hand_data)
	rpc("receive_opponent_hand_count", GameState.player_hand_data)
	rpc("sync_stack_init", domino_pool.size())

@rpc("authority")
func sync_stack_init(pool_size: int) -> void:
	if GameState.is_host:
		return
	_pool_size_at_start = pool_size
	call_deferred("_init_stack_guest", pool_size)

func _init_stack_guest(pool_size: int) -> void:
	print("[Boneyard] _init_stack_guest called — is_host: ", GameState.is_host, " | existing layers: ", _stack_layers.size(), " | pool_size: ", pool_size)
	for layer in _stack_layers:
		if is_instance_valid(layer):
			layer.queue_free()
	_stack_layers.clear()
	for i in range(MAX_STACK_LAYERS):
		var layer = Sprite2D.new()
		layer.texture = main_sprite.texture
		layer.scale = main_sprite.scale
		layer.position = main_sprite.position + LAYER_OFFSET * (i + 1)
		layer.z_index = main_sprite.z_index - (i + 1)
		var darkness = 1.0 - (float(i + 1) / MAX_STACK_LAYERS) * 1.2
		layer.modulate = Color(darkness, darkness, darkness, 1.0)
		add_child(layer)
		_stack_layers.append(layer)
	_pool_size_at_start = pool_size
	print("[Boneyard] _init_stack_guest done — layers created: ", _stack_layers.size(), " | pool_size_at_start: ", _pool_size_at_start)
	_update_stack_with_size(pool_size)

func _update_stack_with_size(current_size: int) -> void:
	if _pool_size_at_start == 0:
		return
	var ratio = float(current_size) / float(_pool_size_at_start)
	var visible_layers = int(ceil(ratio * MAX_STACK_LAYERS))
	for i in range(_stack_layers.size()):
		_stack_layers[i].visible = i < visible_layers

@rpc("authority")
func sync_stack_update(current_size: int) -> void:
	_update_stack_with_size(current_size)

@rpc("any_peer")
func guest_hand_received() -> void:
	if not GameState.is_host:
		return
		
	get_node("../DominoManager").on_guest_ready()
