extends SceneTree
## Froggy's jump, against the original's (copied in below), for the story's and Endless's slingshots alike:
## - The same jump wherever the original ran smoothly: every short and medium drag, every upright one, and
##   full power (the petals' "full strength" jumps), to the number, upward speed always; and a mushroom
##   feels him moving sideways exactly when it did.
## - Smooth: pulling a little further never makes the jump (or the aim line) jump; it only ever grows.
##   (The original suddenly flew 200 slower sideways past a 450 stretch.)
## - Nothing lost: every jump the original could make, some drag still makes, so the climb built around
##   them can still be climbed.
## - A spring multiplies it; a jump still goes just after leaving a platform's edge (can_jump), but not
##   long after, and from just off the edge it flies where the line shows.
## - Real jumps in Endless go where the aim line points.
##   Godot --headless --path . --script res://tools/validate_froggy_jump.gd

const STRETCH := 3.5 * 1.5  # (the original's sideways stretch per pixel of drag, at the default aim)

var _failures: Array[String] = []


## The original drag-to-jump, as it was in Trajectory.gd before (kept here to check against).
static func _original(path: Vector2) -> Vector2:
	var velocity = path * 3.5
	velocity.x *= 1.5
	velocity.y *= 1.1
	velocity.x = clamp(velocity.x, -800, 800)
	velocity.y = clamp(velocity.y, -450, 450)
	if abs(velocity.x) < 450:
		velocity.y *= 1.0
		velocity.x = 200 * sign(velocity.x) + velocity.x
	if abs(velocity.x) < 450 and abs(velocity.y) > 350:
		velocity.y *= 1.0
		velocity.x = 50 * sign(velocity.x) + velocity.x
	return velocity


## How he flies after the friction tick, for a launch.
static func _flight(launch: Vector2) -> Vector2:
	return Vector2(move_toward(launch.x, 0.0, 300.0), launch.y)


