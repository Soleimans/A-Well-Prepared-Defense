extends Node2D

@onready var unit_manager = get_parent()
@onready var grid = unit_manager.get_parent()
@onready var movement_handler = get_parent().get_node("UnitMovementHandler")

var current_unit_index: int = -1
var last_clicked_pos: Vector2 = Vector2(-1, -1)
var currently_highlighted_unit = null

func get_movable_units_at_position(grid_pos: Vector2) -> Array:
	var selectable_units = []
	print("\nChecking movable units at position: ", grid_pos)
	
	if grid_pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[grid_pos]:
			if unit and is_instance_valid(unit):
				# Add check to prevent enemy unit selection
				if unit.is_enemy:
					continue
					
				# Check if unit can move OR has valid attacks
				if unit.can_move() or has_valid_attacks(grid_pos, unit):
					print("Found selectable unit: ", unit.scene_file_path)
					selectable_units.append(unit)
	
	print("Total selectable units found: ", selectable_units.size())
	return selectable_units

func has_valid_attacks(pos: Vector2, unit: Node2D) -> bool:
	# Prevent enemy units from being considered for attacks
	if unit.is_enemy:
		return false
		
	var combat_manager = grid.get_node("CombatManager")
	if combat_manager and !unit.in_combat_this_turn:
		return combat_manager.has_adjacent_enemies(pos, unit)
	return false

func try_select_unit(grid_pos: Vector2):
	print("\nAttempting to select unit at position: ", grid_pos)
	
	# If there's currently a selected unit and it's an enemy, deselect it
	if unit_manager.selected_unit and unit_manager.selected_unit.is_enemy:
		deselect_current_unit()
		return
	
	# Check for combat initiation first
	if unit_manager.selected_unit:
		var combat_manager = grid.get_node("CombatManager")
		if combat_manager:
			var enemy_units = combat_manager.get_enemy_units_at(grid_pos)
			if enemy_units.size() > 0 and !unit_manager.selected_unit.in_combat_this_turn:
				if combat_manager.can_attack_position(unit_manager.unit_start_pos, grid_pos, unit_manager.selected_unit):
					combat_manager.initiate_combat(unit_manager.unit_start_pos, grid_pos)
					deselect_current_unit()
					return

	# If we've already attacked this turn, can't do anything else with this unit
	if unit_manager.selected_unit and unit_manager.selected_unit.in_combat_this_turn:
		deselect_current_unit()
		return
	
	# Check if clicking outside valid moves
	if unit_manager.selected_unit and !unit_manager.is_valid_move(grid_pos) and grid_pos != last_clicked_pos:
		deselect_current_unit()
		return
	
	var movable_units = get_movable_units_at_position(grid_pos)
	
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

func cycle_through_units(grid_pos: Vector2) -> bool:
	var movable_units = get_movable_units_at_position(grid_pos)
	print("\nCycling through units")
	print("Total movable units: ", movable_units.size())
	print("Current unit index: ", current_unit_index)
	
	if movable_units.size() == 0:
		print("No movable units found")
		current_unit_index = -1
		return false
		
	# Clear previous highlighting
	if currently_highlighted_unit:
		set_unit_highlight(currently_highlighted_unit, false)
		
	# Update current_unit_index
	if current_unit_index == -1 or !unit_manager.selected_unit:
		current_unit_index = 0
	else:
		current_unit_index = (current_unit_index + 1) % movable_units.size()
	
	print("New unit index: ", current_unit_index)
	
	# Select the next unit
	unit_manager.selected_unit = movable_units[current_unit_index]
	currently_highlighted_unit = unit_manager.selected_unit
	set_unit_highlight(unit_manager.selected_unit, true)
	unit_manager.unit_start_pos = grid_pos
	highlight_valid_moves(grid_pos)
	update_unit_highlights()
	
	return true

func set_unit_highlight(unit: Node2D, highlight: bool):
	if unit and unit.has_method("set_highlighted"):
		unit.set_highlighted(highlight)

