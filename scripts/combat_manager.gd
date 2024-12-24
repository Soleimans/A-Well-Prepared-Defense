extends Node2D

var combat_tiles = {}  # Dictionary to track which tiles are in combat
var retreating_units = []  # Array to track units that will retreat this turn

@onready var unit_manager = get_node("../UnitManager")
@onready var territory_manager = get_node("../TerritoryManager")

func initiate_combat(attacker_pos: Vector2, defender_pos: Vector2):
	# Add both tiles to combat
	combat_tiles[attacker_pos] = defender_pos
	combat_tiles[defender_pos] = attacker_pos
	
	# Process initial combat round
	resolve_combat(attacker_pos, defender_pos)

func process_turn():
	# First handle retreats from previous turn
	execute_retreats()
	
	# Then process combat for units still in combat
	process_combat()
	
	# Finally, check which units should retreat next turn
	prepare_retreats()

func process_combat():
	var combat_positions = combat_tiles.keys()
	for pos in combat_positions:
		if pos in combat_tiles:  # Check again as tiles might have been removed
			resolve_combat(pos, combat_tiles[pos])

func should_retreat(unit: Node) -> bool:
	var max_health = 1000.0 if unit.scene_file_path.contains("infantry") else 1000.0  # Adjust based on unit type
	var health_percent = (unit.soft_health + unit.hard_health) / max_health
	var equipment_percent = float(unit.equipment) / 1000.0
	return health_percent < 0.25 or equipment_percent < 0.25

func prepare_retreats():
	retreating_units.clear()
	
	# Check all combat tiles for weak units
	for combat_pos in combat_tiles.keys():
		var units = unit_manager.units_in_cells[combat_pos]
		for unit in units:
			if should_retreat(unit):
				retreating_units.append({"unit": unit, "from_pos": combat_pos})

func find_retreat_tile(unit: Node, from_pos: Vector2) -> Vector2:
	var possible_tiles = []
	
	# Check all adjacent tiles
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
				
			var check_pos = Vector2(from_pos.x + x, from_pos.y + y)
			
			# Skip if outside grid or in combat
			if !unit_manager.is_valid_move(check_pos) or check_pos in combat_tiles:
				continue
			
			# Check if this is a friendly tile
			var is_friendly = false
			if unit.is_enemy:
				is_friendly = territory_manager.get_territory_owner(check_pos) == "enemy"
			else:
				is_friendly = territory_manager.get_territory_owner(check_pos) == "player"
			
			if is_friendly and unit_manager.units_in_cells[check_pos].size() < unit_manager.MAX_UNITS_PER_CELL:
				possible_tiles.append(check_pos)
	
	# Return closest friendly tile or Vector2(-1, -1) if none found
	if possible_tiles.size() > 0:
		return possible_tiles[0]
	return Vector2(-1, -1)

func execute_retreats():
	for retreat_data in retreating_units:
		var unit = retreat_data["unit"]
		var from_pos = retreat_data["from_pos"]
		
		var retreat_pos = find_retreat_tile(unit, from_pos)
		if retreat_pos != Vector2(-1, -1):
			# Remove unit from current position
			var current_units = unit_manager.units_in_cells[from_pos]
			current_units.erase(unit)
			
			# Add unit to new position
			if !unit_manager.units_in_cells.has(retreat_pos):
				unit_manager.units_in_cells[retreat_pos] = []
			unit_manager.units_in_cells[retreat_pos].append(unit)
			
			# Update unit position
			unit.position = unit_manager.get_parent().grid_to_world(retreat_pos)
			unit.has_moved = true
			
			# Check if we should remove combat status for this tile
			if unit_manager.units_in_cells[from_pos].size() == 0:
				var opposing_tile = combat_tiles[from_pos]
				combat_tiles.erase(from_pos)
				combat_tiles.erase(opposing_tile)

func get_weakest_unit(units: Array) -> Node:
	var weakest = units[0]
	var lowest_strength = weakest.soft_health + weakest.hard_health + weakest.equipment
	
	for unit in units:
		var strength = unit.soft_health + unit.hard_health + unit.equipment
		if strength < lowest_strength:
			weakest = unit
			lowest_strength = strength
	
	return weakest

func apply_damage(attacker: Node, defender: Node):
	defender.soft_health -= attacker.soft_attack
	defender.hard_health -= attacker.hard_attack
	defender.equipment -= 50  # Fixed equipment loss per attack
	
	defender.update_bars()

func resolve_combat(tile1: Vector2, tile2: Vector2):
	var units1 = unit_manager.units_in_cells[tile1]
	var units2 = unit_manager.units_in_cells[tile2]
	
	# Only have units that aren't retreating participate in combat
	var fighting_units1 = units1.filter(func(u): return not retreating_units.any(func(r): return r["unit"] == u))
	var fighting_units2 = units2.filter(func(u): return not retreating_units.any(func(r): return r["unit"] == u))
	
	# Process attacks
	for unit in fighting_units1:
		if fighting_units2.size() > 0:
			var target = get_weakest_unit(fighting_units2)
			apply_damage(unit, target)
	
	for unit in fighting_units2:
		if fighting_units1.size() > 0:
			var target = get_weakest_unit(fighting_units1)
			apply_damage(unit, target)
	
	cleanup_destroyed_units(tile1)
	cleanup_destroyed_units(tile2)

func cleanup_destroyed_units(tile_pos: Vector2):
	var units = unit_manager.units_in_cells[tile_pos]
	var i = units.size() - 1
	while i >= 0:
		var unit = units[i]
		if unit.soft_health <= 0 or unit.hard_health <= 0 or unit.equipment <= 0:
			units.remove_at(i)
			unit.queue_free()
			
			# If all units on one side are destroyed, remove combat status
			if units.size() == 0:
				var opposing_tile = combat_tiles[tile_pos]
				combat_tiles.erase(tile_pos)
				combat_tiles.erase(opposing_tile)
		i -= 1

func draw(grid_node: Node2D):
	# Draw combat tiles with black color
	for pos in combat_tiles.keys():
		var rect = Rect2(
			pos.x * grid_node.tile_size.x,
			pos.y * grid_node.tile_size.y,
			grid_node.tile_size.x,
			grid_node.tile_size.y
		)
		# Using black color with some transparency
		grid_node.draw_rect(rect, Color(0, 0, 0, 0.5))