class Springy extends CharacterBody2D:
	var boost := 1.0
	func launch_boost() -> float:
		return boost


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void:  # (a script error mustn't leave it running)
		push_warning("FAIL: the jump test didn't finish")
		quit(2))
	await process_frame
	var story := _slingshot("res://scripts/Trajectory.gd", CharacterBody2D.new())
	var springy := Springy.new()
	var endless := _slingshot("res://scenes/endlessplayertrajectory.gd", springy)

	# The same jump where the original ran smoothly; upward speed always; the mushroom's "moving sideways".
	var drags := 0
	var same := 0
	var off := []
	for x in range(-260, 261, 3):
		for y in range(-260, 261, 3):
			var path := Vector2(x, y) * 0.97
			var want := _original(path)
			var got: Vector2 = story.launch_velocity(path)
			drags += 1
			if got != endless.launch_velocity(path):
				off.append("%s: Endless differs from the story" % path)
			if got.y != want.y:
				off.append("%s: upward %.1f, the original %.1f" % [path, got.y, want.y])
			if (got.x != 0.0) != (want.x != 0.0):
				off.append("%s: a mushroom would feel it moving sideways %s, the original %s" % [path, got.x != 0.0, want.x != 0.0])
			var ax := absf(path.x) * STRETCH
			var ay := absf(want.y)
			var kept := (ax <= 350.0 and ay <= 330.0) or (ax <= 200.0 and ay >= 370.0) or ax >= 800.0
			if kept:
				same += 1
				if absf(_flight(got).x - _flight(want).x) > 0.001:
					off.append("%s: flies %.2f sideways, the original %.2f" % [path, _flight(got).x, _flight(want).x])
	_expect(off.is_empty(), "the same jump wherever the original ran smoothly (%s)" % ("; ".join(off.slice(0, 4)) if off else "ok"))

	# Smooth and only growing: sweeping the drag sideways a tenth of a pixel at a time, at many heights.
	var worst_step := 0.0
	var shrinks := 0
	var original_worst := 0.0
	for y in range(-130, 131, 5):
		var last := -1.0
		var last_original := -1.0
		var x := 0.0
		while x <= 200.0:
			var fly: float = absf(story.flight_velocity(Vector2(x, y)).x)
			var fly_original: float = absf(_flight(_original(Vector2(x, y))).x)
			if last >= 0.0:
				worst_step = maxf(worst_step, absf(fly - last))
				original_worst = maxf(original_worst, absf(fly_original - last_original))
				if fly < last - 0.0001:
					shrinks += 1
			last = fly
			last_original = fly_original
			x += 0.1
	_expect(worst_step < 1.0, "pulling a little further never makes the jump jump (worst %.2f a tenth of a pixel; the original's %.0f)" % [worst_step, original_worst])
	_expect(shrinks == 0, "and pulling further never makes it shorter (%d times)" % shrinks)
	var worst_up := 0.0
	for x in range(-150, 151, 7):
		var last := INF
		var y := -130.0
		while y <= 130.0:
			var fly: float = story.flight_velocity(Vector2(x, y)).x
			if last != INF:
				worst_up = maxf(worst_up, absf(fly - last))
			last = fly
			y += 0.1
	_expect(worst_up < 1.0, "nor pulling a little higher or lower (worst %.2f)" % worst_up)

	# Nothing lost: at every height, every sideways speed the original could fly, some drag still flies.
	var missing := []
	for y in range(-130, 131, 5):
		# (what this height reaches, sweeping sideways: from its least to its most, never a gap of a whole
		# unit between neighbours, so every speed in between is there)
		var least := INF
		var most := -INF
		var gap := 0.0
		var last := -1.0
		var x := 0.0
		while x <= 200.0:
			var fly := absf(story.flight_velocity(Vector2(x, y)).x)
			least = minf(least, fly)
			most = maxf(most, fly)
			if last >= 0.0:
				gap = maxf(gap, absf(fly - last))
			last = fly
			x += 0.1
		if gap > 1.0:
			missing.append("a gap of %.1f at drag height %d" % [gap, y])
		for xo in range(0, 201, 2):
			var want_fly: float = absf(_flight(_original(Vector2(xo, y))).x)
			if want_fly < least - 1.0 or want_fly > most + 1.0:
				missing.append("%.0f sideways at drag height %d" % [want_fly, y])
	_expect(missing.is_empty(), "every jump the original could make is still there (%s)" % ("; ".join(missing.slice(0, 4)) if missing else "ok"))

	springy.boost = 1.55
	_expect(endless.launch_velocity(Vector2(-40, 70)) == story.launch_velocity(Vector2(-40, 70)) * 1.55, "off a spring, the same jump 1.55 times as fast")
	springy.boost = 1.0

	for sling in [story, endless]:
		sling._floor_ms = Time.get_ticks_msec() - 60
		_expect(sling.can_jump(), "a jump still goes just after leaving a platform's edge")
		sling._floor_ms = Time.get_ticks_msec() - 400
		_expect(not sling.can_jump(), "but not long after (not a jump in mid-air)")
		# (in the air: these frogs aren't on any floor)
		_expect(sling.release_velocity(Vector2(60, -90)) == sling.flight_velocity(Vector2(60, -90)),
			"just off an edge, letting go gives the flight the line shows (no friction tick to take the push back)")

	await _real_jumps()

	if _failures.is_empty():
		print("Froggy jump test passed (%d drags, %d the same as the original's)." % [drags, same])
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Froggy jump test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## Real jumps off the first lily pad, in Endless itself: the aim line (flight_velocity) must point the way
## he really flies, sideways speed and all (near-upright drags go near straight up). Scratch scores and
## wardrobe; yours are byte-checked by the caller.
func _real_jumps() -> void:
	var mm := root.get_node("MusicManager")
	var real_wardrobe: String = mm.wardrobe_path
	mm.wardrobe_path = "user://test_jump_wardrobe.save"
	var endless: Node2D = (load("res://scenes/EndlessMode.tscn") as PackedScene).instantiate()
	endless.save_path = "user://test_jump_scores.dat"
	root.add_child(endless)
	for _f in 30:
		await process_frame
	var frog: CharacterBody2D = endless.player
	var sling: Node2D = frog.get_node("Trajectory")
	var worst := 0.0
	for path in [Vector2(0, -100), Vector2(5, -80), Vector2(-12, -95), Vector2(40, -60), Vector2(-60, -40), Vector2(70, -90), Vector2(120, -30), Vector2(150, -110)]:
		frog.global_position = Vector2(0.0, -24.0)
		frog.velocity = Vector2.ZERO
		frog.reset_physics_interpolation()
		for _f in 40:
			await physics_frame
			if frog.is_on_floor():
				break
		var shown: Vector2 = sling.flight_velocity(path)
		frog.velocity = sling.release_velocity(path)  # (as letting go does)
		await physics_frame
		await physics_frame
		worst = maxf(worst, absf(frog.velocity.x - shown.x))
		if absf(frog.velocity.x - shown.x) > 0.5:
			_failures.append("drag %s: the line shows %.0f sideways, he flies %.0f" % [path, shown.x, frog.velocity.x])
	_expect(worst <= 0.5, "the aim line points where he really flies (worst %.1f off sideways)" % worst)
	endless.queue_free()
	await process_frame
	mm.wardrobe_path = real_wardrobe
	for f in ["user://test_jump_wardrobe.save", "user://test_jump_scores.dat"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


## A slingshot on a frog of its own (not in any level: nothing jumps).
func _slingshot(path: String, frog: CharacterBody2D) -> Node2D:
	root.add_child(frog)
	var sling := Node2D.new()
	sling.set_script(load(path))
	sling.set_process(false)
	frog.add_child(sling)
	return sling


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
