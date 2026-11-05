extends Node2D
## FROG FRENZY (Muse Pro's): Froggy's microgames one after another, a few seconds each. A word says what to
## do (SCARE! EAT! DROP! WISH! CATCH! HAT! UNLOCK!), then do it before the bar runs out; faster every few
## (FASTER!), the Muse TV's song speeding up with it. Four lives. On your own it's how many you can clear
## (your best kept). With a party: VERSUS, everyone given the same microgames at the same moments on the
## party's clock, the last frog with lives left winning; or TEAM, the lives shared, any of you missing one
## costing the team a life. A host with Muse Pro starts it from Play Together, for friends with or
## without Pro. The original Endless checkerboard behind it, each microgame on its own square stage
## (Micro.gd), the climb's CRT over it all.

signal said(what: Dictionary)  # (your news, as it goes to the others: the tests listen)

const MICROS := {  # (each: its script, its seconds at the first speed, its stage's colour)
	"scare": ["res://scripts/frenzy/MicroScare.gd", 4.0, Color(0.20, 0.16, 0.30)],
	"cake": ["res://scripts/frenzy/MicroCake.gd", 4.0, Color(0.98, 0.88, 0.70)],
	"record": ["res://scripts/frenzy/MicroRecord.gd", 3.6, Color(0.18, 0.137, 0.447)],
	"wish": ["res://scripts/frenzy/MicroWish.gd", 3.6, Color(0.004, 0.02, 0.06)],
	"fly": ["res://scripts/frenzy/MicroFly.gd", 3.6, Color(0.55, 0.78, 0.96)],
	"hat": ["res://scripts/frenzy/MicroHat.gd", 4.0, Color(0.62, 0.84, 0.58)],
	"key": ["res://scripts/frenzy/MicroKey.gd", 4.0, Color(0.52, 0.50, 0.58)],
}
const LIVES := 4
const COUNTDOWN := 3.0
const WORD := 0.8  # (seconds the word's up before it's on)
const RESULT := 0.9  # (seconds of how it went, before the next)
const FASTER_EVERY := 4
const FASTER := 1.3  # (seconds of FASTER! before the next)
const SPEEDUP := 0.14
const SONG := "res://assets/leafedfiltered.ogg"  # (the Muse TV's show)
const SONG_DB := -9.0
const SONG_FASTEST := 1.5
const STAGE := 240.0
const CREAM := Color(0.97, 0.92, 0.80)
const GOLD := Color(1.0, 0.86, 0.42)
const DIM := Color(0.78, 0.74, 0.68)
const GREEN := Color(0.5, 1.0, 0.5)
const HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const STYLES := {"vs": "Versus", "team": "Team"}
const PLACES := ["1st", "2nd", "3rd"]

var style := "solo"  # solo, vs or team
var lives := LIVES  # (yours; in a team, the team's)
var cleared := 0  # (yours)
var over := false
var out := false  # (in versus: out of lives, watching the others)
var paused := false
var results: CanvasLayer
var plan := []  # each round: {kind, speed, faster, word_at, play_at, end_at, next_at}, the same for everyone
var _rng := RandomNumberGenerator.new()
var _seed := 0
var _round := -1
var _settled := -1
var _worded := -1
var _micro: Node2D
var _solo_t := 0.0
var _counted := 0
var _starters := 1  # (frogs in it at the start: alone, you play till you're out)
var _peers := {}  # peer -> {lives, cleared, out, out_round}
var _team := {}  # round -> {peer: cleared it?}, in a team
var _out_round := -1
var _hurt_t := 9.0  # (seconds since a heart went: it shrinks away)
var _new_best := false
var _party_over := ""
var _down := false
var _portrait := true
var _layer: CanvasLayer
var _stage_bg: ColorRect
var _stage: Node2D
var _hud: Control
var _hearts_at := Vector2.ZERO
var _word: Label
var _word_tween: Tween
var _bar: ColorRect
var _bar_back: ColorRect
var _round_label: Label
var _standings: VBoxContainer
var _note: Label
var _pause_button: Button
var _pause_menu: CanvasLayer
var _song: AudioStreamPlayer


