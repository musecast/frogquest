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
var gateDestroyed = 0

## Coming back down past a frog he'd already climbed well above: what they say then, a few each, in turn.
const FELL_LINES := {
	1: ["back so soon..?", "the tree is patient...\nare you?", "falling is just part\nof the climb...",
		"i'd have given up\nby now... heheh"],
	2: ["hehehe... i saw that", "gravity: 1\nfroggy: 0... hehehe", "the petals won't jump\nfor you, young froggy...",
		"now that was a\nleap of failure... hehehe"],
	3: ["even the froggy of fate\nfalls sometimes...", "warm up by the fire,\nthen try again...",
		"the gods are still\nwatching, lil froggy..."],
	4: ["you're lost too..?", "welcome back...\ni'm still lost", "maybe we should stick\ntogether..."],
	5: ["o ho ho ho...\nback again?", "that fall was the real\njoke... hehehehe",
		"o ho ho... the ground\nmissed you, i bet"],
}
const FELL_BY := 25.0  # (in currentHeight, a tenth of a pixel: 250 px above them, since the game started)
## The TV at home, through the static, before he's ever won: why he's going.
const TV_LINES := ["...bzzt...", "...a froggy of fate will\nrise from below...",
	"...and reach the top of\nthe world tree...", "...bzzzzt..."]
const LOST_FROG_TOP := Vector2(2950, -5626)  # (where the lost frog turns up once the gate's open: the castle hall)
const NO_GODS_AT := Vector2(2804, -8160)  # (the middle of the climb's last words: under the plank below the glass)
var _fell_turn := {}
var _tv_bubble: Label
var _tv_done := false
var _lost_frog_up := false
var _lost_frog_thanked := false
var _no_gods: Label

#top of script
@onready var previous_window = DisplayServer.window_get_mode()
@onready var current_window = DisplayServer.window_get_mode()


func _trace(label: String) -> void:
	print("StartupTrace: %s at %d ms" % [label, Time.get_ticks_msec()])


func _supports_desktop_mouse() -> bool:
	var platform := OS.get_name()
	return platform != "iOS" and platform != "Android"


# Called when the node enters the scene tree for the first time.
func _ready():
	_trace("Main ready start")
	
	# Any orientation: portrait on a phone (or a closed iPhone Duo) gets the portrait layouts and camera.
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	print($TileMap.get_layer_name(1))
	Engine.time_scale=1.0

	if $Player.has_key:
		var area = $"World Sprites/Key".get_node_or_null("Area2DKEY")
		if area:
			area.queue_free()
		$Player.setup_key_trail()
	if gateDestroyed == 1:
		$"World Sprites/Key".queue_free()
		$"World Sprites/Keyhole".queue_free()

	# If the player skipped picking up the lantern from npc3, reset npc3 so
	# the lantern offer replays on the next visit — prevents a softlock.
	if npc3 != 0 and not $Player.has_lantern:
		npc3 = 0
	# A conversation cut off by closing the game (saved part way through, 3) starts over, instead of never again.
	for n in ["npc1", "npc2", "npc4", "npc5", "npc6"]:
		if get(n) == 3:
			set(n, 0)
	if npc3 == 3:
		npc3 = 1  # (he has the lantern: that part's done)

	_make_tv_bubble()
	_make_no_gods_line()

	$frogNPC1.play("farmer")

	if MusicManager.MusicPosition != 0:
		$Player/winscreen/goodbyefroggy.play(MusicManager.MusicPosition)
		MusicManager.MusicPosition = 0

	_loop_cave_audio($"Environmental Audio/caveaudio")
	_loop_cave_audio($"Environmental Audio/darktreeAudio")

	load("res://scripts/FlyHunt.gd").spawn_into(self)  # the little flies hiding around the tree (catch them all: the Golden Frog)
	var together: Node2D = load("res://scripts/StoryParty.gd").new()  # (climbing with friends, and everyone online)
	together.name = "StoryParty"
	add_child(together)

	_trace("Main ready end")
	_request_ads_after_first_frames()


