extends Node2D
## Climbing the World Tree together (Party, in its "story" mode), in Main: the other climbers' frogs in
## your world with their names over them, and a stretchy band (a tether) to your nearest friend that
## catches you falling and pulls you back up to them, as in an Endless party. Your jumps never change.
##
## Everyone's world is their own: their own key and gate, their own talks with the frogs, their own
## finale and ending (all Main's and the player's own, as alone). So nobody's pulled, or put, anywhere
## their own world hasn't opened: not past the wall the frog at the finale's door takes away (each
## climber's, when they get to him), not to someone whose ending's playing, and never into anything
## solid in their own world (a gate they haven't opened, a path that hasn't broken). Whoever joins
## appears beside whoever they joined (Party.beside), or at the finale's door when that's as far as
## their own world goes. A frog that's won (their ending) or gone back to the title isn't shown.
##
## Signed in to Muse, starting a climb puts you up the tree with everyone online, quietly
## (Party.climb_with_everyone: friends' rooms first); back at the title, you leave. There, the band ties
## you to your Muse friends only, and a tap on anyone's name opens a little card: Add Friend, Block,
## Report (anyone you can see, you can block and report). On the same Wi-Fi, or in a friends' party,
## everyone's a friend. Your frog goes to the others as [x, y, animation, frame, flip, turn, 0, height,
## band, where] (where: CLIMBING, IN_FINALE, WON or AWAY), and only now and then while it's still.

enum { CLIMBING, IN_FINALE, WON, AWAY }

const FINALE_HEIGHT := 525.0  # (player.currentHeight past the wall the door's frog takes away: y -5721)
const FINALE_DOOR := Vector2(2562.0, -5680.0)  # (beside the frog at the finale's door, in the castle hall)
const WON_HEIGHT := 787.0  # (past the glass: the ending)
const TETHER_SLACK := 140.0  # the band's give before it catches a fall (as Endless's)
const TETHER_REEL := 0.8  # seconds a friend takes to pull you back up
const TETHER_FALLING := 150.0  # (falling at least this fast,
const TETHER_DROP := 80.0  # and this far below where he last stood: coming down onto a ledge isn't a fall)
const TETHER_DRAWN := 1600.0  # (a band longer than this is off the screen: not drawn)
const RETRY_EVERY := 180.0  # seconds before trying everyone online again, when it didn't work
const BESIDE := [Vector2(32, 0), Vector2(-32, 0), Vector2(46, 0), Vector2(-46, 0), Vector2(22, 0), Vector2(-22, 0)]  # (beside a friend, on what they stand on)
const NEARBY := [Vector2(0, 0), Vector2(0, -8), Vector2(0, -16), Vector2(-12, -4), Vector2(12, -4),
	Vector2(0, -28), Vector2(-24, -8), Vector2(24, -8), Vector2(0, -44)]  # (else, spots round them he fits)
const GOLD := Color(1.0, 0.86, 0.42)
const CREAM := Color(0.97, 0.92, 0.80)
const GREEN := Color(0.62, 1.0, 0.62)
const RED := Color(1.0, 0.6, 0.5)

var main: Node
var player: CharacterBody2D
var _frogs := {}  # peer -> PartyFrog
var _layer: CanvasLayer  # names over the frogs (a tap opens a card, online), the card, a few words
var _bands: Node2D
var _tether_peer := 0
var _reel := {}
var _last_floor_y := 0.0
var _tried := false  # (asked to climb with everyone, this climb)
var _asking := false  # (and waiting to hear back)
var _next_try := 0.0  # (seconds since the game started: not before then, after it didn't work)
var _with_everyone := false  # (the party he's in is everyone's room: its ending's said nothing about)
var _climb_on_title := false  # (a party started up the tree with the title up: Play, once it's there)
var _blocked := {}  # "@handle": true, blocked from here (their frog goes at once)
var _card: Control
var _toast: Label


