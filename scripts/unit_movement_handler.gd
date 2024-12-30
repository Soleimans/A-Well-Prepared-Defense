extends Node2D

@onready var unit_manager = get_parent()
@onready var grid = unit_manager.get_parent()
@onready var territory_manager = grid.get_node("TerritoryManager")

func get_valid_moves(from_pos: Vector2, unit: Node2D) -> Array:
	var valid_moves = []
	
	if !unit:
		return valid_moves

	# Get unit type from scene path
	var unit_type = ""
	var max_distance = 1
	
	if unit.scene_file_path.contains("armoured"):
		unit_type = "armoured"
		max_distance = 2
	elif unit.scene_file_path.contains("infantry"):
		unit_type = "infantry"
	elif unit.scene_file_path.contains("garrison"):
		unit_type = "garrison"
	
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
				if is_valid_movement_position(test_pos, unit):
					valid_moves.append(test_pos)
					
		"infantry":
			# Infantry can move in any direction within 1 tile radius
			for x in range(-1, 2):
				for y in range(-1, 2):
					if x == 0 and y == 0:
						continue
					var test_pos = from_pos + Vector2(x, y)
					if is_valid_movement_position(test_pos, unit):
						valid_moves.append(test_pos)
						
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
				for distance in range(1, max_distance + 1):
					var test_pos = from_pos + (dir * distance)
					if is_valid_movement_position(test_pos, unit):
						valid_moves.append(test_pos)
					else:
						break  # Stop checking in this direction if we hit an invalid position
	
	return valid_moves

func is_valid_movement_position(pos: Vector2, unit: Node2D) -> bool:
	# Check if position is within grid bounds
	if pos.x < 0 or pos.x >= grid.grid_size.x or \
	   pos.y < 0 or pos.y >= grid.grid_size.y:
		return false
	
	# Check territory restrictions before war
	if !is_position_in_territory(pos, unit.is_enemy):
		return false
	
	# Only check path blocking if we have a starting position
	if unit_manager.unit_start_pos != null:
		# Check if path is blocked by enemy units
		if is_path_blocked(unit_manager.unit_start_pos, pos, unit):
			return false
	
	# Check if position has space for movement
	if pos in unit_manager.units_in_cells:
		if unit_manager.units_in_cells[pos].size() >= unit_manager.MAX_UNITS_PER_CELL:
			# Check if all units at position are enemies
			var all_enemies = true
			for other_unit in unit_manager.units_in_cells[pos]:
				if other_unit.is_enemy == unit.is_enemy:
					all_enemies = false
					break
			# If not all enemies, position is invalid due to being full
			if !all_enemies:
				return false
	
	return true

func is_position_in_territory(grid_pos: Vector2, is_enemy: bool) -> bool:
	# During war, units can move anywhere
	if territory_manager and territory_manager.war_active:
		return true
		
	# Before war, check territory ownership
	if territory_manager:
		var territory_owner = territory_manager.get_territory_owner(grid_pos)
		if is_enemy and territory_owner != "enemy":
			return false
		elif !is_enemy and territory_owner != "player":
			return false
		return true
		
	return false

func is_path_blocked(from_pos: Vector2, to_pos: Vector2, unit: Node2D) -> bool:
	# Get all points along the path except the starting position
	var path_points = get_line_points(from_pos, to_pos)
	path_points.pop_front()  # Remove starting position
	
	# Check each point along the path for enemy units
	for point in path_points:
		if point in unit_manager.units_in_cells:
			for other_unit in unit_manager.units_in_cells[point]:
				if other_unit.is_enemy != unit.is_enemy:
					return true
	
	return false

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

func execute_move(to_pos: Vector2, unit: Node2D, from_pos: Vector2) -> bool:
	if !unit:
		return false
		
	# Calculate movement cost based on actual distance moved
	var movement_cost = 1
	if unit.scene_file_path.contains("armoured"):
		var dx = abs(to_pos.x - from_pos.x)
		var dy = abs(to_pos.y - from_pos.y)
		movement_cost = max(dx, dy)
	
	# Check territory capture before moving
	var territory_manager = grid.get_node("TerritoryManager")
	if territory_manager:
		territory_manager.check_territory_capture(from_pos, to_pos)
	
	# Only deduct movement points if we're actually moving
	unit.movement_points -= movement_cost
	
	# Remove unit from starting position
	var unit_index = unit_manager.units_in_cells[from_pos].find(unit)
	if unit_index != -1:
		unit_manager.units_in_cells[from_pos].remove_at(unit_index)
	
	# Add unit to new position
	if to_pos not in unit_manager.units_in_cells:
		unit_manager.units_in_cells[to_pos] = []
	unit_manager.units_in_cells[to_pos].append(unit)
	
	# Reposition ALL units in the destination stack with proper offsets
	var world_pos = grid.grid_to_world(to_pos)
	for i in range(unit_manager.units_in_cells[to_pos].size()):
		var stacked_unit = unit_manager.units_in_cells[to_pos][i]
		var offset = Vector2(0, -20 * i)  # -20 pixels offset for each unit in stack
		stacked_unit.position = world_pos + offset
	
	# Also reposition units in the starting position if any remain
	world_pos = grid.grid_to_world(from_pos)
	for i in range(unit_manager.units_in_cells[from_pos].size()):
		var stacked_unit = unit_manager.units_in_cells[from_pos][i]
		var offset = Vector2(0, -20 * i)
		stacked_unit.position = world_pos + offset
	
	if unit.movement_points <= 0:
		unit.has_moved = true
	
	return true

func manhattan_distance(from: Vector2, to: Vector2) -> int:
	return int(abs(from.x - to.x) + abs(from.y - to.y))

func position_has_enemy(pos: Vector2, unit: Node2D) -> bool:
	if pos in unit_manager.units_in_cells:
		for other_unit in unit_manager.units_in_cells[pos]:
			if other_unit.is_enemy != unit.is_enemy:
				return true
	return false