func _request_ads_after_first_frames() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return
	AdsManager.show_banner_bottom()
	AdsManager.preload_interstitial()


## What a frog says when he's back past them after a fall (he's been well above them since the game
## started): the next of theirs each time; "" when he hasn't.
func _fell_line(npc: int, frog: Node2D) -> String:
	var frog_height := (-frog.global_position.y - 472.0) / 10.0
	if $Player.highScore == null or float($Player.highScore) < frog_height + FELL_BY:
		return ""
	var lines: Array = FELL_LINES[npc]
	var turn: int = _fell_turn.get(npc, 0)
	_fell_turn[npc] = turn + 1
	return lines[turn % lines.size()]


## Between a frog's lines, while he's out of earshot: they wait (bubble hidden) and go on when he's back, so
## a hop away doesn't lose the rest (the petals' secret, the lantern).
func _while_away(area: Area2D, bubble: Label) -> void:
	if area.overlaps_body($Player):
		return
	bubble.visible = false
	while is_inside_tree() and not area.overlaps_body($Player):
		await get_tree().process_frame
	bubble.visible = true


## The TV's speech bubble: a frog's (same look), over the TV.
func _make_tv_bubble() -> void:
	var frog_bubble: Label = $frogNPC1/npc1speechbubble
	_tv_bubble = frog_bubble.duplicate()
	_tv_bubble.visible = false
	add_child(_tv_bubble)
	_tv_bubble.scale = frog_bubble.get_global_transform().get_scale()
	_tv_bubble.position = $Musecrtquarterview.position + Vector2(-_tv_bubble.pivot_offset.x, -100.0)


## The TV at home, through the static.
func _tv_talk() -> void:
	for line in TV_LINES:
		_tv_bubble.text = line
		_tv_bubble.visible = true
		await get_tree().create_timer(2.8).timeout
		if not is_inside_tree():
			return
	_tv_bubble.visible = false


