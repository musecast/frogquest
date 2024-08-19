extends Node2D

var mouseOrigin = Vector2()
var mousePosition = Vector2()
var mousePath = Vector2()
var cursorLock = false
var endGame = 1
var sensitivity = 3.5

func _ready():

	pass

func _process(delta):
	if Engine.time_scale != 0.05 and Engine.time_scale != 0.0 and endGame == 0:
		if get_parent().is_on_floor():
			if Input.is_action_just_pressed("ui_mouse"):
				#Input.set_default_cursor_shape()
				#Input.set_custom_mouse_cursor(load("res://assets/cursorclosed.png"))
				if cursorLock == true:
					Input.mouse_mode = 4
					get_viewport().warp_mouse(Vector2(160,15))
				#elif DisplayServer.window_get_mode() == 3:
				#	Input.mouse_mode = 3
				else:
					Input.mouse_mode = 0
				mouseOrigin = get_global_mouse_position()
				$"../frogaim".play()
				
			if Input.is_action_pressed("ui_mouse"):
				Input.set_custom_mouse_cursor(load("res://assets/cursorclosed.png"))
				mousePosition = get_global_mouse_position()
				if mouseOrigin != Vector2(0, 0):
					mousePath = mouseOrigin - mousePosition
					queue_redraw()
			else:
				Input.set_custom_mouse_cursor(load("res://assets/cursoropen.png"))
				
			if Input.is_action_just_released("ui_mouse"):
				
				
				Input.set_custom_mouse_cursor(load("res://assets/cursoropen.png"))
				if cursorLock == true:
					#Input.mouse_mode = 3
					pass
				if mouseOrigin != Vector2(0, 0):
					var velocity = get_parent().velocity
					# dont? MULTIPLY BY SENSITIVITY
					velocity = mousePath * sensitivity
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
			
			#Input.set_custom_mouse_cursor(load("res://assets/cursoropen.png"))
		else:
			Input.set_custom_mouse_cursor(load("res://assets/cursor-x.png"))
					
func _draw():
	if Input.is_action_pressed("ui_mouse"):
		var max_length = Vector2(300, 300).length()
		var trajectory = (mousePath * (sensitivity/2)).clamp(Vector2(-300, -300), Vector2(300, 300))
		var trajectoryLength = trajectory.length()
		trajectory = trajectory.normalized() * trajectoryLength

		var normalized_length = trajectoryLength / max_length
		var lineColor = 1.2 - normalized_length
		
		draw_line(Vector2(0,0), trajectory / 5, Color(255, lineColor, lineColor, 1), 2.0)


func _on_cursor_lock_button_pressed():
	cursorLock = !cursorLock