func _ready() -> void:
	style = Party.race if Party.in_run and Party.mode == "frenzy" and Party.race in STYLES else "solo"
	_seed = Party.run_seed if style != "solo" else randi()
	_rng.seed = _seed
	_starters = maxi(1, Party.players.size()) if style != "solo" else 1
	_build()
	if style != "solo":
		Party.race_said.connect(_heard)
		Party.players_changed.connect(_on_players_changed)
		Party.ended.connect(_on_party_ended)
	AdsManager.hide_banner()
	MuseSocial.set_activity("frenzy")
	_show_standings()


## Seconds since it started: the party's clock in a party (everyone's rounds at the same moments), your own
## (stopped while paused) on your own.
func now() -> float:
	return Party.run_seconds() if style != "solo" else _solo_t


func _build() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	_layer = CanvasLayer.new()
	add_child(_layer)
	var bg := ColorRect.new()  # (the original Endless background)
	var checks := ShaderMaterial.new()
	checks.shader = load("res://checkerboardendless.gdshader")
	bg.material = checks
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(bg)
	_stage_bg = ColorRect.new()
	_stage_bg.color = Color(0.16, 0.12, 0.10)
	_stage_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_stage_bg)
	_stage = Node2D.new()
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.add_child(_stage)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	_layer.add_child(_hud)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.1, 0.07, 0.05, 0.85)
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = Color(0.4, 0.85, 0.35)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bar)
	_round_label = Label.new()
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.style_label(_round_label, 16, CREAM)
	_layer.add_child(_round_label)
	_standings = VBoxContainer.new()
	_standings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standings.add_theme_constant_override("separation", 0)
	_layer.add_child(_standings)
	_note = _label("", 16, CREAM)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_note)
	_word = Label.new()
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word.modulate.a = 0.0
	ui.style_label(_word, 64, CREAM)
	_layer.add_child(_word)
	_make_pause_button()
	# (the climb's CRT and scanlines over it all, as Endless has them: endlessplayer.tscn)
	for i in 2:
		var over_layer := CanvasLayer.new()
		over_layer.layer = 2
		add_child(over_layer)
		var rect := ColorRect.new()
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		if i == 0:
			mat.shader = load("res://scripts/crt.gdshader")
			var crt := {"overlay": true, "scanlines_opacity": 0.0, "scanlines_width": 0.25, "grille_opacity": 0.0,
				"resolution": Vector2(160, 120), "pixelate": false, "roll": false, "roll_speed": 8.0, "roll_size": 19.018,
				"roll_variation": 0.671, "distort_intensity": 0.01, "noise_opacity": 0.0, "noise_speed": 5.0,
				"static_noise_intensity": 0.05, "aberration": 0.0, "brightness": 1.05, "discolor": false,
				"warp_amount": 0.0, "clip_warp": false, "vignette_intensity": 0.0, "vignette_opacity": 0.0}
			for k in crt:
				mat.set_shader_parameter(k, crt[k])
		else:
			mat.shader = load("res://scenes/SCANLINES.gdshader")
			mat.set_shader_parameter("scanline_count", 411.1110195277725)
		rect.material = mat
		over_layer.add_child(rect)
	_song = AudioStreamPlayer.new()
	_song.stream = load(SONG)
	_song.bus = &"Music"
	_song.volume_db = -40.0
	add_child(_song)
	_song.finished.connect(_song.play)
	_song.play()
	_ease(_song, "volume_db", SONG_DB, 1.5)


## The story's own pause button (as Endless has it): a white square, two black bars in it.
func _make_pause_button() -> void:
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.8, 0.8, 0.8) if state.contains("pressed") else Color.WHITE
		_pause_button.add_theme_stylebox_override(state, face)
	for left in [3.0, 11.0]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = left / 20.0
		bar.anchor_right = (left + 6.0) / 20.0
		bar.anchor_top = 3.0 / 20.0
		bar.anchor_bottom = 17.0 / 20.0
		_pause_button.add_child(bar)
	_pause_button.pressed.connect(pause)
	_layer.add_child(_pause_button)


