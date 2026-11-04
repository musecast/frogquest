extends CanvasLayer
## Before his first climb: a dark place between the stars, and the frog god's voice. He's a shadow, the
## frog god's own; it asks what he looks like, and as he chooses, he fills in: his colour, his belly, a
## pattern and its colour, his eyes, a hat (the starters, and any he's found), and his stretchy band's
## colour (FroggyLook). "Is this you?" Yes: the frog god's last words, a flash, and he wakes in his
## bedroom as that froggy (the TV has its words for him there). His look is kept (MusicManager.look) and
## goes online with him (Party). From the wardrobe (from_wardrobe), it's just the choosing.
## (The mood's a dream-like void; the words, the frog god's and the art are Frog Quest's own.)

signal done

const LINES := ["...LITTLE ONE...", "YOU HAVE COME FROM BELOW.", "BEFORE THE TREE CAN KNOW YOU...", "TELL ME.",
	"WHAT DO YOU LOOK LIKE?"]
const AFTER := ["...THEN WAKE, LITTLE ONE.", "THE TREE IS WAITING."]
const ROWS := [["COLOUR", "body"], ["BELLY", "belly"], ["PATTERN", "pattern"], ["PATTERN COLOUR", "pattern_colour"],
	["EYES", "eyes"], ["HAT", "hat"], ["BAND", "band"]]
const IDLE := ["res://assets/frog.png", "res://assets/frog2.png"]
const TYPE_SPEED := 24.0  # letters a second
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

var _look := {}
var _hat := ""
var _hats: Array = []
var _step := ""  # talk, choose, sure, after
var _lines: Array = []
var _line := 0
var _typed := 0.0
var _wait := 0.0
var _shadow := 1.0
var _frame := 0
var _frame_t := 0.0
var _scale := 1.0
var _centred := 1.0  # (1: him in the middle, as the frog god speaks or asks; 0: where he is as he chooses)
var _voice_px := 0
var _fly_on := 0.0  # (0: by YES; 1: by NO, with the mouse over it)
var _fly_want := 0.0

var _bg: ColorRect
var _words: Label
var _frog: TextureRect
var _hat_rect: TextureRect
var _tap: Button
var _scroll: ScrollContainer  # (the choices: they slide, on a screen too short for them all)
var _rows: VBoxContainer
var _values := {}  # key -> [value Label, swatch ColorRect, row]
var _this_is_me: Button
var _sure: HBoxContainer
var _fly: Control
var _spaced: FontVariation
var _flash: ColorRect
var _music: AudioStreamPlayer
var _blip: AudioStreamPlayer
var _waking := false


func _ready() -> void:
	name = "CreatorIntro"
	layer = 110  # (over the game and its menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	_look = look.clean(MusicManager.look)
	_hat = MusicManager.equipped_hat
	_hats = look.starter_hats()
	for id in look.UNLOCKS:
		if look.UNLOCKS[id][0] == "hat" and _owns(id):
			_hats.append(id)
	if not _hat in _hats:
		_hats.append(_hat)
	var ui: GDScript = load("res://scripts/UIStyle.gd")

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var void_mat := ShaderMaterial.new()
	void_mat.shader = load("res://assets/void.gdshader")
	_bg.material = void_mat
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_hat_rect = TextureRect.new()  # (behind him, as his hats are in the game)
	_hat_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hat_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_hat_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hat_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hat_rect)
	_frog = TextureRect.new()
	_frog.texture = load(IDLE[0])
	_frog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frog.stretch_mode = TextureRect.STRETCH_SCALE
	_frog.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frog)

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
	add_child(_words)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	_scroll.visible = false
	add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_rows)
	for each in ROWS:
		_rows.add_child(_make_row(each[0], each[1]))
	ui.finger_scroll(_scroll)
	_this_is_me = _button("THIS IS ME", _ask_sure, "go")
	_this_is_me.visible = false
	add_child(_this_is_me)

	_sure = HBoxContainer.new()
	_sure.add_theme_constant_override("separation", 24)
	_sure.alignment = BoxContainer.ALIGNMENT_CENTER
	_sure.visible = false
	add_child(_sure)
	_sure.add_child(_button("YES", _yes, "go"))
	_sure.add_child(_button("NO", _no, "quiet"))
	_sure.get_child(0).mouse_entered.connect(func() -> void: _fly_want = 0.0)
	_sure.get_child(1).mouse_entered.connect(func() -> void: _fly_want = 1.0)
	_fly = Control.new()  # (a little fly by YES, as the cursor)
	_fly.visible = false
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fly)
	_fly.draw.connect(_draw_fly)

	_tap = Button.new()  # (a tap anywhere while it speaks: the rest of the words, or the next)
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap.pressed.connect(_advance)
	add_child(_tap)
	move_child(_tap, _bg.get_index() + 1)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

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
	_dress()
	_lines = [LINES[-1]] if from_wardrobe else LINES
	_step = "talk"
	_say(_lines[0])
	_fit()


