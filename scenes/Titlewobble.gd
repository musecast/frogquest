extends Sprite2D

var angle_range = 0.02  # The maximum angle to rotate back and forth
var speed = 0.5  # The speed of rotation
var heartoffset = randf_range(-1.0, 1.0)  # Random offset for each heart

var base_scale: Vector2
var spring_offset := 0.0
var spring_velocity := 0.0
var spring_stiffness := 200.0
var spring_damping := 14.0

func _process(delta):
	var time_passed = (Time.get_ticks_msec() / 1000.0) + heartoffset
	rotation = sin(time_passed * speed) * angle_range

	if abs(spring_offset) < 0.0005 and abs(spring_velocity) < 0.001:
		spring_offset = 0.0
		spring_velocity = 0.0
		base_scale = scale  # stay in sync with whatever player.gd set for this orientation
	else:
		var force = -spring_stiffness * spring_offset - spring_damping * spring_velocity
		spring_velocity += force * delta
		spring_offset += spring_velocity * delta
		scale = base_scale + Vector2(spring_offset, spring_offset)

func _input(event):
	var pressed := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if pressed and get_rect().has_point(to_local(event.position)):
		spring_velocity += 0.3
