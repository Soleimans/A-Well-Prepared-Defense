extends Button

@onready var label = %Label  # Path to Build label
@onready var points_label = get_node("../ColorRect/HBoxContainer/Label")
@onready var military_points_label = get_node("../ColorRect/HBoxContainer/Label2")
@onready var grid_node = get_node("/root/Main/Grid")
@onready var turn_count_label = get_node("../TurnCount")
@onready var territory_manager = grid_node.get_node("TerritoryManager") if grid_node else null

var value = 1000  # Starting value
var points_per_civilian_factory = 2000
var points_per_military_factory = 500

func _ready():
	pressed.connect(_on_button_pressed)
	label.text = "Build " + str(value)
	
	print("Turn button ready!")
	print("Points label found: ", points_label != null)
	print("Military points label found: ", military_points_label != null)
	print("Grid node found: ", grid_node != null)
	print("Territory manager found: ", territory_manager != null)

func _on_button_pressed():
	print("\n=== TURN BUTTON PRESSED ===")
	print("Processing turn effects...")
	
	# Save current building selection
	var current_selection = ""
	if grid_node:
		var building_manager = grid_node.get_node("BuildingManager")
		current_selection = building_manager.selected_building_type if building_manager else ""
		
		var unit_manager = grid_node.get_node("UnitManager")
		var resource_manager = grid_node.get_node("ResourceManager")
		var combat_manager = grid_node.get_node("CombatManager")
		var opponent_manager = grid_node.get_node("OpponentManager")
		var combatant_manager = grid_node.get_node("CombatantManager")  # Add reference to CombatantManager
		
		print("Found building manager: ", building_manager != null)
		print("Found opponent manager: ", opponent_manager != null)
		print("Found combatant manager: ", combatant_manager != null)  # Debug output
		
		# Process combat first
		if combat_manager:
			combat_manager.process_turn()
		
		# Process replenishment for all units
		var player_military_cost = 0
		var player_manpower_cost = 0
		var enemy_military_cost = 0
		var enemy_manpower_cost = 0
		
		print("\nProcessing unit replenishment...")
		for pos in unit_manager.units_in_cells:
			for unit in unit_manager.units_in_cells[pos]:
				if unit.has_method("try_replenish"):
					var result = unit.try_replenish()
					if result.replenished:
						print("Replenishing unit at position ", pos)
						if unit.is_enemy:
							enemy_military_cost += result.military_cost
							enemy_manpower_cost += result.manpower_cost
							print("Enemy costs - Military: ", result.military_cost, " Manpower: ", result.manpower_cost)
						else:
							player_military_cost += result.military_cost
							player_manpower_cost += result.manpower_cost
							print("Player costs - Military: ", result.military_cost, " Manpower: ", result.manpower_cost)
		
		# Get factory counts and generate points
		var factory_counts = get_factory_counts()
		
		# Generate player points
		var points_generated = factory_counts["civilian"] * points_per_civilian_factory
		var military_points_generated = factory_counts["military"] * points_per_military_factory
		
		# Generate enemy points
		var enemy_points_generated = factory_counts["enemy_civilian"] * points_per_civilian_factory
		var enemy_military_points_generated = factory_counts["enemy_military"] * points_per_military_factory
		
		print("\nFactory Production:")
		print("Player Civilian factories: ", factory_counts["civilian"])
		print("Player Military factories: ", factory_counts["military"])
		print("Enemy Civilian factories: ", factory_counts["enemy_civilian"])
		print("Enemy Military factories: ", factory_counts["enemy_military"])
		print("Generated player points: ", points_generated)
		print("Generated player military points: ", military_points_generated)
		print("Generated enemy points: ", enemy_points_generated)
		print("Generated enemy military points: ", enemy_military_points_generated)
		
		# Deduct replenishment costs first
		resource_manager.military_points -= player_military_cost
		resource_manager.manpower -= player_manpower_cost
		resource_manager.enemy_military_points -= enemy_military_cost
		resource_manager.enemy_manpower -= enemy_manpower_cost
		
		print("\nReplenishment costs processed:")
		print("Player military cost: ", player_military_cost)
		print("Player manpower cost: ", player_manpower_cost)
		print("Enemy military cost: ", enemy_military_cost)
		print("Enemy manpower cost: ", enemy_manpower_cost)
		
		# Add generated points for player
		resource_manager.points += points_generated
		resource_manager.military_points += military_points_generated
		
		# Add generated points for enemy
		resource_manager.enemy_points += enemy_points_generated
		resource_manager.enemy_military_points += enemy_military_points_generated
		
		# Add political power for player
		var political_power_gain = resource_manager.calculate_political_power_gain()
		resource_manager.political_power += political_power_gain
		print("Generated player political power: ", political_power_gain)
		
		# Add political power for enemy
		var enemy_political_power_gain = resource_manager.calculate_political_power_gain(true)
		resource_manager.enemy_political_power += enemy_political_power_gain
		print("Generated enemy political power: ", enemy_political_power_gain)
		
		# Reset unit movements
		for pos in unit_manager.units_in_cells:
			for unit in unit_manager.units_in_cells[pos]:
				if unit.has_method("reset_movement"):
					unit.reset_movement()
					print("Reset movement for unit at position: ", pos)
		
		# Process construction progress
		building_manager.process_construction()
		print("Construction processing complete")
		
		# Process enemy AI turn
		if opponent_manager:
			print("\nProcessing enemy AI turn...")
			opponent_manager._on_turn_button_pressed()
			print("Enemy AI turn complete")
		else:
			print("ERROR: OpponentManager not found!")
			
		# Process enemy unit deployment
		if combatant_manager:
			print("\nProcessing enemy unit deployment...")
			combatant_manager._on_turn_button_pressed()
			print("Enemy unit deployment complete")
		else:
			print("ERROR: CombatantManager not found!")
		
		# Clear any selected unit and valid move tiles
		unit_manager.selected_unit = null
		unit_manager.valid_move_tiles.clear()
	else:
		print("ERROR: Grid node not found!")
	
	# Update turn count
	if turn_count_label:
		turn_count_label.increment_turn()
		print("Turn count updated")
	else:
		print("ERROR: Turn count label not found!")
	
	# Increment build value
	value += 100
	label.text = "Build " + str(value)
	print("Build value updated to: ", value)
	
	# Restore building selection if it was active
	if grid_node and current_selection != "":
		var building_manager = grid_node.get_node("BuildingManager")
		if building_manager:
			building_manager.selected_building_type = current_selection
			print("Restored building selection to: ", current_selection)
	
	print("=== TURN PROCESSING COMPLETE ===\n")

