extends Node

enum Turn { PLAYER, OPPONENT }

signal turn_changed(whose_turn: Turn)
signal hand_changed(whose_turn: Turn)

var current_turn: Turn = Turn.PLAYER

var player_hand_data: Array = []
var opponent_hand_data: Array = []

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

	hand_changed.emit(Turn.PLAYER)
	hand_changed.emit(Turn.OPPONENT)

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
