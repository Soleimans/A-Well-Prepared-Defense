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
		# Set up unit placement
		unit_manager.selected_unit_type = unit_type
		unit_manager.placing_enemy = true
		
		# Attempt to place the unit
		if unit_manager.try_place_unit(position):
			print("Successfully deployed ", unit_type, " at ", position)
			return true
		else:
			print("Failed to deploy unit at ", position)
	else:
		print("Insufficient resources to deploy ", unit_type)
		print("Available: Military Points = ", resource_manager.enemy_military_points, 
			  ", Manpower = ", resource_manager.enemy_manpower)
	
	# Reset unit manager state
	unit_manager.selected_unit_type = ""
	unit_manager.placing_enemy = false
	return false

func attempt_unit_deployment():
	print("\n=== ATTEMPTING ENEMY UNIT DEPLOYMENT ===")
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

func _on_turn_button_pressed():
	print("\n=== ENEMY UNIT DEPLOYMENT START ===")
	print("Checking deployment conditions...")
	print("Resource manager found: ", resource_manager != null)
	print("Unit manager found: ", unit_manager != null)
	print("Territory manager found: ", territory_manager != null)
	print("Enemy military points: ", resource_manager.enemy_military_points if resource_manager else "N/A")
	print("Enemy manpower: ", resource_manager.enemy_manpower if resource_manager else "N/A")
	
	attempt_unit_deployment()
	
	print("=== ENEMY UNIT DEPLOYMENT END ===\n")
