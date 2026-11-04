extends RefCounted
## A friend's stretchy band (a tether), as a rope between two frogs, caught by what's solid in the world
## as a rope would be: pulled across a ledge, it goes over the ledge's edge and down, never through it.
## The corners it's caught on are where it bends (each found as the rope swings onto it, and kept till
## it swings back off), and between them it hangs (verlet points with gravity): slack when they're
## close, resting on what's under it, and pulled straight as they part, thinner the more it's stretched.
## Everything solid catches it, a platform you jump up through too; only what one of its frogs is in
## (partway up through a platform) lets it through to them. Drawn with a dark edge, its owner's colour
## (FroggyLook.BANDS, from their look), and a light glint down the middle: it was pink, too like his
## tongue. way() is the way along it; body_path() turns that into a way a frog's whole body fits, for a
## friend reeling him in: up round the corners it's caught on, never into the tree.

const POINTS := 24  # (its points, shared out between its stretches from bend to bend)
const GRAVITY := 700.0
const DAMP := 0.96
const SOLVE := 10  # (passes a frame that pull its points back together)
const EDGE := Color(0.10, 0.07, 0.06)
const JUMP := 240.0  # (an end that's gone this far in a frame was moved, not swung: it's laid afresh)
const OFF := 0.75  # (a bend sits this far out from each side of the corner it's caught on)
const STEP := 9.0  # (laid afresh round something: the steps it looks for a way in, half a tile)
const LOOK := 1200  # (and the most it looks at)
const AGAIN := 1.5  # (seconds before it looks again, when there was no way round: not drawn till then)
const AROUND := [Vector2(0.924, 0.383), Vector2(0.383, 0.924), Vector2(-0.383, 0.924), Vector2(-0.924, 0.383),
	Vector2(-0.924, -0.383), Vector2(-0.383, -0.924), Vector2(0.383, -0.924), Vector2(0.924, -0.383)]  # (round a corner: which way is out)
const EIGHT := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1),
	Vector2i(-1, 1), Vector2i(-1, -1)]

var colour := Color(1.0, 0.82, 0.3)
var mine := false  # (his own band: its first end is his)
var taut := 0.0  # 0 slack, 1 pulled straight
var exclude := []  # (RIDs: his own body, as an end of it is inside him)
var _space: PhysicsDirectSpaceState2D
var _ray := PhysicsRayQueryParameters2D.new()
var _probe := PhysicsPointQueryParameters2D.new()
var _bends := PackedVector2Array()  # (the corners it's caught on, from its first end to its last)
var _turns := PackedFloat32Array()  # (which way it turns round each: +1 or -1)
var _a := Vector2.INF  # (its ends, last frame)
var _b := Vector2.INF
var _changed := false  # (its bends changed this frame: its points are shared out afresh)
var _fresh := false  # (laid afresh this frame: its points laid along its way, not where they were)
var _caught := 0.0  # (how far through a swing it was caught)
var _lost := 0.0  # (no way round what's between them: not drawn till this runs out)
var _pts := PackedVector2Array()  # (its hanging points, first end to last)
var _old := PackedVector2Array()
var _pins := PackedInt32Array()  # (which of them are held: its ends and its bends, in order)


## A frame of it: hung from a to b (its ends at the frogs), slack (its give, before it's pulled
## straight), against what's solid in space for the mask (none: it hangs through everything).
func step(a: Vector2, b: Vector2, slack: float, delta: float, space: PhysicsDirectSpaceState2D = null, mask := 1) -> void:
	_space = space
	_ray.collision_mask = mask
	_ray.exclude = exclude
	_probe.collision_mask = mask
	_probe.exclude = exclude
	_changed = false
	_fresh = false
	if space == null:
		_changed = not _bends.is_empty()
		_bends.clear()
		_turns.clear()
		_lost = 0.0
	elif _lost > 0.0:
		_lost -= delta
		if _lost <= 0.0 and not _lay(a, b):
			_lost = AGAIN
	elif _a == Vector2.INF or a.distance_to(_a) > JUMP or b.distance_to(_b) > JUMP or not _clear(_a, a) \
			or not _clear(_b, b) or not _swing(a, b):
		if not _lay(a, b):  # (moved rather than swung, or something's come between it didn't swing onto)
			_lost = AGAIN
	_a = a
	_b = b
	if _lost > 0.0:
		_pts.clear()
		_pins.clear()
		return
	_hang(slack, delta)


