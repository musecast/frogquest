extends Node2D
## Endless mode's sky, behind everything and following the camera. Its colours blend from zone to zone as
## he climbs (EndlessZones.sky_at), and each zone's world fades in and out with that zone's share of the
## sky, all of it alive, and built from the story's own pieces where it has them (its clouds and hills,
## Sky.gd's art, at its pixel):
## - MUSHROOM SWAMP: a sunny morning; the story's far hills with a skyline of giant mushrooms on them in
##   the haze; pastel ones on the story's near hills; two big ones framing it all; spores drifting up,
##   butterflies, the pond with its reeds and glow bugs.
## - THE TREETOPS: sunbeams through the leaves, motes in them; trunks, boughs and leaves in three rows;
##   clouds through the gaps; leaves fluttering down; butterflies; a bird now and then.
## - THE CLOUDS: the story's clouds in three rows on the wind, its sea of cloud below as he comes up into
##   them, flocks of birds, hot air balloons far off.
## - SUNSET SKY: the sun going down behind streaks of cloud, pink clouds, the sea of cloud lit pink, far
##   islands bobbing in the haze, birds going home, the first stars coming out overhead.
## - OUTER SPACE: the Muse Jukebox's starry sky (SparkleSky) in three rows, soft nebulas, the Earth below,
##   the planet and the moon, shooting stars, a comet now and then, a satellite blinking by.
## Depth: 0 stays put on the screen, 1 moves with the world. It's all drawn smooth, then all of it again
## in the story's sky's square pixels (endless_pixels.gdshader). Also the line at his best height, so he
## can see when he's about to beat it.

const FONT := "res://assets/fibberish.ttf"
const TEXEL := 2.4  # world px for each pixel of the sky (the story's sky's own: Sky.TEXEL)

var cam: Camera2D
var best_height := 0.0  # world units above the first lily pad (0: no best yet)
var _zones: Script
var _sparkle: Script
var _t := 0.0
var _half := Vector2(240.0, 350.0)
var _font: Font
var _sun: Texture2D
var _planet: Texture2D
var _earth: Texture2D
var _moon: Texture2D
var _cloud_art: Texture2D  # (the story's clouds: Sky.CLOUDS)
var _cloud_rects: Array = []
var _sea: Texture2D  # (the story's sea of cloud)
var _sea_fill := Color.WHITE
var _far_hills := {}  # (the story's hills: _outline)
var _near_hills := {}
var _stars: Array = []  # (space's, three rows, far to near: SparkleSky)
var _dusk: Array = []  # (the first stars, over the sunset)
var _pixels: Node2D  # (over all of it: the sky in the story's sky's own pixels, endless_pixels.gdshader)
static var _outlines := {}  # (the story's hills, traced once: art path -> _outline)


func _ready() -> void:
	z_index = -50
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_zones = load("res://scripts/EndlessZones.gd")
	_sparkle = load("res://scripts/SparkleSky.gd")
	_font = load(FONT)
	_sun = load("res://assets/endless/sun.png")
	_planet = load("res://assets/endless/planet.png")
	_earth = load("res://assets/endless/earth.png")
	_moon = load("res://assets/endless/moon.png")
	_cloud_art = load("res://assets/sky/clouds.png")
	_cloud_rects = load("res://scripts/Sky.gd").CLOUDS
	_sea = load("res://assets/sky/cloud_sea.png")
	var sea_img := _sea.get_image()
	if sea_img.is_compressed():
		sea_img.decompress()
	_sea_fill = sea_img.get_pixel(0, sea_img.get_height() - 1)
	for path in ["res://assets/sky/hills_far.png", "res://assets/sky/hills_near.png"]:
		if not _outlines.has(path):
			_outlines[path] = _outline(load(path))
	_far_hills = _outlines["res://assets/sky/hills_far.png"]
	_near_hills = _outlines["res://assets/sky/hills_near.png"]
	_stars = [_sparkle.make_stars(120, 11, 0.04), _sparkle.make_stars(60, 12, 0.14), _sparkle.make_stars(26, 13, 0.32)]
	_dusk = _sparkle.make_stars(46, 14, 0.12)
	# (its shapes drawn smooth, then all of it redrawn in square pixels TEXEL of the world's across, as the
	# story's sky is pixel art at that: just over the sky, under the platforms and him)
	_pixels = Node2D.new()
	_pixels.z_index = -49
	_pixels.z_as_relative = false
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/endless_pixels.gdshader")
	_pixels.material = mat
	_pixels.draw.connect(func() -> void:
		var half := get_viewport_rect().size / (cam.zoom if cam else Vector2.ONE) * 0.5 + Vector2(8.0, 8.0)
		_pixels.draw_rect(Rect2(-half, half * 2.0), Color.WHITE))
	add_child(_pixels)


func _process(delta: float) -> void:
	_t += delta
	if cam:
		global_position = cam.get_screen_center_position()
		(_pixels.material as ShaderMaterial).set_shader_parameter("cell", TEXEL * cam.zoom.x)
	queue_redraw()
	_pixels.queue_redraw()


## A cheap repeatable "random" 0..1 for scenery item i of a layer.
static func _h(i: int, salt: int) -> float:
	var n := int(i * 73856093) ^ int(salt * 19349663)
	n = (n ^ (n >> 13)) * 1274126177
	return float(abs(n) % 10000) / 10000.0


func _draw() -> void:
	if cam == null:
		return
	_half = get_viewport_rect().size / cam.zoom * 0.5
	var half := _half
	var height := -global_position.y
	var sky: Array = _zones.sky_at(height)
	draw_polygon(PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)]),
		PackedColorArray([sky[0], sky[0], sky[1], sky[1]]))
	var w: PackedFloat32Array = _zones.weights_at(height)
	if w[4] > 0.01:
		_space(w[4], half)
	if w[3] > 0.01:
		_sunset(w[3], half)
	if w[2] > 0.01:
		_clouds(w[2], half)
	if w[1] > 0.01:
		_treetops(w[1], half)
	if w[0] > 0.01 or global_position.y > -900.0:
		_swamp(maxf(w[0], 0.0), half)
	_best_line(half)


## Where a thing at world height y (and the given depth) is on the screen, from the middle.
func _y(world_y: float, depth: float) -> float:
	return (world_y - global_position.y) * depth


## On the sky's pixel grid (the screen's, from its corner), so the story's art lands pixel for pixel.
func _snap(p: Vector2) -> Vector2:
	return ((p + _half) / TEXEL).round() * TEXEL - _half


## A colour faded toward the air by `haze` (far things are paler), at the zone's share `a`.
static func _faded(col: Color, air: Color, haze: float, a: float) -> Color:
	var c := col.lerp(air, haze)
	c.a = a
	return c


# ── THE STORY'S PIECES ──────────────────────────────────────────────────────────────────────────

