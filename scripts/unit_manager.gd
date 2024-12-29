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
	
	# If placing a new unit (not moving)
	if selected_unit_type != "" and !selected_unit:
		if placing_enemy:  # Changed from is_enemy to placing_enemy
			# Enemy can only place units in the last column
			if grid_pos.x == grid.grid_size.x - 1:
				if territory_manager:
					var territory_owner = territory_manager.get_territory_owner(grid_pos)
					if territory_owner != "enemy":
						print("Cannot place unit - territory not controlled by enemy")
						return false
				return true
			print("Enemy can only place units in the last column")
			return false
		else:
			# Player can only place units in the first column
			if grid_pos.x == 0:
				if territory_manager:
					var territory_owner = territory_manager.get_territory_owner(grid_pos)
					if territory_owner != "player":
						print("Cannot place unit - territory not controlled by player")
						return false
				return true
			print("Player can only place units in the first column")
			return false
	
	# For moving existing units
	else:
		# During war, units can move anywhere
		if territory_manager and territory_manager.war_active:
			return true
			
		# Before war, check territory ownership
		if territory_manager:
			var territory_owner = territory_manager.get_territory_owner(grid_pos)
			if is_enemy and territory_owner != "enemy":
				print("Enemy attempted to move outside their territory")
				return false
			elif !is_enemy and territory_owner != "player":
				print("Player attempted to move outside their territory")
				return false
			return true
			
		return false # Default to false if no territory manager found
	
	return false # Default case

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
	var selectable_units = []
	print("\nChecking movable units at position: ", grid_pos)
	if grid_pos in units_in_cells:
		for unit in units_in_cells[grid_pos]:
			if unit and is_instance_valid(unit):
				# Check if unit hasn't been in combat this turn
				if !unit.in_combat_this_turn:
					# If it can move OR there are adjacent enemies it can attack
					if unit.can_move() or has_adjacent_enemies(grid_pos, unit):
						print("Found selectable unit: ", unit.scene_file_path)
						selectable_units.append(unit)
	print("Total selectable units found: ", selectable_units.size())
	return selectable_units

func has_adjacent_enemies(pos: Vector2, unit: Node2D) -> bool:
	var is_armoured = unit.scene_file_path.contains("armoured")
	var max_range = 2 if is_armoured else 1
	
	# Check all positions within attack range
	for x in range(max(0, pos.x - max_range), min(grid.grid_size.x, pos.x + max_range + 1)):
		for y in range(max(0, pos.y - max_range), min(grid.grid_size.y, pos.y + max_range + 1)):
			var check_pos = Vector2(x, y)
			if check_pos == pos:
				continue
				
			# Check distance for non-armoured units
			if !is_armoured and max(abs(check_pos.x - pos.x), abs(check_pos.y - pos.y)) > 1:
				continue
			
			# Check for enemy units
			if check_pos in units_in_cells:
				for other_unit in units_in_cells[check_pos]:
					if other_unit.is_enemy != unit.is_enemy:
						return true
	return false

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
	
	var world_pos = grid.grid_to_world(grid_pos)
	
	# Calculate the vertical offset based on existing units in the cell
	var stack_height = units_in_cells[grid_pos].size()
	var unit_offset = Vector2(0, -20 * stack_height)  # -20 pixels for each unit in stack
	
	# Apply the offset to the unit's position
	new_unit.position = world_pos + unit_offset
	
	# Add the unit to the cell
	units_in_cells[grid_pos].append(new_unit)
	
	if placing_enemy:
		resource_manager.enemy_military_points -= UNIT_COSTS[selected_unit_type]
		resource_manager.enemy_manpower -= MANPOWER_COSTS[selected_unit_type]
	else:
		resource_manager.military_points -= UNIT_COSTS[selected_unit_type]
		resource_manager.manpower -= MANPOWER_COSTS[selected_unit_type]
	
	print("UnitManager: Unit placed successfully")
	return true