func _process(delta: float) -> void:
	_hurt_t += delta
	_fit()
	_hud.queue_redraw()
	if over:
		return
	if style == "solo":
		if paused:
			return
		_solo_t += minf(delta, 0.1)  # (a hitch doesn't skip a microgame)
	var t := now()
	if t < COUNTDOWN:
		var n := int(ceil(COUNTDOWN - t))
		if n != _counted:
			_counted = n
			_pop(str(n))
			_sound("res://assets/frogaim.wav", 0.9 + 0.1 * (3 - n))
		return
	while plan.is_empty() or t >= float(plan[-1].next_at):
		plan.append(_plan_round(plan.size()))
	var k := maxi(_round, 0)
	while k < plan.size() - 1 and t >= float(plan[k].next_at):
		k += 1
	if k != _round:
		var first := _round < 0
		if not first:
			if _settled < _round:
				_settle(_round)
			for missed in range(_round + 1, k):  # (a stall: the ones it went past are missed)
				_miss(missed)
		if over:
			return
		_begin_round(k)
		var late := float(plan[k].play_at) + (float(plan[k].end_at) - float(plan[k].play_at)) * 0.3
		if first and t > late:  # (a friend come late, most of one gone: the next is theirs)
			_settled = k
			_worded = k
			if _micro:
				_micro.queue_free()
				_micro = null
			_note.text = "Get ready for the next one!"
	var r: Dictionary = plan[k]
	if _worded < k and t >= float(r.word_at):
		_worded = k
		if _micro:
			_pop(_micro.word)
	if _micro and t >= float(r.play_at):
		_micro.playing = true
		_micro.step(minf(delta, 0.1))
	if t >= float(r.end_at) and _settled < k:
		_settle(k)
	var left := 1.0
	if t >= float(r.play_at):
		left = clampf((float(r.end_at) - t) / maxf(0.01, float(r.end_at) - float(r.play_at)), 0.0, 1.0)
	_bar.color = Color(0.4, 0.85, 0.35).lerp(Color(0.95, 0.3, 0.25), 1.0 - left)
	_bar.size.x = _bar_back.size.x * left


## Round k, made the same for everyone from the seed: which microgame (never the same twice running), how
## fast, and when each part of it is.
func _plan_round(k: int) -> Dictionary:
	var start := COUNTDOWN if k == 0 else float(plan[k - 1].next_at)
	var faster := k > 0 and k % FASTER_EVERY == 0
	var speed := 1.0 + SPEEDUP * floorf(float(k) / FASTER_EVERY)
	var kinds := MICROS.keys()
	var kind: String = kinds[_rng.randi_range(0, kinds.size() - 1)]
	if k > 0 and kind == plan[k - 1].kind:
		kind = kinds[(kinds.find(kind) + 1 + _rng.randi_range(0, kinds.size() - 2)) % kinds.size()]
	var word_at := start + (FASTER if faster else 0.0)
	var play_at := word_at + WORD
	var end_at := play_at + float(MICROS[kind][1]) / speed
	return {"kind": kind, "speed": speed, "faster": faster, "word_at": word_at, "play_at": play_at, "end_at": end_at,
		"next_at": end_at + RESULT}


func _begin_round(k: int) -> void:
	_round = k
	_down = false
	if _micro:
		_micro.queue_free()
		_micro = null
	var r: Dictionary = plan[k]
	if r.faster:
		_pop("FASTER!")
		_sound("res://assets/powerUp.wav", 1.0)
		_ease(_song, "pitch_scale", minf(float(r.speed), SONG_FASTEST), 0.8)
	_ease(_stage_bg, "color", MICROS[r.kind][2], 0.25)
	if out:
		return
	_note.text = ""
	_micro = (load(MICROS[r.kind][0]) as GDScript).new()
	_micro.speed = float(r.speed)
	_micro.rng.seed = hash([_seed, k])
	_stage.add_child(_micro)
	_micro.begin()


