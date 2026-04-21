extends CanvasLayer

@onready var player_bg = $"../PlayerHand/PlayerHandBackground"
@onready var opponent_bg = $"../OpponentHand/OpponentHandBackground"
@onready var game_over_banner = $GameOverBanner
@onready var game_over_label = $GameOverBanner/VBoxContainer/GameOverLabel
@onready var button_row = $GameOverBanner/VBoxContainer/ButtonRow
@onready var rematch_button = $GameOverBanner/VBoxContainer/ButtonRow/RematchButton
@onready var lobby_button = $GameOverBanner/VBoxContainer/ButtonRow/LobbyButton
@onready var score_display = $ScoreDisplay
@onready var player_score_label = $ScoreDisplay/ScoreVBox/PlayerScoreLabel
@onready var opponent_score_label = $ScoreDisplay/ScoreVBox/OpponentScoreLabel

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
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	MatchState.score_changed.connect(_on_score_changed)
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
	if MatchState.is_match_mode():
		score_display.visible = true
		_on_score_changed(MatchState.player_score, MatchState.opponent_score)

func _on_turn_changed(whose_turn: GameState.Turn):
	if whose_turn == GameState.Turn.PLAYER:
		_fade_border(opponent_bg, BORDER_COLOR_OFF)
		_fade_border(player_bg, BORDER_COLOR_ON)
	else:
		_fade_border(player_bg, BORDER_COLOR_OFF)
		_fade_border(opponent_bg, BORDER_COLOR_ON)

func _on_score_changed(player_score: int, opponent_score: int) -> void:
	player_score_label.text = "%d" % player_score
	opponent_score_label.text = "%d" % opponent_score

func _on_game_over(winner: GameState.Turn, reason: String):
	_fade_border(player_bg, BORDER_COLOR_OFF)
	_fade_border(opponent_bg, BORDER_COLOR_OFF)
	if MatchState.is_match_mode():
		_on_round_over(winner, reason)
	else:
		_on_unlimited_game_over(winner, reason)

func _on_unlimited_game_over(winner: GameState.Turn, reason: String):
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
	
func _on_round_over(winner: GameState.Turn, reason: String):
	var points = MatchState.last_round_points
	var won = winner == GameState.Turn.PLAYER
	var result_text = ""
	if won:
		result_text = "Round Won!\n+%d points" % points
	else:
		result_text = "Round Lost"
	if reason == "draw":
		result_text = "Draw — No points"
	if MatchState.capicu_pending and won:
		var capicu_bonus = int(round(MatchState.point_target * 0.25 / 5.0) * 5)
		result_text = "Capicú! \n+%d points (+%d bonus)" % [points, capicu_bonus]
	game_over_label.text = result_text
	_set_banner_color(BANNER_COLOR)
	game_over_banner.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(game_over_banner, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(_fade_out_board)
	tween.tween_interval(2.5)
	tween.tween_callback(_check_match_result)
	
func _check_match_result():
	var match_winner = MatchState.check_match_winner()
	if match_winner == MatchState.MatchWinner.NONE:
		MatchState.reset_round()
		get_tree().change_scene_to_file("res://scenes/game_board.tscn")
	else:
		var won = match_winner == MatchState.MatchWinner.PLAYER
		game_over_label.text = "You Win the Match!\n%d — %d" % [MatchState.player_score, MatchState.opponent_score] if won else "Opponent Wins the Match!\n%d — %d" % [MatchState.player_score, MatchState.opponent_score]
		game_over_banner.modulate.a = 0.0
		game_over_banner.visible = true
		var tween = get_tree().create_tween()
		tween.tween_property(game_over_banner, "modulate:a", 1.0, FADE_DURATION)
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
	button_row.visible = true
	rematch_votes = 0
	i_voted_rematch = false
	if not GameState.multiplayer_mode:
		lobby_button.visible = true
		lobby_button.text = "Back to Menu"
		rematch_button.text = "Rematch"
	else:
		lobby_button.visible = true
		lobby_button.text = "Back to Lobby"
		rematch_button.text = "Rematch?"

func _on_rematch_pressed():
	if not GameState.multiplayer_mode:
		GameState.reset()
		get_tree().change_scene_to_file("res://scenes/game_board.tscn")
		return
	if i_voted_rematch:
		return
	i_voted_rematch = true
	rematch_button.disabled = true
	get_node("../DominoManager").rpc("sync_rematch_vote")

func _on_lobby_pressed():
	if not GameState.multiplayer_mode:
		GameState.reset()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	get_node("../DominoManager").rpc("sync_return_to_lobby")

func on_rematch_vote_received():
	rematch_votes += 1
	rematch_button.text = "Rematch %d/2" % rematch_votes
	if rematch_votes >= 2:
		_do_rematch()

func on_return_to_lobby():
	_do_return_to_lobby()

func _do_rematch():
	MatchState.reset_round()
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/game_board.tscn")

func _do_return_to_lobby():
	MatchState.reset_match()
	GameState.reset()
	if GameState.multiplayer_mode:
		GameState.multiplayer_mode = false
		GameState.is_host = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

func _on_peer_disconnected(_peer_id: int):
	if not GameState.multiplayer_mode:
		return
	var was_host = GameState.is_host
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
	MatchState.reset_match()
	GameState.reset()
	GameState.multiplayer_mode = false
	GameState.is_host = false
	multiplayer.multiplayer_peer = null
	if not was_host:
		get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
