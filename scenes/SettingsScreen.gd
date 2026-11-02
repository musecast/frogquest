extends CanvasLayer
## Settings, from the title screen and the pause menu: music and sound on or off, the speedrun timer,
## how hard a drag throws him (aim), the privacy policy and terms, and starting over (the climb, or
## everything, each asked first). Built in code in the menus' look (UIStyle) and placed like Muse
## account: clear of the notch and the ad banners, at a whole size, the middle scrolling if it's too
## tall. player is the story's player (player.gd), which keeps the timer and the aim.

signal closed

const MUSIC_BUS := 1
const SOUND_BUS := 2
const AIMS := [["L", 3.5], ["M", 4.0], ["H", 4.5]]  # (what the old L/M/H buttons set)
const FONT_SZ := 16
const BTN_HEIGHT := 28

var player: Node
var _panel: PanelContainer
var _frame: VBoxContainer  # the title, what scrolls, then Close
var _title: Label
var _scroll: ScrollContainer
var _list: GridContainer  # the settings: one column upright, two sideways (where there's width, not height)
var _left: VBoxContainer  # (music, sound, the timer, sensitivity)
var _right: VBoxContainer  # (the privacy policy and terms, starting over)
var _upright_rule: HSeparator  # (between the two, when they're one column)
var _ask: VBoxContainer  # "Reset your climb?" and the like
var _ask_words: Label
var _ask_yes: Button
var _close: Button
var _pending := ""  # what YES does: "climb" or "all"
var _toggles := {}  # "music", "sound", "timer" -> its ON/OFF button
var _aims: Array[Button] = []


func _ready() -> void:
	name = "SettingsScreen"
	layer = 61  # (over the title (58), the pause menu and Muse account (60); under the privacy policy)
	_build()
	_refresh()
	_fit()


func _build() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # (shown twice as big upright: square pixels)
	add_child(_panel)  # (placed by _fit)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	_panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	margin.add_child(frame)
	_frame = frame

	_title = Label.new()
	_title.text = "Settings"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.style_label(_title, 32, ui.GOLD)
	frame.add_child(_title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)

	_list = GridContainer.new()
	_list.add_theme_constant_override("h_separation", 16)
	_list.add_theme_constant_override("v_separation", 8)
	pages.add_child(_list)
	for column in 2:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(box)
	_left = _list.get_child(0)
	_right = _list.get_child(1)
	_toggles["music"] = _toggle_row("Music", func() -> void: _set_bus(MUSIC_BUS))
	_toggles["sound"] = _toggle_row("Sound", func() -> void: _set_bus(SOUND_BUS))
	_toggles["timer"] = _toggle_row("Speedrun timer", _toggle_timer)
	var aim_row := _row("Sensitivity")
	for aim in AIMS:
		var b := _button(aim[0], _set_aim.bind(aim[1]))
		b.custom_minimum_size.x = BTN_HEIGHT * 1.3
		aim_row.add_child(b)
		_aims.append(b)
	_upright_rule = ui.rule()
	_right.add_child(_upright_rule)
	_right.add_child(_button("Privacy Policy", ComplianceConfig.open_privacy_policy, "quiet"))
	_right.add_child(_button("Terms of Use", ComplianceConfig.open_terms_of_use, "quiet"))
	_right.add_child(ui.rule())
	_right.add_child(_button("Reset Climb", _ask_first.bind("climb"), "danger"))
	_right.add_child(_button("Delete All Data", _ask_first.bind("all"), "danger"))

	_ask = VBoxContainer.new()
	_ask.add_theme_constant_override("separation", 10)
	_ask.visible = false
	pages.add_child(_ask)
	_ask_words = Label.new()
	_ask_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ask_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.style_label(_ask_words, FONT_SZ)
	_ask.add_child(_ask_words)
	_ask_yes = _button("", _on_yes, "danger")
	_ask.add_child(_ask_yes)
	_ask.add_child(_button("No, Keep It", _on_no))

	_close = _button("Close", func() -> void: closed.emit())
	frame.add_child(_close)


## A setting: its name on the left, what changes it on the right.
func _row(words: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = words
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load("res://scripts/UIStyle.gd").style_label(lbl, FONT_SZ)
	row.add_child(lbl)
	_left.add_child(row)
	return row


func _toggle_row(words: String, on_press: Callable) -> Button:
	var b := _button("", on_press)
	b.custom_minimum_size.x = BTN_HEIGHT * 2.4
	_row(words).add_child(b)
	return b


func _button(words: String, on_press: Callable, kind := "wood") -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	load("res://scripts/UIStyle.gd").style_button(b, FONT_SZ, kind)
	b.pressed.connect(_click)
	b.pressed.connect(on_press)
	return b


## Shows each setting as it is now: ON (green) or OFF, and which aim.
func _refresh() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var on := {
		"music": not AudioServer.is_bus_mute(MUSIC_BUS),
		"sound": not AudioServer.is_bus_mute(SOUND_BUS),
		"timer": player != null and bool(player.get("SpeedrunMode")),
	}
	for key in _toggles:
		var b: Button = _toggles[key]
		b.text = "ON" if on[key] else "OFF"
		ui.style_button(b, FONT_SZ, "go" if on[key] else "wood")
	var aim := _current_aim()
	for i in _aims.size():
		ui.style_button(_aims[i], FONT_SZ, "go" if is_equal_approx(AIMS[i][1], aim) else "wood")
	_toggles["timer"].disabled = player == null


func _current_aim() -> float:
	var trajectory: Node = player.get_node_or_null("Trajectory") if player else null
	return float(trajectory.get("sensitivity")) if trajectory else 3.5


func _set_bus(bus: int) -> void:
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh()


func _toggle_timer() -> void:
	if player:
		player.set_speedrun(not bool(player.get("SpeedrunMode")))
	_refresh()


func _set_aim(sensitivity: float) -> void:
	if player:
		player.set_aim(sensitivity)
	_refresh()


func _ask_first(what: String) -> void:
	_pending = what
	if what == "all":
		_ask_words.text = "Delete all your data? Your climb, your wardrobe and your best scores, gone for good."
		_ask_yes.text = "Yes, Delete It All"
	else:
		_ask_words.text = "Reset your climb? You'll start again from the very bottom."
		_ask_yes.text = "Yes, Reset It"
	_list.visible = false
	_ask.visible = true
	_close.visible = false
	_scroll.scroll_vertical = 0


func _on_yes() -> void:
	if player:
		player.reset_progress(_pending)  # (reloads the game: this screen goes with it)


func _on_no() -> void:
	_pending = ""
	_ask.visible = false
	_list.visible = true
	_close.visible = true


func _click() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load("res://assets/frogaim.wav")
	sfx.volume_db = -8.0
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _process(_delta: float) -> void:
	_fit()


## In the room the screen has (clear of the notch and the ad banners), at a whole size: twice as big
## upright on a phone, never shrunk; too tall and the middle scrolls (UIStyle.fit_panel). Sideways,
## where there's width and not height, in two columns.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0 or vp.y < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	if _list.columns != (1 if portrait else 2):  # (turned: sideways it's tighter, so it all fits unscrolled)
		_list.columns = 1 if portrait else 2
		_upright_rule.visible = portrait
		ui.style_label(_title, 32 if portrait else 16, ui.GOLD)
		_frame.add_theme_constant_override("separation", 10 if portrait else 4)
		for box in [_left, _right]:
			box.add_theme_constant_override("separation", 8 if portrait else 4)
	ui.fit_panel(_panel, _scroll, room, ui.panel_zoom(vp, room), 0.9 if portrait else 0.8)
