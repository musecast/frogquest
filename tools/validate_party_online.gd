extends SceneTree
## Online parties (Party.gd through Muse's relay), against stand-ins: Muse's functions answered by a fake,
## and the relay played by a little WebSocket server here that does what muse-tracker-api's does (seats,
## welcome, join, leave, {data} to everyone or {to, data} to one, ping). Two phones in one process: one
## hosts, the other joins; seats and @handles from the room, looks shared, the same climb for both, frogs
## through the relay; a friend leaving and coming back mid-climb is caught up; the host leaving hands the
## party on; the relay dropping ends it; Play with Anyone says so while it isn't open. The Muse sign-in
## stays in memory; yours isn't touched.
##   Godot --headless --path . --script res://tools/validate_party_online.gd

const RELAY_PORT := 47851


## The relay, in small: a WebSocket server with seats, as muse-tracker-api's room Durable Object does.
class FakeRelay extends RefCounted:
	var server := TCPServer.new()
	var conns: Array = []  # {ws, seat, handle}
	var next_seat := 1

	func start() -> int:
		return server.listen(RELAY_PORT, "127.0.0.1")

	func host_seat() -> int:
		var best := 0
		for c in conns:
			if c.seat > 0 and (best == 0 or c.seat < best):
				best = c.seat
		return best

	func poll() -> void:
		while server.is_connection_available():
			var ws := WebSocketPeer.new()
			ws.accept_stream(server.take_connection())
			conns.append({"ws": ws, "seat": 0, "handle": ""})
		for c in conns.duplicate():
			var ws: WebSocketPeer = c.ws
			ws.poll()
			var state := ws.get_ready_state()
			if state == WebSocketPeer.STATE_OPEN and c.seat == 0:
				c.handle = ws.get_requested_url().get_slice("ticket=", 1)
				c.seat = next_seat
				next_seat += 1
				var cards := []
				for o in conns:
					if o.seat > 0:
						cards.append({"slot": o.seat, "handle": o.handle, "displayName": o.handle})
				ws.send_text(JSON.stringify({"sys": "welcome", "you": c.seat, "host": host_seat(), "maxPlayers": 16, "players": cards}))
				_to_others(c, {"sys": "join", "player": {"slot": c.seat, "handle": c.handle}, "host": host_seat()})
			elif state == WebSocketPeer.STATE_OPEN:
				while ws.get_available_packet_count() > 0:
					var text := ws.get_packet().get_string_from_utf8()
					if text == "ping":
						ws.send_text("pong")
						continue
					var msg = JSON.parse_string(text)
					if not (msg is Dictionary):
						continue
					var out := JSON.stringify({"from": c.seat, "data": msg.get("data")})
					for o in conns:
						if o.seat > 0 and o != c and (not msg.has("to") or int(msg.to) == o.seat):
							o.ws.send_text(out)
			elif state == WebSocketPeer.STATE_CLOSED:
				conns.erase(c)
				if c.seat > 0:
					_to_others(c, {"sys": "leave", "slot": c.seat, "host": host_seat()})

	func _to_others(c: Dictionary, msg: Dictionary) -> void:
		for o in conns:
			if o.seat > 0 and o != c and o.ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
				o.ws.send_text(JSON.stringify(msg))

	func drop(seat: int) -> void:
		for c in conns:
			if c.seat == seat:
				c.ws.close(1011, "gone")


var _failures: Array[String] = []
var _started := []
var _frogs := {}
var _relay := FakeRelay.new()
var _tickets: Array[String] = []  # whose ticket each ticket call is (the next phone to connect)
var _room_mode := "endless"  # (what Muse's stand-in says the room climbs)
var _quick_open := false  # (whether Muse's stand-in has quick join yet)
var _ticket_code := 200  # (what the relay's stand-in says to a ticket: 503 once its daily allowance is gone)
var _left_rooms: Array = []  # (rooms let go of: muse_game_room_leave)
var _ask_live := false  # (whether Muse's stand-in has muse_play_ask_for_room yet)
var _asked_room: Array = []  # (asks for more room: the app each was for)


func _initialize() -> void:
	_run.call_deferred()


func _fake_muse(path: String, body: Dictionary, _bearer: String) -> Dictionary:
	if path == "/api/rooms/ticket" and _ticket_code != 200:
		return {"code": _ticket_code, "data": {"error": "Playing online isn't set up yet"}}
	if path.ends_with("muse_game_room_leave"):
		_left_rooms.append(str(body.get("p_room", "")))
	if path == "/api/rooms/ticket":
		var who: String = _tickets.pop_front() if not _tickets.is_empty() else "someone"
		return {"code": 200, "data": {"ticket": who, "url": "ws://127.0.0.1:%d/api/rooms/R1/ws?ticket=%s" % [RELAY_PORT, who], "expires_in": 60, "max_players": 16}}
	match path.trim_prefix("/rest/v1/rpc/"):
		"muse_game_room_create", "muse_game_room_join":
			return {"code": 200, "data": {"room": "R1", "app": "frog-quest", "mode": _room_mode, "maxPlayers": 16,
				"public": _room_mode == "story"}}
		"muse_game_quick_join":
			if _quick_open:
				return {"code": 200, "data": {"room": "R1", "app": "frog-quest", "mode": _room_mode, "maxPlayers": 16, "public": true}}
		"muse_game_room_leave":
			return {"code": 204, "data": null}
		"muse_play_ask_for_room":
			if _ask_live:
				_asked_room.append(str(body.get("p_app", "")))
				return {"code": 200, "data": {"asked": true, "today": 12}}
		"muse_presence_ping":
			return {"code": 200, "data": "online"}
	return {"code": 404, "data": {"message": "no such function"}}


