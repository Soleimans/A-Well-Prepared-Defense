extends Node2D

var units_in_combat = []

@onready var unit_manager = get_parent().get_node("UnitManager")
@onready var building_manager = get_parent().get_node("BuildingManager")

func get_unit_position(unit: Node2D) -> Vector2:
	if !is_instance_valid(unit):
		return Vector2.ZERO
		
	for pos in unit_manager.units_in_cells:
		if unit in unit_manager.units_in_cells[pos]:
			return pos
	return Vector2.ZERO

func can_attack_position(from_pos: Vector2, to_pos: Vector2, unit: Node2D) -> bool:
	if !unit:
		return false
		
	var dx = abs(to_pos.x - from_pos.x)
	var dy = abs(to_pos.y - from_pos.y)
	
	if unit.scene_file_path.contains("garrison"):
		return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)
	
	return dx <= 1 and dy <= 1 and !(dx == 0 and dy == 0)

func get_enemy_units_at(pos: Vector2) -> Array:
	var enemy_units = []
	if !unit_manager.selected_unit:
		return enemy_units
		
	if pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[pos]:
			if unit.is_enemy != unit_manager.selected_unit.is_enemy:
				enemy_units.append(unit)
	return enemy_units

func is_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	print("Checking adjacency - dx: ", dx, " dy: ", dy)
	return dx <= 1 and dy <= 1 and pos1 != pos2

func has_adjacent_enemies(pos: Vector2, unit: Node2D) -> bool:
	if !unit:
		return false

	# Check all adjacent positions
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
				
			if unit.scene_file_path.contains("garrison") and abs(dx) + abs(dy) > 1:
				continue
				
			var check_pos = pos + Vector2(dx, dy)
			if check_pos.x < 0 or check_pos.x >= unit_manager.grid.grid_size.x or \
			   check_pos.y < 0 or check_pos.y >= unit_manager.grid.grid_size.y:
				continue
			
			if check_pos in unit_manager.units_in_cells:
				for other_unit in unit_manager.units_in_cells[check_pos]:
					if other_unit.is_enemy != unit.is_enemy:
						return true
	return false

