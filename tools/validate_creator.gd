extends SceneTree
## Your froggy (FroggyLook) and the frog god's intro (CreatorIntro), in the real level: a new player's
## game starts with it, no title, out of the dark with a low hum (the TV's static quiet), the frog god's
## shadow speaking, slowly, in a low voice; tapping goes through its words to "what do you look like?"
## (in even lines), his skin, then his belly (his eyes always Froggy's black), each from a palette of 40 (a tap or a slide,
## gliding onto him; NEXT and BACK); "Is this you?" No goes back, Yes keeps it (in the wardrobe's save:
## no hat, no pattern, they're earned by playing; his band a random colour of its own); it cuts to black,
## the hum cut off, the climb begins behind it, and he fades in in his bedroom as that froggy, the TV's
## static up and the TV talking; he's lil froggy, and his look goes to his party. A hat he's found is worn
## in front of his head. Next time START's straight to the climb; not made yet, ENDLESS and PLAY TOGETHER
## bring the frog god first too (then Play Together's menu, where his band's colour is changed); the
## wardrobe's CHANGE YOUR LOOK is just the choosing (his pattern's colour too, not his band's), and the
## climb goes on. Then the unlocks (once each; the Mushroom hat at 25 bounces; a big fall; nothing for
## just climbing; the key's Spots, the first frog's Leaf), a friend's frog in their look, and the
## wardrobe's PATTERNS and STILL TO FIND. Scratch saves only.
##   Godot --headless --path . --script res://tools/validate_creator.gd

const SCRATCH_SAVE := "user://test_creator_save.save"
const SCRATCH_WARDROBE := "user://test_creator_wardrobe.save"

