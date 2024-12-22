extends Node

# Constants
const MAX_UNITS_PER_CELL = 3
const UNIT_COSTS = {
	"infantry": 1000,
	"armoured": 3000,
	"garrison": 500
}

# Preloaded scenes
var unit_scenes = {
	"infantry": preload("res://scenes/infantry.tscn"),
	"armoured": preload("res://scenes/armoured.tscn"),
	"garrison": preload("res://scenes/garrison.tscn")
}

# State variables
var units_in_cells = {}
var selected_unit_type: String = ""
var selected_unit = null
var valid_move_tiles: Array = []
var unit_start_pos = null
var placing_enemy: bool = false
var current_unit_index: int = -1
var last_clicked_pos: Vector2 = Vector2(-1, -1)
var currently_highlighted_unit = null

# Node references
@onready var grid = get_parent()
@onready var resource_manager = get_parent().get_node("ResourceManager")
@onready var building_manager = get_parent().get_node("BuildingManager")

func _ready():
	print("UnitManager: Initializing...")

func initialize(size: Vector2):
	for x in range(size.x):
		for y in range(size.y):
			units_in_cells[Vector2(x, y)] = []
	print("UnitManager: Initialized with grid size: ", size)

func has_selected_unit_type() -> bool:
	return selected_unit_type != ""

func has_selected_unit() -> bool:
	return selected_unit != null

func is_valid_move(grid_pos: Vector2) -> bool:
	return grid_pos in valid_move_tiles

func set_unit_highlight(unit: Node2D, highlight: bool):
	if unit and unit.has_method("set_highlighted"):
		unit.set_highlighted(highlight)

func _on_unit_selected(type: String):
	print("UnitManager: Unit type selected: ", type)
	selected_unit_type = type
	selected_unit = null
	valid_move_tiles.clear()
	if building_manager:
		building_manager.selected_building_type = ""

func try_place_unit(grid_pos: Vector2) -> bool:
	print("UnitManager: Attempting to place unit at: ", grid_pos)
	
	# Check if position is within grid bounds for both player and enemy units
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_size.x or grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
		print("UnitManager: Cannot place unit - position out of bounds")
		return false
	
	# Check placement rules for player units (must be placed on leftmost column)
	if !placing_enemy and grid_pos.x != 0:
		print("UnitManager: Cannot place unit - invalid x position for player unit")
		return false
		
	if units_in_cells[grid_pos].size() >= MAX_UNITS_PER_CELL:
		print("UnitManager: Cannot place unit - cell is full")
		return false
		
	if !placing_enemy:
		var cost = UNIT_COSTS[selected_unit_type]
		if resource_manager.military_points < cost:
			print("UnitManager: Cannot place unit - insufficient resources")
			return false
	
	var new_unit = unit_scenes[selected_unit_type].instantiate()
	grid.add_child(new_unit)
	
	if placing_enemy:
		new_unit.is_enemy = true
		if new_unit.has_node("Sprite2D"):
			new_unit.get_node("Sprite2D").modulate = Color.RED
	
	var world_pos = grid.grid_to_world(grid_pos)
	var unit_offset = Vector2(0, -20 * units_in_cells[grid_pos].size())
	new_unit.position = world_pos + unit_offset
	
	units_in_cells[grid_pos].append(new_unit)
	
	if !placing_enemy:
		resource_manager.military_points -= UNIT_COSTS[selected_unit_type]
	
	print("UnitManager: Unit placed successfully")
	return true

func try_select_unit(grid_pos: Vector2):
	print("UnitManager: Attempting to select unit at position: ", grid_pos)
	print("UnitManager: Last clicked position was: ", last_clicked_pos)
	print("UnitManager: Current unit index is: ", current_unit_index)
	
	# Clear previous highlight if exists
	if currently_highlighted_unit:
		set_unit_highlight(currently_highlighted_unit, false)
		currently_highlighted_unit = null
	
	# Clear selection if clicking on a different tile
	if grid_pos != last_clicked_pos:
		print("UnitManager: New tile clicked, resetting selection")
		selected_unit = null
		valid_move_tiles.clear()
		current_unit_index = -1
		
	if grid_pos not in units_in_cells or units_in_cells[grid_pos].size() == 0:
		print("UnitManager: No units found at position")
		return
		
	var units = units_in_cells[grid_pos]
	print("UnitManager: Found ", units.size(), " units at position")
	
	# If clicking the same tile, cycle to next unit
	if grid_pos == last_clicked_pos:
		print("UnitManager: Same tile clicked, cycling units")
		current_unit_index = (current_unit_index + 1) % units.size()
		print("UnitManager: New current_unit_index: ", current_unit_index)
	else:
		# If clicking a new tile, start with the first unit
		current_unit_index = 0
		print("UnitManager: New tile, starting with first unit")
		
	last_clicked_pos = grid_pos
	
	# Try to find a movable unit starting from current_unit_index
	var tried_units = 0
	while tried_units < units.size():
		var unit = units[current_unit_index]
		print("UnitManager: Checking unit at index ", current_unit_index)
		
		if unit and is_instance_valid(unit) and unit.has_method("can_move") and unit.can_move():
			print("UnitManager: Selected unit index ", current_unit_index)
			selected_unit = unit
			currently_highlighted_unit = unit
			set_unit_highlight(unit, true)
			unit_start_pos = grid_pos
			highlight_valid_moves(grid_pos)
			break
		
		current_unit_index = (current_unit_index + 1) % units.size()
		tried_units += 1
	
	# If no movable units found, clear selection
	if !selected_unit:
		current_unit_index = -1
		valid_move_tiles.clear()
		print("UnitManager: No movable units found")

