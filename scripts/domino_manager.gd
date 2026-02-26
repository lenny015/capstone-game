extends Node2D

const HOVER_OFFSET = -15
const SELECT_OFFSET = -30
const DOMINO_SCENE_PATH = "res://scenes/domino.tscn"
const DOMINO_SLOT_SCENE_PATH = "res://scenes/domino_slot.tscn"
const TILE_W = 66
const TILE_H = 132
const SLOT_GAP = 8

var hovered_domino: Node2D = null
var selected_domino: Node2D = null
var domino_original_pos = {}

var board_head = null
var board_tail = null
var active_slots: Array = []

#end values
var head_val: int = -1
var tail_val: int = -1

@onready var boneyard = $"../Boneyard"
@onready var player_hand = $"../PlayerHand"

func _ready():
	call_deferred("_place_first_domino")
	
func _make_board_node(domino_node):
	return {
		"node": domino_node,
		"prev": null,
		"next": null
	}	

func _place_first_domino():
	if boneyard.domino_pool.is_empty():
		return
		
	var values = boneyard.domino_pool.pop_back()
	var domino_scene = preload(DOMINO_SCENE_PATH)
	var new_domino = domino_scene.instantiate()
	add_child(new_domino)
	
	new_domino.position = get_viewport().size / 2
	
	var domino_area = new_domino.get_node("Area2D")
	domino_area.set_values(values[0], values[1])
	domino_area.collision_layer = 0
	domino_area.collision_mask = 0
	new_domino.rotation_degrees = 0 if domino_area.is_double() else 90

	head_val = domino_area.left_val
	tail_val = domino_area.right_val

	var entry = _make_board_node(new_domino)
	print("left: " + str(domino_area.left_val) + ", right: " + str(domino_area.right_val))
	board_head = entry
	board_tail = entry
	
func _half_width(domino_node: Node2D) -> float:
	var r = int(domino_node.rotation_degrees) % 180
	return TILE_H / 2.0 if r == 90 else TILE_W / 2.0

func _can_place(val_a: int, val_b: int, end_val: int) -> bool:
	return val_a == end_val or val_b == end_val
	
func _spawn_slots():
	_clear_slots()
	if board_head == null:
		return

	var slot_scene = preload(DOMINO_SLOT_SCENE_PATH)
	var area = selected_domino.get_node("Area2D")
	var val_a = area.left_val
	var val_b = area.right_val
	var is_double = area.is_double()

	if _can_place(val_a, val_b, head_val):
		_spawn_slot_at_location(slot_scene, board_head["node"], Vector2(-1, 0), is_double)
		
	if _can_place(val_a, val_b, tail_val):
		_spawn_slot_at_location(slot_scene, board_tail["node"], Vector2(1, 0), is_double)
		
func _spawn_slot_at_location(slot_scene, end_node: Node2D, offset: Vector2, is_double: bool):
	var select_half = TILE_W / 2.0 if is_double else TILE_H / 2.0
	var select_rotation = 0 if is_double else 90
	var gap = _half_width(end_node) + select_half + SLOT_GAP
	var slot = slot_scene.instantiate()
	add_child(slot)
	slot.rotation_degrees = select_rotation
	slot.position = end_node.position + offset * gap
	slot.get_node("Area2D").collision_layer = 4
	slot.get_node("Area2D").collision_mask = 4
	active_slots.append(slot)
	

func _clear_slots():
	for slot in active_slots:
		if is_instance_valid(slot):
			slot.queue_free()
	active_slots.clear()

func _on_slot_clicked(slot):
	if selected_domino == null:
		return

	var domino_to_place = selected_domino
	var target_pos = slot.position
	var is_left = slot.position.x < board_head["node"].position.x

	if domino_to_place.get_parent() != self:
		domino_to_place.reparent(self, true)

	var area = domino_to_place.get_node("Area2D")
	var is_double = area.is_double()
	var end_val = head_val if is_left else tail_val
	var needs_flip = area.right_val == end_val
	var new_open = area.right_val if area.left_val == end_val else area.left_val
	
	domino_to_place.rotation_degrees = 0 if is_double else 90
	domino_to_place.position = target_pos
	area.collision_layer = 0
	area.collision_mask = 0
	
	player_hand.remove_domino_from_hand(domino_to_place)
	deselect_domino()

	var entry = _make_board_node(domino_to_place)
	var base_rotation = 0 if is_double else 90
	var flipped_rotation = 180 if is_double else 270
	if is_left:
		head_val = new_open
		entry.next = board_head
		board_head.prev = entry
		board_head = entry
		domino_to_place.rotation_degrees = flipped_rotation if not needs_flip else base_rotation
	else:
		tail_val = new_open
		entry.prev = board_tail
		board_tail.next = entry
		board_tail = entry
		domino_to_place.rotation_degrees = base_rotation if not needs_flip else flipped_rotation

	_clear_slots()
		
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _slot_raycast_check():
				return
			var domino = raycast_check()
			if domino:
				toggle_selection(domino)

func _process(_delta):
	var domino = raycast_check()
	
	if domino != hovered_domino:
		if hovered_domino and hovered_domino != selected_domino:
			move_to_origin(hovered_domino)
		hovered_domino = domino
		
		if hovered_domino and hovered_domino != selected_domino:
			lift_domino(hovered_domino, HOVER_OFFSET)

func toggle_selection(domino: Node2D):
	if selected_domino == domino:
		deselect_domino()
	else:
		if selected_domino:
			deselect_domino()
		select_domino(domino)
		
func select_domino(domino: Node2D):
	selected_domino = domino
	lift_domino(domino, SELECT_OFFSET)
	_spawn_slots()
	
func deselect_domino():
	if selected_domino:
		move_to_origin(selected_domino)
		selected_domino = null
		_clear_slots()
		
func lift_domino(domino: Node2D, offset: float):
	if not domino_original_pos.has(domino):
		domino_original_pos[domino] = domino.position.y
	
	var original_y = domino_original_pos[domino]
	var target_pos = Vector2(domino.position.x, original_y + offset)
	
	var tween = get_tree().create_tween()
	tween.tween_property(domino, "position", target_pos, 0.15)

func move_to_origin(domino: Node2D):
	if domino_original_pos.has(domino):
		var original_y = domino_original_pos[domino]
		var target_pos = Vector2(domino.position.x, original_y)
		
		var tween = get_tree().create_tween()
		tween.tween_property(domino, "position", target_pos, 0.15)

func store_original_position(domino: Node2D):
	domino_original_pos[domino] = domino.position.y

func _slot_raycast_check() :
	if active_slots.is_empty():
		return false
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 4
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		var clicked_area = result[0].collider
		var slot_node = clicked_area.get_parent()
		if slot_node in active_slots:
			_on_slot_clicked(slot_node)
			return true
		return false

func raycast_check():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 1
	
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null