func deselect_current_unit():
	if currently_highlighted_unit:
		set_unit_highlight(currently_highlighted_unit, false)
		currently_highlighted_unit = null
	
	unit_manager.selected_unit = null
	unit_manager.valid_move_tiles.clear()
	current_unit_index = -1
	last_clicked_pos = Vector2(-1, -1)
	update_unit_highlights()

func is_valid_movement_position(pos: Vector2, unit: Node2D) -> bool:
	return movement_handler.is_valid_movement_position(pos, unit)

func highlight_valid_moves(from_pos: Vector2):
	print("Highlighting valid moves from position: ", from_pos)
	unit_manager.valid_move_tiles.clear()
	
	if !unit_manager.selected_unit:
		return
	
	# Get possible moves from movement handler
	if movement_handler:
		unit_manager.valid_move_tiles = movement_handler.get_valid_moves(from_pos, unit_manager.selected_unit)
		
	# Add adjacent positions with enemies that can be attacked
	if !unit_manager.selected_unit.in_combat_this_turn:
		var combat_manager = grid.get_node("CombatManager")
		if combat_manager:
			# Check adjacent positions for enemies
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					
					# For garrison units, only check orthogonal positions
					if unit_manager.selected_unit.scene_file_path.contains("garrison") and abs(dx) + abs(dy) > 1:
						continue
						
					var attack_pos = from_pos + Vector2(dx, dy)
					
					# Check if position is within grid bounds
					if attack_pos.x < 0 or attack_pos.x >= grid.grid_size.x or \
					   attack_pos.y < 0 or attack_pos.y >= grid.grid_size.y:
						continue
					
					# Check if there are enemy units at this position
					if attack_pos in unit_manager.units_in_cells:
						for unit in unit_manager.units_in_cells[attack_pos]:
							if unit.is_enemy != unit_manager.selected_unit.is_enemy:
								if !attack_pos in unit_manager.valid_move_tiles:
									unit_manager.valid_move_tiles.append(attack_pos)
								break
	
	print("Valid move tiles: ", unit_manager.valid_move_tiles)

func update_unit_highlights():
	print("\n=== UPDATING UNIT HIGHLIGHTS ===")
	# Check each unit for available actions
	for pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[pos]:
			var has_available_action = false
			
			# Only check non-enemy units
			if !unit.is_enemy:
				print("Checking unit at position ", pos)
				# Check if unit can move
				if unit.can_move():
					print("- Unit can move")
					# Get valid moves for this unit
					var valid_moves = []
					if movement_handler:
						valid_moves = movement_handler.get_valid_moves(pos, unit)
					
					# If there are valid moves available, highlight the unit
					if !valid_moves.is_empty():
						has_available_action = true
						print("- Has valid moves")
				
				# Check if unit can attack
				if !unit.in_combat_this_turn:
					var combat_manager = grid.get_node("CombatManager")
					if combat_manager:
						var can_attack = combat_manager.has_adjacent_enemies(pos, unit)
						if can_attack:
							has_available_action = true
							print("- Can attack enemies")
				
				# Set label color and text based on unit state
				if unit.has_node("Label"):
					var label = unit.get_node("Label")
					var unit_name = get_unit_name(unit)
					
					if unit == unit_manager.selected_unit:
						# Selected unit gets white color and asterisk
						label.text = "* " + unit_name
						label.modulate = Color(1, 1, 1)
						print("- Unit is selected, setting white color and asterisk")
					else:
						# No asterisk for non-selected units
						label.text = unit_name
						# Orange color for units with available actions, white for others
						label.modulate = Color(1, 0.5, 0) if has_available_action else Color(1, 1, 1)
						print("- Unit has available action: ", has_available_action, ", setting color to ", "orange" if has_available_action else "white")
	
	print("=== HIGHLIGHT UPDATE COMPLETE ===\n")

func get_unit_name(unit: Node2D) -> String:
	if unit.scene_file_path.contains("infantry"):
		return "Infantry"
	elif unit.scene_file_path.contains("armoured"):
		return "Armoured"
	elif unit.scene_file_path.contains("garrison"):
		return "Garrison"
	return "Unknown"

func _process(_delta):
	pass
