extends Node2D

var level = 1

func _ready():
	update_label()

func set_level(new_level):
	level = new_level
	update_label()

func update_label():
	$Sprite2D/Label.text = "Fort Level " + str(level)
