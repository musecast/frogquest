extends Node2D
## Lil Froggy himself. He hops along the bottom of the screen, naps (longer at night), snaps
## flies out of the air, bounces off the sides of the screen (no sticking to them: he can't in the
## game), visits your cursor, and puts up with being petted, picked up and thrown. Pull back from him and let go and he jumps, the way you
## play Frog Quest; hold still on him to pick him up. He doesn't talk (he doesn't in the game
## either). Positions are window pixels; px is screen pixels per sprite pixel, so the
## sprite-pixel numbers below look the same on any screen.

signal landed
signal wants_menu
signal left

enum State { HIDDEN, IDLE, CROUCH, AIR, LAND, NAP, HELD, DIZZY, AIM }

# The game's own frog frames (with the game's timings for idle and sad).
const ANIMS := {
	"idle": [5.0, [["res://assets/frog.png", 3.0], ["res://assets/frog2.png", 2.0]]],
	"crouch": [5.0, [["res://assets/frog_prejump.png", 1.0]]],
	"prejump": [5.0, [["res://assets/frog_prejump.png", 0.7], ["res://assets/frog_prejump2.png", 1.0]]],
	"nap": [1.0, [["res://assets/frog_prejump.png", 1.2], ["res://assets/frog_prejump2.png", 1.6]]],
	"air": [5.0, [["res://assets/frog_airborne.png", 1.0]]],
	"sad": [5.0, [["res://assets/frogsad.png", 1.0], ["res://assets/frogsad2.png", 1.0]]],
}
# Each hat's art, its size next to his sprite and how far it's lifted (art pixels), as player.tscn
# wears them: the crown and the wiz hat are drawn at his own pixel size (the crown on his pixel grid,
# its top-left at his (2, -9)), the cake hat is 64 px art at 0.71.
const HATS := {
	"froggycrown": ["res://assets/froggycrown.png", 1.0, -7.25],
	"blackcrown": ["res://assets/froggycrown.png", 1.0, -7.25],
	"wizhat": ["res://assets/froggywizhat.png", 1.0, 0.0],
	"cakehat": ["res://assets/froggycakehat.png", 0.71, 0.0],
}
const PIXELS_SHADER := "res://scripts/froggy_pixels.gdshader"  # the game's chunky pixels, on just him
const PIXEL_BLOCK := 2.0  # his art pixels per game pixel (the game's 480 px view at its widescreen zoom)
const SOUNDS := {
	"hop": "res://assets/frogjump.wav",
	"leap": "res://assets/jump.wav",
	"glass": "res://assets/glassbreak.mp3",
	"gulp": "res://assets/pickupCoin.wav",
	"grab": "res://assets/frogaim.wav",
	"pop": "res://assets/appear.mp3",
}
const HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]

# Sprite pixels (times px on screen). One of his sprite pixels is 0.912 units in the game (a 0.76
# sprite on a 1.2-scaled player) and the game's gravity is Godot's default 980, so working in those
# units out here makes his jumps arc and time exactly like they do when you play.
const GAME_UNITS_PER_PX := 0.912
const GRAVITY := 980.0 / GAME_UNITS_PER_PX
# From his middle down to the bottom of his feet row, the lowest row the game's chunky pixels show
# (his frames are redrawn on the PIXEL_BLOCK grid lined up with this, and nothing under it is drawn:
# see _solid_frame).
const FEET_TO_CENTER := 13.0
const HALF_W := 15.0
const HEIGHT := 30.0
const HAT_Y := -10.75  # where the game wears his hat, from the sprite centre (it comes down with his head: _place_hat)
const MOUTH_Y := -5.0
const TONGUE_REACH := 48.0
const AIM_SENSITIVITY := 3.5  # the game's (Trajectory.gd): jump speed per pixel pulled back
const AIM_ROOM := Vector2(170.0, 132.0)  # pull room for a full-strength game jump, sideways and down (sprite px)
const AIM_GAIN_MOST := 5.0  # by a screen edge, each pixel of pull counts for up to this many (see _start_aim)

const HOLD_TO_GRAB_MSEC := 450  # holding still on him picks him up (pulling back is a jump)
const HAT_CHANCE := 0.05  # your hat's a rare find in the game, and rarer still out here

var px := 3
var room := Vector2(1280.0, 720.0)
var cursor := Vector2(-99999.0, -99999.0)
var track_os_cursor := true  # the overlay follows the real cursor; the smoke test moves it by hand
var sounds_on := true
var affection := 0
var flies_eaten := 0
# Muse Penguin's penguins out on this screen with him (DesktopFrog.gd hears where they are): x is a
# penguin's middle and y its feet, in window pixels; {id, name, x, y, w, h, state}.
var penguins: Array = []
var tucked_away := false  # hiding after a hard mouse shake (or with the penguins): he comes back out

var feet := Vector2.ZERO  # bottom-centre of froggy
var vel := Vector2.ZERO
var state := State.HIDDEN

var _seq := 0  # bumped whenever whatever he was doing gets cut short
var _busy := false  # an action is running, so the brain waits
var _aim := Vector2.ZERO  # how far you've pulled him back, sprite pixels
var _aim_from := Vector2.ZERO  # where the pull is measured from (window pixels)
var _gain_left := 1.0  # how much each pixel of pull counts, pulling left / right / down (see _start_aim)
var _gain_right := 1.0
var _gain_down := 1.0
var _yours_until := 0  # after you've made him jump, his own ideas wait a moment (msec)
var _idle_left := 0.0
var _state_left := 0.0
var _energy := 1.0
var _floor_override := -1.0  # during the jump out, the game window's floor is his floor
var _exit_edge := INF  # the game window edge he breaks out through
var _exit_dir := 0.0
var _exit_glass := false
var _home := Rect2()  # the game window he's jumping back into
var _walls := true
var _spin_left := 0.0
var _spin_speed := 0.0
var _flip_angle := 0.0
var _flung_hard := false
var _dizzy_pending := false
var _tween: Tween

var _pressing := false
var _press_at := Vector2.ZERO
var _press_msec := 0
var _grab_offset := Vector2.ZERO
var _clicks: Array[int] = []
var _throw_vel := Vector2.ZERO
var _last_cursor := Vector2.ZERO
var _cursor_vel := Vector2.ZERO
var _pet_turns: Array[int] = []
var _pet_dir := 0.0
var _pet_cooldown := 0.0
var _startle_cooldown := 0.0

var _squash := Vector2.ONE
var _tilt := 0.0
var _tilt_target := 0.0
var _tilt_vel := 0.0

var _bubble := ""
var _bubble_left := 0.0
var _particles: Array[Dictionary] = []
var _fly := {}
var _tongue_t := -1.0
var _tongue_to := Vector2.ZERO
var _tongue_hit := false
var _fx_drawn := false
var _mv_events: Array = []  # what he did to the penguins, for DesktopFrog.gd to pass on
var _met_this_jump := {}  # penguins he's already leapfrogged (or boinged off) on this jump
var _boings := 0

var _rig: Node2D  # at his feet: squash
var _pivot: Node2D  # at his middle: leaning and flips
var _look: CanvasGroup  # him and his hat, drawn together in the game's pixels
var _fx_look: CanvasGroup  # his hearts, flies and aim line, in the same pixels
var _body: AnimatedSprite2D
var _hat: Sprite2D
var _froggy_head: Script = load("res://scripts/FroggyHead.gd")
var _fx: Node2D
var _font: Font
var _bubble_box: StyleBoxFlat


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = load("res://assets/fibberish.ttf")
	var frames := SpriteFrames.new()
	var solid := {}
	for anim: String in ANIMS:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, ANIMS[anim][0])
		for frame: Array in ANIMS[anim][1]:
			if not solid.has(frame[0]):
				solid[frame[0]] = _solid_frame(frame[0])
			frames.add_frame(anim, solid[frame[0]], frame[1])
	_rig = Node2D.new()
	add_child(_rig)
	_pivot = Node2D.new()
	_pivot.position = Vector2(0.0, -FEET_TO_CENTER)
	_rig.add_child(_pivot)
	_look = CanvasGroup.new()
	_look.material = _shader_material(PIXELS_SHADER)
	_pivot.add_child(_look)
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = frames
	_look.add_child(_body)
	_hat = Sprite2D.new()
	_hat.position = Vector2(0.0, HAT_Y)
	_look.add_child(_hat)
	_body.frame_changed.connect(_place_hat)
	_body.animation_changed.connect(_place_hat)
	_fx_look = CanvasGroup.new()
	_fx_look.material = _look.material
	add_child(_fx_look)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	_fx_look.add_child(_fx)
	_bubble_box = StyleBoxFlat.new()
	_bubble_box.bg_color = Color(0.98, 0.98, 0.94)
	_bubble_box.border_color = Color(0.1, 0.12, 0.1)
	_dress_up()
	_play("idle")
	_rig.visible = false


