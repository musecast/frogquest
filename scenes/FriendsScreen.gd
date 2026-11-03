extends CanvasLayer
## Your Muse friends (Muse Social: the same friends as Muse Shelf and the other Muse apps): what each
## is up to, adding friends by @handle, answering requests, and removing, blocking or reporting someone;
## and your own status for every Muse app (online, away, do not disturb or invisible). Opened from the
## Muse Account screen once Muse Social's there (MuseSocial.available). Built in code and dressed like
## MuseAccountScreen; MuseSocial.gd does the talking.

signal closed

const BTN_HEIGHT := 28
const BTN_FONT_SZ := 16  # (the pixel font is drawn on a 16-pixel grid)
const TITLE_FONT_SZ := 32
const BODY_FONT_SZ := 16
const GOLD := Color(0.95, 0.88, 0.65)
const GREEN := Color(0.5, 1.0, 0.5)
const RED := Color(1.0, 0.6, 0.5)
const DIM := Color(0.78, 0.74, 0.68)
const DOTS := {"online": Color(0.45, 0.95, 0.45), "away": Color(1.0, 0.8, 0.3), "dnd": Color(1.0, 0.42, 0.38), "offline": Color(0.5, 0.5, 0.5)}
const STATUS_WORDS := {"online": "Online", "away": "Away", "dnd": "Do Not Disturb", "invisible": "Invisible"}
const APP_NAMES := {"frog-quest": "Frog Quest", "muse-shelf": "Muse Shelf", "muse-penguin": "Muse Penguin", "muse-jukebox": "Muse Jukebox"}
const ACTIVITIES := {"title": "In Frog Quest", "story": "Playing the story", "endless": "Playing Endless"}

var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _input: LineEdit
var _note: Label  # what just happened (sent, added, went wrong)
var _note_text := ""
var _note_colour := GOLD
var _open := ""  # the friend whose actions are showing, or "status" for the status choices
var _reporting := ""  # the friend being reported (the reasons are showing)
var _typed := ""  # (what's in the @handle box, kept as the list is rebuilt)
var _busy := false


func _ready() -> void:
	layer = 61  # over the Muse Account screen (60)
	_build_ui()
	_show()
	MuseSocial.changed.connect(_show)
	MuseSocial.watching += 1
	MuseSocial.refresh()


func _exit_tree() -> void:
	MuseSocial.watching = maxi(0, MuseSocial.watching - 1)


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
	frame.add_child(_label("Friends", TITLE_FONT_SZ, ui.GOLD))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	frame.add_child(_button("Close", func() -> void: closed.emit()))


## Fills the list in afresh from MuseSocial: you and your status, adding a friend, requests, friends.
func _show() -> void:
	if _input:
		_typed = _input.text
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_input = null
	_note = null
	if not MuseSocial.available or not MuseAccount.is_signed_in():
		_box.add_child(_label("Sign in to your Muse account to see your friends here.", BODY_FONT_SZ, GOLD))
		_finish_list()
		return
	if MuseSocial.me.is_empty():
		_handle_step()
		_finish_list()
		return
	_box.add_child(_label("You're @%s" % MuseSocial.handle(), BODY_FONT_SZ, GOLD))
	var mine := MuseSocial.status()
	_box.add_child(_button("Status: %s" % STATUS_WORDS[mine], func() -> void: _toggle("status"), "quiet"))
	if _open == "status":
		for each in MuseSocial.STATUSES:
			if each != mine:
				_box.add_child(_button(STATUS_WORDS[each], _set_status.bind(each)))
	_input = LineEdit.new()
	_input.placeholder_text = "Their @handle"
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	_input.max_length = 21
	_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	_input.add_theme_font_override("font", load("res://assets/fibberish.ttf"))
	_input.add_theme_font_size_override("font_size", BTN_FONT_SZ)
	_input.text = _typed
	_input.text_submitted.connect(func(_text: String) -> void: _add())
	_box.add_child(_input)
	_box.add_child(_button("Add Friend", _add, "go"))
	_note = _label(_note_text, BODY_FONT_SZ, _note_colour)
	_note.visible = _note_text != ""
	_box.add_child(_note)
	if not MuseSocial.incoming.is_empty():
		_box.add_child(_label("Want to be your friend", BODY_FONT_SZ, GOLD))
		for card in MuseSocial.incoming:
			_request_row(card)
	_box.add_child(_label("Your friends" if not MuseSocial.friends.is_empty() else "No friends here yet: add one by their @handle!", BODY_FONT_SZ, GOLD))
	for card in MuseSocial.friends:
		_friend_row(card)
	if not MuseSocial.outgoing.is_empty():
		_box.add_child(_label("Waiting on", BODY_FONT_SZ, GOLD))
		for card in MuseSocial.outgoing:
			_box.add_child(_label("@" + str(card.handle), BODY_FONT_SZ, DIM))
			_box.add_child(_button("Take Back", _act.bind("unfriend", str(card.handle), "Taken back."), "quiet"))
	_finish_list()


