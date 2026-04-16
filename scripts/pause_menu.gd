extends Control

@onready var restart_button = $VBoxContainer/RestartButton

func _ready():
	hide()
	restart_button.visible = not GameState.multiplayer_mode

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
	GameState.reset()
	MatchState.reset_match()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_restart_pressed():
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")
 
