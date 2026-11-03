extends SceneTree
## Headless check of Endless mode's climb. Plays a run from the lily pad to outer space by putting
## Froggy on each new platform in turn (the game's own physics lands him), and fails on any script
## error, or if:
##   - a gap between platforms is more than a full jump reaches in the gravity up there,
##   - the zones don't arrive in order (swamp, treetops, clouds, sunset, space), or space isn't floaty,
##   - his score doesn't climb, a spring doesn't boost his jump, or a crumbling platform doesn't go,
##   - old platforms aren't cleaned up below him,
##   - "keep going" doesn't put him back on a platform after a fall.
## The high score and the wardrobe save to scratch files meanwhile; yours are byte-checked.
##   Godot --headless --path . --script res://tools/validate_endless.gd


class ErrorCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


const SCORES := "user://test_endless_highscore.dat"
const WARDROBE := "user://test_endless_wardrobe.save"

var _counter := ErrorCounter.new()
var _failures: Array[String] = []
var _real_scores := PackedByteArray()
var _real_wardrobe := PackedByteArray()
var _real_wardrobe_path := ""


func _initialize() -> void:
	OS.add_logger(_counter)
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
		push_warning("FAIL: " + what)


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	var mm := root.get_node("MusicManager")
	_real_wardrobe_path = mm.wardrobe_path
	_real_wardrobe = FileAccess.get_file_as_bytes(_real_wardrobe_path)
	_real_scores = FileAccess.get_file_as_bytes("user://endless_highscore.dat")
	mm.wardrobe_path = WARDROBE
	for f in [SCORES, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)

	var endless: Node2D = (load("res://scenes/EndlessMode.tscn") as PackedScene).instantiate()
	endless.save_path = SCORES
	root.add_child(endless)
	await _frames(30)
	var player: CharacterBody2D = endless.player
	var zones: Script = load("res://scripts/EndlessZones.gd")

	# Every gap in what's been made so far, and as more is made on the way up, is jumpable.
	var checked_gaps := {}
	var zones_seen: Array[int] = []
	var spring_boosted := false
	var crumble_went := false
	var max_platforms := 0
	var last_id := 1
	for step in 170:
		_check_gaps(endless, zones, checked_gaps)
		var next = _next_platform(endless, last_id)
		if next == null:
			_failures.append("no platform above #%d to climb to" % last_id)
			break
		last_id = int(next.get_meta("platform_id"))
		player.global_position = next.global_position + Vector2(0.0, -24.0)
		player.velocity = Vector2.ZERO
		player.reset_physics_interpolation()
		for _f in 40:  # (until he's landed on it)
			await physics_frame
			if player.is_on_floor() and player._floor_body == next:
				break
		var zone: int = zones.index_at(-player.global_position.y)
		if zones_seen.is_empty() or zones_seen[-1] != zone:
			zones_seen.append(zone)
		if next.spring and not spring_boosted:
			spring_boosted = player.is_on_floor() and is_equal_approx(player.launch_boost(), 1.55)
		if next.crumbles and not crumble_went:
			await _frames(60)  # (it gives way 0.6 s after he lands)
			crumble_went = not is_instance_valid(next) or not next.is_solid()
		max_platforms = maxi(max_platforms, endless.platforms.get_child_count())
		if zone == 4 and -player.global_position.y > zones.ZONES[4]["from"] + 600.0:
			break
	_expect(zones_seen == [0, 1, 2, 3, 4], "the zones came in order, swamp to space (saw %s)" % str(zones_seen))
	_expect(endless.score > 50, "the score climbed (%d)" % endless.score)
	var by_log: int = endless.score_of_log(endless.run_log())
	_expect(by_log == endless.score, "the run's log gives the score the game gave (%d by the log, %d in the game)" % [by_log, endless.score])
	_expect(is_equal_approx(player.gravity, 980.0 * 0.6), "space is floaty (gravity %.0f)" % player.gravity)
	_expect(spring_boosted, "a spring boosts the jump off it")
	_expect(crumble_went, "a crumbling platform gave way after he landed on it")
	_expect(max_platforms < 80, "old platforms are cleaned up below him (at most %d)" % max_platforms)
	_expect(endless._zone_reached == 4, "each zone's banner showed as he reached it")

	# Fall, then keep going.
	player.global_position.y += 1400.0
	player.velocity = Vector2.ZERO
	await _frames(10)
	_expect(endless.is_resetting, "falling far below his best ends the run")
	_expect(endless.can_revive(), "a run that's just ended can keep going")
	await endless.revive()
	await _frames(20)
	_expect(not endless.is_resetting and player.is_on_floor(), "keep going put him back on a platform")
	_expect(endless.score_of_log(endless.run_log()) == endless.score, "after keeping going, the log still gives the game's score")
	_check_scorer_vectors(endless)

	# Pause: the climb stops under a menu, and carries on.
	endless.pause()
	_expect(paused and endless._pause_screen != null, "the pause button pauses, under a menu")
	endless._unpause()
	_expect(not paused and endless._pause_screen == null, "Resume carries on")

	# Into the pond, on the screen: a splash, he's gone under, the run's over.
	endless._cam_y = 0.0
	player.global_position = Vector2(0.0, 40.0)
	player.velocity = Vector2(0.0, 300.0)
	await _frames(5)
	_expect(endless._splashed and not player.visible and endless.is_resetting, "falling into the pond splashes, and ends the run")

	endless.queue_free()
	await _frames(5)
	_finish()


