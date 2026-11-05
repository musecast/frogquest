extends "res://scripts/frenzy/Micro.gd"
## DROP! The Muse Jukebox (Jukebox.gd), its idle glow behind it: a record (the Muse TV's own) slides back
## and forth over it; tap to drop it. Into the slot on top and it plays: the jukebox lights up and its
## starry sky fades in behind (SparkleSky), as the jukebox site's does with a song on. Miss, and it
## bounces off.

const FOOT := Vector2(120.0, 234.0)  # (where the jukebox stands)
const NOTES := [[".##", ".#.", "##.", "##."], ["..##", "..#.", "###.", "##.."]]

var _sky: Node2D
var _record: Sprite2D
var _box: Node2D
var _top := 0.0  # (the slot's height)
var _dropped := -1.0
var _fall := 0.0
var _landed := -1.0
var _notes := []  # [which, x, born]
var _stars := []


func begin() -> void:
	word = "DROP!"
	seconds = 3.6
	var juke: GDScript = load("res://scripts/frenzy/Jukebox.gd")
	_top = juke.box(FOOT).position.y
	_stars = load("res://scripts/SparkleSky.gd").make_stars(70, rng.randi())
	_sky = Node2D.new()  # (first, so it's drawn under everything: a z below the stage's would go under its colour)
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	_record = sprite("res://assets/record.png", Vector2(FOOT.x, 52.0), 40.0)
	_record.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # (the TV's record's a picture)
	_box = Node2D.new()
	_box.z_index = 1  # (over the record once it's down in the slot)
	_box.draw.connect(_draw_box)
	add_child(_box)


## Behind it all: the jukebox's idle glow, and its starry sky coming in once the record's playing.
func _draw_sky() -> void:
	var sky: GDScript = load("res://scripts/SparkleSky.gd")
	var all := Rect2(0.0, 0.0, STAGE, STAGE)
	var night := _night()
	if night < 1.0:
		sky.draw_idle(_sky, all)
	if night > 0.0:
		sky.draw_backdrop(_sky, all, night)
		sky.draw_stars(_sky, all, _stars, t, 1.0, night)


func _night() -> float:
	return smoothstep(0.0, 0.7, t - _landed) if _landed >= 0.0 else 0.0


func _draw_box() -> void:
	load("res://scripts/frenzy/Jukebox.gd").draw(_box, FOOT, t, _night())
	for n in _notes:  # (the song, up out of it)
		var age: float = t - float(n[2])
		var pattern: Array = NOTES[int(n[0]) % NOTES.size()]
		var at := Vector2(float(n[1]), _top - 30.0 - age * 40.0).round()
		var col := Color(1.0, 0.85, 0.95, clampf(1.0 - age, 0.0, 1.0))
		for y in pattern.size():
			for x in str(pattern[y]).length():
				if str(pattern[y])[x] == "#":
					_box.draw_rect(Rect2(at + Vector2(x * 2, y * 2), Vector2(2, 2)), col)


func press(_at: Vector2) -> void:
	if _dropped < 0.0 and not won and not lost:
		_dropped = t
		play("res://assets/frogjump.wav", 1.3, -12.0)


func step(delta: float) -> void:
	super.step(delta)
	_sky.queue_redraw()
	_box.queue_redraw()
	if _dropped < 0.0:
		_record.position.x = FOOT.x + sin(t * 2.6 * speed) * 92.0
		_record.rotation += delta * 3.0
		return
	if _landed >= 0.0:
		_record.rotation += delta * 9.0  # (playing)
		_record.position.y = lerpf(_record.position.y, _top + 4.0, 1.0 - exp(-delta * 10.0))
		if rng.randf() < delta * 5.0:
			_notes.append([rng.randi_range(0, 1), FOOT.x + rng.randf_range(-40.0, 30.0), t])
		return
	_fall += 900.0 * delta
	_record.position.y += _fall * delta
	if not lost and _record.position.y >= _top - 6.0:
		var off := absf(_record.position.x - FOOT.x)
		if off <= 16.0:
			_landed = t
			_record.position = Vector2(FOOT.x, _top - 6.0)  # (down into the slot, behind the jukebox's front)
			play("res://assets/coolfind.mp3", 1.0, -8.0)
			win()
		else:
			_record.z_index = 2  # (in front of the jukebox, falling past it)
			if off <= 54.0:
				_fall = -260.0  # (it bounces off the top)
				play("res://assets/glasshurt.wav", 1.2, -12.0)
			lose()
