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

var placed_dominoes: Array = []
var active_slots: Array = []

@onready var boneyard = $"../Boneyard"
@onready var player_hand = $"../PlayerHand"

func _ready():
	call_deferred("_place_first_domino")
	
func _place_first_domino():
	if boneyard.domino_pool.is_empty():
		return
		
	var values = boneyard.domino_pool.pop_back()
	var domino_scene = preload(DOMINO_SCENE_PATH)
	var new_domino = domino_scene.instantiate()
	add_child(new_domino)
	
	new_domino.position = get_viewport().size / 2
	new_domino.rotation_degrees = 90

	var domino_area = new_domino.get_node("Area2D")
	domino_area.set_values(values[0], values[1])
	domino_area.collision_layer = 0
	domino_area.collision_mask = 0

	placed_dominoes.append({
		"node": new_domino,
		"direction": "horizontal"
	})
	
func _spawn_slots():
	_clear_slots()
	if placed_dominoes.is_empty():
		return

	var slot_scene = preload(DOMINO_SLOT_SCENE_PATH)

	var first = placed_dominoes.front()
	var last = placed_dominoes.back()

	# Slot before first
	var slot_left = slot_scene.instantiate()
	add_child(slot_left)
	slot_left.rotation_degrees = 90
	slot_left.position = first["node"].position + Vector2(-(TILE_H + SLOT_GAP), 0)
	slot_left.get_node("Area2D").collision_layer = 4
	slot_left.get_node("Area2D").collision_mask = 4
	active_slots.append(slot_left)

	# Slot after last
	var slot_right = slot_scene.instantiate()
	add_child(slot_right)
	slot_right.rotation_degrees = 90
	slot_right.position = last["node"].position + Vector2(TILE_H + SLOT_GAP, 0)
	slot_right.get_node("Area2D").collision_layer = 4
	slot_right.get_node("Area2D").collision_mask = 4
	active_slots.append(slot_right)
	

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

	if domino_to_place.get_parent() != self:
		domino_to_place.reparent(self, true)

	domino_to_place.rotation_degrees = 90
	domino_to_place.position = target_pos

	domino_to_place.get_node("Area2D").collision_layer = 0
	domino_to_place.get_node("Area2D").collision_mask = 0
	
	player_hand.remove_domino_from_hand(domino_to_place)
	deselect_domino()

	placed_dominoes.append({
		"node": domino_to_place,
		"direction": "horizontal"
	})

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
