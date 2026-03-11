extends Node

@onready var domino_manager = $"../DominoManager"
@onready var opponent_hand = $"../OpponentHand"
@onready var boneyard = $"../Boneyard"

func _ready():
	GameState.turn_changed.connect(_on_turn_changed)

func _on_turn_changed(whose_turn: GameState.Turn):
	if whose_turn != GameState.Turn.OPPONENT:
		return
	await get_tree().create_timer(0.8).timeout
	_take_turn()

func _take_turn():
	# Try to play from existing hand first
	for values in GameState.opponent_hand_data.duplicate():
		if domino_manager._can_place(values[0], values[1], domino_manager.head_val):
			_place(values[0], values[1], true)
			return
		if domino_manager._can_place(values[0], values[1], domino_manager.tail_val):
			_place(values[0], values[1], false)
			return

	# No valid move — draw until we find one or pool is empty
	while not boneyard.domino_pool.is_empty():
		var drawn = boneyard.domino_pool.pop_back()
		GameState.add_to_hand(GameState.Turn.OPPONENT, drawn)
		opponent_hand._add_domino_visual(drawn[0], drawn[1])
		if boneyard.domino_pool.is_empty():
			boneyard.visible = false
		if domino_manager._can_place(drawn[0], drawn[1], domino_manager.head_val):
			_place(drawn[0], drawn[1], true)
			return
		if domino_manager._can_place(drawn[0], drawn[1], domino_manager.tail_val):
			_place(drawn[0], drawn[1], false)
			return

	# Pool exhausted with no valid move — pass
	GameState.pass_turn()

func _place(left: int, right: int, is_head: bool):
	var end_val = domino_manager.head_val if is_head else domino_manager.tail_val
	var needs_flip = right == end_val
	var new_open = right if left == end_val else left

	var dir = domino_manager.head_dir if is_head else domino_manager.tail_dir
	var board_end = domino_manager.board_head if is_head else domino_manager.board_tail

	var is_double = left == right
	var slot_half = domino_manager.TILE_W / 2.0 if is_double else domino_manager.TILE_H / 2.0
	var end_half = domino_manager._half_width(board_end["node"], dir)
	var pos = board_end["node"].position + domino_manager._dir_vec(dir) * (end_half + slot_half + domino_manager.SLOT_GAP)

	var nudge = domino_manager.TILE_H / 4.0 if not board_end["node"].get_node("Area2D").is_double() else 0.0
	# Keep turning until position is in bounds (mirrors _spawn_slots behaviour)
	while domino_manager._out_of_bounds(pos):
		var turned_dir = domino_manager._try_turn(board_end["node"], dir, slot_half, nudge)
		if turned_dir == dir:
			break  # No valid turn found, place as-is
		var old_dir = dir
		dir = turned_dir
		end_half = domino_manager._half_width(board_end["node"], dir)
		pos = board_end["node"].position + domino_manager._dir_vec(dir) * (end_half + slot_half + domino_manager.SLOT_GAP)
		if not board_end["node"].get_node("Area2D").is_double():
			pos += domino_manager._dir_vec(old_dir) * nudge

	var new_domino = preload("res://scenes/domino.tscn").instantiate()
	domino_manager.board_root.add_child(new_domino)

	var is_vertical = dir == domino_manager.Direction.UP or dir == domino_manager.Direction.DOWN
	var base_rot = 90 if is_double == is_vertical else 0
	var flip_rot = base_rot + 180
	match dir:
		domino_manager.Direction.RIGHT, domino_manager.Direction.UP:
			new_domino.rotation_degrees = flip_rot if needs_flip else base_rot
		domino_manager.Direction.LEFT, domino_manager.Direction.DOWN:
			new_domino.rotation_degrees = flip_rot if not needs_flip else base_rot

	new_domino.position = pos
	var area = new_domino.get_node("Area2D")
	area.set_values(left, right)
	area.collision_layer = 0
	area.collision_mask = 0

	# Update board linked list
	var entry = domino_manager._make_board_node(new_domino)
	if is_head:
		domino_manager.head_val = new_open
		domino_manager.head_dir = dir
		entry.next = domino_manager.board_head
		domino_manager.board_head.prev = entry
		domino_manager.board_head = entry
	else:
		domino_manager.tail_val = new_open
		domino_manager.tail_dir = dir
		entry.prev = domino_manager.board_tail
		domino_manager.board_tail.next = entry
		domino_manager.board_tail = entry

	opponent_hand.remove_domino(left, right)
	GameState.reset_passes()
	if not GameState.check_win_condition():
		GameState.end_turn()
