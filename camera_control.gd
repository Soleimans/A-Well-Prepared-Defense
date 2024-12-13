extends Camera2D

# UI Constants
const UI_MARGIN_TOP = 64  # Space for UI at top

# Zoom limits
var min_zoom = 0.5  # Maximum zoom out (smaller number = further out)
var max_zoom = 2.0  # Maximum zoom in
var zoom_speed = 0.1
var current_zoom = 0.7

func _ready():
	# Set initial zoom level
	zoom = Vector2(current_zoom, current_zoom)
	
	var grid_node = get_parent().get_node("Grid")
	if grid_node:
		# Calculate grid dimensions
		var grid_width = grid_node.total_grid_size.x * grid_node.tile_size.x
		var grid_height = grid_node.total_grid_size.y * grid_node.tile_size.y
		
		# Set camera position, adding the UI margin to push everything down
		position = Vector2(
			grid_width / 2,
			(grid_height / 2) + UI_MARGIN_TOP
		)
		
		# Set camera limits with margins
		limit_left = -grid_width/2
		limit_top = -grid_height/2 + UI_MARGIN_TOP  # Add UI margin to top limit
		limit_right = grid_width * 1.5
		limit_bottom = grid_height * 1.5 + UI_MARGIN_TOP  # Add UI margin to bottom limit
	else:
		print("Grid node not found!")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Zoom in
			current_zoom = clamp(current_zoom - zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(current_zoom, current_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Zoom out
			current_zoom = clamp(current_zoom + zoom_speed, min_zoom, max_zoom)
			zoom = Vector2(current_zoom, current_zoom)
