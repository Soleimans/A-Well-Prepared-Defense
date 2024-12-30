extends Node2D

# Node references
var grid: Node2D
var unit_manager: Node
var resource_manager: Node
var territory_manager: Node
var turn_button: Node

# Unit deployment costs and probabilities
const UNIT_TYPES = ["infantry", "armoured", "garrison"]
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
const UNIT_WEIGHTS = {
	"infantry": 0.6,    # 60% chance
	"armoured": 0.3,    # 30% chance
	"garrison": 0.1     # 10% chance
}

func _ready():
	# Initialize node references
	grid = get_parent()
	if grid:
		unit_manager = grid.get_node("UnitManager")
		resource_manager = grid.get_node("ResourceManager")
		territory_manager = grid.get_node("TerritoryManager")
	
	# Get and connect to turn button
	turn_button = get_node_or_null("/root/Main/UILayer/TurnButton")
	if turn_button:
		if !turn_button.is_connected("pressed", _on_turn_button_pressed):
			turn_button.pressed.connect(_on_turn_button_pressed)
		print("CombatantManager: Successfully connected to turn button")
	else:
		push_error("CombatantManager: Failed to find turn button!")
	
	# Verify all required nodes are found
	print("CombatantManager initialization:")
	print("- Grid found: ", grid != null)
	print("- UnitManager found: ", unit_manager != null)
	print("- ResourceManager found: ", resource_manager != null)
	print("- TerritoryManager found: ", territory_manager != null)
	print("- TurnButton found: ", turn_button != null)

func get_available_deployment_positions() -> Array:
	var available_positions = []
	var last_column = grid.grid_size.x - 1
	
	print("Checking deployment positions in column ", last_column)
	
	# Check each position in the last column
	for y in range(grid.grid_size.y):
		var pos = Vector2(last_column, y)
		
		# Check if position is in enemy territory
		var territory_owner = territory_manager.get_territory_owner(pos)
		print("Position ", pos, " territory owner: ", territory_owner)
		
		if territory_owner == "enemy":
			# Check if position has less than 3 units
			var current_units = unit_manager.units_in_cells.get(pos, [])
			var unit_count = current_units.size() if current_units != null else 0
			print("Position ", pos, " has ", unit_count, " units")
			
			if unit_count < 3:
				available_positions.append(pos)
				print("Position ", pos, " is available for deployment")
	
	print("Total available positions: ", available_positions.size())
	return available_positions

func select_random_unit_type() -> String:
	var total_weight = 0
	for weight in UNIT_WEIGHTS.values():
		total_weight += weight
	
	var random_value = randf() * total_weight
	var current_sum = 0
	
	for unit_type in UNIT_WEIGHTS:
		current_sum += UNIT_WEIGHTS[unit_type]
		if random_value <= current_sum:
			return unit_type
	
	return "infantry"  # Default fallback

func try_deploy_unit(position: Vector2, unit_type: String) -> bool:
	print("\nAttempting to deploy ", unit_type, " at position ", position)
	print("Costs - Military: ", UNIT_COSTS[unit_type], ", Manpower: ", MANPOWER_COSTS[unit_type])
	
	# Check costs
	var military_cost = UNIT_COSTS[unit_type]
	var manpower_cost = MANPOWER_COSTS[unit_type]
	
	if resource_manager.enemy_military_points >= military_cost and \
	   resource_manager.enemy_manpower >= manpower_cost:
		
		# Get current units at position
		var current_units = unit_manager.units_in_cells.get(position, [])
		if current_units.size() >= unit_manager.MAX_UNITS_PER_CELL:
			print("Position already has maximum units")
			return false
		
		# Set up unit placement
		unit_manager.selected_unit_type = unit_type
		unit_manager.placing_enemy = true
		
		# Attempt to place the unit
		var success = unit_manager.try_place_unit(position)
		
		# Always reset the flags
		unit_manager.selected_unit_type = ""
		unit_manager.placing_enemy = false
		
		if success:
			# After successful placement, adjust positions of all units in stack
			var units = unit_manager.units_in_cells[position]
			for i in range(units.size()):
				var world_pos = grid.grid_to_world(position)
				var offset = Vector2(0, -20 * i)  # -20 pixels offset for each unit in stack
				units[i].position = world_pos + offset
			
			print("Successfully deployed ", unit_type, " at ", position)
			return true
		else:
			print("Failed to deploy unit at ", position)
			return false
	else:
		print("Insufficient resources to deploy ", unit_type)
		print("Available: Military Points = ", resource_manager.enemy_military_points, 
			  ", Manpower = ", resource_manager.enemy_manpower)
		
		unit_manager.selected_unit_type = ""
		unit_manager.placing_enemy = false
		return false

