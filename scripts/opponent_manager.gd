extends Node2D

# Node references
@onready var grid = get_parent()
@onready var building_manager = get_parent().get_node("BuildingManager")
@onready var resource_manager = get_parent().get_node("ResourceManager")
@onready var territory_manager = get_parent().get_node("TerritoryManager")

# Building priorities and costs
const BUILDING_COSTS = {
	"civilian_factory": 10800,
	"military_factory": 7200,
	"fort": 500
}

# Track number of enemy buildings
var enemy_civilian_factory_count = 0
var enemy_military_factory_count = 0

func _ready():
	# Connect to the turn button's pressed signal
	var turn_button = get_node("/root/Main/UILayer/TurnButton")
	if turn_button:
		turn_button.pressed.connect(_on_turn_button_pressed)
		print("OpponentManager connected to turn button")
	else:
		print("ERROR: Turn button not found!")
	
	# Count initial enemy buildings
	count_enemy_buildings()


func get_available_build_slots() -> int:
	var available_slots = 0
	var buildable_positions = get_buildable_positions()
	
	for pos in buildable_positions:
		# Check if position already has a factory
		if building_manager.grid_cells.has(pos):
			var cell = building_manager.grid_cells[pos]
			if cell == null or cell.scene_file_path.ends_with("fort.tscn"):
				available_slots += 1
		else:
			available_slots += 1
	
	return available_slots

func should_unlock_column() -> bool:
	# Check if we have less than 2 available build slots
	var available_slots = get_available_build_slots()
	print("\nChecking if should unlock column:")
	print("Available build slots: ", available_slots)
	
	# Get the next possible column to unlock
	var next_column = building_manager.enemy_buildable_columns[0] - 1
	
	# Check if we can unlock more columns
	if next_column < 3:
		print("Cannot unlock more columns - at minimum limit")
		return false
		
	# Check if the column is already claimed
	if next_column in building_manager.buildable_columns or next_column in building_manager.all_unlocked_columns:
		print("Next column already claimed")
		return false
	
	# If we're in war mode, don't unlock new columns
	if territory_manager and territory_manager.war_active:
		print("War is active - no column unlocking")
		return false
	
	# Unlock if we have less than 2 available slots
	var should_unlock = available_slots < 2
	print("Should unlock new column: ", should_unlock)
	return should_unlock

func count_enemy_buildings():
	enemy_civilian_factory_count = 0
	enemy_military_factory_count = 0
	
	for pos in building_manager.grid_cells:
		var cell = building_manager.grid_cells[pos]
		if cell:
			var is_enemy = cell.has_node("Sprite2D") and cell.get_node("Sprite2D").self_modulate == Color.RED
			if is_enemy:
				if cell.scene_file_path == "res://scenes/civilian_factory.tscn":
					enemy_civilian_factory_count += 1
				elif cell.scene_file_path == "res://scenes/military_factory.tscn":
					enemy_military_factory_count += 1

func _on_turn_button_pressed():
	print("\n=== ENEMY AI TURN START ===")
	print("Enemy Resources:")
	print("- Points: ", resource_manager.enemy_points)
	print("- Military Points: ", resource_manager.enemy_military_points)
	
	# Update building counts
	count_enemy_buildings()
	print("Current enemy buildings:")
	print("- Civilian Factories: ", enemy_civilian_factory_count)
	print("- Military Factories: ", enemy_military_factory_count)
	
	attempt_building()

func get_buildable_positions() -> Array:
	var positions = []
	var grid_size = grid.grid_size
	
	# Get all columns where enemy can build
	var buildable_columns = []
	if territory_manager and territory_manager.war_active:
		print("War is active - checking all enemy territory")
		# During war, can build in any captured territory
		for x in range(grid_size.x):
			for y in range(grid_size.y):
				var pos = Vector2(x, y)
				if territory_manager.get_territory_owner(pos) == "enemy":
					if not x in buildable_columns:
						buildable_columns.append(x)
	else:
		print("Peace time - using enemy buildable columns")
		buildable_columns = building_manager.enemy_buildable_columns.duplicate()
	
	# Sort columns from right to left
	buildable_columns.sort_custom(func(a, b): return a > b)
	
	# Check each column
	for x in buildable_columns:
		for y in range(grid_size.y):
			var pos = Vector2(x, y)
			if is_valid_build_position(pos):
				positions.append(pos)
	
	return positions

func get_fort_buildable_positions() -> Array:
	var positions = []
	var upgrade_positions = []  # Separate array for positions that need upgrading past level 5
	var grid_size = grid.grid_size
	
	# Get all columns where enemy can build
	var buildable_columns = []
	if territory_manager and territory_manager.war_active:
		for x in range(grid_size.x):
			for y in range(grid_size.y):
				var pos = Vector2(x, y)
				if territory_manager.get_territory_owner(pos) == "enemy":
					if not x in buildable_columns:
						buildable_columns.append(x)
	else:
		buildable_columns = building_manager.enemy_buildable_columns.duplicate()
	
	# First and last columns are priority for forts
	var priority_columns = [buildable_columns.front(), buildable_columns.back()]
	
	# First check priority columns for positions needing level 5 or less
	var all_level_5_complete = true
	for x in priority_columns:
		for y in range(grid_size.y):
			var pos = Vector2(x, y)
			if can_build_fort(pos):
				var current_level = building_manager.fort_levels.get(pos, 0)
				if current_level < 5:
					positions.append(pos)
					all_level_5_complete = false
				elif current_level >= 5 and current_level < 10:
					upgrade_positions.append(pos)
	
	# If all priority positions have level 5 forts, add upgrade positions
	if all_level_5_complete and not positions.is_empty():
		positions.append_array(upgrade_positions)
	
	# Then check other columns if we're in war
	if territory_manager and territory_manager.war_active:
		for x in buildable_columns:
			if x in priority_columns:
				continue
			for y in range(grid_size.y):
				var pos = Vector2(x, y)
				if can_build_fort(pos):
					positions.append(pos)
	
	return positions

