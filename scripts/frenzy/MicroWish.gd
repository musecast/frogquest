extends "res://scripts/frenzy/Micro.gd"
## WISH! Up on the Muse Jukebox with a song on, under its starry sky (SparkleSky, the sky the jukebox site
## fades into when it plays), Froggy's watching for a shooting star. Tap it before it's gone: it bursts
## into sparkles and he hops. Too slow and it's away over the edge.

const FOOT := Vector2(120.0, 238.0)  # (where the jukebox stands)
const REACH := 24.0  # (how near the star a tap has to be)

var _sky: Node2D
var _him: Sprite2D
var _box: Node2D
var _stars := []
var _from := Vector2.ZERO
var _way := Vector2.ZERO
var _comes := 0.0  # (when it shoots across)
var _star := Vector2(-100.0, -100.0)
var _caught := -1.0
var _bits := []  # [way, colour] of its sparkles, once caught
var _mark: Label


func begin() -> void:
	word = "WISH!"
	seconds = 3.6
	var sky: GDScript = load("res://scripts/SparkleSky.gd")
	_stars = sky.make_stars(90, rng.randi())
	_sky = Node2D.new()
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	_box = Node2D.new()
	_box.draw.connect(func() -> void: load("res://scripts/frenzy/Jukebox.gd").draw(_box, FOOT, t, 1.0))
	add_child(_box)
	var top: float = load("res://scripts/frenzy/Jukebox.gd").box(FOOT).position.y
	_him = frog(Vector2(FOOT.x, top - 15.0), 32.0)
	_comes = rng.randf_range(0.25, 0.9) / speed
	var left := rng.randf() < 0.5
	_from = Vector2(-12.0 if left else STAGE + 12.0, rng.randf_range(16.0, 56.0))
	_way = Vector2(1.0 if left else -1.0, rng.randf_range(0.10, 0.28)).normalized() * 150.0 * speed  # (over his head)
	for i in 10:
		_bits.append([Vector2.from_angle(TAU * i / 10.0 + rng.randf() * 0.3) * rng.randf_range(40.0, 70.0),
			sky.COLOURS[rng.randi_range(0, 4)]])
	_mark = Label.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load("res://scripts/UIStyle.gd").style_label(_mark, 16, Color(0.8, 0.85, 1.0))
	_mark.visible = false
	add_child(_mark)


func _draw_sky() -> void:
	var sky: GDScript = load("res://scripts/SparkleSky.gd")
	var all := Rect2(0.0, 0.0, STAGE, STAGE)
	sky.draw_backdrop(_sky, all)
	sky.draw_stars(_sky, all, _stars, t, 1.0, 1.0, Vector2(t * 2.0, 0.0))
	if _caught >= 0.0:  # (it bursts: sparkles flying out, fading)
		var age := t - _caught
		var k := smoothstep(0.0, 0.6, age)
		for b in _bits:
			var at: Vector2 = (_star + b[0] * k).round()
			sky.sparkle(_sky, at, b[1], 1.0 - k, 1.0, 1.0 - k)
		return
	if t < _comes or not _on_stage():
		return
	for i in 14:  # (its tail, behind it, fading)
		var back := _star - _way.normalized() * i * 3.0
		_sky.draw_rect(Rect2(back.round(), Vector2(2, 2) if i < 5 else Vector2(1, 1)), Color(1.0, 0.95, 0.8, 0.9 * (1.0 - i / 14.0)))
	sky.sparkle(_sky, _star.round(), Color(1.0, 0.98, 0.85), 0.5 + 0.5 * sin(t * 30.0), 1.0, 1.0)


func _on_stage() -> bool:
	return _star.x > -16.0 and _star.x < STAGE + 16.0


func press(at: Vector2) -> void:
	if won or lost or t < _comes or not _on_stage():
		return
	if at.distance_to(_star) <= REACH:
		_caught = t
		play("res://assets/pickupCoin.wav", 1.4, -8.0)
		win()


func step(delta: float) -> void:
	super.step(delta)
	_sky.queue_redraw()
	_box.queue_redraw()
	if _caught < 0.0 and t >= _comes:
		_star = _from + _way * (t - _comes)
		if not lost and not _on_stage():
			_mark.text = "..."
			_mark.visible = true
			lose()
	var top: float = load("res://scripts/frenzy/Jukebox.gd").box(FOOT).position.y
	if _caught >= 0.0:  # (he hops for joy)
		var hop := clampf((t - _caught) / 0.45, 0.0, 1.0)
		_him.position.y = top - 15.0 - sin(hop * PI) * 18.0
	if _mark.visible:
		_mark.size = _mark.get_minimum_size()
		_mark.position = (_him.position + Vector2(-_mark.size.x * 0.5, -36.0)).round()