## The leaderboard server's own test runs (muse-media-tracker tests/play.test.ts): the game's rule
## (EndlessMode.score_of_log) must score each the same, or posted runs and the game would disagree.
func _check_scorer_vectors(endless: Node) -> void:
	var b := []
	for i in range(1, 10):
		b.append([1000 * i, i + 1, 60 * i, 0])
	var e := []
	for i in range(1, 30):
		e.append([400 * i, i + 1, 150 * i, 0])
	var vectors := {
		"A": [{"landings": [[1000, 2, 60, 0], [2000, 3, 120, 0], [3000, 4, 200, 0], [4000, 5, 260, 0], [5000, 7, 370, 0], [8000, 6, 300, 0], [9000, 8, 420, 0]], "flies": [[2500, 0], [6000, 1]], "end_ms": 12000}, 18],
		"B": [{"landings": b, "flies": [[1500, 1], [2500, 0], [3500, 0]], "end_ms": 20000}, 26],
		"C": [{"landings": [[1000, 2, 100, 0], [2000, 6, 520, 1]], "flies": [], "end_ms": 10000}, 5],
		"D": [{"landings": [[500, 1, 0, 0], [1000, 2, 60, 0], [4000, 4, 150, 0], [4500, 3, 100, 0]], "flies": [], "end_ms": 5000}, 4],
		"E": [{"landings": e, "flies": [], "end_ms": 12000}, 77],
		"F": [{"landings": [], "flies": [], "end_ms": 0}, 0],
	}
	for name in vectors:
		var got: int = endless.score_of_log(vectors[name][0])
		_expect(got == vectors[name][1], "the server's test run %s scores %d here too (got %d)" % [name, vectors[name][1], got])


## The next platform up from the one with this id (by id: they're made in order, bottom to top).
func _next_platform(endless: Node, after_id: int):
	var best = null
	for p in endless.platforms.get_children():
		var id := int(p.get_meta("platform_id", 0))
		if id > after_id and not p.is_queued_for_deletion() and p.is_solid():
			if best == null or id < int(best.get_meta("platform_id")):
				best = p
	return best


func _check_gaps(endless: Node, zones: Script, checked: Dictionary) -> void:
	var by_id := {}
	for p in endless.platforms.get_children():
		by_id[int(p.get_meta("platform_id", 0))] = p
	for id in by_id:
		if checked.has(id) or not by_id.has(id - 1) or id <= 2:
			continue
		checked[id] = true
		var lower = by_id[id - 1]
		var upper = by_id[id]
		var g: float = zones.gravity_at(-upper._home.y)
		var reach := 450.0 * 450.0 / (2.0 * 980.0 * g)
		var rise: float = lower._home.y - upper._home.y
		if lower.motion == "bob":
			rise += lower.motion_range * 0.35
		if upper.motion == "bob":
			rise += upper.motion_range * 0.35
		if rise > reach:
			_failures.append("the jump up to platform #%d is %.0f, more than a full jump's %.0f" % [id, rise, reach])


func _finish() -> void:
	var mm := root.get_node("MusicManager")
	mm.wardrobe_path = _real_wardrobe_path
	for f in [SCORES, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	if FileAccess.get_file_as_bytes(_real_wardrobe_path) != _real_wardrobe:
		var w := FileAccess.open(_real_wardrobe_path, FileAccess.WRITE)
		w.store_buffer(_real_wardrobe)
		_failures.append("the real wardrobe save changed (put back)")
	if FileAccess.get_file_as_bytes("user://endless_highscore.dat") != _real_scores:
		if _real_scores.is_empty():
			DirAccess.remove_absolute("user://endless_highscore.dat")
		else:
			var s := FileAccess.open("user://endless_highscore.dat", FileAccess.WRITE)
			s.store_buffer(_real_scores)
		_failures.append("the real Endless high score changed (put back)")
	for e in _counter.errors:
		_failures.append("script error: " + e)
	if _failures.is_empty():
		print("Endless climb test passed.")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		quit(1)