## How round k went: cleared, or a life gone (in a team, the team's).
func _settle(k: int) -> void:
	_settled = k
	if out or _micro == null:
		return
	var ok: bool = _micro.won or (not _micro.lost and _micro.timeout())
	if ok:
		cleared += 1
		_sound("res://assets/pickupCoin.wav", 1.2)
	else:
		_sound("res://assets/wrong.mp3", 1.0)
	if style == "team":
		_team_said(Party.me(), k, ok)
	elif not ok:
		_lose_life()
	_say({"k": "fr", "i": k, "ok": ok, "l": lives, "c": cleared})
	_show_standings()
	_check_vs()


## One gone past without being played (the phone stalled): missed.
func _miss(k: int) -> void:
	_settled = k
	if out:
		return
	if style == "team":
		_team_said(Party.me(), k, false)
	else:
		_lose_life()
	_say({"k": "fr", "i": k, "ok": false, "l": lives, "c": cleared})
	_check_vs()


func _lose_life() -> void:
	if lives <= 0:
		return
	lives -= 1
	_hurt_t = 0.0
	if lives > 0:
		return
	if style == "vs":
		out = true
		_out_round = maxi(_round, 0)
		_pop("OUT!", 0.8)
		_note.text = "You're out! Watching the others..."
	else:
		finish()


## In a team: how a frog did in round k. The team's lives are four less one for each round any of you
## missed, so every phone comes to the same, whatever order the news gets there in.
func _team_said(peer: int, k: int, ok: bool) -> void:
	if not _team.has(k):
		_team[k] = {}
	_team[k][peer] = ok
	var now_lives := LIVES
	for i in _team:
		if false in _team[i].values():
			now_lives -= 1
	now_lives = maxi(0, now_lives)
	if now_lives < lives:
		_hurt_t = 0.0
	lives = now_lives
	if lives <= 0:
		finish()


## The rounds the team cleared: everyone in them, no one missing it.
func team_cleared() -> int:
	var n := 0
	for i in _team:
		if not (false in _team[i].values()):
			n += 1
	return n


## In versus, the last frog standing has won (alone, you play till you're out).
func _check_vs() -> void:
	if style == "vs" and not over and _alive() <= (1 if _starters > 1 else 0):
		finish()


func _alive() -> int:
	var n := 0 if out else 1
	for peer in Party.players:
		if int(peer) != Party.me() and not bool(_peers.get(int(peer), {}).get("out", false)):
			n += 1
	return n


func _heard(peer: int, what: Dictionary) -> void:
	if str(what.get("k", "")) != "fr" or peer == Party.me():
		return
	var i := int(what.get("i", 0))
	var p: Dictionary = _peers.get(peer, {"lives": LIVES, "cleared": 0, "out": false, "out_round": -1})
	p.lives = int(what.get("l", p.lives))
	p.cleared = maxi(int(p.cleared), int(what.get("c", 0)))
	if style == "vs" and p.lives <= 0 and not p.out:
		p.out = true
		p.out_round = i
	_peers[peer] = p
	if style == "team" and not over:
		_team_said(peer, i, bool(what.get("ok", true)))
	_show_standings()
	_check_vs()


func _on_players_changed() -> void:
	_show_standings()
	_check_vs()


func _say(what: Dictionary) -> void:
	if style != "solo":
		Party.say_race(what)
		said.emit(what)


func _unhandled_input(event: InputEvent) -> void:
	if over or out or paused or _micro == null or _round < 0 or _settled >= _round:
		return
	var r: Dictionary = plan[_round]
	var t := now()
	if t < float(r.play_at) or t >= float(r.end_at):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _stage.to_local(event.position)
		if event.pressed:
			_down = true
			_micro.press(at)
		elif _down:
			_down = false
			_micro.release(at)
	elif event is InputEventMouseMotion and _down:
		_micro.move(_stage.to_local(event.position))