func _ready() -> void:
	main = get_parent()
	player = main.get_node("Player")
	main.move_child(self, player.get_index())  # (their frogs just behind his, at his depth)
	_bands = Node2D.new()
	_bands.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bands.z_index = player.z_index
	_bands.z_as_relative = false
	_bands.draw.connect(_draw_bands)
	add_child(_bands)
	_layer = CanvasLayer.new()
	_layer.layer = 3  # (over the game and its corner numbers; under the pause menu, which hides it all)
	add_child(_layer)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	load("res://scripts/UIStyle.gd").style_label(_toast, 16, CREAM)
	_layer.add_child(_toast)
	Party.frog_moved.connect(_on_frog_moved)
	Party.players_changed.connect(_on_party_changed)
	Party.ended.connect(_on_party_ended)
	Party.started.connect(_on_started)
	if Party.in_run and Party.mode == "story":
		_climb_on_title = true  # (came here for a party up the tree)


## Out of the story (back to the title, or the game's started over): out of the party up the tree too.
func _exit_tree() -> void:
	if Party.mode == "story" and (Party.is_on() or Party.online_room != ""):
		Party.leave()


func _process(delta: float) -> void:
	if _at_title():
		MuseSocial.set_activity("title")
		if Party.everyone and (Party.is_on() or Party.online_room != ""):
			Party.leave()  # (the title isn't a climb: out of everyone's room)
		if _climb_on_title:
			if _menus_open():
				_close_menus()  # (the title comes back: Play, next frame)
			elif player.get_node("titlescreen").visible:
				_climb_on_title = false
				player.call_deferred("_on_button_pressed")  # (Play: up the tree with them)
	elif _climbing():
		MuseSocial.set_activity("story")
		_climb_with_everyone()
	if not _in_party():
		if not _frogs.is_empty():
			_clear()
		return
	_with_everyone = Party.everyone
	_send(delta)
	_join_beside()
	_tether(delta)
	_place_tags()
	_bands.queue_redraw()


func _in_party() -> bool:
	return Party.in_run and Party.mode == "story" and Party.is_on()


## Climbing: off the title, and not in the ending.
func _climbing() -> bool:
	return not player.get_node("titlescreen").visible and player.get_node("Trajectory").endGame == 0


## At the title, or in a menu over it (Muse Account, Friends, Play Together...): not climbing yet.
func _at_title() -> bool:
	return player.get_node("titlescreen").visible \
		or (player.get_node("Trajectory").endGame != 0 and player.currentHeight <= WON_HEIGHT)


func _menus_open() -> bool:
	for child in player.get_children():
		if child is CanvasLayer and child.has_signal("closed"):
			return true
	return false


## Where he is in his own world, for the others.
func _where() -> int:
	if player.get_node("titlescreen").visible:
		return AWAY
	if player.get_node("Trajectory").endGame != 0 or player.currentHeight > WON_HEIGHT:
		return WON
	return IN_FINALE if player.currentHeight > FINALE_HEIGHT else CLIMBING


# ── with everyone ───────────────────────────────────────────────────────────────────────────────

## Up the tree with everyone online, once a climb's going: quietly, signed in with an @handle, and
## not in a party already. Not open (or not now: the relay's daily allowance used up, say), or in and
## then out again: the climb goes on alone, and it's tried again a while later.
func _climb_with_everyone() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _tried and not _asking and not Party.is_on() and Party.online_room == "":
		_tried = false
		_next_try = maxf(_next_try, now + 60.0)
	if _tried or Party.is_on() or Party.online_room != "" or not Party.with_everyone:
		return
	if not MuseSocial.is_member() or not MuseSocial.rooms_live or now < _next_try:
		return
	_tried = true
	_asking = true
	var problem: String = await Party.climb_with_everyone()
	_asking = false
	if problem != "" and is_inside_tree():
		_next_try = Time.get_ticks_msec() / 1000.0 + RETRY_EVERY


func _on_started() -> void:
	if Party.mode == "story" and not _climbing():
		_climb_on_title = true


## The menus over the title (Muse Account, Friends, Play Together...), closed: the climb's starting.
func _close_menus() -> void:
	for child in player.get_children():
		if child is CanvasLayer and child.has_signal("closed") and child != player.get_node("titlescreen"):
			child.emit_signal("closed")


# ── the others' frogs ───────────────────────────────────────────────────────────────────────────

func _send(delta: float) -> void:
	var sprite: AnimatedSprite2D = player.get_node("Sprite2D")
	var at: Vector2 = player.global_position
	Party.send_frog([snappedf(at.x, 0.1), snappedf(at.y, 0.1), str(sprite.animation), sprite.frame, sprite.flip_h,
		snappedf(sprite.rotation, 0.01), 0, int(player.currentHeight), _tether_peer if Party.tethers else 0, _where()], delta)


