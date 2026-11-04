extends CanvasLayer
## How the game starts, the first time: a dark place between the stars, and the frog god's voice. He's a
## shadow, the frog god's own, and it asks what he looks like, one thing at a time: the colour of his
## skin, then his eyes, then his belly (any colour at all: a strip of colours to slide along, and under
## it a strip of its shades), and as he chooses he fills in, his colours gliding to each. "Is this you?"
## Yes: it cuts to black (with the sound the finale makes as it closes in), the TV's static comes up,
## and he fades into his bedroom as that froggy. Nothing else is asked, not even a name (he's lil froggy,
## as everyone is; friends know you by your Muse @handle): hats, patterns and skins are found by playing.
## His look is kept (MusicManager.look) and goes online with him (Party). From the wardrobe
## (from_wardrobe): just the choosing, with his pattern's colour (when he's wearing one) and his band's.
## (The mood's a dream-like void; the words, the frog god's and the art are Frog Quest's own.)

signal done

const LINES := ["...LITTLE ONE...", "YOU HAVE COME FROM BELOW.", "BEFORE THE TREE CAN KNOW YOU...", "TELL ME."]
const ASK := {"body": "WHAT COLOUR IS YOUR SKIN?", "eyes": "AND YOUR EYES?", "belly": "AND YOUR BELLY?",
	"pattern_colour": "AND YOUR PATTERN?", "band": "AND YOUR BAND?"}
const SURE := "IS THIS YOU?"
const SHADER_KEYS := {"body": "body_colour", "belly": "belly_colour", "eyes": "eye_colour", "pattern_colour": "pattern_colour"}
const HOLD := 1.1  # (seconds of black after the cut, its sound ringing, before he fades in)
const FADE := 1.8  # (and the fade into the game)
const IDLE := ["res://assets/frog.png", "res://assets/frog2.png"]
const TYPE_SPEED := 24.0  # letters a second
const CREAM := Color(0.97, 0.92, 0.80)
const DIM := Color(0.70, 0.66, 0.82)
const VOICE := Color(0.93, 0.90, 1.0)
const INK := Color(0.10, 0.08, 0.12)
const HAT_Y := -10.75  # (where his hats sit, from his middle, in his own pixels: player.gd's at -9.17, him at -1, at 0.76)
# (the fly by YES, as the cursor: his wings, his light edge, his dark body, his red eyes; wings up, then down)
const FLY := [[".WW.....WW.", "WWWW...WWWW", "WWWWW.WWWWW", ".WWWKKKWWW.", "...KBBBK...", "..KRBBBRK..", "..KBBBBBK..",
	"...KBBBK...", "....KKK...."], ["...........", "...........", ".WW.....WW.", "WWWWKKKWWWW", ".WWKBBBKWW.", "..KRBBBRK..",
	"..KBBBBBK..", "...KBBBK...", "....KKK...."]]
const FLY_COLOURS := {"W": Color(0.82, 0.92, 1.0, 0.9), "K": Color(0.97, 0.92, 0.80), "B": Color(0.20, 0.18, 0.26),
	"R": Color(0.95, 0.28, 0.30)}
const ART_HATS := {"froggycrown": ["res://assets/froggycrown.png", 1.0, -7.25], "blackcrown": ["res://assets/froggycrown.png", 1.0, -7.25],
	"wizhat": ["res://assets/froggywizhat.png", 1.0, 0.0], "cakehat": ["res://assets/froggycakehat.png", 0.71, 0.0]}

var from_wardrobe := false
var cut_sound := true  # (the finale's closing-in sound at the cut; START plays it itself, so not from there)

var _looks: GDScript = load("res://scripts/FroggyLook.gd")
var _look := {}
var _hat := ""
var _steps: Array = []  # (what's asked, in turn: "body", "eyes", "belly"; from the wardrobe, maybe more)
var _at := 0  # (which of them)
var _step := ""  # talk, choose, sure ("" once he's going)
var _line := 0
var _typed := 0.0
var _shadow := 1.0
var _frame := 0
var _frame_t := 0.0
var _clock := 0.0  # (its own time: the bob, the fly, the band; steady in a recording too)
var _centred := 1.0  # (1: him in the middle, as the frog god speaks or asks; 0: where he is as he chooses)
var _strips_in := 0.0  # (the strips coming in, each question)
var _voice_px := 0
var _fly_on := 0.0  # (0: by YES; 1: by NO, with the mouse over it)
var _fly_want := 0.0
var _shown := {}  # (his colours as shown: gliding to what's chosen)
var _ticked := -1  # (the last tick of the strips' little sound)
var _ending := false

