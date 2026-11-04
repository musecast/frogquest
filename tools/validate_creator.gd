extends SceneTree
## Your froggy (FroggyLook) and the frog god's intro (CreatorIntro), in the real level: a new player's
## Play brings the frog god first, as a shadow; tapping goes through its words to the choosing; each
## choice dresses him at once (colour, belly, pattern and its colour, eyes, hat, band), round and round;
## his colours fill in; "Is this you?" No goes back, Yes keeps it (in the wardrobe's save); the last
## words, the flash, and he wakes in his bedroom as that froggy, the TV talking. His look goes to his
## party; next time Play's straight to the climb; not made yet, ENDLESS and PLAY TOGETHER bring the frog
## god first too (then Play Together's menu); the wardrobe's CHANGE YOUR LOOK is just the choosing,
## and the climb goes on. Then the unlocks (once each, with the mushrooms' count and a big fall), a
## friend's frog in their look, and the wardrobe's starters and STILL TO FIND. Scratch saves only.
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

	# A new player: Play brings the frog god first.
	var main: Node = await _game()
	var player: Node = main.get_node("Player")
	var start: Vector2 = player.global_position
	player._on_button_pressed()
	await _frames(3)
	var intro = player.get_node_or_null("CreatorIntro")
	_expect(intro != null and not player.get_node("titlescreen").visible and player.get_node("Trajectory").endGame != 0,
		"a new player's Play brings the frog god, not the climb")
	if intro == null:
		await _finish(real, main)
		return
	_expect(intro._words.text == "...LITTLE ONE..." and intro._shadow > 0.9, "he's the frog god's shadow, and it speaks")
	for _i in 12:
		if intro._step != "talk":
			break
		intro._advance()
		await _frames(1)
	_expect(intro._step == "choose" and intro._scroll.visible and intro._this_is_me.visible,
		"tapping goes through its words to \"what do you look like?\" and the choosing")

	intro._change("body", 3)
	intro._change("pattern", 1)
	intro._change("pattern_colour", 2)
	intro._change("eyes", 2)
	intro._change("hat", 1)
	intro._change("band", 1)
	await _frames(2)
	var chosen: Dictionary = intro._look
	_expect(chosen.body == 3 and chosen.pattern == 1 and chosen.eyes == 2 and chosen.band == 1 and intro._hat == "bow",
		"each choice takes (%s, %s)" % [chosen, intro._hat])
	var mat: ShaderMaterial = intro._frog.material
	_expect(mat.get_shader_parameter("body_colour") == look.BODY[3][1] and mat.get_shader_parameter("pattern") == 1,
		"and dresses him at once")
	_expect(intro._values.pattern_colour[2].visible and intro._values.hat[0].text == "Bow", "the pattern's colour shows once there's a pattern; the hat's name too")
	intro._change("belly", -1)
	_expect(int(intro._look.belly) == look.BELLY.size() - 1, "and round and round (back from the first is the last)")
	intro._change("belly", 1)
	await _wait(1.7)
	_expect(intro._shadow < 0.05, "his colours fill in as he chooses (shadow %.2f)" % intro._shadow)

	intro._ask_sure()
	_expect(intro._sure.visible and intro._words.text == "IS THIS YOU?" and not intro._scroll.visible, "THIS IS ME asks: is this you?")
	intro._no()
	_expect(intro._step == "choose" and intro._scroll.visible, "No goes back to the choosing")
	intro._ask_sure()
	intro._yes()
	_expect(mm.look_made and int(mm.look.body) == 3 and mm.equipped_hat == "bow", "Yes keeps him as he is")
	var kept: Dictionary = mm.look.duplicate()
	mm.look = {}
	mm.look_made = false
	mm.load_wardrobe()
	_expect(mm.look_made and int(mm.look.get("body", -1)) == 3 and int(mm.look.get("band", -1)) == 1,
		"in the wardrobe's save (%s)" % [mm.look])
	mm.look = kept
	await _until(func() -> bool: return not is_instance_valid(intro), 10.0)
	_expect(not is_instance_valid(intro) and not player.get_node("titlescreen").visible and player.get_node("Trajectory").endGame == 0,
		"the last words, the flash, and he wakes and climbs")
	var worn: ShaderMaterial = player.get_node("Sprite2D").material
	var hat: Sprite2D = player.get_node_or_null("LookHat")
	_expect(worn != null and worn.get_shader_parameter("body_colour") == look.BODY[3][1] and hat != null and hat.visible
		and hat.texture == look.hat_texture("bow"), "as the froggy he made, bow and all")
	_expect(hat != null and hat.position.y > player.get_node("Sprite2D").position.y and hat.offset.y < -10.0,
		"his bow's worn in front of his head (after him in the y-sort, drawn up on his head)")
	_expect(player.global_position.distance_to(start) < 60.0, "in his bedroom, where a new climb starts")
	await _wait(1.0)
	_expect(main._tv_done, "and the TV has its words for him")
	var info: Dictionary = root.get_node("Party").my_info()
	_expect(int(info.look.body) == 3 and int(info.look.band) == 1 and info.hat == "bow", "his party sees his look (%s)" % [info])

	# Next time: straight to the climb.
	main.queue_free()
	await _frames(3)
	main = await _game()
	player = main.get_node("Player")
	player._on_button_pressed()
	await _frames(3)
	_expect(player.get_node_or_null("CreatorIntro") == null and player.get_node("Trajectory").endGame == 0, "next time, Play's straight to the climb")

	# Not made yet, ENDLESS and PLAY TOGETHER bring the frog god first too: it's how the game starts.
	var made: Dictionary = mm.look.duplicate()
	var made_hat: String = mm.equipped_hat
	mm.look_made = false
	main.queue_free()
	await _frames(3)
	main = await _game()
	player = main.get_node("Player")
	player._on_endlessmodebutton_pressed()
	await _frames(3)
	var first = player.get_node_or_null("CreatorIntro")
	_expect(first != null and root.get_node_or_null("EndlessMode") == null and is_instance_valid(main) and main.is_inside_tree(),
		"a new player's ENDLESS brings the frog god first, not Endless")
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
			screen.closed.emit()
			await _frames(2)
			_expect(player.get_node("titlescreen").visible, "and closing it, the title's there")
	await _until(func() -> bool: return player.get_node_or_null("CreatorIntro") == null, 3.0)
	mm.look = made
	mm.equipped_hat = made_hat
	mm.look_made = true
	main.queue_free()
	await _frames(3)
	main = await _game()
	player = main.get_node("Player")
	player._on_button_pressed()  # (climbing again, as before)
	await _frames(3)

	# The wardrobe's CHANGE YOUR LOOK: just the choosing; the climb goes on.
	var ws: CanvasLayer = load("res://scenes/WardrobeScreen.gd").new()
	player.add_child(ws)
	await _frames(3)
	var change: Button = ws.find_child("ChangeLookButton", true, false)
	_expect(change != null and change.visible, "the wardrobe has CHANGE YOUR LOOK")
	if change:
		change.pressed.emit()
		await _frames(3)
		var again = root.get_node_or_null("CreatorIntro")
		_expect(again != null and again.from_wardrobe and again._words.text == "WHAT DO YOU LOOK LIKE?" and again._shadow < 0.05,
			"which goes straight to \"what do you look like?\", no shadow")
		if again:
			again._advance()
			again._change("body", 1)
			again._ask_sure()
			again._yes()
			await _until(func() -> bool: return not is_instance_valid(again), 6.0)
			_expect(int(mm.look.body) == 4 and is_instance_valid(main) and player.get_node("Trajectory").endGame == 0,
				"and back, his new look kept, the climb as it was")
	ws.queue_free()

	# Unlocks: once each.
	_expect(mm.unlock("shiny") and not mm.unlock("shiny") and "shiny" in mm.unlocked_skins, "an unlock's yours once (and again does nothing)")
	var tiles: Node = main.get_node("TileMap")
	for _i in 24:
		tiles._counted_bounce()
	_expect(not "mushroom" in mm.unlocked_skins and mm.mushroom_bounces == 24, "24 mushroom bounces: not yet")
	tiles._counted_bounce()
	_expect("mushroom" in mm.unlocked_skins, "the 25th: the Mushroom hat")
	await _until(func() -> bool: return player.is_on_floor(), 2.0)
	player.was_airborne = true
	player._fall_top = player.currentHeight + 160.0
	await _frames(4)
	_expect("ghost" in mm.unlocked_skins, "a really big fall: the Ghost skin")

	# A friend's frog, in their look.
	var frog := Node2D.new()
	frog.set_script(load("res://scripts/PartyFrog.gd"))
	main.add_child(frog)
	frog.setup(player, 2, {"name": "@pal", "hat": "tophat", "skin": "rainbow", "look": {"body": 9, "pattern": 2, "band": 3}})
	var fm: ShaderMaterial = frog._sprite.material
	_expect(fm.get_shader_parameter("body_colour") == look.BODY[9][1] and fm.get_shader_parameter("effect") == 2
		and frog._hats.has("LookHat") and frog._hats.LookHat.visible and frog._hats.LookHat.texture == look.hat_texture("tophat"),
		"a friend's frog wears their look: colour, pattern, skin and hat")
	_expect(frog._hats.LookHat.get_index() > frog._sprite.get_index() and frog._hats.Froggycrown.get_index() < frog._sprite.get_index(),
		"their drawn hat in front of their head, the crown behind it, as on your own")
	_expect(look.material({"body": 5}, "negative_skin").shader.resource_path == "res://assets/negative.gdshader"
		and look.material({"body": 5}, "golden_skin").get_shader_parameter("effect") == 8,
		"the Negative skin is as it always was (the screen behind him, turned over); the others go over his look")

	# The wardrobe: the starter hats are yours; what's still to find says how.
	var ws2: CanvasLayer = load("res://scenes/WardrobeScreen.gd").new()
	player.add_child(ws2)
	await _frames(3)
	var words := ""
	for l in ws2.find_children("*", "Label", true, false):
		words += l.text + " | "
	_expect(words.contains("Beanie") and words.contains("STILL TO FIND") and words.contains("Score 150 in Endless")
		and words.contains("Climb all the way to space in Endless"), "the wardrobe: starters yours, and what's still to find, and how")
	ws2.queue_free()
	await _finish(real, main)


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
