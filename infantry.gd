# infantry.gd / garrison.gd
extends Node2D

var movement_points = 1
var has_moved = false

func reset_movement():
	has_moved = false

func can_move():
	return !has_moved
