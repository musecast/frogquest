extends Node2D

var npc1 = 0
var npc2 = 0
var npc3 = 0
var npc4 = 0
var npc5 = 0
var npc6 = 0
var finaledamage = -2
var jokeCheck = 0
var foreshadowBool = 0

#var position = Vector2()
var has_key = null
var has_lantern = null
var hours = null
var minutes = null
var seconds = null
var SpeedrunMode = null
var froggyCrown = null
var map_variables = null
var jumpCount = null

const RESTRICTED_HEIGHT = 513

#top of script
@onready var previous_window = DisplayServer.window_get_mode()
@onready var current_window = DisplayServer.window_get_mode()


# Called when the node enters the scene tree for the first time.
func _ready():	# Start a timer for autosaving every 60 seconds (or your preferred interval)
	load_game()
	has_key = $Player.has_key
	has_lantern = $Player.has_lantern
	jokeCheck = $".".jokeCheck
	foreshadowBool = $".".foreshadowBool
	hours = $Player.hours
	minutes = $Player.minutes
	seconds = $Player.seconds
	SpeedrunMode = $Player.SpeedrunMode
	froggyCrown = MusicManager.froggyCrown
	jumpCount = $Player.jumpCount
	
	$Player/Trajectory.endGame = 1
	
	
	#Save Capabilities

	print(OS.get_user_data_dir())
	var autosave_timer = $AutosaveTimer  # The Timer node you added
	autosave_timer.start(3)  # Interval in seconds
	
	
	
	print($TileMap.get_layer_name(1))
	Engine.time_scale=1.0
		
	$frogNPC1.play("farmer")
	
	if MusicManager.MusicPosition != 0:
		$Player/winscreen/goodbyefroggy.play(MusicManager.MusicPosition)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#print($Player.currentHeight)
	
	if Input.is_action_just_pressed("pause") and $Player/Trajectory.endGame == 0:
		if Engine.time_scale != 1.0:
			#GAME IS UNPAUSED HERE
					
			$Player/PauseScreen/RestartButton.visible = true
			$Player/PauseScreen/ResumeButton.visible = true
			$Player/PauseScreen/SettingsButton.visible = true
			$Player/PauseScreen/RestartConfirmContainer.visible = false
			$Player/PauseScreen/settingsContainer.visible = false
			$Player/PauseScreen/BackfromSettingsButton.visible = false
			
			$Player/PauseScreen.visible=false
			Engine.time_scale = 1.0
		else:
			#GAME IS PAUSED HERE
			Input.mouse_mode = 0
			$Player/PauseScreen.visible=true
			Engine.time_scale = 0.05

#body of script
func _input(event):
	if Input.is_action_just_pressed("toggle_fullscreen"):
		current_window = DisplayServer.window_get_mode()
		if current_window != 3:
			previous_window = current_window
			DisplayServer.window_set_mode(3)
		else:
			if previous_window == 3:
				previous_window = 2
			DisplayServer.window_set_mode(previous_window)


func _on_area_2d_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	
	if npc1 == 1:
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1speechbubble.visible = true
		$frogNPC1/npc1speechbubble.text = "keep it up \nlil froggy..."
	if npc1 == 0:
		npc1 = 3
		print("npc croak")
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1speechbubble.visible = true
		$frogNPC1/npc1speechbubble.text = "so... you came \nfrom below?"
		await get_tree().create_timer(3.0).timeout
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1speechbubble.text = "maybe you'll be the \none to reach the top..."
		await get_tree().create_timer(3.0).timeout
		
		
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1talk.position.x = -82.842
		$frogNPC1/npc1speechbubble.text = "by the way, have you \nnoticed the white petals?"
		$frogNPC1/npc1talk.position.x = -71.031
		await get_tree().create_timer(4.0).timeout	
			
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1speechbubble.text = "some say they are \nsigns of the gods"
		await get_tree().create_timer(3.0).timeout
			
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1speechbubble.text = "whether you believe \nthat, is up to you"
		await get_tree().create_timer(3.0).timeout
			
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1talk.position.x = -82.842
		$frogNPC1/npc1speechbubble.text = "never had the courage \n for a leap of faith myself"
		await get_tree().create_timer(4.0).timeout
		
		$frogNPC1/npc1talk.position.x = -71.031
		
		
		$frogNPC1/npc1talk.play()
		$frogNPC1/npc1speechbubble.text = "keep it up \nlil froggy..."
		await get_tree().create_timer(3.0).timeout
		
		$frogNPC1/npc1speechbubble.visible = false
		npc1 = 1
		


