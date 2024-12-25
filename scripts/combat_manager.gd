extends Node2D

# Dictionary to track which units are currently in combat
var units_in_combat = []

@onready var unit_manager = get_parent().get_node("UnitManager")
@onready var building_manager = get_parent().get_node("BuildingManager")

# Process combat between two units
func resolve_combat(attacker: Node2D, defender: Node2D):
	# Mark both units as having participated in combat
	attacker.in_combat_this_turn = true
	defender.in_combat_this_turn = true
	
	print("\nCOMBAT RESOLUTION:")
	print("Attacker before - Soft Health: ", attacker.soft_health, " Hard Health: ", attacker.hard_health, " Equipment: ", attacker.equipment)
	print("Defender before - Soft Health: ", defender.soft_health, " Hard Health: ", defender.hard_health, " Equipment: ", defender.equipment)
	
	# Store original health values
	var attacker_original_soft = attacker.soft_health
	var attacker_original_hard = attacker.hard_health
	var defender_original_soft = defender.soft_health
	var defender_original_hard = defender.hard_health
	
	# Calculate base damage first
	var damage_to_defender_soft = attacker.soft_attack
	var damage_to_defender_hard = attacker.hard_attack
	var damage_to_attacker_soft = defender.soft_attack
	var damage_to_attacker_hard = defender.hard_attack
	
	# Find defender's position
	var defender_pos = Vector2.ZERO
	for pos in unit_manager.units_in_cells:
		if defender in unit_manager.units_in_cells[pos]:
			defender_pos = pos
			break
	
	# Calculate total damage reduction
	var base_defense_reduction = 0.2  # 20% base defense bonus
	var fort_reduction = 0.0
	
	# Check for fort at defender's position
	if defender_pos != Vector2.ZERO and building_manager.fort_levels.has(defender_pos):
		var fort_level = building_manager.fort_levels[defender_pos]
		fort_reduction = fort_level * 0.02  # 2% per level
	
	var total_reduction = base_defense_reduction + fort_reduction
	var damage_multiplier = 1.0 - total_reduction
	
	# Apply total damage reduction to defender
	damage_to_defender_soft *= damage_multiplier
	damage_to_defender_hard *= damage_multiplier
	
	# Calculate equipment damage with defense bonus
	var equipment_damage_to_defender = (attacker.soft_attack + attacker.hard_attack) * 0.5 * damage_multiplier
	var equipment_damage_to_attacker = (defender.soft_attack + defender.hard_attack) * 0.5
	
	print("Combat modifiers - Base defense: -20%, Fort level reduction: -" + str(fort_reduction * 100) + "%, Total reduction: -" + str(total_reduction * 100) + "%")
	
	# Apply health damage
	defender.soft_health = max(0, defender.soft_health - damage_to_defender_soft)
	defender.hard_health = max(0, defender.hard_health - damage_to_defender_hard)
	attacker.soft_health = max(0, attacker.soft_health - damage_to_attacker_soft)
	attacker.hard_health = max(0, attacker.hard_health - damage_to_attacker_hard)
	
	# Apply equipment damage
	defender.equipment = max(0, defender.equipment - equipment_damage_to_defender)
	attacker.equipment = max(0, attacker.equipment - equipment_damage_to_attacker)
	
	# Update health and equipment bars
	attacker.update_bars()
	defender.update_bars()
	
	print("Damage dealt to defender - Soft: ", damage_to_defender_soft, " Hard: ", damage_to_defender_hard, " Equipment: ", equipment_damage_to_defender)
	print("Damage dealt to attacker - Soft: ", damage_to_attacker_soft, " Hard: ", damage_to_attacker_hard, " Equipment: ", equipment_damage_to_attacker)
	print("Attacker after - Soft Health: ", attacker.soft_health, " Hard Health: ", attacker.hard_health, " Equipment: ", attacker.equipment)
	print("Defender after - Soft Health: ", defender.soft_health, " Hard Health: ", defender.hard_health, " Equipment: ", defender.equipment)

func check_unit_destroyed(unit: Node2D):
	# Unit is destroyed if both health types are 0 OR if equipment is 0
	if (unit.soft_health <= 0 and unit.hard_health <= 0) or unit.equipment <= 0:
		print("Unit destroyed! Soft Health: ", unit.soft_health, " Hard Health: ", unit.hard_health, " Equipment: ", unit.equipment)
		# Find the unit's position
		var unit_pos = Vector2.ZERO
		for pos in unit_manager.units_in_cells:
			if unit in unit_manager.units_in_cells[pos]:
				unit_pos = pos
				break
		
		# Remove the unit from the cell
		if unit_pos != Vector2.ZERO:
			unit_manager.units_in_cells[unit_pos].erase(unit)
			# Queue the unit for deletion
			unit.queue_free()
			print("Unit removed from position: ", unit_pos)

func initiate_combat(attacker_pos: Vector2, defender_pos: Vector2):
	print("\nINITIATING COMBAT:")
	print("Attacker position: ", attacker_pos)
	print("Defender position: ", defender_pos)
	
	var attacking_units = unit_manager.units_in_cells[attacker_pos]
	var defending_units = unit_manager.units_in_cells[defender_pos]
	
	print("Number of attacking units: ", attacking_units.size())
	print("Number of defending units: ", defending_units.size())
	
	if attacking_units.size() > 0 and defending_units.size() > 0:
		# For simplicity, just use the first unit from each side
		var attacker = attacking_units[0]
		var defender = defending_units[0]
		
		print("Combat Starting!")
		print("Attacker type: ", attacker.scene_file_path)
		print("Defender type: ", defender.scene_file_path)
		
		print("Attacker attacks - Soft: ", attacker.soft_attack, " Hard: ", attacker.hard_attack)
		print("Defender attacks - Soft: ", defender.soft_attack, " Hard: ", defender.hard_attack)
		
		# Add flash effect before combat
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
		
		# Check for destroyed units after resetting colors
		check_unit_destroyed(attacker)
		check_unit_destroyed(defender)
	else:
		print("Combat failed - missing units!")

func process_turn():
	# Clear the combat list at the start of each turn
	units_in_combat.clear()

func draw(grid_node: Node2D):
	# Draw combat indicator for units in combat
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
				# Draw a semi-transparent red overlay for units in combat
				grid_node.draw_rect(rect, Color(1, 0, 0, 0.3))
