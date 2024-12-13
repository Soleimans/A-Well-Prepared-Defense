extends Node2D

# Grid properties
var grid_size = Vector2(15, 5)  # 15 columns, 5 rows
var tile_size = Vector2(128, 128)  # 128x128 pixels per tile

# Building zones
var factory_columns = [0, 1]  # First two columns for factories
var defense_column = 2  # Third column for defensive buildings

# Dictionary to store grid occupancy
var grid_cells = {}

# Preload building scenes
var factory_scene = preload("res://factory.tscn")  # You'll need to create this
var defense_scene = preload("res://defense.tscn")  # You'll need to create this

var playable_area = Vector2(15, 5)
var total_grid_size = Vector2(15, 5)  # Now matches playable area

func _ready():
	initialize_grid()
	print("Factory columns: ", factory_columns)
	
	# Center the grid with equal margins on all sides
	var viewport_size = get_viewport_rect().size
	var grid_width = grid_size.x * tile_size.x
	var grid_height = grid_size.y * tile_size.y
	
	# Calculate centering position
	var x_offset = (viewport_size.x - grid_width) / 2
	var y_offset = (viewport_size.y - grid_height) / 2
	
	# Set grid position
	position = Vector2(x_offset, y_offset)

func _process(_delta):
	queue_redraw()
	
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(mouse_pos)
		print("Clicked grid position: ", grid_pos)
		
		# Determine building type based on column
		var building_type = ""
		if factory_columns.has(int(grid_pos.x)):
			building_type = "factory"
			print("Should be factory position - column: ", grid_pos.x)
		elif grid_pos.x == defense_column:
			building_type = "defense"
			print("Should be defense position - column: ", grid_pos.x)
			
		print("Building type selected: ", building_type)
		print("Is position valid?: ", is_valid_build_position(grid_pos, building_type))
		
		if building_type != "" and is_valid_build_position(grid_pos, building_type):
			place_building(grid_pos, building_type)

func initialize_grid():
	# Create empty grid
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			grid_cells[Vector2(x, y)] = null

func world_to_grid(world_pos: Vector2) -> Vector2:
	var x = floor(world_pos.x / tile_size.x)
	var y = floor(world_pos.y / tile_size.y)
	return Vector2(x, y)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	var x = grid_pos.x * tile_size.x + tile_size.x / 2
	var y = grid_pos.y * tile_size.y + tile_size.y / 2
	return Vector2(x, y)

func is_valid_build_position(grid_pos: Vector2, building_type: String) -> bool:
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid_size.x or \
	   grid_pos.y < 0 or grid_pos.y >= grid_size.y:
		return false
	
	# Check if cell is already occupied
	if grid_cells[grid_pos] != null:
		return false
	
	# Check building type restrictions
	match building_type:
		"factory":
			return factory_columns.has(int(grid_pos.x))
		"defense":
			return grid_pos.x == defense_column
	
	return false

func place_building(grid_pos: Vector2, building_type: String):
	var building
	match building_type:
		"factory":
			building = factory_scene.instantiate()
		"defense":
			building = defense_scene.instantiate()
	
	if building:
		building.position = grid_to_world(grid_pos)
		add_child(building)
		grid_cells[grid_pos] = building
		print("Placed ", building_type, " at ", grid_pos)

func _draw():
	# Draw background area (darker green)
	var full_width = total_grid_size.x * tile_size.x
	var full_height = total_grid_size.y * tile_size.y
	var background_rect = Rect2(0, 0, full_width, full_height)
	draw_rect(background_rect, Color(0.2, 0.4, 0.2, 1.0))
	
	# Draw playable area (lighter green)
	var playable_rect = Rect2(0, 0, playable_area.x * tile_size.x, playable_area.y * tile_size.y)
	draw_rect(playable_rect, Color(0.3, 0.6, 0.3, 1.0))
	
	# Draw vertical lines for playable area
	for x in range(grid_size.x + 1):
		var from = Vector2(x * tile_size.x, 0)
		var to = Vector2(x * tile_size.x, grid_size.y * tile_size.y)
		draw_line(from, to, Color.BLACK, 2.0)
	
	# Draw horizontal lines for playable area
	for y in range(grid_size.y + 1):
		var from = Vector2(0, y * tile_size.y)
		var to = Vector2(grid_size.x * tile_size.x, y * tile_size.y)
		draw_line(from, to, Color.BLACK, 2.0)
		
	# Draw building zones (optional visual feedback)
	for x in factory_columns:
		for y in range(grid_size.y):
			var rect = Rect2(x * tile_size.x, y * tile_size.y, tile_size.x, tile_size.y)
			draw_rect(rect, Color(0, 1, 0, 0.2))
	
	for y in range(grid_size.y):
		var rect = Rect2(defense_column * tile_size.x, y * tile_size.y, tile_size.x, tile_size.y)
		draw_rect(rect, Color(1, 0, 0, 0.2))
