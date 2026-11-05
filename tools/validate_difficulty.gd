extends SceneTree
## The difficulties (Difficulty.gd, AimLine.gd) in the real level: how much of the jump each one's aim line
## shows (Easy all of it, Normal its first part, Hard a short start, OG the first game's straight line);
## the colour going red at full power; the arc being where he really flies, tick for tick; each climb
## remembering the easiest it's been played on (Hard from its first jump, for OG); the top reached on Hard
## unlocking OG mode and the achievements, and its news at the title; OG not to be chosen till then; all of
## it kept with the wardrobe. Scratch save and wardrobe; yours are byte-checked by the caller.
##   Godot --headless --path . --script res://tools/validate_difficulty.gd

const SAVE := "user://test_difficulty_save_game.save"
const WARDROBE := "user://test_difficulty_wardrobe.save"

var _failures: Array[String] = []
var _view: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		_failures.append("timed out")
		_finish())
	var mm := root.get_node("MusicManager")
	var real := [mm.wardrobe_path, mm.look_made, mm.difficulty, mm.og_unlocked, mm.og_seen, mm.achievements.duplicate(), mm.game_beaten]
	mm.wardrobe_path = WARDROBE
	mm.look_made = true
	mm.difficulty = "normal"
	mm.og_unlocked = false
	mm.og_seen = false
	mm.achievements = []
	var aim: Script = load("res://scripts/AimLine.gd")
	var difficulty: Script = load("res://scripts/Difficulty.gd")

	# How much each one shows, and the colour.
	var points := PackedVector2Array()
	for i in 41:
		points.append(Vector2(i * 6.0, -i * 2.0))
	_expect(aim.shown(points, "easy").size() == points.size(), "Easy shows all of the jump")
	var normal: PackedVector2Array = aim.shown(points, "normal")
	_expect(normal.size() > points.size() / 2 and normal.size() < points.size() * 0.75, "Normal past the middle, not the end (%d of %d)" % [normal.size(), points.size()])
	var hard: PackedVector2Array = aim.shown(points, "hard")
	var hard_length := 0.0
	for i in range(1, hard.size()):
		hard_length += hard[i].distance_to(hard[i - 1])
	_expect(absf(hard_length - aim.HARD_LENGTH) < 0.5, "Hard a short start (%.1f px)" % hard_length)
	_expect(aim.shown(points, "og").is_empty(), "OG draws no arc (its own line)")
	var red: Color = aim.heat(1.0)
	var cream: Color = aim.heat(0.0)
	_expect(red.r > 0.8 and red.g < 0.35 and cream.g > 0.9, "cream for a little pull, red at full power")

	# The real level: a new climb takes the difficulty chosen.
	_view = SubViewport.new()
	_view.size = Vector2i(480, 698)
	root.add_child(_view)
	for f in [SAVE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var main := await _game()
	var player: CharacterBody2D = main.get_node("Player")
	_expect(player.easiest_rank == difficulty.rank("normal"), "a new climb is Normal by default (%d)" % player.easiest_rank)
	player.set_difficulty("og")
	_expect(mm.difficulty == "normal", "OG can't be chosen before it's unlocked")
	_expect(not "og" in difficulty.choices(), "and it's not in the settings")
	player.set_difficulty("hard")
	_expect(player.easiest_rank == difficulty.rank("hard") and mm.difficulty == "hard", "Hard chosen before the first jump: the climb's Hard")

	# The arc is where he really flies.
	main._tv_done = true
	player._on_button_pressed()
	player.waking = false
	main._tv_listening = false
	player.global_position = Vector2(1700, -480)
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	for _i in 40:
		await physics_frame
	var sling: Node2D = player.get_node("Trajectory")
	var worst := 0.0
	for pull in [Vector2(40, -60), Vector2(-70, -90), Vector2(150, -110)]:
		player.global_position = Vector2(1700, -480)
		player.velocity = Vector2.ZERO
		player.reset_physics_interpolation()
		for _i in 40:
			await physics_frame
			if player.is_on_floor():
				break
		var predicted: PackedVector2Array = aim.path(player, sling.shown_velocity(pull))
		player.velocity = sling.release_velocity(pull)
		var flown := PackedVector2Array([player.global_position])
		for _i in predicted.size() - 1:
			await physics_frame
			flown.append(player.global_position)
		for i in mini(flown.size(), predicted.size()):
			worst = maxf(worst, flown[i].distance_to(predicted[i]))
	_expect(worst < 3.0, "the arc's where he really flies, tick for tick (worst %.1f px off)" % worst)

	# Each climb remembers the easiest it's been played on.
	player.jumpCount = 3
	player.set_difficulty("easy")
	_expect(player.easiest_rank == difficulty.rank("easy"), "Easy partway: the climb's Easy now")
	player.set_difficulty("hard")
	_expect(player.easiest_rank == difficulty.rank("easy") and not player.climb_is_hard(), "and Hard again doesn't make it Hard (from its first jump only)")
	player.save_game()
	main.queue_free()
	await process_frame
	main = await _game()
	player = main.get_node("Player")
	_expect(player.easiest_rank == difficulty.rank("easy"), "the climb remembers it (saved)")

	# The top, on Normal: the achievement, no OG. On Hard: OG mode and its achievement, and its news.
	player.easiest_rank = difficulty.rank("normal")
	player._record_win()
	_expect("beat_game" in mm.achievements and not "beat_hard" in mm.achievements and not mm.og_unlocked, "the top on Normal: Top of the Tree, not OG")
	player.easiest_rank = difficulty.rank("hard")
	player._record_win()
	_expect("beat_hard" in mm.achievements and mm.og_unlocked and not mm.og_seen, "the top on Hard: Hard Hopper, and OG mode unlocked")
	_expect(mm.achievements.size() == 2, "each earned once (%s)" % [mm.achievements])
	_expect("og" in difficulty.choices(), "OG in the settings now")
	player.easiest_rank = difficulty.rank("og")
	player._record_win()
	_expect("beat_og" in mm.achievements, "the top in OG mode: True OG")
	mm.save_wardrobe()
	var kept := [mm.og_unlocked, mm.achievements.duplicate(), mm.difficulty]
	mm.og_unlocked = false
	mm.achievements = []
	mm.load_wardrobe()
	_expect(mm.og_unlocked == kept[0] and mm.achievements == kept[1] and mm.difficulty == kept[2], "kept with the wardrobe")

	# Its news at the title, once.
	main.queue_free()
	await process_frame
	main = await _game()
	player = main.get_node("Player")
	var news: Node = main.get_node_or_null("OgNews")
	_expect(news != null, "OG Mode Unlocked! at the title (title up %s, unlocked %s, read %s)" % [player.get_node("titlescreen").visible, mm.og_unlocked, mm.og_seen])
	if news:
		news._try()
		await process_frame
		_expect(mm.og_seen and mm.difficulty == "og", "Try OG Mode: chosen, and read")
	main.queue_free()
	await process_frame
	main = await _game()
	_expect(main.get_node_or_null("OgNews") == null, "and not again")
	main.queue_free()
	for _i in 3:
		await process_frame
	mm.wardrobe_path = real[0]
	mm.look_made = real[1]
	mm.difficulty = real[2]
	mm.og_unlocked = real[3]
	mm.og_seen = real[4]
	mm.achievements = real[5]
	mm.game_beaten = real[6]
	_finish()


func _game() -> Node:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	main.get_node("Player").save_path = SAVE
	_view.add_child(main)
	for _i in 10:
		await process_frame
	return main


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _finish() -> void:
	Engine.time_scale = 1.0
	for f in [SAVE, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	if _failures.is_empty():
		print("Difficulty test passed.")
	else:
		for f in _failures:
			print("  FAILED: ", f)
		print("Difficulty test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
