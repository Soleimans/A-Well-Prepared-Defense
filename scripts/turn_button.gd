extends Button

@onready var label = %Label  # Path to Build label
@onready var points_label = get_node("../ColorRect/HBoxContainer/Label")
@onready var military_points_label = get_node("../ColorRect/HBoxContainer/Label2")
@onready var grid_node = get_node("/root/Main/Grid")
@onready var turn_count_label = get_node("../TurnCount")

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
	print("\n=== TURN BUTTON PRESSED ===")
	print("Processing turn effects...")
	
	if grid_node:
		var unit_manager = grid_node.get_node("UnitManager")
		var building_manager = grid_node.get_node("BuildingManager")
		var resource_manager = grid_node.get_node("ResourceManager")
		
		print("Found building manager: ", building_manager != null)
		
		# Get factory counts and generate points
		var factory_counts = get_factory_counts()
		var points_generated = factory_counts["civilian"] * points_per_civilian_factory
		var military_points_generated = factory_counts["military"] * points_per_military_factory
		
		print("Civilian factories: ", factory_counts["civilian"])
		print("Military factories: ", factory_counts["military"])
		print("Generated points: ", points_generated)
		print("Generated military points: ", military_points_generated)
		
		# Add generated points
		resource_manager.points += points_generated
		resource_manager.military_points += military_points_generated
		
		# Reset unit movements
		for pos in unit_manager.units_in_cells:
			for unit in unit_manager.units_in_cells[pos]:
				if unit.has_method("reset_movement"):
					unit.reset_movement()
					print("Reset movement for unit at position: ", pos)
		
		# Process construction progress
		building_manager.process_construction()
		print("Construction processing complete")
		
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
	print("=== TURN PROCESSING COMPLETE ===\n")

func _unhandled_input(event):
	if has_focus():  # Prevent processing if the button is focused
		return
	
	if event.is_action_pressed("ui_accept"):  # Catch the spacebar press
		_on_button_pressed()

func get_factory_counts() -> Dictionary:
	var counts = {"civilian": 0, "military": 0}
	
	if grid_node:
		var building_manager = grid_node.get_node("BuildingManager")
		var construction_positions = building_manager.buildings_under_construction.keys()
		
		for pos in building_manager.grid_cells:
			var cell = building_manager.grid_cells[pos]
			if cell and not pos in construction_positions:
				if cell.scene_file_path == "res://scenes/civilian_factory.tscn":
					counts["civilian"] += 1
					print("Found a completed civilian factory")
				elif cell.scene_file_path == "res://scenes/military_factory.tscn":
					counts["military"] += 1
					print("Found a completed military factory")
	
	return counts
