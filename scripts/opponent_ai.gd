extends Node

const THINK_TIME = 0.8

@onready var domino_manager = get_node("../DominoManager")
@onready var boneyard_node = get_node("../Boneyard")
@onready var opponent_hand_node = get_node("../OpponentHand")

func _ready() -> void:
	if GameState.multiplayer_mode:
		return
	GameState.turn_changed.connect(_on_turn_changed)

func _on_turn_changed(whose_turn: GameState.Turn) -> void:
	if whose_turn != GameState.Turn.OPPONENT or not GameState.game_active:
		return
	await get_tree().create_timer(THINK_TIME).timeout
	_take_turn()

func _take_turn() -> void:
	if not GameState.game_active:
		return

	var move = _pick_best_move()
	if move != null:
		_place_domino(move)
		return

	while not boneyard_node.domino_pool.is_empty():
		var values = boneyard_node.domino_pool.pop_back()
		GameState.add_to_hand(GameState.Turn.OPPONENT, values)
		if boneyard_node.domino_pool.is_empty():
			boneyard_node.visible = false
		await get_tree().create_timer(THINK_TIME).timeout
		if not GameState.game_active:
			return
		move = _pick_best_move()
		if move != null:
			_place_domino(move)
			return
			
	boneyard_node._check_blocked_singleplayer()

func _pick_best_move() -> Variant:
	var best = null
	var best_score = -1

	for values in GameState.opponent_hand_data:
		var left = values[0]
		var right = values[1]
		var pip_total = left + right

		var can_head = (left == domino_manager.head_val or right == domino_manager.head_val)
		var can_tail = (left == domino_manager.tail_val or right == domino_manager.tail_val)

		if not can_head and not can_tail:
			continue

		if pip_total > best_score:
			best_score = pip_total
			var use_head = can_head
			var end_val = domino_manager.head_val if use_head else domino_manager.tail_val
			best = {
				"values": values,
				"is_head": use_head,
				"needs_flip": right == end_val
			}

	return best

func _place_domino(move: Dictionary) -> void:
	var values: Array = move["values"]
	var is_head: bool = move["is_head"]
	var needs_flip: bool = move["needs_flip"]

	var domino_node = _find_domino_node(values[0], values[1])
	if domino_node == null:
		return

	var area = domino_node.get_node("Area2D")
	var is_double = area.is_double()
	var placed_dir = domino_manager.head_dir if is_head else domino_manager.tail_dir
	var end_node = domino_manager.board_head["node"] if is_head else domino_manager.board_tail["node"]

	var slot_half = domino_manager.TILE_W / 2.0 if is_double else domino_manager.TILE_H / 2.0
	var end_half = domino_manager._half_width(end_node, placed_dir)
	var pos = end_node.position + domino_manager._dir_vec(placed_dir) * (end_half + slot_half + domino_manager.SLOT_GAP)

	var is_vertical = (placed_dir == domino_manager.Direction.UP or placed_dir == domino_manager.Direction.DOWN)
	var base_rot = 90 if is_double == is_vertical else 0
	var flip_rot = base_rot + 180
	var final_rot: float
	match placed_dir:
		domino_manager.Direction.RIGHT, domino_manager.Direction.UP:
			final_rot = flip_rot if needs_flip else base_rot
		domino_manager.Direction.LEFT, domino_manager.Direction.DOWN:
			final_rot = flip_rot if not needs_flip else base_rot
		_:
			final_rot = base_rot

	domino_node.reparent(domino_manager.board_root, false)
	domino_node.rotation_degrees = final_rot
	domino_node.position = pos
	area.collision_layer = 0
	area.collision_mask = 0

	domino_node.get_node("Tile").texture = load("res://assets/domino/domino.png")
	domino_node.get_node("Tile/RightPip").visible = true
	domino_node.get_node("Tile/LeftPip").visible = true

	opponent_hand_node.opponent_hand.erase(domino_node)
	opponent_hand_node._update_positions()

	var end_val = domino_manager.head_val if is_head else domino_manager.tail_val
	var new_open = values[1] if values[0] == end_val else values[0]

	GameState.remove_from_hand(GameState.Turn.OPPONENT, values)

	var entry = domino_manager._make_board_node(domino_node)
	if is_head:
		domino_manager.head_val = new_open
		domino_manager.head_dir = placed_dir
		entry.next = domino_manager.board_head
		domino_manager.board_head.prev = entry
		domino_manager.board_head = entry
		domino_manager.head_boundary_expanded = false
		domino_manager.head_dir_prev = placed_dir
	else:
		domino_manager.tail_val = new_open
		domino_manager.tail_dir = placed_dir
		entry.prev = domino_manager.board_tail
		domino_manager.board_tail.next = entry
		domino_manager.board_tail = entry
		domino_manager.tail_boundary_expanded = false
		domino_manager.tail_dir_prev = placed_dir

	domino_manager._update_end_directions()

	var won = GameState.check_win_condition()
	if not won:
		var boneyard_empty = not boneyard_node.visible or boneyard_node.domino_pool.is_empty()
		var pip_counts = domino_manager.get_board_pip_counts()
		var blocked = GameState.check_blocked(domino_manager.head_val, domino_manager.tail_val, pip_counts, boneyard_empty)
		if not blocked:
			GameState.end_turn()

func _find_domino_node(left: int, right: int) -> Node2D:
	for domino in opponent_hand_node.opponent_hand:
		var a = domino.get_node("Area2D")
		if (a.left_val == left and a.right_val == right) or \
		   (a.left_val == right and a.right_val == left):
			return domino
	return null
