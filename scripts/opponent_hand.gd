extends Node2D

const DOMINO_SCENE_PATH = "res://scenes/domino.tscn"
const DOMINO_WIDTH = 80
const BG_PADDING_X = 50
const BG_HEIGHT = 165

var opponent_hand = []
var center_screen_x
var hand_y_pos

@onready var hand_bg = $OpponentHandBackground

func _ready():
	center_screen_x = get_viewport().size.x / 2
	hand_y_pos = get_viewport().size.y * 0.08
	GameState.hand_changed.connect(_on_hand_changed)

func _on_hand_changed(whose_turn: GameState.Turn):
	if whose_turn != GameState.Turn.OPPONENT:
		return
	var data_count = GameState.opponent_hand_data.size()
	var visual_count = opponent_hand.size()
	if data_count > visual_count:
		for i in range(data_count - visual_count):
			_add_domino_visual(0, 0)
	elif data_count < visual_count:
		while opponent_hand.size() > data_count:
			var domino = opponent_hand.pop_back()
			domino.queue_free()
		_update_positions()

func _add_domino_visual(left: int, right: int):
	var domino_scene = preload(DOMINO_SCENE_PATH)
	var new_domino = domino_scene.instantiate()
	add_child(new_domino)
	new_domino.name = "OppDomino_" + str(left) + "_" + str(right)
	new_domino.position = Vector2(center_screen_x, hand_y_pos)

	var domino_area = new_domino.get_node("Area2D")
	domino_area.set_values(left, right)
	domino_area.collision_layer = 0
	domino_area.collision_mask = 0
	
	new_domino.get_node("Tile/RightPip").visible = false
	new_domino.get_node("Tile/LeftPip").visible = false
	new_domino.get_node("Tile").texture = load("res://assets/domino/domino_backside.png")

	opponent_hand.append(new_domino)
	_update_positions()

func remove_domino(left: int, right: int):
	for domino in opponent_hand:
		var area = domino.get_node("Area2D")
		if (area.left_val == left and area.right_val == right) or \
		   (area.left_val == right and area.right_val == left):
			opponent_hand.erase(domino)
			domino.queue_free()
			GameState.remove_from_hand(GameState.Turn.OPPONENT, [left, right])
			_update_positions()
			return

func _update_positions():
	var total_width = (opponent_hand.size() - 1) * DOMINO_WIDTH
	for i in range(opponent_hand.size()):
		var x = center_screen_x + i * DOMINO_WIDTH - total_width / 2.0
		var tween = get_tree().create_tween()
		tween.tween_property(opponent_hand[i], "position", Vector2(x, hand_y_pos), 0.2)
	_update_background()
		
func _update_background():
	if opponent_hand.is_empty():
		hand_bg.visible = false
		return
	hand_bg.visible = true
	var total_width = (opponent_hand.size() - 1) * DOMINO_WIDTH + BG_PADDING_X * 2
	var bg_x = center_screen_x - total_width / 2.0
	var bg_y = hand_y_pos - BG_HEIGHT / 2.0
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(hand_bg, "size", Vector2(total_width, BG_HEIGHT), 0.2)
	tween.tween_property(hand_bg, "position", Vector2(bg_x, bg_y), 0.2)
