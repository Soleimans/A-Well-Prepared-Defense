extends Button
@onready var label = %Label  # Path to Build label
@onready var points_label = get_node("../ColorRect/HBoxContainer/Label")  # Based on your path
@onready var grid_node = get_node("/root/Main/Grid")  # The Grid node path

var value = 1000  # Starting value
var points_per_civilian_factory = 2060

func _ready():
	pressed.connect(_on_button_pressed)
	# Initialize the label with starting value
	label.text = "Build " + str(value)
	
	# Debug prints to verify connections
	print("Turn button ready!")
	print("Points label found: ", points_label != null)
	print("Grid node found: ", grid_node != null)
	if grid_node:
		print("Grid node has grid_cells: ", "grid_cells" in grid_node)

func _on_button_pressed():
	print("Turn button pressed!")
	
	# Calculate and add points BEFORE processing construction
	var civilian_factory_count = count_completed_civilian_factories()
	print("Found completed civilian factories: ", civilian_factory_count)
	
	if grid_node and "points" in grid_node:
		var points_generated = civilian_factory_count * points_per_civilian_factory
		print("Current points before: ", grid_node.points)
		grid_node.points += points_generated
		print("Generated points: ", points_generated)
		print("New total points: ", grid_node.points)
		
		# Update points display
		if points_label:
			points_label.text = str(grid_node.points)
	
	# Process construction progress AFTER points generation
	if grid_node and grid_node.has_method("process_construction"):
		grid_node.process_construction()
	
	# Increment build value
	value += 100
	label.text = "Build " + str(value)

func count_completed_civilian_factories() -> int:
	var count = 0
	if grid_node and "grid_cells" in grid_node:
		# First get all positions that are under construction
		var construction_positions = []
		if "buildings_under_construction" in grid_node:
			construction_positions = grid_node.buildings_under_construction.keys()
		
		# Only count factories that are completed (not under construction)
		for pos in grid_node.grid_cells:
			var cell = grid_node.grid_cells[pos]
			if cell and cell.scene_file_path == "res://civilian_factory.tscn":
				# Only count if the position is not under construction
				if not pos in construction_positions:
					count += 1
					print("Found a completed civilian factory")  # Debug print
	else:
		print("No grid_cells found in grid node!")  # Debug print
	return count