## One of the story's clouds (Sky.CLOUDS, i of them, smallest first), `k` (a whole number) times its size,
## its middle at `at`.
func _cloud(at: Vector2, i: int, k: float, tint: Color) -> void:
	var region: Rect2 = _cloud_rects[clampi(i, 0, _cloud_rects.size() - 1)]
	var size := region.size * TEXEL * k
	draw_texture_rect_region(_cloud_art, Rect2(_snap(at - size * 0.5), size), region, tint)


## A row upon row of the story's clouds, `depth` of the way to moving with the world: one in `odds` of
## the cells `cell` apart, from `sizes` of them, `k` times their size, on a wind of `wind` px a second,
## in `tint`; between world heights band.x and band.y (thinning out over 400 either side of them).
func _cloud_layer(salt: int, depth: float, cell: Vector2, odds: float, sizes: Array, k: float, wind: float,
		tint: Color, band: Vector2) -> void:
	if tint.a <= 0.01:
		return
	var cy := global_position.y * depth  # (the camera, in the layer's own space)
	var cols := int(ceil((_half.x * 2.0 + 800.0) / cell.x))
	var wrap := cols * cell.x
	var first := int(floor((cy - _half.y - cell.y * 2.0) / cell.y))
	var last := int(ceil((cy + _half.y + cell.y) / cell.y))
	for row in range(first, last + 1):
		var world_h := -(row + 0.5) * cell.y / depth
		var fade := clampf((world_h - band.x + 400.0) / 400.0, 0.0, 1.0) * clampf((band.y + 400.0 - world_h) / 400.0, 0.0, 1.0)
		if fade <= 0.0:
			continue
		for col in cols:
			var key := row * 131 + col
			if _h(key, salt) > odds:
				continue
			var i: int = sizes[int(_h(key, salt + 1) * sizes.size()) % sizes.size()]
			var x := fposmod(col * cell.x + _h(key, salt + 2) * cell.x * 0.7 + _t * wind, wrap) - wrap * 0.5
			var y := row * cell.y + _h(key, salt + 3) * cell.y * 0.6 - cy
			_cloud(Vector2(x, y), i, k, Color(tint, tint.a * fade))


## The story's hills as a silhouette: how far down each column of its art the top is, and the runs of its
## darker pixels (the bushes on the near ones), [x, y, length].
static func _outline(tex: Texture2D) -> Dictionary:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var tops := PackedInt32Array()
	tops.resize(w)
	var body := img.get_pixel(0, h - 1)
	for x in w:
		tops[x] = h
		for y in h:
			if img.get_pixel(x, y).a > 0.5:
				tops[x] = y
				break
	var runs := []  # (columns side by side with the same top, one rect each: [x, length, top])
	var start := 0
	for x in range(1, w + 1):
		if x == w or tops[x] != tops[start]:
			runs.append([start, x - start, tops[start]])
			start = x
	var dark := []
	for y in h:
		var run := -1
		for x in w + 1:
			var px := img.get_pixel(x, y) if x < w else Color(0, 0, 0, 0)
			var is_dark := px.a > 0.5 and px.get_luminance() < body.get_luminance() - 0.04
			if is_dark and run < 0:
				run = x
			elif not is_dark and run >= 0:
				dark.append([run, y, x - run])
				run = -1
	return {"w": w, "runs": runs, "dark": dark}


## The story's hills (an _outline) right across, the top of their art at `top`, in `body` with their bushes
## in `bush`, and `body` on down to the bottom of the screen.
func _draw_hills(o: Dictionary, top: float, body: Color, bush: Color, half: Vector2, shift := 0.0) -> void:
	if top > half.y or body.a <= 0.01:
		return
	var w: int = o.w
	var period := w * TEXEL
	var x := floorf((-half.x - shift) / period) * period + shift
	top = _snap(Vector2(0.0, top)).y
	while x < half.x:
		for r in o.runs:
			var cx: float = x + r[0] * TEXEL
			var wide: float = r[1] * TEXEL
			if cx + wide < -half.x or cx > half.x:
				continue
			var ty: float = top + r[2] * TEXEL
			draw_rect(Rect2(cx, ty, wide, half.y - ty + TEXEL), body)
		if bush.a > 0.01:
			for r in o.dark:
				var rx: float = x + r[0] * TEXEL
				if rx > half.x or rx + r[2] * TEXEL < -half.x:
					continue
				draw_rect(Rect2(rx, top + r[1] * TEXEL, r[2] * TEXEL, TEXEL), bush)
		x += period


## The story's sea of cloud (from the top of its tree) right across, its top at `top`, and on down.
func _draw_sea(top: float, tint: Color, half: Vector2) -> void:
	if top > half.y or tint.a <= 0.01:
		return
	var size := Vector2(_sea.get_width(), _sea.get_height()) * TEXEL
	var x := -half.x - size.x + fposmod(_t * 4.0, size.x)  # (rolling slowly along)
	top = _snap(Vector2(0.0, top)).y
	while x < half.x:
		draw_texture_rect(_sea, Rect2(x, top, size.x, size.y), false, tint)
		x += size.x
	if top + size.y < half.y:
		draw_rect(Rect2(-half.x, top + size.y - 1.0, half.x * 2.0, half.y - top - size.y + 2.0), _sea_fill * tint)


# ── MUSHROOM SWAMP ──────────────────────────────────────────────────────────────────────────────
# A sunny morning by the pond: giant mushrooms in soft colours (some with a door and a lit window), paler
# the further off they are, under a warm sun. Pastel, domed and hazy, so none of it is taken for a platform;
# their stems a lilac cream, not the platforms' stalks' cream.
const CAPS := [Color(0.95, 0.56, 0.56), Color(0.98, 0.72, 0.50), Color(0.73, 0.63, 0.93), Color(0.99, 0.84, 0.50), Color(0.93, 0.52, 0.71)]
const STEM := Color(0.89, 0.86, 0.94)  # (a lilac white: never the platforms' cream stalks)
const SPOT := Color(1.0, 0.98, 0.92)
const DOOR := Color(0.55, 0.36, 0.25)
const WINDOW := Color(1.0, 0.88, 0.50)
const SKYLINE := Color(0.64, 0.66, 0.86)  # (the far giants: one hazy lilac)
const MEADOW := [Color(0.60, 0.80, 0.62), Color(0.46, 0.72, 0.48)]
const WINGS := [Color(1.0, 0.72, 0.82), Color(1.0, 0.92, 0.52), Color(0.70, 0.84, 1.0), Color(1.0, 1.0, 0.96)]