var _root: Control  # (everything, to fade it all at once)
var _bg: ColorRect
var _words: Label
var _frog: TextureRect
var _hat_rect: TextureRect
var _band: Control  # (his band, under him, while its colour's chosen)
var _tap: Button
var _strips: Control
var _colour_label: Label
var _hue: ColourStrip
var _shade_label: Label
var _shade: ColourStrip
var _dots: Control
var _back: Button
var _next: Button
var _sure: HBoxContainer
var _fly: Control
var _spaced: FontVariation
var _black: ColorRect
var _music: AudioStreamPlayer
var _blip: AudioStreamPlayer


## A strip to choose a colour along (drag along it, or tap it): its colours from `paint` (where along
## it, 0 to 1), and a knob where it's at, gliding there when it's moved for you.
class ColourStrip extends Control:
	signal moved
	const EDGE := Color(0.10, 0.08, 0.12)
	const KNOB := Color(0.97, 0.92, 0.80)
	var at := 0.0
	var paint: Callable
	var _shown := 0.0
	var _held := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func set_at(where: float, glide := true) -> void:
		at = clampf(where, 0.0, 1.0)
		if not glide:
			_shown = at
		queue_redraw()

	## Moved by a finger (or the mouse) to x across it.
	func slide_to(x: float) -> void:
		at = clampf((x - 3.0) / maxf(1.0, size.x - 6.0), 0.0, 1.0)
		_shown = at
		moved.emit()
		queue_redraw()

	func _process(delta: float) -> void:
		var was := _shown
		_shown = lerpf(_shown, at, 1.0 - exp(-delta * 14.0))
		if absf(_shown - was) > 0.0005:
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_held = e.pressed
			if e.pressed:
				slide_to(e.position.x)
			accept_event()
		elif e is InputEventMouseMotion and _held:
			slide_to(e.position.x)
			accept_event()

	func _draw() -> void:
		if not paint.is_valid():
			return
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), EDGE)
		var inner := Rect2(3, 3, w - 6, h - 6)
		var n := maxi(8, int(inner.size.x / 2.0))
		for i in n:
			var x0 := floorf(inner.position.x + inner.size.x * i / n)
			var x1 := floorf(inner.position.x + inner.size.x * (i + 1) / n)
			draw_rect(Rect2(x0, inner.position.y, x1 - x0, inner.size.y), paint.call((float(i) + 0.5) / n))
		var x := roundf(inner.position.x + inner.size.x * _shown)
		draw_rect(Rect2(x - 6, -4, 12, h + 8), EDGE)  # (the knob: dark round the edge,
		draw_rect(Rect2(x - 4, -2, 8, h + 4), KNOB)  # cream,
		draw_rect(Rect2(x - 2, 0, 4, h), paint.call(_shown))  # the colour it's on in it)


