extends Node2D
## Lil Froggy's home: this copy of the game turns its window into a see-through overlay over one
## screen. Only the bits around froggy catch the mouse; every other click goes straight through
## to the desktop. Right-click him (or his tray icon) for the menu; left-click the tray icon to
## call him over. See DesktopFrogLink.gd for how the game lets him out.

enum { MENU_COME, MENU_NAP, MENU_SOUNDS, MENU_OPEN_GAME, MENU_BYE }

const CLICK_GRID := 8.0  # the click area moves in steps this big, so it isn't re-cut every frame
# What's on screen trails a frame or two behind the click area (which is also all Windows draws),
# so the area covers where he's been over the last few frames too: otherwise a fast drag cuts him off.
const CLICK_TRAIL_FRAMES := 4
const HEARTBEAT_EVERY := 2.0
const CHECK_EVERY := 0.5
# The musiverse (see the bottom of this file): Muse Penguin's penguins, if it's running too.
const MUSIVERSE_PORT := 47830  # he listens here (this computer only)
const PENGUINS_PORT := 47831  # Muse Penguin listens here
const MUSIVERSE_EVERY := 0.15
const PENGUINS_GONE_AFTER := 3.0

var link  # DesktopFrogLink.gd
var froggy  # DesktopFroggy.gd
var settings := ConfigFile.new()

var _screen := -1
var _room := Rect2i()
var _click_polygon := PackedVector2Array()
var _click_trail: Array = []  # the boxes he drew in, for each of the last few frames
var _menu: PopupMenu
var _tray: StatusIndicator
var _heartbeat_in := 0.0
var _check_in := 0.0
var _quitting := false
var _musiverse: PacketPeerUDP
var _musiverse_in := 0.0
var _penguins_heard := -INF  # (seconds)


func _ready() -> void:
	link = load("res://scripts/DesktopFrogLink.gd")
	if not link.is_supported() or not link.is_unlocked():
		get_tree().quit()
		return
	if link.is_out():
		# He's already out there: wave him over instead of making a second one.
		link.send_command("come")
		get_tree().quit()
		return
	get_tree().set_auto_accept_quit(false)
	OS.low_processor_usage_mode = true
	settings.load(link.SETTINGS_PATH)
	_make_window_see_through()

	froggy = load("res://scripts/DesktopFroggy.gd").new()
	froggy.process_priority = -1  # he moves first, then the click area follows him
	froggy.sounds_on = settings.get_value("froggy", "sounds", true)
	froggy.affection = settings.get_value("froggy", "affection", 0)
	froggy.flies_eaten = settings.get_value("froggy", "flies_eaten", 0)
	froggy.wants_menu.connect(_show_menu_at_cursor)
	froggy.left.connect(_on_froggy_left)
	add_child(froggy)

	var from: Rect2i = link.from_rect()
	if from.has_area():
		_move_to_screen(DisplayServer.get_screen_from_rect(Rect2(from)))
		froggy.jump_out_of(Rect2(from.position - _room.position, from.size), link.is_reveal())
	else:
		_move_to_screen(_screen_under_cursor())
		froggy.drop_in(float(settings.get_value("froggy", "x", -1.0)))
	_make_tray()
	_write_state()
	_start_musiverse()


func _process(delta: float) -> void:
	if froggy == null or _quitting:
		return
	_update_click_region()
	_step_musiverse(delta)
	Engine.max_fps = 60 if froggy.is_lively() else 20
	_heartbeat_in -= delta
	if _heartbeat_in <= 0.0:
		_heartbeat_in = HEARTBEAT_EVERY
		_write_state()
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = CHECK_EVERY
		_check_for_command()
		_check_screen()
		_refresh_menu()