func _swamp(a: float, half: Vector2) -> void:
	var sky: Array = _zones.sky_at(-global_position.y)
	var air: Color = sky[0].lerp(sky[1], 0.6)  # (what far things fade toward)
	# The sun, its glow and its beams, and the story's clouds drifting high over it all.
	var sun := Vector2(half.x * 0.42, -half.y * 0.55 + _y(-500.0, 0.05))
	for glow in [[100.0, 0.07], [68.0, 0.12], [44.0, 0.2], [26.0, 1.0]]:
		draw_circle(sun, glow[0], Color(1.0, 0.94, 0.70, glow[1] * a))
	_beams(sun, Vector2(-0.45, 1.0), a * 0.8, Color(1.0, 0.96, 0.78), half)
	_cloud_layer(21, 0.05, Vector2(170.0, 110.0), 0.42, [0, 1, 2, 3, 4, 5, 6], 1.0, 3.0, Color(1, 1, 1, 0.7 * a), Vector2(-2000.0, 2200.0))
	_cloud_layer(22, 0.1, Vector2(270.0, 170.0), 0.32, [6, 7, 8, 9, 10, 11], 1.0, 6.0, Color(1, 1, 1, 0.85 * a), Vector2(-2000.0, 2200.0))
	# Far off: a skyline of giant mushrooms, standing on the story's far hills.
	var far := _y(1100.0, 0.05)
	_giants(0, far, air, a, half)
	_draw_hills(_far_hills, far - 20.0, _faded(Color(0.49, 0.59, 0.70), air, 0.45, a), Color(0, 0, 0, 0), half)
	_mist(far + 10.0, 90.0, air, 0.55 * a, half)
	# Nearer: pastel giants on the story's near hills (their bushes and all).
	var mid := _y(560.0, 0.15)
	_giants(1, mid, air, a, half)
	var hill: Color = _faded(Color(0.37, 0.57, 0.52), air, 0.3, a)
	_draw_hills(_near_hills, mid - 26.0, hill, _faded(Color(0.30, 0.48, 0.44), air, 0.3, a), half, 90.0)
	_mist(mid + 10.0, 110.0, air, 0.45 * a, half)
	# Nearer still: two big ones framing it, little ones round their feet, on a meadow.
	var near := _y(300.0, 0.32)
	_giants(2, near, air, a, half)
	if near - 40.0 < half.y:
		var green := _faded(MEADOW[0], air, 0.12, a)
		for i in range(-10, 11):
			var r := 40.0 + _h(i, 15) * 28.0
			draw_circle(Vector2(i * 64.0 + _h(i, 16) * 26.0, near + r * 0.62), r, green)
		draw_rect(Rect2(-half.x, near + 20.0, half.x * 2.0, maxf(0.0, half.y - near)), green)
	_spores(a, half)
	_butterflies(a, half, Vector2(80.0, 1300.0), 5)
	# Reeds, cattails, grass and flowers along the bank, nearer.
	var reed := Color(0.32, 0.58, 0.32, a)
	var head := Color(0.58, 0.38, 0.23, a)
	var bank := _y(10.0, 0.7)
	for i in range(-20, 21):
		var x := i * 26.0 + _h(i, 4) * 14.0
		var tall := 40.0 + _h(i, 5) * 90.0
		var sway := sin(_t * 1.3 + i) * 2.0
		draw_line(Vector2(x, bank), Vector2(x + sway, bank - tall), reed, 2.0)
		if _h(i, 6) > 0.45:
			draw_rect(Rect2(x + sway - 2.0, bank - tall - 2.0, 4.0, 11.0), head)
	if bank - 30.0 < half.y:
		var grass := Color(0.42, 0.72, 0.38, a)
		var petals := [Color(1.0, 0.68, 0.78, a), Color(1.0, 0.90, 0.45, a), Color(1.0, 1.0, 0.96, a)]
		for i in range(-30, 31):
			var x := i * 17.0 + _h(i, 7) * 10.0
			for blade in 3:
				draw_line(Vector2(x + blade * 3.0, bank), Vector2(x + blade * 3.0 + (blade - 1) * 3.0, bank - 8.0 - _h(i + blade, 8) * 8.0), grass, 2.0)
			if _h(i, 9) > 0.6:
				var flower := Vector2(x + 4.0, bank - 12.0 - _h(i, 10) * 10.0)
				draw_line(Vector2(x + 4.0, bank), flower, grass, 1.0)
				draw_circle(flower, 2.5, petals[i % petals.size()])
	# The pond, right under the first lily pad, glinting.
	var water_top := _y(5.0, 1.0)
	if water_top < half.y:
		draw_rect(Rect2(-half.x, water_top, half.x * 2.0, half.y - water_top + 4.0), Color(0.22, 0.55, 0.70, 1.0))
		draw_rect(Rect2(-half.x, water_top, half.x * 2.0, 3.0), Color(0.72, 0.92, 0.97, 1.0))  # (the bright edge of the water)
		for i in 10:  # (glints, twinkling)
			var glint := Vector2((_h(i, 70) - 0.5) * 1.9 * half.x, water_top + 10.0 + _h(i, 71) * 60.0)
			if sin(_t * 2.5 + i * 1.7) > 0.6:
				draw_rect(Rect2(glint, Vector2(3, 1)), Color(1.0, 1.0, 1.0, 0.8))
		for k in 6:
			var wy := water_top + 6.0 + k * 9.0
			var shift := fmod(_t * (10.0 + k * 3.0), 40.0)
			for i in range(-int(half.x / 40.0) - 2, int(half.x / 40.0) + 2):
				draw_rect(Rect2(i * 40.0 + shift + k * 13.0, wy, 14.0, 2.0), Color(0.80, 0.95, 0.97, 0.55 - k * 0.07))
	_glow_bugs(a, half)


## A row of giant mushrooms standing at `ground`: 0 the far skyline (hazy lilac shapes), 1 the pastel ones
## (gills, spots, a door here and there), 2 the two big ones framing it all, with little ones at their feet.
func _giants(row: int, ground: float, air: Color, a: float, half: Vector2) -> void:
	if ground - 700.0 > half.y:
		return
	match row:
		0:
			var col := _faded(SKYLINE, air, 0.42, a)
			var stem := _faded(SKYLINE.lightened(0.12), air, 0.42, a)
			for i in range(-12, 13):
				var x := i * 58.0 + (_h(i, 1) - 0.5) * 34.0
				if absf(x) > half.x + 80.0:
					continue
				var wide := 34.0 + _h(i, 3) * 60.0
				var tall := wide * (1.0 + _h(i, 2) * 1.6)
				# (their feet well down in the hills, wherever the hills dip)
				_giant(x, ground + 80.0, tall + 80.0, wide, int(_h(i, 4) * 3.0), (_h(i, 5) - 0.5) * 20.0, col, stem, 0.0, i)
		1:
			for i in range(-6, 7):
				var x := i * 150.0 + (_h(i, 21) - 0.5) * 80.0
				if absf(x) > half.x + 120.0:
					continue
				var wide := 62.0 + _h(i, 23) * 70.0
				var cap: Color = CAPS[int(_h(i, 24) * CAPS.size()) % CAPS.size()]
				var tall := wide * (0.9 + _h(i, 22) * 1.0)  # (stout: a stem no more than twice its cap)
				_giant(x, ground + 100.0, tall + 100.0, wide, int(_h(i, 25) * 3.0), (_h(i, 26) - 0.5) * 50.0,
					_faded(cap, air, 0.34, a), _faded(STEM, air, 0.34, a), 0.6, i + 40)
		2:
			for side in [-1.0, 1.0]:
				var i := 90 if side < 0.0 else 91
				var wide := 176.0 + _h(i, 33) * 50.0
				var x: float = side * (half.x - wide * 0.12)
				var cap: Color = CAPS[int(_h(i, 34) * CAPS.size()) % CAPS.size()]
				var tall := wide * (1.6 + _h(i, 32) * 0.6)
				_giant(x, ground, tall, wide, 0, -side * (30.0 + _h(i, 36) * 40.0), _faded(cap, air, 0.2, a), _faded(STEM, air, 0.2, a), 1.0, i)
				for j in 4:  # (little ones round its foot)
					var lx: float = x - side * (40.0 + j * 26.0 + _h(i * 7 + j, 37) * 14.0)
					var little: Color = CAPS[(j + i) % CAPS.size()]
					_giant(lx, ground + 6.0, 14.0 + _h(i * 7 + j, 38) * 22.0, 16.0 + _h(i * 7 + j, 39) * 16.0, j % 2, 0.0,
						_faded(little, air, 0.16, a), _faded(STEM, air, 0.16, a), 0.6, i * 7 + j)


