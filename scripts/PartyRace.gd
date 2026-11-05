extends Node
## A race up Endless's tower with your party (Party.race): everyone on the same tower, on the same clock.
## 3, 2, 1, GO (nobody jumps till GO), then:
##   MINUTE RACE: the highest in a minute wins.
##   SPRINT TO 100 M: the first to 100 m wins.
##   FLY RUSH: the most flies caught in a minute wins (there are flies by most platforms).
##   KNOCKOUT: fall, and you're out; the last frog still climbing wins.
## In all but a knockout a fall puts you back on the last platform you stood on, a moment later: the time
## it costs you is the price. The race's clock up top, the standings in the corner; at the end, the
## results, and for the host the next race. Everyone starts with the minute race, and each race you finish
## unlocks the next (ORDER), one by one, till you have them all.
## EndlessMode makes one when it's a race and tells it what happens: climbed, caught_fly, fell, saw, heard.

signal said(what: Dictionary)  # (your news, as it goes to the others: the tests listen)

const ORDER := ["minute", "sprint", "flies", "knockout"]
const RACES := {
	"minute": {"name": "MINUTE RACE", "label": "Minute Race", "how": "Climb the highest in a minute!"},
	"sprint": {"name": "SPRINT TO 100 M", "label": "Sprint to 100 m", "how": "First to 100 m wins!"},
	"flies": {"name": "FLY RUSH", "label": "Fly Rush", "how": "Catch the most flies in a minute!"},
	"knockout": {"name": "KNOCKOUT", "label": "Knockout", "how": "Fall, and you're out!"},
}
const COUNTDOWN := 3.0  # seconds of 3, 2, 1 before GO, on the party's clock: everyone's GO together
const SECONDS := 60.0  # a minute race's, and a fly rush's
const SPRINT_M := 100
const FLY_CHANCE := 0.85  # (in a fly rush, a fly by this share of the platforms: everyone's the same ones)
const RESPAWN := 0.8  # seconds before a fall puts you back
const RESULTS_AFTER := 1.2  # (seconds after the end before the results: everyone's last word in)
const CREAM := Color(0.97, 0.92, 0.80)
const GOLD := Color(1.0, 0.86, 0.42)
const DIM := Color(0.78, 0.74, 0.68)
const PLACES := ["1st", "2nd", "3rd"]

var endless: Node  # (EndlessMode)
var kind := "minute"
var over := false
var out := false  # (knocked out: watching the others)
var flies := 0
var best_m := 0
var newly := ""  # (the race this one unlocked, if it did)
var results: CanvasLayer
var _out_at := -1.0
var _peers := {}  # peer -> {m, f, out, out_at, y}
var _winner := 0
var _won_at := INF
var _go := false
var _count_shown := 0
var _layer: CanvasLayer
var _count: Label
var _standings: VBoxContainer
var _standings_left := 0.0
var _respawn_left := -1.0


## Whether a race is yours to start (the first always; the rest as you've unlocked them).
static func has(id: String) -> bool:
	return id == ORDER[0] or id in MusicManager.unlocked_modes


## The next race not yet unlocked, unlocked now and kept; "" once they all are.
static func unlock_next() -> String:
	for id in ORDER:
		if not has(id):
			MusicManager.unlocked_modes.append(id)
			MusicManager.save_wardrobe()
			return id
	return ""


## Seconds since GO (less than 0 while it's counting down), on the party's clock.
func clock() -> float:
	return Party.run_seconds() - COUNTDOWN


func _ready() -> void:
	kind = Party.race if Party.race in ORDER else ORDER[0]
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.modulate.a = 0.0
	ui.style_label(_count, 64, CREAM)
	_layer.add_child(_count)
	_standings = VBoxContainer.new()
	_standings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standings.add_theme_constant_override("separation", 0)
	_layer.add_child(_standings)
	Party.race_said.connect(heard)
	_hold(clock() < 0.0)


## Nobody jumps before GO, or once it's over.
func _hold(on: bool) -> void:
	var aim: Node = endless.player.get_node_or_null("Trajectory")
	if aim:
		aim.endGame = 1 if on else 0


func _process(delta: float) -> void:
	_fit()
	_fit_results()
	var t := clock()
	if t < 0.0:
		var n := int(ceil(-t))
		if n != _count_shown and n <= 3:
			_count_shown = n
			_pop(str(n))
			endless._play("res://assets/frogaim.wav", 0.9, -8.0)
	elif not _go:
		_go = true
		if not over and not out:
			_hold(false)
		_pop("GO!")
		endless._play("res://assets/powerUp.wav", 1.0, -8.0)
	if _respawn_left >= 0.0:
		_respawn_left -= delta
		if _respawn_left < 0.0 and not over:
			endless.race_respawn()
	_show_clock(t)
	_standings_left -= delta
	if _standings_left <= 0.0:
		_standings_left = 0.25
		_show_standings()
	if over or not _go:
		return
	if kind in ["minute", "flies"] and t >= SECONDS:
		finish()
	elif kind == "knockout" and _in_count() <= (1 if Party.players.size() > 1 else 0):
		finish()


