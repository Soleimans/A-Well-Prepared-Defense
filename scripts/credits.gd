extends Control

func _ready():
	# Show the credits menu when the scene starts
	visible = true
	
	# Connect the button signals
	var close_button = $Panel/GridContainer/HBoxContainer/CloseCredits
	var website_button = $Panel/GridContainer/HBoxContainer/GoWebsite
	
	close_button.pressed.connect(_on_close_credits_pressed)
	website_button.pressed.connect(_on_go_website_pressed)

func _on_close_credits_pressed():
	# Hide the credits menu
	visible = false

func _on_go_website_pressed():
	# Open the website URL
	OS.shell_open("https://game-icons.net/")
