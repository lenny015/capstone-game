extends Control

const BASE_CODE     = "LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer"
const BASE_PLAYERS  = "LobbyRoom/PanelContainer/MarginContainer/VBoxContainer"
const BASE_READY    = "LobbyRoom/ReadyBanner/MarginContainer/HBoxContainer"
const BASE_CHAT     = "LobbyRoom/RightPanel/MarginContainer/ChatVBox"

@onready var pre_lobby:   Control  = $PreLobby
@onready var status_label: Label   = $PreLobby/StatusLabel
@onready var code_input:  LineEdit = $PreLobby/JoinPanel/MarginContainer/VBoxContainer/HBoxContainer/CodeInput

@onready var lobby_room:    Control       = $LobbyRoom
@onready var code_display:  Label         = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer/Panel/MarginContainer/CodeDisplay
@onready var unlimited_btn: Button        = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer2/HBoxContainer/VBoxContainer/UnlimitedButton
@onready var match_btn:     Button        = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer2/HBoxContainer/VBoxContainer/MatchButton
@onready var points_input:  SpinBox       = $LobbyRoom/LobbyInfo/MarginContainer/HBoxContainer/CodeContainer2/HBoxContainer/PointsInput
@onready var player_slot_1: Panel         = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot1
@onready var player_slot_2: Panel         = $LobbyRoom/PanelContainer/MarginContainer/VBoxContainer/PlayerSlot2
@onready var start_button:  Button        = $LobbyRoom/ReadyBanner/MarginContainer/HBoxContainer/StartButton
@onready var ready_button:  Button        = $LobbyRoom/ReadyBanner/MarginContainer/HBoxContainer/ReadyButton
@onready var chat_log:      RichTextLabel = $LobbyRoom/RightPanel/MarginContainer/ChatVBox/ChatLog
@onready var chat_input:    LineEdit      = $LobbyRoom/RightPanel/MarginContainer/ChatVBox/ChatInputRow/ChatInput

var _style_active: StyleBoxFlat
var _style_inactive: StyleBoxFlat
var _style_active_hover: StyleBoxFlat
var _style_inactive_hover: StyleBoxFlat

var is_host:  bool = false
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

	code_input.text_changed.connect(func(new_text):
		code_input.text = new_text.to_upper()
		code_input.set_caret_column(code_input.text.length())
	)

	points_input.editable = false

	_style_active         = unlimited_btn.get_theme_stylebox("disabled")
	_style_inactive       = unlimited_btn.get_theme_stylebox("normal")
	_style_active_hover   = unlimited_btn.get_theme_stylebox("pressed")
	_style_inactive_hover = unlimited_btn.get_theme_stylebox("hover_pressed")
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
	for slot in [player_slot_1, player_slot_2]:
		for child in slot.get_children():
			child.queue_free()

	var member_count = Steam.getNumLobbyMembers(SteamManager.lobby_id)
	var slots = [player_slot_1, player_slot_2]

	for i in range(min(member_count, slots.size())):
		var steam_id    = Steam.getLobbyMemberByIndex(SteamManager.lobby_id, i)
		var player_name = Steam.getFriendPersonaName(steam_id)
		var is_rdy      = ready_states.get(steam_id, false)

		var label = Label.new()
		label.text = "%s   %s" % [player_name, "[READY]" if is_rdy else "[NOT READY]"]
		label.modulate = Color(0.4, 1.0, 0.4) if is_rdy else Color(1, 1, 1)
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		slots[i].add_child(label)

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
