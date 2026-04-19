extends Control

const BASE_CODE     = "LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer"
const BASE_PLAYERS  = "LobbyRoom/PanelContainer/MarginContainer/VBoxContainer"
const BASE_READY    = "LobbyRoom/ReadyBanner/MarginContainer/HBoxContainer"
const BASE_CHAT     = "LobbyRoom/RightPanel/MarginContainer/ChatVBox"

@onready var pre_lobby:   Control  = $PreLobby
@onready var status_label: Label   = $PreLobby/StatusLabel
@onready var code_input:  LineEdit = $PreLobby/JoinPanel/MarginContainer/VBoxContainer/HBoxContainer/CodeInput
@onready var domino1 = $Control/MarginContainer/CenterContainer/Dominos/Domino
@onready var domino2 = $Control/MarginContainer/CenterContainer/Dominos/Domino2

@onready var lobby_room:    Control       = $LobbyRoom
@onready var code_display:  Label         = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer/Panel/MarginContainer/CodeDisplay
@onready var unlimited_btn: Button        = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer2/HBoxContainer/VBoxContainer/UnlimitedButton
@onready var match_btn:     Button        = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer2/HBoxContainer/VBoxContainer/MatchButton
@onready var points_input:  SpinBox       = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer2/HBoxContainer/PointsInput
@onready var player_slot_1: Panel         = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot1
@onready var player_slot_2: Panel         = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot2
@onready var slot1_content: MarginContainer = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot1/MarginContainer
@onready var slot1_username: Label          = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot1/MarginContainer/HBoxContainer/Username
@onready var slot1_ready_panel: Panel       = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot1/MarginContainer/HBoxContainer/ReadyIndicator
@onready var slot1_ready: Label             = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot1/MarginContainer/HBoxContainer/ReadyIndicator/MarginContainer/ReadyLabel
@onready var slot2_content: MarginContainer = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot2/MarginContainer
@onready var slot2_username: Label          = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot2/MarginContainer/HBoxContainer/Username
@onready var slot2_ready_panel: Panel       = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot2/MarginContainer/HBoxContainer/ReadyIndicator
@onready var slot2_ready: Label             = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot2/MarginContainer/HBoxContainer/ReadyIndicator/MarginContainer/ReadyLabel
@onready var start_button:  Button        = $LobbyRoom/ReadyBanner/MarginContainer/HBoxContainer/StartButton
@onready var ready_button:  Button        = $LobbyRoom/ReadyBanner/MarginContainer/HBoxContainer/ReadyButton
@onready var chat_log:      RichTextLabel = $LobbyRoom/RightPanel/MarginContainer/ChatVBox/ChatLog
@onready var chat_input:    LineEdit      = $LobbyRoom/RightPanel/MarginContainer/ChatVBox/ChatInputRow/ChatInput

var _style_active: StyleBoxFlat
var _style_inactive: StyleBoxFlat
var _style_active_hover: StyleBoxFlat
var _style_inactive_hover: StyleBoxFlat
var _style_ready: StyleBoxFlat
var _style_not_ready: StyleBoxFlat

var is_host:  bool = false
var is_ready: bool = false
var ready_states: Dictionary = {}

func _ready():
	domino1.get_node("Area2D").set_values(Settings.menu_domino_1[0], Settings.menu_domino_1[1])
	domino2.get_node("Area2D").set_values(Settings.menu_domino_2[0], Settings.menu_domino_2[1])
	SteamManager.lobby_created.connect(_on_lobby_created)
	SteamManager.lobby_joined.connect(_on_lobby_joined)
	SteamManager.lobby_join_failed.connect(_on_lobby_join_failed)
	Steam.lobby_message.connect(_on_lobby_message)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	code_input.text_changed.connect(func(new_text):
		code_input.text = new_text.to_upper()
		code_input.set_caret_column(code_input.text.length())
	)

	points_input.editable = false
	var spinbox_style := StyleBoxFlat.new()
	spinbox_style.bg_color = Color(0.9607843, 0.93333334, 0.8627451, 0.14117648)
	spinbox_style.border_width_left = 2
	spinbox_style.border_width_top = 2
	spinbox_style.border_width_right = 2
	spinbox_style.border_width_bottom = 2
	spinbox_style.border_color = Color(0.3529412, 0.5647059, 0.9411765, 1)
	spinbox_style.corner_radius_top_left = 10
	spinbox_style.corner_radius_top_right = 10
	spinbox_style.corner_radius_bottom_right = 10
	spinbox_style.corner_radius_bottom_left = 10
	var line_edit = points_input.get_line_edit()
	line_edit.add_theme_stylebox_override("normal", spinbox_style)
	line_edit.add_theme_stylebox_override("focus", spinbox_style)
	line_edit.add_theme_stylebox_override("read_only", spinbox_style)

	_style_active         = unlimited_btn.get_theme_stylebox("disabled")
	_style_inactive       = unlimited_btn.get_theme_stylebox("normal")
	_style_active_hover   = unlimited_btn.get_theme_stylebox("pressed")
	_style_inactive_hover = unlimited_btn.get_theme_stylebox("hover_pressed")
	_style_not_ready = slot1_ready_panel.get_theme_stylebox("panel")
	var ready_style := StyleBoxFlat.new()
	ready_style.bg_color = Color(0.18, 0.55, 0.27, 0.6)
	ready_style.border_width_left = 1
	ready_style.border_width_top = 1
	ready_style.border_width_right = 1
	ready_style.border_width_bottom = 1
	ready_style.border_color = Color(0.3, 0.85, 0.45, 1)
	ready_style.corner_radius_top_left = 10
	ready_style.corner_radius_top_right = 10
	ready_style.corner_radius_bottom_right = 10
	ready_style.corner_radius_bottom_left = 10
	_style_ready = ready_style
	_update_mode_toggle()


