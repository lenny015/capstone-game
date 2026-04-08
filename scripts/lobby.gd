extends Control

# PreLobby
@onready var pre_lobby: VBoxContainer = $PreLobby
@onready var status_label = $PreLobby/StatusLabel
@onready var code_input = $PreLobby/CodeInput

# Lobby Room
@onready var lobby_room: CenterContainer = $LobbyRoom
@onready var code_display: Label = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/CodeDisplay
@onready var player_list: VBoxContainer = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/PlayerList
@onready var ready_button: Button = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/ReadyButton
@onready var start_button: Button = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/StartButton
@onready var chat_log: RichTextLabel = $LobbyRoom/HBoxContainer/RightPanel/MarginContainer/ChatVBox/ChatLog
@onready var chat_input: LineEdit = $LobbyRoom/HBoxContainer/RightPanel/MarginContainer/ChatVBox/ChatInputRow/ChatInput
@onready var settings_panel: VBoxContainer = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/SettingsPanel
@onready var mode_button: Button = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/SettingsPanel/ModeRow/ModeButton
@onready var points_row: HBoxContainer = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/SettingsPanel/PointsRow
@onready var points_input: SpinBox = $LobbyRoom/HBoxContainer/LeftPanel/MarginContainer/LeftVBox/SettingsPanel/PointsRow/PointsInput

var is_host: bool = false
var is_ready: bool = false
var ready_states: Dictionary = {}

func _ready():
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined.connect(_on_lobby_joined)
	SteamManager.lobby_join_failed.connect(_on_lobby_join_failed)
	Steam.lobby_message.connect(_on_lobby_message)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


# Prelobby

func _on_host_pressed():
	status_label.text = "Creating lobby..."
	SteamManager.create_lobby()

func _on_join_pressed():
	var code = code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		status_label.text = "Enter a valid 6-character code"
		return
	status_label.text = "Joining lobby..."
	SteamManager.join_lobby_by_code(code)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# Entering Lobby Room

func _on_lobby_created(lobby_id: int):
	is_host = true
	var code = SteamManager.lobby_id_to_code(lobby_id)
	SteamManager.start_as_host()
	_enter_lobby_room(code)
	await get_tree().process_frame
	_refresh_player_list()

func _on_lobby_joined(lobby_id: int):
	if is_host:
		return
	var code = SteamManager.lobby_id_to_code(lobby_id)
	var host_id = SteamManager.get_lobby_host_steam_id()
	SteamManager.start_as_client(host_id)
	_enter_lobby_room(code)

func _on_lobby_join_failed():
	status_label.text = "Could not find that lobby code"

func _enter_lobby_room(code: String):
	pre_lobby.visible = false
	lobby_room.visible = true
	code_display.text = "Join Code: %s" % code
	start_button.visible = false
	settings_panel.visible = true
	if not is_host:
		ready_button.disabled = true
		ready_button.text = "Connecting..."
		mode_button.disabled = true
		points_input.editable = false


# Player List

func _refresh_player_list():
	for child in player_list.get_children():
		child.queue_free()
	var member_count = Steam.getNumLobbyMembers(SteamManager.lobby_id)
	for i in range(member_count):
		var steam_id = Steam.getLobbyMemberByIndex(SteamManager.lobby_id, i)
		var player_name = Steam.getFriendPersonaName(steam_id)
		var ready_check = ready_states.get(steam_id, false)
		var label = Label.new()
		label.text = "%s  %s" % [player_name, "[READY]" if ready_check else "[NOT READY]"]
		label.modulate = Color(0.4, 1.0, 0.4) if ready_check else Color(1, 1, 1)
		player_list.add_child(label)

func _on_lobby_chat_update(_lobby_id: int, _changed_id: int, _making_change_id: int, _chat_state: int):
	_refresh_player_list()


# Peer Connection

