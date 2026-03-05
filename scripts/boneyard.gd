extends Node2D

var domino_pool: Array = []

@onready var player_hand = get_node("../PlayerHand")
@onready var domino_manager = get_node("../DominoManager")

func _ready():
	_generate_all_dominoes()
	GameState.start_game(domino_pool.duplicate())
	for values in GameState.player_hand_data:
		domino_pool.erase(values)
	for values in GameState.opponent_hand_data:
		domino_pool.erase(values)
	_spawn_player_hand()

func _generate_all_dominoes():
	domino_pool.clear()
	for left in range(7):
		for right in range(left, 7):
			domino_pool.append([left, right])
	domino_pool.shuffle()
	
func _spawn_player_hand():
	for values in GameState.player_hand_data:
		player_hand.add_domino_to_hand_from_values(values[0], values[1])

func _player_has_valid_move() -> bool:
	return GameState.has_valid_move(
		GameState.Turn.PLAYER,
		domino_manager.head_val,
		domino_manager.tail_val
	)

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
	if domino_pool.is_empty():
		GameState.end_turn()
		return
		
	var values = domino_pool.pop_back()
	GameState.add_to_hand(GameState.Turn.PLAYER, values)
	player_hand.add_domino_to_hand_from_values(values[0], values[1])
	
	if domino_pool.is_empty():
		visible = false
