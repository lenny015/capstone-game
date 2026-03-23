extends Node2D

var domino_pool: Array = []

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
	_spawn_player_hand()
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

func _spawn_player_hand():
	for values in GameState.player_hand_data:
		player_hand.add_domino_to_hand_from_values(values[0], values[1])

func _ready_multiplayer():
	if GameState.is_host:
		_generate_all_dominoes()
		GameState.start_game(domino_pool.duplicate())
		for values in GameState.player_hand_data:
			domino_pool.erase(values)
		for values in GameState.opponent_hand_data:
			domino_pool.erase(values)
		_spawn_player_hand()
		rpc("receive_hand", GameState.opponent_hand_data)
		rpc("receive_opponent_hand_count", GameState.player_hand_data)
		GameState.hand_changed.emit(GameState.Turn.OPPONENT)

@rpc("authority")
func receive_hand(hand: Array) -> void:
	GameState.player_hand_data = hand.duplicate()
	for values in hand:
		player_hand.add_domino_to_hand_from_values(values[0], values[1])
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

@rpc("authority")
func receive_opponent_hand_count(host_hand: Array) -> void:
	GameState.opponent_hand_data = host_hand.duplicate()
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

func _player_has_valid_move() -> bool:
	return GameState.has_valid_move(
		GameState.Turn.PLAYER,
		domino_manager.head_val,
		domino_manager.tail_val
	)

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
			GameState.pass_turn()
			return
		var values = domino_pool.pop_back()
		GameState.add_to_hand(GameState.Turn.PLAYER, values)
		player_hand.add_domino_to_hand_from_values(values[0], values[1])
		if domino_pool.is_empty():
			visible = false

@rpc("any_peer")
func host_draw_for_player() -> void:
	if not GameState.is_host:
		return
	_do_draw(GameState.Turn.OPPONENT)

func _do_draw(turn: GameState.Turn) -> void:
	if domino_pool.is_empty():
		var was_active = GameState.game_active
		GameState.pass_turn()
		if GameState.multiplayer_mode and GameState.is_host:
			if was_active and not GameState.game_active:
				var guest_won = GameState.current_turn == GameState.Turn.OPPONENT
				var reason = "draw" if GameState.consecutive_passes == 0 else "blocked"
				get_node("../DominoManager").rpc("sync_game_over", int(guest_won), reason)
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
		rpc_id(1 ,"sync_opponent_draw", values)
	if domino_pool.is_empty():
		visible = false

@rpc("authority")
func receive_drawn_tile(values: Array) -> void:
	GameState.add_to_hand(GameState.Turn.PLAYER, values)
	player_hand.add_domino_to_hand_from_values(values[0], values[1])

@rpc("any_peer")
func sync_opponent_draw(values: Array) -> void:
	GameState.opponent_hand_data.append(values)
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)
