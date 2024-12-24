extends Node

var available_ministers = []
var active_ministers = []
@onready var resource_manager = get_node("../ResourceManager")
@onready var building_manager = get_node("../BuildingManager")

class Minister:
	var name: String
	var political_power_modifier: int
	var building_effect: Dictionary
	var cost: int
	var active: bool = false
	var label_path: String
	
	func _init(minister_name: String, pp_modifier: int, effect: Dictionary, minister_cost: int, path: String):
		name = minister_name
		political_power_modifier = pp_modifier
		building_effect = effect
		cost = minister_cost
		label_path = path

func _ready():
	# Initialize all ministers
	available_ministers = [
		Minister.new(
			"Political Advisor",
			2,  # political power modifier (+2 per turn)
			{},  # no building effects
			150,  # cost
			"Panel/GridContainer/VBoxContainer/HBoxContainer/Label"
		),
		Minister.new(
			"Industry Minister",
			0,  # no political power modifier
			{"civilian_factory": -1},  # reduces civilian factory build time by 1
			150,  # cost
			"Panel/GridContainer/VBoxContainer/HBoxContainer2/Label"
		),
		Minister.new(
			"Military Industry Minister",
			0,  # no political power modifier
			{"military_factory": -1},  # reduces military factory build time by 1
			150,  # cost
			"Panel/GridContainer/VBoxContainer/HBoxContainer3/Label"
		),
		Minister.new(
			"Fort Construction Minister",
			0,  # no political power modifier
			{"fort": "speed"},  # special effect to make all fort levels build in 1 turn
			150,  # cost
			"Panel/GridContainer/VBoxContainer/HBoxContainer4/Label"
		)
	]

func hire_minister(minister: Minister) -> bool:
	if resource_manager.political_power >= minister.cost:
		resource_manager.political_power -= minister.cost
		minister.active = true
		
		# Apply political power modifier if any
		if minister.political_power_modifier != 0:
			resource_manager.add_political_power_modifier(minister.political_power_modifier)
			
		# Apply building effects if any
		for building_type in minister.building_effect:
			if minister.building_effect[building_type] == "speed" and building_type == "fort":
				building_manager.set_fort_fast_construction(true)
			else:
				building_manager.apply_construction_modifier(building_type, minister.building_effect[building_type])
		
		active_ministers.append(minister)
		available_ministers.erase(minister)
		return true
	return false

func dismiss_minister(minister: Minister):
	minister.active = false
	
	# Remove political power modifier if any
	if minister.political_power_modifier != 0:
		resource_manager.remove_political_power_modifier(minister.political_power_modifier)
		
	# Remove building effects if any
	for building_type in minister.building_effect:
		if minister.building_effect[building_type] == "speed" and building_type == "fort":
			building_manager.set_fort_fast_construction(false)
		else:
			building_manager.remove_construction_modifier(building_type, minister.building_effect[building_type])
	
	active_ministers.erase(minister)
	available_ministers.append(minister)

func get_minister_by_label_path(path: String) -> Minister:
	# Check available ministers
	for minister in available_ministers:
		if minister.label_path == path:
			return minister
			
	# Check active ministers
	for minister in active_ministers:
		if minister.label_path == path:
			return minister
			
	return null
