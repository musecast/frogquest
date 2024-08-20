extends Label

var angle_range = 0.05  # The maximum angle to rotate back and forth
var speed = 0.5  # The speed of rotation
var heartoffset = randf_range(-0.2, 0.2)  # Random offset for each heart

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if $"../../Player/Trajectory".endGame == 0:
		var time_passed = (Time.get_ticks_msec() / 1000.0) + heartoffset
		rotation = sin(time_passed * speed) * angle_range
