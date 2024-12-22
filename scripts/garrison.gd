extends Node2D

var movement_points = 1  # (2 for armoured)
var has_moved = false
var is_enemy = false
@onready var sprite = $Sprite2D  # Reference to the sprite instead of ColorRect

func _ready():
	$Label.text = "Garrison"  # ("Armoured" or "Garrison" for other units)
	if is_enemy and sprite:
		sprite.modulate = Color.RED

func reset_movement():
	has_moved = false
	movement_points = 1  # (or max_movement_points for armoured)

func can_move():
	return !has_moved && movement_points > 0

func set_highlighted(value: bool):
	if sprite:
		if value:
			# Bright yellow tint when highlighted
			sprite.modulate = Color(1.5, 1.5, 0.5) if !is_enemy else Color(1.5, 0.5, 0.5)
		else:
			# Return to normal color or enemy color
			sprite.modulate = Color.WHITE if !is_enemy else Color.RED