func attempt_unit_deployment():
	print("\n=== ATTEMPTING ENEMY UNIT DEPLOYMENT ===")
	
	# Always reset placing_enemy at the start
	unit_manager.placing_enemy = false
	unit_manager.selected_unit_type = ""
	
	var available_positions = get_available_deployment_positions()
	
	if available_positions.is_empty():
		print("No available positions for unit deployment")
		return
	
	# Try to deploy up to 2 units per turn
	var deployments = 0
	const MAX_DEPLOYMENTS = 2
	
	while deployments < MAX_DEPLOYMENTS and !available_positions.is_empty():
		# Select random position and unit type
		var random_index = randi() % available_positions.size()
		var deploy_pos = available_positions[random_index]
		var unit_type = select_random_unit_type()
		
		print("Attempting to deploy ", unit_type, " at position ", deploy_pos)
		
		if try_deploy_unit(deploy_pos, unit_type):
			deployments += 1
			
			# Remove position if it's now full
			var current_units = unit_manager.units_in_cells.get(deploy_pos, [])
			if current_units.size() >= 3:
				available_positions.remove_at(random_index)
		else:
			# If deployment failed, remove this position and try another
			available_positions.remove_at(random_index)
	
	print("Deployed ", deployments, " units this turn")
	print("=== ENEMY UNIT DEPLOYMENT COMPLETE ===\n")
	
	# Always ensure placing_enemy is reset at the end
	unit_manager.placing_enemy = false
	unit_manager.selected_unit_type = ""

func get_manhattan_distance(from: Vector2, to: Vector2) -> int:
	return int(abs(from.x - to.x) + abs(from.y - to.y))

func get_enemy_units_of_type(type: String) -> Array:
	var units = []
	for pos in unit_manager.units_in_cells:
		for unit in unit_manager.units_in_cells[pos]:
			if unit.is_enemy and unit.scene_file_path.ends_with(type + ".tscn"):
				units.append({"unit": unit, "position": pos})
	return units

func get_valid_moves(from_pos: Vector2, unit_type: String, max_distance: int = 1) -> Array:
	var valid_moves = []
	
	# Different movement patterns for each unit type
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
				if is_valid_position(test_pos):
					valid_moves.append(test_pos)
					
		"infantry":
			# Infantry can move in any direction within 1 tile radius
			for x in range(-1, 2):
				for y in range(-1, 2):
					if x == 0 and y == 0:
						continue
					var test_pos = from_pos + Vector2(x, y)
					if is_valid_position(test_pos):
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
				# Can move 1 or 2 spaces in each direction
				for distance in range(1, 3):
					var test_pos = from_pos + (dir * distance)
					if is_valid_position(test_pos):
						valid_moves.append(test_pos)
	
	return valid_moves

func is_valid_position(pos: Vector2) -> bool:
	# Check if position is within grid bounds
	if pos.x < 0 or pos.x >= grid.grid_size.x or pos.y < 0 or pos.y >= grid.grid_size.y:
		return false
		
	# Make sure we have a valid selected unit
	if !unit_manager or !unit_manager.selected_unit:
		return false
		
	# Check if position has space for movement
	if pos in unit_manager.units_in_cells:
		# Allow moving to position with enemy units for combat
		var has_only_enemy_units = true
		for unit in unit_manager.units_in_cells[pos]:
			if unit and unit.has_method("get") and unit_manager.selected_unit.has_method("get"):
				if unit.is_enemy == unit_manager.selected_unit.is_enemy:
					if unit_manager.units_in_cells[pos].size() >= unit_manager.MAX_UNITS_PER_CELL:
						return false
					has_only_enemy_units = false
		
		if has_only_enemy_units:
			return true
			
	return true

