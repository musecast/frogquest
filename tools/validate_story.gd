extends SceneTree
## The story's talk and its ending (Main.gd, player.gd), in the real level: the TV at home (and not once
## he's won); a frog's lines for coming back down after a fall, in turn; a frog waiting while he's out of
## earshot and going on when he's back; a conversation cut off by closing the game starting over; the lost
## frog's hint, and them turning up by the castle once the gate's open; the last words coming up as the
## glass gives; the ending's camera coming to rest on his bedroom, framed as he wakes up there; and the win
## screen's words fitting across a phone held upright. Scratch save and wardrobe; yours are byte-checked by
## the caller.
##   Godot --headless --path . --script res://tools/validate_story.gd

const SAVE := "user://test_story_save_game.save"
const WARDROBE := "user://test_story_wardrobe.save"
const PORTRAIT := Vector2(480, 1039)

var _failures: Array[String] = []
var _view: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		_failures.append("timed out")
		_finish())
	var mm := root.get_node("MusicManager")
	var real_wardrobe: String = mm.wardrobe_path
	var real_beaten: bool = mm.game_beaten
	var real_made: bool = mm.look_made
	mm.wardrobe_path = WARDROBE
	mm.game_beaten = false
	mm.look_made = true  # (he's made his froggy already: Play starts the climb, no intro)
	_view = SubViewport.new()
	_view.size = Vector2i(PORTRAIT)
	root.add_child(_view)

	# A save with two conversations cut off part way (3): they start over, the campfire's is done (lantern).
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_var({"position": Vector2(1291.1925, 262.79996), "has_lantern": true, "npc1": 3, "npc3": 3, "npc5": 3})
	file.close()
	var main := await _game()
	var player: CharacterBody2D = main.get_node("Player")
	_expect(main.npc1 == 0 and main.npc5 == 0, "a conversation cut off by closing the game starts over (%s, %s)" % [main.npc1, main.npc5])
	_expect(main.npc3 == 1, "the campfire frog's is done once he has the lantern (%s)" % main.npc3)
	_expect(not main.way_open and main.get_node_or_null("finale/finale walls/hidethis/delete") != null,
		"the way up to the top of the tree shut, till the frog at the castle door opens it")

	# Home: he wakes up there. Asleep in his beanbag, the TV off (a press is no jump yet); it comes on by
	# itself and he wakes; it speaks, a line a tap (the arrow under it once it's all there, on the screen
	# upright); then the tutorial comes up, and he can jump.
	var hiss: AudioStreamPlayer2D = main.get_node("Musecrtquarterview/AudioStreamPlayer2D")
	var aim: Node2D = player.get_node("Trajectory")
	var how_to: CanvasItem = main.get_node("World Sprites/tutorial")
	var eyes: ShaderMaterial = player.get_node("Sprite2D").material
	player._on_button_pressed()
	for _i in 3:
		await process_frame
	var record: CanvasItem = main.get_node("Musecrtquarterview/Record")
	var screen: ColorRect = main.get_node("Musecrtquarterview/ColorRect")
	_expect(main._tv_done and player.waking and player.asleep and not hiss.playing and main._tv_song.playing and record.visible
		and screen.material != main._tv_static_look and not main._tv_bubble.visible and not how_to.visible and player._zzz != null,
		"starting at home, he's asleep in his beanbag (z's drifting up), fallen asleep to the TV's show (the record, the song from the end), no tutorial yet")
	_expect(eyes.get_shader_parameter("eyes_shut") == true, "his eyes shut")
	Input.action_press("ui_mouse")
	await process_frame
	await process_frame
	_expect(aim.mouseOrigin == Vector2.ZERO, "a press is no jump while he's waking")
	Input.action_release("ui_mouse")
	await process_frame
	await _game_time(2.6)
	_expect(player._zzz != null and player._zzz.breaths >= 1 and player._zzz._breath.stream.resource_path.ends_with("sleep_breath.wav"),
		"asleep, he breathes: a little snore in, a little whistle out")
	_expect(hiss.playing and player.asleep and not record.visible and screen.material == main._tv_static_look,
		"the frog god takes the TV over: its static, the record gone (he's still asleep)")
	await _game_time(0.8)
	_expect(not main._tv_song.playing, "and the song's died under it")
	await _game_time(1.3)
	_expect(not player.asleep and player.waking and eyes.get_shader_parameter("eyes_shut") == false, "and he wakes")
	await _game_time(1.0)
	_expect(main._tv_bubble.visible and main._tv_bubble.text == main.TV_LINES[0], "the TV speaks")
	await _game_time(4.0)
	_expect(main._tv_bubble.text == main.TV_LINES[0] and not main._tv_typing and main._tv_typed >= main.TV_LINES[0].length(),
		"all of its line, and it stays: no going on without a tap")
	_expect(main._tv_more.shown and main._tv_more.modulate.a > 0.5 and main._tv_more.visible, "the arrow under it, for a tap")
	_expect(main._tv_bubble.get_script() == null and main._tv_bubble.rotation == 0.0
		and main._tv_ghosts.size() == 2 and main._tv_ghosts.all(func(g: Label) -> bool: return g.visible and g.text == main._tv_bubble.text),
		"its words staticky, not rocking as the frogs' do: their red and cyan ghosts with them")
	_expect(_tv_words_seen(main), "its words on the screen (upright)")
	root.get_node("AdsManager").test_safe_insets = Vector4(0.0, 0.0, PORTRAIT.x * 0.18, 0.0)  # (a closed iPhone Duo: its strip)
	var pause: Control = player.get_node("CanvasLayer/TouchScreenButtonPause/ColorRect")
	_tap_screen(pause.get_global_rect().get_center())
	await process_frame
	_expect(main._tv_bubble.text == main.TV_LINES[0], "a tap on the pause button isn't one for the TV")
	for line in range(1, main.TV_LINES.size()):
		_tap_screen(Vector2(_view.size) * Vector2(0.5, 0.62))  # (a finger on the screen, as it comes: over its CRT layers)
		_expect(main._tv_bubble.text == main.TV_LINES[line] and main._tv_typing, "a tap: its next line, typed out (%s)" % main._tv_bubble.text.c_escape())
		await process_frame
		await process_frame  # (a whole frame: the arrow's put away as it's typed)
		_expect(not main._tv_more.shown, "the arrow gone while it comes (%s: typing %s, %.1f of %d)" % [main._tv_bubble.text.c_escape(),
			main._tv_typing, main._tv_typed, main._tv_bubble.text.length()])
		main._tv_tap()  # (all of it at once)
		await process_frame
		await process_frame
		_expect(_tv_words_seen(main), "all of them on the screen, not off its edge: %s" % main._tv_bubble.text.c_escape())
		_expect(player.waking and not how_to.visible, "still waking up: no tutorial, no jumping")
	# (upright on a closed Duo the TV's by the strip: the camera leans toward it till its words sit right over
	# it, as the frogs' words do over them, so they're plainly the TV's; he stays well on the screen)
	var cam: Camera2D = player.get_node("Camera2D")
	await _game_time(3.0)
	var words: Label = main._tv_bubble
	var words_mid := (words.get_global_transform() * Vector2(words.size.x * 0.5, 0.0)).x
	var seen: Rect2 = _view.get_canvas_transform().affine_inverse() * load("res://scripts/UIStyle.gd").room(_view.get_visible_rect().size)
	_expect(cam.offset.x > 1.0 and absf(words_mid - main._tv_over) < 1.5 and _tv_words_seen(main),
		"upright on a closed Duo, the camera leans toward the TV, its words right over it (theirs at %.1f, the TV at %.1f, leaning %.1f)"
		% [words_mid, main._tv_over, cam.offset.x])
	_expect(player.global_position.x - seen.position.x >= main.TV_LEAN_ROOM - 1.0, "and he's well on the screen (%.1f from its edge)"
		% (player.global_position.x - seen.position.x))
	_expect(main._tv_god.visible and main._tv_god.modulate.a > 0.1 and main._tv_god.modulate.a <= main.TV_GOD_SHOWS,
		"the frog god faint in its static as it speaks (%.2f)" % main._tv_god.modulate.a)
	_tap_screen(Vector2(_view.size) * Vector2(0.5, 0.62))
	await process_frame
	root.get_node("AdsManager").test_safe_insets = Vector4(-1.0, -1.0, -1.0, -1.0)
	_expect(not main._tv_bubble.visible and not player.waking and how_to.visible, "its last line tapped: the tutorial comes up, and he's off")
	Input.action_press("ui_mouse")
	await process_frame
	await process_frame
	_expect(aim.mouseOrigin != Vector2.ZERO, "and a press is the start of a jump now")
	Input.action_release("ui_mouse")
	await process_frame
	await _game_time(1.0)
	player.jumpCount = 0

	# Left alone, standing still, he nods off (his eyes shut, z's drifting up); a touch and he's awake. And
	# landing after a long fall: a "!" over him (not after a hop).
	await _game_time(player.SLEEPY * 0.5)
	_expect(not player.asleep, "not asleep after a little while")
	_expect(cam.offset.x == 0.0 and not main._tv_leaning, "the TV done, the camera's back on him (%.2f)" % cam.offset.x)
	_expect(not main._tv_god.visible and hiss.playing and screen.material == main._tv_static_look and not record.visible,
		"and the frog god's faded back into its static, which stays: till he's won")
	await _game_time(player.SLEEPY * 0.5 + 1.5)
	_expect(player.asleep and player._napping and player._zzz != null and eyes.get_shader_parameter("eyes_shut") == true,
		"left alone a while, standing still, he nods off")
	Input.action_press("ui_mouse")
	for _i in 3:
		await physics_frame
	_expect(not player.asleep and not player._napping and eyes.get_shader_parameter("eyes_shut") == false, "a touch and he's awake")
	Input.action_release("ui_mouse")
	await _game_time(1.0)
	player.jumpCount = 0
	await _game_time(2.5)  # (the "!" from waking up long gone)
	player.was_airborne = true
	player._fall_top = player.currentHeight + 5.0
	await _physics(2)
	_expect(_marks(player).is_empty() and player.stunned <= 0.0, "a hop: no \"!\" when he lands, and on he goes")
	player.was_airborne = true
	player._fall_top = player.currentHeight + player.LONG_FALL + 5.0
	await _physics(2)
	var mark: Array = _marks(player)
	_expect(mark.size() == 1 and mark[0].top_level and (mark[0].get_child(0) as Label).get_theme_color("font_color").r > 0.9
		and (mark[0].get_child(0) as Label).get_theme_color("font_color").g < 0.4,
		"landing after a long fall: a red \"!\" over him (its own: nothing of his stretches it)")
	_expect(_playing(player, "land_hard.wav"), "and a thud")
	_expect(_dust_flying(main) >= 1, "dust shooting out from under him")
	_expect(player.stunned > 0.3 and not player.can_act(), "and he's stuck there a moment, shivering")
	Input.action_press("ui_mouse")
	await process_frame
	await process_frame
	_expect(aim.mouseOrigin == Vector2.ZERO, "(no jumping while he shivers)")
	Input.action_release("ui_mouse")
	await _game_time(1.2)
	_expect(player.stunned <= 0.0 and player.can_act() and player.get_node("Sprite2D").position.x == 0.0, "then he's shaken it off")
	await process_frame  # (a fresh frame: the press is new in it)
	Input.action_press("ui_mouse")
	await process_frame
	await process_frame
	await process_frame
	var jumped_dust: int = _dust_flying(main)
	Input.action_release("ui_mouse")
	await process_frame
	await process_frame
	_expect(_dust_flying(main) > jumped_dust or player.jumpCount > 0, "a jump: a little puff of dust from under him (jumps %d, dust %d, on the floor %s, aim from %s, stunned %.2f)"
		% [player.jumpCount, _dust_flying(main), player.is_on_floor(), aim.mouseOrigin, player.stunned])
	await _game_time(1.5)
	player.jumpCount = 0
	# (a real long fall: the rush of air as he falls)
	var air_heard := false
	await _put(player, Vector2(2787, -4400))  # (in the mushrooms: open down to a ledge at -4004)
	await _game_time(1.0)
	player.global_position = Vector2(2787, -4380)
	player.velocity = Vector2(0.0, 700.0)
	player.reset_physics_interpolation()
	for _i in 10:  # (in the air, as he sees it: then it's as if he'd come down from way above)
		await physics_frame
		if player.was_airborne:
			break
	player._fall_top += 40.0
	for i in 90:
		await physics_frame
		if player._fall_air != null and player._fall_air.playing and player._fall_air.volume_db > -55.0:
			air_heard = true
		if i > 4 and player.is_on_floor():  # (not the floor he was on before he was put up here)
			break
	_expect(air_heard, "falling a long way: the rush of air comes in (at %s, falling %.0f, fell %.1f, air %s)"
		% [player.global_position.round(), player.velocity.y, player._fall_top - player.currentHeight,
		"none" if player._fall_air == null else "%.1f dB" % player._fall_air.volume_db])
	await _game_time(1.5)
	_expect(player._fall_air == null or not player._fall_air.playing, "gone once he's landed")
	await _put(player, Vector2(1291.1925, 262.79996))
	await _game_time(5.0)  # (THE MUSHROOMS named on the way: faded)

	# A glimpse of the frog god up the climb (FROG KING2...): the plain shadow it always was when it comes,
	# and then, a while after, only its eyes, slowly glowing up out of it (the shadow left as it is).
	var god: Sprite2D = main.get_node("finale/Control/FROG KING2")
	var god_eyes := god.get_node_or_null("eyes") as Sprite2D
	var eyes_look: ShaderMaterial = (god_eyes.material as ShaderMaterial) if god_eyes else null
	var shade := god.self_modulate
	_expect(god.material == null and shade.r == 0.0 and shade.g == 0.0 and shade.b == 0.0 and eyes_look != null
		and float(eyes_look.get_shader_parameter("glow")) == 0.0, "a glimpse of the frog god: its plain shadow, as it always was")
	god.visible = true
	await _game_time(main.GOD_EYES_WAIT.x * 0.5)
	_expect(float(eyes_look.get_shader_parameter("glow")) == 0.0, "its eyes wait a while")
	await _game_time(main.GOD_EYES_WAIT.y + main.GOD_EYES_IN.y * 0.3)
	var glow := float(eyes_look.get_shader_parameter("glow"))
	_expect(glow > 0.05 and glow < 0.95, "then come up slowly (%.2f)" % glow)
	await _game_time(main.GOD_EYES_IN.y)
	_expect(float(eyes_look.get_shader_parameter("glow")) > 0.99 and god.material == null and god.self_modulate == shade,
		"till they glow: the rest of it still just its shadow (%.2f)" % float(eyes_look.get_shader_parameter("glow")))
	god.visible = false

	# Where he is, named as he gets there: not at home, nor on the way out of it (its signs are telling him
	# how to play); THE WORLD TREE, once he's up in it (fading again); not again straight away; and up the
	# tree, each of its parts.
	var titles: Node = main.get_node("AreaTitle")
	_expect(titles.area_at(player.global_position) == "" and titles.showing == "", "at home: no name")
	_expect(titles.area_at(Vector2(1720, -480)) == "" and titles.area_at(Vector2(3900, -480)) == "", "on the ground on the way to the tree (by its signs), and the far side: no name yet")
	_expect(titles.area_at(Vector2(2700, -480)) == "THE WORLD TREE", "at its foot: THE WORLD TREE")
	_expect(titles.area_at(Vector2(250, -150)) == "" and titles.area_at(Vector2(2797, -1240)) == "THE WORLD TREE"
		and titles.area_at(Vector2(2831, -2950)) == "THE DARK" and titles.area_at(Vector2(1150, -2700)) == ""
		and titles.area_at(Vector2(2787, -4400)) == "THE MUSHROOMS"
		and titles.area_at(Vector2(2950, -5626)) == "THE CASTLE" and titles.area_at(Vector2(1500, -6300)) == "THE CLOUDS"
		and titles.area_at(Vector2(2800, -7300)) == "THE TOP OF THE TREE", "the tree's parts, each with its name")
	# THE DARK only where it's dark: the bridge just above it (314.7, the dark already out) is the mushrooms'.
	var bridge := Vector2(2700.0, -(314.7 * 10.0 + 472.0))
	_expect(titles.area_at(bridge) == "THE MUSHROOMS" and titles.area_at(bridge + Vector2(0.0, 20.0)) == "THE DARK",
		"the bridge over the dark is THE MUSHROOMS; a fall back into the dark is THE DARK")
	var home: Vector2 = player.global_position
	await _put(player, Vector2(250, -150))
	await _game_time(0.6)
	_expect(titles.showing == "", "out of his bedroom, the way out under the tree: no name yet")
	await _put(player, Vector2(2797, -1240))
	await _game_time(0.6)
	_expect(titles.showing == "THE WORLD TREE" and titles._box.modulate.a > 0.3, "up in the tree: THE WORLD TREE (%s)" % titles.showing)
	await _game_time(5.5)
	_expect(titles.showing == "" and titles._box.modulate.a < 0.05, "and it fades away")
	await _put(player, home)
	await _game_time(0.6)
	await _put(player, Vector2(2797, -1240))
	await _game_time(0.6)
	_expect(titles.showing == "", "back up a moment later: not named again straight away")
	await _put(player, home)

	# Coming back down past the hut frog after being far higher: their lines, in turn; not before.
	var hut: Node2D = main.get_node("frogNPC1")
	player.highScore = 50.0
	_expect(main._fell_line(1, hut) == "", "no fall line before he's been well above them")
	player.highScore = 300.0
	var first: String = main._fell_line(1, hut)
	var second: String = main._fell_line(1, hut)
	_expect(first == main.FELL_LINES[1][0] and second == main.FELL_LINES[1][1], "fall lines, one after the other")
	main.npc1 = 1
	main._on_area_2d_body_shape_entered(RID(), player, 0, 0)
	_expect(main.get_node("frogNPC1/npc1speechbubble").text == main.FELL_LINES[1][2], "said when he comes back past them")

	# On a bouncy mushroom, the aim line shows the mushroom's throw (and letting go sideways gets it); aimed
	# straight up, his own jump.
	var map: TileMap = main.get_node("TileMap")
	var pad := Vector2i(-99999, 0)
	for cell in map.get_used_cells(1):
		var clear: bool = map.get_cell_source_id(0, cell + Vector2i.UP) == -1 and map.get_cell_source_id(1, cell + Vector2i.UP) == -1 \
			and map.get_cell_source_id(0, cell + Vector2i.UP * 2) == -1 and map.get_cell_source_id(1, cell + Vector2i.UP * 2) == -1
		if clear and map.get_cell_source_id(1, cell) == map.PAD_SOURCE and map.get_cell_atlas_coords(1, cell) in map.MUSHROOMS:
			pad = cell
			break
	_expect(pad.x != -99999, "the level has its bouncy mushrooms")
	if pad.x != -99999:
		var top: Vector2 = map.to_global(map.map_to_local(pad)) - Vector2(0.0, map.tile_set.tile_size.y * map.global_scale.y)
		await _put(player, top)
		var sling: Node2D = player.get_node("Trajectory")
		var sideways := Vector2(40, -60)
		_expect(player.is_on_floor() and map.pad_jump_at(player.position) == map.jump_velocity, "he can stand on a mushroom (%s)" % player.position)
		_expect(sling.shown_velocity(sideways).y == map.jump_velocity, "and aimed sideways there, the line shows the mushroom's throw (%s)" % sling.shown_velocity(sideways))
		_expect(sling.shown_velocity(Vector2(0, -60)) == sling.flight_velocity(Vector2(0, -60)), "aimed straight up, his own jump")
		player.velocity = sling.release_velocity(sideways)
		await process_frame
		await process_frame
		_expect(player.velocity.y < -700.0, "and letting go sideways, the mushroom does throw him (%.0f up)" % player.velocity.y)

	# A frog waits while he's out of earshot, and goes on when he's back.
	var area: Area2D = main.get_node("frogNPC2/Area2D2")
	var bubble: Label = main.get_node("frogNPC2/npc2speechbubble")
	await _put(player, Vector2(1290, 263))
	bubble.visible = true
	var waited := [false]
	var waiting := func() -> void:
		await main._while_away(area, bubble)
		waited[0] = true
	waiting.call()
	await _physics(6)
	_expect(not waited[0] and not bubble.visible, "a frog waits while he's away, their bubble hidden")
	await _put(player, Vector2(1439, -1900))
	await _until(func() -> bool: return waited[0], 3.0)
	_expect(waited[0] and bubble.visible, "and goes on when he's back")

	# The lost frog, first time, without the key: hello, he's lost, and that's all (no hint at the key).
	main.npc4 = 0
	main._on_area_2d_4_body_shape_entered(RID(), player, 0, 0)
	await _game_time(6.5)
	var first_words: Label = main.get_node("frogNPC4/npc4speechbubble")
	_expect(first_words.text == "i'm lost..." and not first_words.visible and main.npc4 == 1, "the lost frog says he's lost, and that's all (%s)" % first_words.text)
	# His words (every frog's) are drawn unshaded, so the dark can't swallow them past the lantern's light.
	var lit := 0
	for i in range(1, 7):
		var said: Label = main.get_node_or_null("frogNPC%d/npc%dspeechbubble" % [i, i])
		if said and said.material is CanvasItemMaterial and said.material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED 				and not said.z_as_relative and said.z_index == main.WORDS_Z:
			lit += 1
	_expect(lit == 6, "every frog's words stay readable in the dark, over the tiles (%d of 6)" % lit)
	await _game_time(4.0)

	# The gate open and him out of the dark, standing: the lost frog follows him out (fading in at the
	# bottom of the shaft, up its rungs and onto the bridge beside him: not up ahead in the castle), and
	# thanks him, each line only while he's by; found, he's just not lost anymore.
	var lost: AnimatedSprite2D = main.get_node("frogNPC4")
	var lost_words: Label = lost.get_node("npc4speechbubble")
	var voice: AudioStreamPlayer2D = lost.get_node("npc4talk")
	main.gateDestroyed = 1
	player.global_position = main.LOST_FROG_OUT + Vector2(300.0, 0.0)
	player.velocity = Vector2.ZERO
	for _i in 60:
		await physics_frame
		if main._lost_frog_up:
			break
	_expect(main._lost_frog_up and not voice.playing,
		"he comes out quietly: his first sound is his first hop (not his voice and a hop at once)")
	await _physics(20)
	await _game_time(0.9)
	_expect(main._lost_frog_up and lost.position.x == main.LOST_FROG_CLIMB[0].x and lost.position.y > main.LOST_FROG_OUT.y + 20.0,
		"up and standing, he sees the lost frog climbing up the shaft out of the dark (%s)" % lost.position.round())
	main._on_area_2d_4_body_shape_entered(RID(), player, 0, 0)  # (as if they touched while he's hopping)
	await _game_time(0.1)
	_expect(main._lost_frog_arriving and not lost_words.visible and not main._lost_frog_talking,
		"no words mid-hop: he lands before he says anything")
	await _put(player, main.LOST_FROG_OUT + Vector2(8.0, 0.0))  # (beside where he lands)
	await _until(func() -> bool: return lost.position.distance_to(main.LOST_FROG_OUT) < 1.0, 4.0)
	_expect(lost.position.distance_to(main.LOST_FROG_OUT) < 1.0 and lost.modulate.a > 0.99 and titles.area_at(lost.position) == "THE MUSHROOMS",
		"and out onto the bridge (%s)" % lost.position.round())
	var hop: AudioStreamPlayer2D = lost.get_node_or_null("hop")
	_expect(hop != null and hop.stream != null and hop.stream == voice.stream and hop.pitch_scale == voice.pitch_scale
		and hop.volume_db == voice.volume_db and hop.bus == voice.bus, "each hop in his own voice: the very sound he talks with")
	await _game_time(main.LOST_FROG_SETTLES * 0.5)
	_expect(main._lost_frog_arriving and not lost_words.visible and not main._lost_frog_talking,
		"landed beside him: a moment before he says anything")
	await _game_time(main.LOST_FROG_SETTLES * 0.5 + 0.4)
	_expect(lost_words.visible and lost_words.text == "i followed your jumps...", "then he thanks him")
	await _put(player, main.LOST_FROG_OUT + Vector2(400.0, 0.0))
	await _game_time(4.0)
	_expect(not lost_words.visible and lost_words.text == "i followed your jumps...", "hopped away: his words wait (hidden), not run on without him")
	await _put(player, main.LOST_FROG_OUT + Vector2(8.0, 0.0))
	await _game_time(3.5)
	_expect(lost_words.visible and lost_words.text.begins_with("thank you for showing"), "back: the rest, from where it was")
	var head_y := lost.global_position.y
	_expect(lost_words.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM and lost_words.get_global_rect().end.y < head_y,
		"two lines grow up from over his head, not down over it")
	await _game_time(3.0)
	main._on_area_2d_4_body_shape_entered(RID(), player, 0, 0)
	await _game_time(0.5)
	_expect(main._lost_frog_thanked and lost_words.text == "i'm not lost anymore...", "found, he's just not lost anymore (%s)" % lost_words.text)

	# The climb's time: as played (the game's own steps), only while he's climbing, not paused; shown with its
	# hours once there are any; kept in the save to the fraction, and saved up in the finale too (from the
	# last place below it, where he'd be put back).
	var played: float = player.play_secs
	await _physics(60)
	_expect(absf(player.play_secs - played - 1.0) < 0.05, "a second climbing is a second on his time (%.3f)" % (player.play_secs - played))
	Engine.time_scale = 0.05  # (paused)
	played = player.play_secs
	await _physics(20)
	Engine.time_scale = 1.0
	_expect(player.play_secs == played, "paused, it doesn't count (%.3f)" % (player.play_secs - played))
	player.play_secs = 3725.4
	_expect(player.play_time_text() == "1:02:05", "over an hour: shown with its hours (%s)" % player.play_time_text())
	player.play_secs = 125.9
	_expect(player.play_time_text() == "2:05", "under an hour: minutes and seconds (%s)" % player.play_time_text())
	player.play_secs = 1234.5
	player.save_game()
	var kept: Dictionary = _saved()
	_expect(is_equal_approx(float(kept.get("play_secs", -1.0)), 1234.5), "kept in the save to the fraction (%s)" % kept.get("play_secs"))
	var below: Vector2 = player.position
	var was_at: Vector2 = player.position
	player.position = Vector2(2804, -8000)
	player.currentHeight = (8000.0 - 472.0) / 10.0
	player.play_secs = 2000.25
	player.save_game()
	kept = _saved()
	_expect(kept.get("position") == below and is_equal_approx(float(kept.get("play_secs", -1.0)), 2000.25),
		"saved up in the finale: his time kept, from the last place below it (%s)" % kept.get("position"))
	await _put(player, was_at)

	# The glass, hit until it gives: the last words come up, under the plank below it.
	_expect(main._no_gods.modulate.a == 0.0, "the last words wait for the glass")
	for _i in 6:
		main._on_finaleexit_body_entered(player)
	await _game_time(3.0)
	_expect(main._no_gods.modulate.a > 0.99, "and come up as it gives (%.2f)" % main._no_gods.modulate.a)
	var middle: Vector2 = main._no_gods.position + main._no_gods.size / 2.0
	_expect(middle.distance_to(main.NO_GODS_AT) < 1.0, "under the plank below the glass")

	# The ending comes to rest on his bedroom, framed as he wakes up there (his camera's own offset aside).
	var anim: Animation = player.get_node("Camera2D/AnimationPlayer").get_animation("end")
	var track := anim.find_track(NodePath(".:position"), Animation.TYPE_VALUE)
	var last: Vector2 = anim.track_get_key_value(track, anim.track_get_key_count(track) - 1)
	_expect(last == player.END_IN_BEDROOM, "the ending's last keyframe is where the win screen rests (%s)" % last)
	var rests: Vector2 = Vector2(2804, -8382) + player.END_IN_BEDROOM * player.scale
	_expect(rests.distance_to(Vector2(1291.19, 262.8)) < 2.0, "which is his bedroom, where he wakes up (%s)" % rests)
	# (on its way: past the World Tree's sign without stopping, down through the underground, curving
	# smoothly through its points)
	var stops := 0
	var under := false
	for k in range(1, anim.track_get_key_count(track)):
		var at: Vector2 = anim.track_get_key_value(track, k)
		if at == anim.track_get_key_value(track, k - 1):
			stops += 1
		var spot: Vector2 = Vector2(2804, -8382) + at * player.scale
		if k < anim.track_get_key_count(track) - 1 and spot.y > -300.0 and spot.x < 1000.0:
			under = true
	_expect(stops == 0 and under and anim.track_get_interpolation_type(track) == Animation.INTERPOLATION_CUBIC,
		"the ending doesn't stop at the sign: on past it, down through the underground, curving, to his bedroom")

	# The win screen, upright: every line of its words across the screen. (No Lil Froggy let out onto this
	# computer's desktop by it.)
	var real_frog_out: bool = mm.desktop_frog_unlocked
	var real_achievements: Array = mm.achievements.duplicate()
	var real_skins: Array = mm.unlocked_skins.duplicate()
	var real_wins: int = mm.wins
	var real_crown = mm.froggyCrown
	var real_hat: String = mm.equipped_hat
	mm.desktop_frog_unlocked = true
	mm.achievements.erase("beat_game")  # (his first win: its achievement new)
	mm.held_news.clear()
	player.finalTime = "12:34"
	player.jumpCount = 1234
	player._on_end_animation_finished()
	for _i in 2:
		await process_frame
	mm.desktop_frog_unlocked = real_frog_out
	_expect("beat_game" in mm.achievements and mm.held_news.has(["achievement", "beat_game"])
		and not mm._toasts.any(func(t: Array) -> bool: return t[0] == "Achievement!"),
		"the win's achievement earned, but not said over the win screen: kept for the next START")
	var congrats: CanvasItem = player.get_node("winscreen/congrats")
	var made_by: CanvasItem = player.get_node("winscreen/by muse2")
	_expect(congrats.modulate.a < 0.5 and made_by.modulate.a < 0.05,
		"the win screen's lines easing in, one after another (%.2f, %.2f)" % [congrats.modulate.a, made_by.modulate.a])
	await _game_time(player.WIN_STAGGER * 4.0 + player.WIN_FADE + 0.4)
	_expect(congrats.modulate.a > 0.99 and made_by.modulate.a > 0.99, "and all there")
	for path in ["winscreen/congrats", "winscreen/time2"]:
		var label: Label = player.get_node(path)
		var size: int = label.get_theme_font_size("font_size")
		var widest := 0.0
		for line in label.text.split("\n"):
			widest = maxf(widest, label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		_expect(widest + 2.0 * label.get_theme_constant("outline_size") <= PORTRAIT.x - 16.0,
			"%s fits across a phone held upright (%d px at %d)" % [path, int(widest), size])
	# "Thanks for playing!": easing in; pressed, the screen eases to black, the game starting over under it.
	var thanks: Button = player.get_node("winscreen/thanksforplayingButton")
	player._on_thanksforplaying_timer_timeout()
	_expect(thanks.visible and thanks.modulate.a < 0.1, "Thanks for playing! easing in (%.2f)" % thanks.modulate.a)
	await _game_time(player.WIN_FADE + 0.3)
	_expect(thanks.modulate.a > 0.99, "and there")
	player._on_thanksforplaying_button_pressed()
	await create_timer(0.15, true, false, true).timeout
	_expect(not mm.curtain_shut(), "pressed: the screen easing to black, not cut to")
	await create_timer(player.HOME_FADE + 0.3, true, false, true).timeout
	_expect(mm.curtain_shut(), "and black")

	mm.wardrobe_path = real_wardrobe
	mm.game_beaten = real_beaten
	main.queue_free()
	await process_frame

	# Once he's won, the TV keeps to its static.
	mm.game_beaten = true
	mm.wardrobe_path = WARDROBE
	main = await _game()
	main.get_node("Player")._on_button_pressed()
	for _i in 3:
		await process_frame
	_expect(not main._tv_done and not main._tv_bubble.visible, "the TV keeps quiet once he's won")
	_expect(mm.held_news.is_empty() and mm._toast_up, "what the win earned, said now, at the next START")
	await create_timer(1.8, true, false, true).timeout
	_expect(not mm.curtain_shut(), "the title came up out of the black")
	mm.achievements = real_achievements
	mm.unlocked_skins = real_skins
	mm.wins = real_wins
	mm.froggyCrown = real_crown
	mm.equipped_hat = real_hat
	main.queue_free()
	await process_frame

	# A climb saved after the frog at the castle door opened the way (a fall back down below it, a landing:
	# saved): loaded, the way's open still, not shut with him gone.
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_var({"position": Vector2(2780, -5620), "has_lantern": true, "gateDestroyed": 1, "npc1": 1, "npc2": 1,
		"npc3": 1, "npc4": 1, "npc5": 1, "npc6": 1})
	file.close()
	main = await _game()
	_expect(main.way_open and main.get_node_or_null("finale/finale walls/hidethis/delete") == null
		and main.get_node("finale/finale walls/toshow").visible and not main.get_node("frogNPC6").visible,
		"a climb saved after he opened the way: loaded, it's open still (%s)" % main.way_open)
	mm.wardrobe_path = real_wardrobe
	mm.game_beaten = real_beaten
	mm.look_made = real_made
	main.queue_free()
	_finish()


## The "!"s up over him now (each its own node: Exclaim, with the "!" in it).
func _marks(player: Node) -> Array:
	var out := []
	for c in player.get_children():
		if str(c.name).begins_with("Exclaim") and not c.is_queued_for_deletion() and c.get_child_count() > 0 \
				and c.get_child(0) is Label and (c.get_child(0) as Label).text == "!":
			out.append(c)
	return out


## Dust flying in the level now (CPUParticles2D, emitting).
func _dust_flying(main: Node) -> int:
	var n := 0
	for c in main.get_children():
		if c is CPUParticles2D and c.emitting:
			n += 1
	return n


## Whether a sound of his (`file`) is playing now.
func _playing(player: Node, file: String) -> bool:
	for c in player.get_children():
		if c is AudioStreamPlayer and c.playing and c.stream != null and str(c.stream.resource_path).ends_with(file):
			return true
	return false


## A tap on the screen at `at`, as a finger's comes into the game (a click: a touch is one too).
func _tap_screen(at: Vector2) -> void:
	for down in [true, false]:
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = down
		tap.position = at
		tap.global_position = at
		_view.push_input(tap)


## The save as it was written (its scratch file).
func _saved() -> Dictionary:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	f.close()
	return d if d is Dictionary else {}


func _game() -> Node:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	main.get_node("Player").save_path = SAVE
	_view.add_child(main)
	for _i in 10:
		await process_frame
	return main


func _put(player: CharacterBody2D, at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	await _physics(30)


func _physics(n: int) -> void:
	for _i in n:
		await physics_frame


## The TV's words all on the screen: the widest of its lines (and its outline), centred in its box, inside
## what the camera shows.
func _tv_words_seen(main: Node) -> bool:
	var words: Label = main._tv_bubble
	var at: Transform2D = words.get_global_transform()
	var mid := (at * Vector2(words.size.x * 0.5, 0.0)).x
	var half := (words.get_minimum_size().x * 0.5 + words.get_theme_constant("outline_size")) * at.get_scale().x
	var room: Rect2 = load("res://scripts/UIStyle.gd").room(_view.get_visible_rect().size)  # (clear of a camera strip)
	var seen: Rect2 = _view.get_canvas_transform().affine_inverse() * room
	return mid - half >= seen.position.x and mid + half <= seen.end.x


## Game time going by quicker (timers only: no one's moving meanwhile).
func _game_time(secs: float) -> void:
	Engine.time_scale = 8.0
	await create_timer(secs).timeout
	Engine.time_scale = 1.0


func _until(check: Callable, secs: float) -> void:
	var t := 0.0
	while not check.call() and t < secs:
		await process_frame
		t += 1.0 / 60.0


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _finish() -> void:
	Engine.time_scale = 1.0
	for f in [SAVE, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	if _failures.is_empty():
		print("Story test passed.")
	else:
		for f in _failures:
			print("  FAILED: ", f)
		print("Story test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