## Everyone in it, best first: in versus, those still in, then whoever lasted longest, then the most
## cleared; in a team, the most cleared.
func rows() -> Array:
	var all := [{"peer": Party.me(), "name": _name_of(Party.me()), "cleared": cleared, "out": out, "out_round": _out_round}]
	for peer in Party.players:
		if int(peer) == Party.me():
			continue
		var p: Dictionary = _peers.get(int(peer), {})
		all.append({"peer": int(peer), "name": _name_of(int(peer)), "cleared": int(p.get("cleared", 0)),
			"out": bool(p.get("out", false)), "out_round": int(p.get("out_round", -1))})
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.out != b.out:
			return not a.out
		if a.out and a.out_round != b.out_round:
			return a.out_round > b.out_round
		if a.cleared != b.cleared:
			return a.cleared > b.cleared
		return a.peer < b.peer)
	return all


func _name_of(peer: int) -> String:
	var name := str(Party.players.get(peer, {}).get("name", Party.NAME))
	if name == Party.NAME and Party.players.size() > 1:
		name += " #%d" % peer
	return name


## Up in the corner: your best on your own; in a party, the top three (and you, if you're not).
func _show_standings() -> void:
	for old in _standings.get_children():
		_standings.remove_child(old)
		old.queue_free()
	if style == "solo":
		if MusicManager.frenzy_best > 0:
			_standings.add_child(_hud_label("Best %d" % MusicManager.frenzy_best, DIM))
		return
	var all := rows()
	for i in all.size():
		var row: Dictionary = all[i]
		if i >= 3 and row.peer != Party.me():
			continue
		var text: String = "%s  %s" % [row.name, "out" if row.out else str(row.cleared)]
		_standings.add_child(_hud_label(text, GOLD if row.peer == Party.me() else (DIM if row.out else CREAM)))


func _hud_label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load("res://scripts/UIStyle.gd").style_label(l, 16, colour)
	return l


## The words: 3, 2, 1, each microgame's, FASTER!, OUT!: big over the stage, easing in and away.
func _pop(text: String, hold := 0.4) -> void:
	_word.text = text
	_word.pivot_offset = _word.size * 0.5
	if _word_tween:
		_word_tween.kill()
	_word.scale = Vector2(1.4, 1.4)
	_word.modulate.a = 0.0
	_word_tween = _word.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	_word_tween.tween_property(_word, "scale", Vector2.ONE, 0.25)
	_word_tween.tween_property(_word, "modulate:a", 1.0, 0.15)
	_word_tween.chain().tween_property(_word, "modulate:a", 0.0, 0.3).set_delay(hold)


func _ease(what: Object, property: String, to: Variant, seconds: float) -> void:
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(what, property, to, seconds)


