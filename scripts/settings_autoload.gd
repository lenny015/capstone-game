# Autoload: Settings
extends Node

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

func apply_windowed(res_index: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var res := RESOLUTIONS[res_index]
	var current_screen := DisplayServer.window_get_current_screen()
	var screen_pos := DisplayServer.screen_get_position(current_screen)
	var screen_size := DisplayServer.screen_get_size(current_screen)
	var centered_pos := screen_pos + (screen_size - res) / 2
	DisplayServer.window_set_size(res)
	DisplayServer.window_set_position(centered_pos)

func apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