func find_attack_position(from_pos: Vector2, target_pos: Vector2) -> Vector2:
	# If we're already adjacent, use current position
	if is_adjacent(from_pos, target_pos):
		return from_pos
	
	# Get the movement range
	var is_armoured = selected_unit.scene_file_path.contains("armoured")
	var max_range = 2 if is_armoured else 1
	
	# First find positions we can move to
	var moveable_positions = []
	if selected_unit.movement_points > 0:
		for x in range(max(0, from_pos.x - max_range), min(grid.grid_size.x, from_pos.x + max_range + 1)):
			for y in range(max(0, from_pos.y - max_range), min(grid.grid_size.y, from_pos.y + max_range + 1)):
				var pos = Vector2(x, y)
				if pos == from_pos:
					continue
					
				var distance = max(abs(pos.x - from_pos.x), abs(pos.y - from_pos.y))
				if !is_armoured and distance > 1:
					continue
					
				if distance > selected_unit.movement_points:
					continue
					
				if !is_position_in_territory(pos, selected_unit.is_enemy):
					continue
					
				if !is_path_blocked(from_pos, pos):
					if !units_in_cells.has(pos) or units_in_cells[pos].size() < MAX_UNITS_PER_CELL:
						moveable_positions.append(pos)
	else:
		# If we can't move, we can only attack from our current position
		moveable_positions = [from_pos]
	
	# From each position we can move to, check if we can attack the target
	var attack_positions = []
	for move_pos in moveable_positions:
		var distance_to_target = max(abs(target_pos.x - move_pos.x), abs(target_pos.y - move_pos.y))
		if (!is_armoured and distance_to_target == 1) or (is_armoured and distance_to_target <= 2):
			attack_positions.append({
				"position": move_pos,
				"distance": max(abs(move_pos.x - from_pos.x), abs(move_pos.y - from_pos.y)),
				"surrounding_enemies": count_surrounding_enemies(move_pos)
			})
	
	# Sort positions by multiple criteria
	attack_positions.sort_custom(func(a, b):
		# First prioritize minimizing movement points used
		if a.distance != b.distance:
			return a.distance < b.distance
		
		# Then prefer positions with fewer surrounding enemies
		if a.surrounding_enemies != b.surrounding_enemies:
			return a.surrounding_enemies < b.surrounding_enemies
		
		# Finally, prefer positions closer to our starting position
		var a_dist_to_start = abs(a.position.x - from_pos.x) + abs(a.position.y - from_pos.y)
		var b_dist_to_start = abs(b.position.x - from_pos.x) + abs(b.position.y - from_pos.y)
		return a_dist_to_start < b_dist_to_start
	)
	
	# Return the best position or invalid position if none found
	return attack_positions[0].position if attack_positions.size() > 0 else Vector2(-1, -1)

