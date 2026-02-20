extends Area2D
class_name Domino

var left_val: int = 0
var right_val: int = 0

@onready var right_pips: AnimatedSprite2D = $"../Tile/RightPip"
@onready var left_pips: AnimatedSprite2D = $"../Tile/LeftPip"
	
func set_values(left: int, right: int):
	left_val = left
	right_val = right
	update_visuals()
	
func update_visuals():
	left_pips.play("default")
	right_pips.play("default")
	
	left_pips.frame = left_val
	right_pips.frame = right_val
	
	left_pips.pause()
	right_pips.pause()
	
func is_double() -> bool:
	return left_val == right_val
	
func get_total_pips() -> int:
	return left_val + right_val