var _failures: Array[String] = []
var mm: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	mm = root.get_node("MusicManager")
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	var real := [mm.wardrobe_path, mm.look.duplicate(), mm.look_made, mm.equipped_hat, mm.equipped_skin,
		mm.unlocked_skins.duplicate(), mm.mushroom_bounces, mm.froggyCrown, mm.seen_cosmetics.duplicate()]
	mm.wardrobe_path = SCRATCH_WARDROBE
	mm.look = {}
	mm.look_made = false
	mm.equipped_hat = ""
	mm.equipped_skin = ""
	mm.unlocked_skins = []
	mm.mushroom_bounces = 0
	mm.froggyCrown = 0

	# A new player: no title; out of the dark, the frog god (and a low hum, not its song).
	var main: Node = await _game()
	var player: Node = main.get_node("Player")
	var start: Vector2 = player.global_position
	var tv: AudioStreamPlayer2D = main.get_node("Musecrtquarterview/AudioStreamPlayer2D")
	var tv_db: float = main._tv_db  # (the TV's static, as the level has it)
	var intro = player.get_node_or_null("CreatorIntro")
	_expect(intro != null and intro.fade_in and not player.get_node("titlescreen").visible and player.get_node("Trajectory").endGame != 0,
		"a new player's game starts with the frog god, not the title")
	if intro == null:
		await _finish(real, main)
		return
	_expect(intro._black.color.a > 0.2 and intro._words.text == "", "fading in out of the dark, before it speaks (%.2f)" % intro._black.color.a)
	var music := intro._music.stream as AudioStreamOggVorbis
	_expect(intro._music.playing and music != null and music.loop and music.loop_offset > 1.0,
		"music under it, looping (from a little way in: its end runs into that)")
	_expect(tv.volume_db < -70.0, "the TV's static quiet while it's there")
	await _until(func() -> bool: return intro._words.text != "", 4.0)
	_expect(intro._words.text == "...LITTLE ONE..." and intro._shadow > 0.9 and intro._black.color.a < 0.5, "he's the frog god's shadow, and it speaks")
	_expect(intro._music.stream.resource_path == "res://assets/froggod_intro.ogg" and intro._music.stream.get_length() > 200.0,
		"the ending's song slowed right down, with brown noise under it (froggod_intro.ogg, the whole song: %.0f s)" % intro._music.stream.get_length())
	await _until(func() -> bool: return intro._typed >= intro._words.text.length(), 4.0)
	await _wait(2.0)
	_expect(intro._words.text == "...LITTLE ONE..." and intro._more.shown and intro._more.modulate.a > 0.5,
		"its words stay till a tap (no going on by themselves), the arrow under them saying so")
	_expect(intro._more.position.y > intro._words.position.y and intro._more.position.y < intro._frog.position.y,
		"the arrow between its words and him")
	intro._advance()
	await _frames(1)
	_expect(intro._words.text.begins_with("YOU HAVE COME") and not intro._more.shown, "a tap: its next words (the arrow gone while they come)")
	_expect(intro.TYPE_SPEED <= 15.0 and intro.VOICE_PITCH.y < 0.5 and intro.VOICE_PITCH.x < intro.VOICE_PITCH.y,
		"slowly, in a low voice (%.0f letters a second, pitch %.2f to %.2f)" % [intro.TYPE_SPEED, intro.VOICE_PITCH.x, intro.VOICE_PITCH.y])
	await _wait(1.0)
	_expect(not main._tv_done, "and the TV keeps its words till he's woken in his bedroom")
	for _i in 12:
		if intro._step != "talk":
			break
		intro._advance()
		await _frames(1)
	await _frames(2)
	_expect(intro._step == "choose" and intro._steps == ["body", "belly"] and intro._at == 0
		and intro._said == "WHAT DO YOU LOOK LIKE?" and intro._part.text == "SKIN" and intro._choosing.visible,
		"then it asks what he looks like: his skin first")
	var lines: PackedStringArray = intro._words.text.split("\n")
	_expect(lines.size() == 1 or (lines.size() == 2 and lines[0].split(" ").size() >= 2 and lines[1].split(" ").size() >= 2),
		"its words in even lines, never one word left on its own (%s)" % [lines])
	intro._even("YOU HAVE COME FROM BELOW.", 230.0)
	var even: PackedStringArray = intro._even("YOU HAVE COME FROM BELOW.", 230.0).split("\n")
	_expect(even.size() >= 2 and even[even.size() - 1].split(" ").size() >= 2, "a longer line broken evenly too (%s)" % [even])

	# His skin: a palette of colours, one tapped.
	var grid = intro._grid
	_expect(grid.colours.size() == 40 and grid.at == 8, "a palette of 40 colours, his own mint framed (%d, at %d)" % [grid.colours.size(), grid.at])
	grid._choose_at(grid.cell(21).get_center())
	var skin: Color = grid.colours[21]
	_expect(grid.at == 21 and str(intro._look.body) == skin.to_html(false), "a tap on a colour: his skin's that colour")
	grid._choose_at(grid.cell(22).get_center())
	grid._choose_at(grid.cell(21).get_center())
	_expect(str(intro._look.body) == skin.to_html(false), "and a finger slid across them, the one it stops on")
	await _wait(1.7)
	_expect(intro._shadow < 0.05 and _near(intro._frog.material.get_shader_parameter("body_colour"), skin, 0.02),
		"his colours fill in, gliding onto him (shadow %.2f)" % intro._shadow)
	intro._next_pressed()
	_expect(intro._at == 1 and intro._part.text == "BELLY" and intro._said == "WHAT DO YOU LOOK LIKE?" and intro._back.visible, "NEXT: his belly")
	grid._choose_at(grid.cell(33).get_center())
	var belly: Color = grid.colours[33]
	intro._back_pressed()
	_expect(intro._at == 0 and intro._part.text == "SKIN" and grid.at == 21, "BACK: his skin again, as he left it")
	intro._next_pressed()
	_expect(intro._at == 1 and intro._part.text == "BELLY" and _near(look.colour(intro._look, "belly"), belly), "then his belly again (as he left it)")
	intro._next_pressed()
	_expect(intro._step == "sure" and intro._sure.visible and intro._said == "IS THIS YOU?",
		"and that's all it asks (no eyes, no name, no hat, no pattern): is this you?")
	intro._no()
	_expect(intro._step == "choose" and intro._at == 0, "No goes back to the start of it")
	intro._ask_sure()
	var made: Dictionary = look.clean(intro._look)
	intro._yes()
	await _frames(1)
	_expect(mm.look_made and str(mm.look.body) == made.body and str(mm.look.eyes) == "000000" and str(mm.look.belly) == made.belly
		and mm.equipped_hat == "" and int(mm.look.pattern) == 0, "Yes keeps him as he is, Froggy's black eyes (hats and patterns are earned by playing)")
	_expect(str(look.clean({"body": "ff8fd6", "eyes": "2a6fd6"}).eyes) == "000000" and str(look.clean({"eyes": 2}).eyes) == "000000",
		"a look from before with coloured eyes (or a friend's): his eyes are Froggy's black")
	var bright: Array = look.palette("band").slice(look.ACROSS, look.ACROSS * 3)
	var rolled: Color = look.band_colour(mm.look)
	var bands := {}
	for _i in 60:
		bands[look.random_band()] = true
	_expect(bright.any(func(c: Color) -> bool: return _near(c, rolled)) and bands.size() >= 8,
		"and gives him a band of a colour all his own, at random (%s; %d different in 60 froggies)" % [rolled.to_html(false), bands.size()])
	_expect(intro._black.color.a > 0.99 and not intro._root.visible and not intro._music.playing and player.get_node("Trajectory").endGame == 0,
		"it cuts to black, the music cut off, and the climb's begun behind it")
	_expect(intro.slow_end and intro.hold() >= 2.0 and intro.fade() >= 3.0, "into his bedroom: a long black, then a slow fade")
	await _wait(2.0)
	_expect(is_instance_valid(intro) and intro._black.color.a > 0.99, "still black two seconds on, its sound ringing out")
	var kept: Dictionary = mm.look.duplicate()
	mm.look = {}
	mm.look_made = false
	mm.load_wardrobe()
	_expect(mm.look_made and str(mm.look.get("body", "")) == made.body, "in the wardrobe's save (%s)" % [mm.look])
	mm.look = kept
	await _until(func() -> bool: return not is_instance_valid(intro), 10.0)  # (a long black, a slow fade)
	_expect(not is_instance_valid(intro) and not player.get_node("titlescreen").visible and player.get_node("Trajectory").endGame == 0,
		"and he fades in from it")
	_expect(player.asleep and player.waking and not tv.playing and main._tv_glass.visible,
		"asleep in his beanbag, the TV off (its static quiet)")
	var worn: ShaderMaterial = player.get_node("Sprite2D").material
	_expect(worn != null and _near(worn.get_shader_parameter("body_colour"), look.colour(made, "body"))
		and _near(worn.get_shader_parameter("eye_colour"), Color.BLACK) and worn.get_shader_parameter("eyes_shut") == true,
		"as the froggy he made, his eyes shut")
	_expect(player.global_position.distance_to(start) < 60.0, "in his bedroom, where a new climb starts")
	await _until(func() -> bool: return tv.playing, 5.0)
	_expect(tv.playing and player.asleep, "the TV comes on by itself")
	await _until(func() -> bool: return not player.asleep, 4.0)
	_expect(not player.asleep and player.waking, "he wakes")
	await _until(func() -> bool: return main._tv_bubble.visible, 4.0)
	_expect(main._tv_done and main._tv_bubble.visible and main._tv_bubble.text == main.TV_LINES[0], "and the TV has its words for him")
	_expect(tv.volume_db > tv_db - 3.0, "its static up (%.1f dB)" % tv.volume_db)
	for _i in 12:
		if not main._tv_listening:
			break
		main._tv_tap()
		await _frames(1)
	_expect(not player.waking and not main._tv_bubble.visible and main.get_node("World Sprites/tutorial").visible,
		"a tap for each of its lines, then the tutorial, and he's off")
	var info: Dictionary = root.get_node("Party").my_info()
	_expect(str(info.look.body) == made.body and str(info.look.belly) == made.belly and info.name == "lil froggy",
		"his party sees his look, and he's lil froggy (%s)" % [info])

	# A hat he's found: worn in front of his head.
	mm.unlocked_skins.append("bow")
	mm.equipped_hat = "bow"
	player._apply_equipped_cosmetics()
	await _frames(2)
	var hat: Sprite2D = player.get_node_or_null("LookHat")
	_expect(hat != null and hat.visible and hat.texture == look.hat_texture("bow") and hat.position.y > player.get_node("Sprite2D").position.y
		and hat.offset.y < -10.0, "a hat he's found is worn in front of his head (after him in the y-sort, drawn up on his head)")
	mm.equipped_hat = ""
	mm.unlocked_skins.erase("bow")
	player._apply_equipped_cosmetics()

	# Next time: straight to the climb.
	main.queue_free()
	await _frames(3)
	main = await _game()
	player = main.get_node("Player")
	player._on_button_pressed()
	await _frames(3)
	_expect(player.get_node_or_null("CreatorIntro") == null and player.get_node("Trajectory").endGame == 0, "next time, Play's straight to the climb")

	# Not made yet, ENDLESS and PLAY TOGETHER bring the frog god first too: it's how the game starts.
	var made_before: Dictionary = mm.look.duplicate()
	var made_hat: String = mm.equipped_hat
	mm.look_made = false
	main.queue_free()
	await _frames(3)
	main = await _game()
	player = main.get_node("Player")
	var opening = player.get_node_or_null("CreatorIntro")  # (the game's own start, the very first time: put by)
	_expect(opening != null and opening.slow_end, "(the game starts with it, into his bedroom: the long black, the slow fade)")
	if opening:
		opening.free()
	player.get_node("titlescreen").visible = true
	player._on_endlessmodebutton_pressed()
	await _frames(3)
	var first = player.get_node_or_null("CreatorIntro")
	_expect(first != null and root.get_node_or_null("EndlessMode") == null and is_instance_valid(main) and main.is_inside_tree()
		and not first.slow_end, "a new player's ENDLESS brings the frog god first, not Endless (and it's quick into it, after)")
	if first:
		first.queue_free()
	await _frames(2)
	player.get_node("titlescreen").visible = true
	player._on_party_button_pressed()
	await _frames(3)
	first = player.get_node_or_null("CreatorIntro")
	_expect(first != null and _party_screen(player) == null, "and PLAY TOGETHER does too, before its menu")
	if first:
		first._advance()
		for _i in 12:
			if first._step != "talk":
				break
			first._advance()
			await _frames(1)
		first._ask_sure()
		first._yes()
		await _until(func() -> bool: return _party_screen(player) != null, 10.0)
		var screen = _party_screen(player)
		_expect(mm.look_made and screen != null, "made, Play Together's menu opens")
		if screen:
			# His band's colour is changed here (the frog god doesn't ask it): its palette, a tap, kept and sent.
			var band_button: Button = screen.find_child("BandButton", true, false)
			var band_line: Control = screen.find_child("BandLine", true, false)
			_expect(band_button != null and band_line != null and screen.find_child("BandGrid", true, false) == null,
				"Play Together has his band's colour (its palette shut till he opens it)")
			if band_button:
				band_button.pressed.emit()
				await _frames(4)
				var band_grid = screen.find_child("BandGrid", true, false)
				var squares: bool = band_grid != null and band_grid.colours.size() == 40
				if band_grid:
					for i in band_grid.colours.size():
						var r: Rect2 = band_grid.cell(i)
						squares = squares and Rect2(Vector2.ZERO, band_grid.size).encloses(r) and r.size.x >= 16.0
				_expect(squares and _near(band_grid.colours[band_grid.at], look.band_colour(mm.look)),
					"BAND COLOUR: its palette, his band's colour framed, every square there")
				if band_grid:
					var pick: int = 3 if band_grid.at != 3 else 4
					band_grid._choose_at(band_grid.cell(pick).get_center())
					var picked: Color = band_grid.colours[pick]
					var sent: Dictionary = root.get_node("Party").my_info()
					_expect(_near(look.band_colour(mm.look), picked) and _near(look.band_colour(sent.look), picked),
						"a tap: his band's that colour, and what his friends see")
					var picked_look: Dictionary = mm.look.duplicate()
					mm.look = {}
					mm.load_wardrobe()
					_expect(_near(look.band_colour(mm.look), picked), "kept in the wardrobe's save")
					mm.look = picked_look
			screen.closed.emit()
			await _frames(2)
			_expect(player.get_node("titlescreen").visible, "and closing it, the title's there")
	await _until(func() -> bool: return player.get_node_or_null("CreatorIntro") == null, 3.0)
	mm.look = made_before
	mm.equipped_hat = made_hat
	mm.look_made = true
	main.queue_free()
	await _frames(3)
	main = await _game()
	player = main.get_node("Player")
	player._on_button_pressed()  # (climbing again, as before)
	await _frames(3)

	# The wardrobe's CHANGE YOUR LOOK: just the choosing (with his pattern's colour, when he's wearing one;
	# not his band's, that's Play Together's); the climb goes on.
	mm.unlocked_skins.append("pattern_spots")
	var spotted: Dictionary = look.clean(mm.look)
	spotted.pattern = 1
	mm.look = spotted
	var ws: CanvasLayer = load("res://scenes/WardrobeScreen.gd").new()
	player.add_child(ws)
	await _frames(3)
	var change: Button = ws.find_child("ChangeLookButton", true, false)
	_expect(change != null and change.visible, "the wardrobe has CHANGE YOUR LOOK")
	if change:
		change.pressed.emit()
		await _frames(3)
		var again = root.get_node_or_null("CreatorIntro")
		_expect(again != null and again.from_wardrobe and again._said == "WHAT DO YOU LOOK LIKE?" and again._part.text == "SKIN"
			and again._shadow < 0.05, "which goes straight to the choosing, no shadow")
		if again:
			_expect(again._steps == ["body", "belly", "pattern_colour"], "his skin and belly, his pattern's colour (not his eyes', not his band's)")
			again._grid._choose_at(again._grid.cell(4).get_center())
			var new_skin: Color = look.colour(again._look, "body")
			var band: Color = look.band_colour(mm.look)
			for _i in 2:
				again._next_pressed()
			await _frames(1)
			_expect(again._part.text == "PATTERN" and again._next.text == "DONE", "his pattern's colour last")
			again._grid._choose_at(again._grid.cell(13).get_center())
			again._next_pressed()
			await _until(func() -> bool: return not is_instance_valid(again), 3.0)
			_expect(_near(look.colour(mm.look, "body"), new_skin) and _near(look.band_colour(mm.look), band) and int(mm.look.pattern) == 1
				and is_instance_valid(main) and player.get_node("Trajectory").endGame == 0, "and back, his new look kept (his band as it was), the climb as it was")
	ws.queue_free()
	mm.unlocked_skins.erase("pattern_spots")
	spotted = look.clean(mm.look)
	spotted.pattern = 0
	mm.look = spotted

	# Unlocks: once each.
	_expect(mm.unlock("shiny") and not mm.unlock("shiny") and "shiny" in mm.unlocked_skins, "an unlock's yours once (and again does nothing)")
	var tiles: Node = main.get_node("TileMap")
	for _i in 24:
		tiles._counted_bounce()
	_expect(not "mushroom" in mm.unlocked_skins and mm.mushroom_bounces == 24 and not "cap" in mm.unlocked_skins,
		"24 mushroom bounces: not the Mushroom hat yet (and nothing for just bouncing)")
	tiles._counted_bounce()
	_expect("mushroom" in mm.unlocked_skins, "the 25th: the Mushroom hat")
	await _until(func() -> bool: return player.is_on_floor(), 2.0)
	player.was_airborne = true
	player._fall_top = player.currentHeight + 160.0
	await _frames(4)
	_expect("ghost" in mm.unlocked_skins, "a really big fall: the Ghost skin")
	_expect(not "leaf" in mm.unlocked_skins and not "pattern_spots" in mm.unlocked_skins, "nothing's given just for climbing")
	main._on_area_2dkey_body_shape_entered(RID(), player, 0, 0)
	_expect("pattern_spots" in mm.unlocked_skins, "finding the key in the dark: the Spots pattern")
	main.npc1 = 1
	main._catch_up_gifts()
	_expect("leaf" in mm.unlocked_skins and not "bow" in mm.unlocked_skins,
		"a save that's talked with the first frog gets his Leaf (and not the joking frog's Bow)")
	_expect(not look.UNLOCKS.has("pattern_freckles") and look.PATTERN_UNLOCKS[3] == "-", "no Freckles")

	# A friend's frog, in their look.
	var frog := Node2D.new()
	frog.set_script(load("res://scripts/PartyFrog.gd"))
	main.add_child(frog)
	frog.setup(player, 2, {"name": "@pal", "hat": "tophat", "skin": "rainbow", "look": {"body": 9, "pattern": 2, "band": 3}})
	var fm: ShaderMaterial = frog._sprite.material
	_expect(_near(fm.get_shader_parameter("body_colour"), look.BODY[9][1]) and fm.get_shader_parameter("effect") == 2
		and frog._hats.has("LookHat") and frog._hats.LookHat.visible and frog._hats.LookHat.texture == look.hat_texture("tophat"),
		"a friend's frog wears their look: colour, pattern, skin and hat")
	_expect(frog._hats.LookHat.get_index() > frog._sprite.get_index() and frog._hats.Froggycrown.get_index() < frog._sprite.get_index(),
		"their drawn hat in front of their head, the crown behind it, as on your own")
	_expect(look.material({"body": 5}, "negative_skin").shader.resource_path == "res://assets/negative.gdshader"
		and look.material({"body": 5}, "golden_skin").get_shader_parameter("effect") == 8,
		"the Negative skin is as it always was (the screen behind him, turned over); the others go over his look")

	# The wardrobe: the patterns he's found (one on at a time); all still to find says how (nothing's his
	# from the start).
	var ws2: CanvasLayer = load("res://scenes/WardrobeScreen.gd").new()
	player.add_child(ws2)
	await _frames(3)
	var words := ""
	for l in ws2.find_children("*", "Label", true, false):
		words += l.text + " | "
	_expect(words.contains("PATTERNS") and words.contains("Spots") and words.contains("STILL TO FIND")
		and words.contains("Hear the joking frog's joke in the World Tree") and words.contains("Catch a fly in Endless")
		and words.contains("Reach the frog at the castle door") and words.contains("Climb all the way to space in Endless")
		and not words.contains("Freckles") and not words.contains("Climb 50 m") and not words.contains("Yours from the start"),
		"the wardrobe: the patterns he's earned, and everything still to earn says how")
	var spots_btn: Button = ws2._item_buttons.get("pattern_spots")
	if spots_btn:
		spots_btn.pressed.emit()
	_expect(spots_btn != null and int(look.clean(mm.look).pattern) == 1, "EQUIP on Spots: he's spotted")
	ws2.queue_free()
	await _finish(real, main)


