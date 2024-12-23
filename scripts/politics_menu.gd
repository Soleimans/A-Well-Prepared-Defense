extends Control

@onready var minister_manager = get_node("/root/Main/Grid/MinisterManager")
@onready var first_minister_label = get_node("Panel/GridContainer/VBoxContainer/HBoxContainer/Label")

func _ready():
	# Connect close button
	$Button.pressed.connect(_on_close_button_pressed)
	
	# Connect the first minister's label
	if first_minister_label:
		first_minister_label.gui_input.connect(_on_minister_label_clicked)
		first_minister_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _on_minister_label_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var minister = minister_manager.get_minister_by_label_path("Panel/GridContainer/VBoxContainer/HBoxContainer/Label")
		if minister:
			if minister.active:
				minister_manager.dismiss_minister(minister)
				first_minister_label.text = "Political Advisor (Available)"
			else:
				if minister_manager.hire_minister(minister):
					first_minister_label.text = "Political Advisor (Active)"

func _on_close_button_pressed():
	hide()

func _process(_delta):
	if visible:
		# Update the first minister's label state
		var minister = minister_manager.get_minister_by_label_path("Panel/GridContainer/VBoxContainer/HBoxContainer/Label")
		if minister:
			if minister.active:
				first_minister_label.text = "Political Advisor (Active)"
			else:
				first_minister_label.text = "Political Advisor (Available)"
