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
const WAKE_DOZE := 2.0  # (seconds he's seen asleep before the TV comes on by itself)
const TV_TYPE_SPEED := 12.0  # (the TV's words, letters a second)
signal _tv_next  # (a tap, once the TV's line is all there)
const LOST_FROG_TOP := Vector2(2950, -5626)  # (where the lost frog turns up once the gate's open: the castle hall)
const NO_GODS_AT := Vector2(2804, -8160)  # (the middle of the climb's last words: under the plank below the glass)
var _fell_turn := {}
var _tv_bubble: Label
var _tv_over := 0.0  # (the middle of the TV, across: its words go over it, unless that's off the screen)
var _tv_done := false
var _tv_db := 0.0  # (the TV's static, as the level has it)
var _tv_typed := 0.0
var _tv_typing := false
var _tv_listening := false  # (its words wait for a tap: wake_up)
var _tv_more: Control  # (MoreArrow, under its words once they're all there)
var _tv_glass: CanvasItem  # (its screen off: dark glass)
var _tv_flash: CanvasItem  # (coming on: a line of light, opening up)
var _tv_voice: AudioStreamPlayer
var _tv_crackle: AudioStreamPlayer
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
	_catch_up_gifts()

	_make_tv_bubble()
	_make_no_gods_line()
	var titles: CanvasLayer = load("res://scripts/AreaTitle.gd").new()  # (where he is, named as he gets there)
	titles.player = $Player
	add_child(titles)
	_frog_gods()

	$frogNPC1.play("farmer")

	if MusicManager.MusicPosition != 0:
		$Player/winscreen/goodbyefroggy.play(MusicManager.MusicPosition)
		MusicManager.MusicPosition = 0

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
## The frogs' gifts (and the key's, and the gate's) for what a save from before they gave them had
## already done: his, quietly (the wardrobe shows them new).
func _catch_up_gifts() -> void:
	var earned := {"leaf": npc1 == 1, "bow": npc2 == 1, "flower": npc3 == 1 and $Player.has_lantern,
		"pattern_spots": $Player.has_key or gateDestroyed == 1, "pattern_stripes": gateDestroyed == 1,
		"pattern_twotone": npc5 == 1, "pattern_stars": npc6 == 1}
	var any := false
	for id in earned:
		if earned[id] and not id in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append(id)
			any = true
	if any:
		MusicManager.save_wardrobe()


func _make_tv_bubble() -> void:
	var frog_bubble: Label = $frogNPC1/npc1speechbubble
	_tv_bubble = frog_bubble.duplicate()
	_tv_bubble.visible = false
	add_child(_tv_bubble)
	_tv_bubble.scale = frog_bubble.get_global_transform().get_scale()
	_tv_bubble.size.x = 400.0  # (wider than any of its lines: each is centred in it)
	_tv_bubble.pivot_offset.x = 200.0
	_tv_over = $Musecrtquarterview.position.x
	_tv_bubble.position = Vector2(_tv_over - _tv_bubble.pivot_offset.x, $Musecrtquarterview.position.y - 100.0)
	_tv_bubble.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # (typed out in place)
	_tv_more = load("res://scripts/MoreArrow.gd").new()
	_tv_more.z_index = _tv_bubble.z_index
	add_child(_tv_more)
	_tv_voice = _tv_sound_player("res://assets/tv_voice.wav", -20.0)
	_tv_crackle = _tv_sound_player("res://assets/tv_crackle.wav", -18.0)
	_tv_db = $Musecrtquarterview/AudioStreamPlayer2D.volume_db
	# (its screen, off and coming on: over the static, under the TV's frame, as the static is)
	var screen: ColorRect = $Musecrtquarterview/ColorRect
	var glass := TextureRect.new()
	var shine := GradientTexture2D.new()
	shine.fill = GradientTexture2D.FILL_RADIAL
	shine.fill_from = Vector2(0.42, 0.38)
	shine.fill_to = Vector2(1.05, 1.0)
	shine.gradient = Gradient.new()
	shine.gradient.set_color(0, Color(0.22, 0.23, 0.28))
	shine.gradient.set_color(1, Color(0.09, 0.09, 0.12))
	glass.texture = shine
	glass.stretch_mode = TextureRect.STRETCH_SCALE
	glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var flash := ColorRect.new()
	flash.color = Color(0.92, 0.95, 1.0)
	for each in [glass, flash]:
		each.z_index = screen.z_index
		each.mouse_filter = Control.MOUSE_FILTER_IGNORE
		each.visible = false
		$Musecrtquarterview.add_child(each)
		each.position = screen.position
		each.size = screen.size
		each.pivot_offset = screen.size * 0.5
	_tv_glass = glass
	_tv_flash = flash