# ── What the overlay asks of him ──────────────────────────────────────────

func set_room(size: Vector2, pixel_scale: int) -> void:
	room = size
	px = pixel_scale
	_bubble_box.set_border_width_all(maxi(1, int(px * 0.5)))
	_bubble_box.set_corner_radius_all(px * 2)
	(_look.material as ShaderMaterial).set_shader_parameter("block", PIXEL_BLOCK * px)
	feet.x = clampf(feet.x, HALF_W * px, room.x - HALF_W * px)
	feet.y = minf(feet.y, _floor())


func drop_in(x := -1.0) -> void:
	_run(&"drop_in", x)


## game is the game window (window pixels); reveal is the big first-time version.
func jump_out_of(game: Rect2, reveal: bool) -> void:
	_run(&"jump_out", [game, reveal])


func come_to(x: float) -> void:
	_run(&"come", x)


func go_home(game: Rect2) -> void:
	_run(&"home", game)


func say_bye() -> void:
	_run(&"bye")


func toggle_nap() -> void:
	_run(&"wake" if state == State.NAP else &"long_nap")


func is_napping() -> bool:
	return state == State.NAP


## Him, for the musiverse (window pixels, like penguins): {} while he's not out.
func musiverse_critter() -> Dictionary:
	if state == State.HIDDEN:
		return {}
	var body := _body_rect()
	return {"id": "froggy", "kind": "frog", "name": "Lil Froggy", "x": feet.x, "y": feet.y,
		"w": body.size.x, "h": body.size.y, "state": String(State.keys()[state]).to_lower()}


## What he's done to the penguins since last time (leapfrog, hop_on, hello).
func take_musiverse_events() -> Array:
	var events := _mv_events
	_mv_events = []
	return events


## Something a penguin did to him: waved hello (greet), came over to visit, or brought him a fish.
func musiverse_event(ev: Dictionary) -> void:
	var type := str(ev.get("type", ""))
	if not (type in ["greet", "visit", "fish"]) or state == State.HIDDEN:
		return
	var pal := _penguin(str(ev.get("from", "")))
	if pal.is_empty():
		return
	if type == "fish":
		# (a fish wakes him right up, and beats whatever he was about to do)
		if state in [State.IDLE, State.LAND, State.NAP] and not _pressing:
			_run(&"take_fish", pal)
		else:
			_add_heart()
		return
	if state == State.NAP:
		return  # (let him sleep)
	if state == State.IDLE and not _busy and Time.get_ticks_msec() >= _yours_until:
		_run(&"wave_back", pal)
	else:
		_add_heart()  # (busy, but he saw)


## A hard mouse shake (or the penguins hiding): he's blown off the screen the way you shook (dir
## -1 left, 1 right, 0: whichever edge is nearer). He stays hidden until come_back_out().
func shake_away(dir: float) -> void:
	if tucked_away or state == State.HELD:
		return  # (already gone; or you've got hold of him, and the shake is you shaking HIM)
	tucked_away = true
	if state == State.HIDDEN:
		return
	_interrupt()  # (aiming, napping, half way through a hop: everything stops)
	if dir == 0.0:
		dir = -1.0 if feet.x < room.x * 0.5 else 1.0
	_walls = false
	_floor_override = room.y * 100.0  # (nothing to land on until he's off the screen)
	vel = Vector2(dir * 1500.0, -620.0) * px
	_spin_left = dir * TAU * 1.5
	_spin_speed = dir * TAU * 4.0  # (same sign as _spin_left, see _step_air)
	_sfx("hop", -10.0, 1.6)
	_set_air()


## Out of hiding again (another shake, the penguins coming out, or "Come here!"): he drops back in
## from the top, at x (or anywhere, for -1), after a moment to make sure the coast is clear.
func come_back_out(x := -1.0) -> void:
	if not tucked_away:
		return
	tucked_away = false
	await get_tree().create_timer(randf_range(0.35, 0.9)).timeout
	if not tucked_away:
		drop_in(x)


## Froggy doesn't talk (he doesn't in Frog Quest either), so there's never a bubble.
func say(_text: String, _seconds := 1.6) -> void:
	pass


## Busy enough to need smooth frames; otherwise the overlay can idle along slowly.
func is_lively() -> bool:
	return state in [State.CROUCH, State.AIR, State.LAND, State.HELD, State.DIZZY, State.AIM] or _pressing \
		or _tween != null or not _particles.is_empty() or not _fly.is_empty() or _tongue_t >= 0.0 \
		or _squash != Vector2.ONE or _tilt != _tilt_target or _tilt_vel != 0.0


## What he's drawing right now as one or two boxes (him with his bubble and sparkles, and a fly
## off to the side), so the part of the overlay that catches clicks stays small.
func get_drawn_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var main := Rect2()
	var have := false
	var parts: Array[Rect2] = []
	if _rig.visible:
		parts.append(_figure_rect())
	if _bubble_left > 0.0:
		parts.append(_bubble_rect())
	if state == State.DIZZY:
		parts.append(Rect2(_head_point() - Vector2(14.0, 8.0) * px, Vector2(28.0, 12.0) * px))
	if state == State.AIM:
		parts.append(Rect2(_center(), Vector2.ZERO).expand(_aim_tip()).grow(2.0 * px))
	if _tongue_t >= 0.0:
		parts.append(Rect2(_mouth(), Vector2.ZERO).expand(_tongue_tip()).grow(2.0 * px))
	for p in _particles:
		parts.append(Rect2(p.pos - Vector2(6.0, 6.0) * px, Vector2(12.0, 12.0) * px))
	for part in parts:
		main = main.merge(part) if have else part
		have = true
	if have:
		rects.append(main)
	if not _fly.is_empty():
		rects.append(Rect2(_fly.pos - Vector2(6.0, 6.0) * px, Vector2(12.0, 12.0) * px))
	return rects


func handle_mouse(event: InputEvent) -> void:
	if state == State.HIDDEN:
		return
	var button := event as InputEventMouseButton
	if button:
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				if _figure_rect().grow(2.0 * px).has_point(button.position):
					_pressing = true
					_press_at = button.position
					_press_msec = Time.get_ticks_msec()
			elif _pressing:
				_pressing = false
				if state == State.HELD:
					_release()
				elif state == State.AIM:
					_launch()
				elif Time.get_ticks_msec() - _press_msec < 400:
					_clicked()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed \
				and _figure_rect().has_point(button.position):
			wants_menu.emit()
		return
	var motion := event as InputEventMouseMotion
	if motion and _pressing and state != State.HELD and state != State.AIM \
			and motion.position.distance_to(_press_at) > 2.0 * px:
		if _can_aim():
			_start_aim()
		else:
			_grab(motion.position)  # (in the air: you caught him)


# ── Every frame ────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if state == State.HIDDEN and _particles.is_empty():
		if _fx_drawn:
			_fx_drawn = false
			_fx.queue_redraw()
		return
	if track_os_cursor:
		cursor = Vector2(DisplayServer.mouse_get_position() - get_window().position)
	if delta > 0.0:
		_cursor_vel = _cursor_vel.lerp((cursor - _last_cursor) / delta, 0.4)
	_last_cursor = cursor
	if _pressing and state != State.HELD and state != State.AIM \
			and Time.get_ticks_msec() - _press_msec >= HOLD_TO_GRAB_MSEC:
		_grab(cursor)
	match state:
		State.AIR:
			_step_air(delta)
		State.HELD:
			_step_held(delta)
		State.AIM:
			_step_aim()
		State.LAND:
			_state_left -= delta
			if _state_left <= 0.0:
				_after_landing()
		State.DIZZY:
			_state_left -= delta
			if _state_left <= 0.0:
				_settle()
		State.NAP:
			_energy = minf(1.0, _energy + delta * 0.02)
		State.IDLE:
			if not _busy:
				_idle_left -= delta
				if _idle_left <= 0.0:
					_think()
	_react_to_cursor(delta)
	_step_fly(delta)
	_step_tongue(delta)
	_step_particles(delta)
	if _bubble_left > 0.0:
		_bubble_left -= delta
	_update_rig(delta)
	var drawing := _bubble_left > 0.0 or not _particles.is_empty() or not _fly.is_empty() \
		or _tongue_t >= 0.0 or state == State.DIZZY or state == State.AIM
	if drawing or _fx_drawn:
		_fx.queue_redraw()
	_fx_drawn = drawing


