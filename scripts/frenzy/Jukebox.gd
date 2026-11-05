extends RefCounted
## The Muse Jukebox (his jukebox site's own), drawn in pixels for Frog Frenzy: its indigo cabinet with the
## rounded top, white rim and periwinkle edge; MUSE across it in its grey-blue; its little screen's bars;
## the speaker grille; and, with a song on, its side lights lit and the pink and blue glow round it.

const RIM := Color(1.0, 1.0, 1.0)
const EDGE := Color(0.545, 0.608, 1.0)  # (#8b9bff)
const TOP := Color(0.192, 0.2, 0.361)  # (#31335c)
const LOW := Color(0.133, 0.141, 0.227)  # (#22243a)
const SHEEN := Color(0.588, 0.49, 1.0)  # (the lilac light on its top)
const GRILLE := Color(0.125, 0.133, 0.212)  # (#202236)
const HOLE := Color(0.05, 0.05, 0.09)
const TITLE := Color(0.66, 0.72, 0.80)
const PINK := Color(1.0, 0.478, 0.851)  # (its glow: #ff7ad9)
const CYAN := Color(0.431, 0.906, 1.0)  # (#6ee7ff)
const WIDE := 100.0
const TALL := 96.0
const ROUND := 18.0


## Its box when it stands on `foot` (the middle of its bottom).
static func box(foot: Vector2) -> Rect2:
	return Rect2(foot.x - WIDE * 0.5, foot.y - TALL, WIDE, TALL)


## The jukebox standing on `foot`; `playing` 0 to 1, how far its song's come in.
static func draw(on: CanvasItem, foot: Vector2, t: float, playing: float) -> void:
	var b := box(foot)
	if playing > 0.0:  # (its glow: pink up top, blue low down)
		for i in 4:
			var k := 1.0 - i / 4.0
			on.draw_circle(Vector2(foot.x, b.position.y + 24.0), 44.0 + i * 12.0, Color(PINK, 0.07 * playing * k))
			on.draw_circle(Vector2(foot.x, foot.y - 22.0), 44.0 + i * 12.0, Color(CYAN, 0.06 * playing * k))
	_rounded(on, b.grow(3.0), ROUND + 3.0, RIM, RIM)
	_rounded(on, b.grow(1.0), ROUND + 1.0, EDGE, EDGE)
	_rounded(on, b, ROUND, TOP, LOW)
	for y in 10:  # (the lilac sheen on its top)
		var w := (WIDE - 30.0) * (1.0 - y / 10.0)
		on.draw_rect(Rect2(foot.x - w * 0.5, b.position.y + 2.0 + y, w, 1.0), Color(SHEEN, 0.16 * (1.0 - y / 10.0)))
	var font: Font = load("res://assets/fibberish.ttf")
	var title := Vector2(b.position.x, b.position.y + 27.0)
	on.draw_string_outline(font, title, "MUSE", HORIZONTAL_ALIGNMENT_CENTER, WIDE, 16, 4, Color(0.06, 0.06, 0.12))
	on.draw_string(font, title, "MUSE", HORIZONTAL_ALIGNMENT_CENTER, WIDE, 16, TITLE)
	# Its screen, its bars dancing to the song.
	var screen := Rect2(b.position.x + 22.0, b.position.y + 34.0, WIDE - 44.0, 22.0)
	on.draw_rect(screen.grow(1.0), Color(EDGE, 0.5))
	on.draw_rect(screen, HOLE)
	for i in 7:
		var dance := 0.5 + 0.5 * sin(t * (7.0 + i * 0.9) + i * 1.3)
		var tall := roundf(2.0 + playing * dance * 16.0)
		var col := PINK.lerp(CYAN, i / 6.0)
		on.draw_rect(Rect2(screen.position.x + 4.0 + i * 7.0, screen.end.y - 2.0 - tall, 5.0, tall), Color(col, 0.35 + 0.65 * playing))
	# Its side lights, lit with a song, cycling.
	for side in [b.position.x + 6.0, b.end.x - 9.0]:
		for i in 6:
			var hue := fposmod(0.85 + i * 0.05 + t * 0.2, 1.0)
			var lit := Color.from_hsv(hue, 0.5, 1.0).lerp(Color(0.3, 0.32, 0.5), 1.0 - playing)
			on.draw_rect(Rect2(side, b.position.y + 30.0 + i * 8.0, 3.0, 6.0), lit)
	# The speaker grille.
	var grille := Rect2(b.position.x + 12.0, b.end.y - 30.0, WIDE - 24.0, 18.0)
	on.draw_rect(grille.grow(1.0), Color(EDGE, 0.25))
	on.draw_rect(grille, GRILLE)
	var x := grille.position.x + 2.0
	while x < grille.end.x - 1.0:
		var y := grille.position.y + 2.0
		while y < grille.end.y - 1.0:
			on.draw_rect(Rect2(x, y, 1.0, 1.0), HOLE)
			y += 3.0
		x += 3.0
	# The slot on top a record goes into.
	on.draw_rect(Rect2(foot.x - 22.0, b.position.y - 1.0, 44.0, 3.0), HOLE)


## A box with its top corners rounded `r` (in whole pixels, a row at a time), `top` colour to `bottom`.
static func _rounded(on: CanvasItem, b: Rect2, r: float, top: Color, bottom: Color) -> void:
	var rows := int(b.size.y)
	for y in rows:
		var inset := 0.0
		if y < r:
			var dy := r - y - 0.5
			inset = ceilf(r - sqrt(maxf(0.0, r * r - dy * dy)))
		on.draw_rect(Rect2(b.position.x + inset, b.position.y + y, b.size.x - inset * 2.0, 1.0), top.lerp(bottom, float(y) / rows))
