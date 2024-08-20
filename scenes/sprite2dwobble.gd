extends Sprite2D

var angle_range = 0.05  # The maximum angle to rotate back and forth
var speed = 2.5  # The speed of rotation
var heartoffset = randf_range(-1.0, 1.0)  # Random offset for each heart

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var time_passed = (Time.get_ticks_msec() / 1000.0) + heartoffset
	rotation = sin(time_passed * speed) * angle_range
