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
var military_points = 0  # Starting military points
var military_points_label = null  # Reference to military points label

# Dictionary to store grid occupancy and fort levels
var grid_cells = {}
var fort_levels = {}

# Currently selected building type
var selected_building_type = ""

# Unit management
var units_in_cells = {}
const MAX_UNITS_PER_CELL = 3
var selected_unit_type = ""
var unit_scenes = {
	"infantry": preload("res://infantry.tscn"),
	"armoured": preload("res://armoured.tscn"),
	"garrison": preload("res://garrison.tscn")
}

const UNIT_COSTS = {
	"infantry": 1000,
	"armoured": 3000,
	"garrison": 500
}

# Unit movement
var selected_unit = null  # Currently selected unit
var valid_move_tiles = []  # Tiles where the selected unit can move
var unit_start_pos = null  # Starting position of the selected unit

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
	
	# Initialize unit tracking
	for y in range(grid_size.y):
		units_in_cells[Vector2(0, y)] = []
	
	# Connect to build menu signal
	print("Connecting to build menu")  # Debug print
	get_node("/root/Main/UILayer/ColorRect/build_menu").building_selected.connect(_on_building_selected)
	print("Connected to build menu")   # Debug print
	
	# Connect to army menu signal
	get_node("/root/Main/UILayer/ColorRect/army_menu").unit_selected.connect(_on_unit_selected)
	
	# Initialize points label reference
	points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label")
	if points_label:
		print("Points label found")
		points_label.text = str(points)
	else:
		print("Points label not found!")
		push_error("Points label not found at /root/Main/UILayer/ColorRect/HBoxContainer/Label")
		
	# Initialize military points label reference
	military_points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label2")
	if military_points_label:
		print("Military points label found")
		military_points_label.text = str(military_points)
	else:
		print("Military points label not found!")
		push_error("Military points label not found at /root/Main/UILayer/ColorRect/HBoxContainer/Label2")

func _process(_delta):
	queue_redraw()
	if points_label:
		points_label.text = str(points)
	if military_points_label:
		military_points_label.text = str(military_points)

func _on_building_selected(type: String):
	selected_building_type = type
	selected_unit_type = ""  # Clear unit selection when building is selected
	selected_unit = null  # Clear unit selection
	valid_move_tiles.clear()  # Clear valid move tiles
	print("Selected building type: ", type) # Debug print

func _on_unit_selected(type: String):
	selected_unit_type = type
	selected_building_type = ""  # Clear building selection when unit is selected
	selected_unit = null  # Clear unit selection
	valid_move_tiles.clear()  # Clear valid move tiles
	print("Selected unit type: ", type)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(mouse_pos)
		
		if selected_building_type != "" and is_valid_build_position(grid_pos, selected_building_type):
			place_building(grid_pos, selected_building_type)
		elif selected_unit_type != "":
			try_place_unit(grid_pos, selected_unit_type)
		elif selected_unit == null:
			select_unit(grid_pos)
		elif grid_pos in valid_move_tiles:
			move_unit(unit_start_pos, grid_pos)

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

func try_place_unit(grid_pos: Vector2, unit_type: String) -> bool:
	# Check if position is in first column
	if grid_pos.x != 0:
		print("Units can only be placed in the first column")
		return false
		
	# Check if position is within grid bounds
	if grid_pos.y < 0 or grid_pos.y >= grid_size.y:
		return false
		
	# Check if cell has reached unit limit
	if units_in_cells[grid_pos].size() >= MAX_UNITS_PER_CELL:
		print("Cell is full")
		return false
		
	# Check if enough military points
	var cost = UNIT_COSTS[unit_type]
	if military_points < cost:
		print("Not enough military points! Cost: ", cost, " Available: ", military_points)
		return false
		
	# Create and place the unit
	var unit = unit_scenes[unit_type].instantiate()
	add_child(unit)
	
	# Position the unit within the cell
	var base_pos = grid_to_world(grid_pos)
	var offset = Vector2(0, -20 * units_in_cells[grid_pos].size())  # Stack units vertically
	unit.position = base_pos + offset
	
	# Add unit to tracking
	units_in_cells[grid_pos].append(unit)
	
	# Deduct points
	military_points -= cost
	
	print("Placed ", unit_type, " at ", grid_pos, ". Cost: ", cost, " Points remaining: ", military_points)
	return true

func select_unit(grid_pos: Vector2):
	if grid_pos not in units_in_cells or units_in_cells[grid_pos].size() == 0:
		return
		
	var unit = units_in_cells[grid_pos][0]  # Select the first unit in the stack
	if unit and unit.has_method("can_move") and unit.can_move():
		selected_unit = unit
		unit_start_pos = grid_pos
		highlight_valid_moves(grid_pos)
	else:
		print("Unit has already moved this turn")

func highlight_valid_moves(from_pos: Vector2):
	valid_move_tiles.clear()
	
	var is_armoured = selected_unit.get_parent().name.begins_with("armoured")
	var move_points = 2 if is_armoured else 1  # 2 for armoured, 1 for others
	
	# Calculate valid moves
	for x in range(max(0, from_pos.x - move_points), min(grid_size.x, from_pos.x + move_points + 1)):
		for y in range(max(0, from_pos.y - move_points), min(grid_size.y, from_pos.y + move_points + 1)):
			var test_pos = Vector2(x, y)
			if test_pos == from_pos:
				continue
				
			if is_armoured:
				# Armoured units can move diagonally and up to 2 tiles
				var distance = (test_pos - from_pos).length()
				if distance <= 2.0:  # Using floating-point distance for diagonal movement
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)
			else:
				# Infantry and garrison can only move 1 tile orthogonally
				if manhattan_distance(from_pos, test_pos) <= move_points:
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)

func manhattan_distance(from: Vector2, to: Vector2) -> int:
	return int(abs(from.x - to.x) + abs(from.y - to.y))

func move_unit(from_pos: Vector2, to_pos: Vector2):
	if !selected_unit or !selected_unit.has_method("can_move") or !selected_unit.can_move():
		return false
		
	var unit_index = units_in_cells[from_pos].find(selected_unit)
	if unit_index == -1:
		return false
		
	# Remove unit from old position
	units_in_cells[from_pos].remove_at(unit_index)
	
	# Add unit to new position
	if to_pos not in units_in_cells:
		units_in_cells[to_pos] = []
	units_in_cells[to_pos].append(selected_unit)
	
	# Update unit position
	var base_pos = grid_to_world(to_pos)
	var offset = Vector2(0, -20 * (units_in_cells[to_pos].size() - 1))
	selected_unit.position = base_pos + offset
	
	# Mark the unit as moved
	selected_unit.has_moved = true
	
	# Clear selection
	selected_unit = null
	valid_move_tiles.clear()
	print("Unit moved from ", from_pos, " to ", to_pos)
	return true

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
		
	# Draw unit count indicators for first column
	for y in range(grid_size.y):
		var pos = Vector2(0, y)
		if pos in units_in_cells:
			var unit_count = units_in_cells[pos].size()
			if unit_count > 0:
				var text_pos = grid_to_world(pos) + Vector2(-tile_size.x/2 + 10, -tile_size.y/2 + 20)
				draw_string(ThemeDB.fallback_font, text_pos, str(unit_count) + "/" + str(MAX_UNITS_PER_CELL))
	
	# Draw valid move tiles
	for pos in valid_move_tiles:
		var rect = Rect2(
			pos.x * tile_size.x,
			pos.y * tile_size.y,
			tile_size.x,
			tile_size.y
		)
		draw_rect(rect, Color(0, 1, 1, 0.3))  # Cyan highlight for valid moves
