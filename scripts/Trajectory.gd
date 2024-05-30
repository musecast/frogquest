extends Node2D

var mouseOrigin = Vector2()
var mousePosition = Vector2()
var mousePath = Vector2()


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if get_parent().is_on_floor():
		
		if Input.is_action_just_pressed("ui_mouse"):
			mouseOrigin = get_global_mouse_position()
			$"../frogaim".play()
			
		if Input.is_action_pressed("ui_mouse"):
			mousePosition = get_global_mouse_position()
			if mouseOrigin != Vector2(0,0):
				mousePath = mouseOrigin - mousePosition
				queue_redraw()
			
		if Input.is_action_just_released("ui_mouse"):
			if mouseOrigin != Vector2(0,0):
				var velocity = get_parent().velocity
				velocity = mousePath * 2
				velocity.x *= 1.5
				while velocity.x < -800:
					velocity.x += 50
				while velocity.x > 800:
					velocity.x -= 50
				while velocity.y < -450:
					velocity.y += 50
					
				#if velocity.x > 800 or velocity.x < -800:
				#	velocity = velocity.clamp(Vector2(-800,-450), Vector2(800,0))
				
				if velocity.x < 450 and velocity.x > -450 and velocity.x > 0:
					velocity.y *= 1.15
					velocity.x = 250 + velocity.x
					print("vel multiplied positive")
					
				if velocity.x < 450 and velocity.x > -450 and velocity.x < 0:
					velocity.y *= 1.15
					velocity.x = -250 + velocity.x
					print("vel multiplied negative")
					
				get_parent().velocity = velocity
				print(velocity)
				mouseOrigin = Vector2(0,0)
				mousePosition = (0)
				$"../frogjump".pitch_scale = randf_range(0.8, 1.2)
				$"../frogjump".play()
				queue_redraw()
		pass



func _draw():
		if Input.is_action_pressed("ui_mouse"):
			var trajectory = mousePath.clamp(Vector2(-300,-300), Vector2(300,300))
			var trajectorylength = trajectory.length()
			trajectory = trajectory.normalized() * (trajectorylength)
			draw_line(Vector2(0,0), trajectory/5, Color.DEEP_PINK, 2.0)