func _step_air(delta: float) -> void:
	vel.y += GRAVITY * px * delta
	var was := feet
	feet += vel * delta
	_meet_penguins(was)
	_tilt_target = 0.0  # upright the whole way, like in the game
	if _spin_left != 0.0:
		var turn := _spin_speed * delta
		if absf(turn) >= absf(_spin_left):
			turn = _spin_left
		_flip_angle += turn
		_spin_left -= turn
	if _exit_edge != INF and (feet.x - _exit_edge) * _exit_dir > 0.0:
		_break_out()
	if _home.has_area() and vel.y > 0.0 and _home.has_point(_center()):
		_vanish()
		return
	var half := HALF_W * px
	if _walls:
		if feet.x < half:
			feet.x = half
			_hit_wall()
		elif feet.x > room.x - half:
			feet.x = room.x - half
			_hit_wall()
		if vel.y < 0.0 and feet.y < HEIGHT * px:
			feet.y = HEIGHT * px
			vel.y = -vel.y * 0.35
	elif feet.x < -40.0 * px or feet.x > room.x + 40.0 * px or feet.y > room.y + 160.0 * px:
		_vanish()  # hopped (or got blown) off the edge of the screen
		return
	if vel.y > 0.0 and feet.y >= _floor():
		feet.y = _floor()
		_land()


## He bounces off the side of the screen the way he bounces off walls in the game (back at 2/5 speed).
func _hit_wall() -> void:
	var impact := absf(vel.x)
	vel.x = -vel.x * 0.4
	if impact > 1500.0 * px / 3.0:
		_dizzy_pending = true
		_sfx("hop", -10.0, 0.6)
		say(["ow!", "oof", "bonk"].pick_random(), 1.0)


func _land() -> void:
	var impact := vel.y / px
	vel = Vector2.ZERO
	_flip_angle = 0.0
	_spin_left = 0.0
	_tilt = 0.0  # feet flat on the floor, whatever he's in the middle of
	_tilt_target = 0.0
	_tilt_vel = 0.0
	if impact > 700.0:
		_add_dust()
	if _flung_hard and impact > 900.0:
		_dizzy_pending = true
	_flung_hard = false
	state = State.LAND
	_state_left = 0.12
	_play("crouch")
	landed.emit()


func _after_landing() -> void:
	if _dizzy_pending:
		_dizzy_pending = false
		_interrupt()
		state = State.DIZZY
		_state_left = 1.8
		_play("sad")
		return
	state = State.IDLE
	_play("idle")
	if not _busy:
		_settle()


func _step_held(delta: float) -> void:
	if track_os_cursor and not (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT):
		_pressing = false  # the button came up somewhere we didn't hear about
		_release()
		return
	var target := cursor + _grab_offset
	target.x = clampf(target.x, HALF_W * px, room.x - HALF_W * px)
	target.y = clampf(target.y, HEIGHT * px, _floor())
	if delta > 0.0:
		_throw_vel = _throw_vel.lerp((target - feet) / delta, 0.35)
	feet = target
	_tilt_target = clampf(-_cursor_vel.x / (2200.0 * px / 3.0), -0.8, 0.8)


## Moves the sprite to match him, only touching what changed, so an idle frog costs nothing to draw.
func _update_rig(delta: float) -> void:
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-delta * 12.0))
	if _squash.distance_squared_to(Vector2.ONE) < 0.00001:
		_squash = Vector2.ONE
	_tilt_vel += ((_tilt_target - _tilt) * 90.0 - _tilt_vel * 12.0) * delta
	_tilt += _tilt_vel * delta
	if absf(_tilt - _tilt_target) < 0.001 and absf(_tilt_vel) < 0.01:
		_tilt = _tilt_target
		_tilt_vel = 0.0
	var block := PIXEL_BLOCK * px
	var at := (feet / block).round() * block  # whole game pixels, so his art sits on the pixel grid
	if _rig.position != at:
		_rig.position = at
	var size := Vector2(px, px) * _squash
	if _rig.scale != size:
		_rig.scale = size
	var turn := _tilt + _flip_angle
	if _pivot.rotation != turn:
		_pivot.rotation = turn


# ── Deciding what to do ────────────────────────────────────────────────────

func _think() -> void:
	var near_cursor := cursor.distance_to(_center()) < 240.0 * px and cursor.y > room.y * 0.5
	var pal := _penguin_on_floor()  # (Muse Penguin's out too: he likes them)
	_run(_pick({
		&"wander": 4.0,
		&"leap": 0.4 + 1.8 * _energy,
		&"nap": (3.0 if _is_night() else 0.5) + (2.0 if _energy < 0.25 else 0.0),
		&"hunt": 1.6,
		&"ribbit": 0.8,
		&"visit": 1.4 if near_cursor else 0.0,
		&"see_penguin": 1.8 if not pal.is_empty() else 0.0,
		&"leapfrog": 0.6 + 1.2 * _energy if not pal.is_empty() else 0.0,
	}), pal)


func _pick(weights: Dictionary) -> StringName:
	var total := 0.0
	for weight: float in weights.values():
		total += weight
	var roll := randf() * total
	for action: StringName in weights:
		roll -= weights[action]
		if roll <= 0.0:
			return action
	return &"wander"


## Starts an action, cutting off whatever he was doing. Actions check s against _seq after every
## wait, so being grabbed (or anything else) part way through stops them cleanly.
func _run(action: StringName, arg: Variant = null) -> void:
	if state == State.AIM and action != &"drop_in" and action != &"jump_out":
		return  # you're in the middle of aiming him
	_interrupt()
	var s := _seq
	_busy = true
	if action != &"drop_in" and action != &"jump_out":
		if state == State.HELD or state == State.AIM or state == State.HIDDEN:
			_busy = false
			return
		if state == State.AIR:
			await landed
			if s != _seq:
				return
		if state == State.NAP and not (action in [&"nap", &"long_nap", &"wake", &"startled"]):
			await _wake_up(s)
			if s != _seq:
				return
	match action:
		&"wander": await _act_wander(s)
		&"leap": await _act_leap(s)
		&"nap": await _act_nap(s, false)
		&"long_nap": await _act_nap(s, true)
		&"hunt": await _act_hunt(s)
		&"ribbit": await _act_ribbit(s)
		&"visit": await _act_come(s, cursor.x, false)
		&"come": await _act_come(s, float(arg), true)
		&"startled": await _act_startled(s, float(arg))
		&"wake": await _wake_up(s)
		&"boing": await _act_boing(s)
		&"flip": await _act_flip(s)
		&"drop_in": await _act_drop_in(s, float(arg))
		&"jump_out": await _act_jump_out(s, arg[0], arg[1])
		&"home": await _act_go_home(s, arg)
		&"bye": await _act_bye(s)
		&"see_penguin": await _act_see_penguin(s, arg)
		&"leapfrog": await _act_leapfrog(s, arg)
		&"wave_back": await _act_wave_back(s)
		&"take_fish": await _act_take_fish(s, arg)
	if s == _seq:
		_busy = false
		_settle()


func _interrupt() -> void:
	if state == State.AIM:
		_end_aim_pointer()  # (the normal pointer back)
	_seq += 1
	_busy = false
	_exit_edge = INF
	_floor_override = -1.0
	_home = Rect2()
	_walls = true
	_spin_left = 0.0
	if _tween:
		_tween.kill()
		_tween = null
	if not _fly.is_empty():
		_fly.leaving = true


