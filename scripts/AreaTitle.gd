extends CanvasLayer
## The name of where he is, as he gets there: THE WORLD TREE (out of the ground: the first, the climb's
## real start; under it, home and the way out, its signs telling him how to play, go unnamed), THE DARK,
## THE MUSHROOMS, THE CASTLE, THE CLOUDS (out in the sky beside it) and THE TOP OF THE TREE.
## It comes in near the top of the screen with a soft whoosh and a low bell: a dark band behind it fading
## in (so it reads over anything), its letters dropping into place from the middle out, in the frog god's
## spread-out capitals, a gold line drawing out under them from the middle and a little diamond popping
## up at each end; it stays a moment, then fades as it drifts up. Named once he's somewhere new, and not
## again for a while (AGAIN), so a ledge on an edge between two doesn't keep naming them. Not on the
## title, while he's waking up at home, or paused.

const AGAIN := 40.0  # (seconds before an area's named again)
const HOLD := 2.6
const CREAM := Color(0.97, 0.92, 0.80)
const GOLD := Color(1.0, 0.86, 0.42)
const INK := Color(0.07, 0.04, 0.02)
## The band behind it: a soft dark glow, fading out at its ends and its top and bottom.
const _BAND := """shader_type canvas_item;
void fragment() {
	float across = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x);
	float down = smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.7, UV.y);
	COLOR = vec4(0.03, 0.02, 0.06, 0.55 * across * down);
}"""

var player: Node2D
var top_at := Vector2(0.18, 0.2)  # (how far down the room it comes in, upright and sideways: Endless's lower, its score's up there)
var showing := ""  # (the name up now, or "")
var _where := ""
var _named := {}  # (each area: when it was last named, in msec)
var _checked := 0.0
var _size := 0  # (the letters' size: 32 upright, 16 sideways)
var _lift := 0.0  # (how far it's drifted up, going)
var _box: Control  # (all of it, faded together)
var _band: ColorRect
var _letters: Control  # (each letter its own Label: they come in one by one)
var _line: ColorRect
var _ends: Array[Control] = []
var _tween: Tween
var _sound: AudioStreamPlayer


## Where `at` is (by its height, currentHeight's: a tenth of a pixel up from 472; and across, for the sky
## beside the castle), or "" below the tree (home, and the way out of it).
const TREE_FOOT := Vector2(2480.0, 3260.0)  # (x: the World Tree's foot, where its name comes up from the ground)


static func area_at(at: Vector2) -> String:
	var h := (-at.y - 472.0) / 10.0
	if h < 0.0:
		return ""
	if h < 148.0:
		# (named at its foot, or once he's up off the ground: not on the way to it, over the signs)
		var at_foot := at.x > TREE_FOOT.x and at.x < TREE_FOOT.y
		return "THE WORLD TREE" if at_foot or h > 12.0 else ""
	if h < 315.0:
		return "THE DARK" if at.x > 2100.0 and at.x < 3450.0 else ""  # (in the tree: out in the sky beside it, it's not dark)
	if h < 505.0:
		return "THE MUSHROOMS"
	if h >= 540.0 and at.x < 1900.0:
		return "THE CLOUDS"
	if h < 612.0:
		return "THE CASTLE"
	return "THE TOP OF THE TREE"


func _ready() -> void:
	name = "AreaTitle"
	layer = 4  # (over the game, under its menus and the frog god)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	add_child(_box)
	_band = ColorRect.new()  # (dark in the middle, fading softly out to nothing all round: _BAND)
	var soft := ShaderMaterial.new()
	soft.shader = Shader.new()
	soft.shader.code = _BAND
	_band.material = soft
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_band)
	_letters = Control.new()
	_letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_letters)
	_line = ColorRect.new()
	_line.color = Color(GOLD, 0.9)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_line)
	for _i in 2:
		var end := Control.new()  # (a little gold diamond, dark-edged)
		end.mouse_filter = Control.MOUSE_FILTER_IGNORE
		end.draw.connect(_draw_diamond.bind(end))
		_box.add_child(end)
		_ends.append(end)
	_sound = AudioStreamPlayer.new()
	_sound.stream = load("res://assets/area_reveal.wav")
	_sound.bus = &"FX"
	_sound.volume_db = -13.0
	add_child(_sound)


func _process(delta: float) -> void:
	_fit()
	_checked -= delta
	if _checked > 0.0 or player == null:
		return
	_checked = 0.25
	if not _in_play():
		return
	var area := area_at(player.global_position)
	if area == _where:
		return
	_where = area
	var now := Time.get_ticks_msec()
	if area != "" and now - int(_named.get(area, -1000000)) > AGAIN * 1000.0:
		_named[area] = now
		_name(area)


## Name `area` now, whatever he's doing (Endless, as he climbs into each of its zones: the same look).
func announce(area: String) -> void:
	_name(area)


