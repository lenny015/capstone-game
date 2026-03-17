extends Node

enum Turn { PLAYER, OPPONENT }

signal turn_changed(whose_turn: Turn)
signal hand_changed(whose_turn: Turn)
signal game_over(winner: Turn, reason: String)

var current_turn: Turn = Turn.PLAYER
var game_active: bool = false

var player_hand_data: Array = []
var opponent_hand_data: Array = []
var consecutive_passes: int = 0

func start_game(domino_pool: Array) -> void:
	player_hand_data.clear()
	opponent_hand_data.clear()
	current_turn = Turn.PLAYER

	for i in range(7):
		if domino_pool.is_empty():
			break
		player_hand_data.append(domino_pool.pop_back())

	for i in range(7):
		if domino_pool.is_empty():
			break
		opponent_hand_data.append(domino_pool.pop_back())

	consecutive_passes = 0
	game_active = true
	
	hand_changed.emit(Turn.PLAYER)
	hand_changed.emit(Turn.OPPONENT)
	
func find_highest_double() -> Dictionary:
	var best_val = -1
	var best_turn = Turn.PLAYER
	for domino in player_hand_data:
		if domino[0] == domino[1] and domino[0] > best_val:
			best_val = domino[0]
			best_turn = Turn.PLAYER
	for domino in opponent_hand_data:
		if domino[0] == domino[1] and domino[0] > best_val:
			best_val = domino[0]
			best_turn = Turn.OPPONENT
	if best_val == -1:
		return {}
	return {"values": [best_val, best_val], "turn": best_turn}

func end_turn() -> void:
	if current_turn == Turn.PLAYER:
		current_turn = Turn.OPPONENT
	else:
		current_turn = Turn.PLAYER
	turn_changed.emit(current_turn)

func add_to_hand(turn: Turn, values: Array) -> void:
	if turn == Turn.PLAYER:
		player_hand_data.append(values)
	else:
		opponent_hand_data.append(values)
	hand_changed.emit(turn)

func remove_from_hand(turn: Turn, values: Array) -> void:
	if turn == Turn.PLAYER:
		player_hand_data.erase(values)
	else:
		opponent_hand_data.erase(values)
	hand_changed.emit(turn)

func get_hand(turn: Turn) -> Array:
	return player_hand_data if turn == Turn.PLAYER else opponent_hand_data

func is_player_turn() -> bool:
	return current_turn == Turn.PLAYER

func has_valid_move(turn: Turn, head_val: int, tail_val: int) -> bool:
	for domino in get_hand(turn):
		if domino[0] == head_val or domino[1] == head_val:
			return true
		if domino[0] == tail_val or domino[1] == tail_val:
			return true
	return false
	
func check_win_condition() -> bool:
	if player_hand_data.is_empty():
		game_active = false
		game_over.emit(Turn.PLAYER, "empty_hand")
		return true
	if opponent_hand_data.is_empty():
		game_active = false
		game_over.emit(Turn.OPPONENT, "empty_hand")
		return true
	return false
	
func pass_turn() -> void:
	consecutive_passes += 1
	if consecutive_passes >= 2:
		var player_pips = 0
		for d in player_hand_data:
			player_pips += d[0] + d[1]
		var opponent_pips = 0
		for d in opponent_hand_data:
			opponent_pips += d[0] + d[1]
		if player_pips < opponent_pips:
			game_over.emit(Turn.PLAYER, "blocked")
		elif opponent_pips < player_pips:
			game_over.emit(Turn.OPPONENT, "blocked")
		else:
			game_over.emit(Turn.PLAYER, "draw")
		return
	end_turn()
	
func reset_passes():
	consecutive_passes = 0