func _input(event: InputEvent) -> void:
	if froggy != null:
		froggy.handle_mouse(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit()


# ── The window ─────────────────────────────────────────────────────────────

func _make_window_see_through() -> void:
	var win := get_window()
	# Until froggy is placed, a single pixel catches the mouse.
	win.mouse_passthrough_polygon = PackedVector2Array([Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.title = "Lil Froggy"
	win.borderless = true
	win.transparent = true
	win.always_on_top = true
	win.unfocusable = true
	get_viewport().transparent_bg = true


func _room_on(screen: int) -> Rect2i:
	var room := DisplayServer.screen_get_usable_rect(screen)
	var full := Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen))
	# A window covering the whole monitor reads as a fullscreen app to Windows (an auto-hide
	# taskbar stops popping up over it), so stay a pixel short.
	if room.size.y >= full.size.y:
		room.size.y = full.size.y - 1
	return room


func _move_to_screen(screen: int) -> void:
	if screen < 0 or screen >= DisplayServer.get_screen_count():
		screen = DisplayServer.get_primary_screen()
	_screen = screen
	_room = _room_on(screen)
	var win := get_window()
	win.position = _room.position
	win.size = _room.size
	_click_polygon = PackedVector2Array()
	_click_trail.clear()
	# (a lil frog: about half his old size, in whole screen pixels so he stays crisp)
	froggy.set_room(Vector2(_room.size), maxi(1, roundi(DisplayServer.screen_get_dpi(screen) / 96.0)))


func _screen_under_cursor() -> int:
	var mouse := DisplayServer.mouse_get_position()
	for screen in DisplayServer.get_screen_count():
		if Rect2i(DisplayServer.screen_get_position(screen), DisplayServer.screen_get_size(screen)).has_point(mouse):
			return screen
	return DisplayServer.get_primary_screen()


## Keeps up with resolution changes, a moved taskbar, or a monitor going away.
func _check_screen() -> void:
	if _screen >= DisplayServer.get_screen_count():
		_move_to_screen(DisplayServer.get_primary_screen())
		return
	var win := get_window()
	if _room_on(_screen) != _room or win.position != _room.position or win.size != _room.size:
		_move_to_screen(_screen)


## Only froggy's part of the window catches the mouse (on Windows it's also the only part that
## gets drawn), so it's cut to the boxes he's drawing in, in coarse steps.
func _update_click_region() -> void:
	var bounds := Rect2(Vector2.ZERO, Vector2(_room.size))
	_click_trail.append(froggy.get_drawn_rects())
	if _click_trail.size() > CLICK_TRAIL_FRAMES:
		_click_trail.pop_front()
	var boxes: Array[Rect2] = []
	for frame_rects in _click_trail:
		for drawn: Rect2 in frame_rects:
			var r := drawn.grow(CLICK_GRID * 0.5).intersection(bounds)
			if r.has_area():
				boxes.append(Rect2((r.position / CLICK_GRID).floor() * CLICK_GRID, Vector2.ZERO) \
					.expand((r.end / CLICK_GRID).ceil() * CLICK_GRID))
	# Boxes that touch become one: overlapping outlines would cancel each other out.
	var merged := true
	while merged:
		merged = false
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if boxes[i].grow(1.0).intersects(boxes[j]):
					boxes[i] = boxes[i].merge(boxes[j])
					boxes.remove_at(j)
					merged = true
					break
			if merged:
				break
	if boxes.is_empty():
		boxes.append(Rect2(0.0, 0.0, 1.0, 1.0))
	# One outline per box, joined to the next by a zero-width bridge, then back the same way.
	var polygon := PackedVector2Array()
	for box in boxes:
		polygon.append_array([box.position, Vector2(box.end.x, box.position.y), box.end,
			Vector2(box.position.x, box.end.y), box.position])
	for i in range(boxes.size() - 2, -1, -1):
		polygon.append(boxes[i].position)
	if polygon != _click_polygon:
		_click_polygon = polygon
		get_window().mouse_passthrough_polygon = polygon


# ── Tray icon and menu ─────────────────────────────────────────────────────

func _make_tray() -> void:
	_menu = PopupMenu.new()
	_menu.prefer_native_menu = true
	_menu.add_item("Come here!", MENU_COME)
	_menu.add_check_item("Nap time", MENU_NAP)
	_menu.add_check_item("Sounds", MENU_SOUNDS)
	_menu.add_separator()
	_menu.add_item("Open Frog Quest", MENU_OPEN_GAME)
	_menu.add_item("Bye for now", MENU_BYE)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)
	_refresh_menu()
	_tray = StatusIndicator.new()
	_tray.tooltip = "Lil Froggy (right-click for more)"  # (he doesn't talk, so the hint lives here)
	_tray.icon = load("res://assets/frog.png")
	_tray.pressed.connect(_on_tray_pressed)
	add_child(_tray)
	_tray.menu = _tray.get_path_to(_menu)


