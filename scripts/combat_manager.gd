extends Node2D

# Dictionary to track which units are currently in combat
var units_in_combat = []

@onready var unit_manager = get_parent().get_node("UnitManager")
@onready var building_manager = get_parent().get_node("BuildingManager")

# Utility function to safely get a unit's position
func get_unit_position(unit: Node2D) -> Vector2:
	if !is_instance_valid(unit):
		return Vector2.ZERO
		
	for pos in unit_manager.units_in_cells:
		if unit in unit_manager.units_in_cells[pos]:
			return pos
	return Vector2.ZERO

# Process combat between two units
# In combat_manager.gd

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
	
	# Store initial stats
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
	
	# Calculate all damage first
	var base_damage_to_defender_soft = attacker.soft_attack
	var base_damage_to_defender_hard = attacker.hard_attack
	var base_damage_to_attacker_soft = defender.soft_attack
	var base_damage_to_attacker_hard = defender.hard_attack
	
	print("Base damage calculations:")
	print("To defender - Soft: ", base_damage_to_defender_soft, " Hard: ", base_damage_to_defender_hard)
	print("To attacker - Soft: ", base_damage_to_attacker_soft, " Hard: ", base_damage_to_attacker_hard)
	
	# Calculate defense bonuses
	var base_defense_reduction = 0.2  # 20% base defense
	var fort_reduction = 0.0
	
	if building_manager.fort_levels.has(defender_pos):
		fort_reduction = building_manager.fort_levels[defender_pos] * 0.02  # 2% per fort level
		print("Fort level at defender position: ", building_manager.fort_levels[defender_pos])
	
	var total_reduction = base_defense_reduction + fort_reduction
	print("Total defense reduction: ", total_reduction)
	var damage_multiplier = 1.0 - total_reduction
	
	# Calculate final damage values
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
	
	# Mark combat participation
	attacker.in_combat_this_turn = true
	defender.in_combat_this_turn = true
	
	# Units to be destroyed
	var units_to_destroy = []
	
	# Apply damage to defender
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
	
	# Apply damage to attacker
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
	
	# Handle unit destruction
	print("\nDestroying units:")
	for unit_data in units_to_destroy:
		var unit = unit_data["unit"]
		var pos = unit_data["position"]
		
		if is_instance_valid(unit):
			print("Destroying unit at position: ", pos)
			if pos in unit_manager.units_in_cells:
				unit_manager.units_in_cells[pos].erase(unit)
			unit.queue_free()

func initiate_combat(attacker_pos: Vector2, defender_pos: Vector2):
	print("\nDEBUG: INITIATING COMBAT:")
	print("Attacker position: ", attacker_pos)
	print("Defender position: ", defender_pos)
	
	# Validate positions are within grid bounds
	if attacker_pos.x < 0 or attacker_pos.x >= unit_manager.grid.grid_size.x or \
	   attacker_pos.y < 0 or attacker_pos.y >= unit_manager.grid.grid_size.y or \
	   defender_pos.x < 0 or defender_pos.x >= unit_manager.grid.grid_size.x or \
	   defender_pos.y < 0 or defender_pos.y >= unit_manager.grid.grid_size.y:
		print("Combat cancelled - positions out of bounds")
		return
	
	var attacking_units = unit_manager.units_in_cells[attacker_pos]
	var defending_units = unit_manager.units_in_cells[defender_pos]
	
	# Debug print the units at both positions
	print("\nUnits at attacker position:")
	if attacker_pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[attacker_pos]:
			print("- ", unit.scene_file_path, " (enemy: ", unit.is_enemy, ")")
	
	print("\nUnits at defender position:")
	if defender_pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[defender_pos]:
			print("- ", unit.scene_file_path, " (enemy: ", unit.is_enemy, ")")
	
	if attacking_units.size() > 0 and defending_units.size() > 0:
		# Find the first valid attacking unit
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
		
		# Find the first valid defending unit
		var defender = null
		for unit in defending_units:
			if !unit.in_combat_this_turn:
				defender = unit
				print("Found valid defending unit: ", defender.scene_file_path)
				break
		
		if !attacker or !defender:
			print("Combat cancelled - no valid units found")
			return
			
		if !is_instance_valid(attacker) or !is_instance_valid(defender):
			print("Combat cancelled - invalid units")
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
		
		# Resolve combat with grid positions
		resolve_combat(attacker, defender, attacker_pos, defender_pos)
		
		# Wait a moment
		await get_tree().create_timer(0.2).timeout
		
		# Reset colors if units still exist
		if is_instance_valid(attacker) and !attacker.is_queued_for_deletion() and attacker.has_node("Sprite2D"):
			attacker.get_node("Sprite2D").modulate = Color.WHITE if !attacker.is_enemy else Color.RED
		if is_instance_valid(defender) and !defender.is_queued_for_deletion() and defender.has_node("Sprite2D"):
			defender.get_node("Sprite2D").modulate = Color.WHITE if !defender.is_enemy else Color.RED
	else:
		print("Combat failed - missing units!")

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
