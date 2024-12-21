extends Node2D

var movement_points = 2
var max_movement_points = 2
var has_moved = false
var is_enemy = false

func reset_movement():
	has_moved = false
	movement_points = max_movement_points

func can_move():
	return !has_moved && movement_points > 0

func _ready():
	$Label.text = "Armoured"
