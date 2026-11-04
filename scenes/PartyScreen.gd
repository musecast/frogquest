extends CanvasLayer
## PLAY TOGETHER: a party of up to 16 frogs (Party.MAX_PLAYERS), each on their own phone, up the World Tree
## (each in their own world: StoryParty) or the same Endless tower; the host picks which as they start.
## Host one (and read out its code) or join one by its code, on the same Wi-Fi; pick your party colour
## and the name over your frog (your Muse @handle when you have one), and turn name tags on or off.
## Opened from the title's PLAY TOGETHER. Party.gd does the networking; built in code and dressed like
## MuseAccountScreen.

signal closed

const BTN_HEIGHT := 28
const BTN_FONT_SZ := 16  # (the pixel font is drawn on a 16-pixel grid)
const TITLE_FONT_SZ := 32
const BODY_FONT_SZ := 16
const GOLD := Color(0.95, 0.88, 0.65)
const GREEN := Color(0.5, 1.0, 0.5)
const RED := Color(1.0, 0.6, 0.5)
const DIM := Color(0.78, 0.74, 0.68)

var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _bottom: Button  # Close, or Leave Party in a party
var _input: LineEdit  # the code to join
var _mode := "menu"  # menu, join, host (your party) or joined (someone else's)
var _note := ""
var _note_colour := GOLD
var _typed := ""
var _keyboard: Node  # (KeyboardHelp: a tap off the box puts the keyboard away; how far to lift for it)


func _ready() -> void:
	layer = 60  # over the title screen (layer 58)
	_keyboard = load("res://scripts/KeyboardHelp.gd").new()
	add_child(_keyboard)
	if Party.is_on():
		_mode = "host" if Party.is_host() else "joined"
	_build_ui()
	_show()
	Party.players_changed.connect(_on_players_changed)
	Party.ended.connect(_on_ended)
	Party.started.connect(func() -> void:
		if Party.mode == "story":
			closed.emit())  # (up the tree: the climb takes over from here)


func _build_ui() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_panel)  # (placed by _fit)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	_panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	margin.add_child(frame)
	frame.add_child(_label("Play Together", TITLE_FONT_SZ, ui.GOLD))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	_bottom = _button("Close", _on_bottom)
	frame.add_child(_bottom)


## Fills the panel in for where you are: choosing, joining, or in a party (yours or someone's).
func _show() -> void:
	if _input:
		_typed = _input.text
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_input = null
	match _mode:
		"join":
			_box.add_child(_label("Type the party code from the host's screen. You both need to be on the same Wi-Fi.", BODY_FONT_SZ, GOLD))
			_input = _line("Party code", 4)
			_input.text_submitted.connect(func(text: String) -> void:
				if text.strip_edges() != "":  # (empty, Return just puts the keyboard away)
					_join())
			_box.add_child(_input)
			_box.add_child(_button("Join", _join, "go"))
			_say_note()
			_box.add_child(_button("Back", func() -> void: _go("menu"), "quiet"))
		"host":
			if Party.is_online():
				_box.add_child(_label("Your online party", BODY_FONT_SZ, GOLD))
				_box.add_child(_label("Friends anywhere can tap Join by your name in their Friends list, or you can invite them.", BODY_FONT_SZ, GOLD))
				_box.add_child(_button("Invite Friends", _open_friends))
				_players()
				_starts()
				_say_note()
				_bottom.text = "Leave Party"
				load("res://scripts/UIStyle.gd").finger_scroll(_scroll)
				_fit()
				return
			var code := Party.code()
			_box.add_child(_label("Your party code", BODY_FONT_SZ, GOLD))
			var big := _label(code if code != "" else "----", 32, load("res://scripts/UIStyle.gd").GOLD)
			big.autowrap_mode = TextServer.AUTOWRAP_OFF
			_box.add_child(big)
			_box.add_child(_label("Friends on this Wi-Fi tap Play Together, then Join a Party, and type it in." if code != ""
				else "This phone isn't on Wi-Fi: join one, then friends can find your party.", BODY_FONT_SZ, GOLD if code != "" else RED))
			_players()
			_starts()
			_say_note()
		"connecting":
			_box.add_child(_label("Connecting to the party...", BODY_FONT_SZ, DIM))
			_say_note()
		"joined":
			var host_name := str(Party.players.get(1, {}).get("name", "the host"))
			_box.add_child(_label("You're in %s's party!" % host_name, BODY_FONT_SZ, GREEN))
			_players()
			_box.add_child(_label("Waiting for the host to start the climb...", BODY_FONT_SZ, DIM))
			_say_note()
		_:
			_box.add_child(_label("Up to %d frogs, up the World Tree or an Endless tower." % Party.MAX_PLAYERS, BODY_FONT_SZ, DIM))
			_header("Same Wi-Fi")
			_row([_button("Host", _host, "go"), _button("Join", func() -> void: _go("join"))])
			if MuseSocial.rooms_live:  # (online only once Muse's rooms answer: nothing "coming soon" in a store build)
				_header("Online")
				if MuseSocial.is_member():
					_box.add_child(_button("Host Online Party", _online.bind("host"), "go"))
					_box.add_child(_button("Play with Anyone", _online.bind("anyone")))
				else:
					_box.add_child(_label("Sign in to Muse (Muse Account) to play online.", BODY_FONT_SZ, DIM))
			_say_note()
			_look()
	_bottom.text = "Leave Party" if _mode in ["host", "joined", "connecting"] else "Close"
	load("res://scripts/UIStyle.gd").finger_scroll(_scroll)
	_fit()