## The clock and his own count up top, where Endless keeps its score and height.
func _show_clock(t: float) -> void:
	var secs := 0.0
	match kind:
		"minute", "flies":
			secs = ceilf(clampf(SECONDS - maxf(t, 0.0), 0.0, SECONDS))
		"sprint":
			secs = floorf(clampf(t, 0.0, 5999.0))
	if kind == "knockout":
		endless.score_label.text = "%d left" % _in_count()
	else:
		endless.score_label.text = "%d:%02d" % [int(secs) / 60, int(secs) % 60]
	match kind:
		"flies":
			endless._height_label.text = "%d %s" % [flies, "fly" if flies == 1 else "flies"]
		"sprint":
			endless._height_label.text = "%d / %d m" % [mini(best_m, SPRINT_M), SPRINT_M]
		_:
			endless._height_label.text = "%d m" % best_m


## 3, 2, 1, GO! and OUT!: big in the middle, easing in and away.
func _pop(text: String) -> void:
	_count.text = text
	_fit()
	_count.pivot_offset = _count.size * 0.5
	_count.scale = Vector2(1.5, 1.5)
	_count.modulate.a = 0.0
	var tw := _count.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_count, "scale", Vector2.ONE, 0.3)
	tw.tween_property(_count, "modulate:a", 1.0, 0.2)
	tw.chain().tween_property(_count, "modulate:a", 0.0, 0.4).set_delay(0.35)


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var room: Rect2 = load("res://scripts/UIStyle.gd").room(vp)
	_count.size = Vector2(room.size.x, 96.0)
	_count.position = Vector2(room.position.x, room.position.y + room.size.y * 0.47 - 48.0).round()  # (between the race's name and the frogs at the start)
	_standings.size = _standings.get_combined_minimum_size()
	_standings.position = Vector2(room.end.x - _standings.size.x - 10.0, room.position.y + 10.0).round()


## The standings, up in the corner: everyone's place and how they're doing, him in gold.
func _show_standings() -> void:
	for old in _standings.get_children():
		old.queue_free()
	if Party.players.size() < 2:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var rows := rows()
	for i in mini(rows.size(), 5):
		var r: Dictionary = rows[i]
		var line := Label.new()
		line.text = "%d. %s %s" % [i + 1, r.name, _value(r)]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.style_label(line, 16, GOLD if r.peer == Party.me() else (DIM if r.out else CREAM))
		_standings.add_child(line)


## How one's doing, in this race's terms.
func _value(r: Dictionary) -> String:
	match kind:
		"flies":
			return "%d %s" % [r.f, "fly" if r.f == 1 else "flies"]
		"knockout":
			return "out" if r.out else "%d m" % r.m
	return "%d m" % r.m


## Everyone in the race, best first: {peer, name, m, f, out, out_at}.
func rows() -> Array:
	var all := [{"peer": Party.me(), "name": _name_of(Party.me()), "m": best_m, "f": flies, "out": out, "out_at": _out_at}]
	for peer in Party.players:
		if int(peer) == Party.me():
			continue
		var p: Dictionary = _peers.get(int(peer), {})
		all.append({"peer": int(peer), "name": _name_of(int(peer)), "m": int(p.get("m", 0)), "f": int(p.get("f", 0)),
			"out": bool(p.get("out", false)), "out_at": float(p.get("out_at", -1.0))})
	all.sort_custom(_better)
	return all


func _better(a: Dictionary, b: Dictionary) -> bool:
	match kind:
		"flies":
			if a.f != b.f:
				return a.f > b.f
		"sprint":
			if (a.peer == _winner) != (b.peer == _winner):
				return a.peer == _winner
		"knockout":
			if a.out != b.out:
				return not a.out
			if a.out and a.out_at != b.out_at:
				return a.out_at > b.out_at  # (out later, placed higher)
	if a.m != b.m:
		return a.m > b.m
	return a.peer < b.peer


## A racer's name: their @handle online; on the Wi-Fi everyone's lil froggy, so their seat too.
func _name_of(peer: int) -> String:
	var name := str(Party.players.get(peer, {}).get("name", Party.NAME))
	if name == Party.NAME and Party.players.size() > 1:
		name += " #%d" % peer
	return name


func _in_count() -> int:
	var n := 0 if out else 1
	for peer in Party.players:
		if int(peer) != Party.me() and not bool(_peers.get(int(peer), {}).get("out", false)):
			n += 1
	return n


## He's climbed higher (EndlessMode._climbed): in a sprint, at 100 m he's won.
func climbed(metres: int) -> void:
	best_m = maxi(best_m, metres)
	if kind == "sprint" and not over and not out and _go and best_m >= SPRINT_M:
		var t := clock()
		_say({"k": "won", "s": t})
		_won(Party.me(), t)


func caught_fly() -> void:
	if _go and not over and not out:
		flies += 1


