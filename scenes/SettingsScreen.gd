extends CanvasLayer
## Settings, from the title screen and the pause menu: music and sound on or off, the speedrun timer,
## how hard a drag throws him (aim), the privacy policy and terms, and starting over (the climb, or
## everything, each asked first). Built in code in the menus' look (UIStyle) and placed like Muse
## account: clear of the notch and the ad banners, at a whole size, the middle scrolling if it's too
## tall. player is the story's player (player.gd), which keeps the timer and the aim. A store build says
## which it is at the bottom, and which update it's on (Updater.gd).

signal closed

const MUSIC_BUS := 1
const SOUND_BUS := 2
const AIM_RANGE := Vector2(3.0, 5.0)  # (the Sensitivity slider's ends: the middle, 4, is the default)
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
var _ask_alt: Button  # (a third choice: going harder partway up, keep climbing on it from here)
var _ask_no: Button
var _close: Button
var _pending := ""  # what YES does: "climb", "all", or a difficulty partway up ("easier:normal", "harder:hard")
var _toggles := {}  # "music", "sound", "timer" -> its ON/OFF button
var _aim_slider: HSlider
var _aim_value: Label
var _aim_moved := false  # (to be kept with the wardrobe: on letting go, or closing)
var _difficulties := {}  # "easy", "normal", "hard" (and "og", once it's unlocked) -> its button
var _difficulty_about: Label  # (what the one chosen shows)


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
	_aim_value = Label.new()
	_aim_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ui.style_label(_aim_value, FONT_SZ, ui.GOLD)
	aim_row.add_child(_aim_value)
	_aim_slider = HSlider.new()
	_aim_slider.min_value = AIM_RANGE.x
	_aim_slider.max_value = AIM_RANGE.y
	_aim_slider.step = 0.1
	_aim_slider.tick_count = 5  # (3, 3.5, 4: the middle, 4.5 and 5)
	_aim_slider.ticks_on_borders = true
	_aim_slider.focus_mode = Control.FOCUS_NONE
	_aim_slider.custom_minimum_size = Vector2(120, BTN_HEIGHT)
	_aim_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.style_slider(_aim_slider)
	_aim_slider.set_value_no_signal(MusicManager.sensitivity)
	_aim_slider.value_changed.connect(_set_aim)
	_aim_slider.drag_ended.connect(func(_changed: bool) -> void: _keep_aim())
	_left.add_child(_aim_slider)
	_row("Difficulty")
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 6)
	_left.add_child(levels)
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	for mode in difficulty.choices():
		var b := _button(difficulty.NAMES[mode], _set_difficulty.bind(mode))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		levels.add_child(b)
		_difficulties[mode] = b
	_difficulty_about = Label.new()
	_difficulty_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_about.custom_minimum_size.x = 120
	ui.style_label(_difficulty_about, FONT_SZ, Color(0.78, 0.74, 0.68))
	_left.add_child(_difficulty_about)
	_upright_rule = ui.rule()
	_right.add_child(_upright_rule)
	_right.add_child(_button("Privacy Policy", ComplianceConfig.open_privacy_policy, "quiet"))
	_right.add_child(_button("Terms of Use", ComplianceConfig.open_terms_of_use, "quiet"))
	_right.add_child(ui.rule())
	_right.add_child(_button("Reset Climb", _ask_first.bind("climb"), "danger"))
	_right.add_child(_button("Delete All Data", _ask_first.bind("all"), "danger"))
	if Updater.build > 0:  # (a store build: which one, and which update it's on: what a phone has, at a glance)
		var which := Label.new()
		which.text = "Version %s (%d)" % [Updater.version, Updater.build]
		if Updater.update > 0:
			which.text += ", update %d" % Updater.update
		which.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.style_label(which, FONT_SZ, Color(0.6, 0.57, 0.52))
		_right.add_child(which)

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
	_ask_alt = _button("", _on_alt)
	_ask.add_child(_ask_alt)
	_ask_no = _button("No, Keep It", _on_no)
	_ask.add_child(_ask_no)

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
	b.custom_minimum_size.x = roundf(BTN_HEIGHT * 2.4)
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
	_aim_slider.set_value_no_signal(MusicManager.sensitivity)
	_aim_value.text = "%.1f" % MusicManager.sensitivity
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	var chosen: String = difficulty.current()
	for mode in _difficulties:
		ui.style_button(_difficulties[mode], FONT_SZ, "go" if mode == chosen else "wood")
	var about: String = difficulty.ABOUT[chosen]
	if chosen in ["hard", "og"] and player and player.has_method("climb_is_hard") and not player.climb_is_hard():
		about += " " + difficulty.HARD_FROM_START
	_difficulty_about.text = about
	_toggles["timer"].disabled = player == null


func _set_bus(bus: int) -> void:
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh()


func _toggle_timer() -> void:
	if player:
		player.set_speedrun(not bool(player.get("SpeedrunMode")))
	_refresh()