func count_surrounding_enemies(pos: Vector2) -> int:
	var count = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
				
			var check_pos = pos + Vector2(dx, dy)
			if check_pos.x < 0 or check_pos.x >= grid.grid_size.x or \
			   check_pos.y < 0 or check_pos.y >= grid.grid_size.y:
				continue
			
			if check_pos in units_in_cells:
				for unit in units_in_cells[check_pos]:
					if unit.is_enemy != selected_unit.is_enemy:
						count += 1
						break
	return count

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
		
		# Can only attack if we haven't been in combat this turn
		if enemy_units.size() > 0 and !selected_unit.in_combat_this_turn and grid_pos in valid_move_tiles:
			print("Valid enemy target found")
			# Find a valid adjacent position to attack from
			var attack_pos = find_attack_position(unit_start_pos, grid_pos)
			if attack_pos != Vector2(-1, -1):
				print("Found valid attack position: ", attack_pos)
				# Move to attack position if needed and if we have movement points
				if attack_pos != unit_start_pos and selected_unit.movement_points > 0:
					execute_move(attack_pos)
				# Initiate combat
				if combat_manager:
					combat_manager.initiate_combat(attack_pos, grid_pos)
				# Only move into enemy position if we have movement points left and unit still exists
				if selected_unit and is_instance_valid(selected_unit) and \
				   selected_unit.movement_points > 0 and !selected_unit.has_moved:
					execute_move(grid_pos)
				deselect_current_unit()
				return
	
	# If we've already attacked this turn, can't do anything else with this unit
	if selected_unit and selected_unit.in_combat_this_turn:
		print("Unit has already attacked this turn - deselecting")
		deselect_current_unit()
		return
	
	# Check if clicking outside valid moves
	if selected_unit and !is_valid_move(grid_pos) and grid_pos != last_clicked_pos:
		print("Clicked outside valid moves - deselecting")
		deselect_current_unit()
		return
	
	# Only allow selecting units that haven't attacked this turn
	var movable_units = []
	if grid_pos in units_in_cells:
		for unit in units_in_cells[grid_pos]:
			if !unit.in_combat_this_turn:
				movable_units.append(unit)
	
	# Handle unit cycling
	if grid_pos == last_clicked_pos and movable_units.size() > 0:
		print("Same tile clicked - attempting to cycle units")
		if current_unit_index >= movable_units.size():
			current_unit_index = -1
		cycle_through_units(grid_pos)
	else:
		print("New tile clicked - resetting cycle")
		last_clicked_pos = grid_pos
		current_unit_index = -1
		if movable_units.size() > 0:
			cycle_through_units(grid_pos)
		else:
			deselect_current_unit()
	
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
	
	# Get unit type from scene path
	var unit_type = ""
	if selected_unit.scene_file_path.contains("infantry"):
		unit_type = "infantry"
	elif selected_unit.scene_file_path.contains("armoured"):
		unit_type = "armoured"
	elif selected_unit.scene_file_path.contains("garrison"):
		unit_type = "garrison"
	
	# Only process moves if unit has movement points
	if selected_unit.movement_points > 0:
		match unit_type:
			"garrison":
				# Garrison moves only up, down, left, right (no diagonals)
				var directions = [
					Vector2(1, 0),   # right
					Vector2(-1, 0),  # left
					Vector2(0, 1),   # down
					Vector2(0, -1)   # up
				]
				
				for dir in directions:
					var test_pos = from_pos + dir
					if is_valid_movement_position(test_pos):
						valid_move_tiles.append(test_pos)
						
			"infantry":
				# Infantry can move in any direction within 1 tile radius
				for x in range(-1, 2):
					for y in range(-1, 2):
						if x == 0 and y == 0:
							continue
						var test_pos = from_pos + Vector2(x, y)
						if is_valid_movement_position(test_pos):
							valid_move_tiles.append(test_pos)
							
			"armoured":
				# Armoured moves like a queen in chess with range of 2
				var directions = [
					Vector2(1, 0),    # right
					Vector2(-1, 0),   # left
					Vector2(0, 1),    # down
					Vector2(0, -1),   # up
					Vector2(1, 1),    # diagonal down-right
					Vector2(-1, 1),   # diagonal down-left
					Vector2(1, -1),   # diagonal up-right
					Vector2(-1, -1)   # diagonal up-left
				]
				
				for dir in directions:
					# Can move 1 or 2 spaces in each direction
					for distance in range(1, 3):
						var test_pos = from_pos + (dir * distance)
						if is_valid_movement_position(test_pos):
							valid_move_tiles.append(test_pos)
	
	# Add combat tiles - units can attack even if they can't move
	if !selected_unit.in_combat_this_turn:
		var combat_range = 2 if unit_type == "armoured" else 1
		add_combat_tiles(from_pos, combat_range)

