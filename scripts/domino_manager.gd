extends Node2D

const HOVER_OFFSET = -15
const SELECT_OFFSET = -30

var hovered_domino: Node2D = null
var selected_domino: Node2D = null
var domino_original_pos = {}

func _ready():
	pass


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
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
	print("Selected domino")
	
func deselect_domino():
	if selected_domino:
		move_to_origin(selected_domino)
		selected_domino = null
		print("Deselected domino")
		
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
