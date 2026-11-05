extends Node2D
## A little yellow songbird sitting about the tree: it hops, turns round and pecks, and when the frog comes near
## (or lands, or jumps, near it) it's off with a flutter and a chirp, up and away; it's back later, once
## he's gone a good way off. Wildlife.gd puts them out.

const ART := "res://assets/critters.png"
## (its frames: CritterArt's bird_sit, bird_peck, bird_fly1 and bird_fly2, at its pixel size)
const NEAR := 80.0  # the frog this near and it's off
const STARTLED := 170.0  # this near and him moving fast (a jump, a landing), off too
const FAST := 140.0
const BACK_AFTER := 30.0  # seconds gone at the least, before it's back (and only with him far off)
const AWAKE := 1000.0  # (it only bothers with anything with the camera this near)
const SOUND := "res://assets/bird_away.wav"

enum { SITTING, FLYING, GONE }

var perch := Vector2.ZERO  # (where its feet go)
var frog: Node2D = null
var state := SITTING
var _art: Texture2D
var _frames := {}
var _t := 0.0
var _next := 1.0  # seconds to its next little move
var _peck := 0.0
var _hop := 0.0  # (seconds into a hop; 0 when not hopping)
var _hop_from := 0.0
var _hop_to := 0.0
var _vel := Vector2.ZERO
var _gone := 0.0
var _left := true  # facing left (as drawn)
var _sound: AudioStreamPlayer2D


func _ready() -> void:
	_art = load(ART)
	var art: Script = load("res://scripts/CritterArt.gd")
	for f in ["sit", "peck", "fly1", "fly2"]:
		_frames[f] = art.RECTS["bird_" + f]
	z_index = 1
	scale = Vector2(art.PIXEL, art.PIXEL)
	position = perch
	_left = randf() < 0.5
	_next = randf_range(0.5, 2.5)
	_sound = AudioStreamPlayer2D.new()
	_sound.stream = load(SOUND)
	_sound.bus = &"FX"
	_sound.volume_db = -13.0
	_sound.max_distance = 900.0
	add_child(_sound)


func _process(delta: float) -> void:
	if state == GONE:
		_gone += delta
		if _gone >= BACK_AFTER and _far_off():
			state = SITTING
			position = perch
			visible = true
			_next = randf_range(0.5, 2.0)
		return
	if not _view().grow(AWAKE).has_point(global_position):
		return
	_t += delta
	if state == SITTING:
		_sit(delta)
	else:
		_fly(delta)
	queue_redraw()


func _sit(delta: float) -> void:
	if frog and is_instance_valid(frog) and frog.is_visible_in_tree():
		var d := frog.global_position.distance_to(global_position)
		var moving: float = frog.velocity.length() if "velocity" in frog else 0.0
		if d < NEAR or (d < STARTLED and moving > FAST):
			fly_off()
			return
	if _peck > 0.0:
		_peck -= delta
	if _hop > 0.0:
		_hop += delta
		var k := minf(1.0, _hop / 0.16)
		position = Vector2(lerpf(_hop_from, _hop_to, k), perch.y - sin(k * PI) * 3.0)
		if k >= 1.0:
			_hop = 0.0
		return
	_next -= delta
	if _next > 0.0:
		return
	_next = randf_range(0.8, 2.6)
	var what := randf()
	if what < 0.45:
		_peck = 0.28
	elif what < 0.75:
		_hop_from = position.x
		_hop_to = clampf(position.x + (-4.0 if _left else 4.0), perch.x - 10.0, perch.x + 10.0)
		_hop = 0.001
	else:
		_left = not _left


## Off it goes: a flutter and a chirp, up and away from him.
func fly_off() -> void:
	if state != SITTING:
		return
	state = FLYING
	var away := 1.0
	if frog and is_instance_valid(frog):
		away = signf(global_position.x - frog.global_position.x)
	if away == 0.0:
		away = 1.0 if randf() < 0.5 else -1.0
	_left = away < 0.0
	_vel = Vector2(away * randf_range(60.0, 85.0), -randf_range(80.0, 105.0))
	_t = 0.0
	_sound.pitch_scale = randf_range(0.92, 1.12)
	_sound.play()


func _fly(delta: float) -> void:
	_vel += Vector2(signf(_vel.x) * 40.0, -30.0) * delta
	position += _vel * delta
	if _t > 4.0 or not _view().grow(120.0).has_point(global_position):
		state = GONE
		_gone = 0.0
		visible = false


## Him far off, and its perch not on the screen: nobody sees it come back.
func _far_off() -> bool:
	if frog and is_instance_valid(frog) and frog.global_position.distance_to(perch) < 700.0:
		return false
	return not _view().grow(60.0).has_point(perch)


func _draw() -> void:
	var frame: Rect2 = _frames.sit
	if state == FLYING:
		frame = _frames.fly1 if int(_t * 16.0) % 2 == 0 else _frames.fly2
	elif _peck > 0.0:
		frame = _frames.peck
	var size := frame.size
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
	if not _left:
		rect = Rect2(rect.position.x + size.x, rect.position.y, -size.x, size.y)
	draw_texture_rect_region(_art, rect, frame)


## What the camera sees, in the world.
func _view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := vp.get_canvas_transform().affine_inverse()
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
