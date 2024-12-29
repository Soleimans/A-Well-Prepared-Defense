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
	"infantry": 0.5,    # 50% chance
	"armoured": 0.2,    # 20% chance
	"garrison": 0.3     # 30% chance
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
	var directions = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	
	if unit_type == "armoured":
		# Add diagonal moves for armoured units
		directions.append_array([Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)])
		max_distance = 2
	
	for y in range(-max_distance, max_distance + 1):
		for x in range(-max_distance, max_distance + 1):
			var test_pos = from_pos + Vector2(x, y)
			
			# Check if position is within grid bounds
			if test_pos.x < 0 or test_pos.x >= grid.grid_size.x or \
			   test_pos.y < 0 or test_pos.y >= grid.grid_size.y:
				continue
			
			# Check distance
			if get_manhattan_distance(from_pos, test_pos) > max_distance:
				continue
			
			# Check if destination is full
			if test_pos in unit_manager.units_in_cells and \
			   unit_manager.units_in_cells[test_pos].size() >= unit_manager.MAX_UNITS_PER_CELL:
				continue
			
			valid_moves.append(test_pos)
	
	return valid_moves

func move_garrison_units():
	print("\nMoving garrison units...")
	var garrison_units = get_enemy_units_of_type("garrison")
	
	for unit_data in garrison_units:
		var unit = unit_data["unit"]
		var current_pos = unit_data["position"]
		
		if !unit.can_move():
			continue
			
		# Get valid moves within 1 tile
		var valid_moves = get_valid_moves(current_pos, "garrison")
		if valid_moves.is_empty():
			continue
			
		# Score each move based on position
		var scored_moves = []
		for move in valid_moves:
			var score = 0
			
			# Prefer last column
			if move.x == grid.grid_size.x - 1:
				score += 100
			
			# Prefer leftmost enemy territory
			if territory_manager.get_territory_owner(move) == "enemy":
				score += (grid.grid_size.x - move.x) * 10
			
			# Check for enemy units in range
			var has_enemies = false
			for check_pos in get_valid_moves(move, "garrison", 2):
				if check_pos in unit_manager.units_in_cells:
					for check_unit in unit_manager.units_in_cells[check_pos]:
						if !check_unit.is_enemy:
							has_enemies = true
							break
			
			# Only attack empty tiles
			if !has_enemies:
				scored_moves.append({"position": move, "score": score})
		
		# Sort moves by score
		scored_moves.sort_custom(func(a, b): return a.score > b.score)
		
		# Execute best move
		if !scored_moves.is_empty():
			var best_move = scored_moves[0].position
			if best_move != current_pos:
				unit_manager.selected_unit = unit
				unit_manager.unit_start_pos = current_pos
				unit_manager.execute_move(best_move)

func move_combat_units():
	print("\nMoving combat units...")
	var infantry_units = get_enemy_units_of_type("infantry")
	var armoured_units = get_enemy_units_of_type("armoured")
	
	# Process armoured units first, then infantry
	for unit_data in armoured_units + infantry_units:
		var unit = unit_data["unit"]
		var current_pos = unit_data["position"]
		
		if !unit.can_move():
			continue
		
		var unit_type = "armoured" if unit.scene_file_path.ends_with("armoured.tscn") else "infantry"
		var valid_moves = get_valid_moves(current_pos, unit_type)
		
		if valid_moves.is_empty():
			continue
		
		# Score moves based on proximity to player units and territory
		var scored_moves = []
		for move in valid_moves:
			var score = 0
			
			# Check for adjacent enemy units to attack
			var has_adjacent_enemies = false
			for check_pos in get_valid_moves(move, unit_type, 1):
				if check_pos in unit_manager.units_in_cells:
					for check_unit in unit_manager.units_in_cells[check_pos]:
						if !check_unit.is_enemy:
							has_adjacent_enemies = true
							score += 100  # High priority for attacking
							break
			
			# If no immediate attacks, prefer moving towards player territory
			if !has_adjacent_enemies:
				# Prefer moving left (towards player territory)
				score += (grid.grid_size.x - move.x) * 5
				
				# Extra points for moving into neutral or player territory
				var territory_owner = territory_manager.get_territory_owner(move)
				if territory_owner == "player":
					score += 50
				elif territory_owner == "neutral":
					score += 25
			
			scored_moves.append({"position": move, "score": score})
		
		# Sort moves by score
		scored_moves.sort_custom(func(a, b): return a.score > b.score)
		
		# Execute best move
		if !scored_moves.is_empty():
			var best_move = scored_moves[0].position
			if best_move != current_pos:
				unit_manager.selected_unit = unit
				unit_manager.unit_start_pos = current_pos
				
				# Check for attack opportunity
				var attack_pos = null
				for check_pos in get_valid_moves(best_move, unit_type, 1):
					if check_pos in unit_manager.units_in_cells:
						for check_unit in unit_manager.units_in_cells[check_pos]:
							if !check_unit.is_enemy and !unit.in_combat_this_turn:
								attack_pos = check_pos
								break
				
				if attack_pos:
					# Move and attack
					unit_manager.execute_move(best_move)
					var combat_manager = grid.get_node("CombatManager")
					if combat_manager:
						combat_manager.initiate_combat(best_move, attack_pos)
				else:
					# Just move
					unit_manager.execute_move(best_move)

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
