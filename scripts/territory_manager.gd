extends Node2D

# Dictionary to track territory ownership
# Format: Vector2(grid_pos) : String ("player" or "enemy")
var territory_ownership = {}

# References to other managers
@onready var grid = get_parent()
@onready var building_manager = get_parent().get_node("BuildingManager")
@onready var unit_manager = get_parent().get_node("UnitManager")
@onready var resource_manager = get_parent().get_node("ResourceManager")

# Flag to track if war has started
var war_active = false

func _ready():
	# Initialize territory ownership
	initialize_territory()
	
	# Connect to war count signal (not turn count)
	var war_count = get_node("/root/Main/UILayer/WarCount")
	if war_count:
		war_count.turn_changed.connect(_on_turn_changed)
		print("TerritoryManager: Connected to WarCount")
	else:
		print("ERROR: WarCount not found!")

func debug_print_territory():
	print("\nTerritory Ownership Map:")
	for x in range(grid.grid_size.x):
		var line = "Column " + str(x) + ": "
		for y in range(grid.grid_size.y):
			var pos = Vector2(x, y)
			line += territory_ownership[pos] + " "
		print(line)
	print("\nBuildable columns: ", building_manager.buildable_columns)
	print("Enemy buildable columns: ", building_manager.enemy_buildable_columns)
	print("All unlocked columns: ", building_manager.all_unlocked_columns)

func initialize_territory():
	# Set initial territory ownership
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var pos = Vector2(x, y)
			# Check if column is already unlocked by either side
			if x < 3 or x in building_manager.buildable_columns:  # Starting columns OR unlocked by player
				territory_ownership[pos] = "player"
			elif x >= grid.grid_size.x - 3 or x in building_manager.enemy_buildable_columns:  # Starting columns OR unlocked by enemy
				territory_ownership[pos] = "enemy"
			else:
				territory_ownership[pos] = "neutral"
	
	print("TerritoryManager: Territory initialized")

func _on_turn_changed(current_turn: int):
	if current_turn >= 10 and !war_active:  # War starts at turn 10
		war_active = true
		_on_war_started()
		print("TerritoryManager: War has begun!")

func _on_war_started():
	# Disable column unlocking in BuildingManager
	if building_manager:
		building_manager.war_mode = true
		print("TerritoryManager: Building Manager war mode enabled")
	
	# Reassign all territory ownership when war starts
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var pos = Vector2(x, y)
			# Starting columns and unlocked columns belong to player
			if x < 3 or x in building_manager.buildable_columns:
				territory_ownership[pos] = "player"
			# Last columns and enemy unlocked columns belong to enemy
			elif x >= grid.grid_size.x - 3 or x in building_manager.enemy_buildable_columns:
				territory_ownership[pos] = "enemy"
			# Any remaining neutral territory becomes unclaimed
			else:
				territory_ownership[pos] = "neutral"
	
	print("TerritoryManager: Territory ownership reassigned for war")
	debug_print_territory()

func get_territory_owner(pos: Vector2) -> String:
	return territory_ownership.get(pos, "neutral")

func capture_territory(pos: Vector2, new_owner: String):
	if !war_active:
		print("TerritoryManager: Cannot capture territory - war not active")
		return
		
	var old_owner = get_territory_owner(pos)
	if old_owner == new_owner:
		print("TerritoryManager: Territory already owned by ", new_owner)
		return
		
	print("TerritoryManager: Capturing territory at ", pos, " for ", new_owner)
	territory_ownership[pos] = new_owner
	
	# Handle buildings at this position
	if building_manager.grid_cells.has(pos):
		transfer_buildings(pos, new_owner)
	
	# Force a redraw of the grid
	grid.queue_redraw()

func transfer_buildings(pos: Vector2, new_owner: String):
	# Check for buildings at this position
	if building_manager.grid_cells.has(pos):
		var building = building_manager.grid_cells[pos]
		if building:
			# Change the main building's color if it has a sprite
			if building.has_node("Sprite2D"):
				building.get_node("Sprite2D").modulate = Color.RED if new_owner == "enemy" else Color.WHITE
			
			# If there are multiple buildings (like a fort under a factory), change those too
			for child in building.get_children():
				if child.has_node("Sprite2D"):
					child.get_node("Sprite2D").modulate = Color.RED if new_owner == "enemy" else Color.WHITE
			
			print("TerritoryManager: Transferred building at ", pos, " to ", new_owner)
	
	# Handle any ongoing construction at this position
	if pos in building_manager.buildings_under_construction:
		var construction = building_manager.buildings_under_construction[pos]
		# Update the construction ownership
		construction.is_enemy = (new_owner == "enemy")
		print("TerritoryManager: Updated construction ownership at ", pos)

# This will be called from Grid's _draw function
func draw(grid_node: Node2D):
	if !war_active:
		return
		
	for pos in territory_ownership:
		var owner = territory_ownership[pos]
		if owner != "neutral":
			var rect = Rect2(
				pos.x * grid.tile_size.x,
				pos.y * grid.tile_size.y,
				grid.tile_size.x,
				grid.tile_size.y
			)
			# Use opaque colors for territory
			var color = Color(0.3, 0.6, 0.8, 1.0) if owner == "player" else Color(0.8, 0.3, 0.3, 1.0)
			grid_node.draw_rect(rect, color)

# Debug function to print current territory state
func print_territory_state():
	print("\nTerritory State:")
	print("War Active: ", war_active)
	for pos in territory_ownership:
		print("Position ", pos, ": ", territory_ownership[pos])
