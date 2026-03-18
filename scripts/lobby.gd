extends Control

@onready var status_label = $VBoxContainer/StatusLabel
@onready var code_input = $VBoxContainer/CodeInput

func _on_host_pressed():
	status_label.text = "Creating lobby..."

func _on_join_pressed():
	var code = code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		status_label.text = "Enter a valid 6-character code"
		return
	status_label.text = "Joining lobby: %s" % code

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