func _on_frog_moved(peer: int, state: Array) -> void:
	if not _in_party() or not Party.players.has(peer) or _blocked.has(Party.name_of(peer)):
		return
	var frog = _frogs.get(peer)
	if frog == null:
		frog = Node2D.new()
		frog.set_script(load("res://scripts/PartyFrog.gd"))
		add_child(frog)
		frog.setup(player, peer, Party.players[peer])
		frog.z_index = player.z_index
		_frogs[peer] = frog
		_tell_about_names()
	frog.show_state(state)
	frog.visible = frog.where != WON and frog.where != AWAY


func _on_party_changed() -> void:
	for peer in _frogs.keys():
		if not Party.players.has(peer) or _blocked.has(Party.name_of(peer)):
			_frogs[peer].queue_free()
			_frogs.erase(peer)
		else:
			_frogs[peer].dress(Party.players[peer])


## The party's over (the host left, the Wi-Fi or the relay dropped): he climbs on alone. Everyone's
## room going says nothing (it was never asked for): he's back in one in a little while.
func _on_party_ended(why: String) -> void:
	_clear()
	_tried = false
	_next_try = Time.get_ticks_msec() / 1000.0 + 30.0
	if why != "" and not _with_everyone and is_inside_tree():
		_say(why, RED)
	_with_everyone = false


func _clear() -> void:
	for frog in _frogs.values():
		frog.queue_free()
	_frogs.clear()
	_tether_peer = 0
	if not _reel.is_empty():
		_reel = {}
		player.set_physics_process(true)
	for tag in _layer.get_children():
		if tag.has_meta("peer"):
			tag.queue_free()
	_bands.queue_redraw()


## A friend (the band ties you to them): your Muse friends, up the tree with everyone; on the same
## Wi-Fi or in a friends' party, everyone.
func _is_friend(peer: int) -> bool:
	if not Party.everyone:
		return true
	var handle := Party.name_of(peer).trim_prefix("@")
	for card in MuseSocial.friends:
		if str(card.get("handle", "")) == handle:
			return true
	return false


# ── beside whoever you joined ───────────────────────────────────────────────────────────────────

## Once whoever you joined has said where they are (and they're climbing), you're beside them: at the
## finale's door if they're past it and your own world hasn't opened it, or they've won.
func _join_beside() -> void:
	if Party.beside == "" or not _climbing():
		return
	var frog = _frogs.get(Party.peer_named(Party.beside))
	if frog == null or not frog.seen or frog.where == AWAY:
		return
	var who := Party.beside
	Party.beside = ""
	var to: Vector2 = frog.spot()
	if frog.where == WON or (frog.where == IN_FINALE and not _finale_open()):
		to = FINALE_DOOR
	var spot := _free_spot_near(to)
	if spot == Vector2.INF:
		return
	if not _reel.is_empty():  # (a band reeling him in lets go: he's somewhere else now)
		_reel = {}
		player.set_physics_process(true)
	player.global_position = spot
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	player.get_node("Camera2D").reset_smoothing()
	_last_floor_y = spot.y
	_say("You're climbing with %s!" % who, GREEN)


## Whether his own world's finale is open (the frog at its door has opened the way).
func _finale_open() -> bool:
	return int(main.npc6) == 1


## A spot by `near` where he'd fit in his own world (nothing solid of his there), or Vector2.INF: beside
## them on the ground they're standing on if he can (floor under it in his world too), else as near
## as he fits.
func _free_spot_near(near: Vector2) -> Vector2:
	for step in BESIDE:
		if _free_at(near + step) and _floor_under(near + step):
			return near + step
	for step in NEARBY:
		if _free_at(near + step):
			return near + step
	return Vector2.INF