## Whether he's found this hat already (the crown's kept apart, as it always was).
static func _owns(id: String) -> bool:
	if id == "froggycrown":
		return MusicManager.froggyCrown != 0
	return id in MusicManager.unlocked_skins


func _process(delta: float) -> void:
	_fit()
	var total := _words.text.length()
	if _typed < total:
		var before := int(_typed)
		_typed = minf(float(total), _typed + delta * TYPE_SPEED)
		_words.visible_characters = int(_typed)
		if int(_typed) / 2 != before / 2 and _words.text.substr(int(_typed) - 1, 1) != " ":
			_blip.pitch_scale = randf_range(0.55, 0.7)
			_blip.play()
	elif _step == "after":
		_wait -= delta
		if _wait <= 0.0:
			_advance()
	_frame_t += delta
	if _frame_t > 0.6:
		_frame_t = 0.0
		_frame = 1 - _frame
		_frog.texture = load(IDLE[_frame])
	var want := 1.0 if (_step == "talk" and not from_wardrobe) else 0.0
	_shadow = move_toward(_shadow, want, delta * 0.7)
	if _step != "":
		_centred = move_toward(_centred, 0.0 if _step == "choose" else 1.0, delta * 2.4)
	_fly_on = move_toward(_fly_on, _fly_want, delta * 6.0)
	(_frog.material as ShaderMaterial).set_shader_parameter("shadow_amount", _shadow)
	_hat_rect.modulate.a = 1.0 - _shadow  # (the frog god's shadow wears no hat: his comes with his colours)
	_fly.queue_redraw()


## Words in the frog god's voice, typed out.
func _say(words: String) -> void:
	_words.text = words
	_typed = 0.0
	_words.visible_characters = 0
	_wait = 1.4


## A tap while it speaks: all of these words at once, or the next ones; after them, the choosing (or
## the waking).
func _advance() -> void:
	if _typed < _words.text.length():
		_typed = _words.text.length()
		_words.visible_characters = -1
		return
	_line += 1
	if _line < _lines.size():
		_say(_lines[_line])
	elif _step == "talk":
		_choose()
	elif _step == "after":
		_wake()


func _choose() -> void:
	_step = "choose"
	_tap.visible = false
	_scroll.visible = true
	_this_is_me.visible = true
	_sure.visible = false
	_fly.visible = false
	_say("WHAT DO YOU LOOK LIKE?")
	_typed = _words.text.length()
	_words.visible_characters = -1


