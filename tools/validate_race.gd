extends SceneTree
## Headless check of Endless's party races (PartyRace), each of the four, with a friend in the party (their
## frog and their news fed in as Party would): nobody jumps till GO; the clock and the standings; a fall
## puts you back on a platform (no game over), except in a knockout, where you're out and watch the others;
## each race ends as it should (the minute's up, someone's at 100 m, the last frog in) with the places in
## the right order; and finishing a race unlocks the next, one by one, till you have them all (the party
## screen's locked ones greyed). The high score and the wardrobe save to scratch files; yours are byte-checked.
##   Godot --headless --path . --script res://tools/validate_race.gd


class ErrorCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


class FakeFly extends Node2D:
	var golden := false


const SCORES := "user://test_race_highscore.dat"
const WARDROBE := "user://test_race_wardrobe.save"
const PAL := 2

var _counter := ErrorCounter.new()
var _failures: Array[String] = []
var _said: Array = []


func _initialize() -> void:
	OS.add_logger(_counter)
	_run.call_deferred()


func _run() -> void:
	var mm := root.get_node("MusicManager")
	var party := root.get_node("Party")
	var real_path: String = mm.wardrobe_path
	var real_wardrobe := FileAccess.get_file_as_bytes(real_path)
	var real_scores := FileAccess.get_file_as_bytes("user://endless_highscore.dat")
	var real_modes: Array = mm.unlocked_modes.duplicate()
	mm.wardrobe_path = WARDROBE
	mm.unlocked_modes = []
	var race_script: GDScript = load("res://scripts/PartyRace.gd")
	_expect(race_script.has("minute") and not race_script.has("sprint") and not race_script.has("knockout"),
		"to start with, just the minute race")

	# MINUTE RACE: 3, 2, 1, GO; the standings; a fall's no game over; the minute's up; the next race unlocked.
	var e := await _race("minute")
	var race: Node = e._race
	var aim: Node = e.player.get_node("Trajectory")
	_expect(race != null and race.kind == "minute", "a minute race")
	_expect(aim.endGame == 1, "nobody jumps before GO")
	_expect(e.score_label.text == "1:00" and e._titles.showing == "MINUTE RACE" and e._banner_sub.text == "Climb the highest in a minute!",
		"its clock, its name and how it's won (%s, %s, %s)" % [e.score_label.text, e._titles.showing, e._banner_sub.text])
	party.run_started_ms -= 3200
	await _frames(4)
	_expect(aim.endGame == 0, "GO: off they go")
	e._on_frog_moved(PAL, [0.0, -420.0, "default", 0, false, 0.0, 0, 42, 0, 0, 0])
	var rows: Array = race.rows()
	_expect(rows.size() == 2 and rows[0].peer == PAL and rows[0].m == 42, "the standings: the friend at 42 m ahead of him")
	await _frames(20)
	_expect(race._standings.get_child_count() == 2, "both in the corner's standings")
	var p: CharacterBody2D = e.player
	p.global_position.y = e.highest_player_y + e.fail_y_threshold + 50.0
	await _frames(3)
	_expect(not e.is_resetting and race._respawn_left >= 0.0, "a fall in a race: no game over, he's put back in a moment")
	await create_timer(1.3).timeout
	_expect(p.visible and p.global_position.y < e.highest_player_y + 100.0, "back on a platform (%.0f, best %.0f)"
		% [p.global_position.y, e.highest_player_y])
	party.run_started_ms -= 61000
	await _frames(4)
	_expect(race.over and aim.endGame == 1 and _said.any(func(w) -> bool: return w.get("k") == "done"), "the minute's up: it's over")
	_expect(mm.unlocked_modes == ["sprint"] and race.newly == "sprint", "finishing it unlocks the next race (%s)" % [mm.unlocked_modes])
	await create_timer(1.6).timeout
	var words := _words(race.results)
	_expect(words.contains("1st  @pal  42 m") and words.contains("@pal won!") and words.contains("New race unlocked: Sprint to 100 m!")
		and words.contains("Race Again"), "the results: the places, who won, what's unlocked, again (%s)" % words)
	await _end(e)

	# SPRINT TO 100 M: the first there wins, him or the friend.
	e = await _race("sprint")
	race = e._race
	party.run_started_ms -= 3200
	await _frames(4)
	_expect(e._height_label.text.ends_with(" / 100 m"), "a sprint counts to 100 m (%s)" % e._height_label.text)
	e.highest_player_y = -1005.0
	e._climbed()
	_expect(race.over and race._winner == party.me() and _said.any(func(w) -> bool: return w.get("k") == "won"),
		"at 100 m he's won, and says so")
	await create_timer(1.6).timeout
	_expect(_words(race.results).contains("You won!"), "the results: he won")
	_expect(mm.unlocked_modes == ["sprint", "flies"], "the next race unlocked (%s)" % [mm.unlocked_modes])
	await _end(e)
	e = await _race("sprint")
	race = e._race
	party.run_started_ms -= 3200
	await _frames(4)
	race.heard(PAL, {"k": "won", "s": 21.5, "m": 100})
	_expect(race.over and race._winner == PAL, "the friend there first: they've won")
	await create_timer(1.6).timeout
	_expect(_words(race.results).contains("@pal won!"), "the results: the friend won")
	await _end(e)

	# FLY RUSH: flies by most platforms (the same ones for everyone), the most in a minute wins.
	e = await _race("flies")
	race = e._race
	await _frames(30)
	var platforms: int = e.next_platform_id
	_expect(e._flies.size() >= (platforms - 6) * 0.6, "a fly rush: flies by most platforms (%d by %d)" % [e._flies.size(), platforms])
	party.run_started_ms -= 3200
	await _frames(4)
	for i in 3:
		var fly := FakeFly.new()
		e.add_child(fly)
		e._on_fly_caught(fly)
		fly.queue_free()
	await _frames(2)
	_expect(race.flies == 3 and e._height_label.text == "3 flies", "three flies caught (%s)" % e._height_label.text)
	e._on_frog_moved(PAL, [0.0, -300.0, "default", 0, false, 0.0, 0, 30, 0, 5, 0])
	party.run_started_ms -= 61000
	await _frames(4)
	await create_timer(1.6).timeout
	rows = race.rows()
	_expect(race.over and rows[0].peer == PAL and _words(race.results).contains("1st  @pal  5 flies"),
		"the minute's up: the friend's 5 flies beat his 3")
	await _end(e)

	# KNOCKOUT: a fall and he's out (watching the friend); the last frog in wins.
	e = await _race("knockout")
	race = e._race
	party.run_started_ms -= 3200
	await _frames(4)
	_expect(e.score_label.text == "2 left", "a knockout counts who's left (%s)" % e.score_label.text)
	e._on_frog_moved(PAL, [0.0, -800.0, "default", 0, false, 0.0, 0, 33, 0, 0, 0])
	p = e.player
	p.global_position.y = e.highest_player_y + e.fail_y_threshold + 50.0
	await _frames(3)
	_expect(race.out and not p.visible and _said.any(func(w) -> bool: return w.get("k") == "out"), "a fall: he's out, and says so")
	_expect(race.watch_y() == -800.0, "and watches the friend still in it")
	await _frames(4)
	_expect(race.over, "with one frog left in, it's over")
	await create_timer(1.6).timeout
	_expect(_words(race.results).contains("1st  @pal  33 m") and _words(race.results).contains("@pal won!"),
		"the results: the friend, last in, won")
	_expect(mm.unlocked_modes == ["sprint", "flies", "knockout"] and race_script.unlock_next() == "",
		"one more each race, till he has them all (%s)" % [mm.unlocked_modes])
	await _end(e)

	# The party screen's races: the ones he has to start; the rest there, greyed.
	mm.unlocked_modes = ["sprint"]
	var screen: CanvasLayer = load("res://scenes/PartyScreen.gd").new()
	root.add_child(screen)
	await _frames(2)
	for old in screen._box.get_children():
		old.queue_free()
	await _frames(1)
	screen._starts()
	var buttons := {}
	for b in screen._box.get_children():
		if b is Button:
			buttons[b.text] = not b.disabled
	_expect(buttons.get("Minute Race") == true and buttons.get("Sprint to 100 m") == true and buttons.get("Fly Rush") == false
		and buttons.get("Knockout") == false, "the party screen: Minute Race and Sprint to start, Fly Rush and Knockout locked (%s)" % [buttons])
	_expect(_words(screen).contains("Finish a race to unlock the next one."), "and how to unlock the rest")
	screen.queue_free()

	party.in_run = false
	party.race = ""
	party.players = {}
	mm.unlocked_modes = real_modes
	mm.wardrobe_path = real_path
	for f in [SCORES, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	if FileAccess.get_file_as_bytes(real_path) != real_wardrobe:
		_failures.append("the real wardrobe save changed")
	if FileAccess.get_file_as_bytes("user://endless_highscore.dat") != real_scores:
		_failures.append("the real Endless high score changed")
	for err in _counter.errors:
		_failures.append("script error: " + err)
	if _failures.is_empty():
		print("Race test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Race test failed (%d)." % _failures.size())
	quit(0 if _failures.is_empty() else 1)


## A race of `kind` for him and a friend (@pal), just started: the countdown's on.
func _race(kind: String) -> Node:
	var party := root.get_node("Party")
	party.players = {party.me(): {"name": "@me"}, PAL: {"name": "@pal"}}
	party.in_run = true
	party.mode = "endless"
	party.race = kind
	party.run_seed = 20261105
	party.run_started_ms = Time.get_ticks_msec()
	_said.clear()
	var e: Node = (load("res://scenes/EndlessMode.tscn") as PackedScene).instantiate()
	e.save_path = SCORES
	root.add_child(e)
	await _frames(6)
	e._race.said.connect(func(what: Dictionary) -> void: _said.append(what))
	return e


func _end(e: Node) -> void:
	e.queue_free()
	await _frames(3)


func _words(node: Node) -> String:
	var all := []
	if node == null:
		return ""
	for n in node.find_children("*", "", true, false):
		if n is Label or n is Button:
			all.append(n.text)
	return " | ".join(all)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
		push_warning("FAIL: " + what)
