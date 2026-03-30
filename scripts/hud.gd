extends CanvasLayer

@onready var player_bg = $"../PlayerHand/PlayerHandBackground"
@onready var opponent_bg = $"../OpponentHand/OpponentHandBackground"
@onready var game_over_banner = $GameOverBanner
@onready var game_over_label = $GameOverBanner/VBoxContainer/GameOverLabel
@onready var button_row = $GameOverBanner/VBoxContainer/ButtonRow
@onready var rematch_button = $GameOverBanner/VBoxContainer/ButtonRow/RematchButton
@onready var lobby_button = $GameOverBanner/VBoxContainer/ButtonRow/LobbyButton

const BORDER_COLOR_ON = Color(240, 226, 153, 1)
const BORDER_COLOR_OFF = Color(1.0, 1.0, 1.0, 0.0)
const BORDER_WIDTH = 3
const FADE_DURATION = 0.3

const BANNER_COLOR = Color("02137aff")

var rematch_votes: int = 0
var i_voted_rematch: bool = false

func _ready():
	GameState.turn_changed.connect(_on_turn_changed)
	GameState.game_over.connect(_on_game_over)
	_set_border_width(player_bg, BORDER_WIDTH)
	_set_border_width(opponent_bg, BORDER_WIDTH)
	_set_border_color(player_bg, BORDER_COLOR_OFF)
	_set_border_color(opponent_bg, BORDER_COLOR_OFF)
	_fade_border(player_bg, BORDER_COLOR_ON)
	game_over_banner.modulate.a = 0.0
	game_over_banner.visible = false
	button_row.visible = false
	rematch_button.pressed.connect(_on_rematch_pressed)
	lobby_button.pressed.connect(_on_lobby_pressed)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
func _on_turn_changed(whose_turn: GameState.Turn):
	if whose_turn == GameState.Turn.PLAYER:
		_fade_border(opponent_bg, BORDER_COLOR_OFF)
		_fade_border(player_bg, BORDER_COLOR_ON)
	else:
		_fade_border(player_bg, BORDER_COLOR_OFF)
		_fade_border(opponent_bg, BORDER_COLOR_ON)

func _on_game_over(winner: GameState.Turn, reason: String):
	_fade_border(player_bg, BORDER_COLOR_OFF)
	_fade_border(opponent_bg, BORDER_COLOR_OFF)
	
	if winner == GameState.Turn.PLAYER:
		game_over_label.text = "You Win!" if reason == "empty_hand" else "You Win! (Fewer Pips)"
	else:
		game_over_label.text = "Opponent Wins" if reason == "empty_hand" else "Opponent Wins (Fewer Pips)"
	_set_banner_color(BANNER_COLOR)
		
	game_over_banner.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(game_over_banner, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(_fade_out_board)
	tween.tween_callback(_show_postgame_buttons)
		
func _set_banner_color(color: Color):
	var stylebox = game_over_banner.get_theme_stylebox("panel") as StyleBoxFlat
	if stylebox:
		stylebox.bg_color = color

func _fade_border(panel: Panel, target_color: Color):
	var stylebox = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not stylebox:
		return
	var tween = get_tree().create_tween()
	tween.tween_method(
		func(c: Color): stylebox.border_color = c,
		stylebox.border_color,
		target_color,
		FADE_DURATION
	)

func _set_border_width(panel: Panel, width: int):
	var stylebox = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not stylebox:
		return
	stylebox.set_border_width_all(width)

func _set_border_color(panel: Panel, color: Color):
	var stylebox = panel.get_theme_stylebox("panel") as StyleBoxFlat
	if not stylebox:
		return
	stylebox.border_color = color
	
func _fade_out_board():
	var board = get_node("../DominoManager/BoardRoot")
	var tween = get_tree().create_tween()
	tween.tween_property(board, "modulate:a", 0.0, 0.6)
	
func _show_postgame_buttons():
	if not GameState.multiplayer_mode:
		return
	button_row.visible = true
	rematch_votes = 0
	i_voted_rematch = false
	
func _on_rematch_pressed():
	if i_voted_rematch:
		return
	i_voted_rematch = true
	rematch_button.disabled = true
	get_node("../DominoManager").rpc("sync_rematch_vote")
 
func _on_lobby_pressed():
	get_node("../DominoManager").rpc("sync_return_to_lobby")
	
func on_rematch_vote_received():
	rematch_votes += 1
	rematch_button.text = "Rematch %d/2" % rematch_votes
	if rematch_votes >= 2:
		_do_rematch()
 
func on_return_to_lobby():
	_do_return_to_lobby()
	
func _do_rematch():
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")
 
func _do_return_to_lobby():
	GameState.reset()
	if GameState.multiplayer_mode:
		GameState.multiplayer_mode = false
		GameState.is_host = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	
func _on_peer_disconnected(_peer_id: int):
	if not GameState.multiplayer_mode:
		return
	var player_name = "Opponent"
	var member_count = Steam.getNumLobbyMembers(SteamManager.lobby_id)
	for i in range(member_count):
		var steam_id = Steam.getLobbyMemberByIndex(SteamManager.lobby_id, i)
		if steam_id != Steam.getSteamID():
			player_name = Steam.getFriendPersonaName(steam_id)
			break
	game_over_label.text = "%s disconnected" % player_name
	_set_banner_color(Color(0.15, 0.15, 0.15, 0.95))
	game_over_banner.visible = true
	game_over_banner.modulate.a = 1.0
	button_row.visible = false
	await get_tree().create_timer(2.5).timeout
	GameState.reset()
	GameState.multiplayer_mode = false
	GameState.is_host = false
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