## Whether there's ground just under him at a spot (standing there, he wouldn't fall).
func _floor_under(spot: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(spot, spot + Vector2(0.0, 24.0), player.collision_mask, [player.get_rid()])
	return not player.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _free_at(spot: Vector2) -> bool:
	var body: CollisionShape2D = player.get_node("CollisionShape2D")
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = body.shape
	var xf: Transform2D = player.global_transform
	xf.origin = spot
	q.transform = xf * body.transform
	q.collision_mask = player.collision_mask
	q.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


# ── the band ────────────────────────────────────────────────────────────────────────────────────

## The band: tied to your nearest friend (chosen again whenever you're standing or going up). Falling,
## once you're its slack below a friend who's standing somewhere your own world has open, they reel
## you up.
func _tether(delta: float) -> void:
	if not _reel.is_empty():
		_reel_in(delta)
		return
	if not Party.tethers or not _climbing():
		_tether_peer = 0
		return
	var at: Vector2 = player.global_position
	if player.is_on_floor() and player.velocity.y <= 1.0:  # (standing: not on the way down)
		_last_floor_y = at.y
	if player.velocity.y <= TETHER_FALLING:
		var nearest := 0
		for peer in _frogs:
			if _ties_to(peer) and (nearest == 0 or _frogs[peer].spot().distance_to(at) < _frogs[nearest].spot().distance_to(at)):
				nearest = peer
		_tether_peer = nearest
	elif _tether_peer != 0 and _ties_to(_tether_peer):
		var friend = _frogs[_tether_peer]
		if friend.standing and _reaches(friend) and at.y > _last_floor_y + TETHER_DROP and at.y > friend.spot().y + TETHER_SLACK:
			_start_reel(friend)


func _ties_to(peer: int) -> bool:
	var frog = _frogs.get(peer)
	return frog != null and frog.visible and frog.seen and _is_friend(peer)


## Somewhere his own world has open: not past the finale's door unless his has opened it.
func _reaches(friend: Node2D) -> bool:
	return friend.where == CLIMBING or (friend.where == IN_FINALE and _finale_open())


## Pulled up by the band, to where the friend's standing (or the nearest spot there he fits).
func _start_reel(friend: Node2D) -> bool:
	var to := _free_spot_near(friend.spot() + Vector2(0.0, -2.0))
	if to == Vector2.INF:
		return false
	_reel = {"from": player.global_position, "to": to, "t": 0.0}
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	_float_words(to + Vector2(0, -40), "%s pulled you up!" % Party.name_of(friend.peer), GOLD)
	var s := AudioStreamPlayer.new()
	s.stream = load("res://assets/coolfind.mp3")
	s.pitch_scale = 1.2
	s.volume_db = -6.0
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)
	return true


## Up the band, quickly at first and gently at the end, in a little arc, then down onto the ledge.
func _reel_in(delta: float) -> void:
	_reel.t = minf(1.0, float(_reel.t) + delta / TETHER_REEL)
	var k := 1.0 - pow(1.0 - float(_reel.t), 3.0)
	var from: Vector2 = _reel.from
	var to: Vector2 = _reel.to
	player.global_position = from.lerp(to, k) + Vector2(0.0, -sin(k * PI) * 24.0)
	player.reset_physics_interpolation()
	if _reel.t >= 1.0:
		_reel = {}
		player.velocity = Vector2.ZERO
		player.set_physics_process(true)
		_last_floor_y = to.y


## Every band up the tree you can see: yours to your friend, and each friend's to theirs. Slack, it
## sags, thick and pink; stretched, it pulls straight and thin (as Endless's).
func _draw_bands() -> void:
	if not _in_party() or not Party.tethers or not _climbing():
		return
	var seen := {}
	var mine := Party.me()
	if _ties_to(_tether_peer):
		_band(player.global_position, _frogs[_tether_peer].position)
		seen["%d-%d" % [mini(mine, _tether_peer), maxi(mine, _tether_peer)]] = true
	for peer in _frogs:
		var frog = _frogs[peer]
		var to := int(frog.tether_to)
		if to == 0 or not frog.visible:
			continue
		var other = player if to == mine else _frogs.get(to)
		var key := "%d-%d" % [mini(to, peer), maxi(to, peer)]
		if other == null or not other.visible or seen.has(key):
			continue
		seen[key] = true
		_band(frog.position, other.global_position)


func _band(a: Vector2, b: Vector2) -> void:
	a += Vector2(0.0, -8.0)
	b += Vector2(0.0, -8.0)
	var d := a.distance_to(b)
	if d > TETHER_DRAWN or d < 4.0:
		return
	var taut := clampf((d - TETHER_SLACK * 0.5) / (TETHER_SLACK * 0.5), 0.0, 1.0)
	# (it sags no lower than their feet: on the tree's solid ground, lower is behind the ground)
	var mid := (a + b) * 0.5 + Vector2(0.0, minf(maxf(0.0, TETHER_SLACK - d) * 0.5, 16.0))
	var points := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		points.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	_bands.draw_polyline(points, Color(1.0, 0.5, 0.7).lerp(Color(1.0, 0.82, 0.9), taut), lerpf(3.0, 1.5, taut))


