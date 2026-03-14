extends CanvasLayer

@onready var player_bg = $"../PlayerHand/PlayerHandBackground"
@onready var opponent_bg = $"../OpponentHand/OpponentHandBackground"
@onready var game_over_banner = $GameOverBanner
@onready var game_over_label = $GameOverBanner/GameOverLabel

const BORDER_COLOR_ON = Color(240, 226, 153, 1)
const BORDER_COLOR_OFF = Color(1.0, 1.0, 1.0, 0.0)
const BORDER_WIDTH = 3
const FADE_DURATION = 0.3

const BANNER_COLOR_WIN = Color(0.173, 0.706, 0.175, 0.92)
const BANNER_COLOR_LOSE = Color(0.773, 0.217, 0.213, 0.92)

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
		_set_banner_color(BANNER_COLOR_WIN)
	else:
		game_over_label.text = "Opponent Wins" if reason == "empty_hand" else "Opponent Wins (Fewer Pips)"
		_set_banner_color(BANNER_COLOR_LOSE)
		
	game_over_banner.visible = true
	var tween = get_tree().create_tween()
	tween.tween_property(game_over_banner, "modulate:a", 1.0, FADE_DURATION)
	
	tween.tween_callback(_fade_out_board)
		
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
