extends SceneTree
## Climbing the World Tree together (scripts/StoryParty.gd), in the real level: a party hosted on this
## computer with a pretend friend in it (their frog's state handed in as their phone would send it).
## Checks that their frog shows where they are, named; that the band catches a fall well below a friend
## who's standing and reels him up to them, but never past the finale's door his own world hasn't
## opened, never to someone whose ending is playing (they're not shown), never into anything solid of
## his own world (the gate he hasn't opened), and, up the tree with everyone online, only to friends;
## that whoever joins appears beside whoever they joined, or at the finale's door (and lands there);
## that a still frog is only sent now and then; that a tap on a name blocks or reports them through
## Muse; that a party starting up the tree from the title starts the climb; and that the title leaves
## everyone's room. Scratch saves, a stand-in for Muse: nothing real is touched.
##   Godot --headless --path . --script res://tools/validate_story_party.gd

const SCRATCH_SAVE := "user://test_story_party_save.save"
const SCRATCH_PARTY := "user://test_story_party.cfg"
const SCRATCH_MUSE := "user://test_story_party_muse.save"
const SCRATCH_WARDROBE := "user://test_story_party_wardrobe.save"

var _failures: Array[String] = []
var _calls: Array = []
var party: Node
var main: Node
var player: CharacterBody2D
var sp: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	party = root.get_node("Party")
	var acct := root.get_node("MuseAccount")
	var social := root.get_node("MuseSocial")
	var mm := root.get_node("MusicManager")
	var real := [party.settings_path, acct.save_path, mm.wardrobe_path]
	party.settings_path = SCRATCH_PARTY
	party.on_start = func() -> void: pass  # (the scene stays put)
	party.with_everyone = false  # (no trying Muse's rooms here: the online test does that)
	mm.wardrobe_path = SCRATCH_WARDROBE
	acct.save_path = SCRATCH_MUSE
	acct.changed.disconnect(social._on_account_changed)
	acct.transport = _fake_muse
	acct._loaded = true
	acct._refresh_token = "fake-refresh"
	acct._access_token = "fake-access"
	acct._access_expires_at = Time.get_unix_time_from_system() + 3600.0
	social.available = true
	social.me = {"handle": "froggy"}

	main = load("res://scenes/Main.tscn").instantiate()
	player = main.get_node("Player")
	player.save_path = SCRATCH_SAVE
	root.add_child(main)
	await _frames(40)
	sp = main.get_node_or_null("StoryParty")
	_expect(sp != null, "Main has its StoryParty")
	if sp == null:
		await _finish(real)
		return
	player._on_button_pressed()  # (Play)
	await _wait(0.8)
	var ground: Vector2 = player.global_position  # (where he stands to start: a spot to stand on)
	_expect(player.is_on_floor(), "he's standing at the start (%s)" % ground)

	_expect(party.host() == "", "a party here, on this computer")
	party.players[2] = {"name": "@pal", "hat": "wizhat", "skin": "", "color": 4}
	party.start("story")
	await _frames(2)
	_expect(party.in_run and party.mode == "story" and party.beside == "", "the host starts up the World Tree, staying put")

	var air := _open_column()
	_expect(air != Vector2.INF, "there's open air in the level to fall through (%s)" % air)
	if air == Vector2.INF:
		await _finish(real)
		return

	# Their frog, where their phone says, named over its head.
	_friend(2, air, "default", 0)
	await _frames(3)
	var frog = sp._frogs.get(2)
	_expect(frog != null and frog.visible and frog.spot() == air and frog.z_index == player.z_index,
		"the friend's frog shows where they are, at his depth")
	var tag = sp._layer.get_node_or_null("Tag2")
	var mine = sp._layer.get_node_or_null("Tag0")
	_expect(tag != null and tag.text == "@pal" and mine != null and mine.text == party.display_name(),
		"their name over their frog, and yours over yours")
	Engine.time_scale = 0.05  # (paused)
	await _frames(2)
	_expect(sp._layer.get_node_or_null("Tag2") == null, "paused, no names over the frogs")
	Engine.time_scale = 1.0

	# The band.
	await _fall_below(air)
	_expect(not sp._reel.is_empty(), "falling well below a friend who's standing, the band catches him")
	await _until(func() -> bool: return sp._reel.is_empty(), 2.0)
	_expect(player.global_position.distance_to(air) < 6.0 and sp._free_at(player.global_position),
		"and reels him up to them (%s, they're at %s)" % [player.global_position, air])
	_friend(2, air, "airborne", 0)
	await _fall_below(air)
	_expect(sp._reel.is_empty(), "a friend in the air can't pull anyone up")

	main.npc6 = 0
	_friend(2, air, "default", sp.IN_FINALE)
	await _fall_below(air)
	_expect(sp._reel.is_empty(), "a friend past the finale's door doesn't pull him there while his own world hasn't opened it")
	main.npc6 = 1
	await _fall_below(air)
	_expect(not sp._reel.is_empty(), "once his own world has opened it, they do")
	await _until(func() -> bool: return sp._reel.is_empty(), 2.0)
	main.npc6 = 0

	_friend(2, air, "default", sp.WON)
	await _frames(2)
	_expect(not frog.visible and not sp._ties_to(2), "a friend whose ending is playing isn't shown, nor tied to")
	await _fall_below(air)
	_expect(sp._reel.is_empty(), "nor pulls anyone up")
	_friend(2, air, "default", sp.AWAY)
	await _frames(2)
	_expect(not frog.visible, "nor one who's gone back to the title")

	var gate: Vector2 = main.get_node("World Sprites/Keyhole/Area2Dkeyhole2/CollisionShapekeyhole").global_position
	_expect(not sp._free_at(gate), "his own gate (unopened) is solid where it stands")
	_friend(2, gate, "default", 0)
	var to: Vector2 = sp._free_spot_near(gate + Vector2(0, -2))
	_expect(to == Vector2.INF or sp._free_at(to), "pulled toward a friend standing where his own gate is, he goes only where he fits")

	party.everyone = true  # (up the tree with everyone online: the band's for friends)
	social.friends = []
	_friend(2, air, "default", 0)
	await _frames(2)
	_expect(not sp._ties_to(2), "with everyone, someone who isn't a friend isn't tied to")
	await _fall_below(air)
	_expect(sp._reel.is_empty(), "nor pulls him up")
	social.friends = [{"handle": "pal"}]
	await _frames(2)
	_expect(sp._ties_to(2), "a Muse friend is")
	party.everyone = false

	# Thrifty up the tree (Muse's relay counts it against a daily allowance): about 10 a second moving,
	# about once a second still.
	var still := [1.0, 2.0, "default", 0, false, 0.0, 0, 3, 0, 0]
	var sends := _count_sends(func(_i: int) -> Array: return still, 120)
	_expect(sends >= 2 and sends <= 3, "a still frog is sent about once a second (%d in two seconds)" % sends)
	var moving := _count_sends(func(i: int) -> Array: return [1.0 + i, 2.0, "airborne", 0, false, 0.0, 0, 3, 0, 0], 60)
	_expect(moving >= 8 and moving <= 11, "a moving one about 10 times a second (%d in one)" % moving)

	# Beside whoever you joined.
	await _until(func() -> bool: return sp._reel.is_empty(), 2.0)
	player.global_position = air
	player.velocity = Vector2.ZERO
	party.beside = "@pal"
	_friend(2, ground, "default", 0)
	await _frames(3)
	var off: Vector2 = player.global_position - ground
	_expect(party.beside == "" and absf(off.x) >= 20.0 and absf(off.x) <= 50.0 and absf(off.y) < 4.0 and sp._free_at(player.global_position),
		"joining, he's beside them, on what they stand on (%s, they're at %s)" % [player.global_position, ground])
	await _wait(0.5)
	_expect(player.is_on_floor() and absf(player.global_position.y - ground.y) < 4.0, "and stands there (%s)" % player.global_position)

	# A name's card: Block and Report, through Muse.
	sp._open_card(2)
	await _frames(2)
	var block := _button("Block")
	_expect(block != null and _button("Report") != null and _button("Close") != null, "a tap on a name: Block, Report and Close")
	if block:
		block.pressed.emit()
		await _until(func() -> bool: return not _asked("muse_social_block").is_empty(), 2.0)
		await _frames(2)
		var asked := _asked("muse_social_block")
		_expect(asked.size() == 1 and asked[0].get("p_handle") == "pal" and not sp._frogs.has(2),
			"Block blocks @pal through Muse, and their frog goes")
	party.players[3] = {"name": "@bob", "hat": "", "skin": "", "color": 0}
	_friend(3, air, "default", 0)
	await _frames(2)
	sp._open_card(3)
	await _frames(2)
	var report := _button("Report")
	if report:
		report.pressed.emit()
		await _frames(2)
		var spam := _button("Spam")
		_expect(spam != null, "Report asks what for")
		if spam:
			spam.pressed.emit()
			await _until(func() -> bool: return not _asked("muse_social_report").is_empty(), 2.0)
			var r := _asked("muse_social_report")
			_expect(r.size() == 1 and r[0].get("p_handle") == "bob" and r[0].get("p_reason") == "spam", "and reports @bob to Muse")
	sp._close_card()

	# At the finale's door, when that's as far as his world goes (he lands there).
	await _until(func() -> bool: return sp._reel.is_empty(), 2.0)
	main.npc6 = 0
	player.global_position = ground
	party.beside = "@bob"
	_friend(3, Vector2(2804, -7000), "default", sp.IN_FINALE)
	await _frames(3)
	_expect(player.global_position.distance_to(sp.FINALE_DOOR) < 50.0, "joining someone past the finale's door his world hasn't opened, he's at the door (%s)" % player.global_position)
	await _wait(1.5)
	_expect(player.is_on_floor() and player.global_position.distance_to(sp.FINALE_DOOR) < 90.0,
		"and stands there, on the castle hall's floor (%s)" % player.global_position)

	# A party starting up the tree with the title up: the climb starts.
	player.get_node("titlescreen").visible = true
	player.get_node("Trajectory").endGame = 1
	sp._climb_on_title = true
	await _frames(4)
	_expect(not player.get_node("titlescreen").visible and player.get_node("Trajectory").endGame == 0,
		"a party starting up the tree from the title starts the climb")

	# The title leaves everyone's room.
	party.everyone = true
	player.get_node("titlescreen").visible = true
	await _frames(3)
	_expect(not party.is_on(), "back at the title, out of everyone's room")

	# Everyone's room dropping (the relay's daily allowance gone, say) says nothing: he climbs on alone.
	player.get_node("titlescreen").visible = false
	player.get_node("Trajectory").endGame = 0
	_expect(party.host() == "", "a party here again")
	party.players[2] = {"name": "@pal", "hat": "", "skin": "", "color": 0}
	party.start("story")
	party.everyone = true
	await _frames(3)
	sp._toast.modulate.a = 0.0
	party._end("Lost the online party.")  # (as Party does: out of it, then says so)
	await _frames(3)
	_expect(sp._toast.modulate.a == 0.0, "everyone's room dropping says nothing (it was never asked for)")
	sp._tried = true  # (he was in everyone's room, and now isn't: it's asked for again, in a while)
	sp._asking = false
	sp._climb_with_everyone()
	_expect(not sp._tried and sp._next_try >= Time.get_ticks_msec() / 1000.0 + 59.0,
		"in and then out again, everyone's room is tried again in a while")
	await _finish(real)


