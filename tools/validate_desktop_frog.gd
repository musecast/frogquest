extends SceneTree
## Headless smoke test for Lil Froggy, the desktop frog. Runs each of his behaviours at 8x speed
## in a pretend 1920x1079 screen and fails on any script error, or if he ends up off the screen.
##   Godot --headless --path . --script res://tools/validate_desktop_frog.gd


class ErrorCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


const ROOM := Vector2(1920.0, 1079.0)
const PX := 3
const GAME := Rect2(600.0, 300.0, 800.0, 450.0)

var _froggy
var _states: Dictionary
var _counter := ErrorCounter.new()
var _failures: Array[String] = []
var _left := false
var _saw_shards := false
var _saw_dizzy := false
var _saw_stuck := false
var _saw_words := false
var _told: Array = []  # musiverse events he's sent


func _initialize() -> void:
	OS.add_logger(_counter)
	_run.call_deferred()


func _run() -> void:
	var link = load("res://scripts/DesktopFrogLink.gd")
	_expect(not link.is_launch(), "is_launch() is false without --desktop-frog")
	_expect(not link.from_rect().has_area(), "from_rect() is empty without --from=")
	_expect(not link.is_supported(), "is_supported() is false headless (no transparent windows)")

	var froggy_script = load("res://scripts/DesktopFroggy.gd")
	_states = froggy_script.State
	_froggy = froggy_script.new()
	_froggy.track_os_cursor = false
	_froggy.sounds_on = false
	_froggy.left.connect(func() -> void: _left = true)
	root.add_child(_froggy)
	_froggy.set_room(ROOM, PX)
	Engine.time_scale = 8.0

	_froggy.drop_in(400.0)
	await _until_idle("drop in")
	_expect(is_equal_approx(_froggy.feet.y, ROOM.y), "lands on the floor after dropping in")
	_expect(not _froggy.get_drawn_rects().is_empty(), "reports where he's drawing")
	# Every frame sits on the game's chunky-pixel grid: each 2x2 block all one colour (so whichever
	# pixel the shader keeps he looks the same), no lone specks, and nothing under his feet.
	var frames: SpriteFrames = _froggy._body.sprite_frames
	var problems := []
	for anim in frames.get_animation_names():
		for i in frames.get_frame_count(anim):
			var problem := _frame_problem(frames.get_frame_texture(anim, i), froggy_script.FEET_TO_CENTER)
			if problem != "":
				problems.append("%s %d: %s" % [anim, i, problem])
	_expect(problems.is_empty(), "no stray pixels in any of his frames " + str(problems))
	var soft_hats := []
	for hat: String in froggy_script.HATS:
		var image: Image = _froggy._solid_hat(froggy_script.HATS[hat][0]).get_image()
		for y in image.get_height():
			for x in image.get_width():
				var a := image.get_pixel(x, y).a
				if a > 0.0 and a < 1.0 and not soft_hats.has(hat):
					soft_hats.append(hat)
	_expect(soft_hats.is_empty(), "every hat is all hat or nothing, pixel by pixel " + str(soft_hats))

	_froggy.cursor = Vector2(1500.0, 1000.0)
	for action in [&"wander", &"leap", &"ribbit", &"hunt", &"visit", &"boing", &"flip"]:
		_froggy._run(action)
		await _until_idle(str(action), 14.0)
	_froggy._run(&"startled", 1.0)
	await _until_idle("startled")

	_froggy.toggle_nap()
	await _until(func() -> bool: return _froggy.state == _states.NAP, 3.0, "falls asleep")
	_froggy.toggle_nap()
	await _until_idle("wakes up")

	# A click is a hop.
	var middle: Vector2 = _froggy._center()
	_mouse_button(middle, true)
	_mouse_button(middle, false)
	await _until(func() -> bool: return _froggy._busy, 1.0, "click starts a hop")
	await _until_idle("click hop")

	# Rubbing back and forth over him is petting (at normal speed: he judges how fast you rub).
	Engine.time_scale = 1.0
	var affection: int = _froggy.affection
	middle = _froggy._center()
	for i in 40:
		_froggy.cursor = middle + Vector2(18.0 if i % 2 == 0 else -18.0, 0.0)
		await process_frame
	_expect(_froggy.affection > affection, "petting him counts")
	_froggy.cursor = Vector2(1500.0, 1000.0)
	Engine.time_scale = 8.0

	# Pulled back and let go, the way you play the game: he jumps the other way...
	middle = _froggy._center()
	_froggy.cursor = middle
	_mouse_button(middle, true)
	_mouse_motion(middle + Vector2(30.0, 30.0))
	_expect(_froggy.state == _states.AIM, "pulling back from him aims a jump")
	_froggy.cursor = middle + Vector2(60.0, 45.0)
	await process_frame
	_mouse_button(_froggy.cursor, false)
	_expect(_froggy.state == _states.AIR and _froggy.vel.x < 0.0 and _froggy.vel.y < 0.0, "letting go jumps him up and the other way")
	_froggy.cursor = Vector2(1500.0, 1000.0)
	await _until(func() -> bool: return _froggy.state != _states.AIR, 6.0, "aimed jump comes down")
	_expect(is_equal_approx(_froggy._tilt_target, 0.0), "lands flat")
	await _until_idle("aimed jump")

	# ...and standing on the bottom of the screen, where there's hardly any room to pull down, a pull
	# to the very edge still counts as a big one: without the pointer being moved anywhere.
	middle = _froggy._center()
	var room_below := ROOM.y - middle.y
	_froggy.cursor = middle
	_mouse_button(middle, true)
	_mouse_motion(middle + Vector2(0.0, 8.0))
	_froggy.cursor = middle + Vector2(-room_below * 0.5, room_below)
	await process_frame
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "aiming leaves the pointer alone (no jumping mouse)")
	_expect(_froggy._aim.y * PX < -room_below * 1.5, "a pull to the bottom edge of the screen counts for more")
	_mouse_button(_froggy.cursor, false)
	_expect(_froggy.state == _states.AIR and _froggy.vel.y < 0.0 and _froggy.vel.x > 0.0, "...and still jumps him, up and the other way")
	_froggy.cursor = Vector2(1500.0, 1000.0)
	await _until(func() -> bool: return _froggy.state != _states.AIR, 6.0, "edge jump comes down")
	await _until_idle("edge jump")

	# ...holding still on him picks him up; carried a bit and let go...
	middle = _froggy._center()
	_froggy.cursor = middle
	_mouse_button(middle, true)
	await create_timer(0.6, true, false, true).timeout  # (real time: that's how long he waits)
	_expect(_froggy.state == _states.HELD, "holding still on him picks him up")
	for i in 5:
		_froggy.cursor = middle + Vector2(30.0 + i * 10.0, -30.0)
		await process_frame
	_mouse_button(_froggy.cursor, false)
	await _until_idle("picked up and dropped")
	# ...and thrown hard into a wall.
	_froggy._grab(_froggy._center())
	_froggy._throw_vel = Vector2(5000.0, -1500.0)
	_froggy._release()
	await _until_idle("thrown into a wall", 10.0)
	_expect(_saw_dizzy, "a hard throw leaves him dizzy")

	_froggy.jump_out_of(GAME, true)
	await _until_idle("jump out of the game", 14.0)
	_expect(_saw_shards, "breaking out of the game window shatters glass")
	_expect(is_equal_approx(_froggy.feet.y, ROOM.y), "lands on the desktop floor after the jump out")
	_expect(_froggy.feet.x < GAME.position.x or _froggy.feet.x > GAME.end.x, "ends up outside the game window")

	_froggy.come_to(1700.0)
	await _until_idle("come here", 14.0)
	_expect(absf(_froggy.feet.x - 1700.0) < 60.0 * PX, "comes when called")

	# Muse Penguin's out too (the musiverse): a penguin on the floor, x its middle and y its feet.
	# (At 2x: whole-arc checks like going over the top of one need finer steps than 8x gives.)
	Engine.time_scale = 2.0
	var me: Dictionary = _froggy.musiverse_critter()
	_expect(me.get("kind") == "frog" and is_equal_approx(float(me.x), _froggy.feet.x) and me.get("state") == "idle",
		"tells the musiverse where he is")
	var pal := {"id": "p1", "name": "Pebble", "x": 1100.0, "y": ROOM.y, "w": 26.0 * PX, "h": 34.0 * PX, "state": "stand"}
	_froggy.penguins = [pal]
	_expect(_froggy._penguin_on_floor().get("id") == "p1", "notices a penguin down on the floor with him")
	_froggy._run(&"see_penguin", pal)
	await _until_idle("visits a penguin", 14.0)
	_expect(absf(_froggy.feet.x - 1100.0) < 13.0 * PX + 40.0 * PX, "hops over next to the penguin")
	_expect(_told_to("hello", "p1"), "says hello to the penguin")
	_froggy._run(&"leapfrog", pal)
	await _until_idle("leapfrog", 14.0)
	_expect(_told_to("leapfrog", "p1"), "leapfrogs right over the penguin")
	# Coming down on a penguin's head is a boing: he bounces off to the side.
	_froggy._interrupt()
	_froggy.feet = Vector2(1100.0, ROOM.y - 34.0 * PX - 60.0 * PX)
	_froggy.vel = Vector2(0.0, 300.0 * PX)
	_froggy._set_air()
	await _until(func() -> bool: return _froggy.vel.y < 0.0, 2.0, "boings off a penguin's head")
	_expect(_told_to("hop_on", "p1"), "tells the penguin he boinged off its head")
	await _until_idle("comes down off the penguin", 10.0)
	_expect(absf(_froggy.feet.x - 1100.0) > 13.0 * PX, "bounces off to one side (not on and on)")
	# A penguin waving at him gets hearts and a happy hop back.
	_froggy._particles.clear()
	_froggy.musiverse_event({"type": "greet", "from": "p1", "to": "froggy"})
	_expect(_froggy._busy and not _froggy._particles.is_empty(), "waves back when a penguin says hi")
	await _until_idle("waves back")
	# One coming over to visit gets the same; one holding out a fish gets his tongue (and a gulp).
	_froggy._particles.clear()
	_froggy.musiverse_event({"type": "visit", "from": "p1", "to": "froggy"})
	_expect(_froggy._busy and not _froggy._particles.is_empty(), "waves back when a penguin visits")
	await _until_idle("waves back at a visit")
	var fond: int = _froggy.affection
	_froggy.musiverse_event({"type": "fish", "from": "p1", "to": "froggy"})
	await _until(func() -> bool: return _froggy._tongue_t >= 0.0, 2.0, "tongue out for the fish")
	await _until(func() -> bool: return _froggy.affection > fond, 3.0, "gulps the fish down")
	await _until_idle("after the fish")
	# The overlay's end: screen pixels in (here, as if he were on a second screen), his window pixels out.
	var overlay = load("res://scripts/DesktopFrog.gd").new()
	overlay.froggy = _froggy
	overlay._room = Rect2i(1920, 0, int(ROOM.x), int(ROOM.y))
	overlay._heard_penguins({"mv": 1.0, "from": "muse-penguin", "events": "junk", "critters": [
		{"id": "p2", "kind": "penguin", "name": "Waddles", "x": 2500.0, "y": ROOM.y, "w": 60.0, "h": 90.0, "state": "stand"},
		{"id": "far", "kind": "penguin", "name": "Faraway", "x": 300.0, "y": ROOM.y, "w": 60.0, "h": 90.0},
		{"id": "odd", "kind": "penguin", "x": "nope", "y": null}, "junk", {"kind": "frog", "x": 2400.0, "y": ROOM.y}]})
	_expect(_froggy.penguins.size() == 1 and _froggy.penguins[0].id == "p2" and is_equal_approx(float(_froggy.penguins[0].x), 580.0),
		"hears where the penguins on his own screen are (and ignores junk)")
	# Muse Penguin's penguins all hiding (your shake, or its HIDE!): he's blown off the screen too,
	# stays around (the app doesn't quit), and comes back out when they do.
	_froggy.penguins = []
	overlay._heard_penguins({"mv": 1.0, "from": "muse-penguin", "critters": [], "hidden": true})
	_expect(_froggy.tucked_away, "hides when the penguins do")
	await _until(func() -> bool: return _froggy.state == _states.HIDDEN, 6.0, "blown off the screen")
	_expect(not _left, "...and is still around while he's hiding (the app doesn't quit)")
	overlay._heard_penguins({"mv": 1.0, "from": "muse-penguin", "critters": [], "hidden": false})
	await _until_idle("comes back out with the penguins", 8.0)
	_expect(not _froggy.tucked_away and is_equal_approx(_froggy.feet.y, ROOM.y), "comes back out when they do")
	# On his own, a really hard mouse shake does it (the same test of what counts as Muse Penguin's).
	var shake = load("res://scripts/DesktopFrog.gd").Shake.new()
	var t := 1000
	var fired := 0
	for i in 40:
		fired += 1 if shake.feed(t, 500.0 + sin(float(i)) * 30.0) else 0
		t += 30
	_expect(fired == 0, "ordinary mousing about isn't a shake")
	t += 1000
	for i in 40:
		fired += 1 if shake.feed(t, 500.0 + (180.0 if i % 2 == 0 else -180.0)) else 0
		t += 50
	_expect(fired == 1, "a really hard shake is one (once, then it cools down)")
	overlay.free()
	_froggy.penguins = []
	Engine.time_scale = 8.0

	_froggy.go_home(GAME)
	await _until(func() -> bool: return _left, 14.0, "hops back into the game window")
	_expect(_froggy.state == _states.HIDDEN, "is gone after going home")

	_left = false
	_froggy.drop_in(900.0)
	await _until_idle("drop in again")
	_froggy.say_bye()
	await _until(func() -> bool: return _left, 20.0, "hops off the screen to say bye")

	_expect(_froggy.musiverse_critter().is_empty(), "isn't in the musiverse once he's gone")
	_expect(not _saw_stuck, "never sticks to the side of the screen (he can't in the game)")
	_expect(not _saw_words, "never says a word (he doesn't in the game either)")
	for error in _counter.errors:
		_failures.append("script error: " + error)
	if _failures.is_empty():
		print("Desktop frog smoke test passed.")
	else:
		for failure in _failures:
			push_warning("FAIL: " + failure)
		printerr("Desktop frog smoke test failed (%d)." % _failures.size())
	OS.remove_logger(_counter)
	quit(1 if not _failures.is_empty() else 0)


