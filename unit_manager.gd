extends Node

const MAX_UNITS_PER_CELL = 3

var units_in_cells = {}
var selected_unit_type = ""
var selected_unit = null
var valid_move_tiles = []
var unit_start_pos = null

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

@onready var grid = get_parent()
@onready var resource_manager = get_parent().get_node("ResourceManager")
@onready var building_manager = get_parent().get_node("BuildingManager")

func initialize(size: Vector2):
	# Initialize unit tracking for all cells
	for x in range(size.x):
		for y in range(size.y):
			units_in_cells[Vector2(x, y)] = []
	print("UnitManager initialized with grid size: ", size)
	print("Initial units_in_cells: ", units_in_cells)

func has_selected_unit_type() -> bool:
	return selected_unit_type != ""

func has_selected_unit() -> bool:
	return selected_unit != null

func is_valid_move(grid_pos: Vector2) -> bool:
	return grid_pos in valid_move_tiles

func _on_unit_selected(type: String):
	selected_unit_type = type
	selected_unit = null
	valid_move_tiles.clear()
	# Clear building selection when unit is selected
	if building_manager:
		building_manager.selected_building_type = ""
	print("Selected unit type: ", type)

func try_place_unit(grid_pos: Vector2) -> bool:
	print("Attempting to place unit: ", selected_unit_type)
	print("At position: ", grid_pos)
	print("Current military points: ", resource_manager.military_points)
	print("Current units_in_cells state: ", units_in_cells)
	
	# Check if position is in first column
	if grid_pos.x != 0:
		print("Units can only be placed in the first column")
		return false
		
	# Check if position is within grid bounds
	if grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
		print("Position out of bounds")
		return false
		
	# Check if cell has reached unit limit
	if units_in_cells[grid_pos].size() >= MAX_UNITS_PER_CELL:
		print("Cell is full")
		return false
		
	# Check if enough military points
	var cost = UNIT_COSTS[selected_unit_type]
	if resource_manager.military_points < cost:
		print("Not enough military points! Cost: ", cost, " Available: ", resource_manager.military_points)
		return false
		
	# Create and place the unit
	var unit = unit_scenes[selected_unit_type].instantiate()
	grid.add_child(unit)
	
	# Position the unit within the cell
	var base_pos = grid.grid_to_world(grid_pos)
	var offset = Vector2(0, -20 * units_in_cells[grid_pos].size())
	unit.position = base_pos + offset
	
	# Add unit to tracking
	units_in_cells[grid_pos].append(unit)
	
	# Deduct points
	resource_manager.military_points -= cost
	
	print("Successfully placed ", selected_unit_type, " at ", grid_pos)
	print("Remaining military points: ", resource_manager.military_points)
	return true

func try_select_unit(grid_pos: Vector2):
	print("Trying to select unit at: ", grid_pos)
	print("Units at this position: ", units_in_cells.get(grid_pos, []))
	
	if grid_pos not in units_in_cells or units_in_cells[grid_pos].size() == 0:
		print("No units at position: ", grid_pos)
		return
		
	# Get the first unit in the stack
	var unit = units_in_cells[grid_pos][0]
	print("Found unit: ", unit)
	
	# Check if the unit can move
	if unit and is_instance_valid(unit):  # Check if unit exists and is valid
		if unit.has_method("can_move"):
			if unit.can_move():
				selected_unit = unit
				unit_start_pos = grid_pos
				highlight_valid_moves(grid_pos)
				print("Selected unit at position: ", grid_pos)
			else:
				print("Unit has already moved this turn")
		else:
			print("Unit doesn't have can_move method")
	else:
		print("Invalid unit reference")

func highlight_valid_moves(from_pos: Vector2):
	valid_move_tiles.clear()
	
	# Make sure we have a selected unit
	if not selected_unit:
		print("No unit selected")
		return
		
	print("Selected unit: ", selected_unit)
	
	# Determine unit type by checking the scene name
	var is_armoured = selected_unit.scene_file_path.contains("armoured")
	var move_points = 2 if is_armoured else 1
	print("Move points: ", move_points, " (Armoured: ", is_armoured, ")")
	
	# Calculate valid moves
	for x in range(max(0, from_pos.x - move_points), min(grid.grid_size.x, from_pos.x + move_points + 1)):
		for y in range(max(0, from_pos.y - move_points), min(grid.grid_size.y, from_pos.y + move_points + 1)):
			var test_pos = Vector2(x, y)
			if test_pos == from_pos:
				continue
				
			if is_armoured:
				# Armoured units can move diagonally and up to 2 tiles
				var distance = (test_pos - from_pos).length()
				if distance <= 2.0:
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)
						print("Added valid move tile: ", test_pos)
			else:
				# Infantry and garrison can only move 1 tile orthogonally
				if manhattan_distance(from_pos, test_pos) <= move_points:
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)
						print("Added valid move tile: ", test_pos)

func manhattan_distance(from: Vector2, to: Vector2) -> int:
	return int(abs(from.x - to.x) + abs(from.y - to.y))

func execute_move(to_pos: Vector2):
	if !selected_unit or !selected_unit.has_method("can_move") or !selected_unit.can_move():
		print("Invalid unit or unit cannot move")
		return false
		
	var unit_index = units_in_cells[unit_start_pos].find(selected_unit)
	if unit_index == -1:
		print("Unit not found in starting position")
		return false
		
	# Remove unit from old position
	units_in_cells[unit_start_pos].remove_at(unit_index)
	
	# Add unit to new position
	if to_pos not in units_in_cells:
		units_in_cells[to_pos] = []
	units_in_cells[to_pos].append(selected_unit)
	
	# Update unit position
	var base_pos = grid.grid_to_world(to_pos)
	var offset = Vector2(0, -20 * (units_in_cells[to_pos].size() - 1))
	selected_unit.position = base_pos + offset
	
	# Mark unit as moved
	selected_unit.has_moved = true
	
	# Clear selection
	selected_unit = null
	valid_move_tiles.clear()
	print("Unit moved from ", unit_start_pos, " to ", to_pos)
	return true

func draw(grid_node: Node2D):
	# Draw valid move tiles
	for pos in valid_move_tiles:
		var rect = Rect2(
			pos.x * grid.tile_size.x,
			pos.y * grid.tile_size.y,
			grid.tile_size.x,
			grid.tile_size.y
		)
		grid_node.draw_rect(rect, Color(0, 1, 1, 0.3))