## The climb's last words, in the finale's own look ("you are the"'s), just under the plank below the glass
## (the top of what the camera shows): they come up once the glass gives.
func _make_no_gods_line() -> void:
	var you_are: Label = $"finale/finale sprites/frog quest2"
	_no_gods = you_are.duplicate()
	_no_gods.text = "no petals. no gods.\njust you..."
	_no_gods.z_index = 5
	_no_gods.size = Vector2(1100.0, 240.0)
	_no_gods.pivot_offset = _no_gods.size / 2.0
	_no_gods.scale = Vector2(0.32, 0.32)
	_no_gods.position = NO_GODS_AT - _no_gods.size / 2.0
	_no_gods.modulate.a = 0.0
	add_child(_no_gods)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# (not while the frog god's still asking what he looks like: once he's woken, in his bedroom)
	if not _tv_done and not MusicManager.game_beaten and not $Player/titlescreen.visible and not $Player.has_node("CreatorIntro") \
			and $Player.global_position.distance_to($Musecrtquarterview.global_position) < 220.0:
		_tv_done = true
		_tv_talk()
	# The lost frog, let out by the gate he opened, turns up by the castle (while he's well away from both).
	if gateDestroyed == 1 and not _lost_frog_up and $Player.currentHeight > 400.0:
		_lost_frog_up = true
		$frogNPC4.position = LOST_FROG_TOP

	#DELETE THIS IN FINAL PRODUCT
	#DELETE THIS IN FINAL PRODUCT
	#DELETE THIS IN FINAL PRODUCT
	#if Input.is_action_pressed("ui_fastforward"):
	#	Engine.time_scale = 8.0
	#else:
	#	Engine.time_scale = 1.0
	#DELETE THIS IN FINAL PRODUCT
	#DELETE THIS IN FINAL PRODUCT
	#DELETE THIS IN FINAL PRODUCT
	
	
	if Input.is_action_just_pressed("pause") and $Player/Trajectory.endGame == 0:
		if $Player._active_wardrobe and is_instance_valid($Player._active_wardrobe):
			$Player._active_wardrobe.closed.emit()
			return
		var settings: Node = $Player.get_node_or_null("SettingsScreen")
		if settings:
			settings.closed.emit()  # (back to the pause menu, or the title)
			return
		if Engine.time_scale != 1.0:
			#GAME IS UNPAUSED HERE

			$Player/PauseScreen.visible=false
			Engine.time_scale = 1.0
		else:
			#GAME IS PAUSED HERE
			if _supports_desktop_mouse():
				Input.mouse_mode = 0
			$Player/PauseScreen.visible=true
			$Player/frogaim.play()
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
	
	var area: Area2D = $frogNPC1/Area2D
	var bubble: Label = $frogNPC1/npc1speechbubble
	if npc1 == 1:
		$frogNPC1/npc1talk.play()
		bubble.visible = true
		var fell := _fell_line(1, $frogNPC1)
		bubble.text = fell if fell != "" else "keep it up \nlil froggy..."
	if npc1 == 0:
		npc1 = 3
		print("npc croak")
		$frogNPC1/npc1talk.play()
		bubble.visible = true
		bubble.text = "so... you came \nfrom below?"
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC1/npc1talk.play()
		bubble.text = "maybe you'll be the \none to reach the top..."
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC1/npc1talk.play()
		bubble.text = "by the way, have you \nnoticed the white petals?"
		await get_tree().create_timer(4.0).timeout
		await _while_away(area, bubble)
		$frogNPC1/npc1talk.play()
		bubble.text = "some say they are \nsigns of the gods"
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC1/npc1talk.play()
		bubble.text = "signs to jump as \nhard as you can"
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC1/npc1talk.play()
		bubble.text = "whether you believe \nthat, is up to you"
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC1/npc1talk.play()
		bubble.text = "never had the courage \nfor a leap of faith myself"
		await get_tree().create_timer(4.0).timeout
		await _while_away(area, bubble)
		$frogNPC1/npc1talk.play()
		bubble.text = "keep it up \nlil froggy..."
		await get_tree().create_timer(3.0).timeout
		$frogNPC1/npc1speechbubble.visible = false
		npc1 = 1
		


func _on_area_2d_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
	if npc1 == 1:
		$frogNPC1/npc1speechbubble.visible = false


func _on_area_2d_2_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	
		var area: Area2D = $frogNPC2/Area2D2
		var bubble: Label = $frogNPC2/npc2speechbubble
		if npc2 == 1:
			$frogNPC2/npc2talk.play()
			bubble.visible = true
			var fell := _fell_line(2, $frogNPC2)
			if fell != "":
				bubble.text = fell
				await get_tree().create_timer(2.5).timeout
				if npc2 != 1 or not area.overlaps_body($Player):
					return
				$frogNPC2/npc2talk.play()
			bubble.text = "don't forget to jump full \npower if you see the petals..."

		if npc2 == 0:
			npc2 = 3
			print("npc croak")
			$frogNPC2/npc2talk.play()
			bubble.visible = true
			bubble.text = "hehehe... good job \non the leap of faith"
			await get_tree().create_timer(3.0).timeout
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "how about \na joke..?"
			await get_tree().create_timer(3.0).timeout
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "what's a frog's \nfavorite year?"
			await get_tree().create_timer(3.0).timeout
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "leap year \nheheheheheh"
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
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "thank you for listening \nto my joke young froggy"
			await get_tree().create_timer(3.0).timeout
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "now i shall give you wisdom \nhanded to me from the gods..."
			await get_tree().create_timer(5.0).timeout
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "the white petals indicate \nguaranteed safety for a jump..."
			await get_tree().create_timer(5.0).timeout
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "...but only if you take that \njump at your full strength."
			await get_tree().create_timer(5.0).timeout
			await _while_away(area, bubble)
			$frogNPC2/npc2talk.play()
			bubble.text = "now hop along young froggy \nand let the petals guide you..."
			await get_tree().create_timer(4.0).timeout
			$frogNPC2/npc2speechbubble.visible = false
			npc2 = 1
			jokeCheck = 1