# ── names ───────────────────────────────────────────────────────────────────────────────────────

## Each frog's name just over its head, on the screen at the pixel font's size: yours in gold, friends'
## in green, everyone else's in cream. Online, each is a button (a tap: Add Friend, Block, Report), so
## a tap on it doesn't start a jump. Off with the name tags setting, paused, and at the title.
func _place_tags() -> void:
	var want := {}
	if Party.name_tags and _climbing() and Engine.time_scale > 0.5 and _card == null:
		for peer in _frogs:
			if _frogs[peer].visible:
				want[peer] = [_frogs[peer], Party.name_of(peer), GREEN if (Party.everyone and _is_friend(peer)) else CREAM]
		if not want.is_empty():
			want[0] = [player, Party.display_name(), GOLD]
	for tag in _layer.get_children():
		if tag.has_meta("peer") and not want.has(int(tag.get_meta("peer"))):
			tag.queue_free()
	var xf := get_viewport().get_canvas_transform()
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	for peer in want:
		var tag := _layer.get_node_or_null("Tag%d" % peer) as Control
		if tag == null:
			if Party.is_online() and peer != 0:
				var b := Button.new()
				b.flat = true
				b.focus_mode = Control.FOCUS_NONE
				for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
					b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
				b.add_theme_font_override("font", ui.font())
				b.add_theme_font_size_override("font_size", 16)
				for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
					b.add_theme_color_override(state, want[peer][2])
				b.add_theme_color_override("font_outline_color", ui.INK)
				b.add_theme_constant_override("outline_size", ui.outline_px(16))
				b.pressed.connect(_open_card.bind(peer))
				tag = b
			else:
				var l := Label.new()
				l.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ui.style_label(l, 16, want[peer][2])
				tag = l
			tag.name = "Tag%d" % peer
			tag.set_meta("peer", peer)
			_layer.add_child(tag)
		tag.set("text", want[peer][1])
		tag.size = tag.get_combined_minimum_size()
		var frog: Node2D = want[peer][0]
		var head: Vector2 = xf * (frog.global_position + Vector2(0.0, -18.0 * frog.scale.y))
		tag.position = (head - Vector2(tag.size.x * 0.5, tag.size.y)).round()
	# (frogs side by side: a name that would run into another's goes up over it)
	var placed: Array[Rect2] = []
	for peer in want:
		var tag := _layer.get_node_or_null("Tag%d" % peer) as Control
		if tag == null:
			continue
		for _try in 4:
			var bumped := false
			for r in placed:
				if r.grow(1.0).intersects(Rect2(tag.position, tag.size)):
					tag.position.y = r.position.y - tag.size.y - 1.0
					bumped = true
			if not bumped:
				break
		placed.append(Rect2(tag.position, tag.size))


## The first time someone else is up the tree with you online: how to add, block or report them.
func _tell_about_names() -> void:
	if Party.told_names or not Party.everyone:
		return
	Party.set_told_names()
	_say("Climbing with everyone online! Tap a frog's name to add them as a friend, or to block or report them.", CREAM, 6.0)


## A few words at the top of the screen for a moment.
func _say(words: String, colour: Color, seconds := 3.5) -> void:
	var vp := get_viewport().get_visible_rect().size
	_toast.text = words
	_toast.add_theme_color_override("font_color", colour)
	_toast.size = Vector2(minf(vp.x - 40.0, 420.0), 0.0)
	_toast.position = Vector2(roundf((vp.x - _toast.size.x) * 0.5), roundf(vp.y * 0.16))
	var tw := _toast.create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.3)
	tw.tween_interval(seconds)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


## A few words floating up off a spot in the world (a friend pulling you up).
func _float_words(at: Vector2, words: String, colour: Color) -> void:
	var w := FloatWords.new()
	w.text = words
	w.colour = colour
	w.position = at
	add_child(w)


class FloatWords extends Node2D:
	var text := ""
	var colour := Color.WHITE
	var _t := 0.0

	func _ready() -> void:
		z_index = 20
		z_as_relative = false
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_t += delta
		position.y -= 30.0 * delta
		modulate.a = clampf(1.8 - _t * 1.2, 0.0, 1.0)
		if _t > 1.5:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var font: Font = load("res://assets/fibberish.ttf")
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var at := Vector2(-roundf(w * 0.5), 0.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.2, 0.17, 0.19))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, colour)