func _refresh_menu() -> void:
	if _menu == null:
		return
	var nap := _menu.get_item_index(MENU_NAP)
	if _menu.is_item_checked(nap) != froggy.is_napping():
		_menu.set_item_checked(nap, froggy.is_napping())
	var sounds := _menu.get_item_index(MENU_SOUNDS)
	if _menu.is_item_checked(sounds) != froggy.sounds_on:
		_menu.set_item_checked(sounds, froggy.sounds_on)


func _on_menu_id_pressed(id: int) -> void:
	match id:
		MENU_COME:
			_call_over()
		MENU_NAP:
			froggy.toggle_nap()
		MENU_SOUNDS:
			froggy.sounds_on = not froggy.sounds_on
			_save_settings()
		MENU_OPEN_GAME:
			_open_game()
		MENU_BYE:
			_say_bye()
	_refresh_menu()


func _on_tray_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		_call_over()


func _show_menu_at_cursor() -> void:
	_refresh_menu()
	_menu.popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ONE))


## Hops over to the cursor, crossing to its screen first if it's on another one.
func _call_over() -> void:
	var screen := _screen_under_cursor()
	var x := float(DisplayServer.mouse_get_position().x - _room_on(screen).position.x)
	if screen != _screen:
		_move_to_screen(screen)
		froggy.drop_in(x)
	else:
		froggy.come_to(x)


func _open_game() -> void:
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	OS.create_process(OS.get_executable_path(), args)


func _say_bye() -> void:
	froggy.say_bye()
	# However he gets held up on the way out, he's gone in a few seconds.
	get_tree().create_timer(6.0).timeout.connect(_quit)


func _on_froggy_left() -> void:
	get_tree().create_timer(0.8).timeout.connect(_quit)  # let his last sound finish


# ── Talking to the game ────────────────────────────────────────────────────

func _write_state() -> void:
	DirAccess.make_dir_recursive_absolute(link.DIR)
	var state := ConfigFile.new()
	state.set_value("froggy", "pid", OS.get_process_id())
	state.set_value("froggy", "heartbeat", Time.get_unix_time_from_system())
	state.save(link.STATE_PATH)


func _check_for_command() -> void:
	if not FileAccess.file_exists(link.COMMAND_PATH):
		return
	var note := ConfigFile.new()
	var loaded := note.load(link.COMMAND_PATH) == OK
	DirAccess.remove_absolute(link.COMMAND_PATH)
	if not loaded:
		return
	match str(note.get_value("command", "name", "")):
		"come":
			_call_over()
		"home":
			var rect: Rect2i = note.get_value("command", "rect", Rect2i())
			if not rect.has_area():
				_say_bye()
				return
			var screen := DisplayServer.get_screen_from_rect(Rect2(rect))
			if screen >= 0 and screen != _screen:
				_move_to_screen(screen)
			froggy.go_home(Rect2(rect.position - _room.position, rect.size))
			get_tree().create_timer(8.0).timeout.connect(_quit)


func _save_settings() -> void:
	if froggy == null:
		return
	settings.set_value("froggy", "sounds", froggy.sounds_on)
	settings.set_value("froggy", "affection", froggy.affection)
	settings.set_value("froggy", "flies_eaten", froggy.flies_eaten)
	settings.set_value("froggy", "x", froggy.feet.x)
	DirAccess.make_dir_recursive_absolute(link.DIR)
	settings.save(link.SETTINGS_PATH)