func find_attack_position(from_pos: Vector2, target_pos: Vector2) -> Vector2:
	# If we are adjacent, use current 
	if is_adjacent(from_pos, target_pos):
		return from_pos
	
	var is_armoured = unit_manager.selected_unit.scene_file_path.contains("armoured")
	var max_range = 2 if is_armoured else 1
	
	# find positions we can move to
	var moveable_positions = []
	if unit_manager.selected_unit.movement_points > 0:
		for x in range(max(0, from_pos.x - max_range), min(unit_manager.grid.grid_size.x, from_pos.x + max_range + 1)):
			for y in range(max(0, from_pos.y - max_range), min(unit_manager.grid.grid_size.y, from_pos.y + max_range + 1)):
				var pos = Vector2(x, y)
				if pos == from_pos:
					continue
					
				var distance = max(abs(pos.x - from_pos.x), abs(pos.y - from_pos.y))
				if !is_armoured and distance > 1:
					continue
					
				if distance > unit_manager.selected_unit.movement_points:
					continue
					
				if !unit_manager.movement_handler.is_position_in_territory(pos, unit_manager.selected_unit.is_enemy):
					continue
					
				if !unit_manager.movement_handler.is_path_blocked(from_pos, pos, unit_manager.selected_unit):
					if !unit_manager.units_in_cells.has(pos) or unit_manager.units_in_cells[pos].size() < unit_manager.MAX_UNITS_PER_CELL:
						moveable_positions.append(pos)
	else:
		# If we can't move, we can only attack from our current position
		moveable_positions = [from_pos]
	
	# From each position we can move to, check if we can attack
	var attack_positions = []
	for move_pos in moveable_positions:
		if can_attack_position(move_pos, target_pos, unit_manager.selected_unit):
			attack_positions.append({
				"position": move_pos,
				"distance": max(abs(move_pos.x - from_pos.x), abs(move_pos.y - from_pos.y)),
				"surrounding_enemies": count_surrounding_enemies(move_pos)
			})
	
	# Sort positions
	attack_positions.sort_custom(func(a, b):
		# prioritize minimizing movement points used
		if a.distance != b.distance:
			return a.distance < b.distance
		
		#  prefer positions with fewer enemies around
		if a.surrounding_enemies != b.surrounding_enemies:
			return a.surrounding_enemies < b.surrounding_enemies
		
		# prefer positions closer to starting position
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
			if check_pos.x < 0 or check_pos.x >= unit_manager.grid.grid_size.x or \
			   check_pos.y < 0 or check_pos.y >= unit_manager.grid.grid_size.y:
				continue
			
			if check_pos in unit_manager.units_in_cells:
				for unit in unit_manager.units_in_cells[check_pos]:
					if unit.is_enemy != unit_manager.selected_unit.is_enemy:
						count += 1
						break
	return count

func initiate_combat(attacker_pos: Vector2, defender_pos: Vector2):
	print("\nDEBUG: INITIATING COMBAT:")
	print("Attacker position: ", attacker_pos)
	print("Defender position: ", defender_pos)
	
	# check if positions are within grid bounds
	if attacker_pos.x < 0 or attacker_pos.x >= unit_manager.grid.grid_size.x or \
	   attacker_pos.y < 0 or attacker_pos.y >= unit_manager.grid.grid_size.y or \
	   defender_pos.x < 0 or defender_pos.x >= unit_manager.grid.grid_size.x or \
	   defender_pos.y < 0 or defender_pos.y >= unit_manager.grid.grid_size.y:
		print("Combat cancelled - positions out of bounds")
		return
	
	var attacking_units = unit_manager.units_in_cells[attacker_pos]
	var defending_units = unit_manager.units_in_cells[defender_pos]
	
	print("\nUnits at attacker position:")
	if attacker_pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[attacker_pos]:
			print("- ", unit.scene_file_path, " (enemy: ", unit.is_enemy, ")")
	
	print("\nUnits at defender position:")
	if defender_pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[defender_pos]:
			print("- ", unit.scene_file_path, " (enemy: ", unit.is_enemy, ")")
	
	if attacking_units.size() > 0 and defending_units.size() > 0:
		# Find the attacking unit (use selected unit if available, else first valid unit)
		var attacker = null
		if unit_manager.selected_unit and unit_manager.selected_unit in attacking_units:
			attacker = unit_manager.selected_unit
			print("Using selected unit as attacker: ", attacker.scene_file_path)
		else:
			for unit in attacking_units:
				if !unit.in_combat_this_turn:
					attacker = unit
					print("Found valid attacking unit: ", attacker.scene_file_path)
					break
		
		# Get the defender (bottom unit in stack)
		var defender = defending_units[0] 
		print("Using bottom unit as defender: ", defender.scene_file_path)
		
		if !attacker or !defender:
			print("Combat cancelled - no valid units found")
			return
			
		if !is_instance_valid(attacker) or !is_instance_valid(defender):
			print("Combat cancelled - invalid units")
			return
			
		# Check if attack is valid based on unit type
		if !can_attack_position(attacker_pos, defender_pos, attacker):
			print("Combat cancelled - invalid attack position for unit type")
			return
		
		print("Combat Starting!")
		print("Attacker type: ", attacker.scene_file_path)
		print("Defender type: ", defender.scene_file_path)
		print("Attacker position in world: ", attacker.position)
		print("Defender position in world: ", defender.position)
		print("Attacker health - Soft: ", attacker.soft_health, " Hard: ", attacker.hard_health)
		print("Defender health - Soft: ", defender.soft_health, " Hard: ", defender.hard_health)
		
		# Add flash effect
		if attacker.has_node("Sprite2D"):
			attacker.get_node("Sprite2D").modulate = Color(1, 0, 0)
		if defender.has_node("Sprite2D"):
			defender.get_node("Sprite2D").modulate = Color(1, 0, 0)
		
		resolve_combat(attacker, defender, attacker_pos, defender_pos)
		
		await get_tree().create_timer(0.2).timeout
		
		# Reset colors if units still exist
		if is_instance_valid(attacker) and !attacker.is_queued_for_deletion() and attacker.has_node("Sprite2D"):
			attacker.get_node("Sprite2D").modulate = Color.WHITE if !attacker.is_enemy else Color.RED
		if is_instance_valid(defender) and !defender.is_queued_for_deletion() and defender.has_node("Sprite2D"):
			defender.get_node("Sprite2D").modulate = Color.WHITE if !defender.is_enemy else Color.RED
	else:
		print("Combat failed - missing units!")

func resolve_combat(attacker: Node2D, defender: Node2D, attacker_pos: Vector2, defender_pos: Vector2):
	if !is_instance_valid(attacker) or !is_instance_valid(defender):
		print("Combat cancelled - invalid units")
		return
	
	print("\nDEBUG: COMBAT RESOLUTION:")
	print("Attacker scene path: ", attacker.scene_file_path)
	print("Defender scene path: ", defender.scene_file_path)
	print("Attacker is enemy: ", attacker.is_enemy)
	print("Defender is enemy: ", defender.is_enemy)
	print("Attacker grid position: ", attacker_pos)
	print("Defender grid position: ", defender_pos)
	print("Attacker position in world: ", attacker.position)
	print("Defender position in world: ", defender.position)
	
	var initial_attacker_stats = {
		"soft_health": attacker.soft_health,
		"hard_health": attacker.hard_health,
		"equipment": attacker.equipment
	}
	
	var initial_defender_stats = {
		"soft_health": defender.soft_health,
		"hard_health": defender.hard_health,
		"equipment": defender.equipment
	}
	
	print("Initial attacker stats - Soft: ", initial_attacker_stats.soft_health, 
		  " Hard: ", initial_attacker_stats.hard_health,
		  " Equipment: ", initial_attacker_stats.equipment)
	print("Initial defender stats - Soft: ", initial_defender_stats.soft_health,
		  " Hard: ", initial_defender_stats.hard_health,
		  " Equipment: ", initial_defender_stats.equipment)
	
	var base_damage_to_defender_soft = attacker.soft_attack
	var base_damage_to_defender_hard = attacker.hard_attack
	var base_damage_to_attacker_soft = defender.soft_attack
	var base_damage_to_attacker_hard = defender.hard_attack
	
	print("Base damage calculations:")
	print("To defender - Soft: ", base_damage_to_defender_soft, " Hard: ", base_damage_to_defender_hard)
	print("To attacker - Soft: ", base_damage_to_attacker_soft, " Hard: ", base_damage_to_attacker_hard)
	
	var base_defense_reduction = 0.2  
	var fort_reduction = 0.0
	
	if building_manager.fort_levels.has(defender_pos):
		fort_reduction = building_manager.fort_levels[defender_pos] * 0.02  
		print("Fort level at defender position: ", building_manager.fort_levels[defender_pos])
	
	var total_reduction = base_defense_reduction + fort_reduction
	print("Total defense reduction: ", total_reduction)
	var damage_multiplier = 1.0 - total_reduction
	
	var final_damage_to_defender_soft = base_damage_to_defender_soft * damage_multiplier
	var final_damage_to_defender_hard = base_damage_to_defender_hard * damage_multiplier
	var final_damage_to_defender_equipment = (base_damage_to_defender_soft + base_damage_to_defender_hard) * 0.5 * damage_multiplier
	
	var final_damage_to_attacker_soft = base_damage_to_attacker_soft
	var final_damage_to_attacker_hard = base_damage_to_attacker_hard
	var final_damage_to_attacker_equipment = (base_damage_to_attacker_soft + base_damage_to_attacker_hard) * 0.5
	
	print("Final damage calculations:")
	print("To defender - Soft: ", final_damage_to_defender_soft, 
		  " Hard: ", final_damage_to_defender_hard,
		  " Equipment: ", final_damage_to_defender_equipment)
	print("To attacker - Soft: ", final_damage_to_attacker_soft,
		  " Hard: ", final_damage_to_attacker_hard,
		  " Equipment: ", final_damage_to_attacker_equipment)
	
	attacker.in_combat_this_turn = true
	defender.in_combat_this_turn = false
	
	var units_to_destroy = []
	
	if is_instance_valid(defender):
		print("\nApplying damage to defender:")
		print("Before - Soft: ", defender.soft_health, " Hard: ", defender.hard_health, " Equipment: ", defender.equipment)
		
		defender.soft_health = max(0, defender.soft_health - final_damage_to_defender_soft)
		defender.hard_health = max(0, defender.hard_health - final_damage_to_defender_hard)
		defender.equipment = max(0, defender.equipment - final_damage_to_defender_equipment)
		
		print("After - Soft: ", defender.soft_health, " Hard: ", defender.hard_health, " Equipment: ", defender.equipment)
		
		defender.update_bars()
		
		if (defender.soft_health <= 0 and defender.hard_health <= 0) or defender.equipment <= 0:
			units_to_destroy.append({"unit": defender, "position": defender_pos})
	
	if is_instance_valid(attacker):
		print("\nApplying damage to attacker:")
		print("Before - Soft: ", attacker.soft_health, " Hard: ", attacker.hard_health, " Equipment: ", attacker.equipment)
		
		attacker.soft_health = max(0, attacker.soft_health - final_damage_to_attacker_soft)
		attacker.hard_health = max(0, attacker.hard_health - final_damage_to_attacker_hard)
		attacker.equipment = max(0, attacker.equipment - final_damage_to_attacker_equipment)
		
		print("After - Soft: ", attacker.soft_health, " Hard: ", attacker.hard_health, " Equipment: ", attacker.equipment)
		
		attacker.update_bars()
		
		if (attacker.soft_health <= 0 and attacker.hard_health <= 0) or attacker.equipment <= 0:
			units_to_destroy.append({"unit": attacker, "position": attacker_pos})
	
	print("\nDestroying units:")
	for unit_data in units_to_destroy:
		var unit = unit_data["unit"]
		var pos = unit_data["position"]
		
		if is_instance_valid(unit):
			print("Destroying unit at position: ", pos)
			if pos in unit_manager.units_in_cells:
				unit_manager.units_in_cells[pos].erase(unit)
			unit.queue_free()

func process_turn():
	units_in_combat.clear()

func draw(grid_node: Node2D):
	for unit_pos in unit_manager.units_in_cells:
		var units = unit_manager.units_in_cells[unit_pos]
		for unit in units:
			if unit in units_in_combat:
				var rect = Rect2(
					unit_pos.x * grid_node.tile_size.x,
					unit_pos.y * grid_node.tile_size.y,
					grid_node.tile_size.x,
					grid_node.tile_size.y
				)
				grid_node.draw_rect(rect, Color(1, 0, 0, 0.3))
