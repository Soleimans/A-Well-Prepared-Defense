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
		
		print("Click at grid position: ", grid_pos)
		
		if building_manager.has_selected_building():
			print("Attempting to place building")
			building_manager.try_place_building(grid_pos)
			
		elif unit_manager.has_selected_unit_type():
			print("Attempting to place unit")
			unit_manager.try_place_unit(grid_pos)
			
		else:
			# Check if we have a selected unit
			if unit_manager.selected_unit != null:
				# Check if there are enemy units at the clicked position
				var enemy_units = unit_manager.get_enemy_units_at(grid_pos)
				
				if enemy_units.size() > 0:
					print("Enemy units found at click position")
					# Check if the position is adjacent and unit hasn't attacked this turn
					if unit_manager.is_adjacent(unit_manager.unit_start_pos, grid_pos) and !unit_manager.selected_unit.in_combat_this_turn:
						print("Position is adjacent and unit hasn't attacked, initiating combat!")
						var combat_manager = get_node("CombatManager")
						combat_manager.initiate_combat(unit_manager.unit_start_pos, grid_pos)
						unit_manager.deselect_current_unit()
						return
					elif unit_manager.selected_unit.in_combat_this_turn:
						print("Unit has already attacked this turn")
						return
					else:
						print("Enemy found but not in adjacent tile")
				
				# If no combat was initiated and the move is valid, execute the move
				elif unit_manager.is_valid_move(grid_pos):
					print("Executing move")
					unit_manager.execute_move(grid_pos)
				else:
					print("Invalid move location")
			else:
				# No unit selected, try to select one
				print("Attempting to select/cycle units")
				unit_manager.try_select_unit(grid_pos)

func _process(_delta):
	queue_redraw()

func _draw():
	# Get reference to territory manager
	var territory_manager = get_node("TerritoryManager")
	var war_active = territory_manager.war_active if territory_manager else false

	# Only draw the base background if war is not active
	if !war_active:
		# Draw background area (darker green)
		var full_width = total_grid_size.x * tile_size.x
		var full_height = total_grid_size.y * tile_size.y
		var background_rect = Rect2(0, 0, full_width, full_height)
		draw_rect(background_rect, Color(0.2, 0.4, 0.2, 1.0))

		# Draw columns with different colors based on their state
		for x in range(playable_area.x):
			var column_rect = Rect2(
				x * tile_size.x,
				0,
				tile_size.x,
				playable_area.y * tile_size.y
			)
			
			if x in building_manager.buildable_columns:
				# Already unlocked columns
				draw_rect(column_rect, Color(0.3, 0.6, 0.3, 1.0))
			elif x == building_manager.buildable_columns.size() and building_manager.can_unlock_next_column() and x <= building_manager.max_unlockable_column:
				# Only highlight and show cost if the column can be unlocked
				draw_rect(column_rect, Color(0.4, 0.5, 0.2, 1.0))
				
				# Draw cost text if hovering over this column
				var mouse_pos = get_global_mouse_position()
				var grid_pos = world_to_grid(mouse_pos)
				if grid_pos.x == x:
					var cost = building_manager.get_next_column_cost()
					draw_string(
						ThemeDB.fallback_font,
						Vector2(x * tile_size.x + 10, tile_size.y - 10),
						"Cost: " + str(cost),
						HORIZONTAL_ALIGNMENT_LEFT,
						-1,
						16,
						Color.WHITE
					)
			else:
				# Locked columns
				draw_rect(column_rect, Color(0.2, 0.3, 0.2, 1.0))
	else:
		# During war, just draw a neutral background
		var full_width = total_grid_size.x * tile_size.x
		var full_height = total_grid_size.y * tile_size.y
		var background_rect = Rect2(0, 0, full_width, full_height)
		draw_rect(background_rect, Color(0.2, 0.2, 0.2, 1.0))  # Neutral dark gray background
		
		# Draw territory colors
		if territory_manager:
			territory_manager.draw(self)

	# Always draw grid lines
	for x in range(playable_area.x + 1):
		var from = Vector2(x * tile_size.x, 0)
		var to = Vector2(x * tile_size.x, playable_area.y * tile_size.y)
		draw_line(from, to, Color.BLACK, 2.0)
	
	for y in range(playable_area.y + 1):
		var from = Vector2(0, y * tile_size.y)
		var to = Vector2(playable_area.x * tile_size.x, y * tile_size.y)
		draw_line(from, to, Color.BLACK, 2.0)
	
	# Draw mouse hover highlight
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
	
	# Draw manager content
	building_manager.draw(self)
	unit_manager.draw(self)

	# Draw combat tiles if combat manager exists
	var combat_manager = get_node("CombatManager")
	if combat_manager:
		combat_manager.draw(self)