func _on_area_2d_2_body_shape_exited(_body_rid, body, _body_shape_index, local_shape_index):
	if npc2 == 1:
		$frogNPC2/npc2speechbubble.visible = false


func _on_area_2d_3_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):

	var area: Area2D = $frogNPC3/Area2D3
	var bubble: Label = $frogNPC3/npc3speechbubble
	if npc3 == 1:
		$frogNPC3/npc3talk.play()
		bubble.visible = true
		var fell := _fell_line(3, $frogNPC3)
		bubble.text = fell if fell != "" else "may the gods protect \nyou on your ascent..."
		await get_tree().create_timer(2.5 if fell != "" else 2.0).timeout
		$frogNPC3/npc3talk.play()
		bubble.text = "godspeed \nlil froggy..."

	if npc3 == 0:
		npc3 = 3
		$frogNPC3/npc3talk.play()
		bubble.visible = true
		bubble.text = "the froggy of fate...\ni can't believe it"
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC3/npc3talk.play()
		bubble.text = "take this with you,\nit will help"
		await get_tree().create_timer(2.0).timeout
		$frogNPC3/lanternhitbox.visible = true
		$frogNPC3/lanternhitbox.position = Vector2(0,0)
		$frogNPC3/npc3itemspawn.play()
		await get_tree().create_timer(2.0).timeout
		await _while_away(area, bubble)
		$frogNPC3/npc3talk.play()
		bubble.text = "with this lantern, \ndarkness fears you..."
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC3/npc3talk.play()
		bubble.text = "it shall light your \nway automatically"
		await get_tree().create_timer(3.0).timeout
		await _while_away(area, bubble)
		$frogNPC3/npc3talk.play()
		bubble.text = "godspeed lil\nfroggy..."
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
	var bubble: Label = $frogNPC4/npc4speechbubble
	if _lost_frog_up:  # (out of the dark at last, by the castle)
		$frogNPC4/npc4talk.play()
		bubble.visible = true
		if _lost_frog_thanked:
			bubble.text = "go on...\nthey're waiting for you"
			return
		_lost_frog_thanked = true
		bubble.text = "i followed your jumps..."
		await get_tree().create_timer(3.0).timeout
		$frogNPC4/npc4talk.play()
		bubble.text = "thank you for showing\nme the way out..."
		await get_tree().create_timer(3.5).timeout
		$frogNPC4/npc4talk.play()
		bubble.text = "go on...\nthey're waiting for you"
		await get_tree().create_timer(3.0).timeout
		bubble.visible = false
		return

	if npc4 == 1:
		$frogNPC4/npc4talk.play()
		bubble.visible = true
		var fell := _fell_line(4, $frogNPC4)
		if $Player.has_key:
			bubble.text = "you found the key...!\nmaybe there's a way out"
		elif gateDestroyed == 1:
			bubble.text = "was that the gate..?\ni'll follow your jumps"
		elif fell != "":
			bubble.text = fell
		else:
			bubble.text = "hello again..."

	if npc4 == 0:
		npc4 = 3
		$frogNPC4/npc4talk.play()
		bubble.visible = true
		bubble.text = "oh hello"
		await get_tree().create_timer(3.0).timeout
		$frogNPC4/npc4talk.play()
		bubble.text = "i'm lost..."
		await get_tree().create_timer(3.0).timeout
		if $Player.has_key:
			$frogNPC4/npc4talk.play()
			bubble.text = "is that a key..?\nyou could get out of here"
			await get_tree().create_timer(3.5).timeout
		elif gateDestroyed == 0:
			$frogNPC4/npc4talk.play()
			bubble.text = "they say there's a key\nsomewhere in the dark..."
			await get_tree().create_timer(3.5).timeout
		bubble.visible = false
		npc4 = 1


