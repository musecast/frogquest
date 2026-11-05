extends SceneTree
## Headless check of Frog Frenzy (Frenzy.gd, Muse Pro's microgames).
## - The microgames are played as the real Froggy (his own jump), but EAT!, tapped: each won by doing it (him
##   put where a good jump takes him), and lost (or timed out) by not; SCARE! in his bedroom.
## - His jump's held while a microgame's word is up and after its time, let go only while it's on.
## - The rounds are planned the same from the same seed: never the same twice running, FASTER every four.
## - On your own: 3, 2, 1, a cleared round counts, a missed one costs a life, paused it stops; out of
##   lives it's over, and your best is kept.
## - Versus with a friend: what's said to the party, the standings, the last frog in winning (either way).
## - Team: one life a round however many miss it, and the rounds cleared.
## - A friend joining late starts where everyone is, owing nothing.
## - On a closed iPhone Duo (its camera strip down the right): the stage, hearts and round clear of it.
## - Party: "frenzy" starts it (PROTOCOL 3).
## - Play Together: Frog Frenzy for Muse Pro hosts, greyed without it.
## The wardrobe saves to a scratch file; yours is byte-checked.
##   Godot --headless --path . --script res://tools/validate_frenzy.gd


class ErrorCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


const WARDROBE := "user://test_frenzy_wardrobe.save"
const MUSE := "user://test_frenzy_muse.save"
const PAL := 2
const PAL2 := 3
const DT := 1.0 / 60.0

var _counter := ErrorCounter.new()
var _failures: Array[String] = []
var _said: Array = []


func _initialize() -> void:
	OS.add_logger(_counter)
	_run.call_deferred()


