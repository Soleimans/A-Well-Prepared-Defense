extends Node

# Player resources
var points = 100000
var military_points = 100000
var political_power = 100
var manpower = 1000000  # Add player manpower
var political_power_gain = 10
var political_power_modifiers = []

# Enemy resources
var enemy_points = 0
var enemy_military_points = 0
var enemy_political_power = 100
var enemy_manpower = 1000000  # Base manpower that doesn't change with factories
var enemy_political_power_gain = 10
var enemy_political_power_modifiers = []

# Node references
@onready var points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label")
@onready var military_points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label2")
@onready var political_power_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Politics_Label")
@onready var manpower_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Manpower_Count")

# Enemy resource labels
@onready var enemy_points_label = get_node("/root/Main/UILayer/Debug/Panel/GridContainer/VBoxContainer/EnemyIndustrialPoints")
@onready var enemy_military_points_label = get_node("/root/Main/UILayer/Debug/Panel/GridContainer/VBoxContainer/EnemyMilitaryPoints")
@onready var enemy_political_points_label = get_node("/root/Main/UILayer/Debug/Panel/GridContainer/VBoxContainer/EnemyPoliticalPoints")
@onready var enemy_manpower_points_label = get_node("/root/Main/UILayer/Debug/Panel/GridContainer/VBoxContainer/EnemyManpowerPoints")

func initialize():
	update_labels()
	print("ResourceManager initialized")

func update_labels():
	# Update player labels
	if points_label:
		points_label.text = str(points)
	if military_points_label:
		military_points_label.text = str(military_points)
	if political_power_label:
		political_power_label.text = str(political_power)
	if manpower_label:
		manpower_label.text = str(manpower)
		
	# Update enemy labels
	if enemy_points_label:
		enemy_points_label.text = str(enemy_points)
	if enemy_military_points_label:
		enemy_military_points_label.text = str(enemy_military_points)
	if enemy_political_points_label:
		enemy_political_points_label.text = str(enemy_political_power)
	if enemy_manpower_points_label:
		enemy_manpower_points_label.text = str(enemy_manpower)  # Display static manpower value

func calculate_political_power_gain(is_enemy: bool = false) -> int:
	if is_enemy:
		var total_gain = enemy_political_power_gain
		for modifier in enemy_political_power_modifiers:
			total_gain += modifier
		return total_gain
	else:
		var total_gain = political_power_gain
		for modifier in political_power_modifiers:
			total_gain += modifier
		return total_gain

func add_political_power_modifier(value: int, is_enemy: bool = false):
	if is_enemy:
		enemy_political_power_modifiers.append(value)
	else:
		political_power_modifiers.append(value)

func remove_political_power_modifier(value: int, is_enemy: bool = false):
	if is_enemy:
		enemy_political_power_modifiers.erase(value)
	else:
		political_power_modifiers.erase(value)

func can_afford(cost: int, resource_type: String, is_enemy: bool = false) -> bool:
	match resource_type:
		"points":
			return is_enemy if enemy_points >= cost else points >= cost
		"military_points":
			return is_enemy if enemy_military_points >= cost else military_points >= cost
		"political_power":
			return is_enemy if enemy_political_power >= cost else political_power >= cost
	return false

func spend_resources(cost: int, resource_type: String, is_enemy: bool = false):
	match resource_type:
		"points":
			if is_enemy:
				enemy_points -= cost
			else:
				points -= cost
		"military_points":
			if is_enemy:
				enemy_military_points -= cost
			else:
				military_points -= cost
		"political_power":
			if is_enemy:
				enemy_political_power -= cost
			else:
				political_power -= cost

func _process(_delta):
	update_labels()
