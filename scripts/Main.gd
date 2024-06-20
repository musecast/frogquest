extends Node2D

var npc1 = 0
var npc2 = 0
var npc3 = 0
var npc4 = 0

#top of script
@onready var previous_window = DisplayServer.window_get_mode()
@onready var current_window = DisplayServer.window_get_mode()


# Called when the node enters the scene tree for the first time.
func _ready():
	print($TileMap.get_layer_name(1))
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$frogNPC1.play("prejump1")
	if Input.is_action_just_pressed("pause"):
		if Engine.time_scale != 1.0:
			#GAME IS UNPAUSED HERE
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
		if current_window != 4:
			previous_window = current_window
			DisplayServer.window_set_mode(4)
		else:
			if previous_window == 4:
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
		$frogNPC1/npc1speechbubble.text = "maybe you'll be the \none to reach the top"
		await get_tree().create_timer(3.0).timeout
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
			$frogNPC2/npc2speechbubble.text = "heheheheheh\nhehehehe"
			
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
			$frogNPC2.play("laughing")
			await get_tree().create_timer(0.5).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.49).timeout
			$frogNPC2/npc2talk.play()
			await get_tree().create_timer(0.5).timeout
			$frogNPC2.play("default")
			await get_tree().create_timer(0.3).timeout
			$frogNPC2/npc2speechbubble.visible = false
			npc2 = 1


func _on_area_2d_2_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
	if npc2 == 1:
		$frogNPC2/npc2speechbubble.visible = false


func _on_area_2d_3_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):

	if npc3 == 1:
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.visible = true
		$frogNPC3/npc3speechbubble.text = "press 'f' to\nuse the lantern"
		
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
		$frogNPC3/npc3speechbubble.text = "press 'f' to\nuse the lantern"
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
	$"finale/Control/froggod".play()

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
