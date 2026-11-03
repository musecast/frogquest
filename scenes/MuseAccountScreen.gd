extends CanvasLayer
## Sign in with your Muse account (the one from Muse Shelf and the other Muse apps): through Muse
## Shelf, where you're signed in with Google, Apple or email (the game shows a code to type in there),
## or by the code Muse emails you. With Muse Pro, this is Frog Quest+. Opened from the title screen's
## MUSE ACCOUNT button and from Remove Ads; built in code and dressed like RemoveAdsScreen.
## MuseAccount.gd does the talking.

signal closed

const BTN_HEIGHT := 28
const BTN_FONT_SZ := 16  # (the pixel font is drawn on a 16-pixel grid)
const TITLE_FONT_SZ := 32
const BODY_FONT_SZ := 16
const GOLD := Color(0.95, 0.88, 0.65)
const GREEN := Color(0.5, 1.0, 0.5)
const RED := Color(1.0, 0.6, 0.5)
const BLACK := Color(0.0, 0.0, 0.0, 1.0)

var _font: Font
var _panel: PanelContainer
var _scroll: ScrollContainer  # (scrolls only if the panel's too tall for the room at 1:1: _fit)
var _body: Label
var _pro_note: Label
var _input: LineEdit
var _primary: Button
var _secondary: Button
var _status: Label
var _code: Label  # the code to type into Muse Shelf, big
var _buttons: Array[Button] = []
var _mode := ""  # signed out: "" (which way to sign in), "email", "code" (emailed) or "link" (waiting on Muse Shelf)
var _sent_to := ""  # where the code went, between "Email Me a Code" and "Sign In"
var _busy := false
var _friends: Button  # (Friends and Leaderboard: signed in, once Muse Social's there)
var _leaderboard: Button


func _ready() -> void:
	layer = 60  # over the title screen (layer 58) and Remove Ads
	_build_ui()
	_show_state()
	_fit()
	MuseAccount.changed.connect(_show_state)
	MuseSocial.changed.connect(_show_state)
	MuseAccount.link_ended.connect(_on_link_ended)
	if not MuseAccount.linking.is_empty():
		_mode = "link"  # (opened again while it's still waiting on Muse Shelf)
		_show_state()


func _build_ui() -> void:
	_font = load("res://assets/fibberish.ttf")

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", load("res://scripts/UIStyle.gd").panel_box(10))
	add_child(_panel)  # (placed by _fit)

	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	_panel.add_child(margin)
	# The title, then what's in it (it scrolls if the room's too short: _fit), then Close, always there.
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	margin.add_child(frame)
	frame.add_child(_label("Muse Account", TITLE_FONT_SZ, load("res://scripts/UIStyle.gd").GOLD, 6))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	load("res://scripts/UIStyle.gd").style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)

	_body = _label("", BODY_FONT_SZ, GOLD, 4)
	box.add_child(_body)
	_pro_note = _label("", BODY_FONT_SZ, GREEN, 4)
	box.add_child(_pro_note)
	_code = _label("", 32, load("res://scripts/UIStyle.gd").GOLD, 8)
	_code.autowrap_mode = TextServer.AUTOWRAP_OFF  # (one line: split, it read as two codes)
	_code.visible = false
	box.add_child(_code)

	_input = LineEdit.new()
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	_input.add_theme_font_override("font", _font)
	_input.add_theme_font_size_override("font_size", BTN_FONT_SZ)
	_input.text_submitted.connect(func(_text: String) -> void: _on_primary())
	box.add_child(_input)

	_primary = _button("", _on_primary, "go")
	box.add_child(_primary)
	_secondary = _button("", _on_secondary)
	box.add_child(_secondary)

	_status = _label("", BODY_FONT_SZ, RED, 4)
	_status.visible = false
	box.add_child(_status)

	_friends = _button("Friends", _open_screen.bind("res://scenes/FriendsScreen.gd"), "go")
	box.add_child(_friends)
	_leaderboard = _button("Leaderboard", _open_screen.bind("res://scenes/LeaderboardScreen.gd"))
	box.add_child(_leaderboard)
	box.add_child(_button("Privacy Policy", ComplianceConfig.open_privacy_policy))
	frame.add_child(_button("Close", func() -> void: closed.emit()))


