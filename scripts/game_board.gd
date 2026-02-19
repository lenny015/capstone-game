extends Node2D

func _ready():
	var domino_scene = preload("res://scenes/domino.tscn")
	
	# Test Dominoes
	for i in range(7):
		var domino = domino_scene.instantiate()
		domino.position = Vector2(100 + i * 80, 400)
		add_child(domino)
		domino.set_values(i, 6 - i)
