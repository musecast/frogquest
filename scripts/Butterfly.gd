extends Node2D
## A butterfly about a patch of flowers: it flits round them (two frames of wings), now and then settles on
## one a while, and flutters off up out of the way if the frog comes near. Wildlife.gd puts them out.

const ART := "res://assets/critters.png"
const WINGS := [  # each colour: wings open, shut
	[Rect2(99, 0, 7, 6), Rect2(107, 0, 7, 6)],
	[Rect2(115, 0, 7, 6), Rect2(123, 0, 7, 6)],
	[Rect2(131, 0, 7, 6), Rect2(139, 0, 7, 6)],
]
const SCALE := 1.2  # (the tiles')
const ROAM := Vector2(46.0, 30.0)  # how far it wanders from its flowers
const SPEED := 30.0
const SHY := 70.0  # the frog this near and it's off
const AWAKE := 900.0  # (it only bothers moving with the camera this near)

var home := Vector2.ZERO  # (its flowers, on the ground)
var colour := 0
var frog: Node2D = null
var _art: Texture2D
var _target := Vector2.ZERO
var _vel := Vector2.ZERO
var _t := 0.0
var _flap := 0.0
var _open := true
var _rest := 0.0  # seconds left settled
var _scared := 0.0


func _ready() -> void:
	_art = load(ART)
	z_index = 1
	scale = Vector2(SCALE, SCALE)
	_t = randf() * 10.0
	position = home + Vector2(randf_range(-ROAM.x, ROAM.x), -randf_range(10.0, ROAM.y))
	_pick()


func _pick() -> void:
	if randf() < 0.22:  # down onto a flower for a bit
		_target = home + Vector2(randf_range(-ROAM.x * 0.5, ROAM.x * 0.5), -9.0)
		_rest = -1.0  # (settles when it gets there)
	else:
		_target = home + Vector2(randf_range(-ROAM.x, ROAM.x), -randf_range(10.0, ROAM.y + 10.0))
		_rest = 0.0


func _process(delta: float) -> void:
	if not _view().grow(AWAKE).has_point(global_position):
		return
	_t += delta
	if frog and is_instance_valid(frog) and frog.global_position.distance_to(global_position) < SHY and _scared <= 0.0:
		_scared = 2.4
		var away := signf(global_position.x - frog.global_position.x)
		_target = global_position + Vector2((away if away != 0.0 else 1.0) * 60.0, -48.0)
		_rest = 0.0
	var speed := SPEED
	if _scared > 0.0:
		_scared -= delta
		speed *= 2.2
		if _scared <= 0.0:
			_pick()
	if _rest > 0.0:
		# Settled: wings shut, opening slowly now and then.
		_rest -= delta
		_open = fmod(_t, 1.6) < 0.35
		if _rest <= 0.0:
			_pick()
		queue_redraw()
		return
	var to := _target - position
	if to.length() < 3.0:
		if _rest < 0.0:
			_rest = randf_range(1.8, 4.0)
			_vel = Vector2.ZERO
			return
		_pick()
	_vel = _vel.lerp(to.normalized() * speed, minf(1.0, delta * 3.0))
	position += (_vel + Vector2(0.0, sin(_t * 7.0) * 9.0)) * delta  # (and a little up and down as it flaps)
	_flap -= delta
	if _flap <= 0.0:
		_open = not _open
		_flap = 0.06 if _scared > 0.0 else randf_range(0.07, 0.12)
	queue_redraw()


func _draw() -> void:
	var frame: Rect2 = WINGS[colour % WINGS.size()][0 if _open else 1]
	draw_texture_rect_region(_art, Rect2(-frame.size * 0.5, frame.size), frame)


## What the camera sees, in the world.
func _view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := vp.get_canvas_transform().affine_inverse()
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