## Who's in the party, you marked.
func _players() -> void:
	_box.add_child(_label("Frogs here (%d of %d)" % [Party.players.size(), Party.MAX_PLAYERS], BODY_FONT_SZ, GOLD))
	var ids := Party.players.keys()
	ids.sort()
	for id in ids:
		var who := str(Party.players[id].get("name", Party.NAME))
		_box.add_child(_label(who + (" (you)" if int(id) == Party.me() else ""), BODY_FONT_SZ, GREEN if int(id) == Party.me() else DIM))


## The host's two ways to start: up the World Tree (everyone appears beside you, each in their own world)
## or a new Endless tower for all.
func _starts() -> void:
	_box.add_child(_button("Climb the World Tree", func() -> void: Party.start("story"), "go"))
	_box.add_child(_button("Climb Endless", func() -> void: Party.start("endless")))


## You, as your friends see you: your froggy (your look: FroggyLook) and, signed in to Muse, your
## @handle over him (there's no name to give: everyone's lil froggy), name tags and tethers.
func _look() -> void:
	_header("You")
	if MuseSocial.is_member():
		_box.add_child(_label("Friends see you as %s" % Party.display_name(), BODY_FONT_SZ, GOLD))
	else:
		_box.add_child(_label("Sign in to Muse and friends see your @handle over you.", BODY_FONT_SZ, DIM))
	_box.add_child(_label("You climb as your froggy. Change your look in the Wardrobe.", BODY_FONT_SZ, DIM))
	_box.add_child(_button("Name Tags: %s" % ("On" if Party.name_tags else "Off"), func() -> void:
		Party.set_name_tags(not Party.name_tags)
		_show(), "go" if Party.name_tags else "quiet"))
	_box.add_child(_button("Tethers: %s" % ("On" if Party.tethers else "Off"), func() -> void:
		Party.set_tethers(not Party.tethers)
		_show(), "go" if Party.tethers else "quiet"))
	_box.add_child(_label("With tethers, a friend pulls you up when you fall.", BODY_FONT_SZ, DIM))
	if MuseSocial.rooms_live and MuseSocial.is_member():
		_box.add_child(_button("Climb with Everyone: %s" % ("On" if Party.with_everyone else "Off"), func() -> void:
			Party.set_with_everyone(not Party.with_everyone)
			_show(), "go" if Party.with_everyone else "quiet"))
		_box.add_child(_label("On the World Tree, see everyone online climbing too. Friends can join you from their Friends list.", BODY_FONT_SZ, DIM))


