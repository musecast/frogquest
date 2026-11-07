extends Node2D
## Leaves drifting down past the World Tree: a few at a time, swaying and turning over as they fall, mostly
## green, now and then a gold one. Only where the tree is and there's light to see them (not in the dark,
## not over the top); behind Froggy and the platforms. Up at the castle it's the white petals instead:
## there, as its frog says, the petals have fallen (lighter: slower, and swaying wider). Only once he's opened
## the way up, though (Main.way_open): before that, nothing falls in the castle. The petals fall in front of
## the castle's platforms (a layer of their own over them). Leaves and petals come to rest on the floor they
## fall onto, lying there a while before they slowly fade; Froggy landing by them, or jumping from by them,
## throws them up (they flutter down again), and flying right through falling ones sweeps them along.

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
const PETALS_ACROSS := Vector2(2150.0, 4300.0)  # (the castle's wider than the tree: out to its east wall)
const PETAL_Z := 1  # (the petals' layer: in front of the platforms (0), behind Froggy and the overlay (2))
const REST := Vector2(6.0, 12.0)  # (landed: how long one lies there before it starts to fade)
const FADE := 3.0  # (and how slowly it fades away)
const MOST_DOWN := 14  # (lying about at once, at the most: past that, the ones there longest go first)
const FLOOR_MASK := 1  # (the world's solid: what Froggy stands on)
const FROG_FEET := 11.0  # (his feet, below his middle)
const KICK_NEAR := Vector2(46.0, 24.0)  # (how near his feet a lying one is thrown up: across, and up or down)
const KICK_UP := Vector2(90.0, 200.0)  # (how hard up: by how hard he came down, or went up)
const KICK_SIDE := Vector2(25.0, 85.0)  # (and away from him)
const KICK_SLOW := 260.0  # (a throw dying away, px/s every second)
const BRUSH := 20.0  # (a falling one this near him as he flies by fast is swept along)
const SETTLE := 0.3  # (landed mid-turn: how long it takes to settle flat)
## The white petals' colours, for the leaf's own three (its outline, its light and its shade): the white
## petals' own, as they're drawn on the ledges (a white shine, icy white, the slate outline).
const PETAL_OF := {"345551": Color8(68, 75, 96), "36e377": Color8(254, 254, 254), "2eb082": Color8(232, 251, 250)}

var _art: Texture2D
var _kinds := []
var _gold := Rect2()
var _petals: Array[Texture2D] = []  # (the leaf's two ways up, in the white petals' colours)
var _scale := 2.4
var _leaves: Array[Dictionary] = []
var _wait := 0.0
var story: Node  # (Main: whether the castle's way is open yet, for its petals; and Froggy, who scatters them)
var _middles: Array[Vector2] = []  # (where each frame's leaf is in it: its pixels' middle, from the frame's; leaf0, leaf1, gold)
var _lows: Array[float] = []  # (and how far below that middle its lowest pixel's bottom is, drawn: what it lies on)
var _petal_layer: Node2D  # (drawn here, over the platforms: the petals, and whatever's lying on a floor (over its edge))
var _frog: CharacterBody2D
var _frog_on := true
var _frog_was := Vector2.ZERO  # (his velocity a step ago: as he lands, how hard he came down)


func _ready() -> void:
	_art = load(ART)
	var art: Script = load("res://scripts/CritterArt.gd")
	_kinds = [art.RECTS.leaf0, art.RECTS.leaf1]
	_gold = art.RECTS.leaf_gold
	_scale = art.PIXEL
	for frame in _kinds:
		_petals.append(_petal(frame))
	var art_img := _art.get_image()
	if art_img.is_compressed():
		art_img.decompress()
	for frame in [_kinds[0], _kinds[1], _gold]:
		_measure(art_img, frame)
	z_index = -1
	_petal_layer = Node2D.new()
	_petal_layer.name = "Petals"
	_petal_layer.z_as_relative = false
	_petal_layer.z_index = PETAL_Z
	_petal_layer.draw.connect(_draw_front)
	add_child(_petal_layer)


