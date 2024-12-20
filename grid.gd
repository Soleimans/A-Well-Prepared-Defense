extends Node2D

# Grid properties
var grid_size = Vector2(15, 5)  # 15 columns, 5 rows
var tile_size = Vector2(128, 128)  # 128x128 pixels per tile

# Building zones
var factory_columns = [0, 1]  # First two columns for factories
var defense_column = 2  # Third column for defensive buildings

# Building costs and properties
var building_costs = {
	"civilian_factory": 10800,
	"military_factory": 7200,
	"fort": 500
}

# Construction times
var construction_times = {
	"civilian_factory": 6,
	"military_factory": 4,
	"fort": 1  # Base time for first 5 levels, will be 2 for levels 6-10
}

# Dictionary to track buildings under construction
# Format: Vector2(grid_pos) : {"type": string, "turns_left": int, "total_turns": int}
var buildings_under_construction = {}

# Points system
var points = 10800  # Starting points
var points_label = null  # Reference to points label

# Dictionary to store grid occupancy and fort levels
var grid_cells = {}
var fort_levels = {}

# Currently selected building type
var selected_building_type = ""

# Preload building scenes
var civilian_factory_scene = preload("res://civilian_factory.tscn")
var military_factory_scene = preload("res://military_factory.tscn")
var fort_scene = preload("res://fort.tscn")

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
	
	# Connect to build menu signal
	print("Connecting to build menu")  # Debug print
	get_node("/root/Main/UILayer/ColorRect/build_menu").building_selected.connect(_on_building_selected)
	print("Connected to build menu")   # Debug print
	
	# Initialize points label reference
	points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label")
	if points_label:
		print("Points label found")
		points_label.text = str(points)
	else:
		print("Points label not found!")
		push_error("Points label not found at /root/Main/UILayer/ColorRect/HBoxContainer/Label")

func _process(_delta):
	queue_redraw()
	if points_label:
		points_label.text = str(points)

func _on_building_selected(type: String):
	selected_building_type = type
	print("Selected building type: ", type) # Debug print
	
func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(mouse_pos)
		print("Clicked grid position: ", grid_pos)
		print("Current selected building type: ", selected_building_type) # Debug print
		
		if selected_building_type != "" and is_valid_build_position(grid_pos, selected_building_type):
			place_building(grid_pos, selected_building_type)

func initialize_grid():
	# Create empty grid and initialize fort levels
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			grid_cells[Vector2(x, y)] = null
			fort_levels[Vector2(x, y)] = 0

func world_to_grid(world_pos: Vector2) -> Vector2:
	var local_pos = world_pos - position  # Adjust for grid position offset
	var x = floor(local_pos.x / tile_size.x)
	var y = floor(local_pos.y / tile_size.y)
	return Vector2(x, y)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	var x = grid_pos.x * tile_size.x + tile_size.x / 2
	var y = grid_pos.y * tile_size.y + tile_size.y / 2
	return Vector2(x, y)

func get_building_cost(building_type: String, grid_pos: Vector2) -> int:
	if building_type == "fort":
		return building_costs[building_type] * (fort_levels[grid_pos] + 1)
	return building_costs[building_type]

func is_valid_build_position(grid_pos: Vector2, building_type: String) -> bool:
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid_size.x or \
	   grid_pos.y < 0 or grid_pos.y >= grid_size.y:
		return false
	
	# Check if there's already a building under construction at this position
	if grid_pos in buildings_under_construction:
		print("Construction already in progress at this position")
		return false
	
	# Check building type restrictions and costs
	match building_type:
		"civilian_factory", "military_factory":
			if !factory_columns.has(int(grid_pos.x)):
				print("Invalid column for factory")
				return false
			if grid_cells[grid_pos] != null:
				print("Cell already occupied")
				return false
		"fort":
			if grid_pos.x != defense_column:
				print("Invalid column for fort")
				return false
			if fort_levels[grid_pos] >= 10:
				print("Maximum fort level reached")
				return false
	
	# Check if enough points
	var cost = get_building_cost(building_type, grid_pos)
	if points < cost:
		print("Not enough points! Cost: ", cost, " Available: ", points)
		return false
		
	return true

func place_building(grid_pos: Vector2, building_type: String):
	var cost = get_building_cost(building_type, grid_pos)
	
	# Start construction instead of instant placement
	if building_type == "fort":
		var current_level = fort_levels[grid_pos]
		var construction_time = 2 if current_level >= 5 else 1  # 2 turns for levels 6-10
		buildings_under_construction[grid_pos] = {
			"type": building_type,
			"turns_left": construction_time,
			"total_turns": construction_time,
			"target_level": current_level + 1
		}
	else:
		buildings_under_construction[grid_pos] = {
			"type": building_type,
			"turns_left": construction_times[building_type],
			"total_turns": construction_times[building_type]
		}
	
	points -= cost
	print("Construction started: ", building_type, " at ", grid_pos)

func process_construction():
	var completed_positions = []
	
	for grid_pos in buildings_under_construction:
		var construction = buildings_under_construction[grid_pos]
		construction.turns_left -= 1
		
		if construction.turns_left <= 0:
			# Construction complete - create the building
			var building
			match construction.type:
				"civilian_factory":
					building = civilian_factory_scene.instantiate()
				"military_factory":
					building = military_factory_scene.instantiate()
				"fort":
					building = fort_scene.instantiate()
					fort_levels[grid_pos] = construction.target_level
					if building.has_method("set_level"):
						building.set_level(fort_levels[grid_pos])
			
			if building:
				if construction.type == "fort" and grid_cells[grid_pos]:
					grid_cells[grid_pos].queue_free()
				building.position = grid_to_world(grid_pos)
				add_child(building)
				grid_cells[grid_pos] = building
				completed_positions.append(grid_pos)
	
	# Remove completed constructions
	for pos in completed_positions:
		buildings_under_construction.erase(pos)

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
		
	# Draw building zones with colors
	# Factory zone (green tint)
	for x in factory_columns:
		for y in range(grid_size.y):
			var rect = Rect2(x * tile_size.x, y * tile_size.y, tile_size.x, tile_size.y)
			draw_rect(rect, Color(0, 1, 0, 0.2))
	
	# Defense zone (red tint)
	for y in range(grid_size.y):
		var rect = Rect2(defense_column * tile_size.x, y * tile_size.y, tile_size.x, tile_size.y)
		draw_rect(rect, Color(1, 0, 0, 0.2))
	
	# Draw construction progress
	for grid_pos in buildings_under_construction:
		var construction = buildings_under_construction[grid_pos]
		var progress = float(construction.total_turns - construction.turns_left) / construction.total_turns
		var rect = Rect2(
			grid_pos.x * tile_size.x,
			grid_pos.y * tile_size.y,
			tile_size.x,
			tile_size.y
		)
		
		# Draw construction indicator (checkerboard pattern)
		draw_rect(rect, Color(0.7, 0.7, 0.2, 0.3))  # Light yellow tint
		
		# Draw progress bar
		var progress_rect = Rect2(
			rect.position.x,
			rect.position.y + rect.size.y - 10,
			rect.size.x * progress,
			10
		)
		draw_rect(progress_rect, Color(1, 1, 0, 0.8))  # Yellow progress bar