## One giant mushroom: its foot at (x, foot), its stem `tall` and leaning over `bend` by the top, its cap
## `wide`, `shape` 0 a dome, 1 a bell, 2 flat; `detail` 0 (a far shape) to 1 (gills, a skirt, a shine,
## spots, and on the biggest a door and a lit window).
func _giant(x: float, foot: float, tall: float, wide: float, shape: int, bend: float, cap: Color, stem: Color, detail: float, i: int) -> void:
	var sw := maxf(TEXEL * 2.0, wide * (0.17 if shape == 2 else 0.21))
	var top := foot - tall
	var shade := Color(stem.darkened(0.16), stem.a)
	# The stem, in one go: leaning as it goes up, flaring at its foot (its edges at ten heights).
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var crease := PackedVector2Array()
	for k in 11:
		var u := k / 10.0
		var w := sw * (1.0 + 0.5 * pow(1.0 - u, 3.0))
		var cx := x + bend * (1.0 - cos(u * PI * 0.5))
		var y := foot + TEXEL * 2.0 - (tall + TEXEL * 2.0) * u
		left.append(Vector2(cx - w * 0.5, y))
		right.append(Vector2(cx + w * 0.5, y))
		crease.append(Vector2(cx + w * 0.2, y))
	var outline := left.duplicate()
	var shaded := crease.duplicate()
	for k in range(10, -1, -1):
		outline.append(right[k])
		shaded.append(right[k])
	draw_colored_polygon(outline, stem)
	if detail > 0.0:
		draw_colored_polygon(shaded, shade)
	var head := Vector2(x + bend, top)
	var cap_h: float = wide * [0.46, 0.66, 0.28][shape]
	if detail >= 0.5:  # (its skirt, a little way under the cap)
		var skirt := top + minf(tall * 0.2, 26.0)
		draw_rect(Rect2(head.x - sw * 0.75, skirt, sw * 1.5, TEXEL * 2.0), Color(stem.lightened(0.08), stem.a))
		draw_rect(Rect2(head.x - sw * 0.75, skirt + TEXEL * 2.0, sw * 1.5, TEXEL), shade)
	if detail > 0.0:  # (the gills under the cap)
		_dome(head + Vector2(0.0, TEXEL * 1.5), wide * 0.84, cap_h * 0.14, Color(cap.darkened(0.42).lerp(stem, 0.35), cap.a), true)
	_dome(head - Vector2(0.0, cap_h), wide, cap_h, cap)
	if shape == 1:  # (a bell's flared rim)
		draw_rect(Rect2(head.x - wide * 0.53, top - TEXEL * 2.0, wide * 1.06, TEXEL * 2.0), cap)
	if detail <= 0.0:
		return
	_dome(head - Vector2(wide * 0.16, cap_h * 0.92), wide * 0.36, cap_h * 0.22, Color(cap.lightened(0.32), cap.a))  # (a shine)
	for s in 2 + int(detail * 3.0):  # (spots)
		var sx := (_h(i * 5 + s, 12) - 0.5) * wide * 0.66
		var lift := (1.0 - pow(absf(sx) / (wide * 0.5), 2.0)) * 0.75
		var spot := head + Vector2(sx, -cap_h * (0.22 + _h(i * 5 + s, 13) * lift))
		draw_circle(spot, maxf(TEXEL * 1.2, wide * (0.035 + _h(i * 5 + s, 14) * 0.035)), Color(SPOT, cap.a * 0.95))
	if detail >= 1.0 and sw >= 30.0:  # (a front door, and a window lit inside)
		var door_w := roundf(sw * 0.36)
		var sill := foot - 8.0
		var dx := x + bend * 0.08
		draw_rect(Rect2(dx - door_w * 0.5, sill - door_w * 1.2, door_w, door_w * 1.2), Color(DOOR, cap.a))
		draw_circle(Vector2(dx, sill - door_w * 1.2), door_w * 0.5, Color(DOOR, cap.a))
		var lamp := Vector2(dx + bend * 0.2 - sw * 0.12, sill - door_w * 3.0)
		draw_circle(lamp, maxf(3.0, sw * 0.12), Color(WINDOW, cap.a * (0.85 + 0.15 * sin(_t * 2.0 + i))))


## A dome `w` across and `h` tall, its top middle at `top_mid` (upside down, its flat side up).
func _dome(top_mid: Vector2, w: float, h: float, col: Color, under := false) -> void:
	var pts := PackedVector2Array()
	for k in 17:
		var ang := PI + PI * k / 16.0
		var dy := sin(ang) * h + h
		pts.append(top_mid + Vector2(cos(ang) * w * 0.5, (h - dy) if under else dy))
	draw_colored_polygon(pts, col)


## Morning mist lying over a row's feet: thickest at `low`, gone `tall` above it.
func _mist(low: float, tall: float, air: Color, a: float, half: Vector2) -> void:
	if low - tall > half.y or a <= 0.01:
		return
	var thick := Color(air, a)
	var thin := Color(air, 0.0)
	draw_polygon(PackedVector2Array([Vector2(-half.x, low - tall), Vector2(half.x, low - tall), Vector2(half.x, low), Vector2(-half.x, low)]),
		PackedColorArray([thin, thin, thick, thick]))
	if low < half.y:
		draw_rect(Rect2(-half.x, low, half.x * 2.0, minf(30.0, half.y - low)), Color(air, a * 0.6))