func _on_area_2d_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
	if npc1 == 1:
		$frogNPC1/npc1speechbubble.visible = false


func _on_area_2d_2_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	
		if npc2 == 1:
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.visible = true
			$frogNPC2/npc2speechbubble.text = "don't forget to jump full \npower if you see the petals..."
			
		if npc2 == 0:
			npc2 = 3
			print("npc croak")
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.visible = true
			$frogNPC2/npc2speechbubble.text = "hehehe... good job \non the leap of faith"
			await get_tree().create_timer(3.0).timeout
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "how about \na joke..?"
			await get_tree().create_timer(3.0).timeout
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "what's a frog's \nfavorite year?"
			await get_tree().create_timer(3.0).timeout
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "leap year \nheheheheheh"
			await get_tree().create_timer(0.75).timeout
			$frogNPC2/npc2rimshot.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC2.play("wizlaugh")
			await get_tree().create_timer(0.5).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.49).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC2.play("wiz")
			await get_tree().create_timer(1.0).timeout

			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "thank you for listening \nto my joke young froggy"
			await get_tree().create_timer(3.0).timeout
			
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "now i shall give you wisdom \nhanded to me from the gods..."
			await get_tree().create_timer(5.0).timeout
			
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "the white petals indicate \nguaranteed safety for a jump..."
			await get_tree().create_timer(5.0).timeout
			
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "...but only if you take that \njump at your full strength."
			await get_tree().create_timer(5.0).timeout
			
			$frogNPC2/npc2talk.play()
			$frogNPC2/npc2speechbubble.text = "now hop along young froggy \nand let the petals guide you..."
			await get_tree().create_timer(4.0).timeout
			
			
			$frogNPC2/npc2speechbubble.visible = false
			npc2 = 1
			jokeCheck = 1


func _on_area_2d_2_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
	if npc2 == 1:
		$frogNPC2/npc2speechbubble.visible = false


func _on_area_2d_3_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):

	if npc3 == 1:
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.visible = true
		$frogNPC3/npc3speechbubble.text = "may the gods protect \nyou on your ascent..."
		await get_tree().create_timer(2.0).timeout
		$frogNPC3/npc3speechbubble.text = "godspeed \nlil froggy..."
		$frogNPC3/npc3talk.play()
		
	if npc3 == 0:
		npc3 = 3
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.visible = true
		$frogNPC3/npc3speechbubble.text = "the froggy of fate...\ni can't believe it"
		await get_tree().create_timer(3.0).timeout
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.text = "take this with you,\nit will help"
		await get_tree().create_timer(2.0).timeout
		$frogNPC3/lanternhitbox.visible = true
		$frogNPC3/lanternhitbox.position = Vector2(0,0)
		$frogNPC3/npc3itemspawn.play()
		await get_tree().create_timer(2.0).timeout
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.text = "with this lantern, \ndarkness fears you..."
		await get_tree().create_timer(3.0).timeout
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.text = "it shall light your \nway automatically"
		await get_tree().create_timer(3.0).timeout
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.text = "godspeed lil\nfroggy..."
		await get_tree().create_timer(3.0).timeout
		$frogNPC3/npc3speechbubble.visible = false
		npc3 = 1
		


func _on_area_2d_3_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
	if npc3 == 1:
		$frogNPC3/npc3speechbubble.visible = false


