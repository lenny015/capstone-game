extends Control

const RESOLUTION_LABELS: Array[String] = [
	"1280 x 720",
	"1600 x 900",
	"1920 x 1080"
]

@onready var resolution_option: OptionButton = $Panel/MarginContainer/VBoxContainer/VideoSection/ResolutionRow/ResolutionOption
@onready var fullscreen_check: CheckButton = $Panel/MarginContainer/VBoxContainer/VideoSection/FullscreenRow/FullscreenCheck

func _ready() -> void:
	resolution_option.clear()
	for label in RESOLUTION_LABELS:
		resolution_option.add_item(label)

	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or
						  mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fullscreen_check.button_pressed = is_fullscreen
	resolution_option.disabled = is_fullscreen

	var current_size := DisplayServer.window_get_size()
	var best := 2
	for i in range(Settings.RESOLUTIONS.size()):
		if Settings.RESOLUTIONS[i] == current_size:
			best = i
			break
	resolution_option.select(best)

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	resolution_option.disabled = toggled_on

func _on_apply_pressed() -> void:
	if fullscreen_check.button_pressed:
		Settings.apply_fullscreen()
	else:
		Settings.apply_windowed(resolution_option.selected)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
