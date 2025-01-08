extends Camera2D

const UI_MARGIN_TOP = 64  

var min_zoom = 0.5  
var max_zoom = 2.0  
var zoom_speed = 0.1
var current_zoom = 0.7

var camera_speed = 1000

func _ready():
	zoom = Vector2(current_zoom, current_zoom)
	
	var grid_node = get_parent().get_node("Grid")
	if grid_node:
		# Calculate grid dimensions
		var grid_width = grid_node.total_grid_size.x * grid_node.tile_size.x
		var grid_height = grid_node.total_grid_size.y * grid_node.tile_size.y
		
		position = Vector2(
			grid_width / 2,
			(grid_height / 2) + UI_MARGIN_TOP
		)
		
		limit_left = -grid_width/2
		limit_top = -grid_height/2 + UI_MARGIN_TOP  
		limit_right = grid_width * 1.5
		limit_bottom = grid_height * 1.5 + UI_MARGIN_TOP  
	else:
		print("Grid node not found!")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(current_zoom, current_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(current_zoom, current_zoom)

func _process(delta):
	var input_dir = Vector2.ZERO
	
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		position += input_dir * camera_speed * (1.0 / current_zoom) * delta
	
	position.x = clamp(position.x, limit_left, limit_right)
	position.y = clamp(position.y, limit_top, limit_bottom)