func draw(canvas: CanvasItem) -> void:
	if _pts.size() < 2 or _pins.size() < 2:
		return
	var line := PackedVector2Array()
	for k in range(_pins.size() - 1):  # (each stretch rounded, its bends kept sharp: it's caught there)
		var part := _pts.slice(_pins[k], _pins[k + 1] + 1)
		if part.size() > 2:
			part = _smooth(_smooth(part))
		if k > 0:
			part = part.slice(1)
		line.append_array(part)
	var w := lerpf(4.0, 2.0, taut)
	canvas.draw_polyline(line, EDGE, w + 2.0)
	canvas.draw_polyline(line, colour, w)
	canvas.draw_polyline(line, colour.lerp(Color.WHITE, 0.55), maxf(1.0, w * 0.35))


## Its way, from its first end to its last, bend to bend (the corners it's caught on).
func way() -> PackedVector2Array:
	var out := PackedVector2Array([_a])
	out.append_array(_bends)
	out.append(_b)
	return out


## Whether it's showing (not lost for a way round what's between them).
func shown() -> bool:
	return _lost <= 0.0 and _pts.size() >= 2


# ── caught on corners ───────────────────────────────────────────────────────────────────────────

## A frame's swing: his end from where it was to where it is (the rest held still), then the other's,
## each caught on the corners it meets; then let go of the ones it's swung back off. False when it
## can't be followed (something's come between that it didn't swing onto).
func _swing(a: Vector2, b: Vector2) -> bool:
	return _move_end(true, _a, a, _b) and _move_end(false, _b, b, a) and _let_go(a, b) and _sound(a, b)


## One end swung from `from` to `to`, `other` the far end: caught on each corner it meets on the way.
func _move_end(first: bool, from: Vector2, to: Vector2, other: Vector2) -> bool:
	var at := from
	for _i in 6:
		var next := other
		if not _bends.is_empty():
			next = _bends[0] if first else _bends[_bends.size() - 1]
		if _clear(to, next):
			return true
		var bend := _catch(next, at, to)
		if bend == Vector2.INF:
			return false
		at = at.lerp(to, _caught)
		var turn := signf((bend - to).cross(next - bend)) if first else signf((bend - next).cross(to - bend))
		if turn == 0.0:
			return false
		if first:
			_bends.insert(0, bend)
			_turns.insert(0, turn)
		else:
			_bends.append(bend)
			_turns.append(turn)
		_changed = true
	return false


## Each bend it's swung back off (straight across it, or turning the other way round it) let go: and if
## that would take it through something else, it's caught on that instead.
func _let_go(a: Vector2, b: Vector2) -> bool:
	var i := 0
	var guard := 0
	while i < _bends.size():
		guard += 1
		if guard > 32:
			return false
		var prev := a if i == 0 else _bends[i - 1]
		var next := b if i == _bends.size() - 1 else _bends[i + 1]
		if (_bends[i] - prev).cross(next - _bends[i]) * _turns[i] > 0.0:
			i += 1
			continue
		_changed = true
		if _clear(prev, next):
			_bends.remove_at(i)
			_turns.remove_at(i)
			i = maxi(i - 1, 0)
			continue
		var bend := _catch(prev, _bends[i], next)
		var turn := signf((bend - prev).cross(next - bend)) if bend != Vector2.INF else 0.0
		if turn == 0.0:
			return false
		_bends[i] = bend
		_turns[i] = turn
		i += 1
	return true


