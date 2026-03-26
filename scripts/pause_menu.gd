extends Control

func _ready():
	hide()

func open():
	show()
	get_tree().paused = true

func close():
	hide()
	get_tree().paused = false

func _on_resume_pressed():
	close()

func _on_exit_to_menu_pressed():
	get_tree().paused = false
	if GameState.multiplayer_mode:
		multiplayer.multiplayer_peer = null
		GameState.multiplayer_mode = false
		GameState.is_host = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
