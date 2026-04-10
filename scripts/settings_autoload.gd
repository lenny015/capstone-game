# Autoload: Settings
extends Node

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

func apply_windowed(res_index: int) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(RESOLUTIONS[res_index])
	var screen_size := DisplayServer.screen_get_size()
	var window_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position((screen_size - window_size) / 2)

func apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
