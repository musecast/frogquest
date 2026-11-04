extends Control
## A palette to choose a colour from: little squares in rows, tapped (or a finger slid across them), a
## frame gliding to the one that's chosen. The frog god's (CreatorIntro: your skin, eyes and belly) and
## Play Together's (PartyScreen: your band). Its squares fill its width; given a height, they fit that too.

signal picked
const EDGE := Color(0.10, 0.08, 0.12)
const FRAME := Color(0.97, 0.92, 0.80)
var colours: Array = []
var across := 8
var at := -1  # (which is chosen)
var _shown := Rect2()  # (where the frame is, gliding)
var _held := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## The palette, and which of it is chosen (the frame glides there; at once when it's new).
func show_colours(list: Array, chosen: int) -> void:
	colours = list
	at = chosen
	_shown = cell(at)
	queue_redraw()


func rows() -> int:
	return ceili(float(colours.size()) / float(across))


## Each square's size and the gap between them, to fill its width (and fit its height).
func cell_size() -> float:
	var gap := gap_size()
	return floorf(minf((size.x - gap * (across - 1)) / across, (size.y - gap * (rows() - 1)) / maxi(1, rows())))


func gap_size() -> float:
	return clampf(roundf(size.x / across * 0.14), 3.0, 7.0)


func cell(i: int) -> Rect2:
	if i < 0 or colours.is_empty():
		return Rect2()
	var s := cell_size()
	var gap := gap_size()
	var span := Vector2(across * s + (across - 1) * gap, rows() * s + (rows() - 1) * gap)
	var origin := ((size - span) * 0.5).floor()
	return Rect2(origin + Vector2(i % across, i / across) * (s + gap), Vector2(s, s))


## The height its width wants (square squares).
func height_for(width: float) -> float:
	var gap := clampf(roundf(width / across * 0.14), 3.0, 7.0)
	var s := floorf((width - gap * (across - 1)) / across)
	return rows() * s + (rows() - 1) * gap


func _process(delta: float) -> void:
	if at < 0:
		return
	var want := cell(at)
	if _shown.size.x <= 0.0:  # (shown before it was laid out: the frame starts where it belongs)
		_shown = want
		queue_redraw()
		return
	var k := 1.0 - exp(-delta * 16.0)
	var was := _shown
	_shown = Rect2(_shown.position.lerp(want.position, k), _shown.size.lerp(want.size, k))
	if not _shown.position.is_equal_approx(was.position) or not _shown.size.is_equal_approx(was.size):
		queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_held = e.pressed
		if e.pressed:
			_choose_at(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _held:
		_choose_at(e.position)
		accept_event()


## The square under a finger: chosen.
func _choose_at(p: Vector2) -> void:
	for i in colours.size():
		if cell(i).grow(gap_size() * 0.5).has_point(p):
			if i != at:
				at = i
				picked.emit()
			return


func _draw() -> void:
	for i in colours.size():
		var r := cell(i)
		var c: Color = colours[i]
		draw_rect(r, EDGE)
		draw_rect(r.grow(-2.0), c)
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4.0, 2.0)), c.lightened(0.28))  # (a light edge on top,
		draw_rect(Rect2(r.position + Vector2(2, r.size.y - 4.0), Vector2(r.size.x - 4.0, 2.0)), c.darkened(0.2))  # dark below)
	if at >= 0:
		var f := _shown.grow(4.0)
		draw_rect(f.grow(2.0), EDGE, false, 2.0)
		draw_rect(f, FRAME, false, 3.0)
