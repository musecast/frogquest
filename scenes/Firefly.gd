extends Sprite2D

# Reference to the player node
@onready var player = $"../../Player"

func _process(delta):
	# Get the direction vector from the sprite to the player
	var direction = player.position - global_position
	# Calculate the angle to the player
	var angle = direction.angle() + 1.4
	# Set the sprite's rotation to face the player
	rotation = angle
