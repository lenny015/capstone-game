extends Node2D

@onready var boneyard = $"../Boneyard"
@onready var player_hand = $"../PlayerHand"
@onready var boundary_node = $"../Boundary"
@onready var board_root = $"BoardRoot"

enum Direction { RIGHT, LEFT, DOWN, UP }

const HOVER_OFFSET = -15
const SELECT_OFFSET = -30
const DOMINO_SCENE_PATH = "res://scenes/domino.tscn"
const DOMINO_SLOT_SCENE_PATH = "res://scenes/domino_slot.tscn"
const TILE_W = 66
const TILE_H = 132
const SLOT_GAP = 8

var hovered_domino: Node2D = null
var selected_domino: Node2D = null
var domino_original_pos = {}
var boundary: Rect2

var board_head = null
var board_tail = null
var active_slots: Array = []

#end values
var head_val: int = -1
var tail_val: int = -1

var head_dir: Direction = Direction.LEFT
var tail_dir: Direction = Direction.RIGHT

func _ready():
	call_deferred("_place_first_domino")
	call_deferred("_setup_boundary")
	
func _make_board_node(domino_node):
	return {
		"node": domino_node,
		"prev": null,
		"next": null
	}
	
func _setup_boundary():
	var shape = boundary_node.get_node("CollisionShape2D")
	var shape_size = shape.shape.size * shape.global_transform.get_scale()
	var world_rect = Rect2(shape.global_position - shape_size / 2.0, shape_size)
	var top_left = board_root.to_local(world_rect.position)
	var bottom_right = board_root.to_local(world_rect.position + world_rect.size)
	boundary = Rect2(top_left, bottom_right - top_left)

func _place_first_domino():
	await get_tree().create_timer(1.0).timeout
	if GameState.multiplayer_mode:
		if GameState.is_host:
			var result = GameState.find_highest_double()
			if result.is_empty():
				while not boneyard.domino_pool.is_empty():
					var drawn = boneyard.domino_pool.pop_back()
					if drawn[0] == drawn[1]:
						rpc("sync_first_tile", drawn, GameState.Turn.PLAYER, false)
						return
				return
			rpc("sync_first_tile", result["values"], result["turn"], true)
	else:
		var result = GameState.find_highest_double()
		if result.is_empty():
			while not boneyard.domino_pool.is_empty():
				var drawn = boneyard.domino_pool.pop_back()
				if drawn[0] == drawn[1]:
					_spawn_first_tile(drawn, GameState.Turn.PLAYER, false)
					return
			return
		_spawn_first_tile(result["values"], result["turn"], true)
	
@rpc("authority", "call_local")
func sync_first_tile(values: Array, holder: GameState.Turn, from_hand: bool) -> void:
	_spawn_first_tile(values, holder, from_hand)
	
func _spawn_first_tile(values: Array, holder: GameState.Turn, from_hand: bool):
	var new_domino = preload(DOMINO_SCENE_PATH).instantiate()
	board_root.add_child(new_domino)
	new_domino.position = board_root.to_local(get_viewport().size / 2)
 
	var domino_area = new_domino.get_node("Area2D")
	domino_area.set_values(values[0], values[1])
	domino_area.collision_layer = 0
	domino_area.collision_mask = 0
	new_domino.rotation_degrees = 0
 
	head_val = domino_area.left_val
	tail_val = domino_area.right_val
 
	var entry = _make_board_node(new_domino)
	board_head = entry
	board_tail = entry
 
	if from_hand:
		var held: bool
		if GameState.multiplayer_mode:
			held = (holder == GameState.Turn.PLAYER and GameState.is_host) or (holder == GameState.Turn.OPPONENT and not GameState.is_host)
		else: 
			held = (holder == GameState.Turn.PLAYER)
			
		if held:
			for domino in player_hand.player_hand:
				var area = domino.get_node("Area2D")
				if area.left_val == values[0] and area.right_val == values[1]:
					domino.queue_free()
					player_hand.player_hand.erase(domino)
					domino_original_pos.erase(domino)
					player_hand.update_hand_positions()
					break
			GameState.remove_from_hand(GameState.Turn.PLAYER, values)
			GameState.current_turn = GameState.Turn.OPPONENT
			if not GameState.multiplayer_mode:
				GameState.end_turn()
		else:
			var opp_hand = get_node("../OpponentHand")
			opp_hand.remove_domino(values[0], values[1], false)
			GameState.remove_from_hand(GameState.Turn.OPPONENT, values)
			GameState.current_turn = GameState.Turn.PLAYER
			if not GameState.multiplayer_mode:
				GameState.turn_changed.emit(GameState.current_turn)	
		
	if GameState.multiplayer_mode and GameState.is_host:
		var turn_for_guest = GameState.Turn.PLAYER if GameState.current_turn == GameState.Turn.OPPONENT else GameState.Turn.OPPONENT
		rpc("sync_turn", turn_for_guest)
		GameState.turn_changed.emit(GameState.current_turn)
	
