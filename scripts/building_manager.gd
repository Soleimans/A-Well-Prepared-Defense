extends Node

# Building zones
var buildable_columns = [0, 1, 2]  # First 3 columns are buildable

# Building properties
var building_costs = {
	"civilian_factory": 10800,
	"military_factory": 7200,
	"fort": 500
}

# Construction times
var construction_times = {
	"civilian_factory": 6,
	"military_factory": 4,
	"fort": 1  # Base time for first 5 levels, will be 2 for levels 6-10
}

# Column unlocking properties
var max_unlockable_column = 11  # Up to column 12 (0-11)
var base_column_cost = 5000  # Starting cost
var column_cost_multiplier = 1.5  # Each new column costs 1.5x more

# Dictionary to track buildings under construction
# Format: Vector2(grid_pos) : {"type": string, "turns_left": int, "total_turns": int}
var buildings_under_construction = {}

# Dictionary to store grid occupancy and fort levels
var grid_cells = {}
var fort_levels = {}

# Currently selected building type
var selected_building_type = ""

# Preload building scenes
var civilian_factory_scene = preload("res://scenes/civilian_factory.tscn")
var military_factory_scene = preload("res://scenes/military_factory.tscn")
var fort_scene = preload("res://scenes/fort.tscn")

@onready var grid = get_parent()
@onready var resource_manager = get_parent().get_node("ResourceManager")
@onready var unit_manager = get_parent().get_node("UnitManager")

func initialize(size: Vector2):
	# Initialize grid cells and fort levels
	for x in range(size.x):
		for y in range(size.y):
			grid_cells[Vector2(x, y)] = null
			fort_levels[Vector2(x, y)] = 0
	print("BuildingManager initialized")

func has_selected_building() -> bool:
	return selected_building_type != ""

func _on_building_selected(type: String):
	selected_building_type = type
	if type == "unlock_column":
		if unlock_next_column():
			selected_building_type = ""  # Clear selection after unlocking
			var build_menu = get_node("/root/Main/UILayer/ColorRect/build_menu")
			if build_menu:
				build_menu.update_unlock_label()
	# Clear unit selection when building is selected
	if unit_manager:
		unit_manager.selected_unit_type = ""
		unit_manager.selected_unit = null
		unit_manager.valid_move_tiles.clear()
	print("Selected building type: ", type)

func get_building_cost(building_type: String, grid_pos: Vector2) -> int:
	if building_type == "fort":
		return building_costs[building_type] * (fort_levels[grid_pos] + 1)
	return building_costs[building_type]

func get_next_column_cost() -> int:
	if buildable_columns.size() >= max_unlockable_column + 1:
		return 0  # All columns unlocked
	return int(base_column_cost * pow(column_cost_multiplier, buildable_columns.size() - 3))

func can_unlock_next_column() -> bool:
	if buildable_columns.size() >= max_unlockable_column + 1:
		return false
	return resource_manager.points >= get_next_column_cost()

func unlock_next_column() -> bool:
	if !can_unlock_next_column():
		return false
		
	var cost = get_next_column_cost()
	var next_column = buildable_columns.size()
	
	resource_manager.points -= cost
	buildable_columns.append(next_column)
	return true

func is_valid_build_position(grid_pos: Vector2, building_type: String) -> bool:
	print("Checking build position for ", building_type, " at ", grid_pos)
	
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_size.x or \
	   grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
		print("Position out of bounds")
		return false
	
	# Check if there's already a building under construction
	if grid_pos in buildings_under_construction:
		print("Construction already in progress at this position")
		return false
	
	# Check building type restrictions and costs
	# Check if position is in buildable columns
	if !buildable_columns.has(int(grid_pos.x)):
		print("Position not in buildable columns")
		return false
		
	match building_type:
		"civilian_factory", "military_factory":
			if grid_cells[grid_pos] != null:
				print("Position already occupied")
				return false
		"fort":
			if fort_levels[grid_pos] >= 10:
				print("Maximum fort level reached")
				return false
	
	# Check if enough points
	var cost = get_building_cost(building_type, grid_pos)
	if resource_manager.points < cost:
		print("Not enough points! Cost: ", cost, " Available: ", resource_manager.points)
		return false
		
	print("Valid build position")
	return true

