extends RefCounted
## The night sky behind the Muse Jukebox, in pixels: near-black navy, deep blue low down, full of little
## stars in white, pale blue, blue and now and then cyan, purple, green or red, the brighter ones
## four-pointed sparkles (a + or, rarely, an x) that twinkle. The Jukebox fades it in when a song plays.
## Frog Frenzy's Jukebox microgames (DROP!, WISH!) are under it, and Endless's outer space is made of it.
## Everything here is drawn in square pixels `px` across, onto any CanvasItem.

const TOP := Color(0.004, 0.02, 0.06)  # (the Jukebox's sky: #01050f)
const BOTTOM := Color(0.03, 0.06, 0.17)
## Its idle backdrop, before a song: a light blue glow in the middle going to deep purple (#91cdfa, #2e2372).
const IDLE_MIDDLE := Color(0.569, 0.804, 0.98)
const IDLE_EDGE := Color(0.18, 0.137, 0.447)
## The stars' colours, and how many of every hundred are each.
const COLOURS := [Color(1.0, 1.0, 1.0), Color(0.72, 0.84, 1.0), Color(0.36, 0.56, 1.0), Color(0.42, 0.95, 1.0),
	Color(0.78, 0.62, 1.0), Color(0.32, 1.0, 0.56), Color(1.0, 0.36, 0.36)]
const SHARES := [34, 26, 18, 8, 7, 4, 3]
enum {DOT, BIG_DOT, PLUS, CROSS}


## `count` stars, scattered the same way every time for a seed: [x 0..1, y 0..1, kind, colour, phase,
## twinkle speed].
static func make_stars(count: int, seed_n: int, sparkles := 0.14) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var stars := []
	for i in count:
		var pick := rng.randi_range(0, 99)
		var colour := 0
		while pick >= SHARES[colour]:
			pick -= SHARES[colour]
			colour += 1
		var kind := DOT
		var roll := rng.randf()
		if roll < sparkles:
			kind = CROSS if rng.randf() < 0.18 else PLUS
		elif roll < sparkles + 0.12:
			kind = BIG_DOT
		stars.append([rng.randf(), rng.randf(), kind, colour, rng.randf() * TAU, rng.randf_range(1.2, 3.4)])
	return stars


## The sky's own colours, top to bottom, over `area`, `alpha` of the way in.
static func draw_backdrop(on: CanvasItem, area: Rect2, alpha := 1.0) -> void:
	var top := Color(TOP, alpha)
	var bottom := Color(BOTTOM, alpha)
	on.draw_polygon(PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end,
		Vector2(area.position.x, area.end.y)]), PackedColorArray([top, top, bottom, bottom]))


## The Jukebox's idle glow over `area`: round, from its light blue middle out to its purple edge (a fan of
## triangles from the middle, each corner of it coloured by how far out it is).
static func draw_idle(on: CanvasItem, area: Rect2, alpha := 1.0) -> void:
	var middle := area.get_center()
	var reach := area.size.length() * 0.5
	var edge := PackedVector2Array()
	var sides := 16
	for side in 4:
		var a: Vector2 = [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)][side]
		var b: Vector2 = [Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y), area.position][side]
		for i in sides:
			edge.append(a.lerp(b, float(i) / sides))
	for i in edge.size():
		var p: Vector2 = edge[i]
		var q: Vector2 = edge[(i + 1) % edge.size()]
		var cols := PackedColorArray([Color(IDLE_MIDDLE, alpha)])
		for e in [p, q]:
			cols.append(Color(IDLE_MIDDLE.lerp(IDLE_EDGE, clampf(middle.distance_to(e) / reach, 0.0, 1.0)), alpha))
		on.draw_polygon(PackedVector2Array([middle, p, q]), cols)


## The stars over `area`, `shift` moving them (they wrap round), twinkling at time `t`.
static func draw_stars(on: CanvasItem, area: Rect2, stars: Array, t: float, px := 1.0, alpha := 1.0, shift := Vector2.ZERO) -> void:
	if alpha <= 0.0:
		return
	for s in stars:
		var at := area.position + Vector2(fposmod(float(s[0]) * area.size.x + shift.x, area.size.x),
			fposmod(float(s[1]) * area.size.y + shift.y, area.size.y))
		at = (at / px).floor() * px
		var twinkle := 0.5 + 0.5 * sin(t * float(s[5]) + float(s[4]))
		var col: Color = COLOURS[int(s[3])]
		match int(s[2]):
			DOT:
				on.draw_rect(Rect2(at, Vector2(px, px)), Color(col, (0.3 + 0.7 * twinkle) * alpha))
			BIG_DOT:
				on.draw_rect(Rect2(at, Vector2(px, px) * 2.0), Color(col, (0.45 + 0.55 * twinkle) * alpha))
			PLUS, CROSS:
				sparkle(on, at, col, twinkle, px, alpha, int(s[2]) == CROSS)


## One four-pointed sparkle at `at`: a bright middle and arms that reach out as it twinkles.
static func sparkle(on: CanvasItem, at: Vector2, col: Color, twinkle: float, px := 1.0, alpha := 1.0, diagonal := false) -> void:
	var arm := 1 + int(round(twinkle * 2.0))
	var dirs := [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)] if diagonal else \
		[Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for d in dirs:
		for step in range(1, arm + 1):
			var fade := (1.0 - float(step) / (arm + 1.0)) * (0.5 + 0.5 * twinkle)
			on.draw_rect(Rect2(at + d * step * px, Vector2(px, px)), Color(col, fade * alpha))
	on.draw_rect(Rect2(at, Vector2(px, px)), Color(col.lightened(0.5), (0.7 + 0.3 * twinkle) * alpha))