func move_garrison_units():
	print("\nMoving garrison units...")
	var garrison_units = get_enemy_units_of_type("garrison")
	
	for unit_data in garrison_units:
		var unit = unit_data["unit"]
		var current_pos = unit_data["position"]
		
		if !unit.can_move():
			continue
		
		print("Checking garrison at ", current_pos)
		
		# Get possible orthogonal moves
		var possible_moves = []
		var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		
		for dir in directions:
			var test_pos = current_pos + dir
			if test_pos.x >= 0 and test_pos.x < grid.grid_size.x and \
			   test_pos.y >= 0 and test_pos.y < grid.grid_size.y:
				possible_moves.append(test_pos)
		
		# Score each possible move
		var scored_moves = []
		for move in possible_moves:
			var score = 0
			
			# During war, garrisons should move towards player territory
			score += (grid.grid_size.x - move.x) * 50
			
			# Extra score for moving out of the starting column
			if current_pos.x == grid.grid_size.x - 1:
				score += 500
			
			# Only consider moves to empty spaces or spaces with room
			if !unit_manager.units_in_cells.has(move) or \
			   unit_manager.units_in_cells[move].size() < unit_manager.MAX_UNITS_PER_CELL:
				scored_moves.append({"position": move, "score": score})
		
		# Execute the highest-scored move
		if !scored_moves.is_empty():
			scored_moves.sort_custom(func(a, b): return a.score > b.score)
			var best_move = scored_moves[0].position
			
			if best_move != current_pos:
				print("Moving garrison from ", current_pos, " to ", best_move)
				unit_manager.selected_unit = unit
				unit_manager.unit_start_pos = current_pos
				unit_manager.movement_handler.execute_move(best_move, unit, current_pos)

func move_combat_units():
	print("\nMoving combat units...")
	var infantry_units = get_enemy_units_of_type("infantry")
	var armoured_units = get_enemy_units_of_type("armoured")
	
	# First pass: Check for immediate attack opportunities
	for unit_data in armoured_units + infantry_units:
		var unit = unit_data["unit"]
		var current_pos = unit_data["position"]
		
		if !unit.can_move() or unit.in_combat_this_turn:
			continue
			
		print("Checking unit at ", current_pos)
		
		var unit_type = "armoured" if unit.scene_file_path.ends_with("armoured.tscn") else "infantry"
		var movement_range = 2 if unit_type == "armoured" else 1
		
		# Get all possible positions within range
		var possible_moves = []
		for x in range(-movement_range, movement_range + 1):
			for y in range(-movement_range, movement_range + 1):
				if x == 0 and y == 0:
					continue
					
				var test_pos = current_pos + Vector2(x, y)
				
				# Check if position is within grid bounds
				if test_pos.x >= 0 and test_pos.x < grid.grid_size.x and \
				   test_pos.y >= 0 and test_pos.y < grid.grid_size.y:
					# For non-armoured units, only allow orthogonal and diagonal moves
					if unit_type != "armoured" and abs(x) + abs(y) > 1:
						continue
					
					# For armoured units, ensure movement is in straight lines
					if unit_type == "armoured" and x != 0 and y != 0 and abs(x) != abs(y):
						continue
						
					possible_moves.append(test_pos)
		
		# Score each possible move
		var scored_moves = []
		for move in possible_moves:
			var score = 0
			
			# Check for player units to attack
			var has_attackable_unit = false
			if move in unit_manager.units_in_cells:
				for target_unit in unit_manager.units_in_cells[move]:
					if !target_unit.is_enemy:
						has_attackable_unit = true
						score += 1000  # High priority for attack moves
						
						# Bonus for attacking damaged units
						var health_ratio = (target_unit.soft_health + target_unit.hard_health) / \
										 float(target_unit.max_soft_health + target_unit.max_hard_health)
						if health_ratio < 0.5:
							score += 500
						break
			
			# If no immediate attack, score based on position
			if !has_attackable_unit:
				# Prioritize moving towards player territory
				score += (grid.grid_size.x - move.x) * 100
				
				# Check if the move gets us closer to any player unit
				var min_distance_to_player = 999
				for check_pos in unit_manager.units_in_cells:
					for check_unit in unit_manager.units_in_cells[check_pos]:
						if !check_unit.is_enemy:
							var distance = abs(move.x - check_pos.x) + abs(move.y - check_pos.y)
							min_distance_to_player = min(min_distance_to_player, distance)
				
				# Higher score for positions closer to player units
				if min_distance_to_player != 999:
					score += (20 - min_distance_to_player) * 50
				
				# Extra points for moving into player territory
				var territory_owner = territory_manager.get_territory_owner(move)
				if territory_owner == "player":
					score += 300
			
			# Check if we can actually move there
			if !unit_manager.units_in_cells.has(move) or \
			   unit_manager.units_in_cells[move].size() < unit_manager.MAX_UNITS_PER_CELL or \
			   has_attackable_unit:
				scored_moves.append({"position": move, "score": score})
		
		# Execute the highest-scored move
		if !scored_moves.is_empty():
			scored_moves.sort_custom(func(a, b): return a.score > b.score)
			var best_move = scored_moves[0].position
			
			if best_move != current_pos:
				print("Moving unit from ", current_pos, " to ", best_move)
				unit_manager.selected_unit = unit
				unit_manager.unit_start_pos = current_pos
				
				# If this is an attack move, initiate combat
				if best_move in unit_manager.units_in_cells and \
				   unit_manager.units_in_cells[best_move].any(func(u): return !u.is_enemy):
					var combat_manager = grid.get_node("CombatManager")
					if combat_manager:
						combat_manager.initiate_combat(current_pos, best_move)
				else:
					# Regular movement
					unit_manager.movement_handler.execute_move(best_move, unit, current_pos)

