extends Node

# Constants
const MAX_UNITS_PER_CELL = 3
const UNIT_COSTS = {
	"infantry": 1000,
	"armoured": 3000,
	"garrison": 500
}

const MANPOWER_COSTS = {
	"infantry": 1000,
	"armoured": 1000,
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
@onready var territory_manager = get_parent().get_node("TerritoryManager")

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

func is_position_in_territory(grid_pos: Vector2, is_enemy: bool) -> bool:
	# First check if the position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_size.x or \
	   grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
		print("Position out of grid bounds")
		return false
	
	# Get reference to building manager
	var building_manager = get_parent().get_node("BuildingManager")
	if !building_manager:
		print("BuildingManager not found")
		return false
	
	if is_enemy:
		# If placing a new unit (not moving)
		if selected_unit_type != "" and !selected_unit:
			# Enemy can only place units in the rightmost column
			if grid_pos.x == grid.grid_size.x - 1:
				# Check if the territory is owned by the enemy
				if territory_manager:
					var territory_owner = territory_manager.get_territory_owner(grid_pos)
					if territory_owner != "enemy":
						print("Cannot place unit - territory not controlled by enemy")
						return false
				return true
			print("Enemy can only place new units in the last column")
			return false
		# For moving existing units
		else:
			# During war, units can move anywhere
			if territory_manager and territory_manager.war_active:
				return true
			# Before war, check if column is in enemy territory
			for column in building_manager.enemy_buildable_columns:
				if grid_pos.x == column:
					return true
			print("Enemy attempted to move outside their territory at column: ", grid_pos.x)
			print("Enemy buildable columns: ", building_manager.enemy_buildable_columns)
			return false
	else:
		# If placing a new unit (not moving)
		if selected_unit_type != "" and !selected_unit:
			# Player can only place units in the leftmost column
			if grid_pos.x == 0:
				# Check if the territory is owned by the player
				if territory_manager:
					var territory_owner = territory_manager.get_territory_owner(grid_pos)
					if territory_owner != "player":
						print("Cannot place unit - territory not controlled by player")
						return false
				return true
			print("Player can only place new units in the first column")
			return false
		# For moving existing units
		else:
			# During war, units can move anywhere
			if territory_manager and territory_manager.war_active:
				return true
			# Before war, check if column is in player territory
			for column in building_manager.buildable_columns:
				if grid_pos.x == column:
					return true
			print("Player attempted to move outside their territory at column: ", grid_pos.x)
			print("Player buildable columns: ", building_manager.buildable_columns)
			return false

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

func deselect_current_unit():
	if currently_highlighted_unit:
		set_unit_highlight(currently_highlighted_unit, false)
		currently_highlighted_unit = null
	
	selected_unit = null
	valid_move_tiles.clear()
	current_unit_index = -1
	last_clicked_pos = Vector2(-1, -1)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			deselect_current_unit()

func get_movable_units_at_position(grid_pos: Vector2) -> Array:
	var movable_units = []
	print("\nChecking movable units at position: ", grid_pos)
	if grid_pos in units_in_cells:
		for unit in units_in_cells[grid_pos]:
			if unit and is_instance_valid(unit) and unit.has_method("can_move") and unit.can_move():
				print("Found movable unit: ", unit.scene_file_path)
				movable_units.append(unit)
	print("Total movable units found: ", movable_units.size())
	return movable_units

func cycle_through_units(grid_pos: Vector2) -> bool:
	var movable_units = get_movable_units_at_position(grid_pos)
	print("\nCycling through units")
	print("Total movable units: ", movable_units.size())
	print("Currently selected unit: ", selected_unit)
	print("Current unit index: ", current_unit_index)
	
	if movable_units.size() == 0:
		print("No movable units found")
		current_unit_index = -1
		return false
		
	# Clear previous highlighting
	if currently_highlighted_unit:
		set_unit_highlight(currently_highlighted_unit, false)
		
	# Update current_unit_index
	if current_unit_index == -1 or !selected_unit:
		current_unit_index = 0
	else:
		current_unit_index = (current_unit_index + 1) % movable_units.size()
	
	print("New unit index: ", current_unit_index)
	
	# Select the next unit
	selected_unit = movable_units[current_unit_index]
	currently_highlighted_unit = selected_unit
	set_unit_highlight(selected_unit, true)
	unit_start_pos = grid_pos
	highlight_valid_moves(grid_pos)
	
	return true

func try_place_unit(grid_pos: Vector2) -> bool:
	print("UnitManager: Attempting to place unit at: ", grid_pos)
	
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_size.x or grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
		print("UnitManager: Cannot place unit - position out of bounds")
		return false
	
	# Check territory restrictions before war
	if !is_position_in_territory(grid_pos, placing_enemy):
		print("UnitManager: Cannot place unit - wrong territory")
		return false
		
	if units_in_cells[grid_pos].size() >= MAX_UNITS_PER_CELL:
		print("UnitManager: Cannot place unit - cell is full")
		return false
		
	# Check military points and manpower costs
	var military_cost = UNIT_COSTS[selected_unit_type]
	var manpower_cost = MANPOWER_COSTS[selected_unit_type]
	
	if placing_enemy:
		if resource_manager.enemy_military_points < military_cost:
			print("UnitManager: Cannot place unit - insufficient enemy military points")
			return false
		if resource_manager.enemy_manpower < manpower_cost:
			print("UnitManager: Cannot place unit - insufficient enemy manpower")
			return false
	else:
		if resource_manager.military_points < military_cost:
			print("UnitManager: Cannot place unit - insufficient military points")
			return false
		if resource_manager.manpower < manpower_cost:
			print("UnitManager: Cannot place unit - insufficient manpower")
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
	
	if placing_enemy:
		resource_manager.enemy_military_points -= UNIT_COSTS[selected_unit_type]
		resource_manager.enemy_manpower -= MANPOWER_COSTS[selected_unit_type]
	else:
		resource_manager.military_points -= UNIT_COSTS[selected_unit_type]
		resource_manager.manpower -= MANPOWER_COSTS[selected_unit_type]
	
	print("UnitManager: Unit placed successfully")
	return true

func try_select_unit(grid_pos: Vector2):
	print("\nUnitManager: Attempting to select unit at position: ", grid_pos)
	print("Current state:")
	print("- Selected unit: ", selected_unit)
	print("- Last clicked position: ", last_clicked_pos)
	print("- Current unit index: ", current_unit_index)
	print("- Units at position: ", units_in_cells[grid_pos] if units_in_cells.has(grid_pos) else "None")
	
	# Get reference to combat manager
	var combat_manager = get_parent().get_node("CombatManager")
	
	# Check for combat initiation
	if selected_unit and units_in_cells.has(grid_pos):
		var enemy_units = get_enemy_units_at(grid_pos)
		print("Enemy units found at position: ", enemy_units.size())
		if enemy_units.size() > 0:
			if is_adjacent(unit_start_pos, grid_pos):
				print("Initiating combat between adjacent units")
				combat_manager.initiate_combat(unit_start_pos, grid_pos)
				deselect_current_unit()
				return
			else:
				print("Enemy units found but not adjacent")
	
	# Check if clicking outside valid moves
	if selected_unit and !is_valid_move(grid_pos) and grid_pos != last_clicked_pos:
		print("Clicked outside valid moves - deselecting")
		deselect_current_unit()
		return
	
	# Handle unit cycling
	if grid_pos == last_clicked_pos:
		print("Same tile clicked - attempting to cycle units")
		# Get all movable units at this position before cycling
		var movable_units = get_movable_units_at_position(grid_pos)
		print("Movable units at position: ", movable_units.size())
		if movable_units.size() > 0:
			# Reset current_unit_index if it's invalid
			if current_unit_index >= movable_units.size():
				current_unit_index = -1
			cycle_through_units(grid_pos)
		else:
			print("No movable units to cycle through")
	else:
		print("New tile clicked - resetting cycle")
		last_clicked_pos = grid_pos
		current_unit_index = -1
		cycle_through_units(grid_pos)
	
	print("After selection attempt:")
	print("- Selected unit: ", selected_unit)
	print("- Current unit index: ", current_unit_index)
	if selected_unit:
		print("- Selected unit type: ", selected_unit.scene_file_path)

func get_enemy_units_at(pos: Vector2) -> Array:
	var enemy_units = []
	if pos in units_in_cells:
		for unit in units_in_cells[pos]:
			if unit.is_enemy != selected_unit.is_enemy:
				enemy_units.append(unit)
	return enemy_units

func is_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	print("Checking adjacency - dx: ", dx, " dy: ", dy)
	return dx <= 1 and dy <= 1 and pos1 != pos2

func get_line_points(start: Vector2, end: Vector2) -> Array:
	var points = []
	var x0 = int(start.x)
	var y0 = int(start.y)
	var x1 = int(end.x)
	var y1 = int(end.y)
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var x = x0
	var y = y0
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	
	if dx > dy:
		var err = dx / 2
		while x != x1:
			points.append(Vector2(x, y))
			err -= dy
			if err < 0:
				y += sy
				err += dx
			x += sx
	else:
		var err = dy / 2
		while y != y1:
			points.append(Vector2(x, y))
			err -= dx
			if err < 0:
				x += sx
				err += dy
			y += sy
	
	points.append(Vector2(x1, y1))
	return points

func is_path_blocked(from_pos: Vector2, to_pos: Vector2) -> bool:
	# Get all points along the path except the starting position
	var path_points = get_line_points(from_pos, to_pos)
	path_points.pop_front()  # Remove starting position
	
	# Check each point along the path for enemy units
	for point in path_points:
		if point in units_in_cells:
			for unit in units_in_cells[point]:
				if unit.is_enemy != selected_unit.is_enemy:
					print("Path blocked by enemy unit at ", point)
					return true
	
	return false

func highlight_valid_moves(from_pos: Vector2):
	print("UnitManager: Highlighting valid moves from position: ", from_pos)
	valid_move_tiles.clear()
	
	if !selected_unit:
		print("UnitManager: No unit selected to highlight moves for")
		return
		
	var is_armoured = selected_unit.scene_file_path.contains("armoured")
	var remaining_points = selected_unit.movement_points
	
	if is_armoured:
		# Get all possible directions (horizontal, vertical, and diagonal)
		var directions = [
			Vector2(1, 0),   # right
			Vector2(-1, 0),  # left
			Vector2(0, 1),   # down
			Vector2(0, -1),  # up
			Vector2(1, 1),   # down-right
			Vector2(-1, 1),  # down-left
			Vector2(1, -1),  # up-right
			Vector2(-1, -1)  # up-left
		]
		
		# Check each direction up to 2 tiles away
		for direction in directions:
			for distance in range(1, remaining_points + 1):
				var test_pos = from_pos + direction * distance
				
				# Check if position is within grid bounds
				if test_pos.x < 0 or test_pos.x >= grid.grid_size.x or \
				   test_pos.y < 0 or test_pos.y >= grid.grid_size.y:
					break
				
				# Check territory restrictions before war
				if !is_position_in_territory(test_pos, selected_unit.is_enemy):
					break
				
				# Check if tile is occupied by max units
				if test_pos in units_in_cells and units_in_cells[test_pos].size() >= MAX_UNITS_PER_CELL:
					break
					
				# Check if path is blocked by enemy units
				if is_path_blocked(from_pos, test_pos):
					break
				
				valid_move_tiles.append(test_pos)
	else:
		# Infantry and garrison movement (1 tile orthogonally)
		for x in range(max(0, from_pos.x - 1), min(grid.grid_size.x, from_pos.x + 2)):
			for y in range(max(0, from_pos.y - 1), min(grid.grid_size.y, from_pos.y + 2)):
				var test_pos = Vector2(x, y)
				if test_pos == from_pos:
					continue
					
				if manhattan_distance(from_pos, test_pos) == 1:
					# Check territory restrictions before war
					if is_position_in_territory(test_pos, selected_unit.is_enemy):
						# Check if destination has enemy units
						var has_enemy = false
						if test_pos in units_in_cells:
							for unit in units_in_cells[test_pos]:
								if unit.is_enemy != selected_unit.is_enemy:
									has_enemy = true
									break
						
						if !has_enemy and (test_pos not in units_in_cells or units_in_cells[test_pos].size() < MAX_UNITS_PER_CELL):
							valid_move_tiles.append(test_pos)
	
	print("UnitManager: Found ", valid_move_tiles.size(), " valid moves")


func manhattan_distance(from: Vector2, to: Vector2) -> int:
	return int(abs(from.x - to.x) + abs(from.y - to.y))


# In unit_manager.gd
func check_territory_capture(from_pos: Vector2, to_pos: Vector2):
	var territory_mgr = get_parent().get_node("TerritoryManager")
	if territory_mgr and selected_unit:
		# Determine the capturing side
		var capturing_player = "enemy" if selected_unit.is_enemy else "player"
		
		# For armoured units, process the entire path
		if selected_unit.scene_file_path.contains("armoured"):
			var path_points = get_line_points(from_pos, to_pos)
			
			# Process every point in the path (including start and end)
			for point in path_points:
				# Verify the position is within grid bounds
				if point.x >= 0 and point.x < grid.grid_size.x and \
				   point.y >= 0 and point.y < grid.grid_size.y:
					# Get current territory owner
					var current_owner = territory_mgr.get_territory_owner(point)
					
					# Capture if it's not our territory
					if current_owner != capturing_player:
						territory_mgr.capture_territory(point, capturing_player)
		else:
			# For infantry and garrison, only capture the destination tile
			var current_owner = territory_mgr.get_territory_owner(to_pos)
			if current_owner != capturing_player:
				territory_mgr.capture_territory(to_pos, capturing_player)


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
	
	# Verify the path isn't blocked before moving
	if is_path_blocked(unit_start_pos, to_pos):
		print("UnitManager: Cannot move - path is blocked by enemy unit")
		return false
		
	# Calculate movement cost based on actual distance moved
	var movement_cost = 1
	if selected_unit.scene_file_path.contains("armoured"):
		var dx = abs(to_pos.x - unit_start_pos.x)
		var dy = abs(to_pos.y - unit_start_pos.y)
		movement_cost = max(dx, dy)
	
	# Check territory capture before moving
	check_territory_capture(unit_start_pos, to_pos)
	
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
	current_unit_index = -1
	last_clicked_pos = Vector2(-1, -1)
	
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