func _on_lanternhitbox_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$frogNPC3/lanternhitbox.queue_free()
	$frogNPC3/npc3itempickup.play()
	$Player.has_lantern = true


func _on_area_2d_4_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	if npc4 == 1:
		$frogNPC4/npc4talk.play()
		$frogNPC4/npc4speechbubble.visible = true
		$frogNPC4/npc4speechbubble.text = "hello again..."
		
	if npc4 == 0:
		npc4 = 3
		$frogNPC4/npc4talk.play()
		$frogNPC4/npc4speechbubble.visible = true
		$frogNPC4/npc4speechbubble.text = "oh hello"
		await get_tree().create_timer(3.0).timeout
		$frogNPC4/npc4talk.play()
		$frogNPC4/npc4speechbubble.text = "i'm lost..."
		await get_tree().create_timer(3.0).timeout
		$frogNPC4/npc4speechbubble.visible = false
		npc4 = 1


func _on_area_2d_4_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if npc4 == 1:
		$frogNPC4/npc4speechbubble.visible = false


func _on_area_2dkey_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"World Sprites/Key/Area2DKEY".queue_free()
	$Player.has_key = true
	$"World Sprites/Key".visible = false
	$"World Sprites/Key/keypickup".play()



func _on_frogking_2_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING2/frogking2".queue_free()
	$"finale/Control/FROG KING2".visible = true
	$finale/Control/frogappear.play()
	await get_tree().create_timer(2.0).timeout
	#$"finale/Control/froggod".play()

func _on_frogking_3_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING3/frogking3".queue_free()
	$"finale/Control/FROG KING3".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_4_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING4/frogking4".queue_free()
	$"finale/Control/FROG KING4".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_5_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING5/frogking5".queue_free()
	$"finale/Control/FROG KING5".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_6_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING6/frogking6".queue_free()
	$"finale/Control/FROG KING6".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_7_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING7/frogking7".queue_free()
	$"finale/Control/FROG KING7".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_8_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING8/frogking8".queue_free()
	$"finale/Control/FROG KING8".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_9_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING9/frogking9".queue_free()
	$"finale/Control/FROG KING9".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_10_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING10/frogking10".queue_free()
	$"finale/Control/FROG KING10".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_11_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING11/frogking11".queue_free()
	$"finale/Control/FROG KING11".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_12_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING12/frogking12".queue_free()
	$"finale/Control/FROG KING12".visible = true
	$finale/Control/frogappear.play()

func _on_frogking_13_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING13/frogking13".queue_free()
	$"finale/Control/FROG KING13".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_14_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING14/frogking14".queue_free()
	$"finale/Control/FROG KING14".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_15_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING15/frogking15".queue_free()
	$"finale/Control/FROG KING15".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_16_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING16/frogking16".queue_free()
	$"finale/Control/FROG KING16".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_17_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING17/frogking17".queue_free()
	$"finale/Control/FROG KING17".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_18_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING18/frogking18".queue_free()
	$"finale/Control/FROG KING18".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_19_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING19/frogking19".queue_free()
	$"finale/Control/FROG KING19".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_20_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING20/frogking20".queue_free()
	$"finale/Control/FROG KING20".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_21_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING21/frogking21".queue_free()
	$"finale/Control/FROG KING21".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_22_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING22/frogking22".queue_free()
	$"finale/Control/FROG KING22".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_23_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING23/frogking23".queue_free()
	$"finale/Control/FROG KING23".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_24_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING24/frogking24".queue_free()
	$"finale/Control/FROG KING24".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_25_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING25/frogking25".queue_free()
	$"finale/Control/FROG KING25".visible = true
	$finale/Control/frogappear.play()
	
func _on_frogking_26_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"finale/Control/FROG KING26/frogking26".queue_free()
	$"finale/Control/FROG KING26".visible = true
	$finale/Control/frogappear.play()


