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
	mm.wardrobe_path = WARDROBE
	mm.game_beaten = false
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

	# The TV, as he starts at home.
	player._on_button_pressed()
	for _i in 3:
		await process_frame
	_expect(main._tv_done and main._tv_bubble.visible and main._tv_bubble.text == main.TV_LINES[0], "the TV talks as he starts at home")
	await _game_time(3.0)
	_expect(main._tv_bubble.text == main.TV_LINES[1], "line by line (%s)" % main._tv_bubble.text.c_escape())
	await _game_time(9.0)
	_expect(not main._tv_bubble.visible, "and goes back to static")

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

	# The lost frog: the hint, first time, without the key.
	main.npc4 = 0
	main._on_area_2d_4_body_shape_entered(RID(), player, 0, 0)
	await _game_time(6.5)
	_expect(main.get_node("frogNPC4/npc4speechbubble").text.begins_with("they say there's a key"), "the lost frog hints at the key")
	await _game_time(4.0)

	# The gate open and him well up: the lost frog turns up by the castle, and thanks him.
	main.gateDestroyed = 1
	await _put(player, Vector2(3150, -5680))
	for _i in 3:
		await process_frame
	_expect(main.get_node("frogNPC4").position == main.LOST_FROG_TOP, "the lost frog turns up by the castle once the gate's open")
	main._on_area_2d_4_body_shape_entered(RID(), player, 0, 0)
	_expect(main.get_node("frogNPC4/npc4speechbubble").text == "i followed your jumps...", "and thanks him")

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

	# The win screen, upright: every line of its words across the screen. (No Lil Froggy let out onto this
	# computer's desktop by it.)
	var real_frog_out: bool = mm.desktop_frog_unlocked
	mm.desktop_frog_unlocked = true
	player.finalTime = "12:34"
	player.jumpCount = 1234
	player._on_end_animation_finished()
	for _i in 2:
		await process_frame
	mm.desktop_frog_unlocked = real_frog_out
	for path in ["winscreen/congrats", "winscreen/time2"]:
		var label: Label = player.get_node(path)
		var size: int = label.get_theme_font_size("font_size")
		var widest := 0.0
		for line in label.text.split("\n"):
			widest = maxf(widest, label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		_expect(widest + 2.0 * label.get_theme_constant("outline_size") <= PORTRAIT.x - 16.0,
			"%s fits across a phone held upright (%d px at %d)" % [path, int(widest), size])

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
	mm.wardrobe_path = real_wardrobe
	mm.game_beaten = real_beaten
	main.queue_free()
	_finish()


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
