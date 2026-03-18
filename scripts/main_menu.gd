extends Control

func _ready():
	var init = Steam.steamInitEx()
	if init["status"] != Steam.STEAM_API_INIT_RESULT_OK:
		print("Steam not running")
		return
	print("Steam OK: ", Steam.getPersonaName())

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_exit_pressed():
	get_tree().quit()