func _process(delta: float) -> void:
	var view := _view()
	var any := not _leaves.is_empty()
	_watch_froggy()
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for leaf in _leaves:
		if leaf.down:  # (lying on a floor)
			leaf.rest += delta
			continue
		leaf.t += delta
		var was := Vector2(leaf.x, leaf.y)
		leaf.vx = move_toward(leaf.vx, 0.0, KICK_SLOW * delta)
		leaf.vy = move_toward(leaf.vy, 0.0, KICK_SLOW * delta)
		leaf.x0 += leaf.vx * delta
		leaf.y += (leaf.fall + leaf.vy) * delta
		leaf.x = leaf.x0 + sin(leaf.t * leaf.sway + leaf.phase) * leaf.wide
		if space != null and leaf.fall + leaf.vy > 0.0:
			_land(leaf, was, space)
	_leaves = _leaves.filter(func(l: Dictionary) -> bool:
		if l.down:
			return l.rest < l.lies + FADE and absf(l.y - view.get_center().y) < view.size.y
		return l.y < view.end.y + 30.0 and l.t < 40.0)
	var lying := _leaves.filter(func(l: Dictionary) -> bool: return l.down)
	if lying.size() > MOST_DOWN:  # (too many about: the ones there longest go first)
		lying.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rest - a.lies > b.rest - b.lies)
		for i in lying.size() - MOST_DOWN:
			lying[i].rest = maxf(lying[i].rest, lying[i].lies)
	_wait -= delta
	if _wait <= 0.0:
		_wait = randf_range(EVERY.x, EVERY.y)
		if _leaves.filter(func(l: Dictionary) -> bool: return not l.down).size() < MOST and _falls_here(view):
			var petal := _petals_here(view)
			var across := PETALS_ACROSS if petal else ACROSS
			var x := randf_range(maxf(view.position.x, across.x), minf(view.end.x, across.y))
			_leaves.append({
				"x0": x, "x": x, "y": view.position.y - 20.0, "t": 0.0, "phase": randf() * TAU,
				"fall": randf_range(16.0, 26.0) if petal else randf_range(22.0, 34.0), "sway": randf_range(1.2, 2.1),
				"wide": randf_range(14.0, 28.0) if petal else randf_range(10.0, 22.0),
				"gold": not petal and randf() < 0.18, "flip": randf() < 0.5, "petal": petal,
				"vx": 0.0, "vy": 0.0, "down": false, "rest": 0.0, "lies": randf_range(REST.x, REST.y),
				"side": 1.0, "face_at": 1.0,
			})
	if any or not _leaves.is_empty():
		queue_redraw()
		_petal_layer.queue_redraw()


## A falling one reaching a floor (its top, from above, as it fell this step): there it comes to rest, lying
## on it. Not on Froggy: he'd carry it off.
func _land(leaf: Dictionary, was: Vector2, space: PhysicsDirectSpaceState2D) -> void:
	var spin := cos(leaf.t * leaf.sway + leaf.phase)
	var edge: float = _lows[2 if leaf.gold else (0 if spin > 0.0 else 1)]
	var ray := PhysicsRayQueryParameters2D.create(was + Vector2(0.0, edge), Vector2(leaf.x, leaf.y + edge), FLOOR_MASK,
		[_frog.get_rid()] if is_instance_valid(_frog) else [])
	ray.hit_from_inside = false
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y > -0.5:
		return
	leaf.down = true
	leaf.rest = 0.0
	leaf.vx = 0.0
	leaf.vy = 0.0
	leaf.side = 1.0 if spin > 0.0 else -1.0  # (lying on the side it came down on, settling flat: _place)
	leaf.face_at = absf(spin)
	leaf.x = hit.position.x
	leaf.y = hit.position.y - edge


## How far below a leaf's middle its edge is (it lies on that).
func _half_height() -> float:
	return _kinds[0].size.y * _scale * 0.5


## Froggy: landing, or jumping off, the ones lying by his feet thrown up; flying by fast, the falling ones
## he goes right through swept along.
func _watch_froggy() -> void:
	if not is_instance_valid(_frog):
		_frog = story.get_node_or_null("Player") as CharacterBody2D if story != null else null
		if _frog == null:
			return
	var on := _frog.is_on_floor()
	if on != _frog_on:  # (landed: how hard he came down; or off: how hard he went up)
		kick(_frog.global_position + Vector2(0.0, FROG_FEET), absf(_frog_was.y if on else _frog.velocity.y))
	_frog_on = on
	_frog_was = _frog.velocity
	if not on and _frog.velocity.length() > 150.0:
		for leaf in _leaves:
			if not leaf.down and Vector2(leaf.x, leaf.y).distance_to(_frog.global_position) < BRUSH:
				leaf.vx = clampf(_frog.velocity.x * 0.35, -120.0, 120.0)
				leaf.vy = clampf(_frog.velocity.y * 0.35, -140.0, 100.0)


