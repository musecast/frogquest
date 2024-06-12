extends TileMap

# Amplitude of the movement
var amplitude = 10.0
# Speed of the movement
var speed = 1.0
# Initial position
var initial_position = Vector2()

# Called when the node enters the scene tree for the first time.
func _ready():
	# Store the initial position of the TileMap
	initial_position = position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Calculate the new y position using a sine wave
	var new_y = initial_position.y + amplitude * sin(speed * Time.get_ticks_msec() / 1000.0)
	# Update the position of the TileMap
	position.y = new_y