func _sound(path: String, pitch: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = &"FX"
	p.pitch_scale = pitch
	p.volume_db = -8.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## The stage as big as fits, square, under the pause button's strip and over the bar; the hearts in the
## middle up top, the round's number and the standings to the right.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	if portrait != _portrait:
		_portrait = portrait
		ui.style_label(_word, 64 if portrait else 48, CREAM)
	var t := inverse_lerp(0.65, 1.3, clampf(vp.y / vp.x, 0.65, 1.3))
	var button := 20.0 * lerpf(1.5, 2.5, t)  # (as Endless's: 20 across at 1.5 to 2.5 times, 26 to 42 in)
	var middle := lerpf(26.0, 42.0, t)
	_pause_button.custom_minimum_size = Vector2(button, button)
	_pause_button.size = Vector2(button, button)
	_pause_button.position = (room.position + Vector2(middle, middle) - Vector2(button, button) * 0.5).round()
	_hearts_at = Vector2(vp.x * 0.5, room.position.y + middle - 9.0).round()  # (the screen's middle: UIStyle.across)
	var top := room.position.y + middle * 2.0
	var bottom := room.end.y - 36.0
	var span: Vector2 = ui.across(vp, room, room.size.x - 24.0)  # (in the screen's middle, clear of a camera strip)
	var side := maxf(60.0, minf(span.y, bottom - top))
	var at := Vector2(span.x + (span.y - side) * 0.5, top + (bottom - top - side) * 0.5).round()
	_stage.position = at
	_stage.scale = Vector2.ONE * side / STAGE
	_stage_bg.position = at
	_stage_bg.size = Vector2(side, side)
	_bar_back.position = Vector2(at.x, at.y + side + 12.0)
	_bar_back.size = Vector2(side, 10.0)
	_bar.position = _bar_back.position
	_bar.size.y = 10.0
	_word.size = Vector2(span.y, 96.0)
	_word.position = Vector2(span.x, at.y + side * 0.5 - 48.0).round()
	_word.pivot_offset = _word.size * 0.5
	_note.size = Vector2(side, 0.0)
	_note.position = Vector2(at.x, at.y + side * 0.72).round()
	_round_label.text = "Round %d" % (_round + 1) if _round >= 0 else ""
	_round_label.size = _round_label.get_minimum_size()
	_round_label.position = Vector2(room.end.x - _round_label.size.x - 12.0, room.position.y + middle - _round_label.size.y * 0.5).round()
	_standings.size = _standings.get_combined_minimum_size()
	_standings.position = Vector2(room.end.x - _standings.size.x - 12.0, _round_label.position.y + _round_label.size.y).round()
	for panel_layer in [_pause_menu, results]:
		if panel_layer != null:
			var panel: Control = panel_layer.get_node("Panel")
			ui.fit_panel(panel, panel.find_child("Scroll", true, false), room, ui.panel_zoom(vp, room), 0.8 if portrait else 0.5)


## The hearts up top (the team's, in a team): a heart just lost shrinks away.
func _draw_hud() -> void:
	var px := 3.0 if _portrait else 2.0
	var wide := 7.0 * px
	var gap := px * 2.0
	var total := LIVES * wide + (LIVES - 1) * gap
	for i in LIVES:
		var middle := Vector2(_hearts_at.x - total * 0.5 + i * (wide + gap) + wide * 0.5, _hearts_at.y + 3.0 * px)
		_draw_heart(middle, px, Color(0.25, 0.2, 0.22, 0.8), 1.0)
		if i < lives:
			_draw_heart(middle, px, Color(0.92, 0.25, 0.3), 1.0)
		elif i == lives and _hurt_t < 0.5:
			_draw_heart(middle, px, Color(0.92, 0.25, 0.3), 1.0 - smoothstep(0.0, 0.5, _hurt_t))


func _draw_heart(middle: Vector2, px: float, colour: Color, k: float) -> void:
	if k <= 0.0:
		return
	_hud.draw_set_transform(middle, 0.0, Vector2(k, k))
	for y in HEART.size():
		var row: String = HEART[y]
		for x in row.length():
			if row[x] == "#":
				_hud.draw_rect(Rect2(Vector2(x - 3.5, y - 3.0) * px, Vector2(px, px)), colour)
	_hud.draw_set_transform(Vector2.ZERO)


## Paused: on your own, it stops where it is; in a party it goes on without you.
func pause() -> void:
	if over or _pause_menu != null or results != null or not is_inside_tree():
		return
	paused = true
	_down = false
	if style == "solo":
		_song.stream_paused = true
	_pause_menu = _panel("Paused", 75)
	var box: VBoxContainer = _pause_menu.get_meta("box")
	if style != "solo":
		box.add_child(_label("The game goes on without you!", 16, DIM))
	box.add_child(_button("Keep Playing", _unpause, "go"))
	box.add_child(_button("Leave" if style == "solo" else "Leave Party", _leave, "quiet"))
	_fit()


func _unpause() -> void:
	paused = false
	_song.stream_paused = false
	if _pause_menu:
		_pause_menu.queue_free()
		_pause_menu = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause()


## Over: GAME OVER (or YOU WIN!), your best kept on your own, the music away; then the results.
func finish() -> void:
	if over:
		return
	over = true
	_down = false
	if _micro:
		_micro.playing = false
	if style == "solo" and cleared > MusicManager.frenzy_best:
		MusicManager.frenzy_best = cleared
		MusicManager.save_wardrobe()
		_new_best = true
	var won := style == "vs" and _starters > 1 and not out
	_pop("YOU WIN!" if won else "GAME OVER", 0.9)
	_sound("res://assets/coolfind.mp3" if won else "res://assets/fallendown.mp3", 1.0)
	_ease(_song, "volume_db", -40.0, 1.2)
	get_tree().create_timer(1.4).timeout.connect(_show_results)


func _show_results() -> void:
	if not is_inside_tree() or results != null:
		return
	if _pause_menu:
		_unpause()
	results = _panel("FROG FRENZY", 70)
	var box: VBoxContainer = results.get_meta("box")
	match style:
		"solo":
			box.add_child(_label("You cleared %d!" % cleared, 16, GOLD))
			box.add_child(_label("A new best!" if _new_best else "Your best: %d" % MusicManager.frenzy_best, 16,
				GREEN if _new_best else CREAM))
			box.add_child(_button("Play Again", func() -> void: get_tree().reload_current_scene(), "go"))
			box.add_child(_button("Leave", _leave, "quiet"))
			_fit()
			return
		"team":
			box.add_child(_label("Your team cleared %d!" % team_cleared(), 16, GOLD))
			for row in rows():
				box.add_child(_label("%s  %d cleared" % [row.name, row.cleared], 16, GOLD if row.peer == Party.me() else CREAM))
		"vs":
			var all := rows()
			if all.size() > 1:
				box.add_child(_label("You won!" if all[0].peer == Party.me() else "%s won!" % all[0].name, 16, GOLD))
			for i in all.size():
				var place: String = PLACES[i] if i < PLACES.size() else "%dth" % (i + 1)
				box.add_child(_label("%s  %s  %d cleared" % [place, all[i].name, all[i].cleared], 16,
					GOLD if all[i].peer == Party.me() else CREAM))
	if _party_over != "":
		box.add_child(_label(_party_over, 16, DIM))
	if Party.is_host():
		box.add_child(_button("Play Again", func() -> void: Party.start("frenzy", style), "go"))
		var other := "team" if style == "vs" else "vs"
		box.add_child(_button("Play %s" % STYLES[other], func() -> void: Party.start("frenzy", other), "wood"))
		box.add_child(_button("Climb Together", func() -> void: Party.start("endless"), "wood"))
	elif Party.is_on():
		box.add_child(_label("Waiting for the host to start the next one...", 16, DIM))
	box.add_child(_button("Leave Party" if Party.is_on() else "Leave", _leave, "quiet"))
	_fit()


func _on_party_ended(why: String) -> void:
	_party_over = why if why != "" else "The party's over."
	if not over:
		finish()
	elif results != null:  # (the host's buttons are no good now)
		results.queue_free()
		results = null
		_show_results()


func _leave() -> void:
	if Party.is_on():
		Party.leave()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


## A menu panel (the pause menu, the results), dressed as the others, fading in; what goes in it goes in
## its "box".
func _panel(title: String, layer: int) -> CanvasLayer:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var holder := CanvasLayer.new()
	holder.layer = layer
	add_child(holder)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(dim)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	margin.add_child(frame)
	frame.add_child(_label(title, 32, ui.GOLD))
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(scroll.get_v_scroll_bar())
	frame.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	holder.set_meta("box", box)
	for each in [dim, panel]:
		each.modulate.a = 0.0
		_ease(each, "modulate:a", 1.0, 0.25)
	return holder


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load("res://scripts/UIStyle.gd").style_label(l, size, colour)
	return l


func _button(text: String, on_press: Callable, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28)
	load("res://scripts/UIStyle.gd").style_button(b, 16, kind)
	b.pressed.connect(on_press)
	return b
