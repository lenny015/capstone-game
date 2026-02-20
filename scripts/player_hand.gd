extends Node2D

const HAND_COUNT = 7
const DOMINO_SCENE_PATH = "res://scenes/domino.tscn"
const DOMINO_WIDTH = 80

var player_hand = []
var center_screen_x
var hand_y_pos

@onready var domino_manager = $"../DominoManager"

func _ready():
	center_screen_x = get_viewport().size.x / 2
	hand_y_pos = get_viewport().size.y * 0.92
	
	var domino_scene = preload(DOMINO_SCENE_PATH)
	for i in range(HAND_COUNT):
		var new_domino = domino_scene.instantiate()
		domino_manager.add_child(new_domino)
		new_domino.name = "Domino" + str(i)
		add_domino_to_hand(new_domino)
		
func add_domino_to_hand(domino):
	player_hand.insert(0, domino)
	update_hand_positions()
	
func update_hand_positions():
	for i in range(player_hand.size()):
		var new_pos = Vector2(calc_domino_pos(i), hand_y_pos)
		var domino = player_hand[i]
		animate_card_to_position(domino, new_pos)
		
		await get_tree().create_timer(0.15).timeout
		domino_manager.store_original_position(domino)
		
func calc_domino_pos(index):
	var total_width = (player_hand.size() -1) * DOMINO_WIDTH
	var x_offset = center_screen_x + index * DOMINO_WIDTH - total_width / 2.0
	return x_offset

func animate_card_to_position(domino, new_pos):
	var tween = get_tree().create_tween()
	tween.tween_property(domino, "position", new_pos, 0.1)