func _unhandled_input(event):
	if has_focus():  # Prevent processing if the button is focused
		return
	
	if event.is_action_pressed("ui_accept"):  # Catch the spacebar press
		_on_button_pressed()

func get_factory_counts() -> Dictionary:
	var counts = {
		"civilian": 0, 
		"military": 0,
		"enemy_civilian": 0,
		"enemy_military": 0
	}
	
	if grid_node:
		var building_manager = grid_node.get_node("BuildingManager")
		var construction_positions = building_manager.buildings_under_construction.keys()
		
		for pos in building_manager.grid_cells:
			var cell = building_manager.grid_cells[pos]
			if cell and not pos in construction_positions:
				var is_enemy = territory_manager and territory_manager.get_territory_owner(pos) == "enemy"
					
				# Check if this is a factory by its scene path
				if cell.scene_file_path == "res://scenes/civilian_factory.tscn":
					if is_enemy:
						counts["enemy_civilian"] += 1
						print("Found a completed enemy civilian factory")
					else:
						counts["civilian"] += 1
						print("Found a completed civilian factory")
				elif cell.scene_file_path == "res://scenes/military_factory.tscn":
					if is_enemy:
						counts["enemy_military"] += 1
						print("Found a completed enemy military factory")
					else:
						counts["military"] += 1
						print("Found a completed military factory")
				
				# If there are multiple nodes at this position, check them too
				for child in cell.get_children():
					if not child.scene_file_path:
						continue
					if child.scene_file_path == "res://scenes/civilian_factory.tscn":
						if is_enemy:
							counts["enemy_civilian"] += 1
							print("Found a completed enemy civilian factory")
						else:
							counts["civilian"] += 1
							print("Found a completed civilian factory")
					elif child.scene_file_path == "res://scenes/military_factory.tscn":
						if is_enemy:
							counts["enemy_military"] += 1
							print("Found a completed enemy military factory")
						else:
							counts["military"] += 1
							print("Found a completed military factory")
	
	return counts
