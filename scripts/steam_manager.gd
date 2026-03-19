extends Node

signal steam_initialized
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_join_failed
signal player_connected(steam_id: int)
signal player_disconnected(steam_id: int)

var steam_available: bool = false
var lobby_id: int = 0
var lobby_members: Array = []

const LOBBY_MAX_MEMBERS = 2

func _ready():
	var init = Steam.steamInitEx()
	if init["status"] != Steam.STEAM_API_INIT_RESULT_OK:
		return
	steam_available = true
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	steam_initialized.emit()
	
func _process(_delta):
	if steam_available:
		Steam.run_callbacks()


#### Lobby ID / Code
func lobby_id_to_code(id: int) -> String:
	return ("%X" % id).right(6).to_upper()
	
func find_lobby_by_code(code: String) -> void:
	Steam.addRequestLobbyListStringFilter("join_code", code, Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()


#### Host
func create_lobby():
	if not steam_available:
		return
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, LOBBY_MAX_MEMBERS)
	
func _on_lobby_created(result: int, id: int):
	if result != Steam.RESULT_OK:
		return
	lobby_id = id
	var code = lobby_id_to_code(id)
	Steam.setLobbyData(id, "join_code", code)
	Steam.setLobbyData(id, "game", "domino")
	lobby_created.emit(id)
 

#### Join
func join_lobby_by_code(code: String):
	if not steam_available:
		return
	find_lobby_by_code(code.to_upper())
	
func _on_lobby_match_list(lobbies: Array) -> void:
	if lobbies.is_empty():
		lobby_join_failed.emit()
		return
	Steam.joinLobby(lobbies[0])
	
func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_join_failed.emit()
		return
	lobby_id = id
	lobby_joined.emit(id)
	

#### MultiplayerPeer
func start_as_host() -> void:
	var peer = SteamMultiplayerPeer.new()
	peer.create_host(0)
	multiplayer.multiplayer_peer = peer
	GameState.multiplayer_mode = true
	GameState.is_host = true
	
func start_as_client(host_steam_id: int) -> void:
	var peer = SteamMultiplayerPeer.new()
	peer.create_client(host_steam_id, 0)
	multiplayer.multiplayer_peer = peer
	GameState.multiplayer_mode = true
	GameState.is_host = false
	
func get_lobby_host_steam_id() -> int:
	return Steam.getLobbyOwner(lobby_id)
