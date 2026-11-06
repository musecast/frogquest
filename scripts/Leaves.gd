extends Node2D
## Leaves drifting down past the World Tree: a few at a time, swaying and turning over as they fall, mostly
## green, now and then a gold one. Only where the tree is and there's light to see them (not in the dark,
## not over the top); behind Froggy and the platforms. Up at the castle it's the white petals instead:
## there, as its frog says, the petals have fallen (lighter: slower, and swaying wider).

const ART := "res://assets/critters.png"
## (CritterArt's leaf0 and leaf1, a green leaf two ways up, and leaf_gold, at its pixel size)
const MOST := 9  # on screen at once, at the most
const EVERY := Vector2(0.7, 1.6)  # seconds between new ones
## Where they fall: across the tree (and a little either side), from the ground to the clouds, but not in
## the dark (heights 148-313: the dark's own).
const ACROSS := Vector2(2150.0, 3650.0)
const HEIGHTS := [Vector2(-60.0, 145.0), Vector2(318.0, 610.0)]
const GROUND := -472.0
const PETALS_FROM := 505.0  # (THE CASTLE: where the white petals have fallen)
## The white petals' colours, for the leaf's own three (its outline, its light and its shade): the white
## petals' white and lavender, the outline a soft purple.
const PETAL_OF := {"345551": Color8(105, 105, 178), "36e377": Color8(234, 242, 250), "2eb082": Color8(177, 177, 237)}

var _art: Texture2D
var _kinds := []
var _gold := Rect2()
var _petals: Array[Texture2D] = []  # (the leaf's two ways up, in the white petals' colours)
var _scale := 2.4
var _leaves: Array[Dictionary] = []
var _wait := 0.0


func _ready() -> void:
	_art = load(ART)
	var art: Script = load("res://scripts/CritterArt.gd")
	_kinds = [art.RECTS.leaf0, art.RECTS.leaf1]
	_gold = art.RECTS.leaf_gold
	_scale = art.PIXEL
	for frame in _kinds:
		_petals.append(_petal(frame))
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
			var petal := (GROUND - view.get_center().y) / 10.0 >= PETALS_FROM
			_leaves.append({
				"x0": x, "x": x, "y": view.position.y - 20.0, "t": 0.0, "phase": randf() * TAU,
				"fall": randf_range(16.0, 26.0) if petal else randf_range(22.0, 34.0), "sway": randf_range(1.2, 2.1),
				"wide": randf_range(14.0, 28.0) if petal else randf_range(10.0, 22.0),
				"gold": not petal and randf() < 0.18, "flip": randf() < 0.5, "petal": petal,
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
		var frame: Rect2 = _gold if leaf.gold else _kinds[0 if turn > 0.0 else 1]
		var size := frame.size * _scale
		var at := Vector2(roundf(leaf.x - size.x * 0.5), roundf(leaf.y - size.y * 0.5))
		var flip: bool = leaf.flip != (turn < -0.6)
		var rect := Rect2(at, size)
		if flip:
			rect = Rect2(at.x + size.x, at.y, -size.x, size.y)
		if leaf.petal:
			draw_texture_rect(_petals[0 if turn > 0.0 else 1], rect, false)
		else:
			draw_texture_rect_region(_art, rect, frame)


## What the camera sees, in the world.
func _view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := vp.get_canvas_transform().affine_inverse()
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)


## A white petal: the leaf's own shape, in the white petals' colours (PETAL_OF), at its pixel size.
func _petal(frame: Rect2) -> Texture2D:
	var img := _art.get_image().get_region(Rect2i(frame))
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				var to: Color = PETAL_OF.get(c.to_html(false), Color8(234, 242, 250))
				img.set_pixel(x, y, Color(to, c.a))
	return ImageTexture.create_from_image(img)
