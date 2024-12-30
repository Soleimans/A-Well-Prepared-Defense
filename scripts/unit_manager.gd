extends Node

# Core grid components
@onready var grid = get_parent()
@onready var resource_manager = get_parent().get_node("ResourceManager")
@onready var building_manager = get_parent().get_node("BuildingManager")
@onready var territory_manager = get_parent().get_node("TerritoryManager")
@onready var movement_handler = $UnitMovementHandler
@onready var selection_handler = $UnitSelectionHandler

# Constants
const MAX_UNITS_PER_CELL = 3
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

# Preloaded scenes
var unit_scenes = {
	"infantry": preload("res://scenes/infantry.tscn"),
	"armoured": preload("res://scenes/armoured.tscn"),
	"garrison": preload("res://scenes/garrison.tscn")
}

# State variables
var units_in_cells = {}
var selected_unit_type: String = ""
var selected_unit = null
var valid_move_tiles: Array = []
var unit_start_pos = null
var placing_enemy: bool = false

func _ready():
	print("UnitManager: Initializing...")

func initialize(size: Vector2):
	for x in range(size.x):
		for y in range(size.y):
			units_in_cells[Vector2(x, y)] = []
	print("UnitManager: Initialized with grid size: ", size)

func has_selected_unit_type() -> bool:
	return selected_unit_type != ""

func has_selected_unit() -> bool:
	return selected_unit != null

func _on_unit_selected(type: String):
	print("UnitManager: Unit type selected: ", type)
	selected_unit_type = type
	selected_unit = null
	valid_move_tiles.clear()
	if building_manager:
		building_manager.selected_building_type = ""

func deselect_current_unit():
	selection_handler.deselect_current_unit()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			deselect_current_unit()

func try_select_unit(grid_pos: Vector2):
	selection_handler.try_select_unit(grid_pos)

func is_valid_move(grid_pos: Vector2) -> bool:
	return grid_pos in valid_move_tiles

func try_place_unit(grid_pos: Vector2) -> bool:
	print("UnitManager: Attempting to place unit at: ", grid_pos)
	
	# Check if position is within grid bounds
	if grid_pos.x < 0 or grid_pos.x >= grid.grid_size.x or grid_pos.y < 0 or grid_pos.y >= grid.grid_size.y:
		print("UnitManager: Cannot place unit - position out of bounds")
		return false
	
	# Check territory restrictions before war
	if !movement_handler.is_position_in_territory(grid_pos, placing_enemy):
		print("UnitManager: Cannot place unit - wrong territory")
		return false
		
	if units_in_cells[grid_pos].size() >= MAX_UNITS_PER_CELL:
		print("UnitManager: Cannot place unit - cell is full")
		return false
		
	# Check military points and manpower costs
	var military_cost = UNIT_COSTS[selected_unit_type]
	var manpower_cost = MANPOWER_COSTS[selected_unit_type]
	
	if placing_enemy:
		if resource_manager.enemy_military_points < military_cost:
			print("UnitManager: Cannot place unit - insufficient enemy military points")
			return false
		if resource_manager.enemy_manpower < manpower_cost:
			print("UnitManager: Cannot place unit - insufficient enemy manpower")
			return false
	else:
		if resource_manager.military_points < military_cost:
			print("UnitManager: Cannot place unit - insufficient military points")
			return false
		if resource_manager.manpower < manpower_cost:
			print("UnitManager: Cannot place unit - insufficient manpower")
			return false
	
	var new_unit = unit_scenes[selected_unit_type].instantiate()
	grid.add_child(new_unit)
	
	if placing_enemy:
		new_unit.is_enemy = true
	
	var world_pos = grid.grid_to_world(grid_pos)
	
	# Calculate the vertical offset based on existing units in the cell
	var stack_height = units_in_cells[grid_pos].size()
	var unit_offset = Vector2(0, -20 * stack_height)  # -20 pixels for each unit in stack
	
	# Apply the offset to the unit's position
	new_unit.position = world_pos + unit_offset
	
	# Add the unit to the cell
	units_in_cells[grid_pos].append(new_unit)
	
	if placing_enemy:
		resource_manager.enemy_military_points -= UNIT_COSTS[selected_unit_type]
		resource_manager.enemy_manpower -= MANPOWER_COSTS[selected_unit_type]
	else:
		resource_manager.military_points -= UNIT_COSTS[selected_unit_type]
		resource_manager.manpower -= MANPOWER_COSTS[selected_unit_type]
	
	print("UnitManager: Unit placed successfully")
	return true

func execute_move(to_pos: Vector2) -> bool:
	if movement_handler and selected_unit and unit_start_pos:
		if movement_handler.execute_move(to_pos, selected_unit, unit_start_pos):
			selected_unit = null
			valid_move_tiles.clear()
			selection_handler.current_unit_index = -1
			selection_handler.last_clicked_pos = Vector2(-1, -1)
			return true
	return false

func draw(grid_node: Node2D):
	for pos in valid_move_tiles:
		var rect = Rect2(
			pos.x * grid.tile_size.x,
			pos.y * grid.tile_size.y,
			grid.tile_size.x,
			grid.tile_size.y
		)
		grid_node.draw_rect(rect, Color(0, 1, 1, 0.3))