## Fills the panel in for where you are: choosing how to sign in, typing your email, waiting on the
## emailed code, waiting on Muse Shelf, or signed in.
func _show_state() -> void:
	_pro_note.visible = false
	_code.visible = false
	_friends.visible = MuseAccount.is_signed_in() and MuseSocial.available
	_leaderboard.visible = _friends.visible
	if MuseAccount.is_signed_in():
		_mode = ""
		_body.text = "Signed in as\n%s" % MuseAccount.email
		if MuseAccount.member_since_text() != "":
			_body.text += "\nMember since %s" % MuseAccount.member_since_text()
		_pro_note.visible = true
		if MuseAccount.has_pro():
			_pro_note.text = "You have Muse Pro, so this is Frog Quest+: %s!" % _perks()
			_pro_note.add_theme_color_override("font_color", GREEN)
		else:
			_pro_note.text = "This account doesn't have Muse Pro."
			_pro_note.add_theme_color_override("font_color", GOLD)
		_input.visible = false
		_primary.text = "Check Again"
		_secondary.text = "Sign Out"
		_secondary.visible = true
	elif _mode == "link" and not MuseAccount.linking.is_empty():
		var opened_app: bool = MuseAccount.linking.get("opened_app", false)  # (then the button's the website)
		if opened_app:
			_body.text = "Muse Shelf didn't show this code? Update it, or approve it on the website instead:"
		else:
			_body.text = "Tap Open Muse Shelf, check it shows this code, and approve it there:"
		_code.text = str(MuseAccount.linking.get("code", ""))
		_code.visible = true
		_input.visible = false
		_primary.text = "Open the Website" if opened_app else "Open Muse Shelf"
		_secondary.text = "Cancel"
		_secondary.visible = true
		_wait("Waiting for Muse Shelf...")
	elif _mode == "code" and _sent_to != "":
		_body.text = "Muse emailed a code to\n%s" % _sent_to
		_ask("Code from the email", LineEdit.KEYBOARD_TYPE_NUMBER, 10)
		_primary.text = "Sign In"
		_secondary.text = "Different Email"
		_secondary.visible = true
	elif _mode == "email":
		_body.text = "Type the email of your Muse account, and Muse will email you a code."
		_ask("Email", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS, 254)
		_primary.text = "Email Me a Code"
		_secondary.text = "Back"
		_secondary.visible = true
	else:
		_mode = ""
		_body.text = "Sign in with your Muse account, the one from Muse Shelf (Google, Apple or email). With Muse Pro, this is Frog Quest+: %s." % _perks()
		_input.visible = false
		_primary.text = "Sign In with Muse Shelf"
		_secondary.text = "Sign In with Email"
		_secondary.visible = true


## Friends or the leaderboard, over this screen; back here when it's closed.
func _open_screen(path: String) -> void:
	var screen = load(path).new()
	add_child(screen)
	screen.closed.connect(screen.queue_free)


func _ask(placeholder: String, keyboard: LineEdit.VirtualKeyboardType, longest: int) -> void:
	if _input.placeholder_text != placeholder:
		_input.text = ""
	_input.placeholder_text = placeholder
	_input.virtual_keyboard_type = keyboard
	_input.max_length = longest
	_input.visible = true


## What Muse Pro does here.
func _perks() -> String:
	var perks := ["the + on the logo"]
	if AdsManager.platform_has_ads():
		perks.append("no ads")
	if load("res://scripts/DesktopFrogLink.gd").is_supported():
		perks.append("Lil Froggy on your desktop")
	if perks.size() == 1:
		return perks[0]
	return ", ".join(perks.slice(0, perks.size() - 1)) + " and " + perks[-1]


