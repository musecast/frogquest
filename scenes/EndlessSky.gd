extends Node2D
## Endless mode's sky, behind everything and following the camera. Its colours blend from zone to zone
## as he climbs (EndlessZones.sky_at), and each zone's own scenery fades in and out with that zone's
## share of the sky: the swamp's pond, reeds and fireflies; the treetops' trunks and falling leaves;
## drifting clouds and birds; the sunset's sun and far islands; space's stars, planets and the Earth
## below. Scenery has depth: 0 stays put on the screen, 1 moves with the world.
## Also the line at his best height, so he can see when he's about to beat it.

const FONT := "res://assets/fibberish.ttf"

var cam: Camera2D
var best_height := 0.0  # world units above the first lily pad (0: no best yet)
var _zones: Script
var _t := 0.0
var _font: Font
var _sun: Texture2D
var _planet: Texture2D
var _earth: Texture2D
var _moon: Texture2D
var _stars := []  # [x 0..1, y 0..1, size, layer, phase]


func _ready() -> void:
	z_index = -50
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_zones = load("res://scripts/EndlessZones.gd")
	_font = load(FONT)
	_sun = load("res://assets/endless/sun.png")
	_planet = load("res://assets/endless/planet.png")
	_earth = load("res://assets/endless/earth.png")
	_moon = load("res://assets/endless/moon.png")
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 42
	for i in 150:
		_stars.append([rnd.randf(), rnd.randf(), 1.0 + float(rnd.randi() % 3 == 0), i % 3, rnd.randf() * TAU])


func _process(delta: float) -> void:
	_t += delta
	if cam:
		global_position = cam.get_screen_center_position()
	queue_redraw()


## A cheap repeatable "random" 0..1 for scenery item i of a layer.
static func _h(i: int, salt: int) -> float:
	var n := int(i * 73856093) ^ int(salt * 19349663)
	n = (n ^ (n >> 13)) * 1274126177
	return float(abs(n) % 10000) / 10000.0


func _draw() -> void:
	if cam == null:
		return
	var half: Vector2 = get_viewport_rect().size / cam.zoom * 0.5
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


# ── MUSHROOM SWAMP ──────────────────────────────────────────────────────────────────────────────
# A sunny morning by the pond: giant mushrooms in soft colours (some with a door and a lit window) on
# green hills, paler the further off they are, under a warm sun and a few clouds. (It was a misty teal
# with dark mushroom poles, which looked liminal and a bit scary.) Pastel, domed and hazy, so none of it
# is taken for a platform.
const CAPS := [Color(0.95, 0.56, 0.56), Color(0.98, 0.72, 0.50), Color(0.73, 0.63, 0.93), Color(0.99, 0.84, 0.50), Color(0.93, 0.52, 0.71)]
const STEM := Color(0.98, 0.93, 0.81)
const STEM_SHADE := Color(0.87, 0.78, 0.64)
const SPOT := Color(1.0, 0.98, 0.92)
const DOOR := Color(0.55, 0.36, 0.25)
const WINDOW := Color(1.0, 0.88, 0.50)
const HILLS := [Color(0.62, 0.84, 0.58), Color(0.50, 0.76, 0.46)]