func _settle() -> void:
	if state == State.HIDDEN:
		return
	state = State.IDLE
	_play("idle")
	_tilt_target = 0.0
	_idle_left = maxf(randf_range(1.5, 4.5), (_yours_until - Time.get_ticks_msec()) / 1000.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Crouch, then jump with velocity v (sprite pixels per second). False if he got interrupted.
func _jump(v: Vector2, crouch: float, s: int) -> bool:
	state = State.CROUCH
	_play("crouch")
	await _wait(crouch)
	if s != _seq:
		return false
	vel = v * px
	if _spin_left != 0.0:
		_spin_speed = _spin_left / maxf(0.25, 2.0 * absf(v.y) / GRAVITY)
	_set_air()
	await landed
	return s == _seq


## A big jump that comes down at target. up is the launch speed (sprite pixels per second).
func _leap_to(target: Vector2, up: float, s: int, max_vx := 320.0) -> bool:
	var g := GRAVITY * px
	var vy := -up * px
	var t := (-vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * (target.y - feet.y)))) / g
	var vx := clampf((target.x - feet.x) / maxf(t, 0.1), -max_vx * px, max_vx * px)
	_sfx("leap", -16.0, randf_range(0.95, 1.1))
	return await _jump(Vector2(vx / px, -up), randf_range(0.22, 0.34), s)


func _set_air() -> void:
	state = State.AIR
	_play("air")
	_met_this_jump.clear()
	_boings = 0


# ── Things he does ─────────────────────────────────────────────────────────

func _act_wander(s: int) -> void:
	var dir := _roomier_side() if randf() < 0.6 else (1.0 if randf() < 0.5 else -1.0)
	for i in randi_range(2, 5):
		if _near_wall(dir, 30.0):
			dir = -dir
		if not await _jump(Vector2(dir * randf_range(50.0, 75.0), -randf_range(140.0, 185.0)), randf_range(0.07, 0.14), s):
			return
		_energy = maxf(0.0, _energy - 0.01)
		await _wait(randf_range(0.05, 0.35))
		if s != _seq:
			return


func _act_leap(s: int) -> void:
	var x := feet.x
	for i in 8:
		x = randf_range(HALF_W * px * 2.0, room.x - HALF_W * px * 2.0)
		if absf(x - feet.x) > 140.0 * px:
			break
	_energy = maxf(0.0, _energy - 0.05)
	if await _leap_to(Vector2(x, _floor()), randf_range(380.0, 520.0), s):
		await _wait(randf_range(0.3, 0.8))


func _act_nap(s: int, long: bool) -> void:
	_tilt_target = 0.0
	say("*yawn*", 1.2)
	await _wait(1.0)
	if s != _seq:
		return
	state = State.NAP
	_play("nap")
	await _wait(randf_range(60.0, 180.0) if long or _is_night() else randf_range(20.0, 60.0))
	if s != _seq:
		return
	await _wake_up(s)


func _wake_up(_s: int) -> void:
	state = State.IDLE
	_play("idle")
	_squash = Vector2(0.86, 1.18)
	say(["?", "mm?", "!"].pick_random(), 1.0)
	await _wait(0.9)


func _act_hunt(s: int) -> void:
	_spawn_fly()
	var waited := 0.0
	var next_scoot := 4.0
	while not _fly.is_empty() and not _fly.leaving:
		var to_fly: Vector2 = _fly.pos - _mouth()
		if waited > 1.2 and _tongue_t < 0.0 and to_fly.y < 0.0 and to_fly.length() < TONGUE_REACH * px:
			_snap_tongue()
			await _wait(0.35)
			if s != _seq:
				return
			if _tongue_hit:
				flies_eaten += 1
				_sfx("gulp", -20.0, 1.5)
				_squash = Vector2(1.15, 0.9)
				if randf() < 0.35:
					say(["yum!", "gulp", "tasty"].pick_random(), 1.0)
			else:
				say("?", 0.8)
			await _wait(0.6)
			return
		await _wait(0.1)
		if s != _seq:
			return
		waited += 0.1
		if waited > next_scoot:
			# Shuffle closer.
			next_scoot = waited + 2.5
			if not await _jump(Vector2(signf(to_fly.x) * 55.0, -160.0), 0.08, s):
				return
		if waited > 14.0:
			_fly.leaving = true
	_tilt_target = 0.0


func _act_ribbit(s: int) -> void:
	say("ribbit!", 1.4)
	for i in 2:
		_squash = Vector2(1.14, 0.9)
		await _wait(0.25)
		if s != _seq:
			return
	await _wait(0.6)


func _act_come(s: int, x: float, called: bool) -> void:
	if not await _hop_over_to(x, s):
		return
	if called or randf() < 0.5:
		say(["hi!", "ribbit!", "hello!", "here!"].pick_random(), 1.3)
	await _wait(1.0)


## Hops (with a big leap first, from far off) until he's within near sprite pixels of x. False if
## he got interrupted.
func _hop_over_to(x: float, s: int, near := 40.0) -> bool:
	x = clampf(x, HALF_W * px, room.x - HALF_W * px)
	if absf(x - feet.x) > 260.0 * px:
		if not await _leap_to(Vector2(x - signf(x - feet.x) * 50.0 * px, _floor()), 480.0, s, 700.0):
			return false
	for i in 12:
		var dx := x - feet.x
		if absf(dx) < near * px:
			break
		if not await _jump(Vector2(signf(dx) * clampf(absf(dx) / px * 1.6, 40.0, 80.0), -randf_range(150.0, 185.0)), 0.08, s):
			return false
		await _wait(randf_range(0.04, 0.16))
		if s != _seq:
			return false
	return true


func _act_startled(s: int, away: float) -> void:
	_play("idle")
	say("!", 0.8)
	_squash = Vector2(0.8, 1.25)
	if await _jump(Vector2(away * randf_range(90.0, 130.0), -randf_range(250.0, 310.0)), 0.03, s):
		await _wait(0.5)


func _act_boing(s: int) -> void:
	_sfx("hop", -16.0, randf_range(1.1, 1.3))
	if randf() < 0.5:
		say(["ribbit!", "hi!", "boing", "hehe"].pick_random(), 1.0)
	await _jump(Vector2(0.0, -230.0), 0.06, s)


func _act_flip(s: int) -> void:
	say("wheee!", 1.0)
	_sfx("hop", -14.0, 1.4)
	_spin_left = TAU * (1.0 if randf() < 0.5 else -1.0)
	await _jump(Vector2(0.0, -380.0), 0.1, s)


func _act_drop_in(s: int, x: float) -> void:
	if x < 0.0 or x > room.x:
		x = randf_range(room.x * 0.25, room.x * 0.75)
	feet = Vector2(clampf(x, HALF_W * px, room.x - HALF_W * px), 0.0)  # just above the top edge
	vel = Vector2(0.0, 40.0 * px)
	_rig.visible = true
	_sfx("pop", -16.0)
	_set_air()
	await landed
	if s != _seq:
		return
	say(["hi!", "ribbit!", "i'm back!"].pick_random(), 1.4)
	await _wait(1.4)


## He shows up standing in the game window, then hops out of its side onto the desktop.
func _act_jump_out(s: int, game: Rect2, reveal: bool) -> void:
	var dir := 1.0 if room.x - game.end.x >= game.position.x else -1.0
	_floor_override = game.end.y - game.size.y * 0.06
	feet = Vector2(game.get_center().x - dir * game.size.x * 0.15, _floor_override)
	vel = Vector2.ZERO
	state = State.IDLE
	_play("idle")
	_squash = Vector2(0.15, 0.15)  # pops in
	_rig.visible = true
	_sfx("pop", -16.0)
	await _wait(0.9)
	if s != _seq:
		return
	if reveal:
		await _wait(1.4)  # he takes a moment to work out where he is
		if s != _seq:
			return
		say("?", 1.3)
		await _wait(1.6)
		if s != _seq:
			return
		say("!", 1.0)
		_squash = Vector2(0.85, 1.2)
		await _wait(1.1)
		if s != _seq:
			return
	for i in 2:
		if not await _jump(Vector2(dir * 60.0, -150.0), 0.1, s):
			return
		await _wait(0.15)
		if s != _seq:
			return
	# The big one, straight out through the side of the window.
	var edge := game.end.x if dir > 0.0 else game.position.x
	_exit_edge = edge
	_exit_dir = dir
	_exit_glass = reveal
	var up := 430.0
	var vx := dir * clampf((absf(edge - feet.x) / px + HALF_W) / (up / GRAVITY * 0.85), 120.0, 900.0)
	_sfx("leap", -12.0)
	if not await _jump(Vector2(vx, -up), 0.5 if reveal else 0.2, s):
		return
	if reveal:
		say("ribbit!!", 1.8)
		await _wait(2.0)
	else:
		await _wait(0.5)