func _tv_sound_player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = &"FX"
	p.volume_db = db
	add_child(p)
	return p


## The TV's words over it, but kept on the screen, clear of a closed iPhone Duo's camera strip or a notch
## (UIStyle.room): upright, a phone shows less of the room either side of it, and they'd run off the edge.
func _keep_tv_words_in_view() -> void:
	var vp := get_viewport()
	var to_world := vp.get_canvas_transform().affine_inverse()
	var seen: Rect2 = to_world * load("res://scripts/UIStyle.gd").room(vp.get_visible_rect().size)
	var rim := float(_tv_bubble.get_theme_constant("outline_size") + 4)  # (its outline, and a little room)
	var half := (_tv_bubble.get_minimum_size().x * 0.5 + rim) * _tv_bubble.scale.x
	var mid := _tv_over
	if seen.size.x > half * 2.0 and _tv_over > seen.position.x and _tv_over < seen.end.x:  # (the TV's on the screen)
		mid = clampf(mid, seen.position.x + half, seen.end.x - half)
	_tv_bubble.position.x = mid - _tv_bubble.pivot_offset.x


## A new climb from his bedroom (player._on_button_pressed): he's asleep in his beanbag, the TV off. It
## comes on by itself (a thunk, a line of light opening up, its static swelling in), he wakes, and it
## speaks, crackling in the frog god's voice: each of its lines stays till a tap (the arrow under it says
## so). Then the tutorial comes up, and off he goes. from_dark: the game's fading in from the frog god's
## black (CreatorIntro), so he's asleep all through that, and a little while after.
func wake_up(from_dark: bool) -> void:
	if _tv_done:
		return
	_tv_done = true
	var player := $Player
	player.waking = true
	player.set_asleep(true)
	_tv_power(false)
	_tutorials(false)
	var intro: GDScript = load("res://scenes/CreatorIntro.gd")
	if not await _wait((intro.HOLD + intro.FADE if from_dark else 0.5) + WAKE_DOZE):
		return
	_tv_power(true)
	if not await _wait(1.1):
		return
	player.wake()
	if not await _wait(0.9):
		return
	_tv_listening = true
	for line in TV_LINES:
		_tv_say(line)
		await _tv_next
		if not is_inside_tree():
			return
	_tv_listening = false
	_tv_bubble.visible = false
	_tutorials(true)
	player.waking = false


## The frog god's glimpses up the climb (FROG KING2 on: a shadow of him come as he passes each): once one's
## there, a plain shadow, it slowly turns (each in its own time) into the frog god as the intro shows him
## (CreatorIntro): dark, a violet rim breathing round him, his eyes glowing.
func _frog_gods() -> void:
	var looks: GDScript = load("res://scripts/FroggyLook.gd")
	for god in $"finale/Control".get_children():
		if god is Sprite2D and str(god.name).begins_with("FROG KING"):
			var mat: ShaderMaterial = looks.material({}, "")
			mat.set_shader_parameter("shadow_amount", 0.0)  # (a plain shadow to start: as it always was)
			god.material = mat
			god.visibility_changed.connect(_godlike.bind(god))