func highlight_valid_moves(from_pos: Vector2):
	print("UnitManager: Highlighting valid moves from position: ", from_pos)
	valid_move_tiles.clear()
	
	if !selected_unit:
		print("UnitManager: No unit selected to highlight moves for")
		return
		
	var is_armoured = selected_unit.scene_file_path.contains("armoured")
	var remaining_points = selected_unit.movement_points
	
	if is_armoured:
		# Check all positions within a 2-tile radius
		for x in range(max(0, from_pos.x - 2), min(grid.grid_size.x, from_pos.x + 3)):
			for y in range(max(0, from_pos.y - 2), min(grid.grid_size.y, from_pos.y + 3)):
				var test_pos = Vector2(x, y)
				if test_pos == from_pos:
					continue
					
				var dx = abs(test_pos.x - from_pos.x)
				var dy = abs(test_pos.y - from_pos.y)
				var max_dist = max(dx, dy)
				
				if max_dist <= 2 and max_dist <= remaining_points:
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)
	else:
		# Infantry and garrison movement (1 tile orthogonally)
		for x in range(max(0, from_pos.x - 1), min(grid.grid_size.x, from_pos.x + 2)):
			for y in range(max(0, from_pos.y - 1), min(grid.grid_size.y, from_pos.y + 2)):
				var test_pos = Vector2(x, y)
				if test_pos == from_pos:
					continue
					
				if manhattan_distance(from_pos, test_pos) == 1:
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)
	
	print("UnitManager: Found ", valid_move_tiles.size(), " valid moves")

func manhattan_distance(from: Vector2, to: Vector2) -> int:
	return int(abs(from.x - to.x) + abs(from.y - to.y))

func execute_move(to_pos: Vector2) -> bool:
	print("UnitManager: Executing unit move to ", to_pos)
	
	# Clear highlight of the moving unit
	if currently_highlighted_unit:
		set_unit_highlight(currently_highlighted_unit, false)
		currently_highlighted_unit = null
	
	if !selected_unit or !selected_unit.has_method("can_move") or !selected_unit.can_move():
		print("UnitManager: Cannot move - invalid unit state")
		return false
		
	var unit_index = units_in_cells[unit_start_pos].find(selected_unit)
	if unit_index == -1:
		print("UnitManager: Cannot move - unit not found in starting position")
		return false
		
	var movement_cost = 1
	if selected_unit.scene_file_path.contains("armoured"):
		var dx = abs(to_pos.x - unit_start_pos.x)
		var dy = abs(to_pos.y - unit_start_pos.y)
		movement_cost = max(dx, dy)
	
	selected_unit.movement_points -= movement_cost
	
	units_in_cells[unit_start_pos].remove_at(unit_index)
	
	if to_pos not in units_in_cells:
		units_in_cells[to_pos] = []
	units_in_cells[to_pos].append(selected_unit)
	
	var world_pos = grid.grid_to_world(to_pos)
	var unit_offset = Vector2(0, -20 * (units_in_cells[to_pos].size() - 1))
	selected_unit.position = world_pos + unit_offset
	
	if selected_unit.movement_points <= 0:
		selected_unit.has_moved = true
	
	selected_unit = null
	valid_move_tiles.clear()
	current_unit_index = -1  # Reset the current unit index after move
	last_clicked_pos = Vector2(-1, -1)  # Reset the last clicked position
	
	print("UnitManager: Unit move complete")
	return true

func draw(grid_node: Node2D):
	for pos in valid_move_tiles:
		var rect = Rect2(
			pos.x * grid.tile_size.x,
			pos.y * grid.tile_size.y,
			grid.tile_size.x,
			grid.tile_size.y
		)
		grid_node.draw_rect(rect, Color(0, 1, 1, 0.3))
