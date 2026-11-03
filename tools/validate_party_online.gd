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


func _initialize() -> void:
	_run.call_deferred()


func _fake_muse(path: String, _body: Dictionary, _bearer: String) -> Dictionary:
	if path == "/api/rooms/ticket":
		var who: String = _tickets.pop_front() if not _tickets.is_empty() else "someone"
		return {"code": 200, "data": {"ticket": who, "url": "ws://127.0.0.1:%d/api/rooms/R1/ws?ticket=%s" % [RELAY_PORT, who], "expires_in": 60, "max_players": 16}}
	match path.trim_prefix("/rest/v1/rpc/"):
		"muse_game_room_create", "muse_game_room_join":
			return {"code": 200, "data": {"room": "R1", "app": "frog-quest", "mode": "endless", "maxPlayers": 16}}
		"muse_game_room_leave":
			return {"code": 204, "data": null}
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