## Spores drifting up through the swamp, glinting, out in the world.
func _spores(a: float, half: Vector2) -> void:
	var row_h := 80.0
	var first := int(floor((global_position.y - half.y - 160.0) / row_h))
	var last := int(floor((global_position.y + half.y + 20.0) / row_h))
	for row in range(first, last + 1):
		if row * row_h > 40.0 or row * row_h < -1500.0:
			continue
		for j in 2:
			var k := row * 2 + j
			var p := fposmod(_t * (0.05 + _h(k, 81) * 0.04) + _h(k, 82), 1.0)
			var at := Vector2((_h(k, 83) - 0.5) * 1.9 * half.x + sin(_t * 0.9 + k) * 10.0, _y(row * row_h - p * 150.0, 0.9))
			draw_rect(Rect2(at, Vector2(TEXEL, TEXEL)), Color(1.0, 0.98, 0.82, sin(p * PI) * 0.85 * a))


## Butterflies out in the world between heights band.x and band.y, fluttering about.
func _butterflies(a: float, half: Vector2, band: Vector2, count: int) -> void:
	for i in count:
		var home := Vector2((_h(i, 91) - 0.5) * 1.5 * half.x, -(band.x + (band.y - band.x) * (i + _h(i, 92)) / count))
		var at := home + Vector2(sin(_t * 0.5 + i * 2.0) * 70.0 + sin(_t * 1.7 + i) * 12.0, sin(_t * 0.8 + i * 3.0) * 34.0)
		at = Vector2(at.x, _y(at.y, 1.0))
		if absf(at.y) > half.y + 10.0:
			continue
		var col: Color = WINGS[i % WINGS.size()]
		var open := sin(_t * 16.0 + i * 1.3) > -0.2
		var wing := Vector2(TEXEL * 2.0, TEXEL * 2.0) if open else Vector2(TEXEL, TEXEL * 2.0)
		draw_rect(Rect2(at - Vector2(wing.x + TEXEL * 0.5, TEXEL * 1.5), wing), Color(col, a))
		draw_rect(Rect2(at + Vector2(TEXEL * 0.5, -TEXEL * 1.5), wing), Color(col, a))
		draw_rect(Rect2(at - Vector2(TEXEL * 0.5, TEXEL), Vector2(TEXEL, TEXEL * 2.5)), Color(0.25, 0.2, 0.25, a))


## Glow bugs out in the world, not on the screen: each keeps to its own spot as he climbs past (they
## used to ride along with the camera), wandering a little and pulsing. Some are a touch further back.
func _glow_bugs(a: float, half: Vector2) -> void:
	var row_h := 70.0
	for layer in 2:
		var depth := 0.75 if layer == 0 else 1.0
		var first := int(floor((global_position.y - half.y / depth - 20.0) / row_h))
		var last := int(floor((global_position.y + half.y / depth + 20.0) / row_h))
		for row in range(first, last + 1):
			if row * row_h > 0.0 or row * row_h < -1600.0:  # (over the pond and up through the swamp)
				continue
			var k := row * 2 + layer
			var phase := _h(k, 51) * TAU
			var home := Vector2((_h(k, 50) - 0.5) * 1.9 * half.x, _y(row * row_h + row_h * _h(k, 52), depth))
			var p := home + Vector2(sin(_t * 0.6 + phase) * 14.0, cos(_t * 0.45 + phase) * 10.0)
			var glow := 0.5 + 0.5 * sin(_t * 3.0 + phase)
			draw_circle(p, 6.0, Color(1.0, 0.95, 0.5, 0.18 * glow * a))
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.93, 0.45, (0.5 + 0.5 * glow) * a))


## Sunbeams from `from`, fanning out along `way`, slowly swaying and breathing.
func _beams(from: Vector2, way: Vector2, a: float, col: Color, half: Vector2) -> void:
	var reach := half.length() * 2.6
	var base := way.angle()
	for i in 4:
		var ang := base + (i - 1.5) * 0.17 + sin(_t * 0.12 + i * 1.7) * 0.04
		var spread := 0.035 + _h(i, 61) * 0.03
		var pulse := 0.6 + 0.4 * sin(_t * 0.35 + i * 2.3)
		draw_colored_polygon(PackedVector2Array([from, from + Vector2.from_angle(ang - spread) * reach,
			from + Vector2.from_angle(ang + spread) * reach]), Color(col, 0.07 * pulse * a))


# ── TREETOPS ────────────────────────────────────────────────────────────────────────────────────
# Sunlit, not a dark wood: warm bark and soft leaves, paler further off so the leafy platforms stand out
# in front; the sky through the gaps, sunbeams slanting in.
const BARK := Color(0.52, 0.39, 0.28)
const LEAVES := [Color(0.36, 0.58, 0.32), Color(0.48, 0.72, 0.40), Color(0.66, 0.84, 0.50)]  # (shadow, leaf, sunlit)


func _treetops(a: float, half: Vector2) -> void:
	var sky: Array = _zones.sky_at(-global_position.y)
	var air: Color = sky[0].lerp(sky[1], 0.45)
	_cloud_layer(31, 0.05, Vector2(170.0, 120.0), 0.45, [0, 1, 2, 3, 4, 5, 6, 7], 1.0, 3.0, Color(1, 1, 1, 0.65 * a), Vector2(900.0, 3500.0))
	_trees(0, 0.12, air, a, half)
	_beams(Vector2(half.x * 0.9, -half.y * 1.15), Vector2(-0.5, 1.0), a, Color(1.0, 0.97, 0.72), half)
	_trees(1, 0.3, air, a, half)
	_motes(a, half)
	_trees(2, 0.62, air, a, half)
	_falling_leaves(a, half)
	_butterflies(a, half, Vector2(1300.0, 3100.0), 4)
	_flock(a, half, 17.0, 1, -0.3, Color(0.22, 0.30, 0.22, 0.85 * a), 11)


