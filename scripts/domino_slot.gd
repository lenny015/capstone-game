extends Area2D

signal slot_clicked(slot)

var dir
var is_head: bool

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		slot_clicked.emit(get_parent())