## What's wrong with one of his frames on the 2x2 grid (lined up from his feet, like _solid_frame), or "".
func _frame_problem(texture: Texture2D, feet_to_center: float) -> String:
	var image := texture.get_image()
	var w := image.get_width()
	var h := image.get_height()
	var feet_row := int(feet_to_center) + h / 2
	var start := Vector2i(posmod(w / 2, 2), posmod(feet_row, 2))
	var solid := {}
	for by in range(start.y - 2, h, 2):
		for bx in range(start.x - 2, w, 2):
			var first := Color(0, 0, 0, 0)
			var found := false
			for corner in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var p: Vector2i = Vector2i(bx, by) + corner
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
					continue
				var c := image.get_pixelv(p)
				if c.a > 0.0 and p.y >= feet_row:
					return "something under his feet at %s" % p
				if not found:
					first = c
					found = true
				elif not c.is_equal_approx(first):
					return "block at %s isn't all one colour" % Vector2i(bx, by)
			if found and first.a > 0.0:
				solid[Vector2i(bx, by)] = true
	for b: Vector2i in solid:
		if not (solid.has(b + Vector2i(2, 0)) or solid.has(b - Vector2i(2, 0)) or solid.has(b + Vector2i(0, 2)) or solid.has(b - Vector2i(0, 2))):
			return "a lone speck at %s" % b
	return "" if not solid.is_empty() else "empty"


