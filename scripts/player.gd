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
@export var max_y_position: float = 500.0 # The Y position at which the opacity should be 100%
var fade_duration = 1.0 # Duration for fading in seconds
var bangersCount = 0
var songTrigger = 70
@export var has_lantern = false
@export var has_key = false
var music_bus = AudioServer.get_bus_index("Master")
var SpeedrunMode = false


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var highScore
var currentHeight

func _ready():
	
	currentHeight = (-position.y - 472) /10
	highScore = currentHeight
	time_start = Time.get_unix_time_from_system()


func _physics_process(delta):
	
	if Input.is_action_just_pressed("mute_music"):
		$sadTimer.stop()
		$"../Environmental Audio/Classical Bangers".stop()
		$"../Environmental Audio/Classical Bangers2".stop()
		$"../Environmental Audio/Classical Bangers3".stop()
		$"../finale/Control/froggod".stop()
	
	
	
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
	
	
	if currentHeight > 779:
		$CanvasLayer.visible = false
			
	elif currentHeight >= 0:
		$"CanvasLayer/current height".visible = true
		
	if currentHeight > 787:
		$Trajectory.endGame = 1
		position.y = -8382
		velocity = Vector2(0,0)
		
		
	# Add the gravity.
	if not is_on_floor():
		
		velocity.y += gravity * delta
		$Sprite2D.play("airborne")
		$Shadow.play("airborne")
		
		if is_on_wall():
			print("Wall detected at position: ", position)
			velocity.x = -tempVelocityx
			print("New velocity: ", velocity)

			
	if is_on_floor():
		
		if $Trajectory.mousePath.length() > 200:
			$Sprite2D.play("prejump")
		else:	
			if currentHeight < highScore - songTrigger and bestRun == 1:
				songTrigger += 15
				$sadTimer.start()
				bestRun = 0
			
			if $sadTimer.is_stopped():
				$Sprite2D.play("default")
				$Shadow.play("default")
			else:
				$Sprite2D.play("sad")
				if not $"../finale/Control/froggod".playing:
					if not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and bangersCount  == 0:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers".play(0.0)
						bangersCount = 1
					elif not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and bangersCount == 1:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers2".play(0.0)
						bangersCount = 2
					elif not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and bangersCount == 2:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers3".play(0.0)
						bangersCount = 0
					
				

				
		
		
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
		
	if has_lantern and Input.is_action_just_pressed("ui_light"):
		if $FrogLantern.visible:
			$FrogLantern.visible = false
			$FrogLantern/lanternout.play()
			fade_lantern(0.0)
		else:
			$FrogLantern.visible = true
			$FrogLantern/lanternignite.play()
			fade_lantern(1.0)
			
			
	
	tempVelocityx = velocity.x/2.5
	
	$"CanvasLayer/current height".text = str(int(currentHeight))
	$"CanvasLayer/high score".text = str(int(highScore))
	$CanvasLayer/time.text = ("time: " + str(int(minutes))+ ":"+str("%02d" % seconds) )
	$CanvasLayer/jumpcount.text = ("jumps: " + str(int(jumpCount)))
	
	
	fade_darkness()
	
	move_and_slide()


func _on_area_2d_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	velocity = Vector2(-500, -400)
	$"../frogNPC3/campfire/Area2D/burnSound".play()
	
	
	

func fade_lantern(target_alpha):
	var start_alpha = $FrogLantern.modulate.a
	var elapsed_time = 0.0
	
	while elapsed_time < fade_duration:
		elapsed_time += get_process_delta_time()
		var new_alpha = lerp(start_alpha, target_alpha, elapsed_time / fade_duration)
		$FrogLantern.modulate.a = new_alpha
		await get_tree().create_timer(0.01).timeout

func fade_darkness():
	var heightCheck = currentHeight - 145
	var darknessHeight = (clamp(heightCheck, 0, 100)/100) * 2
	
	if darknessHeight > 1:
		darknessHeight = 1
	
	if currentHeight > 313:
		$"../Darkness".visible = false
		$FrogLantern.visible = false
	elif currentHeight > 155:
		$"../Darkness".visible = true
		#RGB VALUES ARE FROM 0 TO 1 DUHHHHHH
		$"../Darkness".color.r = 1 - darknessHeight
		$"../Darkness".color.g = 1 - darknessHeight
		$"../Darkness".color.b = 1 - darknessHeight
		#print($"../Darkness".color.r)
	else:
		$FrogLantern.visible = false
		$"../Darkness".visible = false


func _on_area_2_dkeyhole_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	print("keyhole attempt")
	if has_key == true:
		print("keyhole success")
		$"../World Sprites/Keyhole/Area2Dkeyholeblocker".queue_free()
		$"../World Sprites/Keyhole".visible = false
		$"../World Sprites/Keyhole/havekey".play()
		$"../frogNPC6/pathopen".play()
		await get_tree().create_timer(0.5).timeout
		$"../World Sprites/Keyhole".queue_free()
	else:
		$"../World Sprites/Keyhole/donthavekey".play()
		print("keyhole fail")


func _on_restart_button_pressed():
	get_tree().reload_current_scene()
	Engine.time_scale = 1.0


func _on_mute_button_pressed():
	AudioServer.set_bus_mute(music_bus, not AudioServer.is_bus_mute(music_bus))


func _on_speedrun_mode_button_pressed():
	SpeedrunMode = !SpeedrunMode
	if SpeedrunMode == true:
		$CanvasLayer/time.visible = true
		$CanvasLayer/jumpcount.visible = true
	else:
		$CanvasLayer/time.visible = false
		$CanvasLayer/jumpcount.visible = false



func _on_blockedpath_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	velocity = Vector2(500, -300)
	$"../Environmental Audio/pathBreaking".play()
	$"../World Sprites/Blockedpath".queue_free()
