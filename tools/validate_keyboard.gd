extends SceneTree
## The keyboard on the screens you type on (scripts/KeyboardHelp.gd): Friends, Muse Account and Play
## Together, on an upright iPhone Duo. An iPhone's keyboard has no key to put it away, and Return on the
## Friends screen once saved an @handle (agreeing to the community rules) for someone only closing the
## keyboard. Checks that a tap anywhere off the box puts the keyboard away and one in it doesn't; that
## Return there only puts it away, and the @handle's saved only after Agree and Save and a last yes;
## that a button tapped as typing ends still presses, the panel staying put under the finger until the
## keyboard's gone; that the boxes are lifted above it; and that Muse's half-minute news doesn't rebuild
## the box you're typing in. Muse is a fake and the sign-in a scratch one: nothing real is touched.
##   Godot --headless --path . --script res://tools/validate_keyboard.gd

const SCRATCH := "user://test_keyboard_muse.save"
const DUO := Vector2(480, 698)  # an upright iPhone Duo's viewport (1375x2000, the story's 480 across)

var _failures: Array[String] = []
var _calls: Array = []  # [Muse function, its args], in turn
var _me := {}  # you, as the pretend Muse Social has you
var _keyboard_px := 0.0  # the pretend keyboard's height, in the window's pixels (0: it's down)
var _keyboard_top := 0.0  # where its top is, in the screen's pixels, while it's up
var _view: SubViewport
var _acct: Node
var _social: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	_acct = root.get_node("MuseAccount")
	_social = root.get_node("MuseSocial")
	var real_save: String = _acct.save_path
	_acct.save_path = SCRATCH
	_acct.changed.disconnect(_social._on_account_changed)
	_acct.transport = _fake_muse
	_acct._loaded = true
	_acct._refresh_token = "fake-refresh"
	_acct._access_token = "fake-access"
	_acct._access_expires_at = Time.get_unix_time_from_system() + 3600.0
	_social.available = true
	_social.me = {}
	_view = SubViewport.new()
	_view.size = Vector2i(DUO)
	_view.disable_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(_view)

	for part in [_picking_a_handle, _adding_a_friend, _signing_in, _joining_a_party]:
		await part.call()
		for left in _view.get_children():  # (one that stopped short leaves its screen over the next's)
			left.queue_free()
		_keyboard_px = 0.0
		await _frames(2)

	_view.queue_free()
	_acct.transport = Callable()
	_acct._refresh_token = ""
	_acct._access_token = ""
	_acct.save_path = real_save
	_acct.changed.connect(_social._on_account_changed)
	_social.available = false
	_social.me = {}
	if FileAccess.file_exists(SCRATCH):
		DirAccess.remove_absolute(SCRATCH)
	if _failures.is_empty():
		print("Keyboard test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Keyboard test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## The Friends screen with no @handle yet: Return, taps off the box, Agree and Save, the last yes.
func _picking_a_handle() -> void:
	_me = {}
	var screen = await _open("res://scenes/FriendsScreen.gd", func(s) -> bool:
		return _box(s) != null and _box(s).placeholder_text == "your_handle")
	var box: LineEdit = _box(screen)
	box.text = "froggy"
	await _tap(box)
	_expect(box.is_editing(), "a tap in the @handle box types in it (the keyboard comes up)")
	await _return_key()
	_expect(_asked("muse_social_save_profile").is_empty() and screen._confirming == "",
		"Return saves nothing, nor asks to (it saved the @handle, and agreed to the rules, for someone closing the keyboard)")
	if not _still(box, screen):
		return
	_expect(not box.is_editing() and box.text == "froggy", "it only puts the keyboard away, the @handle still in the box")
	await _tap(box)
	await _tap_at_spot(box, Vector2(0.2, 0.5))
	_expect(box.is_editing(), "a tap elsewhere in the box keeps typing")
	await _tap(_label(screen, "3 to 20 letters"))
	_expect(not box.is_editing() and not box.has_focus(), "a tap on words off the box puts the keyboard away")
	await _tap(box)
	await _tap_at(Vector2(3.0, 3.0))
	_expect(not box.is_editing(), "and so does a tap on the dimmed screen round the panel")

	await _tap(_button(screen, "Agree and Save"))
	_expect(screen._confirming == "froggy" and _label(screen, "You'll be @froggy") != null,
		"Agree and Save asks once more (\"You'll be @froggy in every Muse app...\")")
	_expect(_asked("muse_social_save_profile").is_empty(), "and saves nothing yet")
	await _tap(_button(screen, "Change It"))
	_expect(screen._confirming == "" and _box(screen) != null and _box(screen).text == "froggy",
		"Change It goes back to the box, the @handle still in it")
	for bad in [["ab", "Use 3 to 20"], ["1234", "Use 3 to 20"], ["frog-man", "Use 3 to 20"], ["adm1n", "That handle is reserved"]]:
		_box(screen).text = bad[0]
		await _tap(_button(screen, "Agree and Save"))
		_expect(screen._confirming == "" and str(screen._note_text).begins_with(bad[1]),
			"\"%s\", which Muse wouldn't take, is turned down at once (%s)" % [bad[0], screen._note_text])
	_box(screen).text = "taken_one"
	await _tap(_button(screen, "Agree and Save"))
	await _tap(_button(screen, "Yes, Save It"))
	await _until(func() -> bool: return screen._note_text == "That handle is taken.", 3.0)
	_expect(screen._note_text == "That handle is taken." and _box(screen) != null and _box(screen).text == "taken_one",
		"a taken @handle goes back to the box with Muse's words, still in it to change")
	_box(screen).text = "@Froggy"
	await _tap(_button(screen, "Agree and Save"))
	await _tap(_button(screen, "Yes, Save It"))
	await _until(func() -> bool: return _social.handle() == "froggy", 3.0)
	var saves := _asked("muse_social_save_profile")
	_expect(saves.size() == 2 and saves[-1].get("p_handle") == "froggy" and saves[-1].get("p_accept_rules") == true,
		"Yes, Save It saves @froggy, agreeing to the rules")
	await _frames(2)
	_expect(_label(screen, "You're @froggy") != null, "and the screen goes on to your friends")
	screen.queue_free()
	await process_frame


## The Friends screen with an @handle: Return, the lift, tapping Add Friend as typing ends, Muse's news.
func _adding_a_friend() -> void:
	_me = {"handle": "froggy"}
	var screen = await _open("res://scenes/FriendsScreen.gd", func(s) -> bool:
		return _box(s) != null and _box(s).placeholder_text == "Their @handle")
	var box: LineEdit = _box(screen)
	box.text = "pal"
	await _tap(box)
	await _return_key()
	_expect(_asked("muse_social_request_friend").is_empty() and screen._note_text == "",
		"Return in Their @handle asks no one (nor says to type one first)")
	if not _still(box, screen):
		return
	_expect(not box.is_editing() and box.text == "pal", "it only puts the keyboard away, @pal still in the box")
	await _tap(box)
	await _frames(2)
	var resting: Vector2 = screen._panel.position
	_keyboard_up()
	await _frames(3)
	var add := _button(screen, "Add Friend")
	var lifted: Vector2 = screen._panel.position
	_expect(lifted.y < resting.y - 10.0 and _bottom(add) <= _keyboard_top + 0.5,
		"typing, the box and Add Friend are lifted above the keyboard (Add Friend's bottom %.0f, its top %.0f)" % [_bottom(add), _keyboard_top])
	var at := _centre(add)
	_press(at, true)
	await _frames(3)
	_expect(screen._panel.position == lifted,
		"a finger on Add Friend: the panel stays put as typing ends (it dropped away under the finger: %s, was %s)" % [screen._panel.position, lifted])
	_slide(at + Vector2(0.5, 0.0))
	_press(at + Vector2(0.5, 0.0), false)
	await _until(func() -> bool: return not _asked("muse_social_request_friend").is_empty(), 2.0)
	var asks := _asked("muse_social_request_friend")
	_expect(asks.size() == 1 and asks[0].get("p_handle") == "pal", "and the tap (with a wobble) asks @pal")
	await _frames(2)
	_expect(screen._panel.position == lifted, "the panel stays up while the keyboard slides away")
	_keyboard_px = 0.0
	await _frames(2)
	_expect(screen._panel.position.y > lifted.y + 10.0, "and comes down once it's gone")

	await _tap(_box(screen))
	var typing_in: LineEdit = _box(screen)
	var typing_id := typing_in.get_instance_id()
	typing_in.text = "bud"
	_social.changed.emit()  # (as Muse's half-minute look does)
	await _frames(2)
	_expect(_box(screen) == typing_in and typing_in.is_editing(),
		"Muse's news while you type leaves the box (and the keyboard) be")
	await _tap(_label(screen, "You're @froggy"))
	await _frames(2)
	_expect(_box(screen) != null and _box(screen).get_instance_id() != typing_id and _box(screen).text == "bud",
		"and shows once you've stopped, what you typed kept")
	screen.queue_free()
	await process_frame


## Muse Account, typing your email: Return on an empty box, the lift, a tap off the box.
func _signing_in() -> void:
	var token: String = _acct._refresh_token
	_acct._refresh_token = ""  # (signed out, for the email box)
	var screen = await _open("res://scenes/MuseAccountScreen.gd", func(s) -> bool:
		s._mode = "email"
		s._show_state()
		return _box(s).visible)
	var box: LineEdit = _box(screen)
	await _tap(box)
	_expect(box.is_editing(), "Muse Account: a tap in the email box types in it")
	await _return_key()
	_expect(not box.is_editing() and not screen._status.visible, "Return on an empty box just puts the keyboard away (no telling off)")
	await _tap(box)
	_keyboard_up()
	await _frames(3)
	_expect(_bottom(screen._primary) <= _keyboard_top + 0.5, "typing your email, it and Email Me a Code are above the keyboard")
	await _tap(screen._body)
	_expect(not box.is_editing(), "a tap off the box puts the keyboard away")
	_keyboard_px = 0.0
	screen.queue_free()
	await process_frame
	_acct._refresh_token = token


## Play Together, typing a party code: Return on an empty box, the lift, a tap off the box.
func _joining_a_party() -> void:
	var screen = await _open("res://scenes/PartyScreen.gd", func(s) -> bool:
		if s._mode != "join":
			s._go("join")
		return _box(s) != null)
	var box: LineEdit = _box(screen)
	await _tap(box)
	await _return_key()
	_expect(not box.is_editing() and screen._note == "", "Play Together: Return on an empty code just puts the keyboard away")
	await _tap(_box(screen))
	_keyboard_up()
	await _frames(3)
	_expect(_bottom(_button(screen, "Join")) <= _keyboard_top + 0.5, "typing the code, it and Join are above the keyboard")
	await _tap(_label(screen, "party code"))
	_expect(not _box(screen).is_editing(), "a tap off the box puts the keyboard away")
	_keyboard_px = 0.0
	screen.queue_free()
	await process_frame


## A screen in the iPhone Duo's view, on the pretend keyboard, once ready says it's ready.
func _open(path: String, ready: Callable) -> Node:
	var screen: Node = load(path).new()
	_view.add_child(screen)
	screen._keyboard.height_source = func() -> float: return _keyboard_px
	await _until(func() -> bool: return ready.call(screen), 3.0)
	_expect(ready.call(screen), "%s opens ready to type in" % path.get_file())
	await _frames(2)
	return screen


## The keyboard up, as tall as an iPhone's over half the screen.
func _keyboard_up() -> void:
	_keyboard_px = 0.5 * maxf(1.0, float(DisplayServer.window_get_size().y))
	_keyboard_top = DUO.y - _keyboard_px * DUO.y / maxf(1.0, float(DisplayServer.window_get_size().y))


func _fake_muse(path: String, body: Dictionary, _bearer: String) -> Dictionary:
	var fn := path.trim_prefix("/rest/v1/rpc/")
	_calls.append([fn, body])
	match fn:
		"muse_social_me":
			return {"code": 200, "data": _me}
		"muse_social_friends_list":
			return {"code": 200, "data": {"friends": [], "incoming": [], "outgoing": []}}
		"muse_social_save_profile":
			if str(body.get("p_handle")) == "taken_one":
				return {"code": 400, "data": {"message": "That handle is taken."}}
			_me = {"handle": str(body.get("p_handle"))}
			return {"code": 200, "data": null}
		"muse_social_request_friend":
			return {"code": 200, "data": "requested"}
	return {"code": 404, "data": {"message": "no such function"}}


## The args of each call to one of Muse's functions.
func _asked(fn: String) -> Array:
	var out := []
	for c in _calls:
		if c[0] == fn:
			out.append(c[1])
	return out


func _tap(c: Control) -> void:
	if c == null:
		_failures.append("nothing there to tap")
		return
	await _tap_at(_centre(c))


func _tap_at_spot(c: Control, spot: Vector2) -> void:
	await _tap_at(c.get_global_transform_with_canvas() * (c.size * spot))


func _tap_at(at: Vector2) -> void:
	_press(at, true)
	_press(at, false)
	await _frames(2)


func _press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_view.push_input(e, true)


func _slide(to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_view.push_input(e, true)


func _return_key() -> void:
	for down in [true, false]:
		var k := InputEventKey.new()
		k.keycode = KEY_ENTER
		k.physical_keycode = KEY_ENTER
		k.pressed = down
		_view.push_input(k, true)
	await _frames(2)


func _button(screen: Node, text: String) -> Button:
	for b in screen.find_children("*", "Button", true, false):
		if b.text == text and b.is_visible_in_tree():
			return b
	_failures.append("no \"%s\" button showing" % text)
	return null


func _label(screen: Node, words: String) -> Label:
	for l in screen.find_children("*", "Label", true, false):
		if l.text.contains(words) and l.is_visible_in_tree():
			return l
	return null


## Return left the box where it was (not rebuilt, as doing something rebuilds it): else says so, and
## the rest of that part's skipped.
func _still(box, screen) -> bool:  # (untyped: the box may be freed)
	var same: bool = is_instance_valid(box) and _box(screen) == box
	_expect(same, "Return left the box as it was (it did something, rebuilding the screen)")
	return same


## The screen's text box (its _input: as a Node's, that name's the input callback).
static func _box(screen) -> LineEdit:
	return screen.get("_input")


static func _centre(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


static func _bottom(c: Control) -> float:
	return (c.get_global_transform_with_canvas() * c.size).y if c else INF


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _until(done: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < end:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