func _swamp(a: float, half: Vector2) -> void:
	var sky: Array = _zones.sky_at(-global_position.y)
	var air: Color = sky[0].lerp(sky[1], 0.6)  # (what far things fade toward)
	# The sun, and a few high clouds drifting by.
	var sun := Vector2(half.x * 0.5, -half.y * 0.6 + _y(-500.0, 0.05))
	for glow in [[64.0, 0.10], [42.0, 0.16], [24.0, 1.0]]:
		draw_circle(sun, glow[0], Color(1.0, 0.97, 0.80, glow[1] * a))
	var step := 240.0
	var off := fposmod(-global_position.y * 0.12, step)
	var j := -2
	while j * step + off - half.y < half.y + step:
		var row := j - int(floor(-global_position.y * 0.12 / step))
		var drift := fposmod(_t * 5.0 + _h(row, 60) * 900.0, half.x * 2.0 + 260.0) - half.x - 130.0
		_puff(Vector2(drift, j * step + off - half.y), 0.8, Color(1.0, 1.0, 1.0, 0.5 * a))
		j += 1
	# Giant mushrooms on their hills, in two layers.
	for layer in 2:
		_giant_mushrooms(layer, a, half, air)
	# Reeds, cattails, grass and flowers along the bank, nearer.
	var reed := Color(0.32, 0.58, 0.32, a)
	var head := Color(0.58, 0.38, 0.23, a)
	var near := _y(10.0, 0.7)
	for i in range(-20, 21):
		var x := i * 26.0 + _h(i, 4) * 14.0
		var tall := 40.0 + _h(i, 5) * 90.0
		var sway := sin(_t * 1.3 + i) * 2.0
		draw_line(Vector2(x, near), Vector2(x + sway, near - tall), reed, 2.0)
		if _h(i, 6) > 0.45:
			draw_rect(Rect2(x + sway - 2.0, near - tall - 2.0, 4.0, 11.0), head)
	if near - 30.0 < half.y:
		var grass := Color(0.42, 0.72, 0.38, a)
		var petals := [Color(1.0, 0.68, 0.78, a), Color(1.0, 0.90, 0.45, a), Color(1.0, 1.0, 0.96, a)]
		for i in range(-30, 31):
			var x := i * 17.0 + _h(i, 7) * 10.0
			for blade in 3:
				draw_line(Vector2(x + blade * 3.0, near), Vector2(x + blade * 3.0 + (blade - 1) * 3.0, near - 8.0 - _h(i + blade, 8) * 8.0), grass, 2.0)
			if _h(i, 9) > 0.6:
				var flower := Vector2(x + 4.0, near - 12.0 - _h(i, 10) * 10.0)
				draw_line(Vector2(x + 4.0, near), flower, grass, 1.0)
				draw_circle(flower, 2.5, petals[i % petals.size()])
	# The pond, right under the first lily pad, glinting.
	var water_top := _y(5.0, 1.0)
	if water_top < half.y:
		draw_rect(Rect2(-half.x, water_top, half.x * 2.0, half.y - water_top + 4.0), Color(0.30, 0.63, 0.74, 1.0))
		for k in 6:
			var wy := water_top + 6.0 + k * 9.0
			var shift := fmod(_t * (10.0 + k * 3.0), 40.0)
			for i in range(-int(half.x / 40.0) - 2, int(half.x / 40.0) + 2):
				draw_rect(Rect2(i * 40.0 + shift + k * 13.0, wy, 14.0, 2.0), Color(0.80, 0.95, 0.97, 0.55 - k * 0.07))
	_glow_bugs(a, half)


## One layer of giant mushrooms (0 far, 1 nearer), growing from hills along their foot.
func _giant_mushrooms(layer: int, a: float, half: Vector2, air: Color) -> void:
	var depth := 0.2 if layer == 0 else 0.4
	var haze := 0.5 if layer == 0 else 0.22
	var ground := _y(80.0, depth)
	var salt := layer * 20
	var spacing := 110.0 if layer == 0 else 150.0
	for i in range(-8, 9):
		var x := i * spacing + (_h(i, 1 + salt) - 0.5) * spacing * 0.6
		var tall := (70.0 + _h(i, 2 + salt) * 260.0) if layer == 0 else (90.0 + _h(i, 2 + salt) * 540.0)
		var cap_w := (34.0 + _h(i, 3 + salt) * 40.0) * (1.0 + layer * 0.6)
		var cap_h := cap_w * 0.5
		var stem_w := roundf(maxf(6.0, cap_w * 0.24))
		var top := ground - tall
		if top - cap_h > half.y or absf(x) - cap_w > half.x:
			continue
		var stem_col := _faded(STEM, air, haze, a)
		draw_rect(Rect2(x - stem_w * 0.5, top, stem_w, tall + 6.0), stem_col)
		draw_rect(Rect2(x + stem_w * 0.5 - stem_w * 0.3, top, stem_w * 0.3, tall + 6.0), _faded(STEM_SHADE, air, haze, a))
		# Now and then a front door, and a window lit inside.
		if layer == 1 and stem_w >= 12.0 and _h(i, 11 + salt) > 0.5:
			var door_w := roundf(stem_w * 0.45)
			var sill := ground - 38.0  # (above the hills)
			draw_rect(Rect2(x - door_w * 0.5, sill - door_w * 1.1, door_w, door_w * 1.1), _faded(DOOR, air, haze, a))
			draw_circle(Vector2(x, sill - door_w * 1.1), door_w * 0.5, _faded(DOOR, air, haze, a))
			draw_circle(Vector2(x - stem_w * 0.12, sill - door_w * 2.6), maxf(2.0, stem_w * 0.15), _faded(WINDOW, air, haze * 0.5, a))
		var cap: Color = CAPS[int(_h(i, 4 + salt) * CAPS.size()) % CAPS.size()]
		draw_rect(Rect2(x - cap_w * 0.4, top - 2.0, cap_w * 0.8, 3.0), _faded(cap.darkened(0.25), air, haze, a))
		_dome(Vector2(x, top - cap_h), cap_w, cap_h, _faded(cap, air, haze, a))
		for s in 3:
			var spot := Vector2(x + (_h(i * 3 + s, 12 + salt) - 0.5) * cap_w * 0.55, top - cap_h * (0.3 + _h(i * 3 + s, 13 + salt) * 0.4))
			draw_circle(spot, cap_w * (0.05 + _h(i * 3 + s, 14 + salt) * 0.035), _faded(SPOT, air, haze, a))
	# Their hills, in front of the stems' feet.
	if ground - 40.0 < half.y:
		var hill := _faded(HILLS[layer], air, haze * 0.6, a)
		for i in range(-10, 11):
			var r := 46.0 + _h(i, 15 + salt) * 30.0
			draw_circle(Vector2(i * 70.0 + _h(i, 16 + salt) * 30.0, ground + r * 0.6), r, hill)
		draw_rect(Rect2(-half.x, ground + 20.0, half.x * 2.0, maxf(0.0, half.y - ground)), hill)