## He's fallen too far (EndlessMode._trigger_reset): in a knockout he's out; in the others he's back on
## his last platform in a moment. True: the race has it (there's no game over in a race).
func fell() -> bool:
	if over or out:
		return true
	if kind == "knockout" and _go:
		out = true
		_out_at = clock()
		_say({"k": "out", "m": best_m, "s": _out_at})
		_pop("OUT!")
		endless.race_out()
		return true
	if _respawn_left < 0.0:  # (falling on: one respawn, not a fresh wait every frame he's still going)
		_respawn_left = RESPAWN
	return true


## Where to watch, knocked out: the highest frog still in (its y), or null.
func watch_y():
	var best = null
	for peer in _peers:
		var p: Dictionary = _peers[peer]
		if not bool(p.get("out", false)) and p.has("y") and (best == null or float(p.y) < best):
			best = float(p.y)
	return best


## A friend's frog as it comes (EndlessMode._on_frog_moved): its height, its flies, whether it's out.
func saw(peer: int, state: Array) -> void:
	var p: Dictionary = _peers.get(peer, {"m": 0, "f": 0, "out": false, "out_at": -1.0})
	p.m = maxi(int(p.m), int(state[7]))
	p.y = float(state[1])
	if state.size() > 9:
		p.f = maxi(int(p.f), int(state[9]))
	if state.size() > 10 and bool(state[10]) and not bool(p.out):
		p.out = true
		p.out_at = clock()
	_peers[peer] = p


## A friend's news (Party.race_said): out, won, done.
func heard(peer: int, what: Dictionary) -> void:
	if not Party.players.has(peer):
		return
	var p: Dictionary = _peers.get(peer, {"m": 0, "f": 0, "out": false, "out_at": -1.0})
	p.m = maxi(int(p.m), int(what.get("m", 0)))
	p.f = maxi(int(p.f), int(what.get("f", 0)))
	match str(what.get("k", "")):
		"out":
			p.out = true
			p.out_at = float(what.get("s", clock()))
		"won":
			_peers[peer] = p
			_won(peer, float(what.get("s", clock())))
			return
	_peers[peer] = p


func _won(peer: int, at: float) -> void:
	if at < _won_at:  # (two at once: whoever got there first)
		_won_at = at
		_winner = peer
	finish()


func _say(what: Dictionary) -> void:
	said.emit(what)
	Party.say_race(what)


## The race is over: nobody moves; your last word to the others; the next race unlocked; then the results.
func finish() -> void:
	if over:
		return
	over = true
	_hold(true)
	_say({"k": "done", "m": best_m, "f": flies})
	newly = unlock_next()
	if newly != "":
		MusicManager.show_toast("New Race Unlocked!", null, "%s: %s" % [RACES[newly].label, RACES[newly].how])
	get_tree().create_timer(RESULTS_AFTER).timeout.connect(_show_results)


## The results: the places, who won, what's unlocked; the host starts the next one from here.
func _show_results() -> void:
	if not is_inside_tree() or results != null:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	results = CanvasLayer.new()
	results.layer = 70
	add_child(results)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	results.add_child(bg)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	results.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	margin.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(scroll.get_v_scroll_bar())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(_label(RACES[kind].name, 32, ui.GOLD))
	frame.add_child(scroll)
	scroll.add_child(box)
	var rows := rows()
	var first: Dictionary = rows[0]
	if rows.size() > 1:
		box.add_child(_label("You won!" if first.peer == Party.me() else "%s won!" % first.name, 16, GOLD))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var place: String = PLACES[i] if i < PLACES.size() else "%dth" % (i + 1)
		box.add_child(_label("%s  %s  %s" % [place, r.name, _value(r)], 16, GOLD if r.peer == Party.me() else CREAM))
	if newly != "":
		box.add_child(_label("New race unlocked: %s!" % RACES[newly].label, 16, Color(0.5, 1.0, 0.5)))
	if Party.is_host() or not Party.is_on():
		box.add_child(_button("Race Again", func() -> void: Party.start("endless", kind), "go"))
		for id in ORDER:
			if id != kind and has(id):
				box.add_child(_button(RACES[id].label, func() -> void: Party.start("endless", id), "wood"))
		box.add_child(_button("Climb Together", func() -> void: Party.start("endless"), "wood"))
	else:
		box.add_child(_label("Waiting for the host to start the next race...", 16, DIM))
	box.add_child(_button("Leave Party", _leave, "quiet"))
	ui.finger_scroll(scroll)
	_fit_results()


func _fit_results() -> void:
	if results == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	ui.fit_panel(results.get_node("Panel"), results.get_node("Panel").find_child("Scroll", true, false), room,
		ui.panel_zoom(vp, room), 0.8 if portrait else 0.5)


func _leave() -> void:
	Party.leave()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load("res://scripts/UIStyle.gd").style_label(l, size, colour)
	return l


func _button(text: String, on_press: Callable, style: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28)
	load("res://scripts/UIStyle.gd").style_button(b, 16, style)
	b.pressed.connect(on_press)
	return b