## Whether every stretch of it is clear, end to bend to bend to end.
func _sound(a: Vector2, b: Vector2) -> bool:
	var from := a
	for bend in _bends:
		if not _clear(from, bend):
			return false
		from = bend
	return _clear(from, b)


## The line from `fixed` swung from `p0` (where it's clear) round to `p1` (where it isn't): the corner
## it's first caught on, as a bend just outside it (_caught: how far through the swing), or INF.
func _catch(fixed: Vector2, p0: Vector2, p1: Vector2) -> Vector2:
	if not _clear(p0, fixed):
		return Vector2.INF
	var lo := 0.0
	var hi := 1.0
	for _i in 14:
		var m := (lo + hi) * 0.5
		if _clear(p0.lerp(p1, m), fixed):
			lo = m
		else:
			hi = m
	_caught = hi
	var hit := _hit(fixed, p0.lerp(p1, hi))
	return Vector2.INF if hit.is_empty() else _outside(hit.position)


## Just outside a corner, OFF from each side of it (which way is out: away from what's solid round it),
## or INF when there's no telling (inside something, or in a gap).
func _outside(corner: Vector2) -> Vector2:
	var solid := Vector2.ZERO
	for d in AROUND:
		_probe.position = corner + d * 1.5
		if not _space.intersect_point(_probe, 1).is_empty():
			solid += d
	if solid.length() < 0.2:
		return Vector2.INF
	var bend := corner - solid.normalized() * OFF * 1.4142
	return bend if _open(bend) else Vector2.INF


## Laid afresh from a to b: straight when nothing's between them, else round what is, the shortest way
## (looked for in steps, then pulled taut onto the corners it rests on). False if there's no way round.
func _lay(a: Vector2, b: Vector2) -> bool:
	_bends.clear()
	_turns.clear()
	_changed = true
	_fresh = true
	if _space == null or _clear(a, b):
		return true
	var steps := search(a, b, STEP, _open, LOOK, _clear)
	if steps.size() < 2:
		return false
	var way := PackedVector2Array([a])  # (pulled taut: from each, on to the furthest it can see)
	var i := 0
	while i < steps.size() - 1:
		var j := i + 1
		while j + 1 < steps.size() and _clear(steps[j + 1], steps[i]):
			j += 1
		way.append(steps[j])
		i = j
	var taut := PackedVector2Array([a])  # (each bend onto the corner it's by: or round the two of a thin
	for k in range(1, way.size() - 1):  # platform's end, the one seen from each side)
		var prev: Vector2 = taut[taut.size() - 1]
		var next: Vector2 = way[k + 1]
		var near := _catch(prev, way[k], next)
		var far := _catch(next, way[k], prev)
		if near != Vector2.INF and _clear(near, prev) and _clear(near, next):
			taut.append(near)
		elif near != Vector2.INF and far != Vector2.INF and _clear(near, prev) and _clear(near, far) and _clear(far, next):
			taut.append(near)
			taut.append(far)
		elif far != Vector2.INF and _clear(far, prev) and _clear(far, next):
			taut.append(far)
		else:
			taut.append(way[k])
	taut.append(b)
	for k in range(1, taut.size() - 1):
		_bends.append(taut[k])
		_turns.append(signf((taut[k] - taut[k - 1]).cross(taut[k + 1] - taut[k])))
	var m := 0
	while m < _bends.size():  # (and none it doesn't need)
		if _clear(a if m == 0 else _bends[m - 1], b if m == _bends.size() - 1 else _bends[m + 1]):
			_bends.remove_at(m)
			_turns.remove_at(m)
			m = maxi(m - 1, 0)
		else:
			m += 1
	return _let_go(a, b) and _sound(a, b)


## Whether nothing solid is between p and q.
func _clear(p: Vector2, q: Vector2) -> bool:
	return _space == null or _hit(p, q).is_empty()