func _run() -> void:
	var mm := root.get_node("MusicManager")
	var party := root.get_node("Party")
	var real_path: String = mm.wardrobe_path
	var real_wardrobe := FileAccess.get_file_as_bytes(real_path)
	var real_best: int = mm.frenzy_best
	mm.wardrobe_path = WARDROBE
	mm.frenzy_best = 0

	await _microgames()
	_plans()
	await _solo()
	await _versus()
	await _versus_out_first()
	await _team()
	await _late()
	await _layout()
	_party_wiring(party)
	await _party_screen()

	party.in_run = false
	party.mode = "endless"
	party.race = ""
	party.players = {}
	mm.frenzy_best = real_best
	mm.wardrobe_path = real_path
	for f in [WARDROBE, MUSE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	if FileAccess.get_file_as_bytes(real_path) != real_wardrobe:
		_failures.append("the real wardrobe save changed")
	for err in _counter.errors:
		_failures.append("script error: " + err)
	if _failures.is_empty():
		print("Frenzy test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("Frenzy test failed (%d)." % _failures.size())
	quit(0 if _failures.is_empty() else 1)


# ── the microgames ──────────────────────────────────────────────────────────────────────────────

var _froggy: CharacterBody2D  # (the real Froggy, as Frenzy has him, for the microgames played as him)


func _micro(kind: String, seed_n := 7) -> Node2D:
	var frenzy: GDScript = load("res://scripts/Frenzy.gd")
	var m: Node2D = (load(frenzy.MICROS[kind][0]) as GDScript).new()
	m.rng.seed = seed_n
	m.froggy = _froggy
	root.add_child(m)
	m.begin()
	if m.uses_froggy:
		_froggy.global_position = m.froggy_at
		_froggy.velocity = Vector2.ZERO
		_froggy.visible = true
		_froggy.set_physics_process(true)
		m.froggy_placed()
	m.playing = true
	m.accepting = true
	return m


func _steps(m: Node2D, seconds: float, until := Callable()) -> void:
	var n := int(seconds / DT)
	for _i in n:
		if until.is_valid() and until.call():
			return
		m.step(DT)


func _done(m: Node2D) -> void:
	if m.uses_froggy:
		m.froggy_left()
	m.queue_free()
	await _frames(2)


func _microgames() -> void:
	_froggy = (load("res://scenes/endlessplayer.tscn") as PackedScene).instantiate()
	root.add_child(_froggy)
	for layer_name in ["CanvasLayer", "CRT Shader", "SCANLINES", "PauseScreen", "winscreen"]:
		var layer_node := _froggy.get_node_or_null(layer_name)
		if layer_node:
			layer_node.visible = false
	_froggy.get_node("Trajectory").endGame = 1  # (no stray jumps in here)
	await _frames(2)
	var kinds := {}
	for kind in ["scare", "fly", "hat", "wish", "key", "play"]:
		var m := _micro(kind)
		kinds[kind] = m.uses_froggy
		m.queue_free()
	_expect(not kinds.values().has(false), "the microgames are played as Froggy, his own jump and all (%s)" % [kinds])
	# He stands where he's put (a pixel over what's under him: one-way platforms let through what starts in them).
	var m := _micro("hat")
	for _i in 30:
		await physics_frame
	_expect(_froggy.is_on_floor() and _froggy.global_position.distance_to(m.froggy_at) < 3.0, "he's put on his feet, and stays there (%s, %s)"
		% [_froggy.global_position, m.froggy_at])
	await _done(m)
	# SCARE!: in his bedroom (the story's own), in the TV; out at her while she leans in: she's scared. Too soon, no.
	m = _micro("scare")
	_expect(m._room.get_node_or_null("Bae") != null and m._room.get_node_or_null("Beanbag") != null and m._screen.has_point(_froggy.global_position),
		"SCARE!: in his bedroom, him in the Muse TV")
	_steps(m, 6.0, func() -> bool: return m._lean > 0.8)
	_froggy.global_position = m._screen.position + Vector2(-14.0, m._screen.size.y * 0.5)
	m.step(DT)
	_expect(m.word == "SCARE!" and m.won and _froggy.z_index > 5, "SCARE!: out of the TV as she leans in, in front of it, and she's scared")
	await _done(m)
	m = _micro("scare")
	_steps(m, 0.1)
	_froggy.global_position = m._screen.position + Vector2(-14.0, m._screen.size.y * 0.5)
	m.step(DT)
	_expect(m.lost and not m.won, "SCARE!: out too soon, while she's sat back: she watches him come")
	await _done(m)
	# CATCH!: into the fly. Or not.
	m = _micro("fly")
	_froggy.global_position = m._fly.position + Vector2(6.0, 4.0)
	m.step(DT)
	_expect(m.word == "CATCH!" and m.won, "CATCH!: jumped into the fly")
	await _done(m)
	m = _micro("fly")
	_steps(m, 4.4)
	_expect(not m.timeout(), "CATCH!: no jump, no fly")
	await _done(m)
	# HAT!: into the hat, and he's wearing it (his own hidden meanwhile, and back after).
	m = _micro("hat")
	var his := 0
	for child in _froggy.get_children():
		if child is Sprite2D and child.visible:
			his += 1
	_froggy.global_position = m._hat.position
	m.step(DT)
	m.step(DT)
	_expect(m.word == "HAT!" and m.won and m._hat.position.distance_to(_froggy.global_position + Vector2(0.0, -m.FEET - m._tall * 0.5 + 2.0)) < 1.0,
		"HAT!: jumped into it, and he's wearing it")
	await _done(m)
	var back := 0
	for child in _froggy.get_children():
		if child is Sprite2D and child.visible:
			back += 1
	_expect(back == his, "and his own hat's back after (%d, %d)" % [his, back])
	# WISH!: into the shooting star; too slow and it's gone.
	m = _micro("wish")
	_steps(m, 2.0, func() -> bool: return m.t > m._comes + 0.2)
	_froggy.global_position = m._star
	m.step(DT)
	_expect(m.word == "WISH!" and m.won, "WISH!: the shooting star, caught")
	await _done(m)
	m = _micro("wish")
	_steps(m, 4.4)
	_expect(m.lost and m._mark != null and m._mark.text == "...", "WISH!: too slow, it's away over the edge")
	await _done(m)
	# UNLOCK!: up into the keyhole with the key.
	m = _micro("key")
	_froggy.global_position = m._hole
	m.step(DT)
	_expect(m.word == "UNLOCK!" and m.won, "UNLOCK!: the key in, turned")
	await _done(m)
	# PLAY!: down onto the jukebox and it plays; onto the floor, no song.
	m = _micro("play")
	m.step(DT)
	_froggy.global_position = m._top.position + Vector2(0.0, -m.FEET - 2.0)
	_froggy.velocity = Vector2.ZERO
	for _i in 30:
		m.step(DT)
		await physics_frame
		if m.won:
			break
	_expect(m.word == "PLAY!" and m.won, "PLAY!: down on the jukebox, and it plays")
	await _done(m)
	m = _micro("play")
	_froggy.global_position = Vector2(m._top.position.x + (130.0 if m._top.position.x < 0.0 else -130.0), m.FLOOR_Y - m.FEET - 2.0)
	_froggy.velocity = Vector2.ZERO
	for _i in 30:
		m.step(DT)
		await physics_frame
		if m.lost:
			break
	_expect(m.lost, "PLAY!: down on the floor instead: no song")
	await _done(m)
	# EAT!: tapped (every tap a bite); or the farmer frog's finished first.
	m = _micro("cake")
	_expect(not m.uses_froggy, "EAT!'s tapped")
	for _i in m._need:
		m.press(Vector2(66, 190))
	_expect(m.word == "EAT!" and m.won, "EAT!: the whole cake, bite by bite (%d)" % m._need)
	await _done(m)
	m = _micro("cake")
	_steps(m, 4.0)
	_expect(m.lost, "EAT!: too slow, the farmer frog's finished theirs")
	await _done(m)
	_froggy.queue_free()
	await _frames(2)


func _plans() -> void:
	var frenzy: GDScript = load("res://scripts/Frenzy.gd")
	var a: Node2D = frenzy.new()
	var b: Node2D = frenzy.new()
	for f in [a, b]:
		f._rng.seed = 424242
		for k in 13:
			f.plan.append(f._plan_round(k))
	var same := true
	var twice := false
	for k in 13:
		if a.plan[k] != b.plan[k]:
			same = false
		if k > 0 and a.plan[k].kind == a.plan[k - 1].kind:
			twice = true
	_expect(same, "the same seed, the same rounds (everyone's the same microgames at the same moments)")
	_expect(not twice, "never the same microgame twice running")
	_expect(not a.plan[3].faster and a.plan[4].faster and a.plan[8].faster and is_equal_approx(a.plan[3].speed, 1.0)
		and is_equal_approx(a.plan[4].speed, 1.14) and is_equal_approx(a.plan[8].speed, 1.28),
		"FASTER! every four (%.2f, %.2f, %.2f)" % [a.plan[3].speed, a.plan[4].speed, a.plan[8].speed])
	var kinds := {}
	for r in a.plan:
		kinds[r.kind] = true
	_expect(kinds.size() >= 5, "a good mix of them (%s)" % [kinds.keys()])
	a.free()
	b.free()


# ── on your own ─────────────────────────────────────────────────────────────────────────────────

func _solo() -> void:
	var mm := root.get_node("MusicManager")
	var f: Node2D = await _frenzy()
	_expect(f.style == "solo" and f.lives == 4, "on its own: solo, four lives")
	await _frames(2)
	_expect(f._word.text == "3", "3, 2, 1 to start (%s)" % f._word.text)
	f._solo_t = 3.02
	await _frames(2)
	_expect(f._round == 0 and f._micro != null and f.plan.size() >= 1, "then the first microgame")
	var aim: Node = f.froggy.get_node("Trajectory")
	_expect(aim.endGame == 1, "his jump held while its word's up")
	f._solo_t = float(f.plan[0].play_at) + 0.01
	await _frames(2)
	_expect(aim.endGame == (0 if f._micro.uses_froggy else 1) and f._micro.accepting, "and let go once it's on (if it's played as him)")
	f._solo_t = float(f.plan[0].word_at) + 0.01
	await _frames(2)
	_expect(f._word.text == f._micro.word, "its word, big (%s)" % f._word.text)
	f._micro.win()
	f._solo_t = float(f.plan[0].end_at) + 0.01
	await _frames(2)
	_expect(f.cleared == 1 and f.lives == 4, "cleared: one, no life lost")
	_expect(aim.endGame == 1 and not f._micro.accepting, "his jump held again once its time's up")
	f._solo_t = float(f.plan[0].next_at) + 0.01
	await _frames(2)
	_expect(f._round == 1 and f.plan.size() >= 2, "on to the next")
	f._solo_t = float(f.plan[1].end_at) + 0.01
	await _frames(2)
	_expect(f.cleared == 1 and f.lives == 3, "missed: a life gone (%d)" % f.lives)
	f.pause()
	var at: float = f._solo_t
	await _frames(10)
	_expect(f.paused and f._solo_t == at and _words(f._pause_menu).contains("Keep Playing") and _words(f._pause_menu).contains("Leave"),
		"paused: it stops where it is, Keep Playing or Leave")
	f._unpause()
	await _frames(3)
	_expect(not f.paused and f._solo_t > at, "and on it goes")
	f._solo_t += 40.0  # (four lives' worth of missing)
	await _frames(3)
	_expect(f.over and f.lives == 0, "out of lives: over")
	_expect(mm.frenzy_best == 1, "his best kept (%d)" % mm.frenzy_best)
	await create_timer(1.6).timeout
	var words := _words(f.results)
	_expect(words.contains("You cleared 1!") and words.contains("A new best!") and words.contains("Play Again"),
		"the results: how many, a new best, play again (%s)" % words)
	await _end(f)


# ── with a friend ───────────────────────────────────────────────────────────────────────────────

func _versus() -> void:
	var f: Node2D = await _frenzy("vs", 3100)
	_expect(f.style == "vs" and f._starters == 2, "versus, with a friend")
	await _frames(2)
	var party := root.get_node("Party")
	f._micro.win()
	party.run_started_ms -= int((float(f.plan[0].end_at) - party.run_seconds() + 0.02) * 1000.0)
	await _frames(2)
	_expect(_said.size() >= 1 and _said[0] == {"k": "fr", "i": 0, "ok": true, "l": 4, "c": 1}, "how it went, said to the party (%s)" % [_said])
	f._heard(PAL, {"k": "fr", "i": 0, "ok": false, "l": 3, "c": 0})
	var rows: Array = f.rows()
	_expect(rows.size() == 2 and rows[0].peer == party.me() and rows[1].peer == PAL and not f.over, "the standings: him ahead")
	f._heard(PAL, {"k": "fr", "i": 1, "ok": false, "l": 0, "c": 0})
	_expect(f.over and f._word.text == "YOU WIN!", "the friend's out: the last frog in, he wins")
	await create_timer(1.6).timeout
	var words := _words(f.results)
	_expect(words.contains("You won!") and words.contains("1st  @me") and words.contains("2nd  @pal"), "the results, in order (%s)" % words)
	await _end(f)


func _versus_out_first() -> void:
	# Two of them: his last life gone, the friend's the last in, and has won.
	var f: Node2D = await _frenzy("vs", 3100)
	await _frames(2)
	var party := root.get_node("Party")
	f.lives = 1
	party.run_started_ms -= int((float(f.plan[0].end_at) - party.run_seconds() + 0.02) * 1000.0)
	await _frames(2)
	_expect(f.out and f.over and _said.size() >= 1 and int(_said[-1].l) == 0, "out with one friend left in: over, and the party's told")
	await create_timer(1.6).timeout
	_expect(_words(f.results).contains("@pal won!"), "the friend's the last in: they won (%s)" % _words(f.results))
	await _end(f)
	# Three of them: he's out first and watches the other two.
	f = await _frenzy("vs", 3100, 2)
	await _frames(2)
	f.lives = 1
	party.run_started_ms -= int((float(f.plan[0].end_at) - party.run_seconds() + 0.02) * 1000.0)
	await _frames(2)
	_expect(f.out and not f.over and f._note.text.contains("out"), "out with two friends still in: he watches")
	party.run_started_ms -= 6000
	await _frames(2)
	_expect(f._micro == null and not f.over, "no more microgames for him; it goes on")
	f._heard(PAL, {"k": "fr", "i": f._round, "ok": false, "l": 0, "c": 2})
	_expect(f.over, "a friend out too: one left, over")
	await create_timer(1.6).timeout
	var words := _words(f.results)
	_expect(words.contains("@pal2 won!") and words.contains("2nd  @pal") and words.contains("3rd  @me"),
		"the last in won, and whoever lasted longer's next (%s)" % words)
	await _end(f)


func _team() -> void:
	var f: Node2D = await _frenzy("team", 3100)
	await _frames(2)
	var party := root.get_node("Party")
	f._team_said(party.me(), 0, false)
	f._heard(PAL, {"k": "fr", "i": 0, "ok": false, "l": 4, "c": 0})
	_expect(f.lives == 3, "a team: both missing one costs one life (%d)" % f.lives)
	f._heard(PAL, {"k": "fr", "i": 1, "ok": false, "l": 4, "c": 0})
	f._team_said(party.me(), 1, true)
	_expect(f.lives == 2, "the friend missing the next: another (%d)" % f.lives)
	f._team_said(party.me(), 2, true)
	f._heard(PAL, {"k": "fr", "i": 2, "ok": true, "l": 4, "c": 1})
	_expect(f.lives == 2 and f.team_cleared() == 1, "both clearing one: no life lost, one cleared")
	f._team_said(party.me(), 3, false)
	f._team_said(party.me(), 4, false)
	_expect(f.over and f.lives == 0, "four rounds missed between them: over")
	await create_timer(1.6).timeout
	_expect(_words(f.results).contains("Your team cleared 1!"), "the team's results (%s)" % _words(f.results))
	await _end(f)


func _late() -> void:
	var plan: Array = _plan_of(20261105, 5)
	# In while one's on: straight into it, all four lives.
	var f: Node2D = await _frenzy("vs", int((float(plan[3].play_at) + 0.5) * 1000.0))
	await _frames(2)
	_expect(f._round == 3 and f.lives == 4 and f._micro != null and f._settled < 3,
		"joining late, while one's on: straight into it, all four lives (round %d, %d lives)" % [f._round, f.lives])
	await _end(f)
	# In just as one ends: that one's not his, the next is; nothing owed.
	f = await _frenzy("vs", int((float(plan[3].end_at) + 0.3) * 1000.0))
	await _frames(2)
	_expect(f._round == 3 and f.lives == 4 and f._micro == null and f._note.text == "Get ready for the next one!",
		"joining late, as one ends: ready for the next, nothing owed (%d lives, \"%s\")" % [f.lives, f._note.text])
	var party := root.get_node("Party")
	party.run_started_ms -= int((float(plan[3].next_at) - party.run_seconds() + 0.05) * 1000.0)
	await _frames(2)
	_expect(f._round == 4 and f._micro != null and f._note.text == "" and f.lives == 4, "then the next one's his")
	await _end(f)


## The rounds a seed plans, as everyone's Frenzy does.
func _plan_of(seed_n: int, n: int) -> Array:
	var f: Node2D = (load("res://scripts/Frenzy.gd") as GDScript).new()
	f._rng.seed = seed_n
	for k in n:
		f.plan.append(f._plan_round(k))
	var plan: Array = f.plan.duplicate(true)
	f.free()
	return plan


## Upright on a closed Duo, its camera strip down the right (UIStyle.room stops short of it): the stage in
## the middle of the screen and clear of the strip, the hearts and the round's number too.
func _layout() -> void:
	var ads := root.get_node("AdsManager")
	var real := [ads.test_safe_insets, ads.test_banner_clearance]
	var view := SubViewport.new()
	view.size = Vector2i(480, 698)
	root.add_child(view)
	ads.test_safe_insets = Vector4(0.0, 0.0, 480.0 * 0.18, 0.0)
	ads.test_banner_clearance = Vector2.ZERO
	root.get_node("Party").in_run = false
	var f: Node2D = (load("res://scenes/Frenzy.tscn") as PackedScene).instantiate()
	view.add_child(f)
	f._solo_t = 3.1
	await _frames(3)
	var room: Rect2 = load("res://scripts/UIStyle.gd").room(Vector2(480, 698))
	var stage := Rect2(f._stage_bg.position, f._stage_bg.size)
	_expect(room.size.x < 480.0 and stage.position.x >= room.position.x and stage.end.x <= room.end.x,
		"the stage clear of the camera strip (%s in %s)" % [stage, room])
	_expect(absf(stage.get_center().x - 240.0) < 40.0 and stage.size.x > 300.0, "and big, in the middle of the screen (%s)" % stage)
	var label := Rect2(f._round_label.position, f._round_label.size)
	_expect(f._hearts_at.x + 60.0 <= room.end.x and label.end.x <= room.end.x and label.position.x > f._hearts_at.x + 60.0,
		"the hearts and the round's number clear of it and of each other (%s, %s)" % [f._hearts_at, label])
	f.queue_free()
	view.queue_free()
	ads.test_safe_insets = real[0]
	ads.test_banner_clearance = real[1]
	await _frames(2)


func _party_wiring(party: Node) -> void:
	_expect(party.PROTOCOL == 3, "the party's protocol moved on (a new mode)")
	_expect(party.what_of("frenzy") == "frenzy" and party.what_of("story") == "story" and party.what_of("??") == "endless",
		"what a start says the party plays")
	var real_start: Callable = party.on_start
	party.on_start = func() -> void: pass
	party._begin(11, 0, "frenzy", "team")
	_expect(party.mode == "frenzy" and party.race == "team", "Frog Frenzy, as a team")
	party._begin(11, 0, "frenzy", "minute")
	_expect(party.race == "vs", "anything else: versus")
	party._begin(11, 0, "endless", "team")
	_expect(party.mode == "endless" and party.race == "", "and a team's no race up Endless")
	party.on_start = real_start
	party.in_run = false


func _party_screen() -> void:
	var acct := root.get_node("MuseAccount")
	var real := [acct.save_path, acct._loaded, acct._refresh_token, acct._pro, acct._pro_checked_at]
	acct.save_path = MUSE
	acct._loaded = true
	acct._refresh_token = ""
	acct._pro = false
	var screen: CanvasLayer = load("res://scenes/PartyScreen.gd").new()
	root.add_child(screen)
	await _frames(2)
	var buttons := _buttons(screen)
	_expect(buttons.get("Frog Frenzy (Beta)") == false and _words(screen).contains("Frog Frenzy needs Muse Pro."),
		"without Muse Pro: Frog Frenzy greyed, and why (%s)" % [buttons])
	_restart(screen)
	buttons = _buttons(screen)
	_expect(buttons.get("Frog Frenzy Beta: Versus") == false and buttons.get("Frog Frenzy Beta: Team") == false,
		"a party's Frog Frenzy greyed for a host without it (%s)" % [buttons])
	acct._refresh_token = "test"
	acct._pro = true
	acct._pro_checked_at = acct._now()
	screen._show()
	await _frames(1)
	_expect(_buttons(screen).get("Frog Frenzy (Beta)") == true, "with Muse Pro: Frog Frenzy (in beta), on your own")
	_restart(screen)
	buttons = _buttons(screen)
	_expect(buttons.get("Frog Frenzy Beta: Versus") == true and buttons.get("Frog Frenzy Beta: Team") == true,
		"and for the party, versus or as a team (%s)" % [buttons])
	screen.queue_free()
	acct.save_path = real[0]
	acct._loaded = real[1]
	acct._refresh_token = real[2]
	acct._pro = real[3]
	acct._pro_checked_at = real[4]
	await _frames(2)


func _restart(screen: CanvasLayer) -> void:
	for old in screen._box.get_children():
		screen._box.remove_child(old)
		old.queue_free()
	screen._starts()


func _buttons(screen: CanvasLayer) -> Dictionary:
	var all := {}
	for b in screen._box.find_children("*", "Button", true, false):
		all[b.text] = not b.disabled
	return all


# ── helpers ─────────────────────────────────────────────────────────────────────────────────────

## Frog Frenzy: on your own (style ""), or with a friend (@pal, and @pal2 with two) in a party, its clock
## `ago_ms` in.
func _frenzy(style := "", ago_ms := 0, friends := 1) -> Node2D:
	var party := root.get_node("Party")
	if style != "":
		party.players = {party.me(): {"name": "@me"}, PAL: {"name": "@pal"}}
		if friends > 1:
			party.players[PAL2] = {"name": "@pal2"}
		party.in_run = true
		party.mode = "frenzy"
		party.race = style
		party.run_seed = 20261105
		party.run_started_ms = Time.get_ticks_msec() - ago_ms
	else:
		party.in_run = false
		party.players = {}
	_said.clear()
	var f: Node2D = (load("res://scenes/Frenzy.tscn") as PackedScene).instantiate()
	root.add_child(f)
	f.said.connect(func(what: Dictionary) -> void: _said.append(what))
	await _frames(1)
	return f


func _end(f: Node) -> void:
	f.queue_free()
	await _frames(3)


func _words(node: Node) -> String:
	var all := []
	if node == null:
		return ""
	for n in node.find_children("*", "", true, false):
		if n is Label or n is Button:
			all.append(n.text)
	return " | ".join(all)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
		push_warning("FAIL: " + what)
