extends CanvasLayer
## How the game starts, the first time: out of the dark, slowly, a place between the stars and the frog
## god's voice, the ending's song under it, slowed right down. He's a shadow, the frog god's own; it asks what he looks like, and he
## chooses, one thing at a time (his skin, then his belly), each from a palette of
## colours to tap or slide a finger across, his colours gliding to each as he fills in. "Is this you?"
## Yes: it cuts to black (the music cut off, with the sound the finale makes as it closes in), the TV's
## static comes up, and he fades into his bedroom as that froggy. Nothing else is asked, not even a name
## (he's lil froggy, as everyone is; friends know you by your Muse @handle): hats, patterns and skins are
## earned by playing. His look is kept (MusicManager.look) and goes online with him (Party), with a band
## of a colour all his own (a random one: he changes it in Play Together, not here). From the wardrobe
## (from_wardrobe): just the choosing, with his pattern's colour when he's wearing one, eased in over the
## wardrobe and out again, its question there at once (no slow typing), the game's music turned down under its
## own, all on real time (the pause menu runs the game at a twentieth of its speed). (The mood's a
## dream-like void; the words, the frog god's and the art are Frog Quest's own.)

signal done
signal covered  ## (from the wardrobe: eased all the way in, nothing else to be seen)
signal uncovering  ## (and starting to ease away, back to the wardrobe)

const LINES := ["...LITTLE ONE...", "YOU HAVE COME FROM BELOW.", "BEFORE THE TREE CAN KNOW YOU...", "TELL ME."]
const ASK := "WHAT DO YOU LOOK LIKE?"
const SURE := "IS THIS YOU?"
const PARTS := {"body": "SKIN", "belly": "BELLY", "pattern_colour": "PATTERN"}
const PALETTES := {"body": "skin", "belly": "belly", "pattern_colour": "skin"}
const SHADER_KEYS := {"body": "body_colour", "belly": "belly_colour", "eyes": "eye_colour", "pattern_colour": "pattern_colour"}
const FADE_IN := 3.0  # (the first time: out of the dark, slowly)
const HOLD := 2.5  # (seconds of black after the cut, its sound ringing out, before he fades in at home)
const FADE := 3.5  # (and the slow fade into his bedroom: he's asleep in it)
const QUICK_HOLD := 1.1  # (into Endless, or Play Together's menu: on with it)
const QUICK_FADE := 1.8
const FROM_WARDROBE := 0.35  # (from the wardrobe: easing in, and away again)
const DUCK_DB := 24.0  # (the game's own music turned down this much under the frog god's, from the wardrobe)
const MUSIC_DB := -9.0  # (its file's at -16 LUFS: this puts it at about -25, as loud as the hum before it)
const IDLE := ["res://assets/frog.png", "res://assets/frog2.png"]
const TYPE_SPEED := 10.0  # letters a second (slow: the frog god is old, and big)
const VOICE_PITCH := Vector2(0.28, 0.34)  # (its voice, a blip every other letter: deep, a little different each time)
const CREAM := Color(0.97, 0.92, 0.80)
const DIM := Color(0.70, 0.66, 0.82)
const VOICE := Color(0.93, 0.90, 1.0)
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
var fade_in := false  # (the game's very first moments: out of the black, slowly)
var cut_sound := true  # (the finale's closing-in sound at the cut; START plays it itself, so not from there)
var slow_end := true  # (into his bedroom, where he's asleep: a long black, a slow fade. Not into Endless or Play Together)

var _looks: GDScript = load("res://scripts/FroggyLook.gd")
var _look := {}
var _hat := ""
var _steps: Array = []  # (what's chosen, in turn: "body", "belly"; from the wardrobe, maybe more. His eyes are his own)
var _at := 0  # (which of them)
var _step := ""  # talk, choose, sure ("" once he's going)
var _line := 0
var _said := ""  # (the words, before they're broken into even lines)
var _typed := 0.0
var _shadow := 1.0
var _frame := 0
var _frame_t := 0.0
var _clock := 0.0  # (its own time: the bob, the fly; steady in a recording too)
var _centred := 1.0  # (1: him in the middle, as the frog god speaks or asks; 0: where he is as he chooses)
var _palette_in := 0.0  # (each part's palette coming in)
var _voice_px := 0
var _fly_on := 0.0  # (0: by YES; 1: by NO, with the mouse over it)
var _fly_want := 0.0
var _shown := {}  # (his colours as shown: gliding to what's chosen)
var _ending := false
var _quiet := 0.0  # (the first time: before the frog god speaks, out of the dark)