func _ready() -> void:
	name = "CreatorIntro"
	layer = 110  # (over the game and its menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_look = _looks.clean(MusicManager.look)
	_hat = MusicManager.equipped_hat
	_steps = ["body", "eyes", "belly"]
	if from_wardrobe:
		if int(_look.pattern) != 0:
			_steps.append("pattern_colour")
		_steps.append("band")
	for key in SHADER_KEYS:
		_shown[key] = _looks.colour(_look, key)
	var ui: GDScript = load("res://scripts/UIStyle.gd")

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var void_mat := ShaderMaterial.new()
	void_mat.shader = load("res://assets/void.gdshader")
	_bg.material = void_mat
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	_tap = Button.new()  # (a tap anywhere while it speaks: the rest of the words, or the next)
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap.pressed.connect(_advance)
	_root.add_child(_tap)

	_band = Control.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.visible = false
	_band.draw.connect(_draw_band)
	_root.add_child(_band)
	_hat_rect = TextureRect.new()
	_hat_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hat_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_hat_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hat_rect)
	_frog = TextureRect.new()
	_frog.texture = load(IDLE[0])
	_frog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frog.stretch_mode = TextureRect.STRETCH_SCALE
	_frog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frog.material = _looks.material(_look, "", 1.0)
	_root.add_child(_frog)
	_dress_hat()

	_words = Label.new()
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # (typed out in place, not reflowing)
	ui.style_label(_words, 16, VOICE)
	_spaced = FontVariation.new()  # (the frog god's words, spread out)
	_spaced.base_font = ui.font()
	_words.add_theme_font_override("font", _spaced)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_words)

	_strips = Control.new()  # (a colour, its shade, which question this is, and back and next)
	_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strips.visible = false
	_root.add_child(_strips)
	_colour_label = _label("COLOUR")
	_strips.add_child(_colour_label)
	_hue = ColourStrip.new()
	_hue.moved.connect(_pick)
	_strips.add_child(_hue)
	_shade_label = _label("SHADE")
	_strips.add_child(_shade_label)
	_shade = ColourStrip.new()
	_shade.moved.connect(_pick)
	_strips.add_child(_shade)
	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	_strips.add_child(_dots)
	_back = _button("BACK", _back_pressed, "quiet")
	_strips.add_child(_back)
	_next = _button("NEXT", _next_pressed, "go")
	_strips.add_child(_next)

	_sure = HBoxContainer.new()
	_sure.add_theme_constant_override("separation", 24)
	_sure.alignment = BoxContainer.ALIGNMENT_CENTER
	_sure.visible = false
	_root.add_child(_sure)
	_sure.add_child(_button("YES", _yes, "go"))
	_sure.add_child(_button("NO", _no, "quiet"))
	_sure.get_child(0).mouse_entered.connect(func() -> void: _fly_want = 0.0)
	_sure.get_child(1).mouse_entered.connect(func() -> void: _fly_want = 1.0)
	_fly = Control.new()  # (a little fly by YES, as the cursor)
	_fly.visible = false
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fly)
	_fly.draw.connect(_draw_fly)

	_black = ColorRect.new()  # (the cut to black, at the end: the game fades in from it)
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/GOD FROG.ogg")
	_music.bus = &"Music"
	_music.volume_db = -40.0
	add_child(_music)
	_music.play()
	_music.create_tween().tween_property(_music, "volume_db", -12.0, 2.5)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/frogaim.wav")
	_blip.bus = &"FX"
	_blip.volume_db = -22.0
	add_child(_blip)

	_shadow = 0.0 if from_wardrobe else 1.0
	if from_wardrobe:
		_centred = 0.0
		_choose(0)
	else:
		_step = "talk"
		_say(LINES[0])
	_fit()


func _process(delta: float) -> void:
	_clock += delta
	_fit()
	var total := _words.text.length()
	if _typed < total:
		var before := int(_typed)
		_typed = minf(float(total), _typed + delta * TYPE_SPEED)
		_words.visible_characters = int(_typed)
		if int(_typed) / 2 != before / 2 and _words.text.substr(int(_typed) - 1, 1) != " ":
			_blip.pitch_scale = randf_range(0.55, 0.7)
			_blip.play()
	_frame_t += delta
	if _frame_t > 0.6:
		_frame_t = 0.0
		_frame = 1 - _frame
		_frog.texture = load(IDLE[_frame])
	var dark := 1.0 if (_step == "talk" and not from_wardrobe) else 0.0
	_shadow = move_toward(_shadow, dark, delta * 0.7)
	if _step != "":
		_centred = move_toward(_centred, 0.0 if _step == "choose" else 1.0, delta * 2.4)
	_strips_in = move_toward(_strips_in, 1.0, delta * 4.0)
	_fly_on = move_toward(_fly_on, _fly_want, delta * 6.0)
	var mat := _frog.material as ShaderMaterial
	var glide := 1.0 - exp(-delta * 12.0)  # (his colours glide to what's chosen)
	for key in SHADER_KEYS:
		_shown[key] = (_shown[key] as Color).lerp(_looks.colour(_look, key), glide)
		mat.set_shader_parameter(SHADER_KEYS[key], _shown[key])
	mat.set_shader_parameter("pattern", int(_look.pattern))
	mat.set_shader_parameter("shadow_amount", _shadow)
	_hat_rect.modulate.a = 1.0 - _shadow  # (the frog god's shadow wears no hat: his comes with his colours)
	_band.visible = _step == "choose" and _steps[_at] == "band"
	_band.queue_redraw()
	_fly.queue_redraw()


## Words in the frog god's voice, typed out.
func _say(words: String) -> void:
	_words.text = words
	_typed = 0.0
	_words.visible_characters = 0


