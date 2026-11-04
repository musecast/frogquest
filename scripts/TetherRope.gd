extends RefCounted
## A friend's stretchy band (a tether), as a rope: POINTS points hanging between the two frogs, with
## gravity (verlet), resting on and catching round what's solid in the world (a point that would go into
## a wall or a ledge stays where it was: it isn't drawn through them), slack when they're close and
## pulled straight as they part, thinner the more it's stretched. Drawn with a dark edge, its owner's
## colour (FroggyLook.BANDS, from their look), and a light glint down the middle: it was pink, too like
## his tongue. along() is the way along it, for a friend reeling him in over the ledge it lies across
## rather than through it.

const POINTS := 14
const GRAVITY := 700.0
const DAMP := 0.96
const SOLVE := 10  # (passes a frame that pull its points back together)
const EDGE := Color(0.10, 0.07, 0.06)
const NUDGES := [Vector2(0, -2), Vector2(0, -4), Vector2(-2, 0), Vector2(2, 0), Vector2(0, -7), Vector2(-4, -2),
	Vector2(4, -2), Vector2(0, -11)]  # (a point that's gone into something steps out to the nearest open spot: up off a ledge, out from a wall)

var colour := Color(1.0, 0.82, 0.3)
var mine := false  # (his own band: its first end is his)
var taut := 0.0  # 0 slack, 1 pulled straight
var _pts := PackedVector2Array()
var _old := PackedVector2Array()


## A frame of it: hung from a to b (its ends at the frogs), slack (its give, before it's pulled
## straight), against what's solid in space for the mask (none: it hangs through everything).
func step(a: Vector2, b: Vector2, slack: float, delta: float, space: PhysicsDirectSpaceState2D = null, mask := 1) -> void:
	if _pts.size() != POINTS:
		_pts.resize(POINTS)
		_old.resize(POINTS)
		for i in POINTS:
			_pts[i] = a.lerp(b, float(i) / float(POINTS - 1))
			_old[i] = _pts[i]
	var d := a.distance_to(b)
	taut = clampf((d - slack * 0.5) / (slack * 0.5), 0.0, 1.0)
	var seg := maxf(d * 1.03, slack) / float(POINTS - 1)  # (a little longer than straight: room to bend round a corner)
	var fall := Vector2(0.0, GRAVITY) * delta * delta
	for i in range(1, POINTS - 1):
		var p := _pts[i]
		_pts[i] = p + (p - _old[i]) * DAMP + fall
		_old[i] = p
	_pts[0] = a
	_pts[POINTS - 1] = b
	for _k in SOLVE:
		for i in range(POINTS - 1):
			var gap := _pts[i + 1] - _pts[i]
			var dist := gap.length()
			if dist < 0.0001:
				continue
			var pull := gap * ((dist - seg) / dist)
			if i == 0:
				_pts[1] -= pull
			elif i == POINTS - 2:
				_pts[i] += pull
			else:
				_pts[i] += pull * 0.5
				_pts[i + 1] -= pull * 0.5
	if space == null:
		return
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = mask
	for i in range(1, POINTS - 1):
		q.position = _pts[i]
		if space.intersect_point(q, 1).is_empty():
			continue
		var out := Vector2.INF
		for nudge in NUDGES:
			q.position = _pts[i] + nudge
			if space.intersect_point(q, 1).is_empty():
				out = q.position
				break
		if out == Vector2.INF:
			q.position = _old[i]
			out = _old[i] if space.intersect_point(q, 1).is_empty() else _pts[i]
		_pts[i] = out  # (it rests on it, or catches round its corner)
		_old[i] = out.lerp(_old[i], 0.5)  # (and loses most of its speed doing so)


func draw(canvas: CanvasItem) -> void:
	if _pts.size() < 2:
		return
	var line := _smooth(_smooth(_pts))
	var w := lerpf(4.0, 2.0, taut)
	canvas.draw_polyline(line, EDGE, w + 2.0)
	canvas.draw_polyline(line, colour, w)
	canvas.draw_polyline(line, colour.lerp(Color.WHITE, 0.55), maxf(1.0, w * 0.35))


## Rounder (Chaikin's corner cutting): each corner of the rope eased into a curve.
static func _smooth(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	for i in range(line.size() - 1):
		out.append(line[i].lerp(line[i + 1], 0.25))
		out.append(line[i].lerp(line[i + 1], 0.75))
	out.append(line[line.size() - 1])
	return out


## Its points from its first end to its last (the way a friend reels him in), then on to `to`.
func path_to(to: Vector2) -> PackedVector2Array:
	var out := _pts.duplicate()
	out.append(to)
	return out


## The spot `along` of the way through path (0 at its start, 1 at its end).
static func along(path: PackedVector2Array, k: float) -> Vector2:
	if path.size() == 0:
		return Vector2.ZERO
	var total := 0.0
	for i in range(path.size() - 1):
		total += path[i].distance_to(path[i + 1])
	var want := clampf(k, 0.0, 1.0) * total
	for i in range(path.size() - 1):
		var seg := path[i].distance_to(path[i + 1])
		if want <= seg or i == path.size() - 2:
			return path[i].lerp(path[i + 1], 0.0 if seg < 0.0001 else clampf(want / seg, 0.0, 1.0))
		want -= seg
	return path[path.size() - 1]
