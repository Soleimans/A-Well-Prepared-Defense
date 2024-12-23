extends Node

var available_ministers = []
var active_ministers = []
@onready var resource_manager = get_node("../ResourceManager")

class Minister:
	var name: String
	var political_power_modifier: int
	var cost: int
	var active: bool = false
	var label_path: String
	
	func _init(minister_name: String, pp_modifier: int, minister_cost: int, path: String):
		name = minister_name
		political_power_modifier = pp_modifier
		cost = minister_cost
		label_path = path

func _ready():
	# Add just the first minister
	available_ministers = [
		Minister.new(
			"Political Advisor",
			2,  # political power modifier (+2 per turn)
			150,  # cost
			"Panel/GridContainer/VBoxContainer/HBoxContainer/Label"
		)
	]

func hire_minister(minister: Minister) -> bool:
	if resource_manager.political_power >= minister.cost:
		resource_manager.political_power -= minister.cost
		minister.active = true
		resource_manager.add_political_power_modifier(minister.political_power_modifier)
		active_ministers.append(minister)
		available_ministers.erase(minister)
		return true
	return false

func dismiss_minister(minister: Minister):
	minister.active = false
	resource_manager.remove_political_power_modifier(minister.political_power_modifier)
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
