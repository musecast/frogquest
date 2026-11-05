extends "res://scripts/frenzy/Micro.gd"
## SCARE! He's in the movie on the Muse TV, and the little girl froggy (her picture's on his shelf) is
## watching it from his beanbag, leaning in closer now and then, curious. Tap while she's leaning right up
## to the screen and he bursts out of it: she leaps back, scared silly. Tap while she's sat back and he only
## gets as far as the glass.

const SCREEN := Vector2(170.0, 124.0)  # (the middle of the TV's screen, on the stage)
const HER_HOME := Vector2(64.0, 150.0)

var _her: Sprite2D
var _movie: Node2D
var _him: Sprite2D
var _lean := 0.0  # (0 sat back, 1 right up to the screen)
var _leans := []  # [start, peak, hold, end] of each lean in, in seconds
var _burst := -1.0
var _scared := false
var _mark: Label


func begin() -> void:
	word = "SCARE!"
	seconds = 4.0
	sprite("res://assets/beanbag.png", Vector2(60.0, 178.0), 56.0)
	_her = frog(HER_HOME, 44.0, {"body": "a4ffb0", "belly": "f6fdcd"})  # (the girl in the picture: bae.png)
	var bow := Node2D.new()
	bow.draw.connect(func() -> void:  # (her red bow and her red lips, as in the picture)
		for r in [Rect2(4, -16, 3, 3), Rect2(7, -15, 2, 2), Rect2(9, -16, 3, 3), Rect2(-2, -7, 4, 1)]:
			bow.draw_rect(r, Color(0.851, 0.341, 0.388)))
	_her.add_child(bow)
	_movie = Node2D.new()  # (the movie, behind the TV's glass: dark, him in it, coming closer)
	_movie.draw.connect(_draw_movie)
	add_child(_movie)
	sprite("res://assets/musecrtquarterview.png", Vector2(176.0, 132.0), 96.0)
	_him = frog(SCREEN, 14.0)
	_him.modulate = Color(0.75, 0.8, 1.0, 0.9)
	var at := rng.randf_range(0.35, 0.8)
	while at < 6.0:  # (her leans in, each a little different)
		var lean_in := rng.randf_range(0.45, 0.65) / speed
		var hold := rng.randf_range(0.4, 0.6) / speed
		_leans.append([at, at + lean_in, at + lean_in + hold, at + lean_in * 2.0 + hold])
		at += lean_in * 2.0 + hold + rng.randf_range(0.25, 0.6) / speed
	_mark = Label.new()
	_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load("res://scripts/UIStyle.gd").style_label(_mark, 16, Color(1.0, 0.3, 0.25))
	_mark.visible = false
	add_child(_mark)


func _draw_movie() -> void:
	_movie.draw_rect(Rect2(SCREEN - Vector2(30, 24), Vector2(60, 48)), Color(0.08, 0.08, 0.14))
	for i in 10:  # (a little static)
		var p := SCREEN + Vector2(fmod(i * 23.0 + t * 90.0, 56.0) - 28.0, fmod(i * 17.0 + t * 40.0, 44.0) - 22.0)
		_movie.draw_rect(Rect2(p.round(), Vector2(2, 1)), Color(0.6, 0.65, 0.8, 0.5))


func press(_at: Vector2) -> void:
	if _burst >= 0.0 or won or lost:
		return
	_burst = t
	_scared = _lean > 0.7
	play("res://assets/appear.mp3", 1.3, -10.0)


func step(delta: float) -> void:
	super.step(delta)
	_movie.queue_redraw()
	if not _scared:
		var want := 0.0
		for l in _leans:
			if t >= l[0] and t < l[3]:
				if t < l[1]:
					want = smoothstep(l[0], l[1], t)
				elif t < l[2]:
					want = 1.0
				else:
					want = 1.0 - smoothstep(l[2], l[3], t)
		_lean = want
		_her.position = HER_HOME + Vector2(26.0 * _lean, -4.0 * _lean)
		_her.rotation = 0.22 * _lean
	if _burst >= 0.0:
		var k := smoothstep(0.0, 0.22, t - _burst)  # (out of the screen, and big)
		var to := HER_HOME + Vector2(40.0 + 26.0 * _lean, -6.0) if _scared else SCREEN + Vector2(-8.0, 0.0)
		_him.position = SCREEN.lerp(to, k)
		var tall := lerpf(14.0, 52.0 if _scared else 22.0, k)
		_him.scale = Vector2.ONE * tall / 32.0
		_him.modulate = Color(1, 1, 1, 1).lerp(Color(0.75, 0.8, 1.0, 0.9), 1.0 - k)
		if k >= 1.0 and not won and not lost:
			if _scared:
				_mark.text = "!!"
				_mark.visible = true
				play("res://assets/exclaim.wav", 1.3, -6.0)
				win()
			else:
				_mark.text = "..."
				_mark.visible = true
				lose()
	if won:  # (she leaps back off the beanbag)
		var since := t - _burst - 0.22
		_her.position = HER_HOME + Vector2(-14.0 * smoothstep(0.0, 0.3, since), -28.0 * sin(clampf(since / 0.5, 0.0, 1.0) * PI))
		_her.rotation = lerpf(_her.rotation, -0.5, 0.2)
	if _mark.visible:
		_mark.size = _mark.get_minimum_size()
		_mark.position = (_her.position + Vector2(-_mark.size.x * 0.5, -48.0)).round()