# New function to evaluate attack positions
func evaluate_attack_position(pos: Vector2, attacker) -> int:
	var score = 0
	
	# Check enemy units at position
	for target_unit in unit_manager.units_in_cells[pos]:
		if !target_unit.is_enemy:
			# Base score on potential damage based on unit types
			if target_unit.scene_file_path.ends_with("armoured.tscn"):
				score += attacker.hard_attack * 2  # Double score for attacking armored with appropriate units
			else:
				score += attacker.soft_attack  # Regular score for soft targets
			
			# Add bonus for low health targets
			var health_percentage = (target_unit.soft_health + target_unit.hard_health) / (target_unit.max_soft_health + target_unit.max_hard_health)
			if health_percentage < 0.5:
				score += 100  # Significant bonus for attacking damaged units
				
			# Add bonus for low equipment
			var equipment_percentage = target_unit.equipment / target_unit.max_equipment
			if equipment_percentage < 0.5:
				score += 100  # Significant bonus for attacking under-equipped units
			
			# Add bonus for strategic positions
			var territory_owner = territory_manager.get_territory_owner(pos)
			if territory_owner == "player":
				score += 50  # Bonus for attacking units in player territory
	
	return score

func process_enemy_movements():
	print("\n=== PROCESSING ENEMY UNIT MOVEMENTS ===")
	
	# Move garrison units first
	move_garrison_units()
	
	# Then move combat units
	move_combat_units()
	
	print("=== ENEMY UNIT MOVEMENTS COMPLETE ===\n")

func _on_turn_button_pressed():
	print("\n=== ENEMY UNIT DEPLOYMENT START ===")
	print("Checking deployment conditions...")
	print("Resource manager found: ", resource_manager != null)
	print("Unit manager found: ", unit_manager != null)
	print("Territory manager found: ", territory_manager != null)
	print("Enemy military points: ", resource_manager.enemy_military_points if resource_manager else "N/A")
	print("Enemy manpower: ", resource_manager.enemy_manpower if resource_manager else "N/A")
	
	attempt_unit_deployment()
	
	# Process enemy unit movements after deployment
	if territory_manager and territory_manager.war_active:
		process_enemy_movements()