## The first thing solid between p and q (cast from the higher of them down), or nothing. What either
## end is in doesn't count: a frog partway up through a platform is still reached.
func _hit(p: Vector2, q: Vector2) -> Dictionary:
	var from := p if p.y <= q.y else q
	var to := q if p.y <= q.y else p
	var dir := (to - from).normalized()
	for _i in 4:
		_ray.from = from  # (what the higher end's in, the ray doesn't see)
		_ray.to = to
		var hit := _space.intersect_ray(_ray)
		if hit.is_empty() or not _holds(hit, to):
			return hit
		from = hit.position + dir * 0.05  # (what the lower end's in: on through it to the end)
	return {}


## Whether what a ray hit holds the spot `at` too (it's what that end of the band is in).
func _holds(hit: Dictionary, at: Vector2) -> bool:
	_probe.position = at
	for other in _space.intersect_point(_probe, 8):
		if other.get("rid") == hit.get("rid") and other.get("shape") == hit.get("shape"):
			return true
	return false


func _open(p: Vector2) -> bool:
	_probe.position = p
	return _space.intersect_point(_probe, 1).is_empty()


# ── hanging ─────────────────────────────────────────────────────────────────────────────────────

## Its points hung along its way: held at its ends and bends, hanging between (each stretch as much rope
## as it's long, more when it's slack), resting on what's under them.
func _hang(slack: float, delta: float) -> void:
	var way := way()
	var lengths := PackedFloat32Array()
	var total := 0.0
	for i in range(way.size() - 1):
		lengths.append(way[i].distance_to(way[i + 1]))
		total += lengths[i]
	taut = clampf((total - slack * 0.5) / (slack * 0.5), 0.0, 1.0)
	if _changed or _pins.size() != way.size() or _pts.size() < 2:
		_share_out(way, lengths, total)
	# (a little more band than way while they're close, so it droops between them: a band, not a coil of
	# rope dangling off them; pulled straight past its slack)
	var give := maxf(1.0, minf(slack, total + maxf(12.0, total * 0.4)) / maxf(total, 0.001))
	var held := PackedByteArray()
	held.resize(_pts.size())
	for pin in _pins:
		held[pin] = 1
	var start := _pts.duplicate()  # (where each was: it moves only as far as it can get from there)
	var fall := Vector2(0.0, GRAVITY) * delta * delta
	for i in _pts.size():
		if held[i] == 0:
			var p := _pts[i]
			_pts[i] = p + (p - _old[i]) * DAMP + fall
			_old[i] = p
	for k in _pins.size():
		_pts[_pins[k]] = way[k]
		_old[_pins[k]] = way[k]
	for _s in SOLVE:
		for k in range(_pins.size() - 1):
			var rest := lengths[k] * give / float(_pins[k + 1] - _pins[k])
			for i in range(_pins[k], _pins[k + 1]):
				if held[i] == 1 and held[i + 1] == 1:
					continue
				var gap := _pts[i + 1] - _pts[i]
				var dist := gap.length()
				if dist < 0.0001:
					continue
				var pull := gap * ((dist - rest) / dist)
				if held[i] == 1:
					_pts[i + 1] -= pull
				elif held[i + 1] == 1:
					_pts[i] += pull
				else:
					_pts[i] += pull * 0.5
					_pts[i + 1] -= pull * 0.5
	if _space == null:
		return
	var line := _on_way(way)
	for i in _pts.size():
		if held[i] == 0:
			_settle(i, start[i], line[i])


## Its points shared out along its way afresh (each stretch from bend to bend its share, one at least):
## each where it was along the rope before (its shape kept) if that's in the open with a clear way to its
## place on the way; else on the way (and all on the way when it's been laid afresh: moved, not swung).
func _share_out(way: PackedVector2Array, lengths: PackedFloat32Array, total: float) -> void:
	var whole := maxf(total, 0.001)
	var fractions := PackedFloat32Array([0.0])
	var pins := PackedInt32Array([0])
	var done := 0.0
	for k in lengths.size():
		var n := maxi(1, roundi((POINTS - 1) * lengths[k] / whole))
		for s in range(1, n + 1):
			fractions.append((done + lengths[k] * float(s) / float(n)) / whole)
		done += lengths[k]
		pins.append(fractions.size() - 1)
	var pts := PackedVector2Array()
	var old := PackedVector2Array()
	for f in fractions:
		var on := along(way, f)
		if not _fresh and _pts.size() >= 2:
			var was := along(_pts, f)
			if _space == null or (_open(was) and _clear(was, on)):
				pts.append(was)
				old.append(along(_old, f))
				continue
		pts.append(on)
		old.append(on)
	_pts = pts
	_old = old
	_pins = pins