var _root: Control  # (everything, to fade it all at once)
var _bg: ColorRect
var _words: Label
var _frog: TextureRect
var _hat_rect: TextureRect
var _tap: Button
var _choosing: Control
var _part: Label
var _grid: Control  # (ColourGrid: the palette)
var _dots: Control
var _back: Button
var _next: Button
var _sure: HBoxContainer
var _fly: Control
var _spaced: FontVariation
var _black: ColorRect
var _music: AudioStreamPlayer
var _more: Control  # (MoreArrow: under its words once they're all there, for a tap)
var _ducked := {}  # (from the wardrobe: the game's music players turned down under the frog god's, and how loud they were)
var _evened := {}  # (_even's answers, by words and room: worked out once, not every frame)
var _blip: AudioStreamPlayer


func _ready() -> void:
	name = "CreatorIntro"
	layer = 110  # (over the game and its menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_look = _looks.clean(MusicManager.look)
	_hat = MusicManager.equipped_hat
	_steps = ["body", "belly"]
	if from_wardrobe:
		if int(_look.pattern) != 0:
			_steps.append("pattern_colour")
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
	_frog.material = _looks.material(_look, "", 0.0 if from_wardrobe else 1.0)  # (from the wardrobe: him at once, no shadow first)
	_root.add_child(_frog)
	_dress_hat()

	_words = Label.new()
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_OFF  # (broken into even lines here: _even)
	_words.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING  # (typed out in place, not reflowing)
	ui.style_label(_words, 16, VOICE)
	_spaced = FontVariation.new()  # (the frog god's words, spread out)
	_spaced.base_font = ui.font()
	_words.add_theme_font_override("font", _spaced)
	_words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_words)
	_more = load("res://scripts/MoreArrow.gd").new()  # (its words go on only with a tap: this says so)
	_more.colour = VOICE
	_root.add_child(_more)

	_choosing = Control.new()  # (which part, its palette, which of them this is, and back and next)
	_choosing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choosing.visible = false
	_root.add_child(_choosing)
	_part = Label.new()
	_part.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_part.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.style_label(_part, 16, CREAM)
	_choosing.add_child(_part)
	_grid = load("res://scripts/ColourGrid.gd").new()
	_grid.picked.connect(_pick)
	_choosing.add_child(_grid)
	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	_choosing.add_child(_dots)
	_back = _button("BACK", _back_pressed, "quiet")
	_choosing.add_child(_back)
	_next = _button("NEXT", _next_pressed, "go")
	_choosing.add_child(_next)

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

	_black = ColorRect.new()  # (the dark it comes out of, the first time, and the cut to black at the end)
	_black.color = Color(0, 0, 0, 1.0 if fade_in else 0.0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	# (goodbyefroggy, the ending's song, at half speed: an octave down, in a big dark room, smooth brown
	# noise under it; the whole song, looping (from 8 s: its end runs into it). It comes in, and it's cut
	# off at the end. So the game's first music is the last, as if from far away.)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/froggod_intro.ogg")
	_music.bus = &"Music"
	_music.volume_db = -50.0
	add_child(_music)
	_music.play()
	_music.create_tween().set_ignore_time_scale(from_wardrobe).tween_property(_music, "volume_db", MUSIC_DB, FADE_IN if fade_in else 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)  # (from the wardrobe the pause menu may have slowed the game right down)
	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/frogaim.wav")
	_blip.bus = &"FX"
	_blip.volume_db = -20.0  # (a low voice sounds quieter on a phone's small speaker)
	add_child(_blip)

	_shadow = 0.0 if from_wardrobe else 1.0
	if from_wardrobe:
		_centred = 0.0
		_choose(0)
		_duck(true)
		_root.modulate.a = 0.0  # (eased in over the wardrobe, not there all at once)
		var come := create_tween().set_ignore_time_scale(true)
		come.tween_property(_root, "modulate:a", 1.0, FROM_WARDROBE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		come.tween_callback(func() -> void: covered.emit())
	else:
		_step = "talk"
		if fade_in:
			_quiet = FADE_IN * 0.6  # (the frog god speaks once it's mostly out of the dark)
			create_tween().tween_property(_black, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_say("")
		else:
			_say(LINES[0])
	_fit()


func _process(delta: float) -> void:
	delta = _real(delta)
	_clock += delta
	if _quiet > 0.0:
		_quiet -= delta
		if _quiet <= 0.0:
			_say(LINES[0])
	_fit()
	var total := _words.text.length()
	if from_wardrobe:  # (its question there at once: it's been asked before)
		_typed = float(total)
		_words.visible_characters = -1
	elif _typed < total:
		var before := int(_typed)
		_typed = minf(float(total), _typed + delta * TYPE_SPEED)
		_words.visible_characters = int(_typed)
		var ch := _words.text.substr(int(_typed) - 1, 1)
		if int(_typed) / 2 != before / 2 and ch != " " and ch != "\n":
			_blip.pitch_scale = randf_range(VOICE_PITCH.x, VOICE_PITCH.y)
			_blip.play()
	_more.shown = _step == "talk" and _quiet <= 0.0 and total > 0 and _typed >= total
	_frame_t += delta
	if _frame_t > 0.6:
		_frame_t = 0.0
		_frame = 1 - _frame
		_frog.texture = load(IDLE[_frame])
	var dark := 1.0 if (_step == "talk" and not from_wardrobe) else 0.0
	_shadow = move_toward(_shadow, dark, delta * 0.7)
	if _step != "":
		_centred = move_toward(_centred, 0.0 if _step == "choose" else 1.0, delta * 2.4)
	_palette_in = move_toward(_palette_in, 1.0, delta * 4.0)
	_fly_on = move_toward(_fly_on, _fly_want, delta * 6.0)
	var mat := _frog.material as ShaderMaterial
	var glide := 1.0 - exp(-delta * 12.0)  # (his colours glide to what's chosen)
	for key in SHADER_KEYS:
		_shown[key] = (_shown[key] as Color).lerp(_looks.colour(_look, key), glide)
		mat.set_shader_parameter(SHADER_KEYS[key], _shown[key])
	mat.set_shader_parameter("pattern", int(_look.pattern))
	mat.set_shader_parameter("shadow_amount", smoothstep(0.0, 1.0, _shadow))
	_hat_rect.modulate.a = 1.0 - smoothstep(0.0, 1.0, _shadow)  # (the frog god's shadow wears no hat: his comes with his colours)
	_fly.queue_redraw()


## Words in the frog god's voice, typed out (broken into even lines as they're laid out: _fit).
func _say(words: String) -> void:
	_said = words
	_words.text = words
	_typed = 0.0
	_words.visible_characters = 0


## A tap while it speaks: all of these words at once, or the next ones; after them, the choosing.
func _advance() -> void:
	if _quiet > 0.0:
		return
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


## Part `at` to choose (its palette, with what he is now framed): the frog god asks what he looks like.
func _choose(at: int) -> void:
	var first := _step != "choose"
	_at = clampi(at, 0, _steps.size() - 1)
	_step = "choose"
	_tap.visible = false
	_palette_in = 0.0
	_sure.visible = false
	_fly.visible = false
	var kind: String = _steps[_at]
	var colours: Array = _looks.palette(PALETTES[kind])
	_grid.show_colours(colours, _looks.nearest(colours, _looks.colour(_look, kind)))
	_part.text = PARTS[kind]
	_back.visible = _at > 0 or from_wardrobe
	_back.text = "BACK" if _at > 0 else "CANCEL"
	_next.text = "DONE" if (from_wardrobe and _at == _steps.size() - 1) else "NEXT"
	_dots.queue_redraw()
	if first or _said != ASK:
		_say(ASK)


## A colour tapped: that's his now (gliding onto him).
func _pick() -> void:
	var kind: String = _steps[_at]
	_look[kind] = (_grid.colours[_grid.at] as Color).to_html(false)
	_blip.pitch_scale = 0.85 + float(_grid.at % _grid.across) * 0.06
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
	if not from_wardrobe:
		_look.band = _looks.random_band()  # (a band of a colour all his own; changed in Play Together)
	MusicManager.look = _looks.clean(_look)
	MusicManager.look_made = true
	MusicManager.save_wardrobe()


## The end of it. The first time: it cuts to black, the music cut off (with the finale's closing-in sound),
## the game takes over behind it (done), and it fades in from the black. From the wardrobe: it just
## fades back to it.
func _end() -> void:
	if _ending:
		return
	_ending = true
	_step = ""
	_tap.visible = false
	if from_wardrobe:
		uncovering.emit()
		var away := create_tween().set_ignore_time_scale(true)
		away.tween_property(_root, "modulate:a", 0.0, FROM_WARDROBE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		away.parallel().tween_property(_music, "volume_db", -50.0, FROM_WARDROBE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_duck(false, away)
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
	out.tween_interval(hold())
	out.tween_property(_black, "color:a", 0.0, fade()).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await out.finished
	queue_free()


## How long it's black after the cut, and then how long it fades: long and slow into his bedroom, quicker
## into Endless or Play Together's menu.
func hold() -> float:
	return HOLD if slow_end else QUICK_HOLD


func fade() -> float:
	return FADE if slow_end else QUICK_FADE


## His hat (the one he's wearing, if any: they're earned by playing), as in the game.
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
## (sideways), the palette under him or beside him.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	(_bg.material as ShaderMaterial).set_shader_parameter("pixels", (vp * 0.5).floor())
	_voice(32 if portrait else 16)
	var px := (5.0 if room.size.y >= 660.0 else 4.0) if portrait else 3.0  # (each of his pixels, in the screen's)
	var frog_size := Vector2(32, 32) * px
	var bob := sin(_clock * 1.6) * 3.0
	var k := smoothstep(0.0, 1.0, _centred)
	var words_h := 96.0 if portrait else 44.0
	var gap := 20.0 if portrait else 8.0
	var middle := Vector2(vp.x * 0.5, room.position.y + room.size.y * (0.52 if portrait else 0.56))
	var choosing: Vector2  # (where he is as he chooses)
	var words_w: float
	if portrait:
		var w := roundf(minf(room.size.x * 0.86, 380.0))
		var grid_h := roundf(w * 5.0 / 8.0)
		var below := 26.0 + grid_h + 14.0 + 8.0 + 14.0 + 34.0  # (the part's name, the palette, the dots, the buttons)
		var block := words_h + gap + frog_size.y + 22.0 + below  # (the question, him and the palette: in the middle)
		var top := room.position.y + maxf(10.0, (room.size.y - block) * 0.42)
		choosing = Vector2(vp.x * 0.5, top + words_h + gap + frog_size.y * 0.5)
		words_w = room.size.x - 32.0
		_lay_choosing(Vector2(roundf((vp.x - w) * 0.5), roundf(choosing.y + frog_size.y * 0.5 + 22.0)), w, grid_h, 26.0, 14.0, 34.0)
	else:
		var w := roundf(clampf(room.size.x - 196.0, 220.0, 300.0))
		var left := room.size.x - w - 20.0  # (his side)
		choosing = Vector2(room.position.x + left * 0.5 + 4.0,
			maxf(room.position.y + 6.0 + words_h + gap + frog_size.y * 0.5, room.position.y + room.size.y * 0.55))
		words_w = left
		var grid_h := minf(roundf(w * 5.0 / 8.0), room.size.y - 18.0 - 6.0 - 8.0 - 6.0 - 24.0 - 12.0)
		_lay_choosing(Vector2(roundf(room.end.x - w - 12.0), roundf(room.position.y + 6.0)), w, grid_h, 18.0, 6.0, 24.0)
	var centre := choosing.lerp(middle, k)
	words_w = lerpf(words_w, room.size.x - 32.0, k)
	_words.size = Vector2(words_w, words_h)
	_words.position = Vector2(centre.x - words_w * 0.5, centre.y - frog_size.y * 0.5 - gap - words_h).round()
	var lines := _words.text.count("
") + 1
	var text_bottom := _words.position.y + words_h * 0.5 + lines * _words.get_line_height() * 0.5
	_more.pixel = 2.0
	_more.position = Vector2(centre.x - _more.size.x * 0.5, text_bottom + (8.0 if portrait else 3.0)).round()
	var even := _even(_said, words_w - 8.0)  # (in even lines: never one word left alone on the last)
	if _words.text != even:
		_words.text = even
	_choosing.modulate.a = (1.0 - k) * smoothstep(0.0, 1.0, _palette_in)
	_choosing.visible = _step == "choose" or _choosing.modulate.a > 0.02
	_choosing.position.y += roundf((1.0 - smoothstep(0.0, 1.0, _palette_in)) * 10.0)  # (each part's palette rises into place)
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


## The part's name, its palette, the dots and the buttons, from `at` down, `w` across.
func _lay_choosing(at: Vector2, w: float, grid_h: float, label_h: float, gap: float, button_h: float) -> void:
	_choosing.position = at
	var y := 0.0
	_part.position = Vector2(0, y)
	_part.size = Vector2(w, label_h)
	y += label_h
	_grid.position = Vector2(0, y)
	_grid.size = Vector2(w, grid_h)
	y += grid_h + gap
	_dots.position = Vector2(0, y)
	_dots.size = Vector2(w, 8)
	y += 8 + gap
	var bw := roundf((w - 12.0) * 0.5)
	_back.position = Vector2(0, y)
	_back.size = Vector2(bw, button_h)
	_next.position = Vector2(w - bw, y)
	_next.size = Vector2(bw, button_h)
	_choosing.size = Vector2(w, y + button_h)


## Words broken into as few lines as fit `room` across, as even as they can be (the longest line as
## short as it can be: never one word on its own under the rest). Spaces become the breaks, so it's
## as long as it was (what's typed out stays where it is).
func _even(words: String, room: float) -> String:
	var key := "%s|%d|%d" % [words, roundi(room), _voice_px]
	if not _evened.has(key):
		_evened[key] = _even_now(words, room)
	return _evened[key]


func _even_now(words: String, room: float) -> String:
	var parts := words.split(" ", false)
	var size := _voice_px
	if parts.size() < 2 or _spaced.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= room:
		return words
	for lines in range(2, parts.size() + 1):
		var best := ""
		var widest_best := INF
		for breaks in _ways_to_break(parts.size() - 1, lines - 1):
			var out := ""
			var widest := 0.0
			var line := ""
			for i in parts.size():
				line += ("" if line == "" else " ") + parts[i]
				if i in breaks or i == parts.size() - 1:
					widest = maxf(widest, _spaced.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
					out += line + ("\n" if i in breaks else "")
					line = ""
			if widest <= room and widest < widest_best:
				widest_best = widest
				best = out
		if best != "":
			return best
	return words


## Every way to choose `count` of the `gaps` places between words (as the index of the word before).
static func _ways_to_break(gaps: int, count: int, from := 0) -> Array:
	if count == 0:
		return [[]]
	var out := []
	for i in range(from, gaps - count + 1):
		for rest in _ways_to_break(gaps, count - 1, i + 1):
			out.append([i] + rest)
	return out


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


## Which part this is, of them all: a little square each, this one filled.
func _draw_dots() -> void:
	var n := _steps.size()
	var span := n * 8.0 + (n - 1) * 8.0
	var x0 := roundf((_dots.size.x - span) * 0.5)
	for i in n:
		var r := Rect2(x0 + i * 16.0, 0, 8, 8)
		_dots.draw_rect(r, CREAM if i == _at else DIM.darkened(0.45))


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


func _button(text: String, on_press: Callable, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 28)
	load("res://scripts/UIStyle.gd").style_button(b, 16, kind)
	b.pressed.connect(on_press)
	return b


## From the wardrobe: the game's own music (whatever's playing on the Music bus) turned down under the frog
## god's as it eases in (down), and back up as it eases away (with `away`: alongside its fade).
func _duck(down: bool, away: Tween = null) -> void:
	if down:
		var players: Array[Node] = get_tree().root.find_children("*", "AudioStreamPlayer", true, false)
		players.append_array(get_tree().root.find_children("*", "AudioStreamPlayer2D", true, false))
		for p in players:
			if p != _music and p != _blip and p.bus == &"Music" and p.playing:
				_ducked[p] = p.volume_db
		var dip := create_tween().set_ignore_time_scale(true).set_parallel(true)
		for p in _ducked:
			dip.tween_property(p, "volume_db", float(_ducked[p]) - DUCK_DB, FROM_WARDROBE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		if _ducked.is_empty():
			dip.kill()
		return
	for p in _ducked:
		if is_instance_valid(p):
			away.parallel().tween_property(p, "volume_db", float(_ducked[p]), FROM_WARDROBE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A frame's time, never slower than it really went: the pause menu runs the game at a twentieth of its speed
## (Engine.time_scale), and a menu over it shouldn't crawl; sped up (the tests' fast-forward), it goes with the
## game. Steady frame to frame, as the game's own is.
func _real(delta: float) -> float:
	return delta / Engine.time_scale if Engine.time_scale > 0.0 and Engine.time_scale < 1.0 else delta