## A row of trees, `depth` of the way to moving with the world: 0 far and pale, 1 nearer (bark and
## boughs), 2 one big trunk up a side, its leaves near enough to sway.
func _trees(row: int, depth: float, air: Color, a: float, half: Vector2) -> void:
	var haze: float = [0.55, 0.22, 0.04][row]
	var spacing: float = [150.0, 240.0, 0.0][row]
	var xs: Array = []
	if row == 2:
		xs = [-(half.x + 6.0)]
	else:
		for i in range(-6, 7):
			var x := i * spacing + _h(i, 10 + row) * spacing * 0.5
			if absf(x) < half.x + 120.0:
				xs.append(x)
	var bark := _faded(BARK.lightened(0.2 if row == 0 else 0.0).darkened(0.12 if row == 2 else 0.0), air, haze, a)
	var groove := Color(bark.darkened(0.25), bark.a)
	var greens: Array = []
	for c in LEAVES:
		greens.append(_faded(c, air, haze, a))
	for n in xs.size():
		var x: float = xs[n]
		var tw: float = [16.0 + _h(n, 12) * 12.0, 26.0 + _h(n, 13) * 16.0, 70.0][row]
		draw_rect(Rect2(x - tw * 0.5, -half.y, tw, half.y * 2.0), bark)
		# Bark: grooves up it, moving with it.
		var step := 160.0
		var off := fposmod(-global_position.y * depth, step)
		if row > 0:
			var g := -2
			while g * step + off - half.y < half.y + step:
				var gy := g * step + off - half.y
				var gx := x - tw * 0.3 + _h(g + n * 7, 14) * tw * 0.5
				draw_rect(Rect2(gx, gy, TEXEL, 40.0 + _h(g + n * 7, 15) * 50.0), groove)
				if _h(g + n * 7, 16) > 0.6:
					draw_circle(Vector2(x + (_h(g + n * 7, 17) - 0.5) * tw * 0.4, gy + 80.0), tw * 0.12, groove)
				g += 1
		# Boughs, out to one side or the other, and their leaves.
		var bough_step: float = [190.0, 230.0, 300.0][row]
		var boff := fposmod(-global_position.y * depth + _h(n, 18) * bough_step, bough_step)
		var j := -2
		while j * bough_step + boff - half.y < half.y + bough_step * 1.5:
			var by := j * bough_step + boff - half.y
			var key := j - int(floor(-global_position.y * depth / bough_step)) + n * 31
			var side := -1.0 if (key % 2 == 0) else 1.0
			if row == 2:
				side = 1.0
			var reach: float = [34.0, 60.0, 120.0][row] * (0.7 + _h(key, 19) * 0.6)
			var from := Vector2(x + side * tw * 0.4, by + 30.0)
			var to := from + Vector2(side * reach, -reach * 0.45)
			if row > 0:
				draw_line(from, to, bark, [0.0, 7.0, 12.0][row])
			var sway: float = sin(_t * (0.7 + row * 0.2) + key) * [0.0, 1.5, 4.0][row]
			_leaf_clump(to + Vector2(sway, -4.0), [26.0, 34.0, 52.0][row] * (0.8 + _h(key, 20) * 0.4), greens, key)
			j += 1


## A clump of leaves: shadow under it, the leaves, the sun on top.
func _leaf_clump(at: Vector2, r: float, greens: Array, key: int) -> void:
	for layer in 3:
		var lift: float = [0.18, 0.0, -0.22][layer] * r
		var scale: float = [1.0, 0.9, 0.5][layer]
		for b in 5:
			var ang := TAU * b / 5.0 + _h(key * 5 + b, 22)
			var spot := at + Vector2(cos(ang) * r * 0.55 - (r * 0.18 if layer == 2 else 0.0), sin(ang) * r * 0.32 + lift)
			draw_circle(spot, r * 0.5 * scale * (0.8 + _h(key * 5 + b, 23) * 0.4), greens[layer])


## Motes of dust in the sunbeams, drifting and glinting.
func _motes(a: float, half: Vector2) -> void:
	for i in 26:
		var p := fposmod(_t * (0.012 + _h(i, 71) * 0.01) + _h(i, 72), 1.0)
		var at := Vector2((_h(i, 73) - 0.3) * half.x * 1.6 + sin(_t * 0.4 + i) * 16.0, (p - 0.5) * half.y * 2.2)
		var glint := 0.5 + 0.5 * sin(_t * 2.2 + i * 1.9)
		draw_rect(Rect2(at, Vector2(TEXEL, TEXEL)), Color(1.0, 0.98, 0.8, glint * 0.6 * a * sin(p * PI)))


## Leaves fluttering down, turning as they go.
func _falling_leaves(a: float, half: Vector2) -> void:
	for i in 16:
		var fx := sin(_t * 0.5 + i * 2.1) * half.x * 0.95 + sin(_t * 2.4 + i) * 7.0
		var fy := fposmod(_t * (22.0 + i * 3.0) + i * 97.0, half.y * 2.0 + 40.0) - half.y - 20.0
		var col := Color(0.55, 0.78, 0.32, 0.85 * a) if i % 3 else Color(0.88, 0.70, 0.28, 0.85 * a)
		var turn := sin(_t * 3.0 + i * 1.7)
		var size := Vector2(TEXEL * 2.0, TEXEL) if turn > 0.3 else (Vector2(TEXEL, TEXEL * 2.0) if turn < -0.3 else Vector2(TEXEL, TEXEL))
		draw_rect(Rect2(Vector2(fx, fy), size), col)


## Birds crossing the sky now and then: `count` of them (a V of them, more than one), every `every`
## seconds, `y` up the screen (-1 top, 1 bottom).
func _flock(a: float, half: Vector2, every: float, count: int, y: float, col: Color, salt: int) -> void:
	var lap := floorf(_t / every)
	var p := fposmod(_t, every) / every
	var cross := 0.75  # (of the lap, flying across; the rest, gone)
	if p > cross:
		return
	var k := p / cross
	var left := _h(int(lap), salt) < 0.5
	var lead := Vector2(lerpf(-half.x - 60.0, half.x + 60.0, k if left else 1.0 - k), half.y * (y + (_h(int(lap), salt + 1) - 0.5) * 0.4))
	for b in count:
		var row := int((b + 1) / 2.0)
		var at := lead + Vector2((-1.0 if left else 1.0) * row * 16.0, row * 9.0 * (1.0 if b % 2 else -1.0) + sin(_t * 2.0 + b) * 2.0)
		var flap := 4.0 if fmod(_t * 6.0 + b * 0.7, 2.0) < 1.0 else -2.0
		draw_line(at + Vector2(-7.0, -flap), at, col, 2.0)
		draw_line(at, at + Vector2(7.0, -flap), col, 2.0)


# ── CLOUDS ──────────────────────────────────────────────────────────────────────────────────────
# Up among the story's own clouds: three rows of them on the wind (a touch blue and see-through, so the
# white cloud platforms stand out in front), its sea of cloud below him as he comes up into them.
func _clouds(a: float, half: Vector2) -> void:
	var sun := Vector2(half.x * 0.55, -half.y * 0.72 + _y(-4200.0, 0.03))
	for glow in [[150.0, 0.05], [96.0, 0.08], [60.0, 0.13], [30.0, 1.0]]:
		draw_circle(sun, glow[0], Color(1.0, 1.0, 0.92, glow[1] * a))
	_cloud_layer(41, 0.05, Vector2(150.0, 100.0), 0.5, [0, 1, 2, 3, 4, 5, 6, 7], 1.0, 3.0, Color(0.93, 0.96, 1.0, 0.6 * a), Vector2(2900.0, 6000.0))
	_draw_sea(_y(-3060.0, 0.3), Color(1, 1, 1, a), half)
	_balloons(a, half)
	_cloud_layer(42, 0.15, Vector2(230.0, 150.0), 0.45, [5, 6, 7, 8, 9, 10, 11, 12], 1.0, 7.0, Color(0.92, 0.95, 1.0, 0.75 * a), Vector2(2900.0, 6000.0))
	_flock(a, half, 13.0, 5, -0.35, Color(0.20, 0.28, 0.42, 0.8 * a), 41)
	_flock(a, half, 9.0, 1, 0.1, Color(0.20, 0.28, 0.42, 0.7 * a), 47)
	_cloud_layer(43, 0.36, Vector2(460.0, 300.0), 0.38, [11, 12, 13, 14, 15, 16], 2.0, 12.0, Color(0.9, 0.94, 1.0, 0.55 * a), Vector2(2900.0, 6000.0))


