extends Node2D

var domino_pool: Array = []

@onready var player_hand = get_node("../PlayerHand")
@onready var domino_manager = get_node("../DominoManager")

func _ready():
	print("_ready multiplayer_mode: %s  is_host: %s" % [GameState.multiplayer_mode, GameState.is_host])
	if GameState.multiplayer_mode:
		_ready_multiplayer()
	else:
		_ready_singleplayer()

# --- Singleplayer (unchanged) ---

func _ready_singleplayer():
	print("singleplayer path")
	_generate_all_dominoes()
	GameState.start_game(domino_pool.duplicate())
	for values in GameState.player_hand_data:
		domino_pool.erase(values)
	for values in GameState.opponent_hand_data:
		domino_pool.erase(values)
	_spawn_player_hand()
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

func _spawn_player_hand():
	print("spawning player hand, %d tiles" % GameState.player_hand_data.size())
	for values in GameState.player_hand_data:
		player_hand.add_domino_to_hand_from_values(values[0], values[1])

# --- Multiplayer ---

func _ready_multiplayer():
	print("multiplayer path, is_host: %s" % GameState.is_host)
	if GameState.is_host:
		_generate_all_dominoes()
		print("pool generated, %d tiles" % domino_pool.size())
		GameState.start_game(domino_pool.duplicate())
		for values in GameState.player_hand_data:
			domino_pool.erase(values)
		for values in GameState.opponent_hand_data:
			domino_pool.erase(values)
		print("host hand: %d tiles  guest hand: %d tiles  pool remaining: %d" % [
			GameState.player_hand_data.size(),
			GameState.opponent_hand_data.size(),
			domino_pool.size()
		])
		_spawn_player_hand()
		print("sending guest hand via RPC: %s" % str(GameState.opponent_hand_data))
		rpc("receive_hand", GameState.opponent_hand_data)
		GameState.hand_changed.emit(GameState.Turn.OPPONENT)
	else:
		print("guest, waiting for receive_hand RPC")

@rpc("authority")
func receive_hand(hand: Array) -> void:
	print("guest received hand %d tiles: %s" % [hand.size(), str(hand)])
	GameState.player_hand_data = hand.duplicate()
	for values in hand:
		player_hand.add_domino_to_hand_from_values(values[0], values[1])
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)

# --- Shared ---

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
		print("draw blocked, player has valid move")
		return
	if GameState.multiplayer_mode:
		if not GameState.is_host:
			print("guest requesting draw from host")
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
	print("host drawing for guest")
	_do_draw(GameState.Turn.OPPONENT)

func _do_draw(turn: GameState.Turn) -> void:
	if domino_pool.is_empty():
		print("pool empty — passing turn")
		GameState.pass_turn()
		return
	var values = domino_pool.pop_back()
	print("drawing tile: %s for turn: %s" % [str(values), turn])
	if turn == GameState.Turn.PLAYER:
		GameState.add_to_hand(GameState.Turn.PLAYER, values)
		player_hand.add_domino_to_hand_from_values(values[0], values[1])
		rpc("sync_opponent_draw_count", GameState.player_hand_data.size())
	else:
		GameState.add_to_hand(GameState.Turn.OPPONENT, values)
		rpc_id(multiplayer.get_remote_sender_id(), "receive_drawn_tile", values)
		rpc("sync_opponent_draw_count", GameState.opponent_hand_data.size())
	if domino_pool.is_empty():
		visible = false

@rpc("authority")
func receive_drawn_tile(values: Array) -> void:
	print("guest received drawn tile: %s" % str(values))
	GameState.add_to_hand(GameState.Turn.PLAYER, values)
	player_hand.add_domino_to_hand_from_values(values[0], values[1])

@rpc("any_peer", "call_local")
func sync_opponent_draw_count(_count: int) -> void:
	print("syncing opponent draw count: %d" % _count)
	GameState.hand_changed.emit(GameState.Turn.OPPONENT)