func is_valid_movement_position(pos: Vector2) -> bool:
	# Check if position is within grid bounds
	if pos.x < 0 or pos.x >= grid.grid_size.x or \
	   pos.y < 0 or pos.y >= grid.grid_size.y:
		return false
	
	# Check territory restrictions before war
	if !is_position_in_territory(pos, selected_unit.is_enemy):
		return false
	
	# Check if path is blocked by enemy units
	if is_path_blocked(unit_start_pos, pos):
		return false
	
	# Check if position has space for movement
	if pos in units_in_cells:
		# Allow moving to position with enemy units for combat
		var has_only_enemy_units = true
		for unit in units_in_cells[pos]:
			if unit.is_enemy == selected_unit.is_enemy:
				if units_in_cells[pos].size() >= MAX_UNITS_PER_CELL:
					return false
				has_only_enemy_units = false
		
		if has_only_enemy_units:
			return true
			
	return true

func add_combat_tiles(from_pos: Vector2, combat_range: int):
	# Add tiles where enemy units are present within combat range
	for x in range(-combat_range, combat_range + 1):
		for y in range(-combat_range, combat_range + 1):
			if x == 0 and y == 0:
				continue
				
			var test_pos = from_pos + Vector2(x, y)
			
			# Check if position is within grid bounds
			if test_pos.x < 0 or test_pos.x >= grid.grid_size.x or \
			   test_pos.y < 0 or test_pos.y >= grid.grid_size.y:
				continue
			
			# For non-armoured units, only allow adjacent attacks
			if combat_range == 1 and abs(x) + abs(y) > 1:
				continue
			
			# Check if there are enemy units at this position
			if test_pos in units_in_cells:
				for unit in units_in_cells[test_pos]:
					if unit.is_enemy != selected_unit.is_enemy:
						valid_move_tiles.append(test_pos)
						break

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
	
	if !selected_unit:
		print("UnitManager: Cannot move - invalid unit state")
		return false
		
	var unit_index = units_in_cells[unit_start_pos].find(selected_unit)
	if unit_index == -1:
		print("UnitManager: Cannot move - unit not found in starting position")
		return false
	
	# Check if the destination has enemy units
	var has_enemy = false
	if to_pos in units_in_cells:
		for unit in units_in_cells[to_pos]:
			if unit.is_enemy != selected_unit.is_enemy:
				has_enemy = true
				break
	
	# If there are enemy units and we have no movement points, only initiate combat
	if has_enemy and selected_unit.movement_points <= 0:
		print("UnitManager: Unit has no movement points - initiating combat only")
		var combat_manager = get_parent().get_node("CombatManager")
		if combat_manager:
			combat_manager.initiate_combat(unit_start_pos, to_pos)
		return true
	
	# If we're moving (not just attacking), verify we can move
	if !has_enemy and (!selected_unit.has_method("can_move") or !selected_unit.can_move()):
		print("UnitManager: Cannot move - invalid unit state")
		return false
	
	# If there are enemy units, don't check space limitations
	if !has_enemy:
		# Only check space limitations for non-combat moves
		if to_pos in units_in_cells and units_in_cells[to_pos].size() >= MAX_UNITS_PER_CELL:
			print("UnitManager: Cannot move - destination is full")
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
	
	# Only deduct movement points if we're actually moving
	if !has_enemy:
		selected_unit.movement_points -= movement_cost
	
	# Only move the unit if there are no enemy units at the destination
	if !has_enemy:
		# Remove unit from starting position
		units_in_cells[unit_start_pos].remove_at(unit_index)
		
		# Add unit to new position
		if to_pos not in units_in_cells:
			units_in_cells[to_pos] = []
		units_in_cells[to_pos].append(selected_unit)
		
		# Reposition ALL units in the destination stack with proper offsets
		var world_pos = grid.grid_to_world(to_pos)
		for i in range(units_in_cells[to_pos].size()):
			var unit = units_in_cells[to_pos][i]
			var offset = Vector2(0, -20 * i)  # -20 pixels offset for each unit in stack
			unit.position = world_pos + offset
		
		# Also reposition units in the starting position if any remain
		world_pos = grid.grid_to_world(unit_start_pos)
		for i in range(units_in_cells[unit_start_pos].size()):
			var unit = units_in_cells[unit_start_pos][i]
			var offset = Vector2(0, -20 * i)
			unit.position = world_pos + offset
	
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