## Two colours the same, near enough (each of red, green and blue within the tolerance).
func _near(a, b, tolerance := 0.01) -> bool:
	if not (a is Color and b is Color):
		return false
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


## Play Together's menu (PartyScreen), open over the title, or null.
func _party_screen(player: Node) -> Node:
	for child in player.get_children():
		var s: Script = child.get_script()
		if s != null and s.resource_path == "res://scenes/PartyScreen.gd" and not child.is_queued_for_deletion():
			return child
	return null


func _game() -> Node:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	main.get_node("Player").save_path = SCRATCH_SAVE
	root.add_child(main)
	await _frames(40)
	return main


func _finish(real: Array, main: Node) -> void:
	if is_instance_valid(main):
		main.queue_free()
	for n in root.get_children():
		if n.name == "CreatorIntro":
			n.queue_free()
	await _frames(3)
	mm.wardrobe_path = real[0]
	mm.look = real[1]
	mm.look_made = real[2]
	mm.equipped_hat = real[3]
	mm.equipped_skin = real[4]
	mm.unlocked_skins = real[5]
	mm.mushroom_bounces = real[6]
	mm.froggyCrown = real[7]
	mm.seen_cosmetics = real[8]
	Engine.time_scale = 1.0
	for p in [SCRATCH_SAVE, SCRATCH_WARDROBE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if _failures.is_empty():
		print("Creator test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Creator test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


func _until(done: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < end:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
