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
func resolve_combat(attacker: Node2D, defender: Node2D):
	if !is_instance_valid(attacker) or !is_instance_valid(defender):
		print("Combat cancelled - invalid units")
		return
		
	print("\nCOMBAT RESOLUTION:")
	print("Starting combat calculation...")
	
	# Get positions before any potential unit removal
	var attacker_pos = get_unit_position(attacker)
	var defender_pos = get_unit_position(defender)
	
	if attacker_pos == Vector2.ZERO or defender_pos == Vector2.ZERO:
		print("Combat cancelled - invalid positions")
		return
	
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
	
	# Calculate all damage first
	var base_damage_to_defender_soft = attacker.soft_attack
	var base_damage_to_defender_hard = attacker.hard_attack
	var base_damage_to_attacker_soft = defender.soft_attack
	var base_damage_to_attacker_hard = defender.hard_attack
	
	# Calculate defense bonuses
	var base_defense_reduction = 0.2
	var fort_reduction = 0.0
	
	if building_manager.fort_levels.has(defender_pos):
		fort_reduction = building_manager.fort_levels[defender_pos] * 0.02
	
	var total_reduction = base_defense_reduction + fort_reduction
	var damage_multiplier = 1.0 - total_reduction
	
	# Calculate final damage values
	var final_damage_to_defender_soft = base_damage_to_defender_soft * damage_multiplier
	var final_damage_to_defender_hard = base_damage_to_defender_hard * damage_multiplier
	var final_damage_to_defender_equipment = (base_damage_to_defender_soft + base_damage_to_defender_hard) * 0.5 * damage_multiplier
	
	var final_damage_to_attacker_soft = base_damage_to_attacker_soft
	var final_damage_to_attacker_hard = base_damage_to_attacker_hard
	var final_damage_to_attacker_equipment = (base_damage_to_attacker_soft + base_damage_to_attacker_hard) * 0.5
	
	# Mark combat participation
	if is_instance_valid(attacker):
		attacker.in_combat_this_turn = true
	if is_instance_valid(defender):
		defender.in_combat_this_turn = true
	
	# Apply damage and check for destruction
	var units_to_destroy = []
	
	# Apply damage to defender
	if is_instance_valid(defender):
		defender.soft_health = max(0, defender.soft_health - final_damage_to_defender_soft)
		defender.hard_health = max(0, defender.hard_health - final_damage_to_defender_hard)
		defender.equipment = max(0, defender.equipment - final_damage_to_defender_equipment)
		defender.update_bars()
		
		if (defender.soft_health <= 0 and defender.hard_health <= 0) or defender.equipment <= 0:
			units_to_destroy.append({"unit": defender, "position": defender_pos})
	
	# Apply damage to attacker
	if is_instance_valid(attacker):
		attacker.soft_health = max(0, attacker.soft_health - final_damage_to_attacker_soft)
		attacker.hard_health = max(0, attacker.hard_health - final_damage_to_attacker_hard)
		attacker.equipment = max(0, attacker.equipment - final_damage_to_attacker_equipment)
		attacker.update_bars()
		
		if (attacker.soft_health <= 0 and attacker.hard_health <= 0) or attacker.equipment <= 0:
			units_to_destroy.append({"unit": attacker, "position": attacker_pos})
	
	# Print combat results
	print("\nCombat Results:")
	print("Damage dealt to defender - Soft: ", final_damage_to_defender_soft, 
		  " Hard: ", final_damage_to_defender_hard, 
		  " Equipment: ", final_damage_to_defender_equipment)
	print("Damage dealt to attacker - Soft: ", final_damage_to_attacker_soft, 
		  " Hard: ", final_damage_to_attacker_hard, 
		  " Equipment: ", final_damage_to_attacker_equipment)
	
	# Handle unit destruction
	for unit_data in units_to_destroy:
		var unit = unit_data["unit"]
		var pos = unit_data["position"]
		
		if is_instance_valid(unit) and pos != Vector2.ZERO:
			if pos in unit_manager.units_in_cells:
				unit_manager.units_in_cells[pos].erase(unit)
				print("Removed unit from position: ", pos)
			unit.queue_free()
			print("Unit destroyed!")

func initiate_combat(attacker_pos: Vector2, defender_pos: Vector2):
	print("\nINITIATING COMBAT:")
	print("Attacker position: ", attacker_pos)
	print("Defender position: ", defender_pos)
	
	var attacking_units = unit_manager.units_in_cells[attacker_pos]
	var defending_units = unit_manager.units_in_cells[defender_pos]
	
	if attacking_units.size() > 0 and defending_units.size() > 0:
		var attacker = unit_manager.selected_unit if unit_manager.selected_unit else attacking_units[0]
		var defender = defending_units[0]
		
		if !is_instance_valid(attacker) or !is_instance_valid(defender):
			print("Combat cancelled - invalid units")
			return
		
		print("Combat Starting!")
		print("Attacker type: ", attacker.scene_file_path)
		print("Defender type: ", defender.scene_file_path)
		
		# Add flash effect
		if attacker.has_node("Sprite2D"):
			attacker.get_node("Sprite2D").modulate = Color(1, 0, 0)
		if defender.has_node("Sprite2D"):
			defender.get_node("Sprite2D").modulate = Color(1, 0, 0)
		
		# Resolve combat
		resolve_combat(attacker, defender)
		
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
