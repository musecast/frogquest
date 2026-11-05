extends RefCounted
## The aim line, story and Endless alike, as much of the jump as the difficulty shows (Difficulty.gd):
## - easy: the arc he'll really fly, all of it, to where he lands;
## - normal: the arc past its peak (the first part of it), never quite to where he lands;
## - hard: just the start of the arc, a short curve the same length whatever the pull;
## - og: the very first Frog Quest's line (2024), thin and pink, straight out the way he'll go.
## The arc's worked out the way his physics will go: the launch he'll get (a mushroom's throw, a spring's
## boost and all), gravity each tick, and off a wall he comes back two fifths as fast, as he does. It
## uses his own shape (one-way platforms and all, through the physics' own test), so it bends where he'll
## go and ends where he'll land or bump his head (or once he's fallen back below where he started).
## Drawn as round dots, drifting slowly out the way he'll go: cream, yellow, orange, red at full power
## (gold all along on a spring), biggest by him and fading out at the far end, each with a soft dark rim.

const TICK := 1.0 / 60.0  # (his physics')
const MOST_TIME := 1.6  # seconds of flight worked out, at the most
const BOUNCES := 2  # (off walls)
const BELOW := 40.0  # px under where he started: far enough (he's falling away by then)
const NORMAL_SHARE := 0.6  # (normal: the first this much of the flight)
const HARD_LENGTH := 95.0  # (hard: this many px of it)
const GAP := 11.0  # px between dots, along the arc
const FIRST := 15.0  # (the first dot's this far along: clear of him)
const DRIFT := 18.0  # px a second the dots drift out along it
const BIG := 3.3  # (a dot's radius by him...)
const SMALL := 1.6  # (...and at the far end)
const SPRING := Color(1.0, 0.86, 0.3)
const RIM := Color(0.07, 0.05, 0.1, 0.42)
## Strength as colour: [power, colour] (cream, yellow, orange, red at full).
const HEAT := [[0.0, Color(1.0, 0.97, 0.88)], [0.45, Color(1.0, 0.89, 0.45)], [0.75, Color(1.0, 0.55, 0.2)],
	[1.0, Color(0.92, 0.22, 0.16)]]


## Where he'll be, tick by tick (in the world), leaving `frog` with `velocity`: the arc, up to where he
## lands or bumps into something, or falls away.
static func path(frog: CharacterBody2D, velocity: Vector2) -> PackedVector2Array:
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	var start := frog.global_position
	var points := PackedVector2Array([start])
	var at := frog.global_transform
	var v := velocity
	var bounces := 0
	var hit := KinematicCollision2D.new()
	var t := 0.0
	while t < MOST_TIME:
		if t > 0.0:
			v.y += gravity * TICK  # (the tick he jumps on, he's still standing: no gravity yet)
		t += TICK
		var step := v * TICK
		if frog.test_move(at, step, hit):
			at.origin += hit.get_travel()
			var normal := hit.get_normal()
			var rest := hit.get_remainder().slide(normal)  # (the rest of the tick, along what he hit: as he does)
			if absf(normal.x) > 0.7 and bounces < BOUNCES:
				at.origin += rest
				points.append(at.origin)
				v.x = -v.x / 2.5  # (off a wall: back the other way, two fifths as fast)
				bounces += 1
				continue
			if normal.y < -0.7:
				at.origin += rest  # (landing: he slides out the tick along the ground)
			points.append(at.origin)
			break  # (he lands, or bumps his head)
		at.origin += step
		points.append(at.origin)
		if v.y > 0.0 and at.origin.y > start.y + BELOW:
			break
	return points


## How much of the arc a difficulty shows: all of it (easy), its first part (normal), just its start
## (hard; og draws no arc at all).
static func shown(points: PackedVector2Array, mode: String) -> PackedVector2Array:
	match mode:
		"easy":
			return points
		"normal":
			return points.slice(0, maxi(2, int(ceil(points.size() * NORMAL_SHARE))))
		"hard":
			return _first(points, HARD_LENGTH)
	return PackedVector2Array()


## Strength as colour, 0 to 1 (full power's 1).
static func heat(power: float) -> Color:
	for i in range(1, HEAT.size()):
		if power <= HEAT[i][0]:
			var a: Array = HEAT[i - 1]
			var b: Array = HEAT[i]
			return (a[1] as Color).lerp(b[1], (power - a[0]) / (b[0] - a[0]))
	return HEAT[-1][1]


## Draws it on `canvas` (the slingshot, on him) for `frog` leaving with `velocity`. power: 0 to 1. drag:
## the pull itself, in the slingshot's own px (OG's line points along it).
static func draw(canvas: CanvasItem, frog: CharacterBody2D, velocity: Vector2, power: float, mode: String,
		drag: Vector2, spring := false) -> void:
	if mode == "og":
		_og(canvas, drag)
		return
	var points := shown(path(frog, velocity), mode)
	var along := PackedFloat32Array([0.0])
	for i in range(1, points.size()):
		along.append(along[i - 1] + points[i].distance_to(points[i - 1]))
	var total: float = along[-1] if along.size() > 0 else 0.0
	if total < FIRST + 2.0:
		return
	canvas.draw_set_transform_matrix(canvas.get_global_transform().affine_inverse())
	var colour: Color = SPRING if spring else heat(clampf(power, 0.0, 1.0))
	var fade := 0.35 if mode == "easy" else 0.5
	var d := FIRST + fmod(Time.get_ticks_msec() / 1000.0 * DRIFT, GAP)
	var i := 1
	while d < total:
		while i < points.size() - 1 and along[i] < d:
			i += 1
		var piece := maxf(along[i] - along[i - 1], 0.001)
		var dot := points[i - 1].lerp(points[i], clampf((d - along[i - 1]) / piece, 0.0, 1.0))
		var t := d / total
		var seen := clampf((1.0 - t) / fade, 0.0, 1.0) * clampf((d - FIRST) / (GAP * 1.5), 0.25, 1.0)
		var r := lerpf(BIG, SMALL, t)
		canvas.draw_circle(dot, r + 1.1, Color(RIM, RIM.a * seen), true, -1.0, true)
		canvas.draw_circle(dot, r, Color(colour, seen), true, -1.0, true)
		d += GAP
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## OG: the first Frog Quest's line, exactly (2024): from him straight out the way he'll go, a fifth as long
## as the pull (up to 300 each way), two pixels thick; white-pink turning red the harder you pull.
static func _og(canvas: CanvasItem, drag: Vector2) -> void:
	var pull := drag.clamp(Vector2(-300, -300), Vector2(300, 300))
	var length := pull.length()
	if length <= 0.0:
		return
	var shade := 1.2 - length / Vector2(300, 300).length()
	canvas.draw_line(Vector2.ZERO, pull / 5.0, Color(255, shade, shade, 1), 2.0)


## The first `length` px of a path.
static func _first(points: PackedVector2Array, length: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if points.is_empty():
		return out
	out.append(points[0])
	var gone := 0.0
	for i in range(1, points.size()):
		var piece := points[i].distance_to(points[i - 1])
		if gone + piece >= length:
			out.append(points[i - 1].lerp(points[i], (length - gone) / maxf(piece, 0.001)))
			return out
		gone += piece
		out.append(points[i])
	return out