## Their phone says where their frog is: [x, y, animation, frame, flip, turn, score, height, band, where].
func _friend(peer: int, at: Vector2, anim: String, where: int) -> void:
	party.frog_moved.emit(peer, [at.x, at.y, anim, 0, false, 0.0, 0, 0, 0, where])


## Him, falling fast well below `above` (tied to the friend), for a moment.
func _fall_below(above: Vector2) -> void:
	sp._reel = {}
	player.set_physics_process(true)
	sp._tether_peer = 2
	player.global_position = above + Vector2(0, 230)
	player.velocity = Vector2(0, 420)
	sp._last_floor_y = above.y - 200.0
	await _frames(3)


## Somewhere in the open (he fits there and 400 under it): to fall through.
func _open_column() -> Vector2:
	for y in range(-1500, -7000, -250):
		for x in range(200, 5000, 150):
			var p := Vector2(x, y)
			var ok := true
			for d in range(0, 420, 20):
				if not sp._free_at(p + Vector2(0, d)):
					ok = false
					break
			if ok:
				return p
	return Vector2.INF


## How many of n frames (a 60th of a second each) sent the frog (Party.send_frog: _since_sent back to 0).
func _count_sends(state_at: Callable, n: int) -> int:
	var sent := 0
	party._send_left = 0.0
	party._since_sent = 10.0
	party._last_state = []
	for i in n:
		party.send_frog(state_at.call(i), 1.0 / 60.0)
		if party._since_sent == 0.0:
			sent += 1
	return sent


