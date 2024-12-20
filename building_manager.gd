extends Node

# Building zones
var factory_columns = [0, 1]
var defense_column = 2

# Building properties
var building_costs = {
	"civilian_factory": 10800,
	"military_factory": 7200,
	"fort": 500
}

var construction_times = {
	"civilian_factory": 6,
	"military_factory": 4,
	"fort": 1
}

var buildings_under_construction = {}
var grid_cells = {}
var fort_levels = {}
var selected_building_type = ""

# Preloaded scenes
var civilian_factory_scene = preload("res://civilian_factory.tscn")
var military_factory_scene = preload("res://military_factory.tscn")
var fort_scene = preload("res://fort.tscn")

@onready var grid = get_parent()
@onready var resource_manager = get_parent().get_node("ResourceManager")

func initialize(size: Vector2):
	# Initialize grid cells and fort levels
	for x in range(size.x):
		for y in range(size.y):
			grid_cells[Vector2(x, y)] = null
			fort_levels[Vector2(x, y)] = 0

func has_selected_building() -> bool:
	return selected_building_type != ""

func _on_building_selected(type: String):
	selected_building_type = type
	print("Selected building type: ", type)

func get_building_cost(building_type: String, grid_pos: Vector2) -> int:
	if building_type == "fort":
		return building_costs[building_type] * (fort_levels[grid_pos] + 1)
	return building_costs[building_type]

func is_valid_build_position(grid_pos: Vector2, building_type: String) -> bool:
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_size.x or \
	   grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
		return false
	
	# Check if there's already a building under construction
	if grid_pos in buildings_under_construction:
		print("Construction already in progress at this position")
		return false
	
	# Check building type restrictions and costs
	match building_type:
		"civilian_factory", "military_factory":
			if !factory_columns.has(int(grid_pos.x)):
				print("Invalid column for factory")
				return false
			if grid_cells[grid_pos] != null:
				print("Cell already occupied")
				return false
		"fort":
			if grid_pos.x != defense_column:
				print("Invalid column for fort")
				return false
			if fort_levels[grid_pos] >= 10:
				print("Maximum fort level reached")
				return false
	
	# Check if enough points
	var cost = get_building_cost(building_type, grid_pos)
	if resource_manager.points < cost:
		print("Not enough points! Cost: ", cost, " Available: ", resource_manager.points)
		return false
		
	return true

func try_place_building(grid_pos: Vector2):
	if is_valid_build_position(grid_pos, selected_building_type):
		place_building(grid_pos, selected_building_type)

func place_building(grid_pos: Vector2, building_type: String):
	var cost = get_building_cost(building_type, grid_pos)
	
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

func process_construction():
	var completed_positions = []
	
	for grid_pos in buildings_under_construction:
		var construction = buildings_under_construction[grid_pos]
		construction.turns_left -= 1
		
		if construction.turns_left <= 0:
			# Construction complete - create the building
			var building
			match construction.type:
				"civilian_factory":
					building = civilian_factory_scene.instantiate()
				"military_factory":
					building = military_factory_scene.instantiate()
				"fort":
					building = fort_scene.instantiate()
					fort_levels[grid_pos] = construction.target_level
					if building.has_method("set_level"):
						building.set_level(fort_levels[grid_pos])
			
			if building:
				if construction.type == "fort" and grid_cells[grid_pos]:
					grid_cells[grid_pos].queue_free()
				building.position = grid.grid_to_world(grid_pos)
				grid.add_child(building)
				grid_cells[grid_pos] = building
				completed_positions.append(grid_pos)
	
	# Remove completed constructions
	for pos in completed_positions:
		buildings_under_construction.erase(pos)

func draw(grid_node: Node2D):
	# Draw building zones
	for x in factory_columns:
		for y in range(grid.grid_size.y):
			var rect = Rect2(
				x * grid.tile_size.x,
				y * grid.tile_size.y,
				grid.tile_size.x,
				grid.tile_size.y
			)
			grid_node.draw_rect(rect, Color(0, 1, 0, 0.2))
	
	# Draw defense zone
	for y in range(grid.grid_size.y):
		var rect = Rect2(
			defense_column * grid.tile_size.x,
			y * grid.tile_size.y,
			grid.tile_size.x,
			grid.tile_size.y
		)
		grid_node.draw_rect(rect, Color(1, 0, 0, 0.2))
	
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
		
		# Draw construction indicator
		grid_node.draw_rect(rect, Color(0.7, 0.7, 0.2, 0.3))
		
		# Draw progress bar
		var progress_rect = Rect2(
			rect.position.x,
			rect.position.y + rect.size.y - 10,
			rect.size.x * progress,
			10
		)
		grid_node.draw_rect(progress_rect, Color(1, 1, 0, 0.8))
