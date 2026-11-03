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

	# Codes: the last two numbers of the host's address, back to the same address.
	var party: Node = root.get_node("Party")
	var mine: String = party.local_ip()
	if mine != "":
		var made: String = party.code()
		_expect(made.length() == 4 and party.ip_for(made) == mine, "a party code comes back to this computer's address (%s, %s)" % [made, mine])
	_expect(party.ip_for("1.2.3.4") == "1.2.3.4" and party.ip_for("zzzzz") == "" and party.ip_for("!!!!") == "", "a whole address passes, nonsense doesn't")

	await _same_tower(party)

	for f in ["user://test_party_PhoneA.cfg", "user://test_party_PhoneB.cfg", SCORES, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
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
	for endless in runs:
		endless.queue_free()
	party.in_run = false
	await process_frame


func _until(done: Callable, seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < until:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
