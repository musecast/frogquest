extends PointLight2D

# Variables to define the range and speed of the oscillation
var min_scale = 0.7
var max_scale = 0.8
var speed = 0.8  # Adjust this to change the speed of the oscillation

# Variable to keep track of the time
var time_passed = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time_passed += delta * speed
	var scale_value = lerp(min_scale, max_scale, 0.5 * (1 + sin(time_passed)))
	scale = Vector2(scale_value, scale_value)
