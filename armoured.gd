extends Node2D

var movement_points = 2
var has_moved = false
var is_enemy = false

func reset_movement():
	has_moved = false

func can_move():
	return !has_moved

func _ready():
	$Label.text = "Armoured"
