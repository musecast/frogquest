extends SceneTree
## Party play (Party.gd) over a real network: a host and a friend in this one process, each with its own
## multiplayer as if on two phones, talking ENet over this computer. The friend joins, both see both, the
## host starts and both get the same climb; frogs go both ways; the friend leaving drops them from the
## host's list; the host leaving ends it for the friend. Then two Endless runs on one seed must build the
## same tower, platform for platform, and a party code must come back to the address it was made from.
## Party settings, scores and the wardrobe go to scratch files; yours are byte-checked by the caller.
##   Godot --headless --path . --script res://tools/validate_party.gd

const SCORES := "user://test_party_scores.dat"
const WARDROBE := "user://test_party_wardrobe.save"

var _failures: Array[String] = []
var _started := {}
var _frogs := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var mm := root.get_node("MusicManager")
	var real_wardrobe: String = mm.wardrobe_path
	mm.wardrobe_path = WARDROBE

	var host := _phone("PhoneA")
	var friend := _phone("PhoneB")
	_expect(host.host() == "", "a party starts")
	_expect(host.players.size() == 1 and host.is_host(), "with just the host in it")
	_expect(friend.join("127.0.0.1") == "", "the friend looks for it")
	await _until(func() -> bool: return host.players.size() == 2 and friend.players.size() == 2, 5.0)
	_expect(host.players.size() == 2 and friend.players.size() == 2, "both see both in the party (%d, %d)" % [host.players.size(), friend.players.size()])
	var friend_id: int = friend.me()
	_expect(friend_id > 1 and host.players.has(friend_id), "the host knows the friend by their id")

	host.start()
	await _until(func() -> bool: return _started.size() == 2, 3.0)
	_expect(_started.size() == 2 and host.in_run and friend.in_run and host.run_seed == friend.run_seed,
		"starting climbs for both, on the same tower (seeds %d, %d)" % [host.run_seed, friend.run_seed])

	friend.send_frog([10.0, -50.0, "default", 0, false, 0.0, 3, 5], 1.0)
	host.send_frog([-20.0, -80.0, "prejump", 1, true, 0.1, 7, 9], 1.0)
	await _until(func() -> bool: return _frogs.size() == 2, 3.0)
	_expect(_frogs.get("PhoneA", [0, []])[0] == friend_id and _frogs.get("PhoneA", [0, []])[1][6] == 3, "the friend's frog reaches the host")
	_expect(_frogs.get("PhoneB", [0, []])[0] == 1 and _frogs.get("PhoneB", [0, []])[1][2] == "prejump", "and the host's reaches the friend")

	friend.leave()
	await _until(func() -> bool: return host.players.size() == 1, 5.0)
	_expect(host.players.size() == 1, "a friend leaving drops them from the host's party")
	var why := [""]
	friend.ended.connect(func(w: String) -> void: why[0] = w)
	_expect(friend.join("127.0.0.1") == "", "the friend can come back")
	await _until(func() -> bool: return host.players.size() == 2, 5.0)
	await _until(func() -> bool: return _started.size() == 3, 3.0)
	_expect(_started.size() == 3, "a friend joining mid-climb is caught up with it")
	host.leave()
	await _until(func() -> bool: return why[0] != "", 5.0)
	_expect(why[0] != "" and not friend.is_on(), "the host leaving ends the party for the friend (%s)" % why[0])

	# A full party: the host and 15 friends all see all 16; a 17th is turned away.
	var big_host := _phone("PhoneH")
	_expect(big_host.host() == "", "a second party starts")
	var guests: Array = []
	for i in big_host.MAX_PLAYERS - 1:
		var guest := _phone("PhoneJ%d" % i)
		guest.join("127.0.0.1")
		guests.append(guest)
	await _until(func() -> bool: return guests.all(func(g) -> bool: return g.players.size() == big_host.MAX_PLAYERS), 15.0)
	_expect(big_host.players.size() == big_host.MAX_PLAYERS and guests.all(func(g) -> bool: return g.players.size() == big_host.MAX_PLAYERS),
		"a full party of %d: everyone sees everyone (the host sees %d)" % [big_host.MAX_PLAYERS, big_host.players.size()])
	var extra := _phone("PhoneJx")
	var turned_away := [""]
	extra.ended.connect(func(w: String) -> void: turned_away[0] = w)
	extra.join("127.0.0.1")
	await _until(func() -> bool: return turned_away[0] != "", 8.0)
	_expect(turned_away[0].contains("full") and big_host.players.size() == big_host.MAX_PLAYERS,
		"one more than a full party is told it's full (%s)" % turned_away[0])
	big_host.leave()
	for guest in guests:
		guest.leave()
	await process_frame

	# Codes: the last two numbers of the host's address, back to the same address.
	var party: Node = root.get_node("Party")
	var mine: String = party.local_ip()
	if mine != "":
		var made: String = party.code()
		_expect(made.length() == 4 and party.ip_for(made) == mine, "a party code comes back to this computer's address (%s, %s)" % [made, mine])
	_expect(party.ip_for("1.2.3.4") == "1.2.3.4" and party.ip_for("zzzzz") == "" and party.ip_for("!!!!") == "", "a whole address passes, nonsense doesn't")

	await _same_tower(party)

	for f in [SCORES, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	for f in DirAccess.get_files_at("user://"):
		if f.begins_with("test_party_Phone") and f.ends_with(".cfg"):
			DirAccess.remove_absolute("user://" + f)
	mm.wardrobe_path = real_wardrobe
	if _failures.is_empty():
		print("Party test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Party test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## One phone: its own branch with its own multiplayer, and its own Party in it.
func _phone(branch_name: String) -> Node:
	var branch := Node.new()
	branch.name = branch_name
	root.add_child(branch)
	set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var party := Node.new()
	party.name = "Party"
	party.set_script(load("res://scripts/Party.gd"))
	party.settings_path = "user://test_party_%s.cfg" % branch_name
	party.on_start = func() -> void: _started[branch_name + str(_started.size())] = true
	branch.add_child(party)
	party.frog_moved.connect(func(peer: int, state: Array) -> void: _frogs[branch_name] = [peer, state])
	return party


## Two Endless runs on one party seed: the same platforms, in the same places, doing the same things.
func _same_tower(party: Node) -> void:
	party.in_run = true
	party.run_seed = 20261102
	party.run_started_ms = Time.get_ticks_msec()
	var runs := []
	for i in 2:
		var endless: Node2D = (load("res://scenes/EndlessMode.tscn") as PackedScene).instantiate()
		endless.save_path = SCORES
		root.add_child(endless)
		runs.append(endless)
	for _f in 20:
		await process_frame
	var a: Array = runs[0].platforms.get_children()
	var b: Array = runs[1].platforms.get_children()
	var same := a.size() == b.size() and a.size() >= 20
	for i in mini(a.size(), b.size()):
		var p = a[i]
		var q = b[i]
		if p.position.distance_to(q.position) > 0.01 or p.kind != q.kind or p.width != q.width or p.spring != q.spring \
				or p.crumbles != q.crumbles or p.motion != q.motion or not is_equal_approx(p.phase, q.phase):
			same = false
			break
	_expect(same, "two runs on one seed build the same tower (%d and %d platforms)" % [a.size(), b.size()])
	await _rubber_banding(runs[0], party)
	for endless in runs:
		endless.queue_free()
	party.in_run = false
	await process_frame


## Rubber banding, the tether: tied to the nearest friend; a real fall, once the band's taut, has them reel
## you up to them; coming down onto a platform below doesn't; with tethers off, nothing catches you; and
## past the point of no return a friend above still pulls you up rather than the run ending.
func _rubber_banding(endless: Node2D, party: Node) -> void:
	party.players = {1: {"name": "@me", "hat": "", "skin": "", "color": 0}, 2: {"name": "@pal", "hat": "", "skin": "", "color": 2}}
	party.tethers = true
	var player: CharacterBody2D = endless.player
	player.set_physics_process(false)  # (held where he's put)
	var y: float = player.global_position.y
	var friend_y := y - 300.0
	endless._on_frog_moved(2, [0.0, friend_y, "default", 0, false, 0.0, 0, 30, 1])
	for _f in 40:  # (their frog glides to where it's said to be)
		await process_frame
	player.velocity = Vector2.ZERO
	endless._tether(0.016)
	_expect(endless._tether_peer == 2, "the band ties to the nearest friend")
	endless._last_floor_y = y
	player.global_position.y = y + 30.0
	player.velocity = Vector2(0.0, 400.0)
	endless._tether(0.016)
	_expect(endless._reel.is_empty(), "coming down a little, onto a platform below, isn't a fall: no pull")
	player.global_position.y = y + 120.0
	endless._tether(0.016)
	_expect(not endless._reel.is_empty(), "a real fall, the band taut: your friend starts pulling you up")
	await create_timer(endless.TETHER_REEL + 0.3).timeout
	_expect(endless._reel.is_empty() and absf(player.global_position.y - friend_y) < 150.0,
		"and you're up by them (%.0f from them)" % absf(player.global_position.y - friend_y))
	player.set_physics_process(false)
	party.tethers = false
	endless._last_floor_y = player.global_position.y
	player.global_position.y += 400.0
	player.velocity = Vector2(0.0, 400.0)
	endless._tether(0.016)
	_expect(endless._reel.is_empty() and endless._tether_peer == 0, "with tethers off, nothing catches you")
	party.tethers = true
	endless.highest_player_y = friend_y
	player.global_position.y = friend_y + endless.fail_y_threshold + 10.0
	endless._trigger_reset()
	_expect(not endless.is_resetting and not endless._reel.is_empty(), "past the point of no return, a friend above still pulls you up")
	await create_timer(endless.TETHER_REEL + 0.3).timeout
	party.players = {}


func _until(done: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < until:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