func _on_blockedpath_area_2d_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	#MAKE FIREFLY VISIBLE
	$"World Sprites/Firefly5".visible = true


func _on_blockedpath_area_2d_body_entered(body):
	#MAKE FIREFLY VISIBLE
	$"World Sprites/Firefly5".visible = true


func _on_finaleexit_body_entered(body):
	finaledamage += 1
	
	if finaledamage == 1:
		$finale/glasshurt.play()
		$"finale/finale sprites/Exit-entrance".play("2")
		$"World Sprites/GodraysContainer".visible = true
		$"World Sprites/GodraysContainer".modulate = Color(1, 1, 1, 0.7)
		
	if finaledamage == 2:
		$finale/glasshurt.play()
		$"finale/finale sprites/Exit-entrance".play("3")
		$"World Sprites/GodraysContainer2".visible = true		
		
	if finaledamage == 3:
		$finale/glasshurt.play()
		$"finale/finale sprites/Exit-entrance".modulate = Color(1, 1, 1, 0.7)
		$"World Sprites/GodraysContainer".modulate = Color(1, 1, 1, 1.0)
		$"World Sprites/GodraysContainer2".visible = true
		
	if finaledamage == 4:
		print("you win...")
		$"finale/finale sprites/Exit-entrance".queue_free()
		$finale/Control/froggod.stop()
		$finale/glassbreak.play()
		$"World Sprites/GodraysContainer3".visible = true


func _on_area_2d_5_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	
		if npc5 == 1:
			$frogNPC5/npc5talk.play()
			$frogNPC5/npc5speechbubble.visible = true
			$frogNPC5/npc5speechbubble.text = "the way forward is a\nleap of faith to your right..."
			
		if npc5 == 0:
			npc5 = 3
			print("npc croak")
			$frogNPC5/npc5talk.play()
			$frogNPC5/npc5speechbubble.visible = true
			if jokeCheck == 1:
				$frogNPC5/npc5speechbubble.text = "o ho ho ho so you\nwant another joke, do you?"
			else:
				$frogNPC5/npc5speechbubble.text = "o ho ho ho you must be\nhere for a good joke, yes?"
			await get_tree().create_timer(5.0).timeout
			$frogNPC5/npc5talk.play()
			$frogNPC5/npc5speechbubble.text = "why are frogs\nso happy..?"
			await get_tree().create_timer(3.0).timeout
			$frogNPC5/npc5talk.play()
			$frogNPC5/npc5speechbubble.text = "...because they eat\nwhatever bugs them"
			await get_tree().create_timer(0.75).timeout
			$frogNPC5/npc5rimshot.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC5.play("wizlaugh")
			await get_tree().create_timer(0.5).timeout
			$frogNPC5/npc5talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC5/npc5talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC5/npc5talk.play()
			await get_tree().create_timer(0.49).timeout
			$frogNPC5/npc5talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC5.play("wiz")
			await get_tree().create_timer(0.5).timeout
			$frogNPC5/npc5talk.play()
			$frogNPC5/npc5speechbubble.text = "hehehehe...\nnow let me help you"
			await get_tree().create_timer(3.0).timeout
			$frogNPC5/npc5talk.play()
			$frogNPC5/npc5speechbubble.text = "the way forward is a\nleap of faith to your right..."
			await get_tree().create_timer(5.0).timeout
			
			if jokeCheck == 1:
				$frogNPC5/npc5talk.play()
				$frogNPC5/npc5speechbubble.text = "although you probably \nknew that already heheh..."
				await get_tree().create_timer(4.0).timeout
			else:
				pass
			$frogNPC5/npc5speechbubble.visible = false
			npc5 = 1


func _on_area_2d_5_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if npc5 == 1:
		$frogNPC5/npc5speechbubble.visible = false