# PreLobby

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

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")


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
	code_display.text = code
	start_button.disabled = true
	start_button.text = "Waiting for players"
	if not is_host:
		ready_button.disabled = true
		ready_button.text = "Connecting..."
		unlimited_btn.disabled = true
		match_btn.disabled = true
		points_input.editable = false


# Player List

func _refresh_player_list():
	var member_count = Steam.getNumLobbyMembers(SteamManager.lobby_id)
	var contents     = [slot1_content, slot2_content]
	var usernames    = [slot1_username, slot2_username]
	var ready_panels = [slot1_ready_panel, slot2_ready_panel]
	var ready_labels = [slot1_ready, slot2_ready]

	for i in range(contents.size()):
		if i < member_count:
			var steam_id    = Steam.getLobbyMemberByIndex(SteamManager.lobby_id, i)
			var player_name = Steam.getFriendPersonaName(steam_id)
			var is_rdy      = ready_states.get(steam_id, false)
			contents[i].visible      = true
			usernames[i].text        = player_name
			ready_labels[i].text     = "Ready" if is_rdy else "Not Ready"
			ready_labels[i].modulate = Color(1, 1, 1)
			ready_panels[i].add_theme_stylebox_override("panel", _style_ready if is_rdy else _style_not_ready)
		else:
			contents[i].visible = false

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
	start_button.disabled = true
	start_button.text = "Waiting for players"
	_refresh_player_list()
	if not is_host and peer_id == 1:
		await get_tree().create_timer(1.5).timeout
		_return_to_menu()


# Game Mode Toggle

func _on_unlimited_pressed():
	if not is_host:
		return
	MatchState.game_mode = MatchState.GameMode.UNLIMITED
	MatchState.point_target = 0
	_update_mode_toggle()
	rpc("sync_settings", int(MatchState.game_mode), MatchState.point_target)

func _on_match_pressed():
	if not is_host:
		return
	MatchState.game_mode = MatchState.GameMode.MATCH
	MatchState.point_target = int(points_input.value)
	_update_mode_toggle()
	rpc("sync_settings", int(MatchState.game_mode), MatchState.point_target)

func _update_mode_toggle():
	var is_match = (MatchState.game_mode == MatchState.GameMode.MATCH)
	points_input.editable = is_match
	if _style_active and _style_inactive:
		unlimited_btn.add_theme_stylebox_override("normal", _style_inactive if is_match else _style_active)
		unlimited_btn.add_theme_stylebox_override("hover",  _style_inactive_hover if is_match else _style_active_hover)
		match_btn.add_theme_stylebox_override("normal",     _style_active   if is_match else _style_inactive)
		match_btn.add_theme_stylebox_override("hover",      _style_active_hover if is_match else _style_inactive_hover)

func _on_points_changed(value: float):
	if not is_host:
		return
	MatchState.point_target = int(value)
	rpc("sync_settings", int(MatchState.game_mode), MatchState.point_target)

@rpc("authority", "call_local")
func sync_settings(mode: int, target: int) -> void:
	MatchState.game_mode   = mode as MatchState.GameMode
	MatchState.point_target = target
	_update_mode_toggle()
	if mode == MatchState.GameMode.MATCH:
		points_input.value = target


# Ready / Start

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
		return
	var member_count = Steam.getNumLobbyMembers(SteamManager.lobby_id)
	if member_count < 2:
		start_button.disabled = true
		start_button.text = "Waiting for players"
		return
	for i in range(member_count):
		var steam_id = Steam.getLobbyMemberByIndex(SteamManager.lobby_id, i)
		if not ready_states.get(steam_id, false):
			start_button.disabled = true
			start_button.text = "Waiting for players"
			return
	start_button.disabled = false
	start_button.text = "Start Game"

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