## A tap while it speaks: all of these words at once, or the next ones; after them, the first question.
func _advance() -> void:
	if _typed < _words.text.length():
		_typed = _words.text.length()
		_words.visible_characters = -1
		return
	if _step != "talk":
		return
	_line += 1
	if _line < LINES.size():
		_say(LINES[_line])
	else:
		_choose(0)


## The question `at` (its strips set to what he is now): the frog god asks it.
func _choose(at: int) -> void:
	_at = clampi(at, 0, _steps.size() - 1)
	_step = "choose"
	_tap.visible = false
	_strips_in = 0.0
	_sure.visible = false
	_fly.visible = false
	var kind: String = _steps[_at]
	var paints := _paint_kind(kind)
	_hue.paint = func(t: float) -> Color: return _looks.chosen(paints, t, _shade.at)
	_shade.paint = func(t: float) -> Color: return _looks.chosen(paints, _hue.at, t)
	var where: Vector2 = _looks.place(paints, _looks.colour(_look, kind))
	_hue.set_at(where.x)
	_shade.set_at(where.y)
	_back.visible = _at > 0 or from_wardrobe
	_back.text = "BACK" if _at > 0 else "CANCEL"
	_next.text = "DONE" if (from_wardrobe and _at == _steps.size() - 1) else "NEXT"
	_dots.queue_redraw()
	_say(ASK[kind])


## Which strips a question's colours come from (FroggyLook.chosen): his skin's, his eyes'...
static func _paint_kind(kind: String) -> String:
	return {"body": "skin", "pattern_colour": "pattern"}.get(kind, kind)


## The strips moved: that colour's his now (shown at once on the strips, gliding onto him).
func _pick() -> void:
	var kind: String = _steps[_at]
	_look[kind] = _looks.chosen(_paint_kind(kind), _hue.at, _shade.at).to_html(false)
	_hue.queue_redraw()
	_shade.queue_redraw()
	var tick := int((_hue.at + _shade.at) * 24.0)  # (a soft tick as it slides, higher along it)
	if tick != _ticked:
		_ticked = tick
		_blip.pitch_scale = 0.8 + (_hue.at + _shade.at) * 0.3
		_blip.play()


func _next_pressed() -> void:
	if _at < _steps.size() - 1:
		_choose(_at + 1)
	elif from_wardrobe:
		_keep()
		_end()
	else:
		_ask_sure()


func _back_pressed() -> void:
	if _at > 0:
		_choose(_at - 1)
	elif from_wardrobe:
		_end()  # (as he was)


func _ask_sure() -> void:
	_step = "sure"
	_tap.visible = false
	_sure.visible = true
	_fly.visible = true
	_fly_want = 0.0
	_fly_on = 0.0
	_say(SURE)


func _no() -> void:
	_choose(0)


## Yes: that's him. Kept, and off he goes.
func _yes() -> void:
	_keep()
	_end()


func _keep() -> void:
	MusicManager.look = _looks.clean(_look)
	MusicManager.look_made = true
	MusicManager.save_wardrobe()


