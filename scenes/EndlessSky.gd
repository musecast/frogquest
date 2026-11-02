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
func _swamp(a: float, half: Vector2) -> void:
	# Far giant mushrooms, misty.
	var far := Color(0.20, 0.42, 0.37, 0.75 * a)
	var base := _y(40.0, 0.35)
	for i in range(-6, 7):
		var x := i * 150.0 + _h(i, 1) * 60.0
		var tall := 120.0 + _h(i, 2) * 220.0
		var cap_w := 50.0 + _h(i, 3) * 60.0
		draw_rect(Rect2(x - 6.0, base - tall, 12.0, tall + 400.0), far)
		_dome(Vector2(x, base - tall), cap_w, cap_w * 0.45, far)
	# Reeds and cattails, nearer.
	var reed := Color(0.14, 0.30, 0.22, a)
	var head := Color(0.40, 0.24, 0.14, a)
	var near := _y(10.0, 0.7)
	for i in range(-20, 21):
		var x := i * 26.0 + _h(i, 4) * 14.0
		var tall := 40.0 + _h(i, 5) * 90.0
		var sway := sin(_t * 1.3 + i) * 2.0
		draw_line(Vector2(x, near), Vector2(x + sway, near - tall), reed, 2.0)
		if _h(i, 6) > 0.45:
			draw_rect(Rect2(x + sway - 2.0, near - tall - 2.0, 4.0, 11.0), head)
	# The pond, right under the first lily pad.
	var water_top := _y(5.0, 1.0)
	if water_top < half.y:
		draw_rect(Rect2(-half.x, water_top, half.x * 2.0, half.y - water_top + 4.0), Color(0.16, 0.42, 0.46, 1.0))
		for k in 6:
			var wy := water_top + 6.0 + k * 9.0
			var shift := fmod(_t * (10.0 + k * 3.0), 40.0)
			for i in range(-int(half.x / 40.0) - 2, int(half.x / 40.0) + 2):
				draw_rect(Rect2(i * 40.0 + shift + k * 13.0, wy, 14.0, 2.0), Color(0.55, 0.82, 0.80, 0.5 - k * 0.06))
	# Fireflies.
	for i in 14:
		var p := Vector2(sin(_t * 0.35 + i * 1.7) * half.x * 0.9, cos(_t * 0.27 + i * 2.3) * half.y * 0.8)
		var glow := 0.5 + 0.5 * sin(_t * 3.0 + i)
		draw_circle(p, 6.0, Color(1.0, 0.95, 0.5, 0.12 * glow * a))
		draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.96, 0.6, (0.4 + 0.6 * glow) * a))


func _dome(top_mid: Vector2, w: float, h: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 13:
		var ang := PI + PI * k / 12.0
		pts.append(top_mid + Vector2(cos(ang) * w * 0.5, sin(ang) * h + h))
	draw_colored_polygon(pts, col)


# ── TREETOPS ────────────────────────────────────────────────────────────────────────────────────
func _treetops(a: float, half: Vector2) -> void:
	for layer in 2:
		var depth := 0.35 if layer == 0 else 0.6
		var trunk := Color(0.10, 0.17, 0.11, a) if layer == 0 else Color(0.06, 0.11, 0.07, a)
		var leaves := Color(0.14, 0.28, 0.15, a) if layer == 0 else Color(0.09, 0.19, 0.10, a)
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
			Vector2(x + 160.0, half.y), Vector2(x + 90.0, half.y)]), Color(0.95, 1.0, 0.7, 0.05 * a))
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