## A difficulty picked. Partway up a climb, with an achievement at stake, it asks first: easier, and the
## climb stops counting for it (even if you go back); harder, and it only counts from a climb's first
## jump, so start over on it, or keep climbing on it from here without.
func _set_difficulty(mode: String) -> void:
	var stakes := _difficulty_stakes(mode)
	if stakes.is_empty():
		_apply_difficulty(mode)
	else:
		_ask_difficulty(mode, stakes)


func _apply_difficulty(mode: String) -> void:
	if player and player.has_method("set_difficulty"):
		player.set_difficulty(mode)
	else:  # (no climb here: just the choice, for next time)
		MusicManager.difficulty = mode
		MusicManager.save_wardrobe()
	_refresh()


## What picking `mode` partway up this climb would cost: {"lose": [names]}, the achievements (not yet
## earned) the climb would stop counting for, going easier; {"start": name}, the one it can't count for
## unless started over, going harder. Empty when nothing's at stake (no climb under way, before its first
## jump, or nothing left to earn).
func _difficulty_stakes(mode: String) -> Dictionary:
	if player == null or not player.has_method("climb_is_hard") or int(player.get("jumpCount")) == 0:
		return {}
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	if mode == difficulty.current():
		return {}  # (the one it's on already: asked when it was chosen)
	var achievements: GDScript = load("res://scripts/Achievements.gd")
	var now := int(player.get("easiest_rank"))
	var to: int = difficulty.rank(mode)
	var goals := {"og": "beat_og", "hard": "beat_hard"}  # (the hardest first)
	var lose: Array[String] = []
	for level in goals:
		var needs: int = difficulty.rank(level)
		if achievements.has(goals[level]):
			continue
		if to < now and now >= needs and to < needs:
			lose.append(achievements.LIST[goals[level]].name)
		elif to > now and to >= needs and now < needs:
			return {"start": achievements.LIST[goals[level]].name}
	return {"lose": lose} if not lose.is_empty() else {}


func _ask_difficulty(mode: String, stakes: Dictionary) -> void:
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	var name_of: String = difficulty.NAMES[mode]
	var on := "in OG mode" if mode == "og" else "on " + name_of
	if stakes.has("lose"):
		_pending = "easier:" + mode
		_ask_words.text = "Switch to %s? This climb won't count for %s anymore, even if you switch back later." % [
			name_of, " or ".join(stakes.lose)]
		_ask_yes.text = "Switch to %s" % name_of
		_ask_no.text = "Keep %s" % difficulty.NAMES[difficulty.current()]
		_ask_alt.visible = false
	else:
		_pending = "harder:" + mode
		_ask_words.text = ("%s is for climbing the whole tree %s, from the very first jump. Start over %s to go for it, "
			+ "or keep climbing %s from here (this climb won't count for %s).") % [stakes.start, on, on, on, stakes.start]
		_ask_yes.text = "Start Over on " + name_of
		_ask_alt.text = "Keep Climbing on " + name_of
		_ask_alt.visible = true
		_ask_no.text = "Never Mind"
	_show_ask()


func _set_aim(sensitivity: float) -> void:
	if player and player.has_method("set_aim"):
		player.set_aim(sensitivity)
	else:
		MusicManager.sensitivity = sensitivity
	_aim_moved = true
	_aim_value.text = "%.1f" % sensitivity


## The slider let go (or the settings closed): kept with the wardrobe, once.
func _keep_aim() -> void:
	if _aim_moved:
		_aim_moved = false
		MusicManager.save_wardrobe()


func _exit_tree() -> void:
	_keep_aim()


func _ask_first(what: String) -> void:
	_pending = what
	if what == "all":
		_ask_words.text = "Delete all your data? Your climb, your wardrobe and your best scores, gone for good."
		_ask_yes.text = "Yes, Delete It All"
	else:
		_ask_words.text = "Reset your climb? You'll start again from the very bottom."
		_ask_yes.text = "Yes, Reset It"
	_ask_alt.visible = false
	_ask_no.text = "No, Keep It"
	_show_ask()


func _show_ask() -> void:
	_list.visible = false
	_ask.visible = true
	_close.visible = false
	_scroll.scroll_vertical = 0


func _on_yes() -> void:
	if _pending.begins_with("easier:"):
		_apply_difficulty(_pending.trim_prefix("easier:"))
		_on_no()
		return
	if _pending.begins_with("harder:"):  # (start over on it: a new climb takes the difficulty chosen)
		MusicManager.difficulty = _pending.trim_prefix("harder:")
		MusicManager.save_wardrobe()
		if player:
			player.reset_progress("climb")  # (reloads the game: this screen goes with it)
		return
	if player:
		player.reset_progress(_pending)  # (reloads the game: this screen goes with it)


## Going harder partway up: keep climbing on it from here (the climb won't count for its achievement).
func _on_alt() -> void:
	if _pending.begins_with("harder:"):
		_apply_difficulty(_pending.trim_prefix("harder:"))
	_on_no()


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
