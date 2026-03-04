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
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