func _until_idle(label: String, seconds := 6.0) -> void:
	await _until(func() -> bool: return _froggy.state == _states.IDLE and not _froggy._busy, seconds, label)


func _until(done: Callable, seconds: float, label: String) -> void:
	var stop := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < stop:
		await process_frame
		_watch(label)
		if done.call():
			return
	_failures.append("%s: timed out (state %d)" % [label, _froggy.state])


func _watch(label: String) -> void:
	if _froggy.state == _states.HIDDEN:
		return
	var feet: Vector2 = _froggy.feet
	var walls_on: bool = _froggy._walls  # off while he hops away to say bye
	if (walls_on and (feet.x < -1.0 or feet.x > ROOM.x + 1.0)) or feet.y > ROOM.y + 0.01 or feet.y < -100.0 * PX:
		_failures.append("%s: wandered off the screen to %s" % [label, feet])
	_saw_dizzy = _saw_dizzy or _froggy.state == _states.DIZZY
	# stuck: hanging off the floor while not in the air (or being held, or aiming)
	_saw_stuck = _saw_stuck or (feet.y < ROOM.y - 1.0 and _froggy.state in [_states.IDLE, _states.NAP, _states.LAND] \
		and _froggy._floor_override < 0.0)
	_saw_words = _saw_words or _froggy._bubble_left > 0.0
	_told.append_array(_froggy.take_musiverse_events())  # (he only keeps the last few)
	for p in _froggy._particles:
		_saw_shards = _saw_shards or p.kind == "shard"
		_saw_words = _saw_words or p.kind == "z"


## Whether he's sent that penguin a musiverse event of that type so far.
func _told_to(type: String, penguin: String) -> bool:
	_told.append_array(_froggy.take_musiverse_events())
	for event: Dictionary in _told:
		if event.type == type and event.to == penguin and event.from == "froggy":
			return true
	return false


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	_froggy.handle_mouse(event)


func _mouse_motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	_froggy.handle_mouse(event)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
