extends Control

@onready var domino1 = $Control/MarginContainer/CenterContainer/Dominos/Domino
@onready var domino2 = $Control/MarginContainer/CenterContainer/Dominos/Domino2

func _ready():
	var d1 = Settings.menu_domino_1
	var d2 = Settings.menu_domino_2
	domino1.get_node("Area2D").set_values(d1[0], d1[1])
	domino2.get_node("Area2D").set_values(d2[0], d2[1])

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _on_multiplayer_pressed():
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_exit_pressed():
	get_tree().quit()
