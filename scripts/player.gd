extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var bestRun = 1
var jumpCount = 0
var time_elapsed
var time_now
var time_start
var tempVelocityx = 0.0
var minutes = 0
var seconds = 0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var highScore
var currentHeight

func _ready():	
	currentHeight = (-position.y - 472) /10
	highScore = currentHeight
	time_start = Time.get_unix_time_from_system()


func _physics_process(delta):
	
	currentHeight = (-position.y - 472) /10
	
	time_now = Time.get_unix_time_from_system()
	var time_elapsed = time_now - time_start
	
	if time_elapsed > seconds:
		seconds = time_elapsed
	
	if time_elapsed > 59:
		minutes += 1
		time_elapsed = 0
		seconds = 0
		time_start = Time.get_unix_time_from_system()
	
		
	if currentHeight > highScore:
		highScore = currentHeight
		bestRun = 1
		
	if currentHeight >= 0:
		$"CanvasLayer/current height".visible = true
	# Add the gravity.
	if not is_on_floor():
		
		velocity.y += gravity * delta
		$Sprite2D.play("airborne")
		
		
		if is_on_wall():
			print("Wall detected at position: ", position)
			velocity.x = -tempVelocityx
			print("New velocity: ", velocity)

			
	if is_on_floor():
		
		if $Trajectory.mousePath.length() > 200:
			$Sprite2D.play("prejump")
		else:	
			if currentHeight < highScore - 70 and bestRun == 1:
				$sadTimer.start()
				bestRun = 0
			
			if $sadTimer.is_stopped():
				$Sprite2D.play("default")
			else:
				$Sprite2D.play("sad")
				if $"../Environmental Audio/Classical Bangers".playing == false:
					await get_tree().create_timer(0.8).timeout
					$"../Environmental Audio/Classical Bangers".play(0.0)
				

				
		
		
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		
	tempVelocityx = velocity.x/2.5
	
	$"CanvasLayer/current height".text = str(int(currentHeight))
	$"CanvasLayer/high score".text = str(int(highScore))
	$CanvasLayer/time.text = ("time: " + str(int(minutes))+ ":"+str("%02d" % seconds) )
	$CanvasLayer/jumpcount.text = ("jumps: " + str(int(jumpCount)))
	
	move_and_slide()


func _on_area_2d_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	velocity = Vector2(-500, -400)
	$"../frogNPC3/campfire/Area2D/burnSound".play()