## Hot air balloons far off, drifting on the wind and bobbing.
func _balloons(a: float, half: Vector2) -> void:
	var colours := [[Color(0.95, 0.45, 0.42), Color(1.0, 0.86, 0.5)], [Color(0.45, 0.62, 0.95), Color(0.98, 0.96, 0.9)],
		[Color(0.70, 0.52, 0.90), Color(0.65, 0.90, 0.75)]]
	for i in 3:
		var depth := 0.06 + i * 0.03
		var y := _y(-(3600.0 + i * 900.0), depth)
		var wrap := half.x * 2.0 + 160.0
		var x := fposmod(_t * (3.0 + i * 1.5) + _h(i, 101) * wrap, wrap) - wrap * 0.5
		var at := Vector2(x, y + sin(_t * 0.7 + i * 2.0) * 5.0)
		if absf(at.y) > half.y + 40.0:
			continue
		var r := 13.0 - i * 2.0
		var pair: Array = colours[i]
		var haze := 0.25 + (2 - i) * 0.1
		var c0: Color = Color(pair[0].lerp(Color(0.8, 0.88, 1.0), haze), 0.9 * a)
		var c1: Color = Color(pair[1].lerp(Color(0.8, 0.88, 1.0), haze), 0.9 * a)
		draw_circle(at, r, c0)
		draw_set_transform(at, 0.0, Vector2(0.45, 1.0))
		draw_circle(Vector2.ZERO, r, c1)
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.7, r * 0.7), at + Vector2(r * 0.7, r * 0.7),
			at + Vector2(r * 0.25, r * 1.25), at + Vector2(-r * 0.25, r * 1.25)]), c0)
		var basket := at + Vector2(0.0, r * 1.25 + 5.0)
		var rope := Color(0.35, 0.3, 0.3, 0.7 * a)
		draw_line(at + Vector2(-r * 0.25, r * 1.25), basket + Vector2(-2.5, 0.0), rope, 1.0)
		draw_line(at + Vector2(r * 0.25, r * 1.25), basket + Vector2(2.5, 0.0), rope, 1.0)
		draw_rect(Rect2(basket - Vector2(3.0, 0.0), Vector2(6.0, 4.0)), Color(0.55, 0.38, 0.25, 0.9 * a))


# ── SUNSET ──────────────────────────────────────────────────────────────────────────────────────
func _sunset(a: float, half: Vector2) -> void:
	# The first stars, overhead, more of them the higher he is.
	var dusk := clampf((-global_position.y - 6200.0) / 2400.0, 0.0, 1.0)
	if dusk > 0.0:
		var top := Rect2(-half, Vector2(half.x * 2.0, half.y * 0.9))
		_sparkle.draw_stars(self, top, _dusk, _t, TEXEL, dusk * a * 0.85, Vector2(0.0, -global_position.y * 0.02))
	# The sun going down, streaks of cloud across it, the sea of cloud lit pink below.
	var sun_at := Vector2(-half.x * 0.22, half.y * 0.38 + _y(-7000.0, 0.04))
	for glow in [[150.0, 0.06], [104.0, 0.1], [80.0, 0.16]]:
		draw_circle(sun_at, glow[0], Color(1.0, 0.72, 0.42, glow[1] * a))
	var sun_size := Vector2(_sun.get_width(), _sun.get_height()) * TEXEL
	draw_texture_rect(_sun, Rect2(_snap(sun_at - sun_size * 0.5), sun_size), false, Color(1, 1, 1, a))
	for i in 5:
		var long := 150.0 + _h(i, 111) * 170.0
		var sx := fposmod(_t * (4.0 + i) + _h(i, 112) * 900.0, half.x * 2.0 + long + 200.0) - half.x - long - 100.0
		var sy := sun_at.y - 70.0 + i * 34.0 + _h(i, 113) * 12.0
		draw_rect(Rect2(sx, sy, long, TEXEL * 2.0), Color(0.55, 0.26, 0.42, 0.55 * a))
		draw_rect(Rect2(sx + long * 0.1, sy - TEXEL, long * 0.7, TEXEL), Color(0.98, 0.62, 0.5, 0.45 * a))
	_draw_sea(_y(-5500.0, 0.26), Color(1.0, 0.72, 0.66, a), half)
	_cloud_layer(51, 0.06, Vector2(170.0, 110.0), 0.4, [0, 1, 2, 3, 4, 5, 6, 7], 1.0, 4.0, Color(1.0, 0.76, 0.70, 0.6 * a), Vector2(5300.0, 8600.0))
	_islands(a, half)
	_cloud_layer(52, 0.17, Vector2(260.0, 170.0), 0.36, [6, 7, 8, 9, 10, 11, 12], 1.0, 8.0, Color(1.0, 0.68, 0.62, 0.75 * a), Vector2(5300.0, 8600.0))
	_flock(a, half, 15.0, 3, -0.15, Color(0.16, 0.08, 0.18, 0.8 * a), 53)


## Far islands floating in the haze, bobbing: a grassy top lit by the sun, rock hanging under it, a little
## tree, now and then a waterfall.
func _islands(a: float, half: Vector2) -> void:
	var rock := Color(0.32, 0.17, 0.36, 0.55 * a)  # (faint: far away, and not to be mistaken for a platform)
	var lit := Color(0.78, 0.42, 0.46, 0.5 * a)
	var step := 330.0
	var depth := 0.28
	var off := fposmod(-global_position.y * depth, step)
	var j := -2
	while j * step + off - half.y < half.y + step:
		var row := j - int(floor(-global_position.y * depth / step))
		var cx := (_h(row, 40) - 0.5) * half.x * 1.6
		var at := Vector2(cx, j * step + off - half.y + sin(_t * 0.6 + row) * 4.0)
		var iw := 40.0 + _h(row, 41) * 46.0
		var drop := iw * (0.7 + _h(row, 42) * 0.4)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-iw, 0.0), at + Vector2(iw, 0.0), at + Vector2(iw * 0.55, drop * 0.45),
			at + Vector2(iw * 0.2, drop), at + Vector2(-iw * 0.25, drop * 0.7), at + Vector2(-iw * 0.6, drop * 0.35)]), rock)
		draw_rect(Rect2(at.x - iw, at.y - TEXEL, iw * 2.0, TEXEL * 1.5), lit)
		if _h(row, 43) > 0.35:  # (a little tree)
			var tx := at.x + (_h(row, 44) - 0.5) * iw
			draw_rect(Rect2(tx - 1.5, at.y - 14.0, 3.0, 14.0), rock)
			draw_circle(Vector2(tx, at.y - 17.0), 8.0, rock)
		if _h(row, 45) > 0.6:  # (a waterfall off its edge)
			var fx := at.x + iw * 0.8
			draw_rect(Rect2(fx, at.y, TEXEL, drop * 1.6), Color(0.85, 0.7, 0.85, 0.3 * a))
		j += 1


