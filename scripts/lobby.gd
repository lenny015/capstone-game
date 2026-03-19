extends Control

@onready var status_label = $VBoxContainer/StatusLabel
@onready var code_input = $VBoxContainer/CodeInput

func _ready():
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined.connect(_on_lobby_joined)
	SteamManager.lobby_join_failed.connect(_on_lobby_join_failed)

func _on_host_pressed():
	status_label.text = "Creating lobby..."
	SteamManager.create_lobby()

func _on_join_pressed():
	var code = code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		status_label.text = "Enter a valid 6-character code"
		return
	status_label.text = "Joining lobby: %s" % code
	SteamManager.join_lobby_by_code(code)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
func _on_lobby_created(lobby_id: int):
	var code = SteamManager.lobby_id_to_code(lobby_id)
	status_label.text = "Lobby created. Code: %s" % code

func _on_lobby_joined(lobby_id: int):
	var code = SteamManager.lobby_id_to_code(lobby_id)
	status_label.text = "Joined lobby. Code: %s" % code
	
func _on_lobby_join_failed():
	status_label.text = "Could not find that lobby code"
