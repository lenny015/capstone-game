extends Control

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _on_multiplayer_pressed():
	# Change to lobby scene
	pass

func _on_exit_pressed():
	get_tree().quit()
