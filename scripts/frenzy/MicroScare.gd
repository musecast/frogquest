extends "res://scripts/frenzy/Micro.gd"
## SCARE! In Froggy's bedroom (the story's own: scenes/frenzy/Bedroom.tscn), the little girl froggy (her
## picture's on his shelf) is in his beanbag watching the Muse TV, and he's in it: in the movie, behind the
## glass. Now and then she leans in close, curious. Jump out at her then (his own jump: drag back, let go)
## and he bursts out of the screen and she leaps back, scared silly. Jump while she's sat back and she just
## watches him come.

const HER_BODY := {"body": "a4ffb0", "belly": "f6fdcd"}  # (as in her picture: bae.png)
const LEAN_IN := 0.6  # (how far leaned in she has to be)

var _room: Node2D
var _tv: Sprite2D
var _screen := Rect2()  # (the TV's glass, in its world)
var _her: Sprite2D
var _her_home := Vector2.ZERO
var _lean := 0.0  # (0 sat back, 1 right up to the screen)
var _leans := []  # [start, leaned in, still leaning, sat back] of each lean, in seconds
var _out := -1.0  # (when he burst out of the screen)
var _scared := false
var _shards := []  # [where, which way]
var _mark: Label


func begin() -> void:
	word = "SCARE!"
	seconds = 5.0
	uses_froggy = true
	view = Rect2(-150.0, -135.0, 300.0, 300.0)
	_room = (load("res://scenes/frenzy/Bedroom.tscn") as PackedScene).instantiate()
	add_child(_room)
	_tv = _room.get_node("Musecrtquarterview")
	for quiet in ["AudioStreamPlayer2D", "Record", "Recordshadow"]:  # (no song, no record: a movie's on)
		var n := _tv.get_node_or_null(quiet)
		if n:
			n.queue_free()
	var glass: ColorRect = _tv.get_node("ColorRect")
	glass.material = null
	glass.color = Color(0.07, 0.07, 0.14)
	glass.z_as_relative = false
	glass.z_index = 3
	_tv.z_as_relative = false
	_tv.z_index = 5  # (its frame over him while he's in it)
	var k: float = _tv.scale.x
	_screen = Rect2(_tv.position + Vector2(glass.offset_left, glass.offset_top) * k,
		Vector2(glass.offset_right - glass.offset_left, glass.offset_bottom - glass.offset_top) * k)
	# (In the story the TV fills a nook of solid wall: the room's end. Here he's in it: the wall's gone from
	# behind the glass, where the TV hides it anyway.)
	var map: TileMap = _room.get_node("TileMap")
	for layer in map.get_layers_count():
		for cell in map.get_used_cells(layer):
			if _screen.has_point(map.position + map.map_to_local(cell) * map.scale):
				map.erase_cell(layer, cell)
	var ledge := floor_at(Vector2(_screen.get_center().x, _screen.end.y - 6.0), _screen.size.x - 8.0)  # (the bottom of the picture)
	ledge.name = "InTheTV"
	froggy_at = Vector2(_screen.get_center().x + 6.0, _screen.end.y - 6.0 - FEET)
	var beanbag: Node2D = _room.get_node("Beanbag")
	_her_home = beanbag.position + Vector2(4.0, -10.0)
	_her = frog(_her_home, 24.0, HER_BODY)
	var bow := Node2D.new()
	bow.draw.connect(func() -> void:  # (her red bow and her red lips, as in the picture)
		for r in [Rect2(4, -16, 3, 3), Rect2(7, -15, 2, 2), Rect2(9, -16, 3, 3), Rect2(-2, -7, 4, 1)]:
			bow.draw_rect(r, Color(0.851, 0.341, 0.388)))
	_her.add_child(bow)
	var at := rng.randf_range(0.4, 0.9)
	while at < 8.0:  # (her leans in, each a little different)
		var lean_in := rng.randf_range(0.45, 0.65) / speed
		var hold := rng.randf_range(0.5, 0.7) / speed
		_leans.append([at, at + lean_in, at + lean_in + hold, at + lean_in * 2.0 + hold])
		at += lean_in * 2.0 + hold + rng.randf_range(0.3, 0.7) / speed


## (Frenzy, once he's put in: in the TV, behind its frame.)
func froggy_placed() -> void:
	froggy.z_index = 4


func step(delta: float) -> void:
	super.step(delta)
	queue_redraw()
	if _out < 0.0 and froggy and not _screen.grow(2.0).has_point(froggy.global_position):
		_burst()
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
		_her.position = _her_home + Vector2(10.0 * _lean, -2.0 * _lean)
		_her.rotation = 0.2 * _lean
	else:  # (she leaps back out of the beanbag, and lands)
		var since := t - _out
		var hop := clampf(since / 0.55, 0.0, 1.0)
		_her.position = _her_home + Vector2(-26.0 * smoothstep(0.0, 1.0, hop), -30.0 * sin(hop * PI))
		_her.rotation = lerp_angle(_her.rotation, -0.4 * (1.0 - hop), 1.0 - exp(-delta * 10.0))
	for s in _shards:
		s[1].y += 500.0 * delta
		s[0] += s[1] * delta
	if _mark:
		_mark.position = (_her.position + Vector2(-_mark.size.x * 0.5, -34.0)).round()


## Out of the screen: the glass goes, and she's scared if she was leaned right in.
func _burst() -> void:
	_out = t
	froggy.z_index = 6
	play("res://assets/glassbreak.mp3", 1.2, -10.0)
	for i in 10:
		var from := Vector2(_screen.position.x + 2.0, rng.randf_range(_screen.position.y, _screen.end.y))
		_shards.append([from, Vector2(rng.randf_range(-160.0, -40.0), rng.randf_range(-160.0, 20.0))])
	if won or lost:
		return
	if _lean >= LEAN_IN:
		_scared = true
		_mark = mark("!!", Color(1.0, 0.3, 0.25))
		play("res://assets/exclaim.wav", 1.3, -6.0)
		win()
	else:
		_mark = mark("...", Color(0.8, 0.85, 1.0))
		lose()


func _draw() -> void:
	for s in _shards:  # (bits of the glass)
		var age := t - _out
		if age < 0.9:
			draw_rect(Rect2((s[0] as Vector2).round(), Vector2(2, 2)), Color(0.75, 0.88, 1.0, 1.0 - age / 0.9))