func _half_width(domino_node: Node2D, dir: Direction) -> float:
	var r = int(domino_node.rotation_degrees) % 180
	match dir:
		Direction.LEFT, Direction.RIGHT:
			return TILE_H / 2.0 if r == 90 else TILE_W / 2.0
		Direction.UP, Direction.DOWN:
			return TILE_W / 2.0 if r == 90 else TILE_H / 2.0
	return TILE_H / 2.0

func _can_place(val_a: int, val_b: int, end_val: int) -> bool:
	return val_a == end_val or val_b == end_val
	
func _dir_vec(dir: Direction) -> Vector2:
	match dir:
		Direction.RIGHT: return Vector2(1, 0)
		Direction.LEFT:  return Vector2(-1, 0)
		Direction.DOWN:  return Vector2(0, 1)
		Direction.UP:    return Vector2(0, -1)
	return Vector2(1, 0)
	
func _turn_cw(dir: Direction) -> Direction:
	match dir:
		Direction.RIGHT: return Direction.DOWN
		Direction.DOWN:  return Direction.LEFT
		Direction.LEFT:  return Direction.UP
		Direction.UP:    return Direction.RIGHT
	return dir
	
func _out_of_bounds(pos: Vector2) -> bool:
	var margin = TILE_H / 2.0 + SLOT_GAP
	var set_margin = boundary.grow(-margin)
	return not set_margin.has_point(pos)
	
func _try_turn(base_node: Node2D, current_dir: Direction, incoming_half: float, old_dir_nudge: float = 0.0) -> Direction:
	var new_dir = _turn_cw(current_dir)
	var new_end_half = _half_width(base_node, new_dir)
	var gap = new_end_half + incoming_half + SLOT_GAP
	var candidate_pos = base_node.position + _dir_vec(new_dir) * gap + _dir_vec(current_dir) * old_dir_nudge
	if not _out_of_bounds(candidate_pos):
		return new_dir
	return current_dir
	
func _spawn_slots():
	_clear_slots()
	if board_head == null:
		return

	var slot_scene = preload(DOMINO_SLOT_SCENE_PATH)
	var area = selected_domino.get_node("Area2D")
	var is_double = area.is_double()
	var val_a = area.left_val
	var val_b = area.right_val
	var slot_half = TILE_W / 2.0 if is_double else TILE_H / 2.0
	var slot_rot = 0 if is_double else 90

	if _can_place(val_a, val_b, head_val):
		var dir = head_dir
		var end_half = _half_width(board_head["node"], dir)
		var pos = board_head["node"].position + _dir_vec(head_dir) * (end_half + slot_half + SLOT_GAP)
		if _out_of_bounds(pos):
			var head_area = board_head["node"].get_node("Area2D")
			var nudge = TILE_H / 4.0 if not head_area.is_double() else 0.0
			var turned_dir = _try_turn(board_head["node"], dir, slot_half, nudge)
			if turned_dir != dir:
				dir = turned_dir
				end_half = _half_width(board_head["node"], dir)
				pos = board_head["node"].position + _dir_vec(dir) * (end_half + slot_half + SLOT_GAP)
				if not head_area.is_double():
					pos += _dir_vec(head_dir) * nudge
		var rot = slot_rot if (dir == Direction.LEFT or dir == Direction.RIGHT) else slot_rot + 90
		_make_slot(slot_scene, pos, rot, dir, true)

	if _can_place(val_a, val_b, tail_val):
		var dir = tail_dir
		var end_half = _half_width(board_tail["node"], dir)
		var pos = board_tail["node"].position + _dir_vec(tail_dir) * (end_half + slot_half + SLOT_GAP)
		if _out_of_bounds(pos):
			var tail_area = board_tail["node"].get_node("Area2D")
			var nudge = TILE_H / 4.0 if not tail_area.is_double() else 0.0
			var turned_dir = _try_turn(board_tail["node"], dir, slot_half, nudge)
			if turned_dir != dir:
				dir = turned_dir
				end_half = _half_width(board_tail["node"], dir)
				pos = board_tail["node"].position + _dir_vec(dir) * (end_half + slot_half + SLOT_GAP)
				if not tail_area.is_double():
					pos += _dir_vec(tail_dir) * nudge
		var rot = slot_rot if (dir == Direction.LEFT or dir == Direction.RIGHT) else slot_rot + 90
		_make_slot(slot_scene, pos, rot, dir, false)
		