func _break_out() -> void:
	_exit_edge = INF
	_floor_override = -1.0
	if not _exit_glass:
		_sfx("pop", -16.0)
		return
	_sfx("glass", -6.0)
	var at := _center()
	for i in 18:
		_particles.append({
			"kind": "shard",
			"pos": at + Vector2(0.0, randf_range(-24.0, 24.0) * px),
			"vel": Vector2(_exit_dir * randf_range(40.0, 260.0), randf_range(-240.0, 40.0)) * px,
			"rot": randf() * TAU,
			"spin": randf_range(-14.0, 14.0),
			"size": randf_range(1.5, 4.0) * px,
			"life": randf_range(0.9, 1.6),
			"max": 1.6,
		})


## Back into the game window, then he's gone.
func _act_go_home(s: int, game: Rect2) -> void:
	say("bye bye!", 1.2)
	await _wait(1.0)
	if s != _seq:
		return
	_home = game.grow(-HALF_W * px)
	var target := Vector2(clampf(game.get_center().x, HALF_W * px, room.x - HALF_W * px), game.end.y - game.size.y * 0.1)
	var rise := (feet.y - target.y) / px + 40.0
	await _leap_to(target, maxf(560.0, sqrt(2.0 * GRAVITY * maxf(rise, 0.0))), s, 1200.0)
	if s == _seq:
		_vanish()  # came down without getting in (the window moved?): off he goes anyway


func _act_bye(s: int) -> void:
	say("bye!", 1.4)
	await _wait(1.2)
	if s != _seq:
		return
	_walls = false
	var dir := -1.0 if feet.x < room.x * 0.5 else 1.0
	while s == _seq:
		if not await _jump(Vector2(dir * 90.0, -190.0), 0.08, s):
			return


func _vanish() -> void:
	_interrupt()
	state = State.HIDDEN
	vel = Vector2.ZERO
	_rig.visible = false
	_sfx("pop", -14.0)
	if not tucked_away:
		left.emit()  # (gone for good: home, or bye; hiding after a shake, he's still around)


# ── Muse Penguin's penguins (the musiverse) ───────────────────────────────
# They know him over there too (Muse Penguin's renderer/musiverse.js): they wave, look up as he
# goes over, and yelp when he boings off their heads.

## Hops over next to a penguin and says hello.
func _act_see_penguin(s: int, pal: Dictionary) -> void:
	var side := _side_of(pal)
	var gap := float(pal.w) * 0.5 + (HALF_W + 4.0) * px
	var x := float(pal.x) + side * gap
	if x < HALF_W * px or x > room.x - HALF_W * px:
		x = float(pal.x) - side * gap
	if not await _hop_over_to(x, s, 16.0):
		return
	_tell(&"hello", pal.id)
	_add_heart()
	await _wait(randf_range(1.5, 2.5))


## Leapfrog! A run-up to a penguin, then one big jump right over the top of them.
func _act_leapfrog(s: int, pal: Dictionary) -> void:
	var side := _side_of(pal)
	var clear := float(pal.w) * 0.5 + HALF_W * px
	if not _has_room_past(pal, side, clear):
		await _act_see_penguin(s, pal)  # (they're up against the edge: just say hi)
		return
	if not await _hop_over_to(float(pal.x) + side * (clear + 24.0 * px), s, 16.0):
		return
	pal = _penguin(str(pal.id))  # (where they've got to since)
	if pal.is_empty() or absf(feet.x - float(pal.x)) < clear or not _has_room_past(pal, side, clear):
		return
	await _wait(randf_range(0.2, 0.4))
	if s != _seq:
		return
	# Up fast enough that his feet are well clear of their head, and down as far past their middle
	# as he takes off from, so the top of the jump is right over them.
	var up := sqrt(2.0 * GRAVITY * (float(pal.h) / px + 24.0))
	var land := clampf(2.0 * float(pal.x) - feet.x, HALF_W * px, room.x - HALF_W * px)
	if await _leap_to(Vector2(land, _floor()), clampf(up, 300.0, 700.0), s, 700.0):
		await _wait(randf_range(0.4, 0.9))


## A penguin held out a fish: he turns to it and snaps it up with his tongue, like a fly (but much
## bigger, so: a happy hop after).
func _act_take_fish(s: int, pal: Dictionary) -> void:
	# (the penguin faces him, holding the fish out in front of its head: on his side of it)
	var side := _side_of(pal)
	var fish := Vector2(float(pal.x) + side * float(pal.w) * 0.35, float(pal.y) - float(pal.h) * 0.7)
	if fish.distance_to(_mouth()) > TONGUE_REACH * px:
		fish = _mouth() + (fish - _mouth()).limit_length(TONGUE_REACH * px)
	await _wait(0.15)
	if s != _seq:
		return
	_tongue_t = 0.0
	_tongue_hit = true
	_tongue_to = fish
	await _wait(0.3)
	if s != _seq:
		return
	_sfx("gulp", -18.0, 1.1)
	_squash = Vector2(1.2, 0.85)
	affection += 1
	_add_heart()
	await _wait(0.4)
	if s != _seq:
		return
	_add_heart()
	await _jump(Vector2(0.0, -230.0), 0.06, s)


## A penguin came over to wave: hearts, and a happy hop for them.
func _act_wave_back(s: int) -> void:
	_add_heart()
	await _wait(0.35)
	if s != _seq:
		return
	_add_heart()
	_sfx("hop", -16.0, randf_range(1.1, 1.3))
	await _jump(Vector2(0.0, -210.0), 0.06, s)


## On the way past a penguin: going right over the top of one is leapfrog, and coming down on
## one's head is a boing (he bounces off to the side, like off a springboard).
func _meet_penguins(was: Vector2) -> void:
	if penguins.is_empty() or not _walls or _floor_override >= 0.0 or _home.has_area():
		return
	for p: Dictionary in penguins:
		var id := str(p.id)
		var head := float(p.y) - float(p.h)
		var dx := feet.x - float(p.x)
		var reach := float(p.w) * 0.5 + HALF_W * px * 0.5
		if vel.y > 0.0 and was.y <= head and feet.y >= head and absf(dx) < reach and _boings < 2:
			_boings += 1
			_met_this_jump[id] = true
			feet.y = head
			vel.y = -maxf(vel.y * 0.7, 260.0 * px)
			vel.x = (signf(dx) if dx != 0.0 else _roomier_side()) * maxf(absf(vel.x), 90.0 * px)
			_sfx("hop", -12.0, randf_range(1.25, 1.45))
			_tell(&"hop_on", id)
			return
		if not _met_this_jump.has(id) and minf(was.y, feet.y) < head and signf(was.x - float(p.x)) != signf(dx):
			_met_this_jump[id] = true
			_tell(&"leapfrog", id)


## A penguin down on the floor with him, to go and see ({} when there isn't one).
func _penguin_on_floor() -> Dictionary:
	var near: Array = []
	for p: Dictionary in penguins:
		if absf(float(p.y) - _floor()) < 12.0 * px and float(p.x) > HALF_W * px and float(p.x) < room.x - HALF_W * px:
			near.append(p)
	return near.pick_random() if not near.is_empty() else {}


func _penguin(id: String) -> Dictionary:
	for p: Dictionary in penguins:
		if str(p.id) == id:
			return p
	return {}


## Which side of a penguin he's on (1: their right).
func _side_of(pal: Dictionary) -> float:
	var side := signf(feet.x - float(pal.x))
	return side if side != 0.0 else _roomier_side()


func _has_room_past(pal: Dictionary, side: float, clear: float) -> bool:
	var land := float(pal.x) - side * (clear + 20.0 * px)
	return land >= HALF_W * px and land <= room.x - HALF_W * px


func _tell(type: StringName, to: Variant) -> void:
	_mv_events.append({"type": String(type), "from": "froggy", "to": str(to)})
	if _mv_events.size() > 8:
		_mv_events.pop_front()


