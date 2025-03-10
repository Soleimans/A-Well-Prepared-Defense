extends Node2D

var territory_ownership = {}

@onready var grid = get_parent()
@onready var building_manager = get_parent().get_node("BuildingManager")
@onready var unit_manager = get_parent().get_node("UnitManager")
@onready var resource_manager = get_parent().get_node("ResourceManager")
@onready var end_menu = get_node("/root/Main/UILayer/end_menu")

var war_active = false

func _ready():
	initialize_territory()
	
	var war_count = get_node("/root/Main/UILayer/WarCount")
	if war_count:
		war_count.connect("turn_changed", _on_turn_changed)
		print("TerritoryManager: Connected to WarCount")
	else:
		print("ERROR: WarCount not found!")

func initialize_territory():
	territory_ownership.clear()
	
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var pos = Vector2(x, y)
			if x < 3 or x in building_manager.buildable_columns: 
				territory_ownership[pos] = "player"
			elif x >= grid.grid_size.x - 3 or x in building_manager.enemy_buildable_columns:  
				territory_ownership[pos] = "enemy"
			else:
				territory_ownership[pos] = "neutral"
	
	print("TerritoryManager: Territory initialized with clean slate")

func _on_turn_changed(current_turn: int):
	if current_turn >= 30 and !war_active:  
		war_active = true
		if building_manager:
			building_manager.war_mode = true
		print("TerritoryManager: War has begun!")
		print("War mode active in building manager: ", building_manager.war_mode if building_manager else "BuildingManager not found")
		debug_print_territory()
		
		if grid:
			var unit_manager = grid.get_node("UnitManager")
			if unit_manager and unit_manager.selection_handler:
				unit_manager.selection_handler.update_unit_highlights()
				unit_manager.selection_handler.deselect_current_unit()
				print("Updated unit highlights and reset selection for war start")

func get_territory_owner(pos: Vector2) -> String:
	return territory_ownership.get(pos, "neutral")

func capture_territory(pos: Vector2, new_owner: String):
	print("TerritoryManager: Capturing territory at ", pos, " for ", new_owner)
	
	territory_ownership[pos] = new_owner
	
	if building_manager.grid_cells.has(pos):
		transfer_buildings(pos, new_owner)
	
	grid.queue_redraw()
	
	check_victory_conditions()

# Function to handle territory capture during unit movement
func check_territory_capture(from_pos: Vector2, to_pos: Vector2, unit: Node2D = null):
	if !unit:
		return
		
	# Determine the capturing side
	var capturing_player = "enemy" if unit.is_enemy else "player"
	
	# For armoured units, process the entire path
	if unit.scene_file_path.contains("armoured"):
		var path_points = unit_manager.movement_handler.get_line_points(from_pos, to_pos)
		
		for point in path_points:
			# Verify the position is within grid bounds
			if point.x >= 0 and point.x < grid.grid_size.x and \
			   point.y >= 0 and point.y < grid.grid_size.y:
				# Get current territory owner
				var current_owner = get_territory_owner(point)
				
				# Capture if it's not our territory
				if current_owner != capturing_player:
					capture_territory(point, capturing_player)
	else:
		# For infantry and garrison, only capture the end tile
		var current_owner = get_territory_owner(to_pos)
		if current_owner != capturing_player:
			capture_territory(to_pos, capturing_player)

func check_victory_conditions():
	var player_territory = 0
	var enemy_territory = 0
	var total_tiles = grid.grid_size.x * grid.grid_size.y
	
	# Count territories
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var check_pos = Vector2(x, y)
			var owner = get_territory_owner(check_pos)
			match owner:
				"player":
					player_territory += 1
				"enemy":
					enemy_territory += 1
	
	# Show end menu if someone has won
	if end_menu and (player_territory == total_tiles or enemy_territory == total_tiles):
		end_menu.force_show()

func transfer_buildings(pos: Vector2, new_owner: String):
	# Check for buildings at this position
	if building_manager.grid_cells.has(pos):
		var building = building_manager.grid_cells[pos]
		if building:
			pass
	
	# Handle ongoing construction at this position
	if pos in building_manager.buildings_under_construction:
		var construction = building_manager.buildings_under_construction[pos]
		construction.is_enemy = (new_owner == "enemy")

func draw(grid_node: Node2D):
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var pos = Vector2(x, y)
			var rect = Rect2(
				pos.x * grid.tile_size.x,
				pos.y * grid.tile_size.y,
				grid.tile_size.x,
				grid.tile_size.y
			)
			
			var color
			match territory_ownership[pos]:
				"player":
					color = Color(0, 0.5, 1, 1)  
				"enemy":
					color = Color(1, 0, 0, 1)    
				_: 
					color = Color(0.2, 0.2, 0.2, 1)  
			
			grid_node.draw_rect(rect, color)

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