## Climbing: not on the title, waking up at home, paused, in the frog god's intro or the ending.
func _in_play() -> bool:
	return player.get_node("Trajectory").endGame == 0 and not player.get("waking") and Engine.time_scale > 0.5 \
		and not player.get_node("titlescreen").visible and not player.has_node("CreatorIntro") \
		and not player.get_node("PauseScreen").visible


func _name(area: String) -> void:
	showing = area
	_spell(area)
	if _tween and _tween.is_valid():
		_tween.kill()
	_lift = 0.0
	_box.modulate.a = 1.0
	_band.modulate.a = 0.0
	_line.scale.x = 0.0
	for end in _ends:
		end.scale = Vector2.ZERO
	_fit()
	_sound.pitch_scale = randf_range(0.98, 1.02)
	_sound.play()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_band, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var letters := _letters.get_children()
	var mid := (letters.size() - 1) * 0.5
	for i in letters.size():
		var letter: Label = letters[i]
		var wait := 0.12 + absf(i - mid) * 0.045  # (from the middle out)
		letter.modulate.a = 0.0
		_tween.tween_property(letter, "modulate:a", 1.0, 0.3).set_delay(wait).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(letter, "position:y", 0.0, 0.5).from(-float(_size) * 0.4).set_delay(wait) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_line, "scale:x", 1.0, 0.8).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for end in _ends:  # (up past their size and back: a pop, eased all the way, never turned over)
		_tween.tween_property(end, "scale", Vector2.ONE * 1.25, 0.2).set_delay(0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(end, "scale", Vector2.ONE, 0.14).set_delay(1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_interval(HOLD)
	_tween.chain().tween_property(_box, "modulate:a", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(self, "_lift", float(_size) * 0.25, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_callback(func() -> void: showing = "")


## Each letter of `words` its own Label (so they come in one by one), set out as the frog god's are:
## spread out, a wide gap for a space.
func _spell(words: String) -> void:
	for old in _letters.get_children():
		_letters.remove_child(old)
		old.queue_free()
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	for ch in words:
		var letter := Label.new()
		letter.text = ch
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.style_label(letter, maxi(16, _size), CREAM)
		_letters.add_child(letter)
	_size = 0  # (laid out afresh: _fit)


## In the middle across, a little way down from the top of the room the screen has (clear of the clock
## and the pause button), at the frog god's sizes: 32 upright, 16 sideways.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	var size := 32 if portrait else 16
	if size != _size:
		_size = size
		var x := 0.0
		for letter: Label in _letters.get_children():
			ui.style_label(letter, size, CREAM)
			letter.size = letter.get_minimum_size()
			letter.position.x = roundf(x)
			x += letter.size.x + (size * 3.0 / 8.0 if letter.text == " " else size / 8.0)
		_letters.size = Vector2(maxf(0.0, x - size / 8.0), size * 1.25)
	var text: Vector2 = _letters.size
	var line_gap := 6.0 if portrait else 3.0
	var line_h := 2.0 if portrait else 1.0
	var pad := Vector2(size * 3.0, size * 0.95)  # (room above and below it, the band soft at its edges)
	var whole := Vector2(text.x + pad.x * 2.0, text.y + line_gap + line_h + pad.y * 2.0)
	var top := room.position.y + room.size.y * (top_at.x if portrait else top_at.y)
	_box.position = Vector2(vp.x * 0.5 - whole.x * 0.5, top - _lift).round()
	_box.size = whole
	_band.position = Vector2.ZERO
	_band.size = whole
	_letters.position = Vector2(pad.x, pad.y).round()
	var w := text.x + size * 1.2
	_line.size = Vector2(w, line_h)
	_line.position = Vector2(pad.x + (text.x - w) * 0.5, pad.y + text.y + line_gap).round()
	_line.pivot_offset = Vector2(w * 0.5, 0.0)
	var d := 4.0 if portrait else 2.0  # (each diamond's half-width)
	for i in 2:
		var end: Control = _ends[i]
		end.size = Vector2(d * 2.0, d * 2.0)
		end.pivot_offset = end.size * 0.5
		var x := _line.position.x - d * 2.0 - 2.0 if i == 0 else _line.position.x + w + 2.0
		end.position = Vector2(x, _line.position.y + line_h * 0.5 - d).round()


## A little diamond, gold with a dark edge.
func _draw_diamond(end: Control) -> void:
	var c := end.size * 0.5
	var r := c.x
	var outer := PackedVector2Array([c + Vector2(0, -r - 1), c + Vector2(r + 1, 0), c + Vector2(0, r + 1), c + Vector2(-r - 1, 0)])
	var inner := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	end.draw_colored_polygon(outer, INK)
	end.draw_colored_polygon(inner, GOLD)