# ── You and him ────────────────────────────────────────────────────────────

func _clicked() -> void:
	var now := Time.get_ticks_msec()
	_clicks.append(now)
	while not _clicks.is_empty() and now - _clicks[0] > 900:
		_clicks.pop_front()
	if state == State.NAP:
		_run(&"wake")
	elif state == State.IDLE or state == State.LAND:
		if _clicks.size() >= 3:
			_clicks.clear()
			_run(&"flip")
		else:
			_run(&"boing")


func _grab(at: Vector2) -> void:
	_interrupt()
	state = State.HELD
	_play("air")
	_sfx("grab", -14.0)
	if randf() < 0.4:
		say(["!", "hey!", "wheee", "eep!"].pick_random(), 0.9)
	_grab_offset = feet - at
	_throw_vel = Vector2.ZERO
	_flip_angle = 0.0


## Standing (or napping), pulling back from him is a Frog Quest jump.
func _can_aim() -> bool:
	return state in [State.IDLE, State.LAND, State.CROUCH, State.NAP]


func _start_aim() -> void:
	_interrupt()
	state = State.AIM
	_play("idle")
	_sfx("grab", -14.0)
	_aim = Vector2.ZERO
	_aim_from = _press_at
	Input.set_custom_mouse_cursor(load("res://assets/cursorclosed.png"))
	# Down on the bottom of the screen there's hardly any room to pull back, so in a cramped direction
	# each pixel of pull counts for more: pulling to the edge of the screen is a full-strength jump.
	# (It used to hide the pointer and move it up out of the way, which felt like the mouse jumped.)
	var need := AIM_ROOM * px
	var reach := _pointer_reach(_aim_from)
	_gain_left = _aim_gain(need.x, _aim_from.x - reach.position.x)
	_gain_right = _aim_gain(need.x, reach.end.x - _aim_from.x)
	_gain_down = _aim_gain(need.y, reach.end.y - _aim_from.y)


## Where the pointer can go from p, in window pixels: along his row across every screen side by side,
## and down to the bottom of his own screen (over the taskbar too: the pointer can go there, he can't).
func _pointer_reach(p: Vector2) -> Rect2:
	if not track_os_cursor:
		return Rect2(Vector2.ZERO, room)
	var origin := Vector2(get_window().position)
	var at := p + origin
	var reach := Rect2(at, Vector2.ZERO)
	for screen in DisplayServer.get_screen_count():
		var r := Rect2(Vector2(DisplayServer.screen_get_position(screen)), Vector2(DisplayServer.screen_get_size(screen)))
		if at.y >= r.position.y and at.y < r.end.y:
			reach = reach.merge(Rect2(r.position.x, at.y, r.size.x, 0.0))
		if r.has_point(at):
			reach = reach.merge(Rect2(at.x, r.position.y, 0.0, r.size.y))
	reach.position -= origin
	return reach


## How much each pixel of pull counts with this much room (need: the room a full-strength jump takes).
func _aim_gain(need: float, space: float) -> float:
	return clampf(need / maxf(space, 1.0), 1.0, AIM_GAIN_MOST)


func _step_aim() -> void:
	if track_os_cursor and not (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT):
		_pressing = false  # the button came up somewhere we didn't hear about
		_launch()
		return
	var pull := _aim_from - cursor  # (pulling to the left is +x: he goes right)
	pull.x *= _gain_left if pull.x > 0.0 else _gain_right
	if pull.y < 0.0:
		pull.y *= _gain_down
	_aim = pull / px
	_play("prejump" if _aim.length() * GAME_UNITS_PER_PX > 200.0 else "idle")  # the game crouches on a big pull


## Let go: he jumps the other way from how you pulled (a tiny tug is nothing).
func _launch() -> void:
	_end_aim_pointer()
	var v := _launch_velocity(_aim)
	_aim = Vector2.ZERO
	if v == Vector2.ZERO:
		_settle()
		return
	_yours_until = Time.get_ticks_msec() + 4000
	vel = v * px
	_sfx("hop", -12.0, randf_range(0.8, 1.2))
	_set_air()


## The pointer back to the normal one (it's the closed hand while you pull).
func _end_aim_pointer() -> void:
	Input.set_custom_mouse_cursor(null)


## Trajectory.gd's own numbers, worked in the game's units: pull back further, jump further.
func _launch_velocity(pull: Vector2) -> Vector2:
	if pull.length() < 4.0:
		return Vector2.ZERO
	var v := pull * GAME_UNITS_PER_PX * AIM_SENSITIVITY
	v.x = clampf(v.x * 1.5, -800.0, 800.0)
	v.y = clampf(v.y * 1.1, -450.0, 450.0)
	if absf(v.x) < 450.0:
		v.x += 200.0 * signf(v.x)
	if absf(v.x) < 450.0 and absf(v.y) > 350.0:
		v.x += 50.0 * signf(v.x)
	v /= GAME_UNITS_PER_PX
	v.y = minf(v.y, -80.0)  # (out here he always leaves the ground)
	return v


## The game's aim line (Trajectory.gd _draw), in the game's units: how long it is, and how red.
func _aim_line() -> Vector2:
	return (_aim * GAME_UNITS_PER_PX * AIM_SENSITIVITY * 0.5).clamp(Vector2(-300.0, -300.0), Vector2(300.0, 300.0))


func _aim_tip() -> Vector2:
	return _center() + _aim_line() / 5.0 / GAME_UNITS_PER_PX * px


func _release() -> void:
	vel = _throw_vel.limit_length(5200.0 * px / 3.0)
	_flung_hard = vel.length() > 1800.0 * px / 3.0
	if _flung_hard and randf() < 0.5:
		say(["wheee!", "aaa!"].pick_random(), 0.9)
	_set_air()


func _react_to_cursor(delta: float) -> void:
	_pet_cooldown -= delta
	_startle_cooldown -= delta
	if (state != State.IDLE and state != State.NAP) or _pressing:
		return
	if _body_rect().has_point(cursor):
		# Rubbing back and forth over him is petting.
		if absf(_cursor_vel.x) > 60.0 * px:
			var dir := signf(_cursor_vel.x)
			if dir != _pet_dir:
				_pet_dir = dir
				_pet_turns.append(Time.get_ticks_msec())
		while not _pet_turns.is_empty() and Time.get_ticks_msec() - _pet_turns[0] > 1600:
			_pet_turns.pop_front()
		if _pet_turns.size() >= 4 and _pet_cooldown <= 0.0:
			_pet_turns.clear()
			_pet_cooldown = 0.7
			_petted()
		return
	# A cursor swooping in fast makes him jump.
	if _startle_cooldown <= 0.0 and _cursor_vel.length() > 2400.0 * px / 3.0 \
			and cursor.distance_to(_center()) < 40.0 * px:
		_startle_cooldown = 5.0
		var away := signf(_center().x - cursor.x)
		_run(&"startled", away if away != 0.0 else 1.0)


func _petted() -> void:
	affection += 1
	_add_heart()
	_add_heart()
	_squash = Vector2(1.12, 0.9)
	if state == State.NAP:
		return  # he smiles in his sleep
	if randf() < 0.25:
		say(["hehe", "<3", "ribbit <3"].pick_random(), 1.2)
	_idle_left = maxf(_idle_left, 2.0)


# ── Flies and his tongue ───────────────────────────────────────────────────

func _spawn_fly() -> void:
	var side := _roomier_side()
	var at := _center() + Vector2(side * randf_range(90.0, 140.0), -randf_range(50.0, 90.0)) * px
	at = at.clamp(Vector2(10.0, 10.0) * px, room - Vector2(10.0, 10.0) * px)
	_fly = {
		"pos": at, "home": at, "t": 0.0,
		"a": randf_range(2.3, 3.4), "b": randf_range(3.1, 4.6), "phase": randf() * TAU,
		"r": Vector2(randf_range(18.0, 34.0), randf_range(10.0, 20.0)) * px,
		"leaving": false, "caught": false, "away": side, "glow": _is_night(),
	}


