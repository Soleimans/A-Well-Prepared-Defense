extends Node

var points = 1000000
var military_points = 1000000
var political_power = 0  # Starting political power
var political_power_gain = 10  # Base gain per turn
var political_power_modifiers = []  # Array to store modifiers from ministers

@onready var points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label")
@onready var military_points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label2")
@onready var political_power_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Politics_Label")

func initialize():
	update_labels()
	print("ResourceManager initialized")

func update_labels():
	if points_label:
		points_label.text = str(points)
	else:
		print("Points label not found!")
		
	if military_points_label:
		military_points_label.text = str(military_points)
	else:
		print("Military points label not found!")
		
	if political_power_label:
		political_power_label.text = str(political_power)
	else:
		print("Political power label not found!")

func calculate_political_power_gain() -> int:
	var total_gain = political_power_gain
	
	# Apply modifiers from ministers
	for modifier in political_power_modifiers:
		total_gain += modifier
	
	return total_gain

func add_political_power_modifier(value: int):
	political_power_modifiers.append(value)

func remove_political_power_modifier(value: int):
	political_power_modifiers.erase(value)

func _process(_delta):
	update_labels()
