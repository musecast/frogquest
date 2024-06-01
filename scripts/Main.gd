extends Node2D

var npc1 = 0
var npc2 = 0
var npc3 = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$frogNPC1.play("prejump1")




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
			await get_tree().create_timer(0.5).timeout
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
		$frogNPC3/npc3speechbubble.text = "godspeed lil\nfroggy..."
		
	if npc3 == 0:
		npc3 = 3
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.visible = true
		$frogNPC3/npc3speechbubble.text = "the froggy of fate...\ni can't believe it"
		await get_tree().create_timer(3.0).timeout
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.text = "take this with you,\nit will help"
		await get_tree().create_timer(2.0).timeout
		$frogNPC3/npc3itempickup.play()
		$frogNPC3/Lantern.visible = true
		await get_tree().create_timer(2.0).timeout
		$frogNPC3/Lantern.visible = false
		$frogNPC3/npc3talk.play()
		$frogNPC3/npc3speechbubble.text = "godspeed lil\nfroggy..."
		await get_tree().create_timer(3.0).timeout
		$frogNPC3/npc3speechbubble.visible = false
		npc3 = 1
		


func _on_area_2d_3_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
		$frogNPC3/npc3speechbubble.visible = false