## A colour faded toward the air by `haze` (far things are paler), at the zone's share `a`.
static func _faded(col: Color, air: Color, haze: float, a: float) -> Color:
	var c := col.lerp(air, haze)
	c.a = a
	return c


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


func _dome(top_mid: Vector2, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 13:
		var ang := PI + PI * k / 12.0
		pts.append(top_mid + Vector2(cos(ang) * w * 0.5, sin(ang) * h + h))
	draw_colored_polygon(pts, col)


# ── TREETOPS ────────────────────────────────────────────────────────────────────────────────────
func _treetops(a: float, half: Vector2) -> void:
	# Sunlit, not a dark wood: warm bark and soft leaves, paler further off so the leafy platforms
	# stand out in front.
	for layer in 2:
		var depth := 0.35 if layer == 0 else 0.6
		var trunk := Color(0.62, 0.50, 0.38, a) if layer == 0 else Color(0.52, 0.39, 0.28, a)
		var leaves := Color(0.58, 0.78, 0.46, a) if layer == 0 else Color(0.46, 0.68, 0.38, a)
		var spacing := 170.0 if layer == 0 else 260.0
		for i in range(-5, 6):
			var x := i * spacing + _h(i, 10 + layer) * 80.0
			var tw := 26.0 + _h(i, 12 + layer) * 26.0 + layer * 14.0
			draw_rect(Rect2(x - tw * 0.5, -half.y, tw, half.y * 2.0), trunk)
			# leaf clumps up the trunk, scrolling with the depth
			var step := 220.0
			var off := fposmod(-global_position.y * depth, step)
			var j := -2
			while j * step + off - half.y < half.y + step:
				var cy := j * step + off - half.y
				var side := -1.0 if (j + i) % 2 == 0 else 1.0
				draw_circle(Vector2(x + side * (tw * 0.5 + 18.0), cy), 26.0 + layer * 8.0, leaves)
				draw_circle(Vector2(x + side * (tw * 0.5 + 40.0), cy + 10.0), 18.0 + layer * 6.0, leaves)
				j += 1
	# Light through the leaves.
	for i in 3:
		var x := -half.x * 0.6 + i * half.x * 0.6 + sin(_t * 0.2 + i) * 20.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -half.y), Vector2(x + 40.0, -half.y),
			Vector2(x + 160.0, half.y), Vector2(x + 90.0, half.y)]), Color(1.0, 1.0, 0.8, 0.12 * a))
	# Falling leaves.
	for i in 14:
		var fx := sin(_t * 0.6 + i * 2.1) * half.x * 0.95
		var fy := fposmod(_t * (24.0 + i * 3.0) + i * 97.0, half.y * 2.0) - half.y
		var col := Color(0.55, 0.78, 0.32, 0.8 * a) if i % 3 else Color(0.85, 0.72, 0.28, 0.8 * a)
		draw_rect(Rect2(fx, fy, 3.0, 2.0), col)


# ── CLOUDS ──────────────────────────────────────────────────────────────────────────────────────
func _clouds(a: float, half: Vector2) -> void:
	for layer in 2:
		var depth := 0.2 if layer == 0 else 0.45
		var alpha := (0.35 if layer == 0 else 0.6) * a
		var size := 1.0 if layer == 0 else 1.7
		var step := 260.0 if layer == 0 else 420.0
		var off := fposmod(-global_position.y * depth, step)
		var j := -2
		while j * step + off - half.y < half.y + step:
			var cy := j * step + off - half.y
			var row := j - int(floor(-global_position.y * depth / step))
			var drift := fposmod(_t * (6.0 + layer * 6.0) + _h(row, 30 + layer) * 900.0, half.x * 2.0 + 300.0) - half.x - 150.0
			_puff(Vector2(drift, cy), size, Color(1.0, 1.0, 1.0, alpha))
			j += 1
	# Birds.
	for i in 3:
		var bx := fposmod(_t * (40.0 + i * 12.0) + i * 400.0, half.x * 2.0 + 200.0) - half.x - 100.0
		var by := -half.y * 0.5 + i * 90.0 + sin(_t * 2.0 + i) * 10.0
		var flap := 4.0 if fmod(_t * 6.0 + i, 2.0) < 1.0 else -2.0
		var bird := Color(0.18, 0.24, 0.36, 0.8 * a)
		draw_line(Vector2(bx - 7.0, by - flap), Vector2(bx, by), bird, 2.0)
		draw_line(Vector2(bx, by), Vector2(bx + 7.0, by - flap), bird, 2.0)