func is_valid_build_position(pos: Vector2) -> bool:
	# Check if position has a building
	if building_manager.grid_cells.has(pos):
		var existing_building = building_manager.grid_cells[pos]
		if existing_building:
			# Don't build if there's any building
			return false
	
	# Check if there's already construction in progress
	if pos in building_manager.buildings_under_construction:
		return false
	
	# Make sure it's enemy territory
	if territory_manager.get_territory_owner(pos) != "enemy":
		return false
	
	return true

func can_build_fort(pos: Vector2) -> bool:
	# Check if position has a completed factory (not under construction)
	if building_manager.grid_cells.has(pos):
		var existing_building = building_manager.grid_cells[pos]
		if existing_building and (existing_building.scene_file_path.ends_with("civilian_factory.tscn") or 
								existing_building.scene_file_path.ends_with("military_factory.tscn")):
			# Check fort level
			var current_fort_level = building_manager.fort_levels.get(pos, 0)
			if current_fort_level < 10:
				# Make sure no fort is already under construction here
				if pos in building_manager.buildings_under_construction:
					var construction = building_manager.buildings_under_construction[pos]
					if construction.type == "fort":
						return false
				# Also check if there's no factory under construction here
				if pos in building_manager.buildings_under_construction:
					var construction = building_manager.buildings_under_construction[pos]
					if construction.type in ["civilian_factory", "military_factory"]:
						return false
				return true
	return false

func attempt_build_at_position(position: Vector2, building_type: String) -> bool:
	var cost = BUILDING_COSTS[building_type]
	
	# Special case for fort - calculate actual cost based on existing level
	if building_type == "fort":
		var current_level = building_manager.fort_levels.get(position, 0)
		if current_level >= 10:
			return false
		cost = cost * (current_level + 1)
	
	if resource_manager.enemy_points >= cost:
		building_manager.selected_building_type = building_type
		building_manager.placing_enemy = true
		
		if building_manager.is_valid_build_position(position, building_type):
			building_manager.place_building(position, building_type)
			print("Successfully placed ", building_type, " at ", position)
			
			# Update counts for factories
			if building_type == "civilian_factory":
				enemy_civilian_factory_count += 1
			elif building_type == "military_factory":
				enemy_military_factory_count += 1
			
			building_manager.selected_building_type = ""
			building_manager.placing_enemy = false
			return true
	
	building_manager.selected_building_type = ""
	building_manager.placing_enemy = false
	return false

func attempt_building():
	print("\n=== ATTEMPTING ENEMY BUILDING ===")
	var actions_taken = 0
	const ACTIONS_PER_TURN = 2
	
	# Check if we should unlock a new column first
	if should_unlock_column():
		print("Unlocking new column for enemy")
		building_manager.unlock_next_enemy_column()
		actions_taken += 1
		
		# Refresh buildable positions after unlocking
		var buildable_positions = get_buildable_positions()
		if !buildable_positions.is_empty():
			# Try to use the remaining action to build
			if enemy_civilian_factory_count < 5:
				if attempt_build_at_position(buildable_positions[0], "civilian_factory"):
					actions_taken += 1
	
	# If we didn't unlock a column or have actions remaining, proceed with normal building
	if actions_taken < ACTIONS_PER_TURN:
		# First phase: Build 5 civilian factories
		if enemy_civilian_factory_count < 5:
			print("Building initial civilian factories (", enemy_civilian_factory_count, "/5)")
			var buildable_positions = get_buildable_positions()
			
			# Try to build civilian factories with remaining actions
			while actions_taken < ACTIONS_PER_TURN and !buildable_positions.is_empty():
				if attempt_build_at_position(buildable_positions[0], "civilian_factory"):
					actions_taken += 1
				buildable_positions.remove_at(0)
		else:
			# After 5 civilian factories, handle military factories and forts
			var buildable_positions = get_buildable_positions()
			var fort_positions = get_fort_buildable_positions()
			
			# Determine if we need military factories
			var need_military = enemy_military_factory_count < 5
			
			while actions_taken < ACTIONS_PER_TURN:
				if need_military and !buildable_positions.is_empty():
					if attempt_build_at_position(buildable_positions[0], "military_factory"):
						actions_taken += 1
					buildable_positions.remove_at(0)
				elif !fort_positions.is_empty():
					if attempt_build_at_position(fort_positions[0], "fort"):
						actions_taken += 1
					fort_positions.remove_at(0)
				else:
					break
	
	print("Actions taken this turn: ", actions_taken)
	print("=== ENEMY BUILDING ATTEMPT COMPLETE ===\n")