func _button(words: String) -> Button:
	if sp._card == null:
		return null
	for b in sp._card.find_children("*", "Button", true, false):
		if b.text == words:
			return b
	return null


func _fake_muse(path: String, body: Dictionary, _bearer: String) -> Dictionary:
	var fn := path.trim_prefix("/rest/v1/rpc/")
	_calls.append([fn, body])
	match fn:
		"muse_social_me":
			return {"code": 200, "data": {"handle": "froggy"}}
		"muse_social_friends_list":
			return {"code": 200, "data": {"friends": [{"handle": "pal"}], "incoming": [], "outgoing": []}}
		"muse_social_block", "muse_social_report":
			return {"code": 200, "data": null}
	return {"code": 404, "data": {"message": "no such function"}}


func _asked(fn: String) -> Array:
	var out := []
	for c in _calls:
		if c[0] == fn:
			out.append(c[1])
	return out


func _finish(real: Array) -> void:
	party.leave()
	if is_instance_valid(main):
		main.queue_free()
	await _frames(3)
	var acct := root.get_node("MuseAccount")
	var social := root.get_node("MuseSocial")
	acct.transport = Callable()
	acct._refresh_token = ""
	acct._access_token = ""
	acct.save_path = real[1]
	acct.changed.connect(social._on_account_changed)
	social.available = false
	social.me = {}
	party.settings_path = real[0]
	party.on_start = Callable()
	root.get_node("MusicManager").wardrobe_path = real[2]
	for p in [SCRATCH_SAVE, SCRATCH_PARTY, SCRATCH_MUSE, SCRATCH_WARDROBE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	if _failures.is_empty():
		print("Story party test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Story party test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _wait(seconds: float) -> void:
	await _until(func() -> bool: return false, seconds)


func _until(done: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call() and Time.get_ticks_msec() < end:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
