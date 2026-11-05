extends "res://scripts/frenzy/Micro.gd"
## WISH! Up on the Muse Jukebox with a song on, under its starry sky (SparkleSky, the sky the jukebox site
## fades into when it plays): a shooting star comes over. Jump up into it (his own jump) before it's gone:
## it bursts into sparkles. Too slow and it's away over the edge.

const FOOT := Vector2(0.0, 62.0)  # (where the jukebox stands)
const REACH := 20.0

var _stars := []
var _from := Vector2.ZERO
var _way := Vector2.ZERO
var _comes := 0.0  # (when it shoots over)
var _star := Vector2(-999.0, -999.0)
var _caught := -1.0
var _bits := []  # [way, colour] of its sparkles, once caught
var _mark: Label


func begin() -> void:
	word = "WISH!"
	seconds = 4.4
	uses_froggy = true
	view = Rect2(-120.0, -175.0, 240.0, 240.0)
	var sky: GDScript = load("res://scripts/SparkleSky.gd")
	_stars = sky.make_stars(90, rng.randi())
	var top: float = load("res://scripts/frenzy/Jukebox.gd").box(FOOT).position.y
	floor_at(Vector2(FOOT.x, top), 96.0)
	froggy_at = Vector2(FOOT.x, top - FEET)
	_comes = rng.randf_range(0.3, 0.9) / speed
	var left := rng.randf() < 0.5
	_from = Vector2(view.position.x - 12.0 if left else view.end.x + 12.0, top - rng.randf_range(72.0, 92.0))
	_way = Vector2(1.0 if left else -1.0, rng.randf_range(0.0, 0.12)).normalized() * 95.0 * speed  # (over his head)
	for i in 10:
		_bits.append([Vector2.from_angle(TAU * i / 10.0 + rng.randf() * 0.3) * rng.randf_range(26.0, 46.0),
			sky.COLOURS[rng.randi_range(0, 4)]])


func _on_screen() -> bool:
	return _star.x > view.position.x - 16.0 and _star.x < view.end.x + 16.0


func step(delta: float) -> void:
	super.step(delta)
	queue_redraw()
	if _caught < 0.0 and t >= _comes:
		_star = _from + _way * (t - _comes)
		if froggy_near(_star, REACH) and not won and not lost:
			_caught = t
			play("res://assets/pickupCoin.wav", 1.4, -8.0)
			win()
		elif not lost and not won and not _on_screen():
			_mark = mark("...", Color(0.8, 0.85, 1.0))
			lose()
	if _mark and froggy:
		_mark.position = (froggy.global_position + Vector2(-_mark.size.x * 0.5, -40.0)).round()


func _draw() -> void:
	var sky: GDScript = load("res://scripts/SparkleSky.gd")
	var all := view.grow(20.0)
	sky.draw_backdrop(self, all)
	sky.draw_stars(self, all, _stars, t, 1.0, 1.0, Vector2(t * 2.0, 0.0))
	load("res://scripts/frenzy/Jukebox.gd").draw(self, FOOT, t, 1.0)
	if _caught >= 0.0:  # (it bursts: sparkles flying out, fading)
		var k := smoothstep(0.0, 0.6, t - _caught)
		for b in _bits:
			sky.sparkle(self, (_star + b[0] * k).round(), b[1], 1.0 - k, 1.0, 1.0 - k)
		return
	if t < _comes or not _on_screen():
		return
	for i in 14:  # (its tail, behind it, fading)
		var back := _star - _way.normalized() * i * 3.0
		draw_rect(Rect2(back.round(), Vector2(2, 2) if i < 5 else Vector2(1, 1)), Color(1.0, 0.95, 0.8, 0.9 * (1.0 - i / 14.0)))
	sky.sparkle(self, _star.round(), Color(1.0, 0.98, 0.85), 0.5 + 0.5 * sin(t * 30.0), 1.0, 1.0)