func _make_slot(slot_scene, pos: Vector2, rot: float, dir, is_head: bool):
	var slot = slot_scene.instantiate()
	board_root.add_child(slot)
	slot.rotation_degrees = rot
	slot.position = pos
	
	var area = slot.get_node("Area2D")
	area.collision_layer = 4
	area.collision_mask = 4
	area.dir = dir
	area.is_head = is_head
	
	active_slots.append(slot)
	
func _clear_slots():
	for slot in active_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	active_slots.clear()

func _on_slot_clicked(slot):
	if selected_domino == null:
		return

	var domino_to_place = selected_domino
	var is_head = slot.get_node("Area2D").is_head
	var placed_dir = slot.get_node("Area2D").dir
	var area = domino_to_place.get_node("Area2D")
	
	var end_val = head_val if is_head else tail_val
	var is_double = area.is_double()
	var needs_flip = area.right_val == end_val
	var new_open = area.right_val if area.left_val == end_val else area.left_val
	
	var is_vertical = placed_dir == Direction.UP or placed_dir == Direction.DOWN
	var base_rot = 90 if is_double == is_vertical else 0
	var flip_rot = base_rot + 180
	
	if domino_to_place.get_parent() != board_root:
		domino_to_place.reparent(board_root, false)
		
	match placed_dir:
		Direction.RIGHT, Direction.UP:
			domino_to_place.rotation_degrees = flip_rot if needs_flip else base_rot
		Direction.LEFT, Direction.DOWN:
			domino_to_place.rotation_degrees = flip_rot if not needs_flip else base_rot
	
	domino_to_place.position = slot.position
	area.collision_layer = 0
	area.collision_mask = 0
	
	player_hand.remove_domino_from_hand(domino_to_place)
	deselect_domino()
	
	var entry = _make_board_node(domino_to_place)
	if is_head:
		head_val = new_open
		head_dir = placed_dir
		entry.next = board_head
		board_head.prev = entry
		board_head = entry
	else:
		tail_val = new_open
		tail_dir = placed_dir
		entry.prev = board_tail
		board_tail.next = entry
		board_tail = entry

	_clear_slots()
	GameState.reset_passes()
	if GameState.multiplayer_mode:
		var left = area.left_val
		var right = area.right_val
		rpc("sync_placement", left, right, int(placed_dir), is_head, domino_to_place.position, domino_to_place.rotation_degrees)
	
	var won = GameState.check_win_condition()
	if GameState.multiplayer_mode and GameState.is_host and won:
		rpc("sync_game_over", int(GameState.current_turn == GameState.Turn.OPPONENT), "empty_hand")
	if not won: 
		if GameState.multiplayer_mode and GameState.is_host:
			GameState.end_turn()
			var turn_for_guest = GameState.Turn.PLAYER if GameState.current_turn == GameState.Turn.OPPONENT else GameState.Turn.OPPONENT
			rpc("sync_turn", turn_for_guest)
		elif GameState.multiplayer_mode and not GameState.is_host:
			rpc_id(1, "request_end_turn")
		elif not GameState.multiplayer_mode:
			GameState.end_turn()
			