func _step_fly(delta: float) -> void:
	if _fly.is_empty():
		return
	var t := float(_fly.t) + delta
	_fly.t = t
	if _fly.caught:
		return
	var home: Vector2 = _fly.home
	if _fly.leaving:
		home += Vector2(float(_fly.away) * 160.0, -110.0) * px * delta
		if home.distance_to(_center()) > 120.0 * px or not Rect2(Vector2.ZERO, room).has_point(home):
			_fly = {}
			return
	else:
		home = home.lerp(_mouth() + Vector2(0.0, -24.0 * px), 1.0 - exp(-delta * 0.35))  # drifts in toward his face
	_fly.home = home
	var r: Vector2 = _fly.r
	_fly.pos = home + Vector2(sin(t * float(_fly.a) + float(_fly.phase)) * r.x, sin(t * float(_fly.b)) * r.y)


func _snap_tongue() -> void:
	_tongue_t = 0.0
	_tongue_hit = randf() < 0.85
	_tongue_to = _fly.pos


func _step_tongue(delta: float) -> void:
	if _tongue_t < 0.0:
		return
	_tongue_t += delta
	if not _fly.is_empty():
		if _tongue_hit and _tongue_t >= 0.07:
			_fly.caught = true
		if _fly.caught:
			_fly.pos = _tongue_tip()
	if _tongue_t >= 0.17:
		_tongue_t = -1.0
		if not _fly.is_empty():
			if _fly.caught:
				_fly = {}
			else:
				_fly.leaving = true


func _tongue_tip() -> Vector2:
	var reach := _tongue_t / 0.07 if _tongue_t < 0.07 else 1.0 - (_tongue_t - 0.07) / 0.1
	return _mouth().lerp(_tongue_to, clampf(reach, 0.0, 1.0))


# ── Hearts, glass and dust ─────────────────────────────────────────────────

func _add_heart() -> void:
	_particles.append({"kind": "heart", "pos": _head_point() + Vector2(randf_range(-8.0, 8.0), 0.0) * px,
		"vel": Vector2(randf_range(-25.0, 25.0), randf_range(-75.0, -55.0)) * px, "life": 1.3, "max": 1.3})


func _add_dust() -> void:
	for side in [-1.0, 1.0]:
		_particles.append({"kind": "dust", "pos": feet + Vector2(side * 10.0, -1.5) * px,
			"vel": Vector2(side * 30.0, -6.0) * px, "life": 0.4, "max": 0.4})


func _step_particles(delta: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var p := _particles[i]
		p.life = float(p.life) - delta
		if p.life <= 0.0:
			_particles.remove_at(i)
			continue
		var v: Vector2 = p.vel
		match p.kind:
			"shard":
				v.y += GRAVITY * px * 0.9 * delta
				p.rot = float(p.rot) + float(p.spin) * delta
			"heart":
				v *= 1.0 - delta * 1.5
		p.vel = v
		p.pos = p.pos + v * delta


func _draw_fx() -> void:
	for p in _particles:
		var fade := clampf(float(p.life) / float(p.max) * 1.5, 0.0, 1.0)
		match p.kind:
			"heart":
				_draw_pattern(HEART, p.pos, maxf(2.0, px - 1.0), Color(1.0, 0.42, 0.56, fade))
			"shard":
				var s: float = p.size
				var shape: PackedVector2Array = Transform2D(float(p.rot), p.pos) \
					* PackedVector2Array([Vector2(-s, -s * 0.4), Vector2(s, 0.0), Vector2(-s * 0.3, s * 0.7)])
				_fx.draw_colored_polygon(shape, Color(0.82, 0.94, 1.0, 0.85 * fade))
				shape.append(shape[0])
				_fx.draw_polyline(shape, Color(1.0, 1.0, 1.0, fade), 1.0)
			"dust":
				var grown := (1.0 - float(p.life) / float(p.max)) * 5.0 * px + px
				_fx.draw_circle(p.pos, grown, Color(0.92, 0.92, 0.86, 0.55 * fade))
	if state == State.DIZZY:
		var head := _head_point()
		for i in 3:
			var a := Time.get_ticks_msec() * 0.006 + i * TAU / 3.0
			_draw_star(head + Vector2(cos(a) * 10.0 * px, sin(a) * 3.0 * px - 3.0 * px))
	if state == State.AIM:
		# white for a little hop, redder the harder you pull (like the game's line)
		var white := clampf(1.2 - _aim_line().length() / Vector2(300.0, 300.0).length(), 0.0, 1.0)
		_fx.draw_line(_center(), _aim_tip(), Color(1.0, white, white), maxf(2.0, float(px)))
	if not _fly.is_empty():
		_draw_fly()
	if _tongue_t >= 0.0:
		var tip := _tongue_tip()
		_fx.draw_line(_mouth(), tip, Color(0.95, 0.45, 0.55), 1.4 * px)
		_fx.draw_circle(tip, 1.4 * px, Color(0.95, 0.45, 0.55))
	if _bubble_left > 0.0:
		_draw_bubble()


func _draw_pattern(rows: Array, center: Vector2, cell: float, color: Color) -> void:
	var origin := center - Vector2(rows[0].length(), rows.size()) * cell * 0.5
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "#":
				_fx.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), color)


func _draw_star(at: Vector2) -> void:
	var color := Color(1.0, 0.9, 0.3)
	_fx.draw_rect(Rect2(at - Vector2(1.5, 0.5) * px, Vector2(3.0, 1.0) * px), color)
	_fx.draw_rect(Rect2(at - Vector2(0.5, 1.5) * px, Vector2(1.0, 3.0) * px), color)


func _draw_fly() -> void:
	var at: Vector2 = _fly.pos
	if _fly.glow:
		_fx.draw_circle(at, 5.0 * px, Color(1.0, 0.95, 0.4, 0.12))
		_fx.draw_circle(at, 2.6 * px, Color(1.0, 0.95, 0.5, 0.3))
		_fx.draw_circle(at, 1.2 * px, Color(1.0, 1.0, 0.75))
		return
	var lift := 1.6 * px * (1.0 if fmod(float(_fly.t) * 28.0, 2.0) < 1.0 else 0.4)
	var wing := Color(0.85, 0.92, 1.0, 0.8)
	_fx.draw_rect(Rect2(at + Vector2(-2.2 * px, -lift), Vector2(1.6, 1.2) * px), wing)
	_fx.draw_rect(Rect2(at + Vector2(0.6 * px, -lift), Vector2(1.6, 1.2) * px), wing)
	_fx.draw_rect(Rect2(at - Vector2(0.9, 0.9) * px, Vector2(1.8, 1.8) * px), Color(0.12, 0.12, 0.14))


func _draw_bubble() -> void:
	var r := _bubble_rect()
	var tail_x := clampf(_head_point().x, r.position.x + 3.0 * px, r.end.x - 3.0 * px)
	_fx.draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 2.0 * px, r.end.y - 1.0),
		Vector2(tail_x + 2.0 * px, r.end.y - 1.0), Vector2(tail_x, r.end.y + 3.0 * px)]), _bubble_box.border_color)
	_fx.draw_style_box(_bubble_box, r)
	_fx.draw_colored_polygon(PackedVector2Array([Vector2(tail_x - 1.2 * px, r.end.y - 2.0),
		Vector2(tail_x + 1.2 * px, r.end.y - 2.0), Vector2(tail_x, r.end.y + 1.6 * px)]), _bubble_box.bg_color)
	var size := _bubble_font_size()
	_fx.draw_string(_font, r.position + Vector2(3.0 * px, 2.0 * px + _font.get_ascent(size)), _bubble,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.1, 0.1, 0.1))


# ── Where his bits are ─────────────────────────────────────────────────────

func _floor() -> float:
	return _floor_override if _floor_override >= 0.0 else room.y


func _center() -> Vector2:
	return feet + Vector2(0.0, -FEET_TO_CENTER * px).rotated(_rig.rotation)


func _pivot_transform() -> Transform2D:
	return Transform2D(_rig.rotation, Vector2(px, px) * _squash, 0.0, feet) \
		* Transform2D(_tilt + _flip_angle, Vector2(0.0, -FEET_TO_CENTER))


func _mouth() -> Vector2:
	return _pivot_transform() * Vector2(0.0, MOUTH_Y)


func _head_point() -> Vector2:
	return Vector2(_center().x, _figure_rect().position.y)