# ── SPACE ───────────────────────────────────────────────────────────────────────────────────────
# The Muse Jukebox's starry sky (its colours are space's in EndlessZones, its stars SparkleSky's).
const NEBULAS := [[Vector2(-0.55, -0.45), Color(0.55, 0.30, 0.85)], [Vector2(0.6, 0.1), Color(0.25, 0.42, 0.95)],
	[Vector2(-0.2, 0.62), Color(0.88, 0.36, 0.70)]]


func _space(a: float, half: Vector2) -> void:
	# Soft nebulas, far far off, breathing.
	for n in NEBULAS.size():
		var spot: Vector2 = NEBULAS[n][0] * half + Vector2(0.0, _y(-10000.0 - n * 900.0, 0.02))
		var col: Color = NEBULAS[n][1]
		for b in 12:  # (lots of faint ones, so it's soft, with no edge to it)
			var ang := TAU * b / 12.0 + n
			var at := spot + Vector2(cos(ang), sin(ang) * 0.6) * (30.0 + _h(n * 12 + b, 121) * 90.0)
			var breathe := 0.8 + 0.2 * sin(_t * 0.3 + b + n)
			draw_circle(at, 50.0 + _h(n * 12 + b, 122) * 110.0, Color(col, 0.02 * breathe * a))
	# The stars, three rows of them.
	var all := Rect2(-half, half * 2.0)
	for i in 3:
		_sparkle.draw_stars(self, all, _stars[i], _t, TEXEL, a, Vector2(0.0, -global_position.y * [0.03, 0.07, 0.14][i]))
	# The Earth he left behind, below him as he reaches space; the planet; the moon.
	var earth_size := Vector2(_earth.get_width(), _earth.get_height()) * TEXEL
	var earth_at := Vector2(half.x * 0.3, _y(-8000.0, 0.15) + 150.0)
	if earth_at.y - earth_size.y * 0.5 < half.y:
		draw_circle(earth_at, earth_size.x * 0.56, Color(0.45, 0.7, 1.0, 0.1 * a))
		draw_texture_rect(_earth, Rect2(_snap(earth_at - earth_size * 0.5), earth_size), false, Color(1, 1, 1, a))
	var planet_size := Vector2(_planet.get_width(), _planet.get_height()) * TEXEL
	draw_texture_rect(_planet, Rect2(_snap(Vector2(-half.x * 0.75, -half.y * 0.55 + _y(-9500.0, 0.06))), planet_size), false, Color(1, 1, 1, a))
	var moon_size := Vector2(_moon.get_width(), _moon.get_height()) * TEXEL
	draw_texture_rect(_moon, Rect2(_snap(Vector2(half.x * 0.5, -half.y * 0.2 + _y(-9000.0, 0.09))), moon_size), false, Color(1, 1, 1, a))
	_satellite(a, half)
	# Now and then, a shooting star; and once in a long while, a comet.
	var lap := floorf(_t / 3.4)
	var p := fposmod(_t, 3.4)
	if p < 0.7:
		var k := p / 0.7
		var left := _h(int(lap), 131) < 0.5
		var start := Vector2((_h(int(lap), 132) - 0.5) * half.x * 1.2, -half.y * (0.3 + _h(int(lap), 133) * 0.6))
		var way := Vector2(1.0 if left else -1.0, 0.35 + _h(int(lap), 134) * 0.25).normalized()
		var head := start + way * 340.0 * k
		for i in 12:
			draw_rect(Rect2(head - way * i * TEXEL * 1.5, Vector2(TEXEL, TEXEL)), Color(1.0, 0.95, 0.85, (1.0 - i / 12.0) * (1.0 - k) * a))
		_sparkle.sparkle(self, head, Color(1.0, 0.98, 0.9), 1.0 - k, TEXEL, (1.0 - k * 0.5) * a)
	var comet := fposmod(_t + 8.0, 24.0) / 9.0
	if comet < 1.0:
		var way := Vector2(1.0, 0.12).normalized()
		var head := Vector2(lerpf(-half.x - 60.0, half.x + 60.0, comet), -half.y * 0.62 + comet * 30.0)
		var glow := sin(comet * PI)
		for i in 34:
			var fade := (1.0 - i / 34.0) * glow
			draw_rect(Rect2(head - way * i * TEXEL + Vector2(0.0, sin(i * 0.6 + _t * 3.0) * 0.8), Vector2(TEXEL, TEXEL * (2.0 if i < 10 else 1.0))),
				Color(0.62, 0.86, 1.0, 0.75 * fade * a))
		draw_rect(Rect2(head - Vector2(TEXEL, TEXEL), Vector2(TEXEL * 2.0, TEXEL * 2.0)), Color(0.95, 1.0, 1.0, glow * a))


## A satellite drifting by, its light blinking.
func _satellite(a: float, half: Vector2) -> void:
	var wrap := half.x * 2.0 + 120.0
	var at := Vector2(fposmod(_t * 6.0, wrap) - wrap * 0.5, -half.y * 0.35 + _y(-9800.0, 0.05))
	if absf(at.y) > half.y:
		return
	var body := Color(0.78, 0.8, 0.86, 0.9 * a)
	var panel := Color(0.3, 0.42, 0.78, 0.9 * a)
	draw_rect(Rect2(at - Vector2(TEXEL, TEXEL), Vector2(TEXEL * 2.0, TEXEL * 2.0)), body)
	draw_rect(Rect2(at + Vector2(-TEXEL * 5.0, -TEXEL * 0.5), Vector2(TEXEL * 3.5, TEXEL)), panel)
	draw_rect(Rect2(at + Vector2(TEXEL * 1.5, -TEXEL * 0.5), Vector2(TEXEL * 3.5, TEXEL)), panel)
	if fposmod(_t, 1.6) < 0.25:
		draw_rect(Rect2(at + Vector2(-TEXEL * 0.5, -TEXEL * 2.0), Vector2(TEXEL, TEXEL)), Color(1.0, 0.3, 0.3, a))


# ── BEST ────────────────────────────────────────────────────────────────────────────────────────
func _best_line(half: Vector2) -> void:
	if best_height <= 0.0:
		return
	var y := _y(-best_height, 1.0)
	if absf(y) > half.y:
		return
	var gold := Color(1.0, 0.86, 0.42, 0.85)
	var x := -half.x
	while x < half.x:
		draw_rect(Rect2(x, y, 10.0, 2.0), gold)
		x += 18.0
	draw_string(_font, Vector2(-half.x + 6.0, y - 4.0), "BEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gold)