## A section's name, in gold, over a thin line.
func _header(text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	_box.add_child(gap)
	_box.add_child(_label(text, BODY_FONT_SZ, load("res://scripts/UIStyle.gd").GOLD))
	var line := ColorRect.new()
	line.color = Color(GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(line)


## Buttons side by side, sharing the width.
func _row(buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_box.add_child(row)


## Online: hosting (friends join from their Friends list) or Play with Anyone (a public party).
func _online(how: String) -> void:
	_say("Joining a public party..." if how == "anyone" else "Starting your online party...", DIM)
	var problem: String
	if how == "anyone":
		problem = await Party.play_with_anyone()
	else:
		problem = await Party.host_online()
	if problem != "":
		_say(problem, RED)
		return
	_mode = "connecting"
	_note = ""
	_show()


func _open_friends() -> void:
	var screen = load("res://scenes/FriendsScreen.gd").new()
	add_child(screen)
	screen.closed.connect(screen.queue_free)


func _host() -> void:
	var problem := Party.host()
	if problem != "":
		_say(problem, RED)
		return
	_note = "If your phone asks to find devices on your local network, tap Allow."
	_note_colour = DIM
	_go("host", false)


func _join() -> void:
	var code := (_input.text if _input else _typed).strip_edges()
	if code == "":
		_say("Type the party code first.", RED)
		return
	var problem := Party.join(code)
	if problem != "":
		_say(problem, RED)
		return
	_say("Looking for the party... If your phone asks to find devices on your local network, tap Allow.", DIM)


func _on_players_changed() -> void:
	if _mode in ["join", "connecting"] and Party.is_on() and Party.players.has(Party.me()):
		_note = ""
		_mode = "host" if Party.is_host() else "joined"
	elif _mode in ["joined", "connecting"] and Party.is_on() and Party.is_host():
		_mode = "host"  # (online, the host left: you've been there longest now)
	if _mode in ["host", "joined", "join", "connecting"]:
		_show()


func _on_ended(why: String) -> void:
	_mode = "menu"
	_say(why if why != "" else "You left the party.", RED if why != "" else DIM)


func _on_bottom() -> void:
	if _mode in ["host", "joined", "connecting"]:
		Party.leave()
		_go("menu")
	else:
		closed.emit()


func _go(mode: String, clear_note := true) -> void:
	_mode = mode
	_typed = ""
	if clear_note:
		_note = ""
	_show()


func _say(what: String, colour: Color) -> void:
	_note = what
	_note_colour = colour
	_show()


func _say_note() -> void:
	if _note != "":
		_box.add_child(_label(_note, BODY_FONT_SZ, _note_colour))


func _process(_delta: float) -> void:
	_fit()


## Centred in the room the screen has, like MuseAccountScreen (UIStyle.fit_panel), lifted above the
## keyboard while you type.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0 or vp.y < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	var s: float = ui.panel_zoom(vp, room)
	ui.fit_panel(_panel, _scroll, room, s, 0.9 if portrait else 0.62)
	var keyboard: float = _keyboard.height_for(_input)
	var lift := 0.0
	if keyboard > 0.0 and _input:
		_scroll.ensure_control_visible(_input)
		var keyboard_top := vp.y - keyboard * vp.y / maxf(1.0, float(DisplayServer.window_get_size().y))
		var input_bottom := (_panel.get_global_transform().affine_inverse() * _input.get_global_rect().end).y
		lift = maxf(0.0, _panel.position.y + (input_bottom + BTN_HEIGHT + 10.0) * s + 8.0 - keyboard_top)
	_panel.position.y = _keyboard.glide(_panel.position.y, _panel.position.y - lift)
	_panel.position = _panel.position.round()


func _line(placeholder: String, longest: int) -> LineEdit:
	var line := LineEdit.new()
	line.placeholder_text = placeholder
	line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	line.max_length = longest
	line.add_theme_font_override("font", load("res://assets/fibberish.ttf"))
	line.add_theme_font_size_override("font_size", BTN_FONT_SZ)
	return line


func _label(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load("res://scripts/UIStyle.gd").style_label(lbl, font_size, color)
	return lbl


func _button(text: String, on_press: Callable, kind := "wood") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	load("res://scripts/UIStyle.gd").style_button(btn, BTN_FONT_SZ, kind)
	btn.pressed.connect(on_press)
	return btn
