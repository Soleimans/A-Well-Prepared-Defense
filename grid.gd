extends Node2D

# Core grid components
@onready var building_manager = $BuildingManager
@onready var unit_manager = $UnitManager
@onready var resource_manager = $ResourceManager

# Grid properties
var grid_size = Vector2(15, 5)  
var tile_size = Vector2(128, 128)  
var playable_area = Vector2(15, 5)
var total_grid_size = Vector2(15, 5)

func _ready():
	initialize_grid()
	setup_position()
	connect_signals()

func initialize_grid():
	building_manager.initialize(grid_size)
	unit_manager.initialize(grid_size)
	resource_manager.initialize()
	print("Grid initialized")

func setup_position():
	var viewport_size = get_viewport_rect().size
	var grid_width = grid_size.x * tile_size.x
	var grid_height = grid_size.y * tile_size.y
	
	var x_offset = (viewport_size.x - grid_width) / 2
	var y_offset = (viewport_size.y - grid_height) / 2
	
	position = Vector2(x_offset, y_offset)
	print("Grid position set to: ", position)

func connect_signals():
	var build_menu = get_node("/root/Main/UILayer/ColorRect/build_menu")
	var army_menu = get_node("/root/Main/UILayer/ColorRect/army_menu")
	
	if build_menu:
		build_menu.building_selected.connect(building_manager._on_building_selected)
		build_menu.menu_closed.connect(func(): building_manager.selected_building_type = "")
		print("Build menu connected")
	else:
		print("Build menu not found!")
		
	if army_menu:
		army_menu.unit_selected.connect(unit_manager._on_unit_selected)
		army_menu.menu_closed.connect(func(): unit_manager.selected_unit_type = "")
		print("Army menu connected")
	else:
		print("Army menu not found!")

func world_to_grid(world_pos: Vector2) -> Vector2:
	var local_pos = world_pos - position
	var x = floor(local_pos.x / tile_size.x)
	var y = floor(local_pos.y / tile_size.y)
	return Vector2(x, y)

func grid_to_world(grid_pos: Vector2) -> Vector2:
	var x = grid_pos.x * tile_size.x + tile_size.x / 2
	var y = grid_pos.y * tile_size.y + tile_size.y / 2
	return Vector2(x, y)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var grid_pos = world_to_grid(mouse_pos)
		
		print("Click at grid position: ", grid_pos) # Add this debug line
		
		if building_manager.has_selected_building():
			print("Attempting to place building")
			building_manager.try_place_building(grid_pos)
			
		elif unit_manager.has_selected_unit_type():
			print("Attempting to place unit")
			unit_manager.try_place_unit(grid_pos)
			
		elif unit_manager.has_selected_unit():
			print("Unit selected, checking for movement")
			if unit_manager.is_valid_move(grid_pos):
				unit_manager.execute_move(grid_pos)
				
		else:
			print("Attempting to select unit")
			unit_manager.try_select_unit(grid_pos)

func _process(_delta):
	queue_redraw()

func _draw():
	# Draw background area (darker green)
	var full_width = total_grid_size.x * tile_size.x
	var full_height = total_grid_size.y * tile_size.y
	var background_rect = Rect2(0, 0, full_width, full_height)
	draw_rect(background_rect, Color(0.2, 0.4, 0.2, 1.0))
	
	# Draw playable area (lighter green)
	var playable_rect = Rect2(0, 0, playable_area.x * tile_size.x, playable_area.y * tile_size.y)
	draw_rect(playable_rect, Color(0.3, 0.6, 0.3, 1.0))
	
	# Draw grid lines only for playable area
	for x in range(playable_area.x + 1):
		var from = Vector2(x * tile_size.x, 0)
		var to = Vector2(x * tile_size.x, playable_area.y * tile_size.y)
		draw_line(from, to, Color.BLACK, 2.0)
	
	for y in range(playable_area.y + 1):
		var from = Vector2(0, y * tile_size.y)
		var to = Vector2(playable_area.x * tile_size.x, y * tile_size.y)
		draw_line(from, to, Color.BLACK, 2.0)
	
	# Draw mouse hover highlight only within playable area
	var mouse_pos = get_global_mouse_position()
	var grid_pos = world_to_grid(mouse_pos)
	if grid_pos.x >= 0 and grid_pos.x < playable_area.x and grid_pos.y >= 0 and grid_pos.y < playable_area.y:
		var highlight_rect = Rect2(
			grid_pos.x * tile_size.x,
			grid_pos.y * tile_size.y,
			tile_size.x,
			tile_size.y
		)
		draw_rect(highlight_rect, Color(1, 1, 1, 0.2))
	
	# Let managers draw their content
	building_manager.draw(self)
	unit_manager.draw(self)