func _on_primary() -> void:
	if _busy:
		return
	if MuseAccount.is_signed_in():
		_set_busy("Checking...")
		var answered: bool = await MuseAccount.check_pro()
		_set_busy("")
		if not answered and MuseAccount.is_signed_in():
			_say("Couldn't reach Muse. Check your connection and try again.")
	elif _mode == "link":
		MuseAccount.open_muse_shelf()
		_show_state()  # (the app opened: next time, the website)
	elif _mode == "code" and _sent_to != "":
		var code := _input.text.strip_edges()
		if code.length() < 6 or not code.is_valid_int():
			_say("Type the code from the email.")
			return
		_set_busy("Signing in...")
		var problem: String = await MuseAccount.verify_code(_sent_to, code)
		_set_busy("")
		if problem != "":
			_say(problem)
			return
		_sent_to = ""
		_mode = ""
		_show_state()
	elif _mode == "email":
		var address := _input.text.strip_edges()
		if not ("@" in address and "." in address.get_slice("@", 1)):
			_say("Type the email address of your Muse account.")
			return
		_set_busy("Sending...")
		var problem: String = await MuseAccount.send_code(address)
		_set_busy("")
		if problem != "":
			_say(problem)
			return
		_sent_to = address
		_mode = "code"
		_show_state()
	else:
		_set_busy("Getting a code...")
		var problem: String = await MuseAccount.start_link()
		_set_busy("")
		if problem != "":
			_say(problem)
			return
		_mode = "link"
		_show_state()


func _on_secondary() -> void:
	if _busy:
		return
	_say("")
	if MuseAccount.is_signed_in():
		MuseAccount.sign_out()  # (MuseAccount.changed brings the signed-out panel)
		return
	match _mode:
		"link":
			MuseAccount.cancel_link()
			_mode = ""
		"code":
			_sent_to = ""
			_mode = "email"
		"email":
			_mode = ""
		_:
			_mode = "email"
	_show_state()


## Muse Shelf let us in (MuseAccount.changed has already shown it), or the code ran out or failed.
func _on_link_ended(result: String) -> void:
	_mode = ""
	_show_state()
	if result == "expired":
		_say("That code ran out. Get a new one with Sign In with Muse Shelf.")
	elif result != "":
		_say(result)


## Everything waits (Close too) while Muse is being asked, with a word on what for.
func _set_busy(what: String) -> void:
	_busy = what != ""
	for b in _buttons:
		b.disabled = _busy
	_input.editable = not _busy
	_status.add_theme_color_override("font_color", GOLD)
	_status.text = what
	_status.visible = _busy


func _say(problem: String) -> void:
	_status.add_theme_color_override("font_color", RED)
	_status.text = problem
	_status.visible = problem != ""


## A note in gold that isn't a problem (and doesn't stop the buttons).
func _wait(what: String) -> void:
	_status.add_theme_color_override("font_color", GOLD)
	_status.text = what
	_status.visible = what != ""


func _process(_delta: float) -> void:
	_fit()


## Centres the panel in the room the screen has (clear of the notch and the ad banners, which are
## drawn over everything) at a whole size, twice as big upright on a phone, so the pixel font and the
## pictures stay on their pixel grid; never shrunk (its words went to mush sideways on a phone): if
## it's too tall at 1:1, what's in it scrolls (UIStyle.fit_panel). Every frame: wrapped text settles
## a frame late, and banners come and go.
## On a phone it also lifts it so what you're typing, and the button under it, stay above the keyboard.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0 or vp.y < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)  # (clear of the notch and the ad banners)
	var portrait := vp.y > vp.x * 1.3
	var s: float = ui.panel_zoom(vp, room)
	# (sideways, wider: the words wrap onto fewer lines, so less of it has to scroll)
	ui.fit_panel(_panel, _scroll, room, s, 0.9 if portrait else 0.62)
	var keyboard := float(DisplayServer.virtual_keyboard_get_height())
	if keyboard > 0.0 and _input.visible and _input.has_focus():
		_scroll.ensure_control_visible(_input)
		var keyboard_top := vp.y - keyboard * vp.y / maxf(1.0, float(DisplayServer.window_get_size().y))
		var primary_bottom := (_panel.get_global_transform().affine_inverse() * _primary.get_global_rect().end).y
		_panel.position.y -= maxf(0.0, _panel.position.y + primary_bottom * s + 8.0 - keyboard_top)
		_panel.position = _panel.position.round()


func _label(text: String, font_size: int, color: Color, _outline: int) -> Label:
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
	_buttons.append(btn)
	return btn
