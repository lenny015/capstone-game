extends Node

enum GameMode { UNLIMITED, MATCH }
enum MatchWinner { NONE, PLAYER, OPPONENT }

signal score_changed(player_score: int, opponent_score: int)
signal match_over(winner: MatchWinner, player_score: int, opponent_score: int) 

var game_mode: GameMode = GameMode.UNLIMITED
var point_target: int = 200
var player_score: int = 0
var opponent_score: int = 0
var round_number: int = 0
var last_round_points: int = 0
var capicu_pending: bool = false

func reset_match():
	player_score = 0
	opponent_score = 0
	round_number = 0
	last_round_points = 0
	capicu_pending = false
	
func reset_round():
	last_round_points = 0
	capicu_pending = false
	round_number += 1
	
func add_score(winner: GameState.Turn, base_points: int):
	var bonus = 100 if capicu_pending else 0
	var total = base_points + bonus
	last_round_points = total
 
	if winner == GameState.Turn.PLAYER:
		player_score += total
	else:
		opponent_score += total
	score_changed.emit(player_score, opponent_score)
	
func check_match_winner() ->  MatchWinner:
	if player_score >= point_target:
		match_over.emit(0, player_score, opponent_score)
		return MatchWinner.PLAYER
	if opponent_score >= point_target:
		match_over.emit(1, player_score, opponent_score)
		return MatchWinner.OPPONENT
	return MatchWinner.NONE
	
func is_match_mode():
	return game_mode == GameMode.MATCH