func _finish_list() -> void:
	load("res://scripts/UIStyle.gd").finger_scroll(_scroll)
	_fit()


## Picking your @handle (the first time): it's how friends find you, the same in every Muse app. Saving
## it agrees to Muse's community rules, shown first (App Review wants them agreed to before anything
## social).
func _handle_step() -> void:
	_box.add_child(_label("Pick your @handle: it's how friends find you, the same in every Muse app.", BODY_FONT_SZ, GOLD))
	_input = LineEdit.new()
	_input.placeholder_text = "your_handle"
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	_input.max_length = 20
	_input.add_theme_font_override("font", load("res://assets/fibberish.ttf"))
	_input.add_theme_font_size_override("font_size", BTN_FONT_SZ)
	_input.text = _typed
	_input.text_submitted.connect(func(_text: String) -> void: _save_handle())
	_box.add_child(_input)
	_box.add_child(_label("3 to 20 letters, numbers or underscores.", BODY_FONT_SZ, DIM))
	_box.add_child(_label("Be kind: no bullying, hate, or anything sexual. Muse can hide anyone who breaks the community rules.", BODY_FONT_SZ, GOLD))
	_box.add_child(_button("Read the Community Rules", func() -> void: OS.shell_open(MuseSocial.COMMUNITY_RULES), "quiet"))
	_box.add_child(_button("Agree and Save", _save_handle, "go"))
	_note = _label(_note_text, BODY_FONT_SZ, _note_colour)
	_note.visible = _note_text != ""
	_box.add_child(_note)


func _save_handle() -> void:
	var wanted := (_input.text if _input else _typed).strip_edges().trim_prefix("@").to_lower()
	if wanted.length() < 3:
		_say("Your @handle needs at least 3 letters or numbers.", RED)
		return
	if _busy:
		return
	_busy = true
	var problem: String = await MuseSocial.save_profile(wanted, true)
	_busy = false
	if problem == "":
		_typed = ""
		_say("You're @%s! Now add a friend by their @handle." % wanted, GREEN)
	else:
		_say(problem, RED)