func _godlike(god: Sprite2D) -> void:
	if not god.visible or god.has_meta("godlike"):
		return
	god.set_meta("godlike", true)
	var shade := god.self_modulate
	var slow := randf_range(4.0, 6.0)
	var turn := god.create_tween()
	turn.tween_interval(randf_range(0.8, 2.2))
	# (him first, while it's still dark: then his violet rim and his eyes come up out of the black)
	turn.tween_property(god.material, "shader_parameter/shadow_amount", 1.0, slow * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	turn.parallel().tween_property(god, "self_modulate", Color(1.0, 1.0, 1.0, maxf(shade.a, 0.92)), slow) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _wait(seconds: float) -> bool:
	await get_tree().create_timer(seconds).timeout
	return is_inside_tree()


## One of the TV's lines, typed out over it (_process: its sounds as it goes, the arrow when it's all there).
func _tv_say(line: String) -> void:
	_tv_bubble.text = line
	_tv_bubble.visible_characters = 0
	_tv_bubble.visible = true
	_tv_typed = 0.0
	_tv_typing = true


## A tap while the TV speaks: all of its line at once, or (once it's all there) the next.
func _tv_tap() -> void:
	if not _tv_listening:
		return
	if _tv_typing:
		_tv_typed = float(_tv_bubble.text.length())
		_tv_bubble.visible_characters = -1
		_tv_typing = false
		return
	_tv_next.emit()


## A tap anywhere while the TV's talking (seen before the screen's full-screen CRT and scanline layers
## take it), but on the pause button, or while the game's paused.
func _tv_input(event: InputEvent) -> void:
	if not _tv_listening or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if Engine.time_scale < 0.5:
		return
	var pause := get_node_or_null("Player/CanvasLayer/TouchScreenButtonPause/ColorRect") as Control
	if pause != null and pause.is_visible_in_tree() and pause.get_global_rect().grow(12.0).has_point(event.position):
		return
	get_viewport().set_input_as_handled()
	_tv_tap()


## The TV off (its screen dark glass, no static) or coming on: a thunk, a line of light opening up into
## the static, its hiss swelling in.
func _tv_power(on: bool) -> void:
	var hiss: AudioStreamPlayer2D = $Musecrtquarterview/AudioStreamPlayer2D
	if not on:
		_tv_glass.visible = true
		_tv_glass.modulate.a = 1.0
		_tv_flash.visible = false
		hiss.stop()
		return
	var thunk := _tv_sound_player("res://assets/tv_on.wav", -8.0)
	thunk.play()
	thunk.finished.connect(thunk.queue_free)
	_tv_flash.visible = true
	_tv_flash.modulate.a = 1.0
	_tv_flash.scale = Vector2(0.2, 0.03)
	var light := create_tween()  # (a dot of light, a line across, the line opening up into the picture)
	light.tween_interval(0.05)
	light.tween_property(_tv_flash, "scale:x", 0.97, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	light.tween_property(_tv_flash, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	light.parallel().tween_property(_tv_glass, "modulate:a", 0.0, 0.3)
	light.tween_property(_tv_flash, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	light.tween_callback(func() -> void:
		_tv_flash.visible = false
		_tv_glass.visible = false)
	hiss.volume_db = _tv_db - 24.0
	hiss.play()
	create_tween().tween_property(hiss, "volume_db", _tv_db, 1.2).set_ease(Tween.EASE_OUT)


## The tutorial's words round the start (how to jump, to pause, that it saves): hidden, or come up softly.
func _tutorials(on: bool) -> void:
	for each in ["tutorial", "tutorial2", "tutorial3", "tutorial4"]:
		var words: CanvasItem = get_node("World Sprites/" + each)
		words.visible = on
		if on:
			words.modulate.a = 0.0
			words.create_tween().tween_property(words, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT)


## The arrow under the TV's words: in the middle of them, a little under their last line.
func _place_tv_more() -> void:
	var lines := _tv_bubble.text.count("\n") + 1
	var pivot := _tv_bubble.pivot_offset
	var bottom := _tv_bubble.position.y + pivot.y + (lines * _tv_bubble.get_line_height() - pivot.y) * _tv_bubble.scale.y
	_tv_more.pixel = 2.0
	_tv_more.position = Vector2(_tv_bubble.position.x + pivot.x - _tv_more.size.x * 0.5, bottom + 4.0).round()


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
	if _tv_typing:  # (the TV's line, typed out: its crackling voice every other letter, "bzzt" its static)
		var total := _tv_bubble.text.length()
		var before := int(_tv_typed)
		_tv_typed = minf(float(total), _tv_typed + delta * TV_TYPE_SPEED)
		_tv_bubble.visible_characters = int(_tv_typed)
		var ch := _tv_bubble.text.substr(int(_tv_typed) - 1, 1)
		if int(_tv_typed) / 2 != before / 2 and not ch in [" ", "\n", "."]:
			var sound := _tv_crackle if _tv_bubble.text.contains("bzz") else _tv_voice
			sound.pitch_scale = randf_range(0.9, 1.06)
			sound.play()
		if _tv_typed >= total:
			_tv_typing = false
	_tv_more.shown = _tv_listening and _tv_bubble.visible and not _tv_typing
	if _tv_bubble.visible:
		_keep_tv_words_in_view()
		_place_tv_more()
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
	_tv_input(event)
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
		MusicManager.unlock("leaf")  # (his gift: the Leaf hat)
		


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
			MusicManager.unlock("bow")  # (for listening to his joke: the Bow)


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
		MusicManager.unlock("flower")  # (with the lantern, a flower: the Flower hat)
		


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
		MusicManager.unlock("pattern_hearts")  # (his thanks: the Hearts pattern)
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
	MusicManager.unlock("pattern_spots")  # (the key found: the Spots pattern)
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
			MusicManager.unlock("pattern_twotone")  # (his second joke heard: the Two-Tone pattern)


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
			MusicManager.unlock("pattern_stars")  # (the frog at the castle door: the Stars pattern)
			#$frogNPC6.queue_free()


func _on_area_2d_6_body_shape_exited(body_rid, body, body_shape_index, local_shape_index):
	if npc6 == 1:
		$frogNPC6/npc6speechbubble.visible = false







func _on_castleaudiocue_body_entered(body):
	if foreshadowBool == 0:
		$"Environmental Audio/castleaudiocue/froggodglimpse".play()
		foreshadowBool = 1
