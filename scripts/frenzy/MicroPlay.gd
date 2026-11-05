extends "res://scripts/frenzy/Micro.gd"
## PLAY! The Muse Jukebox (Jukebox.gd), sliding to and fro across the floor, idling on its blue-to-purple
## glow. He's up on a shelf: jump down onto it (his own jump) and it plays: its lights come on, the notes
## come up out of it and its starry sky fades in, as the jukebox site's does with a song on (SparkleSky).
## Land on the floor instead and there's no song.

const FLOOR_Y := 62.0
const NOTES := [[".##", ".#.", "##.", "##."], ["..##", "..#.", "###.", "##.."]]

var _top: StaticBody2D  # (the jukebox's top, to land on: it slides with it)
var _floor: StaticBody2D
var _x := 0.0
var _phase := 0.0  # (where in its swing it starts: over the far side from him)
var _landed := -1.0
var _notes := []  # [which, x, born]
var _stars := []
var _mark: Label


func begin() -> void:
	word = "PLAY!"
	seconds = 4.6
	uses_froggy = true
	view = Rect2(-120.0, -175.0, 240.0, 240.0)
	_stars = load("res://scripts/SparkleSky.gd").make_stars(80, rng.randi())
	_floor = floor_at(Vector2(0.0, FLOOR_Y), 260.0)
	var juke: GDScript = load("res://scripts/frenzy/Jukebox.gd")
	_top = floor_at(Vector2(0.0, juke.box(Vector2(0.0, FLOOR_Y)).position.y), 96.0)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var shelf := Vector2(-80.0 * side, -70.0)
	floor_at(shelf, 56.0)
	froggy_at = shelf + Vector2(0.0, -FEET)
	set_meta("shelf", shelf)
	_phase = PI * 0.5 * side
	_x = slide_x(0.0)


func step(delta: float) -> void:
	super.step(delta)
	queue_redraw()
	if _landed < 0.0:
		var before := _top.position
		_x = slide_x(t)
		_top.position.x = _x
		_top.constant_linear_velocity = (_top.position - before) / maxf(delta, 0.001)
		if froggy_on(_top) and not won and not lost:
			_landed = t
			_top.constant_linear_velocity = Vector2.ZERO
			play("res://assets/coolfind.mp3", 1.0, -8.0)
			win()
		elif froggy_on(_floor) and not won and not lost:
			_mark = mark("...", Color(0.8, 0.85, 1.0))
			lose()
	elif rng.randf() < delta * 5.0:
		_notes.append([rng.randi_range(0, 1), _x + rng.randf_range(-40.0, 30.0), t])
	if _mark and froggy:
		_mark.position = (froggy.global_position + Vector2(-_mark.size.x * 0.5, -40.0)).round()


## Where the jukebox is, `at` seconds in: sliding to and fro.
func slide_x(at: float) -> float:
	return sin(at * 1.5 * speed + _phase) * 85.0


func _night() -> float:
	return smoothstep(0.0, 0.7, t - _landed) if _landed >= 0.0 else 0.0


func _draw() -> void:
	var sky: GDScript = load("res://scripts/SparkleSky.gd")
	var all := view.grow(20.0)
	var night := _night()
	if night < 1.0:
		sky.draw_idle(self, all)
	if night > 0.0:
		sky.draw_backdrop(self, all, night)
		sky.draw_stars(self, all, _stars, t, 1.0, night)
	draw_rect(Rect2(all.position.x, FLOOR_Y, all.size.x, all.end.y - FLOOR_Y), Color(0.13, 0.11, 0.24))  # (the floor)
	draw_rect(Rect2(all.position.x, FLOOR_Y, all.size.x, 2.0), Color(0.55, 0.6, 1.0, 0.6))
	var shelf: Vector2 = get_meta("shelf", Vector2.ZERO)  # (his shelf)
	draw_rect(Rect2(shelf + Vector2(-28.0, 0.0), Vector2(56.0, 5.0)), Color(0.46, 0.31, 0.18))
	draw_rect(Rect2(shelf + Vector2(-28.0, 5.0), Vector2(56.0, 2.0)), Color(0.17, 0.10, 0.05))
	load("res://scripts/frenzy/Jukebox.gd").draw(self, Vector2(_x, FLOOR_Y), t, night)
	for n in _notes:  # (the song, up out of it)
		var age: float = t - float(n[2])
		var pattern: Array = NOTES[int(n[0]) % NOTES.size()]
		var at := Vector2(float(n[1]), _top.position.y - 26.0 - age * 40.0).round()
		var col := Color(1.0, 0.85, 0.95, clampf(1.0 - age, 0.0, 1.0))
		for y in pattern.size():
			for x in str(pattern[y]).length():
				if str(pattern[y])[x] == "#":
					draw_rect(Rect2(at + Vector2(x * 2, y * 2), Vector2(2, 2)), col)