func _on_area_2d_4_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if npc4 == 1 or _lost_frog_up:
		$frogNPC4/npc4speechbubble.visible = false


func _on_area_2dkey_body_shape_entered(body_rid, body, body_shape_index, local_shape_index):
	$"World Sprites/Key/Area2DKEY".queue_free()
	$Player.has_key = true
	$"World Sprites/Key/keypickup".play()
	$Player.setup_key_trail()



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
		create_tween().tween_property(_no_gods, "modulate:a", 1.0, 2.5)


func _on_area_2d_5_body_shape_entered(_body_rid, body, _body_shape_index, local_shape_index):
	
		var area: Area2D = $frogNPC5/Area2D5
		var bubble: Label = $frogNPC5/npc5speechbubble
		if npc5 == 1:
			$frogNPC5/npc5talk.play()
			bubble.visible = true
			var fell := _fell_line(5, $frogNPC5)
			if fell != "":
				bubble.text = fell
				await get_tree().create_timer(2.5).timeout
				if npc5 != 1 or not area.overlaps_body($Player):
					return
				$frogNPC5/npc5talk.play()
			bubble.text = "the way forward is a\nleap of faith to your right..."

		if npc5 == 0:
			npc5 = 3
			print("npc croak")
			$frogNPC5/npc5talk.play()
			bubble.visible = true
			if jokeCheck == 1:
				bubble.text = "o ho ho ho so you\nwant another joke, do you?"
			else:
				bubble.text = "o ho ho ho you must be\nhere for a good joke, yes?"
			await get_tree().create_timer(5.0).timeout
			await _while_away(area, bubble)
			$frogNPC5/npc5talk.play()
			bubble.text = "why are frogs\nso happy..?"
			await get_tree().create_timer(3.0).timeout
			await _while_away(area, bubble)
			$frogNPC5/npc5talk.play()
			bubble.text = "...because they eat\nwhatever bugs them"
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
			await _while_away(area, bubble)
			$frogNPC5/npc5talk.play()
			bubble.text = "hehehehe...\nnow let me help you"
			await get_tree().create_timer(3.0).timeout
			await _while_away(area, bubble)
			$frogNPC5/npc5talk.play()
			bubble.text = "the way forward is a\nleap of faith to your right..."
			await get_tree().create_timer(5.0).timeout
			if jokeCheck == 1:
				await _while_away(area, bubble)
				$frogNPC5/npc5talk.play()
				bubble.text = "although you probably \nknew that already heheh..."
				await get_tree().create_timer(4.0).timeout
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
			$frogNPC6/npc6speechbubble.text = "as you can see, these\npetals have fallen..."
			await get_tree().create_timer(4.0).timeout
			$frogNPC6/npc6talk.play()
			$frogNPC6/npc6speechbubble.text = "there is no god to guide you,\nyou must succeed on your own..."
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







func _loop_cave_audio(player: AudioStreamPlayer2D) -> void:
	var length: float = player.stream.get_length()
	if length <= 0.0:
		return
	const XFADE: float = 3.0
	var delay: float = max(0.0, length - player.get_playback_position() - XFADE)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(player) or not player.playing:
		return
	var p2 := AudioStreamPlayer2D.new()
	p2.stream = player.stream
	p2.volume_db = -80.0
	p2.max_distance = player.max_distance
	p2.bus = player.bus
	p2.position = player.position
	player.get_parent().add_child(p2)
	p2.play()
	var target_vol: float = player.volume_db
	var t := create_tween().set_parallel(true)
	t.tween_property(player, "volume_db", -80.0, XFADE)
	t.tween_property(p2, "volume_db", target_vol, XFADE)
	await t.finished
	player.stop()
	player.queue_free()
	_loop_cave_audio(p2)


func _on_castleaudiocue_body_entered(body):
	if foreshadowBool == 0:
		$"Environmental Audio/castleaudiocue/froggodglimpse".play()
		foreshadowBool = 1
