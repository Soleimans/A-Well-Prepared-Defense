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
var in_combat_this_turn = false

@onready var sprite = $Sprite2D
@onready var label = $Label
@onready var health_bar = $Health
@onready var equipment_bar = $Equipment

func _ready():
	$Label.text = "Garrison"
	setup_progress_bars()

func setup_progress_bars():
	if health_bar and equipment_bar:
		health_bar.max_value = max_soft_health + max_hard_health
		health_bar.value = soft_health + hard_health
		health_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		
		equipment_bar.max_value = max_equipment
		equipment_bar.value = equipment
		equipment_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.2, 0.2, 0.2, 1.0)  
		style_box.set_corner_radius_all(2)
		
		var health_style = StyleBoxFlat.new()
		health_style.bg_color = Color(0, 0.8, 0, 1.0) 
		health_style.set_corner_radius_all(2)
		
		var equipment_style = StyleBoxFlat.new()
		equipment_style.bg_color = Color(0.8, 0.8, 0, 1.0) 
		equipment_style.set_corner_radius_all(2)
		
		health_bar.add_theme_stylebox_override("background", style_box.duplicate())
		health_bar.add_theme_stylebox_override("fill", health_style)
		
		equipment_bar.add_theme_stylebox_override("background", style_box.duplicate())
		equipment_bar.add_theme_stylebox_override("fill", equipment_style)
		
		health_bar.custom_minimum_size = Vector2(4, 18)  
		equipment_bar.custom_minimum_size = Vector2(4, 18)  
		
		health_bar.value = health_bar.max_value
		equipment_bar.value = equipment_bar.max_value

func try_replenish() -> Dictionary:
	if has_moved or in_combat_this_turn:
		return {"replenished": false}
		
	var equipment_needed = max_equipment - equipment
	var soft_health_needed = max_soft_health - soft_health
	var hard_health_needed = max_hard_health - hard_health
	
	# Calculate actual amounts to replenish 
	var equipment_replenish = min(100, equipment_needed)
	var soft_health_replenish = min(200, soft_health_needed)
	var hard_health_replenish = min(100, hard_health_needed)
	
	# Calculate costs based on actual replenishment
	var military_cost = ceil(equipment_replenish / 100.0 * 100)  
	var manpower_cost = ceil((soft_health_replenish / 200.0 + hard_health_replenish / 100.0) * 300)  
	
	# Apply replenishment
	equipment += equipment_replenish
	soft_health += soft_health_replenish
	hard_health += hard_health_replenish
	
	return {
		"replenished": equipment_replenish > 0 or soft_health_replenish > 0 or hard_health_replenish > 0,
		"military_cost": military_cost,
		"manpower_cost": manpower_cost
	}

func update_bars():
	if health_bar and equipment_bar:
		# Calculate current 
		var current_total_health = soft_health + hard_health
		var current_equipment = equipment
		
		# Update values
		health_bar.value = current_total_health
		equipment_bar.value = current_equipment

func reset_movement():
	has_moved = false
	movement_points = 1
	in_combat_this_turn = false

func can_move():
	return !has_moved && movement_points > 0

func set_highlighted(value: bool):
	pass

func _process(_delta):
	update_bars()