# ── a name's card: Add Friend, Block, Report ────────────────────────────────────────────────────

## A tap on someone's name (online): their @handle, Add Friend (unless they're one), Block and Report.
## Taps on it never start a jump: under the buttons there's only the dimmed screen, itself a button (the
## slingshot leaves presses on buttons alone); a tap on it off the card closes the card.
func _open_card(peer: int, reporting := false, note := "", note_colour := CREAM) -> void:
	_close_card()
	var who := Party.name_of(peer)
	if who == "":
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var vp := get_viewport().get_visible_rect().size
	var shade := Button.new()
	shade.flat = true
	shade.focus_mode = Control.FOCUS_NONE
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(0, 0, 0, 0.55)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		shade.add_theme_stylebox_override(state, dim)
	shade.position = Vector2.ZERO
	shade.size = vp
	_layer.add_child(shade)
	_card = shade
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(panel)
	shade.pressed.connect(func() -> void:
		if not panel.get_global_rect().has_point(shade.get_global_mouse_position()):
			_close_card())
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	var name_label := Label.new()
	name_label.text = who
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.style_label(name_label, 32, ui.GOLD)
	box.add_child(name_label)
	var buttons: Array = []
	if reporting:
		var why := Label.new()
		why.text = "Report %s for:" % who
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.style_label(why, 16, CREAM)
		box.add_child(why)
		for reason in MuseSocial.REPORT_REASONS:
			buttons.append([reason.capitalize(), _report.bind(peer, who, reason), "quiet"])
		buttons.append(["Back", _open_card.bind(peer), "quiet"])
	else:
		if _is_friend(peer):
			var pal := Label.new()
			pal.text = "Your friend"
			pal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ui.style_label(pal, 16, GREEN)
			box.add_child(pal)
		else:
			buttons.append(["Add Friend", _add_friend.bind(peer, who), "go"])
		buttons.append(["Block", _block.bind(peer, who), "quiet"])
		buttons.append(["Report", _open_card.bind(peer, true), "quiet"])
		buttons.append(["Close", _close_card, "wood"])
	for each in buttons:
		var b := Button.new()
		b.text = each[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(200, 28)
		ui.style_button(b, 16, each[2])
		b.pressed.connect(each[1])
		box.add_child(b)
	if note != "":
		var said := Label.new()
		said.text = note
		said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		said.custom_minimum_size = Vector2(200, 0)
		ui.style_label(said, 16, note_colour)
		box.add_child(said)
	panel.size = panel.get_combined_minimum_size()
	var s := maxf(1.0, floorf(ui.panel_zoom(vp, ui.room(vp))))
	panel.scale = Vector2(s, s)
	panel.position = ((vp - panel.size * s) * 0.5).round()


func _close_card() -> void:
	if _card:
		_card.queue_free()
		_card = null


func _add_friend(peer: int, who: String) -> void:
	var said: String = await MuseSocial.add_friend(who)
	if is_inside_tree() and _card:
		_open_card(peer, false, "Asked %s to be friends." % who if said in ["requested", "friends"] else said,
			GREEN if said in ["requested", "friends"] else RED)


## Blocked: their frog goes at once, and you're out of the room and into another (Muse never puts you
## in one together again).
func _block(peer: int, who: String) -> void:
	var problem: String = await MuseSocial.block(who)
	if not is_inside_tree():
		return
	if problem != "":
		_open_card(peer, false, problem, RED)
		return
	_close_card()
	_blocked[who] = true
	if _frogs.has(peer):
		_frogs[peer].queue_free()
		_frogs.erase(peer)
	_say("Blocked %s: you won't see each other in Muse." % who, CREAM)
	if Party.everyone:
		Party.leave()
		_tried = false
		_next_try = Time.get_ticks_msec() / 1000.0 + 2.0


func _report(peer: int, who: String, reason: String) -> void:
	var problem: String = await MuseSocial.report(who, reason)
	if is_inside_tree() and _card:
		_open_card(peer, false, "Thanks: Muse's team will look at %s." % who if problem == "" else problem,
			GREEN if problem == "" else RED)
