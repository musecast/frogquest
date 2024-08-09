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
var finalTime
var finalTimeBool = 0
var finalbuttonBool = 0


# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var highScore
var currentHeight

func _ready():
	
	currentHeight = (-position.y - 472) /10
	highScore = currentHeight
	time_start = Time.get_unix_time_from_system()
	
	if MusicManager.froggyCrown != 0:
		$Froggycrown.visible = true


func _physics_process(delta):
	
	if Input.is_action_just_pressed("mute_music"):
		pass
		#$sadTimer.stop()
		#$"../Environmental Audio/Classical Bangers".stop()
		#$"../Environmental Audio/Classical Bangers2".stop()
		#$"../Environmental Audio/Classical Bangers3".stop()
		#$"../finale/Control/froggod".stop()
		#$winscreen/goodbyefroggy.stop()
	
	
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
		position.x = 2804
		velocity = Vector2(0,0)
		$"../finale/finale walls/toshow".visible = false
		await get_tree().create_timer(1.0).timeout
		$Camera2D/AnimationPlayer.play("end")
		if finalTimeBool == 0:
			finalTime = str(int(minutes))+ ":"+str("%02d" % seconds)
			finalTimeBool =1
			await get_tree().create_timer(3.0).timeout
			$winscreen/goodbyefroggy.play()

		
	if $Camera2D/AnimationPlayer.is_playing and $Camera2D/AnimationPlayer.current_animation:
		position.y = -8382
		position.x = 2804
		if $Camera2D/AnimationPlayer.current_animation_position > 12:
			$Camera2D/AnimationPlayer.seek(13)
			
			$winscreen/time2.text = ("In " + str(finalTime) + " and " + str(int(jumpCount)) + " jumps")
			#$winscreen/jumpcount2.text = ("jumps: " + str(int(jumpCount)))
			
			if finalbuttonBool == 0:
				$winscreen.visible = true
				$winscreen/thanksforplayingButton.visible = false
				$winscreen/thanksforplayingTimer.start()
				finalbuttonBool = 1
				$Camera2D.position = Vector2(-1770.67, 7144.045)
	

		
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
					if not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and not $winscreen/goodbyefroggy.playing and bangersCount  == 0:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers".play(0.0)
						bangersCount = 1
					elif not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and not $winscreen/goodbyefroggy.playing and bangersCount == 1:
						#await get_tree().create_timer(0.8).timeout
						$"../Environmental Audio/Classical Bangers2".play(0.0)
						bangersCount = 2
					elif not $"../Environmental Audio/Classical Bangers".playing and not $"../Environmental Audio/Classical Bangers2".playing and not $"../Environmental Audio/Classical Bangers3".playing and not $winscreen/goodbyefroggy.playing and bangersCount == 2:
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
	
	# Scale the current height from 0-779 to 0-1000
	var scaledHeight = int((currentHeight / 779.0) * 1000)
	
	$"CanvasLayer/current height".text = str(int(scaledHeight))
	$"CanvasLayer/high score".text = str(int(highScore))
	$CanvasLayer/time.text = ("time: " + str(int(minutes))+ ":"+str("%02d" % seconds) )
	$CanvasLayer/jumpcount.text = ("jumps: " + str(int(jumpCount)))
	
	if minutes > 18:
		$CanvasLayer/time.position = Vector2(245, 4)
	
	if jumpCount> 1000:
		$CanvasLayer/jumpcount.position.x = 245
		
	
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
	$PauseScreen/RestartButton.visible = false
	$PauseScreen/ResumeButton.visible = false
	$PauseScreen/SettingsButton.visible = false
	$PauseScreen/RestartConfirmContainer.visible = true
	

func _on_mute_button_pressed():
	#MUTE MUSIC
	AudioServer.set_bus_mute(1, not AudioServer.is_bus_mute(1))


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


func _on_button_pressed():
	$Trajectory.endGame = 0
	$".".visible = true
	$titlescreen. visible = false
	$"../finale/Control/frogappear".play()
	$"../frogNPC6/pathopen".play()


func _on_thanksforplaying_timer_timeout():
	$winscreen/thanksforplayingButton.visible = true


func _on_thanksforplaying_button_pressed():
	MusicManager.MusicPosition = $winscreen/goodbyefroggy.get_playback_position()
	MusicManager.froggyCrown = 1
	get_tree().reload_current_scene()
	Engine.time_scale = 1.0


func _on_settings_button_pressed():
	$frogaim.play()
	
	
	$PauseScreen/RestartButton.visible=false
	$PauseScreen/SettingsButton.visible=false
	$PauseScreen/ResumeButton.visible=false
	
	$PauseScreen/settingsContainer.visible=true
	$PauseScreen/BackfromSettingsButton.visible = true
	


func _on_backfrom_settings_button_pressed():
	$frogaim.play()
	
	
	$PauseScreen/RestartButton.visible=true
	$PauseScreen/SettingsButton.visible=true
	$PauseScreen/ResumeButton.visible=true
	
	$PauseScreen/settingsContainer.visible=false
	$PauseScreen/BackfromSettingsButton.visible = false


func _on_resume_button_pressed():

	$frogjump.pitch_scale = randf_range(0.8, 1.2)	
	$frogjump.play()
	#GAME IS UNPAUSED HERE
	$PauseScreen.visible=false
	Engine.time_scale = 1.0

#CHANGE SENSITIVITY
#CHANGE SENSITIVITY
#CHANGE SENSITIVITY
func _on_l_pressed():
	$Trajectory.sensitivity = 1.5


func _on_m_pressed():
	$Trajectory.sensitivity = 2


func _on_h_pressed():
	$Trajectory.sensitivity = 4


func _on_restart_yes_pressed():
	get_tree().reload_current_scene()
	Engine.time_scale = 1.0


func _on_restart_no_pressed():
	$PauseScreen/RestartButton.visible = true
	$PauseScreen/ResumeButton.visible = true
	$PauseScreen/SettingsButton.visible = true
	$PauseScreen/RestartConfirmContainer.visible = false


func _on_mute_button_2_pressed():
	#MUTE MUSIC
	AudioServer.set_bus_mute(2, not AudioServer.is_bus_mute(2))