## The ones lying near `feet` thrown up and away from him, by how hard (`hard`, px/s) he landed or jumped:
## the nearer, the higher. They flutter back down, and lie again where they land.
func kick(feet: Vector2, hard: float) -> void:
	var power := clampf(hard / 600.0, 0.3, 1.0)
	for leaf in _leaves:
		if not leaf.down:
			continue
		var off := Vector2(leaf.x, leaf.y) - feet
		if absf(off.x) > KICK_NEAR.x or absf(off.y) > KICK_NEAR.y:
			continue
		var near := 1.0 - absf(off.x) / KICK_NEAR.x
		leaf.down = false
		leaf.rest = 0.0
		leaf.phase = (0.0 if leaf.side > 0.0 else PI) - leaf.t * leaf.sway  # (turning on from flat, the side it lay)
		leaf.x0 = leaf.x  # (and its sway from where it lay)
		leaf.vy = -lerpf(KICK_UP.x, KICK_UP.y, power) * (0.55 + 0.45 * near)
		var away := signf(off.x) if off.x != 0.0 else (1.0 if randf() < 0.5 else -1.0)
		leaf.vx = away * randf_range(KICK_SIDE.x, KICK_SIDE.y) * power


## Whether leaves fall anywhere in what the camera sees (at the castle: its petals, once the way's open).
func _falls_here(view: Rect2) -> bool:
	var petal := _petals_here(view)
	if petal and not (story != null and bool(story.get("way_open"))):
		return false
	var across := PETALS_ACROSS if petal else ACROSS
	if view.end.x < across.x or view.position.x > across.y:
		return false
	var h := (GROUND - view.get_center().y) / 10.0
	for band in HEIGHTS:
		if h >= band.x and h <= band.y:
			return true
	return false


func _draw() -> void:
	for leaf in _leaves:
		if not leaf.petal and not leaf.down:
			_draw_one(self, leaf)


## (the petals, falling or lying, and the leaves lying on a floor: in front of the platforms, so a floor's
## top edge doesn't hide what's lying on it)
func _draw_front() -> void:
	for leaf in _leaves:
		if leaf.petal or leaf.down:
			_draw_one(_petal_layer, leaf)


func _draw_one(on: CanvasItem, leaf: Dictionary) -> void:
	var at := _place(leaf)
	var fade := Color(1.0, 1.0, 1.0, 1.0 - smoothstep(leaf.lies, leaf.lies + FADE, leaf.rest) if leaf.down else 1.0)
	if leaf.petal:
		on.draw_texture_rect(_petals[at.i], at.rect, false, fade)
	else:
		on.draw_texture_rect_region(_art, at.rect, at.frame, fade)


## Where a leaf's drawn, and which way round: turning over as it sways, narrowing to its edge at each end of
## its swing and widening again on its other side, so its side changes while it's edge-on, where nothing can
## jump; about its own middle (its pixels', not its frame's: they're not centred in it). Lying, it settles
## flat on the side it came down on.
func _place(leaf: Dictionary) -> Dictionary:
	var spin := cos(leaf.t * leaf.sway + leaf.phase)
	var side := 1.0 if spin > 0.0 else -1.0
	var face := absf(spin)  # (how much of it shows: 1 flat on, 0 edge-on)
	if leaf.down:
		side = leaf.side
		face = lerpf(leaf.face_at, 1.0, smoothstep(0.0, SETTLE, leaf.rest))
	var i := 0 if side > 0.0 else 1
	var frame: Rect2 = _gold if leaf.gold else _kinds[i]
	var middle: Vector2 = _middles[2 if leaf.gold else i] * _scale
	var mirror: bool = leaf.flip != (side < 0.0)
	var size := frame.size * _scale
	var w := maxf(size.x * face, 1.0)
	var x := roundf(leaf.x - middle.x * face * (-1.0 if mirror else 1.0))
	var y := roundf(leaf.y - size.y * 0.5 - middle.y)
	var rect := Rect2(x - w * 0.5, y, w, size.y)
	if mirror:
		rect = Rect2(x + w * 0.5, y, -w, size.y)
	return {"rect": rect, "frame": frame, "i": i}


## A frame's leaf: its pixels' middle (from the frame's own middle), and how far below that its lowest pixel's
## bottom is, both as drawn.
func _measure(img: Image, frame: Rect2) -> void:
	var sum := Vector2.ZERO
	var n := 0
	var low := 0
	for y in int(frame.size.y):
		for x in int(frame.size.x):
			if img.get_pixel(int(frame.position.x) + x, int(frame.position.y) + y).a > 0.0:
				sum += Vector2(x + 0.5, y + 0.5)
				n += 1
				low = maxi(low, y + 1)
	var middle := sum / float(n) if n > 0 else frame.size * 0.5
	_middles.append(middle - frame.size * 0.5)
	_lows.append((float(low) - middle.y) * _scale)


## Whether it's the castle the camera's at: the white petals, not leaves.
func _petals_here(view: Rect2) -> bool:
	return (GROUND - view.get_center().y) / 10.0 >= PETALS_FROM


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
				var to: Color = PETAL_OF.get(c.to_html(false), Color8(232, 251, 250))
				img.set_pixel(x, y, Color(to, c.a))
	return ImageTexture.create_from_image(img)
