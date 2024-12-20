extends Node

var points = 10800
var military_points = 0

@onready var points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label")
@onready var military_points_label = get_node("/root/Main/UILayer/ColorRect/HBoxContainer/Label2")

func initialize():
	update_labels()

func update_labels():
	if points_label:
		points_label.text = str(points)
	else:
		print("Points label not found!")
		push_error("Points label not found at /root/Main/UILayer/ColorRect/HBoxContainer/Label")
		
	if military_points_label:
		military_points_label.text = str(military_points)
	else:
		print("Military points label not found!")
		push_error("Military points label not found at /root/Main/UILayer/ColorRect/HBoxContainer/Label2")

func _process(_delta):
	update_labels()
