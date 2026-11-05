extends Control
## "Tap to go on": a little arrow, bobbing gently, under words that are all there and wait for a tap (the
## frog god's in the intro, CreatorIntro; the TV's as he wakes up, Main). It comes in a moment after
## they're all there (shown), softly, and goes at once. Drawn in pixels, `pixel` of the screen's (or the
## world's) each, 7 across and 4 down, with a dark edge.

const SHAPE := [".#######.", "#CCCCCCC#", ".#CCCCC#.", "..#CCC#..", "...#C#...", "....#...."]

var shown := false
var pixel := 2.0
var colour := Color(0.97, 0.92, 0.80)
var edge := Color(0.10, 0.08, 0.12)
var _clock := 0.0
var _waited := 0.0
var _in := 0.0  # (how far it's come in: 0 to 1)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func _process(delta: float) -> void:
	_clock += delta
	if shown:
		_waited += delta
		if _waited > 0.4:  # (not between quick taps: once the words have had a moment)
			_in = move_toward(_in, 1.0, delta * 2.5)
	else:
		_waited = 0.0
		_in = 0.0
	modulate.a = smoothstep(0.0, 1.0, _in)  # (softly in, and softly to full)
	custom_minimum_size = Vector2(9, 7) * pixel
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	if modulate.a <= 0.0:
		return
	var bob := roundf(sin(_clock * 3.2) * 1.0 + 0.5) * pixel  # (down a pixel and back, slowly)
	for y in SHAPE.size():
		var row: String = SHAPE[y]
		for x in row.length():
			var c := row[x]
			if c == ".":
				continue
			draw_rect(Rect2(Vector2(x, y) * pixel + Vector2(0, bob), Vector2(pixel, pixel)), colour if c == "C" else edge)