func _on_area_2d_6_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	
		$"finale/finale walls/toshow/Screenshot2024-06-26160646/StaticBody2D".set_collision_layer_value(1, 1)
		print("collision enabled")
		
		if npc6 == 1:
			$frogNPC6.queue_free()
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.visible = true
			$frogNPC6/npc6speechbubble.text = "godspeed\nlil froggy..."
			
		if npc6 == 0:
			npc6 = 3
			print("npc croak")
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.visible = true
			$frogNPC6/npc6speechbubble.text = "the froggy of fate\nin the flesh..."
			await get_tree().create_timer(3.0).timeout
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.text = "i commend you for\nmaking it this far..."
			await get_tree().create_timer(3.0).timeout
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.text = "your final test\nawaits you..."
			await get_tree().create_timer(3.0).timeout
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.text = "as you can see, these\n petals have fallen..."
			await get_tree().create_timer(4.0).timeout
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.position.x = -101.658
			$frogNPC6/npc6speechbubble.text = "there is no god to guide you,\n you must succeed on your own..."
			await get_tree().create_timer(5.0).timeout
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.text = "allow me to\nopen the path..."
			await get_tree().create_timer(3.0).timeout
			#OPEN PATH NOISE AND HIDE OUTSIDE (SHOW OUTSIDE SPRITES)
			$frogNPC6/pathopen.play()
			$"finale/finale walls/toshow".visible = true
			$"finale/finale walls/hidethis".visible = false
			$"finale/finale walls/hidethis/delete".queue_free()
			$TileMap.set_layer_enabled(2, 1) #enable finale foreground
			$shadowtilemap.set_layer_enabled(3, 1) #enable finale foreground shadows
			$finale/Control/froggod.play()
			
			
			await get_tree().create_timer(3.0).timeout
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.text = "godspeed\nlil froggy..."
			await get_tree().create_timer(3.0).timeout
			$frogNPC6/pathopen.play()
			$frogNPC6.visible = false
			npc6 = 1
			#$frogNPC6.queue_free()


func _on_area_2d_6_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if npc6 == 1:
		$frogNPC6/npc6speechbubble.visible = false







func _on_castleaudiocue_body_entered(body):
	if foreshadowBool == 0:
		$"Environmental Audio/castleaudiocue/froggodglimpse".play()
		foreshadowBool = 1


func _on_autosave_timer_timeout():
	autosave($Player.currentHeight)



func autosave(current_height):
	if current_height > RESTRICTED_HEIGHT:
		print("Autosave skipped.")
		return

	var save_data = {
		"position": $Player.position,
		"has_key": $Player.has_key,
		"has_lantern": $Player.has_lantern,
		"jokeCheck": jokeCheck,
		"foreshadowBool": foreshadowBool,
		"hours": $Player.hours,
		"minutes": $Player.minutes,
		"seconds": $Player.seconds,
		"SpeedrunMode": $Player.SpeedrunMode,
		"froggyCrown": MusicManager.froggyCrown,
		"map_variables": map_variables,
		"jumpCount": $Player.jumpCount,
	}
	
	var file = FileAccess.open("user://save_game.save", FileAccess.WRITE)
	file.store_var(save_data)
	file.close()
	print("Game saved.")

func load_game():
	var file = FileAccess.open("user://save_game.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		$Player.position = save_data["position"]
		$Player.has_key = save_data["has_key"]
		$Player.has_lantern = save_data["has_lantern"]
		jokeCheck = save_data["jokeCheck"]
		foreshadowBool = save_data["foreshadowBool"]
		$Player.hours = save_data["hours"]
		$Player.minutes = save_data["minutes"]
		$Player.seconds = save_data["seconds"]
		$Player.time_start = $Player.time_start - save_data["seconds"]
		$Player.SpeedrunMode = save_data["SpeedrunMode"]
		MusicManager.froggyCrown = save_data["froggyCrown"]
		map_variables = save_data["map_variables"]
		$Player.jumpCount = save_data.get("jumpCount", 0) 
		print("Game loaded.")
