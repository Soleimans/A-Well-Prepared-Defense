# garrison.gd
extends Node2D

var movement_points = 1
var has_moved = false
var is_enemy = false
var soft_health = 400
var hard_health = 100
var equipment = 500
var max_soft_health = 400
var max_hard_health = 100
var max_equipment = 500
var soft_attack = 200
var hard_attack = 50

@onready var sprite = $Sprite2D
@onready var health_bar = $Health
@onready var equipment_bar = $Equipment

func _ready():
	$Label.text = "Garrison"
	if is_enemy and sprite:
		sprite.modulate = Color.RED
	setup_progress_bars()

func setup_progress_bars():
	if health_bar and equipment_bar:
		# Set max values for total health and equipment
		health_bar.max_value = max_soft_health + max_hard_health
		health_bar.value = soft_health + hard_health
		health_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		
		equipment_bar.max_value = max_equipment
		equipment_bar.value = equipment
		equipment_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		
		# Set up the style for the bars
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.2, 0.2, 0.2, 1.0)  # Dark gray background
		style_box.set_corner_radius_all(2)
		
		var health_style = StyleBoxFlat.new()
		health_style.bg_color = Color(0, 0.8, 0, 1.0)  # Green for health
		health_style.set_corner_radius_all(2)
		
		var equipment_style = StyleBoxFlat.new()
		equipment_style.bg_color = Color(0.8, 0.8, 0, 1.0)  # Yellow for equipment
		equipment_style.set_corner_radius_all(2)
		
		# Apply the styles
		health_bar.add_theme_stylebox_override("background", style_box.duplicate())
		health_bar.add_theme_stylebox_override("fill", health_style)
		
		equipment_bar.add_theme_stylebox_override("background", style_box.duplicate())
		equipment_bar.add_theme_stylebox_override("fill", equipment_style)
		
		# Set the size and layout
		health_bar.custom_minimum_size = Vector2(10, 50)  # Thin and tall
		equipment_bar.custom_minimum_size = Vector2(10, 50)  # Thin and tall
		
		# Set initial values
		health_bar.value = health_bar.max_value
		equipment_bar.value = equipment_bar.max_value

func update_bars():
	if health_bar and equipment_bar:
		# Calculate current values
		var current_total_health = soft_health + hard_health
		var current_equipment = equipment
		
		# Update the bar values
		health_bar.value = current_total_health
		equipment_bar.value = current_equipment

func reset_movement():
	has_moved = false
	movement_points = 1

func can_move():
	return !has_moved && movement_points > 0

func set_highlighted(value: bool):
	if sprite:
		if value:
			sprite.modulate = Color(1.5, 1.5, 0.5) if !is_enemy else Color(1.5, 0.5, 0.5)
		else:
			sprite.modulate = Color.WHITE if !is_enemy else Color.RED

func _process(_delta):
	update_bars()