func try_place_building(grid_pos: Vector2):
	if is_valid_build_position(grid_pos, selected_building_type):
		place_building(grid_pos, selected_building_type)

func place_building(grid_pos: Vector2, building_type: String):
	var cost = get_building_cost(building_type, grid_pos)
	print("Starting construction of ", building_type, " at ", grid_pos)
	
	# Start construction
	if building_type == "fort":
		var current_level = fort_levels[grid_pos]
		var construction_time = 2 if current_level >= 5 else 1
		buildings_under_construction[grid_pos] = {
			"type": building_type,
			"turns_left": construction_time,
			"total_turns": construction_time,
			"target_level": current_level + 1
		}
	else:
		buildings_under_construction[grid_pos] = {
			"type": building_type,
			"turns_left": construction_times[building_type],
			"total_turns": construction_times[building_type]
		}
	
	resource_manager.points -= cost
	print("Construction started: ", building_type, " at ", grid_pos)
	print("Points remaining: ", resource_manager.points)

func process_construction():
	print("Processing construction progress")
	var finished_positions = []
	
	for grid_pos in buildings_under_construction:
		var construction = buildings_under_construction[grid_pos]
		construction.turns_left -= 1
		print("Construction at ", grid_pos, " has ", construction.turns_left, " turns left")
		
		if construction.turns_left <= 0:
			var building
			match construction.type:
				"civilian_factory":
					building = civilian_factory_scene.instantiate()
					print("Completed civilian factory")
				"military_factory":
					building = military_factory_scene.instantiate()
					print("Completed military factory")
				"fort":
					building = fort_scene.instantiate()
					fort_levels[grid_pos] = construction.target_level
					if building.has_method("set_level"):
						building.set_level(fort_levels[grid_pos])
					print("Completed fort level ", fort_levels[grid_pos])
			
			if building:
				if construction.type == "fort":
					if grid_cells[grid_pos]:
						# If there's an existing building, add the fort as a child
						grid_cells[grid_pos].add_child(building)
						building.position = Vector2.ZERO  # Reset the local position to zero
					else:
						# If no existing building, place fort directly in grid cell
						grid.add_child(building)
						grid_cells[grid_pos] = building
						building.position = grid.grid_to_world(grid_pos)
				else:
					# For factories, remove any existing factory (but not forts)
					if grid_cells[grid_pos] and not grid_cells[grid_pos].has_node("Fort"):
						grid_cells[grid_pos].queue_free()
					grid.add_child(building)
					grid_cells[grid_pos] = building
					building.position = grid.grid_to_world(grid_pos)
					
				finished_positions.append(grid_pos)
	
	# Remove completed constructions
	for pos in finished_positions:
		buildings_under_construction.erase(pos)
		print("Removed completed construction at ", pos)

func draw(grid_node: Node2D):
	# Draw buildable zones (blue tint)
	for x in buildable_columns:
		for y in range(grid.grid_size.y):
			var rect = Rect2(
				x * grid.tile_size.x,
				y * grid.tile_size.y,
				grid.tile_size.x,
				grid.tile_size.y
			)
			grid_node.draw_rect(rect, Color(0, 0.5, 1, 0.2))
	
	# Draw construction progress
	for grid_pos in buildings_under_construction:
		var construction = buildings_under_construction[grid_pos]
		var progress = float(construction.total_turns - construction.turns_left) / construction.total_turns
		var rect = Rect2(
			grid_pos.x * grid.tile_size.x,
			grid_pos.y * grid.tile_size.y,
			grid.tile_size.x,
			grid.tile_size.y
		)
		
		# Draw construction indicator (checkerboard pattern)
		grid_node.draw_rect(rect, Color(0.7, 0.7, 0.2, 0.3))
		
		# Draw progress bar
		var progress_rect = Rect2(
			rect.position.x,
			rect.position.y + rect.size.y - 10,
			rect.size.x * progress,
			10
		)
		grid_node.draw_rect(progress_rect, Color(1, 1, 0, 0.8))