## Him and his hat, in window pixels (with a little to spare round the edges).
func _figure_rect() -> Rect2:
	return _bounds(Rect2(-18.0, -35.0, 36.0, 52.0) if _hat.visible else Rect2(-17.0, -17.0, 34.0, 34.0))


## Just his body: what you can click, pet and grab.
func _body_rect() -> Rect2:
	return _bounds(Rect2(-15.0, -14.0, 30.0, 29.0))


func _bounds(local: Rect2) -> Rect2:
	var xf := _pivot_transform()
	var r := Rect2(xf * local.position, Vector2.ZERO)
	for corner in [Vector2(local.end.x, local.position.y), local.end, Vector2(local.position.x, local.end.y)]:
		r = r.expand(xf * corner)
	return r


## (a whole step of the pixel font's 16-pixel grid: in between, its letters go lumpy)
func _bubble_font_size() -> int:
	return load("res://scripts/UIStyle.gd").px(6 * px)


func _bubble_rect() -> Rect2:
	var size := _font.get_string_size(_bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, _bubble_font_size()) + Vector2(6.0, 4.0) * px
	var r := Rect2(_head_point() + Vector2(-size.x * 0.5, -size.y - 5.0 * px), size)
	r.position.x = clampf(r.position.x, 2.0, maxf(2.0, room.x - size.x - 2.0))
	r.position.y = maxf(r.position.y, 2.0)
	return r


func _roomier_side() -> float:
	return 1.0 if room.x - feet.x > feet.x else -1.0


func _near_wall(dir: float, margin: float) -> bool:
	var reach := (HALF_W + margin) * px
	return (dir < 0.0 and feet.x < reach) or (dir > 0.0 and feet.x > room.x - reach)


func _is_night() -> bool:
	var hour := int(Time.get_datetime_dict_from_system().hour)
	return hour >= 21 or hour < 6


# ── Looks and sounds ───────────────────────────────────────────────────────

func _play(anim: StringName) -> void:
	if _body.animation != anim or not _body.is_playing():
		_body.play(anim)


## His hat sits on his head, as in the game: it comes down with his head when he breathes and crouches
## (FroggyHead.gd reads how far from his art).
func _place_hat() -> void:
	var frames: Array = ANIMS.get(String(_body.animation), [0.0, []])[1]
	var drop := 0
	if _body.frame < frames.size():
		drop = _froggy_head.drop(load(frames[_body.frame][0]))
	_hat.position = Vector2(0.0, HAT_Y + drop)


## His hat and skin are the ones he wears in the game (see player.gd _apply_equipped_cosmetics).
func _dress_up() -> void:
	var hat := MusicManager.equipped_hat if randf() < HAT_CHANCE else ""  # (only once in a while)
	_hat.texture = _solid_hat(HATS[hat][0]) if HATS.has(hat) else null
	_hat.scale = Vector2.ONE * (HATS[hat][1] if HATS.has(hat) else 1.0)
	_hat.offset = Vector2(0.0, HATS[hat][2] if HATS.has(hat) else 0.0)
	_hat.visible = _hat.texture != null
	if hat == "blackcrown":
		_hat.material = _tint(Color(0.0, 0.0, 0.0), 1.0)
	match MusicManager.equipped_skin:
		"golden_skin":
			_body.material = _tint(Color(1.0, 0.75, 0.0), 0.55)
		"grayscale_skin":
			_body.material = _shader_material("res://assets/grayscale.gdshader")
		"negative_skin":
			_body.material = _shader_material("res://assets/negative.gdshader")


## A hat with its soft edge made hard: each pixel all hat or not at all. Drawn half see-through over
## his head, the crown's edge mixed with his green and came out as a row of odd yellow-green blocks.
## (Hats are drawn at their own scale, not on his grid, so that's all they need; lone specks go too.)
func _solid_hat(path: String) -> Texture2D:
	var art := (load(path) as Texture2D).get_image()
	if art.is_compressed():
		art.decompress()
	art.convert(Image.FORMAT_RGBA8)
	var w := art.get_width()
	var h := art.get_height()
	var solid := art.duplicate() as Image
	for y in h:
		for x in w:
			var c := art.get_pixel(x, y)
			solid.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0 if c.a >= 0.5 else 0.0))
	var out := solid.duplicate() as Image
	for y in h:
		for x in w:
			if solid.get_pixel(x, y).a == 0.0:
				continue
			var alone := true
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and solid.get_pixelv(p).a > 0.0:
					alone = false
					break
			if alone:
				out.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(out)


## One of his frames from the game, redrawn on the chunky-pixel grid froggy_pixels.gdshader draws.
## The shader keeps one art pixel out of every 2x2 block, solid or not at all, so the game art's soft
## see-through edges (in the game they blend into the ground) came out as stray blocks out here:
## single pixels sticking out of his outline, a notch under his belly, and different ones as he moved.
## So each frame is shrunk onto that grid first, lined up the way _process snaps him (whole game
## pixels from his feet): a block is solid when 2 or more of its 4 pixels are, in their commonest
## colour; lone specks and soft one-block nubs go; and nothing under his feet line is kept. All 4
## pixels of a block are then the same, so whichever one the shader picks, he looks right.
func _solid_frame(path: String) -> Texture2D:
	var art := (load(path) as Texture2D).get_image()
	if art.is_compressed():
		art.decompress()
	art.convert(Image.FORMAT_RGBA8)
	var w := art.get_width()
	var h := art.get_height()
	var feet_row := int(FEET_TO_CENTER) + h / 2  # the first art row under his feet
	# (the sprite is centred, his feet sit on a grid line: so the grid's blocks start on these)
	var start := Vector2i(posmod(w / 2, 2), posmod(feet_row, 2))
	var corners := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	var blocks := {}  # top-left art pixel -> colour
	var ties := {}  # the blocks only 2 of whose 4 pixels are solid (the soft edge's)
	for by in range(start.y - 2, feet_row, 2):
		for bx in range(start.x - 2, w, 2):
			var counts := {}
			var solid := 0
			for corner: Vector2i in corners:
				var p: Vector2i = Vector2i(bx, by) + corner
				if p.x < 0 or p.y < 0 or p.x >= w or p.y >= feet_row:
					continue
				var c := art.get_pixelv(p)
				if c.a >= 0.5:
					solid += 1
					var rgb := Color(c.r, c.g, c.b)
					counts[rgb] = int(counts.get(rgb, 0)) + 1
			if solid >= 2:
				var best := Color()
				var most := 0
				for rgb: Color in counts:
					if int(counts[rgb]) > most:
						most = int(counts[rgb])
						best = rgb
				blocks[Vector2i(bx, by)] = best
				if solid == 2:
					ties[Vector2i(bx, by)] = true
	# A block touching nothing side-on is a speck. A soft-edge block (one that only just made it, on
	# a tie) sticking out on its own, touching one other block, is a nub: the pixel poking up off his
	# head while he naps, or out of his cheek. His toes stick out like that too, so the feet row's stay.
	var specks := {}
	for b: Vector2i in blocks:
		if _side_neighbours(blocks, b) == 0:
			specks[b] = true
	for b: Vector2i in specks:
		blocks.erase(b)
	var feet_blocks := feet_row - 2  # the bottom row of blocks
	var nubs := {}
	for b: Vector2i in blocks:
		if ties.has(b) and b.y < feet_blocks and _side_neighbours(blocks, b) == 1:
			nubs[b] = true
	for b: Vector2i in nubs:
		blocks.erase(b)
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for b: Vector2i in blocks:
		for corner: Vector2i in corners:
			var p: Vector2i = b + corner
			if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
				out.set_pixelv(p, blocks[b])
	return ImageTexture.create_from_image(out)


## How many of a block's four side-on neighbours (2 art pixels away) are blocks too.
static func _side_neighbours(blocks: Dictionary, b: Vector2i) -> int:
	var n := 0
	for d: Vector2i in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
		if blocks.has(b + d):
			n += 1
	return n


func _tint(color: Color, strength: float) -> ShaderMaterial:
	var mat := _shader_material("res://assets/skin_tint.gdshader")
	mat.set_shader_parameter("tint_color", color)
	mat.set_shader_parameter("tint_strength", strength)
	return mat


func _shader_material(path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	return mat


func _sfx(sound: String, volume_db: float, pitch := 1.0) -> void:
	if not sounds_on:
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(SOUNDS[sound])
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
