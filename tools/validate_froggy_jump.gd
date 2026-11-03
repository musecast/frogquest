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

	if _failures.is_empty():
		print("Froggy jump test passed (%d drags)." % drags)
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Froggy jump test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


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
