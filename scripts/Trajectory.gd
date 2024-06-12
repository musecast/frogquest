extends Node2D

var mouseOrigin = Vector2()
var mousePosition = Vector2()
var mousePath = Vector2()

func _ready():
	pass

func _process(delta):
	if get_parent().is_on_floor():
		if Input.is_action_just_pressed("ui_mouse"):
			mouseOrigin = get_global_mouse_position()
			$"../frogaim".play()
			
		if Input.is_action_pressed("ui_mouse"):
			mousePosition = get_global_mouse_position()
			if mouseOrigin != Vector2(0, 0):
				mousePath = mouseOrigin - mousePosition
				queue_redraw()
			
		if Input.is_action_just_released("ui_mouse"):
			if mouseOrigin != Vector2(0, 0):
				var velocity = get_parent().velocity
				velocity = mousePath * 2
				velocity.x *= 1.5
				velocity.y *= 1.1
				velocity.x = clamp(velocity.x, -800, 800)
				velocity.y = clamp(velocity.y, -450, 450)
				
				if abs(velocity.x) < 450:
					velocity.y *= 1.0
					velocity.x = 200 * sign(velocity.x) + velocity.x
					print("vel multiplied")
					
				if abs(velocity.x) < 450 and abs(velocity.y) > 350:
					velocity.y *= 1.0
					velocity.x = 50 * sign(velocity.x) + velocity.x
					#FIX
					#FIX
					#FIX
					#FIX
					#FIX
					#FIX
					print("more vel multiplied")
					
				if abs(velocity.x) >= 450 and abs(velocity.x) <= 520:
					velocity.y *= 1.0
					#velocity.x = 50 * sign(velocity.x) + velocity.x
					print("STRONG vel multiplied")
					
				get_parent().velocity = velocity
				print(velocity)
				mouseOrigin = Vector2(0, 0)
				mousePath = Vector2(0, 0)
				mousePosition = Vector2(0, 0)
				$"../frogjump".pitch_scale = randf_range(0.8, 1.2)
				$"../frogjump".play()
				$"..".jumpCount += 1
				queue_redraw()

func _draw():
	if Input.is_action_pressed("ui_mouse"):
		var max_length = Vector2(300, 300).length()
		var trajectory = mousePath.clamp(Vector2(-300, -300), Vector2(300, 300))
		var trajectoryLength = trajectory.length()
		trajectory = trajectory.normalized() * trajectoryLength

		var normalized_length = trajectoryLength / max_length
		var lineColor = 1.2 - normalized_length
		
		draw_line(Vector2(0,0), trajectory / 5, Color(255, lineColor, lineColor, 1), 2.0)