func _puff(at: Vector2, s: float, col: Color) -> void:
	for p in [[-34.0, 6.0, 20.0], [-12.0, -6.0, 26.0], [14.0, -2.0, 24.0], [36.0, 8.0, 18.0], [0.0, 10.0, 22.0]]:
		draw_circle(at + Vector2(p[0], p[1]) * s, p[2] * s, col)


# ── SUNSET ──────────────────────────────────────────────────────────────────────────────────────
func _sunset(a: float, half: Vector2) -> void:
	var sun_at := Vector2(-half.x * 0.25, half.y * 0.35 + _y(-7000.0, 0.04))
	draw_circle(sun_at, 120.0, Color(1.0, 0.75, 0.45, 0.10 * a))
	draw_circle(sun_at, 80.0, Color(1.0, 0.80, 0.50, 0.15 * a))
	draw_texture_rect(_sun, Rect2(sun_at - Vector2(60, 60), Vector2(120, 120)), false, Color(1, 1, 1, a))
	# Far islands drifting in the haze.
	var isle := Color(0.30, 0.16, 0.36, 0.45 * a)  # (faint: far away, and not to be mistaken for a platform)
	var step := 300.0
	var off := fposmod(-global_position.y * 0.3, step)
	var j := -2
	while j * step + off - half.y < half.y + step:
		var cy := j * step + off - half.y
		var row := j - int(floor(-global_position.y * 0.3 / step))
		var cx := (_h(row, 40) - 0.5) * half.x * 1.6
		var iw := 50.0 + _h(row, 41) * 50.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - iw, cy), Vector2(cx + iw, cy),
			Vector2(cx + iw * 0.3, cy + iw * 0.7), Vector2(cx - iw * 0.3, cy + iw * 0.7)]), isle)
		j += 1
	for i in 2:
		var bx := fposmod(_t * (30.0 + i * 15.0) + i * 300.0, half.x * 2.0 + 200.0) - half.x - 100.0
		var by := -half.y * 0.3 + i * 60.0
		var flap := 4.0 if fmod(_t * 5.0 + i, 2.0) < 1.0 else -2.0
		var bird := Color(0.16, 0.08, 0.18, 0.8 * a)
		draw_line(Vector2(bx - 7.0, by - flap), Vector2(bx, by), bird, 2.0)
		draw_line(Vector2(bx, by), Vector2(bx + 7.0, by - flap), bird, 2.0)


# ── SPACE ───────────────────────────────────────────────────────────────────────────────────────
func _space(a: float, half: Vector2) -> void:
	var tile := Vector2(half.x * 2.0, 900.0)
	for s in _stars:
		var depth: float = [0.05, 0.12, 0.25][s[3]]
		var y: float = fposmod(s[1] * tile.y - global_position.y * depth, tile.y) - tile.y * 0.5
		if absf(y) > half.y + 2.0:
			continue
		var x: float = (s[0] - 0.5) * tile.x
		var twinkle := 0.55 + 0.45 * sin(_t * 2.0 + s[4])
		draw_rect(Rect2(x, y, s[2], s[2]), Color(1.0, 1.0, 0.95, twinkle * a))
	# The Earth he left behind, below him as he reaches space.
	var earth_at := Vector2(half.x * 0.3, _y(-8000.0, 0.15) + 140.0)
	if earth_at.y - 80.0 < half.y:
		draw_texture_rect(_earth, Rect2(earth_at - Vector2(78, 78), Vector2(156, 156)), false, Color(1, 1, 1, a))
	draw_texture_rect(_planet, Rect2(Vector2(-half.x * 0.75, -half.y * 0.55 + _y(-9500.0, 0.06)), Vector2(144, 96)), false, Color(1, 1, 1, a))
	draw_texture_rect(_moon, Rect2(Vector2(half.x * 0.55, -half.y * 0.2 + _y(-9000.0, 0.09)), Vector2(40, 40)), false, Color(1, 1, 1, a))
	# Now and then, a shooting star.
	var cycle := fmod(_t, 5.0)
	if cycle < 0.6:
		var k := cycle / 0.6
		var start := Vector2(-half.x * 0.6 + fmod(floor(_t / 5.0) * 137.0, half.x), -half.y * 0.7)
		var head := start + Vector2(260.0, 120.0) * k
		draw_line(head - Vector2(40.0, 18.0), head, Color(1.0, 1.0, 0.9, (1.0 - k) * a), 2.0)


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
