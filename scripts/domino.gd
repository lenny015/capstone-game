extends Area2D
class_name Domino

var left_val: int = 0
var right_val: int = 0

@onready var right_pips: AnimatedSprite2D = $Texture/RightPip
@onready var left_pips: AnimatedSprite2D = $Texture/LeftPip

func _ready():
	set_values(3, 5)
	
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
