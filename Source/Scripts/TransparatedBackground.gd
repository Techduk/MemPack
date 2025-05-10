extends Node2D

func _ready():
	# Make the viewport's background transparent
	var viewport = get_viewport()
	viewport.transparent_bg = true  # Set transparent background

	# Ensure the sprite is visible
	#$Godot.show() # Add all visible sprites