## One friend: a dot for how they are, their @handle, what they're doing; and, opened, Remove, Block
## and Report (anyone shown here can be blocked or reported).
func _friend_row(card: Dictionary) -> void:
	var who := str(card.handle)
	var state := str(card.get("state", "offline")) if MuseSocial.presence_live else ""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if state != "":
		var dot := ColorRect.new()
		dot.color = DOTS.get(state, DOTS.offline)
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	var name_label := _label("@" + who, BODY_FONT_SZ, GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(name_label)
	if state != "":
		var doing := _label(_doing(card), BODY_FONT_SZ, DIM)
		doing.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		words.add_child(doing)
	row.add_child(words)
	var more := _button("...", func() -> void: _toggle(who), "quiet")
	more.size_flags_horizontal = Control.SIZE_SHRINK_END
	more.custom_minimum_size = Vector2(BTN_HEIGHT * 1.5, BTN_HEIGHT)
	row.add_child(more)
	_box.add_child(row)
	if _open == who:
		if _reporting == who:
			_box.add_child(_label("Report @%s for:" % who, BODY_FONT_SZ, GOLD))
			for reason in MuseSocial.REPORT_REASONS:
				_box.add_child(_button(reason.capitalize(), _report.bind(who, reason), "quiet"))
		else:
			_box.add_child(_button("Remove Friend", _act.bind("unfriend", who, "@%s isn't your friend any more." % who), "quiet"))
			_box.add_child(_button("Block", _act.bind("block", who, "Blocked @%s: you won't see each other in Muse." % who), "quiet"))
			_box.add_child(_button("Report", func() -> void:
				_reporting = who
				_show(), "quiet"))


## A friend request: their @handle, then Yes and No (and Block, for unwanted ones).
func _request_row(card: Dictionary) -> void:
	var who := str(card.handle)
	_box.add_child(_label("@" + who, BODY_FONT_SZ, GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for each in [["Yes", _answer.bind(who, true), "go"], ["No", _answer.bind(who, false), "quiet"], ["Block", _act.bind("block", who, "Blocked @%s." % who), "quiet"]]:
		var btn := _button(each[0], each[1], each[2])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	_box.add_child(row)


## What a friend's doing, in words: "Playing Endless", "In Muse Shelf", "Away", "Offline"...
func _doing(card: Dictionary) -> String:
	var state := str(card.get("state", "offline"))
	var app := str(card.get("app", ""))
	if state == "offline":
		return "Offline"
	var where := ""
	if app == MuseSocial.APP:
		where = ACTIVITIES.get(str(card.get("activity", "")), "In Frog Quest")
	elif app != "":
		where = "In " + APP_NAMES.get(app, "a Muse app")
	match state:
		"away":
			return "Away" + (" (%s)" % where.to_lower() if where != "" else "")
		"dnd":
			return "Do not disturb"
	return where if where != "" else "Online"


func _toggle(what: String) -> void:
	_open = "" if _open == what else what
	_reporting = ""
	_show()


func _set_status(what: String) -> void:
	_open = ""
	if _start_action():
		_end_action(await MuseSocial.set_status(what), "You're %s." % STATUS_WORDS[what].to_lower() if what != "dnd" else "Do not disturb is on.")


func _add() -> void:
	var who := (_input.text if _input else _typed).strip_edges().trim_prefix("@").to_lower()
	if who == "":
		_say("Type their @handle first.", RED)
		return
	if _busy:
		return
	_busy = true
	var result: String = await MuseSocial.add_friend(who)
	_busy = false
	if result == "requested":
		_typed = ""
		_say("Asked @%s to be friends." % who, GREEN)
	elif result == "friends":
		_typed = ""
		_say("You and @%s are friends now!" % who, GREEN)
	else:
		_say(result, RED)


func _answer(who: String, accept: bool) -> void:
	if _start_action():
		_end_action(await MuseSocial.answer_request(who, accept), "You and @%s are friends now!" % who if accept else "Said no to @%s." % who)


func _act(what: String, who: String, done: String) -> void:
	_open = ""
	if not _start_action():
		return
	var problem := ""
	match what:
		"unfriend":
			problem = await MuseSocial.unfriend(who)
		"block":
			problem = await MuseSocial.block(who)
	_end_action(problem, done)


func _report(who: String, reason: String) -> void:
	_open = ""
	_reporting = ""
	if _start_action():
		_end_action(await MuseSocial.report(who, reason), "Thanks: the Muse team will look at @%s." % who)


## One of MuseSocial's actions at a time (a second tap meanwhile does nothing).
func _start_action() -> bool:
	if _busy:
		return false
	_busy = true
	return true


## How it went: "" when it worked (then `done` is said), else what went wrong.
func _end_action(problem: String, done: String) -> void:
	_busy = false
	_say(done if problem == "" else problem, GREEN if problem == "" else RED)


func _say(what: String, colour: Color) -> void:
	_note_text = what
	_note_colour = colour
	_show()


func _process(_delta: float) -> void:
	_fit()


## Centred in the room the screen has, like MuseAccountScreen (UIStyle.fit_panel), lifted above the
## keyboard while you type a handle.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0 or vp.y < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	var s: float = ui.panel_zoom(vp, room)
	ui.fit_panel(_panel, _scroll, room, s, 0.9 if portrait else 0.62)
	var keyboard := float(DisplayServer.virtual_keyboard_get_height())
	if keyboard > 0.0 and _input and _input.has_focus():
		_scroll.ensure_control_visible(_input)
		var keyboard_top := vp.y - keyboard * vp.y / maxf(1.0, float(DisplayServer.window_get_size().y))
		var input_bottom := (_panel.get_global_transform().affine_inverse() * _input.get_global_rect().end).y
		_panel.position.y -= maxf(0.0, _panel.position.y + (input_bottom + BTN_HEIGHT + 10.0) * s + 8.0 - keyboard_top)
		_panel.position = _panel.position.round()


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