## The end of it. The first time: it cuts to black (the finale's closing-in sound), the game takes over
## behind it (done), and it fades in from the black. From the wardrobe: it just fades back to it.
func _end() -> void:
	if _ending:
		return
	_ending = true
	_step = ""
	_tap.visible = false
	if from_wardrobe:
		var away := create_tween()
		away.tween_property(_root, "modulate:a", 0.0, 0.35)
		await away.finished
		done.emit()
		queue_free()
		return
	_black.color = Color(0, 0, 0, 1)
	_root.visible = false
	_music.stop()
	if cut_sound:
		var boom := AudioStreamPlayer.new()
		boom.stream = load("res://assets/appear.mp3")
		boom.pitch_scale = 0.55
		boom.bus = &"FX"
		get_tree().root.add_child(boom)
		boom.play()
		boom.finished.connect(boom.queue_free)
	done.emit()
	var out := create_tween()
	out.tween_interval(HOLD)
	out.tween_property(_black, "color:a", 0.0, FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await out.finished
	queue_free()


## His hat (the one he's wearing, if any: they're found by playing), as in the game.
func _dress_hat() -> void:
	var pic: Texture2D = _looks.hat_texture(_hat)
	if pic == null and ART_HATS.has(_hat):
		pic = load(ART_HATS[_hat][0])
	_hat_rect.texture = pic
	_hat_rect.material = null
	if _hat == "blackcrown":
		var black := ShaderMaterial.new()
		black.shader = load("res://assets/skin_tint.gdshader")
		black.set_shader_parameter("tint_color", Color(0, 0, 0))
		black.set_shader_parameter("tint_strength", 1.0)
		_hat_rect.material = black
	_hat_rect.visible = pic != null
	var at := _frog.get_index()  # (his own art hats behind his head, as in the game; the drawn ones worn in front)
	if ART_HATS.has(_hat):
		if _hat_rect.get_index() > at:
			_root.move_child(_hat_rect, at)
	elif _hat_rect.get_index() < at:
		_root.move_child(_hat_rect, at)


## Laid out for the screen. As the frog god speaks, or asks "is this you?", he's in the middle, its
## words over him (YES and NO under him); as he chooses, he moves up (upright) or to the left
## (sideways), the strips under him or beside him.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	(_bg.material as ShaderMaterial).set_shader_parameter("pixels", (vp * 0.5).floor())
	_voice(32 if portrait else 16)
	var px := (5.0 if room.size.y >= 640.0 else 4.0) if portrait else 3.0  # (each of his pixels, in the screen's)
	var frog_size := Vector2(32, 32) * px
	var bob := sin(_clock * 1.6) * 3.0
	var k := smoothstep(0.0, 1.0, _centred)
	var words_h := 96.0 if portrait else 44.0
	var gap := 20.0 if portrait else 8.0
	var middle := Vector2(vp.x * 0.5, room.position.y + room.size.y * (0.52 if portrait else 0.56))
	var choosing: Vector2  # (where he is as he chooses)
	var words_w: float
	if portrait:
		var w := roundf(minf(room.size.x * 0.86, 400.0))
		var strips_h := 24.0 + 34.0 + 14.0 + 24.0 + 34.0 + 14.0 + 8.0 + 14.0 + 34.0
		var block := words_h + gap + frog_size.y + 30.0 + strips_h  # (the question, him and the strips: in the middle)
		var top := room.position.y + maxf(12.0, (room.size.y - block) * 0.42)
		choosing = Vector2(vp.x * 0.5, top + words_h + gap + frog_size.y * 0.5)
		words_w = room.size.x - 32.0
		_lay_strips(Vector2(roundf((vp.x - w) * 0.5), roundf(choosing.y + frog_size.y * 0.5 + 30.0)), w, 34.0, 24.0, 14.0, 34.0)
	else:
		var w := roundf(clampf(room.size.x - 190.0, 220.0, 300.0))
		var left := room.size.x - w - 20.0  # (his side)
		choosing = Vector2(room.position.x + left * 0.5 + 4.0,
			maxf(room.position.y + 6.0 + words_h + gap + frog_size.y * 0.5, room.position.y + room.size.y * 0.55))
		words_w = left
		_lay_strips(Vector2(roundf(room.end.x - w - 12.0), roundf(room.position.y + 8.0)), w, 20.0, 17.0, 5.0, 24.0)
	var centre := choosing.lerp(middle, k)
	words_w = lerpf(words_w, room.size.x - 32.0, k)
	_words.size = Vector2(words_w, words_h)
	_words.position = Vector2(centre.x - words_w * 0.5, centre.y - frog_size.y * 0.5 - gap - words_h).round()
	_strips.modulate.a = (1.0 - k) * _strips_in
	_strips.visible = _step == "choose" or _strips.modulate.a > 0.02
	_strips.position.y += roundf((1.0 - _strips_in) * 10.0)  # (each question's strips rise into place)
	_frog.size = frog_size
	_frog.position = (centre - frog_size * 0.5 + Vector2(0, bob)).round()
	if _hat_rect.texture:
		var t := _hat_rect.texture.get_size()
		var rel := 1.0
		var off: Vector2 = _looks.hat_offset(_hat)
		if ART_HATS.has(_hat):
			rel = ART_HATS[_hat][1]
			off = Vector2(0.0, ART_HATS[_hat][2])
		var drop: float = load("res://scripts/FroggyHead.gd").drop(_frog.texture)
		var mid: Vector2 = centre + Vector2(0, bob) + (Vector2(0.0, HAT_Y + drop) + off * rel) * px
		_hat_rect.size = t * rel * px
		_hat_rect.position = (mid - _hat_rect.size * 0.5).round()
	_band.size = Vector2(frog_size.x * 1.5, frog_size.y * 0.45)
	_band.position = (centre + Vector2(-_band.size.x * 0.5, frog_size.y * 0.38 + bob)).round()
	var sure_size := _sure.get_combined_minimum_size()
	_sure.size = sure_size
	_sure.position = Vector2(centre.x - sure_size.x * 0.5, centre.y + frog_size.y * 0.5 + (28.0 if portrait else 10.0)).round()
	_sure.modulate.a = k
	if _sure.get_child_count() > 1:
		var yes: Control = _sure.get_child(0)
		var no: Control = _sure.get_child(1)
		var by_yes := _sure.position + yes.position + Vector2(-28.0, yes.size.y * 0.5 - 9.0)
		var by_no := _sure.position + no.position + Vector2(-28.0, no.size.y * 0.5 - 9.0)
		_fly.position = by_yes.lerp(by_no, smoothstep(0.0, 1.0, _fly_on)).round()
		_fly.size = Vector2(22, 18)
		_fly.modulate.a = k


## The strips and what goes with them, from `at` down, `w` across.
func _lay_strips(at: Vector2, w: float, strip_h: float, label_h: float, gap: float, button_h: float) -> void:
	_strips.position = at
	var y := 0.0
	_colour_label.position = Vector2(0, y)
	_colour_label.size = Vector2(w, label_h)
	y += label_h
	_hue.position = Vector2(0, y)
	_hue.size = Vector2(w, strip_h)
	y += strip_h + gap
	_shade_label.position = Vector2(0, y)
	_shade_label.size = Vector2(w, label_h)
	y += label_h
	_shade.position = Vector2(0, y)
	_shade.size = Vector2(w, strip_h)
	y += strip_h + gap
	_dots.position = Vector2(0, y)
	_dots.size = Vector2(w, 8)
	y += 8 + gap
	var bw := roundf((w - 12.0) * 0.5)
	_back.position = Vector2(0, y)
	_back.size = Vector2(bw, button_h)
	_next.position = Vector2(w - bw, y)
	_next.size = Vector2(bw, button_h)
	_strips.size = Vector2(w, y + button_h)


## The frog god's words at this size (32 upright, 16 sideways: twice the font's own, or the same),
## spread out to match.
func _voice(size: int) -> void:
	if size == _voice_px:
		return
	_voice_px = size
	_words.add_theme_font_size_override("font_size", size)
	_words.add_theme_constant_override("outline_size", maxi(2, size / 8))
	_spaced.spacing_glyph = size / 8
	_spaced.spacing_space = size * 3 / 8


## Which question this is, of them all: a little square each, this one filled.
func _draw_dots() -> void:
	var n := _steps.size()
	var span := n * 8.0 + (n - 1) * 8.0
	var x0 := roundf((_dots.size.x - span) * 0.5)
	for i in n:
		var r := Rect2(x0 + i * 16.0, 0, 8, 8)
		_dots.draw_rect(r, CREAM if i == _at else DIM.darkened(0.45))


## His band, slung under him, in the colour it's being given (as friends see it when you climb together).
func _draw_band() -> void:
	var c: Color = _looks.colour(_look, "band")
	var w := _band.size.x
	var h := _band.size.y
	var line := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0
		line.append(Vector2(w * t, h * 0.1 + sin(t * PI) * h * 0.75 + sin(_clock * 2.0 + t * 6.0) * 1.5))
	_band.draw_polyline(line, Color(0.10, 0.07, 0.06), 6.0)
	_band.draw_polyline(line, c, 4.0)
	_band.draw_polyline(line, c.lerp(Color.WHITE, 0.55), 1.5)


## The fly by YES (or NO): two pixels to each of his, his wings flapping, bobbing as he hovers.
func _draw_fly() -> void:
	var rows: Array = FLY[int(_clock * 10.0) % 2]
	var lift := roundf(sin(_clock * 3.0) * 1.5)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			if c != ".":
				_fly.draw_rect(Rect2(Vector2(x, y) * 2.0 + Vector2(0, lift), Vector2(2, 2)), FLY_COLOURS[c])


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load("res://scripts/UIStyle.gd").style_label(l, 16, DIM)
	return l


func _button(text: String, on_press: Callable, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 28)
	load("res://scripts/UIStyle.gd").style_button(b, 16, kind)
	b.pressed.connect(on_press)
	return b
