extends Node2D

# Dictionary to track territory ownership
# Format: Vector2(grid_pos) : String ("player" or "enemy")
var territory_ownership = {}

# References to other managers
@onready var grid = get_parent()
@onready var building_manager = get_parent().get_node("BuildingManager")
@onready var unit_manager = get_parent().get_node("UnitManager")
@onready var resource_manager = get_parent().get_node("ResourceManager")

# Flag to track if war has started
var war_active = false

func _ready():
	# Initialize territory ownership
	initialize_territory()
	
	# Connect to war count signal (not turn count)
	var war_count = get_node("/root/Main/UILayer/WarCount")
	if war_count:
		war_count.turn_changed.connect(_on_turn_changed)
		print("TerritoryManager: Connected to WarCount")
	else:
		print("ERROR: WarCount not found!")

func initialize_territory():
	# Set initial territory ownership
	for x in range(grid.grid_size.x):
		for y in range(grid.grid_size.y):
			var pos = Vector2(x, y)
			if x < 3:  # First 3 columns are player territory
				territory_ownership[pos] = "player"
			elif x >= grid.grid_size.x - 3:  # Last 3 columns are enemy territory
				territory_ownership[pos] = "enemy"
			else:
				territory_ownership[pos] = "neutral"
	
	print("TerritoryManager: Territory initialized")

func _on_turn_changed(current_turn: int):
	if current_turn >= 10 and !war_active:  # War starts at turn 10
		war_active = true
		_on_war_started()
		print("TerritoryManager: War has begun!")

func _on_war_started():
	# Disable column unlocking in BuildingManager
	# We'll need to add this functionality to BuildingManager later
	building_manager.war_mode = true

func get_territory_owner(pos: Vector2) -> String:
	return territory_ownership.get(pos, "neutral")

func capture_territory(pos: Vector2, new_owner: String):
	if !war_active:
		return
		
	var old_owner = get_territory_owner(pos)
	if old_owner == new_owner:
		return
		
	print("TerritoryManager: Capturing territory at ", pos, " for ", new_owner)
	territory_ownership[pos] = new_owner
	
	# Handle buildings at this position
	if building_manager.grid_cells.has(pos):
		transfer_buildings(pos, new_owner)

func transfer_buildings(pos: Vector2, new_owner: String):
	var building = building_manager.grid_cells[pos]
	if building:
		if building.has_node("Sprite2D"):
			var sprite = building.get_node("Sprite2D")
			sprite.modulate = Color.WHITE if new_owner == "player" else Color.RED
		print("TerritoryManager: Transferred building at ", pos, " to ", new_owner)
	
	# Cancel any ongoing construction
	if pos in building_manager.buildings_under_construction:
		building_manager.buildings_under_construction.erase(pos)
		print("TerritoryManager: Cancelled construction at ", pos)

# This will be called from Grid's _draw function
func draw(grid_node: Node2D):
	if !war_active:
		return
		
	for pos in territory_ownership:
		var owner = territory_ownership[pos]
		if owner != "neutral":
			var rect = Rect2(
				pos.x * grid.tile_size.x,
				pos.y * grid.tile_size.y,
				grid.tile_size.x,
				grid.tile_size.y
			)
			var color = Color(0, 0.5, 1, 0.2) if owner == "player" else Color(1, 0, 0, 0.2)
			grid_node.draw_rect(rect, color)