func _process_relay() -> void:
	_relay.poll()


func _run() -> void:
	await process_frame
	var acct := root.get_node("MuseAccount")
	var social := root.get_node("MuseSocial")
	var real_save: String = acct.save_path
	acct.save_path = "user://test_party_online_muse.save"
	acct.changed.disconnect(social._on_account_changed)
	acct.transport = _fake_muse
	acct._loaded = true
	acct._refresh_token = "fake-refresh"
	acct._access_token = "fake-access"
	acct._access_expires_at = Time.get_unix_time_from_system() + 3600.0
	social.available = true
	social.me = {"handle": "hosty"}
	_expect(_relay.start() == OK, "the stand-in relay listens")
	process_frame.connect(_process_relay)

	var host := _phone("OnA")
	var friend := _phone("OnB")
	_tickets.append("hosty")
	_expect(await host.host_online() == "", "an online party starts")
	await _until(func() -> bool: return host.is_on() and host.players.size() == 1, 5.0)
	_expect(host.is_on() and host.is_host() and host.online_room == "R1", "the host is seated in its room, as its host")
	_tickets.append("pal")
	_expect(await friend.join_room("R1") == "", "a friend joins it")
	await _until(func() -> bool: return host.players.size() == 2 and friend.players.size() == 2, 5.0)
	_expect(host.players.size() == 2 and friend.players.size() == 2, "both see both (%d, %d)" % [host.players.size(), friend.players.size()])
	var friend_seat: int = friend.me()
	_expect(str(host.players.get(friend_seat, {}).get("name", "")) == "@pal" and str(friend.players.get(host.me(), {}).get("name", "")) == "@hosty",
		"names are the room's @handles")
	friend.set_color(3)
	await _until(func() -> bool: return int(host.players.get(friend_seat, {}).get("color", 0)) == 3, 3.0)
	_expect(int(host.players.get(friend_seat, {}).get("color", 0)) == 3 and str(host.players.get(friend_seat, {}).get("name", "")) == "@pal",
		"a new colour reaches the others, and a typed name never replaces a handle")

	host.start()
	await _until(func() -> bool: return _started.size() == 2, 3.0)
	_expect(_started.size() == 2 and host.run_seed == friend.run_seed and host.in_run and friend.in_run,
		"starting climbs for both, on one tower (seeds %d, %d)" % [host.run_seed, friend.run_seed])
	friend.send_frog([5.0, -60.0, "default", 0, false, 0.0, 2, 6], 1.0)
	host.send_frog([-5.0, -90.0, "prejump", 1, true, 0.0, 4, 9], 1.0)
	await _until(func() -> bool: return _frogs.size() == 2, 3.0)
	_expect(_frogs.get("OnA", [0, []])[0] == friend_seat and _frogs.get("OnB", [0, []])[0] == host.me(), "frogs go both ways through the relay")

	friend.leave()
	await _until(func() -> bool: return host.players.size() == 1, 5.0)
	_expect(host.players.size() == 1, "a friend leaving drops them from the party")
	_tickets.append("pal")
	_expect(await friend.join_room("R1") == "", "and they can come back")
	await _until(func() -> bool: return _started.size() == 3, 5.0)
	_expect(_started.size() == 3 and friend.run_seed == host.run_seed, "coming back mid-climb catches them up with it")

	host.leave()
	await _until(func() -> bool: return friend.players.size() == 1 and friend.is_host(), 5.0)
	_expect(friend.players.size() == 1 and friend.is_host(), "the host leaving hands the party on")
	var why := [""]
	friend.ended.connect(func(w: String) -> void: why[0] = w)
	_relay.drop(friend.me())
	await _until(func() -> bool: return why[0] != "", 5.0)
	_expect(why[0] != "" and not friend.is_on(), "the relay dropping ends the party (%s)" % why[0])
	_expect(await friend.play_with_anyone() == "Play with Anyone isn't open yet.", "Play with Anyone says so while it isn't open")
	_expect(await friend.climb_with_everyone() != "" and not friend.everyone, "so does climbing with everyone (quietly: StoryParty tries again later)")

	# Up the World Tree with everyone online: Muse's quick join for "story" (a public room) and no start
	# to wait for; a friend's Join (Climb with @climby) puts them beside you, everyone's room for them too.
	_room_mode = "story"
	_quick_open = true
	var climber := _phone("OnC")
	var buddy := _phone("OnD")
	_tickets.append("climby")
	_expect(await climber.climb_with_everyone() == "", "up the World Tree with everyone online")
	await _until(func() -> bool: return climber.is_on() and climber.in_run, 5.0)
	_expect(climber.in_run and climber.mode == "story" and climber.everyone and "OnC" in _started,
		"in everyone's room up the tree, climbing at once (nobody starts it)")
	var shows = climber.joinable()
	_expect(shows is Dictionary and shows.get("mode") == "story" and shows.get("room") == "R1", "friends see they can climb with you (%s)" % [shows])
	_tickets.append("buddy")
	_expect(await buddy.join_room("R1", "@climby") == "", "a friend's Join gets them in")
	await _until(func() -> bool: return buddy.in_run and buddy.players.size() == 2 and climber.players.size() == 2, 5.0)
	_expect(buddy.in_run and buddy.mode == "story" and buddy.everyone and buddy.beside == "@climby"
		and buddy.peer_named("@climby") == climber.me(), "up the tree beside @climby, who they joined (beside %s)" % buddy.beside)
	climber.send_frog([10.0, -500.0, "default", 0, false, 0.0, 0, 50, 0, 0], 1.0)
	await _until(func() -> bool: return _frogs.has("OnD") and _frogs.OnD[0] == climber.me(), 3.0)
	_expect(_frogs.has("OnD") and _frogs.OnD[1].size() == 10 and int(_frogs.OnD[1][9]) == 0, "their frog comes through, with where they are")
	climber.leave()
	buddy.leave()
	_expect(climber.mode == "endless" and not climber.everyone and climber.beside == "" and buddy.beside == "", "leaving clears all that")
	_ticket_code = 503  # (the relay's daily allowance used up)
	_left_rooms.clear()
	_expect(await climber.climb_with_everyone() != "" and climber.online_room == "" and not climber.is_on(),
		"the relay refusing a ticket leaves him climbing alone")
	_expect(_left_rooms.has("R1"), "and lets Muse have the seat back at once (left: %s)" % [_left_rooms])
	var full := root.find_child("RoomFullPopup", true, false)
	var back: String = load("res://scenes/RoomFullPopup.gd").reset_words()
	_expect(full != null and _words_in(full).contains("Online's Full Today") and _words_in(full).contains(back),
		"a popup says online's full for today, and when it's back (%s)" % back)
	if full:
		_ask_live = true
		_press(full, "Ask for More Room")
		await _until(func() -> bool: return _words_in(full).contains("froggies want more room"), 3.0)
		_expect(_asked_room == ["frog-quest"] and _words_in(full).contains("Asked! 12 froggies want more room today."),
			"Ask for More Room asks Muse (once), and says how many asked today (%s)" % [_asked_room])
		_press(full, "OK")
		await process_frame
	await climber.climb_with_everyone()
	await process_frame
	_expect(root.find_child("RoomFullPopup", true, false) == null, "and it's only said once a day")
	_ask_live = false
	await buddy.climb_with_everyone()
	var again := root.find_child("RoomFullPopup", true, false)
	if again:
		_press(again, "Ask for More Room")
		await _until(func() -> bool: return _words_in(again).contains("isn't open yet"), 3.0)
	_expect(again != null and _words_in(again).contains("Asking isn't open yet"), "before Muse counts asks, Ask for More Room says so")
	if again:
		_press(again, "OK")
	_ticket_code = 200

	process_frame.disconnect(_process_relay)
	_relay.server.stop()
	acct.transport = Callable()
	acct._refresh_token = ""
	acct._access_token = ""
	acct.save_path = real_save
	acct.changed.connect(social._on_account_changed)
	social.available = false
	social.me = {}
	for f in ["user://test_party_online_muse.save"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("test_party_On") and f.ends_with(".cfg"):
			DirAccess.remove_absolute("user://" + f)
	if _failures.is_empty():
		print("Online party test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Online party test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## Every word on a screen, one after another.
func _words_in(screen: Node) -> String:
	if not is_instance_valid(screen):
		return ""
	var out := ""
	for l in screen.find_children("*", "Label", true, false):
		if l.visible:
			out += l.text + " "
	return out


func _press(screen: Node, words: String) -> void:
	for b in screen.find_children("*", "Button", true, false):
		if b.text == words and b.visible and not b.disabled:
			b.pressed.emit()
			return
	_failures.append("no \"%s\" button to press" % words)


func _phone(branch_name: String) -> Node:
	var branch := Node.new()
	branch.name = branch_name
	root.add_child(branch)
	var party := Node.new()
	party.name = "Party"
	party.set_script(load("res://scripts/Party.gd"))
	party.settings_path = "user://test_party_%s.cfg" % branch_name
	party.on_start = func() -> void: _started.append(branch_name)
	branch.add_child(party)
	party.frog_moved.connect(func(peer: int, state: Array) -> void: _frogs[branch_name] = [peer, state])
	return party


func _until(done: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < until:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