## A row: its name, < its choice >, and (for colours) a little swatch of it.
func _make_row(title: String, key: String) -> Control:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var left := _button("<", _change.bind(key, -1), "quiet")
	left.custom_minimum_size = Vector2(32, 24)
	row.add_child(left)
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # (a narrow screen: it gives, not the row)
	ui.style_label(name_label, 16, DIM)
	row.add_child(name_label)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(12, 12)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(swatch)
	var value := Label.new()
	value.custom_minimum_size = Vector2(84, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui.style_label(value, 16, CREAM)
	row.add_child(value)
	var right := _button(">", _change.bind(key, 1), "quiet")
	right.custom_minimum_size = Vector2(32, 24)
	row.add_child(right)
	_values[key] = [value, swatch, row]
	return row


## One step along a row's choices, round and round.
func _change(key: String, step: int) -> void:
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	match key:
		"hat":
			_hat = _hats[(_hats.find(_hat) + step + _hats.size()) % _hats.size()]
		_:
			var count: int = {"body": look.BODY.size(), "belly": look.BELLY.size(), "pattern": look.PATTERNS.size(),
				"pattern_colour": look.BODY.size(), "eyes": look.EYES.size(), "band": look.BANDS.size()}[key]
			_look[key] = (int(_look[key]) + step + count) % count
	_blip.pitch_scale = 1.2 if step > 0 else 1.0
	_blip.play()
	_dress()


## Him as chosen so far: his colours, his hat, and each row's choice in words.
func _dress() -> void:
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	_frog.material = look.material(_look, "", _shadow)
	var pic: Texture2D = look.hat_texture(_hat)
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
			move_child(_hat_rect, at)
	elif _hat_rect.get_index() < at:
		move_child(_hat_rect, at)
	for key in _values:
		var value: Label = _values[key][0]
		var swatch: ColorRect = _values[key][1]
		swatch.visible = true
		match key:
			"body":
				value.text = look.BODY[_look.body][0]
				swatch.color = look.BODY[_look.body][1]
			"belly":
				value.text = look.BELLY[_look.belly][0]
				swatch.color = look.BELLY[_look.belly][1]
			"pattern":
				value.text = look.PATTERNS[_look.pattern]
				swatch.visible = false
			"pattern_colour":
				value.text = look.BODY[_look.pattern_colour][0]
				swatch.color = look.BODY[_look.pattern_colour][1]
			"eyes":
				value.text = look.EYES[_look.eyes][0]
				swatch.color = look.EYES[_look.eyes][1].lightened(0.15)
			"hat":
				value.text = _hat_name(_hat)
				swatch.visible = false
			"band":
				value.text = look.BANDS[_look.band][0]
				swatch.color = look.BANDS[_look.band][1]
	_values.pattern_colour[2].visible = int(_look.pattern) != 0


static func _hat_name(id: String) -> String:
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	if id == "":
		return "None"
	if look.HATS.has(id):
		return look.HATS[id][0]
	return look.UNLOCKS.get(id, ["", id.capitalize()])[1]


func _ask_sure() -> void:
	_step = "sure"
	_scroll.visible = false
	_this_is_me.visible = false
	_sure.visible = true
	_fly.visible = true
	_fly_want = 0.0
	_fly_on = 0.0
	_say("IS THIS YOU?")


func _no() -> void:
	_choose()


## Yes: that's him. Kept, and (the first time) the frog god's last words, a flash, and he wakes.
func _yes() -> void:
	MusicManager.look = _look.duplicate()
	MusicManager.equipped_hat = _hat
	MusicManager.look_made = true
	MusicManager.save_wardrobe()
	_sure.visible = false
	_fly.visible = false
	if from_wardrobe:
		_say("THERE YOU ARE.")
		_typed = _words.text.length()
		_words.visible_characters = -1
		await get_tree().create_timer(0.9, true, false, true).timeout
		_wake()
		return
	_step = "after"
	_tap.visible = true
	_lines = AFTER
	_line = 0
	_say(_lines[0])


## The flash, he's done here: the game takes over behind it, and it fades into his bedroom.
func _wake() -> void:
	if _waking:
		return
	_waking = true
	_step = ""
	_music.create_tween().tween_property(_music, "volume_db", -40.0, 0.6)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 1.0, 0.3)
	await tw.finished
	for child in get_children():
		if child is CanvasItem and child != _flash:
			child.visible = false
	done.emit()
	var out := create_tween()
	out.tween_interval(0.15)
	out.tween_property(_flash, "color:a", 0.0, 0.9)
	await out.finished
	queue_free()


