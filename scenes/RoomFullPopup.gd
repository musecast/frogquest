extends CanvasLayer
## "Online's Full Today": Muse's relay has used up its daily allowance (it's on Cloudflare's free plan:
## tickets onto it are turned away until 00:00 UTC), so playing online is off till then. Says when it's
## back, in the player's own time, that the climb goes on alone (or on the same Wi-Fi) meanwhile, and
## offers Ask for More Room: Muse counts one ask per player a day (muse_play_ask_for_room), so Jason can
## see how many wanted more, and raise the limit. Party shows it, at most once a day. The climb waits
## while it's up (the story's pause), and a tap off its buttons is never a jump.

signal closed

const GOLD := Color(0.95, 0.88, 0.65)
const GREEN := Color(0.62, 1.0, 0.62)
const DIM := Color(0.78, 0.74, 0.68)
const RED := Color(1.0, 0.6, 0.5)

var _shade: Button
var _panel: PanelContainer
var _scroll: ScrollContainer
var _note: Label
var _ask: Button
var _paused_it := false  # (it paused the climb, as the pause menu does: no jumps under it)


func _ready() -> void:
	name = "RoomFullPopup"
	layer = 95  # (over the game and its menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = 0.05  # (the story's pause: the slingshot waits)
		_paused_it = true
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var dark := ColorRect.new()  # (the screen dimmed; under the banners too)
	dark.color = Color(0, 0, 0, 0.6)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	_shade = Button.new()  # (the room round the card: a button, so a tap there is never a jump)
	_shade.flat = true
	_shade.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_shade.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(_shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # (a tap on the card, off its buttons, falls to the shade)
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	_panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("separation", 8)
	margin.add_child(frame)
	frame.add_child(_label("Online's Full Today", 32, ui.GOLD))
	_scroll = ScrollContainer.new()  # (on a short screen what's in it slides: UIStyle.fit_panel)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	box.add_child(_label("Lots of froggies are climbing! Playing online is full until %s. Keep climbing on your own, or with friends on the same Wi-Fi, till then." % reset_words(), 16, GOLD))
	_ask = _button("Ask for More Room", _on_ask, "go")
	box.add_child(_ask)
	_note = _label("", 16, GREEN)
	_note.visible = false
	box.add_child(_note)
	frame.add_child(_button("OK", _close, "wood"))
	_shade.pressed.connect(func() -> void:
		if not _panel.get_global_rect().has_point(_shade.get_global_mouse_position()):
			_close())
	_fit()
	get_viewport().size_changed.connect(_fit)


## When playing online's back (the next 00:00 UTC), in the player's own time: "7 PM", "5:30 AM".
static func reset_words(now_unix := -1.0) -> String:
	var now := now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()
	var back := (floorf(now / 86400.0) + 1.0) * 86400.0  # (the next midnight, UTC)
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))  # (minutes from UTC)
	var t := Time.get_datetime_dict_from_unix_time(int(back) + bias * 60)
	var hour: int = int(t.hour)
	var words := str(12 if hour % 12 == 0 else hour % 12)
	if int(t.minute) != 0:
		words += ":%02d" % int(t.minute)
	return words + (" PM" if hour >= 12 else " AM")


func _on_ask() -> void:
	_ask.disabled = true
	var r: Dictionary = await MuseAccount.call_rpc("muse_play_ask_for_room", {"p_app": MuseSocial.APP})
	if not is_inside_tree():
		return
	_ask.visible = false
	if r.code == 200 and r.data is Dictionary:
		var today := int(r.data.get("today", 1))
		_say("Asked! %d froggies want more room today." % today if today > 1 else "Asked! Thanks for letting us know.", GREEN)
	elif r.code == 404:
		_say("Asking isn't open yet. Thanks for wanting to!", DIM)
	else:
		_say(MuseSocial._problem(r), RED)


func _say(what: String, colour: Color) -> void:
	_note.text = what
	_note.add_theme_color_override("font_color", colour)
	_note.visible = true
	_fit()


func _close() -> void:
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if _paused_it and is_equal_approx(Engine.time_scale, 0.05):
		Engine.time_scale = 1.0  # (the climb goes on)


func _process(_delta: float) -> void:
	_fit()  # (wrapped words settle a frame late, and banners come and go)


## In the middle of the room the screen has, at the menus' size.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	_shade.position = room.position
	_shade.size = room.size
	ui.fit_panel(_panel, _scroll, room, ui.panel_zoom(vp, room), 0.9 if vp.y > vp.x * 1.3 else 0.62)


func _label(text: String, font_size: int, colour: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load("res://scripts/UIStyle.gd").style_label(lbl, font_size, colour)
	return lbl


func _button(text: String, on_press: Callable, kind: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 28)
	load("res://scripts/UIStyle.gd").style_button(btn, 16, kind)
	btn.pressed.connect(on_press)
	return btn