func _quit() -> void:
	if _quitting:
		return
	_quitting = true
	_save_settings()
	if _musiverse != null:
		_musiverse.close()
	var state := ConfigFile.new()
	if state.load(link.STATE_PATH) == OK and int(state.get_value("froggy", "pid", 0)) == OS.get_process_id():
		DirAccess.remove_absolute(link.STATE_PATH)
	get_tree().quit()


# ── The musiverse: Muse Penguin's penguins ─────────────────────────────────
# If Muse Penguin is running too, the two apps tell each other where everybody is a few times a
# second over this computer's own loopback network (127.0.0.1 only: nothing leaves the machine,
# nothing outside can reach it). Packets are small JSON, both ways:
#   {mv: 1, from: "lil-froggy" | "muse-penguin",
#    critters: [{id, kind, name, x, y, w, h, state}],  x the middle, y the feet, screen pixels
#    events: [{type, from, to}]}                       greet, hello, leapfrog, hop_on
# Muse Penguin's src/musiverse.js is the other end (it only talks while he's out).

func _start_musiverse() -> void:
	_musiverse = PacketPeerUDP.new()
	if _musiverse.bind(MUSIVERSE_PORT, "127.0.0.1") != OK:
		_musiverse = null  # (something else has the port: no musiverse today)
		return
	_musiverse.set_dest_address("127.0.0.1", PENGUINS_PORT)


func _step_musiverse(delta: float) -> void:
	if _musiverse == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	while _musiverse.get_available_packet_count() > 0:
		var packet := _musiverse.get_packet()
		if _musiverse.get_packet_ip() != "127.0.0.1" or packet.size() > 64000:
			continue
		var m: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if m is Dictionary and _num(m.get("mv")) == 1.0 and m.get("from") == "muse-penguin":
			_penguins_heard = now
			_heard_penguins(m)
	if not froggy.penguins.is_empty() and now - _penguins_heard > PENGUINS_GONE_AFTER:
		froggy.penguins = []  # (Muse Penguin closed)
	_musiverse_in -= delta
	if _musiverse_in > 0.0:
		return
	_musiverse_in = MUSIVERSE_EVERY
	var critters := []
	var me: Dictionary = froggy.musiverse_critter()
	if not me.is_empty():
		me["x"] = float(me["x"]) + _room.position.x
		me["y"] = float(me["y"]) + _room.position.y
		critters.append(me)
	var packet := {"mv": 1, "from": "lil-froggy", "critters": critters, "events": froggy.take_musiverse_events()}
	_musiverse.put_packet(JSON.stringify(packet).to_utf8_buffer())


## The penguins on his screen, in window pixels, and anything they did to him.
func _heard_penguins(m: Dictionary) -> void:
	var screen := Rect2(Vector2(_room.position), Vector2(_room.size)).grow(40.0)
	var list := []
	var critters: Variant = m.get("critters")
	for c: Variant in (critters if critters is Array else []):
		if not (c is Dictionary) or c.get("kind") != "penguin":
			continue
		var at := Vector2(_num(c.get("x")), _num(c.get("y")))
		if not screen.has_point(at):
			continue
		list.append({"id": _text(c.get("id"), 24), "name": _text(c.get("name"), 28),
			"x": at.x - _room.position.x, "y": at.y - _room.position.y,
			"w": maxf(0.0, _num(c.get("w"))), "h": maxf(0.0, _num(c.get("h"))), "state": _text(c.get("state"), 16)})
		if list.size() >= 60:
			break
	froggy.penguins = list
	var events: Variant = m.get("events")
	for e: Variant in (events.slice(0, 8) if events is Array else []):
		if e is Dictionary and e.get("to") == "froggy":
			froggy.musiverse_event(e)


static func _num(v: Variant) -> float:
	return float(v) if (v is float or v is int) and is_finite(float(v)) else 0.0


static func _text(v: Variant, most: int) -> String:
	return str(v).left(most) if v is String else ""