@rpc("any_peer")
func sync_placement(left: int, right: int, placed_dir_int: int, is_head: bool, pos: Vector2, rot: float):
	if multiplayer.get_remote_sender_id() == 0:
		return
	var placed_dir = placed_dir_int as Direction
	var new_open = right if left == (head_val if is_head else tail_val) else left
	
	var new_domino = preload(DOMINO_SCENE_PATH).instantiate()
	board_root.add_child(new_domino)
	new_domino.position = pos
	new_domino.rotation_degrees = rot
	
	var area = new_domino.get_node("Area2D")
	area.set_values(left, right)
	area.collision_layer = 0
	area.collision_mask = 0
	
	GameState.remove_from_hand(GameState.Turn.OPPONENT, [left, right])
	var opp_hand = get_node("../OpponentHand")
	opp_hand.remove_domino(left, right)
	
	var entry = _make_board_node(new_domino)
	if is_head:
		head_val = new_open
		head_dir = placed_dir
		entry.next = board_head
		board_head.prev = entry
		board_head = entry
	else:
		tail_val = new_open
		tail_dir = placed_dir
		entry.prev = board_tail
		board_tail.next = entry
		board_tail = entry
		
	if GameState.multiplayer_mode and GameState.is_host:
		var won = GameState.check_win_condition()
		if won:
			rpc("sync_game_over", int(GameState.current_turn == GameState.Turn.OPPONENT), "empty_hand")
			
@rpc("authority")
func sync_turn(turn: GameState.Turn):
	GameState.current_turn = turn
	GameState.turn_changed.emit(turn)
		
@rpc("any_peer")
func request_end_turn() -> void:
	if not GameState.is_host:
		return
	GameState.end_turn()
	var turn_for_guest = GameState.Turn.PLAYER if GameState.current_turn == GameState.Turn.OPPONENT else GameState.Turn.OPPONENT
	rpc("sync_turn", turn_for_guest)	
	
@rpc("authority")
func sync_game_over(guest_won: int, reason: String) -> void:
	# guest_won: 1 = guest wins, 0 = host wins
	if guest_won == 1:
		GameState.game_over.emit(GameState.Turn.PLAYER, reason)
	else:
		GameState.game_over.emit(GameState.Turn.OPPONENT, reason)
		
@rpc("any_peer", "call_local")
func sync_rematch_vote() -> void:
	get_node("../HUD").on_rematch_vote_received()
	
@rpc("any_peer", "call_local")
func sync_return_to_lobby() -> void:
	get_node("../HUD").on_return_to_lobby()
	
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _slot_raycast_check():
				return
			var domino = raycast_check(1)
			if domino:
				toggle_selection(domino)

func _process(_delta):
	var domino = raycast_check(1)
	if domino != hovered_domino:
		if hovered_domino and hovered_domino != selected_domino:
			move_to_origin(hovered_domino)
		hovered_domino = domino
		if hovered_domino and hovered_domino != selected_domino:
			lift_domino(hovered_domino, HOVER_OFFSET)

func toggle_selection(domino: Node2D):
	if not GameState.is_player_turn():
		return
	if selected_domino == domino:
		deselect_domino()
	else:
		if selected_domino:
			deselect_domino()
		select_domino(domino)
		
func select_domino(domino: Node2D):
	selected_domino = domino
	lift_domino(domino, SELECT_OFFSET)
	_spawn_slots()
	
func deselect_domino():
	if selected_domino:
		move_to_origin(selected_domino)
		selected_domino = null
		_clear_slots()
		
func lift_domino(domino: Node2D, offset: float):
	if not domino_original_pos.has(domino):
		domino_original_pos[domino] = domino.position.y
	
	var original_y = domino_original_pos[domino]
	var target_pos = Vector2(domino.position.x, original_y + offset)
	
	var tween = get_tree().create_tween()
	tween.tween_property(domino, "position", target_pos, 0.15)

func move_to_origin(domino: Node2D):
	if domino_original_pos.has(domino):
		var original_y = domino_original_pos[domino]
		var target_pos = Vector2(domino.position.x, original_y)
		
		var tween = get_tree().create_tween()
		tween.tween_property(domino, "position", target_pos, 0.15)

func store_original_position(domino: Node2D):
	domino_original_pos[domino] = domino.position.y

func _slot_raycast_check() :
	if active_slots.is_empty():
		return false
	var slot = raycast_check(4)
	if slot and slot in active_slots:
		_on_slot_clicked(slot)
		return true
	return false

func raycast_check(mask: int):
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = mask
	
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null
	
