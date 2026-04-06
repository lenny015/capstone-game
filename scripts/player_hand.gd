extends Node2D

const DOMINO_SCENE_PATH = "res://scenes/domino.tscn"
const DOMINO_WIDTH = 80
const BG_PADDING_X = 50
const BG_HEIGHT = 165

var player_hand = []
var center_screen_x
var hand_y_pos

@onready var domino_manager = $"../DominoManager"
@onready var hand_bg = $PlayerHandBackground

func _ready():
	center_screen_x = get_viewport().size.x / 2
	hand_y_pos = get_viewport().size.y * 0.92

func add_domino_to_hand_from_values(left: int, right: int):
	var domino_scene = preload(DOMINO_SCENE_PATH)
	var new_domino = domino_scene.instantiate()
	domino_manager.add_child(new_domino)
	new_domino.name = "Domino_" + str(left) + "_" + str(right)
	
	var boneyard = get_node("../Boneyard")
	new_domino.position = boneyard.get_node("Area2D").global_position
	
	var domino_area = new_domino.get_node("Area2D")
	domino_area.set_values(left, right)
	
	domino_area.collision_layer = 0
	domino_area.collision_mask = 0

	add_domino_to_hand(new_domino)
	
	await get_tree().create_timer(0.4).timeout
	domino_area.collision_layer = 1
	domino_area.collision_mask = 1
		
func add_domino_to_hand(domino):
	player_hand.insert(0, domino)
	update_hand_positions()
	
func remove_domino_from_hand(domino: Node2D):
	var area = domino.get_node("Area2D")
	GameState.remove_from_hand(GameState.Turn.PLAYER, [area.left_val, area.right_val])
	player_hand.erase(domino)
	domino_manager.domino_original_pos.erase(domino)
	update_hand_positions()
	
func clear_hand():
	for domino in player_hand:
		if is_instance_valid(domino):
			domino.queue_free()
	player_hand.clear()
	_update_background()
	
func update_hand_positions():
	for i in range(player_hand.size()):
		var new_pos = Vector2(calc_domino_pos(i), hand_y_pos)
		var domino = player_hand[i]
		animate_card_to_position(domino, new_pos)
	_update_background()
		
func calc_domino_pos(index):
	var total_width = (player_hand.size() -1) * DOMINO_WIDTH
	var x_offset = center_screen_x + index * DOMINO_WIDTH - total_width / 2.0
	return x_offset

func animate_card_to_position(domino, new_pos):
	var tween = get_tree().create_tween()
	tween.tween_property(domino, "position", new_pos, 0.2)
	tween.tween_callback(func():
		if is_instance_valid(domino):
			domino_manager.store_original_position(domino)
	)
	
func _update_background():
	if player_hand.is_empty():
		hand_bg.visible = false
		return
	hand_bg.visible = true
	var total_width = (player_hand.size() - 1) * DOMINO_WIDTH + BG_PADDING_X * 2
	var bg_x = center_screen_x - total_width / 2.0
	var bg_y = hand_y_pos - BG_HEIGHT / 2.0
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(hand_bg, "size", Vector2(total_width, BG_HEIGHT), 0.2)
	tween.tween_property(hand_bg, "position", Vector2(bg_x, bg_y), 0.2)
