extends Node2D
## Leaves drifting down past the World Tree: a few at a time, swaying and turning over as they fall, mostly
## green, now and then a gold one. Only where the tree is and there's light to see them (not in the dark,
## not over the top); behind Froggy and the platforms.

const ART := "res://assets/critters.png"
const KINDS := [Rect2(158, 0, 4, 5), Rect2(163, 0, 4, 5)]  # a green leaf, two ways up
const GOLD := Rect2(168, 0, 4, 5)
const SCALE := 2.0
const MOST := 9  # on screen at once, at the most
const EVERY := Vector2(0.7, 1.6)  # seconds between new ones
## Where they fall: across the tree (and a little either side), from the ground to the clouds, but not in
## the dark (heights 148-313: the dark's own).
const ACROSS := Vector2(2150.0, 3650.0)
const HEIGHTS := [Vector2(-60.0, 145.0), Vector2(318.0, 610.0)]
const GROUND := -472.0

var _art: Texture2D
var _leaves: Array[Dictionary] = []
var _wait := 0.0


func _ready() -> void:
	_art = load(ART)
	z_index = -1


func _process(delta: float) -> void:
	var view := _view()
	var any := not _leaves.is_empty()
	for leaf in _leaves:
		leaf.t += delta
		leaf.y += leaf.fall * delta
		leaf.x = leaf.x0 + sin(leaf.t * leaf.sway + leaf.phase) * leaf.wide
	_leaves = _leaves.filter(func(l: Dictionary) -> bool: return l.y < view.end.y + 30.0 and l.t < 40.0)
	_wait -= delta
	if _wait <= 0.0:
		_wait = randf_range(EVERY.x, EVERY.y)
		if _leaves.size() < MOST and _falls_here(view):
			var x := randf_range(maxf(view.position.x, ACROSS.x), minf(view.end.x, ACROSS.y))
			_leaves.append({
				"x0": x, "x": x, "y": view.position.y - 20.0, "t": 0.0, "phase": randf() * TAU,
				"fall": randf_range(22.0, 34.0), "sway": randf_range(1.2, 2.1), "wide": randf_range(10.0, 22.0),
				"gold": randf() < 0.18, "flip": randf() < 0.5,
			})
	if any or not _leaves.is_empty():
		queue_redraw()


## Whether leaves fall anywhere in what the camera sees.
func _falls_here(view: Rect2) -> bool:
	if view.end.x < ACROSS.x or view.position.x > ACROSS.y:
		return false
	var h := (GROUND - view.get_center().y) / 10.0
	for band in HEIGHTS:
		if h >= band.x and h <= band.y:
			return true
	return false


func _draw() -> void:
	for leaf in _leaves:
		# Turning over as it sways: one way up, then the other.
		var turn := cos(leaf.t * leaf.sway + leaf.phase)
		var frame: Rect2 = GOLD if leaf.gold else KINDS[0 if turn > 0.0 else 1]
		var size := frame.size * SCALE
		var at := Vector2(roundf(leaf.x - size.x * 0.5), roundf(leaf.y - size.y * 0.5))
		var flip: bool = leaf.flip != (turn < -0.6)
		var rect := Rect2(at, size)
		if flip:
			rect = Rect2(at.x + size.x, at.y, -size.x, size.y)
		draw_texture_rect_region(_art, rect, frame)


## What the camera sees, in the world.
func _view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := vp.get_canvas_transform().affine_inverse()
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
