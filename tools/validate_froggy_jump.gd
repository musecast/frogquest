extends SceneTree
## Froggy's jump is the original's, to the number: for thousands of drags, the story's and Endless's
## slingshots (launch_velocity) give exactly what the original code gave (copied in below); a spring
## multiplies it; and a jump still goes just after leaving a platform's edge (can_jump), but not long after.
##   Godot --headless --path . --script res://tools/validate_froggy_jump.gd

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


class Springy extends CharacterBody2D:
	var boost := 1.0
	func launch_boost() -> float:
		return boost


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:  # (a script error mustn't leave it running)
		push_warning("FAIL: the jump test didn't finish")
		quit(2))
	await process_frame
	var story := _slingshot("res://scripts/Trajectory.gd", CharacterBody2D.new())
	var springy := Springy.new()
	var endless := _slingshot("res://scenes/endlessplayertrajectory.gd", springy)
	var drags := 0
	var off := 0
	for x in range(-260, 261, 3):
		for y in range(-260, 261, 3):
			var path := Vector2(x, y) * 0.97
			var want := _original(path)
			drags += 1
			if story.launch_velocity(path) != want or endless.launch_velocity(path) != want:
				off += 1
	_expect(off == 0, "every drag jumps as the original did (%d of %d differ)" % [off, drags])
	springy.boost = 1.55
	_expect(endless.launch_velocity(Vector2(-40, 70)) == _original(Vector2(-40, 70)) * 1.55, "off a spring, the same jump 1.55 times as fast")
	springy.boost = 1.0

	for sling in [story, endless]:
		sling._floor_ms = Time.get_ticks_msec() - 60
		_expect(sling.can_jump(), "a jump still goes just after leaving a platform's edge")
		sling._floor_ms = Time.get_ticks_msec() - 400
		_expect(not sling.can_jump(), "but not long after (not a jump in mid-air)")

	await _real_jumps()

	if _failures.is_empty():
		print("Froggy jump test passed (%d drags)." % drags)
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
	for path in [Vector2(0, -100), Vector2(5, -80), Vector2(-12, -95), Vector2(40, -60), Vector2(-60, -40), Vector2(120, -30), Vector2(150, -110)]:
		frog.global_position = Vector2(0.0, -24.0)
		frog.velocity = Vector2.ZERO
		frog.reset_physics_interpolation()
		for _f in 40:
			await physics_frame
			if frog.is_on_floor():
				break
		var shown: Vector2 = sling.flight_velocity(path)
		frog.velocity = sling.launch_velocity(path)  # (as letting go does)
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