## Where each of its points would be on its way (straight from bend to bend): clear of everything.
func _on_way(way: PackedVector2Array) -> PackedVector2Array:
	var line := PackedVector2Array()
	line.resize(_pts.size())
	for k in range(_pins.size() - 1):
		var n := maxi(1, _pins[k + 1] - _pins[k])
		for i in range(_pins[k], _pins[k + 1] + 1):
			line[i] = way[k].lerp(way[k + 1], float(i - _pins[k]) / float(n))
	return line


## A hanging point moved only as far as it can get from where it was (stopped by anything in the way:
## it rests on it, or catches on its side); one that's somehow still in something goes onto its way.
func _settle(i: int, from: Vector2, on: Vector2) -> void:
	var p := _pts[i]
	_ray.from = from
	_ray.to = p
	var hit := _space.intersect_ray(_ray)
	if not hit.is_empty():
		p = hit.position + hit.normal * 0.5
		_old[i] = p  # (and stops there)
	if not _open(p):
		p = on
		_old[i] = p
	_pts[i] = p


## Rounder (Chaikin's corner cutting): each corner of the rope eased into a curve.
static func _smooth(line: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([line[0]])
	for i in range(line.size() - 1):
		out.append(line[i].lerp(line[i + 1], 0.25))
		out.append(line[i].lerp(line[i + 1], 0.75))
	out.append(line[line.size() - 1])
	return out


# ── his whole body, pulled along it ─────────────────────────────────────────────────────────────

## A way for a frog's whole body (`body`) from `from` to `to` (where he is: his spots), along `band`
## (a band's way, its first end at him): round each corner it's caught on, wide enough for him, every
## stretch one his body can make as he moves (up through a branch, never into anything); else the
## shortest way he fits, looked for in steps; else along the band anyway (he's moved only as he can go).
static func body_path(body: CharacterBody2D, from: Vector2, to: Vector2, band := PackedVector2Array()) -> PackedVector2Array:
	var shape := body.get_node("CollisionShape2D") as CollisionShape2D
	var size := shape.shape.get_rect().size * shape.global_scale.abs()
	var reach := maxf(size.x, size.y) * 0.5 + 2.0
	var centre := shape.global_position - body.global_position
	var way := PackedVector2Array([from])
	for i in range(1, band.size() - 1):
		var u := (band[i] - band[i - 1]).normalized()
		var v := (band[i + 1] - band[i]).normalized()
		var n_in := Vector2(-u.y, u.x)  # (out from the side it comes along)
		var n_out := Vector2(-v.y, v.x)  # (out from the side it goes on along)
		n_in *= -signf(n_in.dot(v))
		n_out *= signf(n_out.dot(u))
		if n_in == Vector2.ZERO or n_out == Vector2.ZERO:
			continue
		for n in [n_in, (n_in + n_out).normalized(), n_out]:
			way.append(band[i] + n * reach - centre)
	way.append(to)
	if goes(body, way):
		return way
	var space := body.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape.shape
	q.collision_mask = body.collision_mask
	q.exclude = [body.get_rid()]
	var fits := func(p: Vector2) -> bool:
		var xf := body.global_transform
		xf.origin = p
		q.transform = xf * shape.transform
		return space.intersect_shape(q, 1).is_empty()
	var steps := search(from, to, 8.0, fits, 2500)
	if steps.size() < 2:
		return way
	var out := PackedVector2Array([from])  # (straightened: on to the furthest he can go to)
	var i := 0
	while i < steps.size() - 1:
		var j := i + 1
		while j + 1 < steps.size() and goes(body, PackedVector2Array([steps[i], steps[j + 1]])):
			j += 1
		out.append(steps[j])
		i = j
	return out


## Whether his body can go along `way`, stretch by stretch, as he'd move (up through a branch, never
## into anything; coming to rest against something at the end of a stretch, on a ledge, is fine).
static func goes(body: PhysicsBody2D, way: PackedVector2Array) -> bool:
	for i in range(way.size() - 1):
		var move := way[i + 1] - way[i]
		var xf := body.global_transform
		xf.origin = way[i]
		if move.length() > 1.0 and body.test_move(xf, move * (1.0 - 1.0 / move.length())):
			return false
	return true


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


# ── looking for a way ───────────────────────────────────────────────────────────────────────────

## The shortest way (A*) from `from` to `to` through spots `fits` says yes
## to, in steps of `step`, eight ways round (never cutting a corner past one that doesn't fit; each
## step one `link` says yes to, when there's a link), looking at no more than `limit`: its spots from
## `from` to `to`, or nothing.
static func search(from: Vector2, to: Vector2, step: float, fits: Callable, limit: int, link := Callable()) -> PackedVector2Array:
	var goal := Vector2i(((to - from) / step).round())
	var heap := []
	var cost := {Vector2i.ZERO: 0.0}
	var came := {}
	var ok := {Vector2i.ZERO: true, goal: true}
	var shut := {}
	_push(heap, Vector2(goal).length(), Vector2i.ZERO)
	while not heap.is_empty() and shut.size() < limit:
		var at := _pop(heap)
		if shut.has(at):
			continue
		if at == goal:
			var cells := [at]
			while came.has(cells[cells.size() - 1]):
				cells.append(came[cells[cells.size() - 1]])
			cells.reverse()
			var out := PackedVector2Array()
			for c in cells:
				out.append(from + Vector2(c) * step)
			out[out.size() - 1] = to
			return out
		shut[at] = true
		var here: float = cost[at]
		for d in EIGHT:
			var next: Vector2i = at + d
			if shut.has(next) or not _fits_at(next, from, step, fits, ok):
				continue
			if d.x != 0 and d.y != 0 and not (_fits_at(at + Vector2i(d.x, 0), from, step, fits, ok) \
					and _fits_at(at + Vector2i(0, d.y), from, step, fits, ok)):
				continue
			var c := here + (1.4142 if d.x != 0 and d.y != 0 else 1.0)
			if c >= float(cost.get(next, INF)):
				continue
			if link.is_valid() and not link.call(from + Vector2(at) * step, to if next == goal else from + Vector2(next) * step):
				continue
			cost[next] = c
			came[next] = at
			_push(heap, c + Vector2(goal - next).length(), next)
	return PackedVector2Array()


static func _fits_at(cell: Vector2i, from: Vector2, step: float, fits: Callable, ok: Dictionary) -> bool:
	if not ok.has(cell):
		ok[cell] = fits.call(from + Vector2(cell) * step)
	return ok[cell]


static func _push(heap: Array, f: float, cell: Vector2i) -> void:
	heap.append(null)
	var i := heap.size() - 1
	while i > 0:
		var up := (i - 1) >> 1
		if heap[up][0] <= f:
			break
		heap[i] = heap[up]
		i = up
	heap[i] = [f, cell]


static func _pop(heap: Array) -> Vector2i:
	var top: Vector2i = heap[0][1]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	var n := heap.size()
	var i := 0
	while true:
		var l := i * 2 + 1
		if l >= n:
			break
		var c := l
		if l + 1 < n and heap[l + 1][0] < heap[l][0]:
			c = l + 1
		if heap[c][0] >= last[0]:
			break
		heap[i] = heap[c]
		i = c
	heap[i] = last
	return top
