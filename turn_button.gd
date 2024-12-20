extends Button

@onready var label = %Label  # Path to Build label
@onready var points_label = get_node("../ColorRect/HBoxContainer/Label")
@onready var military_points_label = get_node("../ColorRect/HBoxContainer/Label2")
@onready var grid_node = get_node("/root/Main/Grid")

var value = 1000  # Starting value
var points_per_civilian_factory = 2160
var points_per_military_factory = 1000

func _ready():
	pressed.connect(_on_button_pressed)
	label.text = "Build " + str(value)
	
	print("Turn button ready!")
	print("Points label found: ", points_label != null)
	print("Military points label found: ", military_points_label != null)
	print("Grid node found: ", grid_node != null)

func _on_button_pressed():
	print("Turn button pressed!")
	
	# Calculate and add points BEFORE processing construction
	var civilian_factory_count = count_completed_civilian_factories()
	var military_factory_count = count_completed_military_factories()
	
	print("Found completed civilian factories: ", civilian_factory_count)
	print("Found completed military factories: ", military_factory_count)
	
	if grid_node:
		var unit_manager = grid_node.get_node("UnitManager")
		var building_manager = grid_node.get_node("BuildingManager")
		var resource_manager = grid_node.get_node("ResourceManager")
		
		# Generate regular points from civilian factories
		var points_generated = civilian_factory_count * points_per_civilian_factory
		resource_manager.points += points_generated
		print("Generated points: ", points_generated)
		
		# Generate military points from military factories
		var military_points_generated = military_factory_count * points_per_military_factory
		resource_manager.military_points += military_points_generated
		print("Generated military points: ", military_points_generated)
		
		# Reset unit movements - Now using UnitManager
		for pos in unit_manager.units_in_cells:
			for unit in unit_manager.units_in_cells[pos]:
				if unit.has_method("reset_movement"):
					unit.reset_movement()
					print("Reset movement for unit at position: ", pos)
		
		# Process construction progress - Now using BuildingManager
		building_manager.process_construction()
		
		# Clear any selected unit and valid move tiles
		unit_manager.selected_unit = null
		unit_manager.valid_move_tiles.clear()
	
	# Increment build value
	value += 100
	label.text = "Build " + str(value)

func count_completed_civilian_factories() -> int:
	var count = 0
	if grid_node:
		var building_manager = grid_node.get_node("BuildingManager")
		var construction_positions = building_manager.buildings_under_construction.keys()
		
		for pos in building_manager.grid_cells:
			var cell = building_manager.grid_cells[pos]
			if cell and cell.scene_file_path == "res://civilian_factory.tscn":
				if not pos in construction_positions:
					count += 1
					print("Found a completed civilian factory")
	return count

func count_completed_military_factories() -> int:
	var count = 0
	if grid_node:
		var building_manager = grid_node.get_node("BuildingManager")
		var construction_positions = building_manager.buildings_under_construction.keys()
		
		for pos in building_manager.grid_cells:
			var cell = building_manager.grid_cells[pos]
			if cell and cell.scene_file_path == "res://military_factory.tscn":
				if not pos in construction_positions:
					count += 1
					print("Found a completed military factory")
	return count
