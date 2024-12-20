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

func initialize(size: Vector2):
	# Initialize unit tracking for the first column
	for y in range(size.y):
		units_in_cells[Vector2(0, y)] = []

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
	print("Selected unit type: ", type)

func try_place_unit(grid_pos: Vector2) -> bool:
	# Check if position is in first column
	if grid_pos.x != 0:
		print("Units can only be placed in the first column")
		return false
		
	# Check if position is within grid bounds
	if grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
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
	
	print("Placed ", selected_unit_type, " at ", grid_pos)
	return true

func try_select_unit(grid_pos: Vector2):
	if grid_pos not in units_in_cells or units_in_cells[grid_pos].size() == 0:
		return
		
	var unit = units_in_cells[grid_pos][0]  # Select first unit in stack
	if unit and unit.has_method("can_move") and unit.can_move():
		selected_unit = unit
		unit_start_pos = grid_pos
		highlight_valid_moves(grid_pos)
	else:
		print("Unit has already moved this turn")

func highlight_valid_moves(from_pos: Vector2):
	valid_move_tiles.clear()
	
	var is_armoured = selected_unit.get_parent().name.begins_with("armoured")
	var move_points = 2 if is_armoured else 1
	
	for x in range(max(0, from_pos.x - move_points), min(grid.grid_size.x, from_pos.x + move_points + 1)):
		for y in range(max(0, from_pos.y - move_points), min(grid.grid_size.y, from_pos.y + move_points + 1)):
			var test_pos = Vector2(x, y)
			if test_pos == from_pos:
				continue
				
			if is_armoured:
				var distance = (test_pos - from_pos).length()
				if distance <= 2.0:
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)
			else:
				if manhattan_distance(from_pos, test_pos) <= move_points:
					if test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL:
						valid_move_tiles.append(test_pos)

func manhattan_distance(from: Vector2, to: Vector2) -> int:
	return int(abs(from.x - to.x) + abs(from.y - to.y))

func execute_move(to_pos: Vector2):
	if !selected_unit or !selected_unit.has_method("can_move") or !selected_unit.can_move():
		return false
		
	var unit_index = units_in_cells[unit_start_pos].find(selected_unit)
	if unit_index == -1:
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
	# Draw unit count indicators for first column
	for y in range(grid.grid_size.y):
		var pos = Vector2(0, y)
		if pos in units_in_cells:
			var unit_count = units_in_cells[pos].size()
			if unit_count > 0:
				var text_pos = grid.grid_to_world(pos) + Vector2(-grid.tile_size.x/2 + 10, -grid.tile_size.y/2 + 20)
				grid_node.draw_string(ThemeDB.fallback_font, text_pos, str(unit_count) + "/" + str(MAX_UNITS_PER_CELL))
	
	# Draw valid move tiles
	for pos in valid_move_tiles:
		var rect = Rect2(
			pos.x * grid.tile_size.x,
			pos.y * grid.tile_size.y,
			grid.tile_size.x,
			grid.tile_size.y
		)
		grid_node.draw_rect(rect, Color(0, 1, 1, 0.3))
