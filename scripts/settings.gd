extends Control

const RESOLUTION_LABELS: Array[String] = [
	"1280 x 720",
	"1600 x 900",
	"1920 x 1080"
]

var _is_fullscreen: bool = false
var _style_active: StyleBoxFlat
var _style_inactive: StyleBoxFlat
var _style_active_hover: StyleBoxFlat
var _style_inactive_hover: StyleBoxFlat

@onready var fullscreen_btn: Button = $Panel/MarginContainer/VBoxContainer/VideoSection/FullscreenRow/FullScreen
@onready var windowed_btn: Button = $Panel/MarginContainer/VBoxContainer/VideoSection/FullscreenRow/Windowed
@onready var resolution_option: OptionButton = $Panel/MarginContainer/VBoxContainer/VideoSection/ResolutionRow/ResolutionOption

func _ready() -> void:
	_style_active        = fullscreen_btn.get_theme_stylebox("disabled")
	_style_inactive      = fullscreen_btn.get_theme_stylebox("normal")
	_style_active_hover  = fullscreen_btn.get_theme_stylebox("pressed")
	_style_inactive_hover = fullscreen_btn.get_theme_stylebox("hover_pressed")

	resolution_option.clear()
	for label in RESOLUTION_LABELS:
		resolution_option.add_item(label)

	var mode := DisplayServer.window_get_mode()
	_is_fullscreen = (mode == DisplayServer.WINDOW_MODE_FULLSCREEN or
					  mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	var current_size := DisplayServer.window_get_size()
	var best := 2
	for i in range(Settings.RESOLUTIONS.size()):
		if Settings.RESOLUTIONS[i] == current_size:
			best = i
			break
	resolution_option.select(best)

	fullscreen_btn.pressed.connect(_on_fullscreen_pressed)
	windowed_btn.pressed.connect(_on_windowed_pressed)

	_update_toggle()

func _on_fullscreen_pressed() -> void:
	_is_fullscreen = true
	_update_toggle()

func _on_windowed_pressed() -> void:
	_is_fullscreen = false
	_update_toggle()

func _update_toggle() -> void:
	fullscreen_btn.add_theme_stylebox_override("normal", _style_active if _is_fullscreen else _style_inactive)
	fullscreen_btn.add_theme_stylebox_override("hover",  _style_active_hover if _is_fullscreen else _style_inactive_hover)
	windowed_btn.add_theme_stylebox_override("normal",   _style_active if not _is_fullscreen else _style_inactive)
	windowed_btn.add_theme_stylebox_override("hover",    _style_active_hover if not _is_fullscreen else _style_inactive_hover)
	resolution_option.disabled = _is_fullscreen

func _on_apply_pressed() -> void:
	if _is_fullscreen:
		Settings.apply_fullscreen()
	else:
		Settings.apply_windowed(resolution_option.selected)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