## Laid out for the screen. As the frog god speaks, or asks "is this you?", he's in the middle, its
## words over him (YES and NO under him); as he chooses, he moves up (upright) or to the left
## (sideways), the choices under him or beside him, each the biggest that fits.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	(_bg.material as ShaderMaterial).set_shader_parameter("pixels", (vp * 0.5).floor())
	_voice(32 if portrait else 16)
	var px := 4.0 if portrait else 3.0  # (each of his pixels, in the screen's)
	var frog_size := Vector2(32, 32) * px
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 1.6) * 3.0
	var k := smoothstep(0.0, 1.0, _centred)
	var words_h := 96.0 if portrait else 44.0
	var gap := 20.0 if portrait else 8.0
	var rows_size := _rows.get_combined_minimum_size()
	var middle := Vector2(vp.x * 0.5, room.position.y + room.size.y * (0.52 if portrait else 0.56))
	var choosing: Vector2  # (where he is as he chooses)
	var words_w: float
	if portrait:
		var rows_w := minf(room.size.x * 0.9, 380.0)
		choosing = Vector2(vp.x * 0.5, room.position.y + 12.0 + words_h + gap + frog_size.y * 0.5)
		words_w = room.size.x - 32.0
		var top := choosing.y + frog_size.y * 0.5 + 16.0
		var tall := minf(rows_size.y, room.end.y - top - 52.0)
		_scroll.size = Vector2(rows_w, tall)
		_scroll.position = Vector2((vp.x - rows_w) * 0.5, top).round()
		_this_is_me.size = Vector2(rows_w, 32.0)
		_this_is_me.position = Vector2((vp.x - rows_w) * 0.5, top + tall + 12.0).round()
	else:
		var rows_w := clampf(room.size.x - 166.0, 260.0, 340.0)
		var left := room.size.x - rows_w - 20.0  # (his side)
		choosing = Vector2(room.position.x + left * 0.5 + 4.0,
			maxf(room.position.y + 6.0 + words_h + gap + frog_size.y * 0.5, room.position.y + room.size.y * 0.55))
		words_w = left
		var top := room.position.y + 6.0
		var tall := minf(rows_size.y, room.end.y - top - 36.0)
		_scroll.size = Vector2(rows_w, tall)
		_scroll.position = Vector2(room.end.x - rows_w - 12.0, top).round()
		_this_is_me.size = Vector2(rows_w, 28.0)
		_this_is_me.position = Vector2(_scroll.position.x, top + tall + 6.0).round()
	var centre := choosing.lerp(middle, k)
	words_w = lerpf(words_w, room.size.x - 32.0, k)
	_words.size = Vector2(words_w, words_h)
	_words.position = Vector2(centre.x - words_w * 0.5, centre.y - frog_size.y * 0.5 - gap - words_h).round()
	_scroll.modulate.a = 1.0 - k
	_this_is_me.modulate.a = 1.0 - k
	_frog.size = frog_size
	_frog.position = (centre - frog_size * 0.5 + Vector2(0, bob)).round()
	if _hat_rect.texture:
		var look: GDScript = load("res://scripts/FroggyLook.gd")
		var t := _hat_rect.texture.get_size()
		var rel := 1.0
		var off: Vector2 = look.hat_offset(_hat)
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


## The fly by YES (or NO): two pixels to each of his, his wings flapping, bobbing as he hovers.
func _draw_fly() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var rows: Array = FLY[int(now * 10.0) % 2]
	var lift := roundf(sin(now * 3.0) * 1.5)
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