func _on_peer_connected(_peer_id: int):
	_add_chat_message("System", "Player connected")
	ready_button.disabled = false
	ready_button.text = "Ready"
	_refresh_player_list()
	if is_host:
		rpc("sync_settings", int(MatchState.game_mode), MatchState.point_target)
 
func _on_peer_disconnected(peer_id: int):
	_add_chat_message("System", "Player disconnected")
	ready_states.clear()
	start_button.visible = false
	_refresh_player_list()
	
	if not is_host and peer_id == 1:
		await get_tree().create_timer(1.5).timeout
		_return_to_menu()


# Buttons

func _on_ready_pressed():
	is_ready = !is_ready
	ready_button.text = "Unready" if is_ready else "Ready"
	var my_id = Steam.getSteamID()
	ready_states[my_id] = is_ready
	rpc("sync_ready", my_id, is_ready)
	_refresh_player_list()
	_check_all_ready()
	
@rpc("any_peer", "call_local")
func sync_ready(steam_id: int, rdy: bool):
	ready_states[steam_id] = rdy
	_refresh_player_list()
	_check_all_ready()
	
func _check_all_ready():
	if not is_host:
		start_button.visible = false
		return
	var member_count = Steam.getNumLobbyMembers(SteamManager.lobby_id)
	if member_count < 2:
		start_button.visible = false
		return
	for i in range(member_count):
		var steam_id = Steam.getLobbyMemberByIndex(SteamManager.lobby_id, i)
		if not ready_states.get(steam_id, false):
			start_button.visible = false
			return
	start_button.visible = true
	
func _on_mode_pressed():
	if not is_host:
		return
	if MatchState.game_mode == MatchState.GameMode.UNLIMITED:
		MatchState.game_mode = MatchState.GameMode.MATCH
		mode_button.text = "Match Mode"
		points_row.visible = true
		MatchState.point_target = int(points_input.value)
	else:
		MatchState.game_mode = MatchState.GameMode.UNLIMITED
		mode_button.text = "Unlimited"
		points_row.visible = false
	rpc("sync_settings", int(MatchState.game_mode), MatchState.point_target)

func _on_points_changed(value: float):
	if not is_host:
		return
	MatchState.point_target = int(value)
	rpc("sync_settings", int(MatchState.game_mode), MatchState.point_target)

@rpc("authority", "call_local")
func sync_settings(mode: int, target: int) -> void:
	MatchState.game_mode = mode as MatchState.GameMode
	MatchState.point_target = target
	
	if mode == MatchState.GameMode.MATCH:
		mode_button.text = "Match Mode"
		points_row.visible = true
		points_input.value = target
	else:
		mode_button.text = "Unlimited"
		points_row.visible = false

func _on_start_pressed():
	if is_host:
		rpc("start_game_rpc")
		
@rpc("authority", "call_local")
func start_game_rpc():
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _on_leave_pressed():
	_return_to_menu()
	
func _return_to_menu():
	Steam.leaveLobby(SteamManager.lobby_id)
	SteamManager.lobby_id = 0
	multiplayer.multiplayer_peer = null
	GameState.multiplayer_mode = false
	GameState.is_host = false
	GameState.reset()
	MatchState.reset_match()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	

# Chat

func _on_send_pressed():
	_send_chat()

func _on_chat_submitted(_text: String):
	_send_chat()

func _send_chat():
	var msg = chat_input.text.strip_edges()
	if msg.is_empty():
		return
	chat_input.text = ""
	Steam.sendLobbyChatMsg(SteamManager.lobby_id, msg)

func _on_lobby_message(_lobby_id: int, user: int, message: String, _type: int):
	var sender_name = Steam.getFriendPersonaName(user)
	_add_chat_message(sender_name, message)

func _add_chat_message(sender: String, message: String):
	var color = "#ffff88" if sender == "System" else "#ffffff"
	chat_log.append_text("[color=%s][b]%s:[/b][/color] %s\n" % [color, sender, message])
