extends CanvasLayer
## Sign in with your Muse account (the one from Muse Shelf and the other Muse apps) by the code Muse
## emails you. With Muse Pro, this is Frog Quest+. Opened from the title screen's MUSE ACCOUNT button
## and from Remove Ads; built in code and dressed like RemoveAdsScreen. MuseAccount.gd does the talking.

signal closed

const BTN_HEIGHT := 38
const BTN_FONT_SZ := 16
const TITLE_FONT_SZ := 22
const BODY_FONT_SZ := 14
const GOLD := Color(0.95, 0.88, 0.65)
const GREEN := Color(0.5, 1.0, 0.5)
const RED := Color(1.0, 0.6, 0.5)
const BLACK := Color(0.0, 0.0, 0.0, 1.0)

var _font: Font
var _panel: PanelContainer
var _body: Label
var _pro_note: Label
var _input: LineEdit
var _primary: Button
var _secondary: Button
var _status: Label
var _buttons: Array[Button] = []
var _sent_to := ""  # where the code went, between "Email Me a Code" and "Sign In"
var _busy := false


func _ready() -> void:
	layer = 60  # over the title screen (layer 58) and Remove Ads
	_build_ui()
	_show_state()
	_fit()
	MuseAccount.changed.connect(_show_state)


func _build_ui() -> void:
	_font = load("res://assets/fibberish.ttf")

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.13, 0.10, 0.08, 0.97)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.75, 0.65, 0.45, 0.9)
	panel_style.set_corner_radius_all(8)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)  # (placed by _fit)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 16)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	box.add_child(_label("Muse Account", TITLE_FONT_SZ, GOLD, 6))
	_body = _label("", BODY_FONT_SZ, GOLD, 4)
	box.add_child(_body)
	_pro_note = _label("", BODY_FONT_SZ, GREEN, 4)
	box.add_child(_pro_note)

	_input = LineEdit.new()
	_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_input.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	_input.add_theme_font_override("font", _font)
	_input.add_theme_font_size_override("font_size", BTN_FONT_SZ)
	_input.text_submitted.connect(func(_text: String) -> void: _on_primary())
	box.add_child(_input)

	_primary = _button("", _on_primary)
	box.add_child(_primary)
	_secondary = _button("", _on_secondary)
	box.add_child(_secondary)

	_status = _label("", BODY_FONT_SZ, RED, 4)
	_status.visible = false
	box.add_child(_status)

	box.add_child(_button("Privacy Policy", ComplianceConfig.open_privacy_policy))
	box.add_child(_button("Close", func() -> void: closed.emit()))


## Fills the panel in for where you are: signed out, waiting on the code, or signed in.
func _show_state() -> void:
	_pro_note.visible = false
	if MuseAccount.is_signed_in():
		_body.text = "Signed in as\n%s" % MuseAccount.email
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
	elif _sent_to != "":
		_body.text = "Muse emailed a code to\n%s" % _sent_to
		_ask("Code from the email", LineEdit.KEYBOARD_TYPE_NUMBER, 10)
		_primary.text = "Sign In"
		_secondary.text = "Use a Different Email"
		_secondary.visible = true
	else:
		_body.text = "Sign in with your Muse account, the one from Muse Shelf. With Muse Pro, this is Frog Quest+: %s." % _perks()
		_ask("Email", LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS, 254)
		_primary.text = "Email Me a Code"
		_secondary.visible = false


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
	elif _sent_to != "":
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
		_show_state()
	else:
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
		_show_state()


func _on_secondary() -> void:
	if _busy:
		return
	_say("")
	if MuseAccount.is_signed_in():
		MuseAccount.sign_out()  # (MuseAccount.changed brings the signed-out panel)
	else:
		_sent_to = ""
		_show_state()


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


func _process(_delta: float) -> void:
	_fit()


## Centres the panel and shrinks it, all together, when the screen is too short or narrow for it
## (every frame: wrapped text settles a frame late, and the keyboard comes and goes). On a phone it
## also lifts it so what you're typing, and the button under it, stay above the keyboard.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0 or vp.y < 50.0:
		return
	var portrait := vp.y > vp.x * 1.3
	var zoom := 1.4 if portrait else 1.0  # (upright on a phone: laid out narrower, shown bigger)
	_panel.custom_minimum_size = Vector2(vp.x * (0.82 if portrait else 0.42) / zoom, 0)
	var need := _panel.get_combined_minimum_size()
	var s := minf(zoom, minf(vp.x * 0.96 / need.x, vp.y * 0.94 / need.y))
	_panel.size = need
	_panel.scale = Vector2(s, s)
	var pos := (vp - need * s) / 2.0
	var keyboard := float(DisplayServer.virtual_keyboard_get_height())
	if keyboard > 0.0 and _input.visible and _input.has_focus():
		var keyboard_top := vp.y - keyboard * vp.y / maxf(1.0, float(DisplayServer.window_get_size().y))
		var primary_bottom := (_panel.get_global_transform().affine_inverse() * _primary.get_global_rect().end).y
		pos.y -= maxf(0.0, pos.y + primary_bottom * s + 8.0 - keyboard_top)
	_panel.position = pos


func _label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", _font)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", BLACK)
	lbl.add_theme_constant_override("outline_size", outline)
	return lbl


func _button(text: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.16, 0.12, 1.0)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.75, 0.65, 0.45, 0.9)
	normal.set_corner_radius_all(5)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.30, 0.24, 0.18, 1.0)
	hover.border_color = Color(0.95, 0.85, 0.55, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.09, 0.07, 1.0)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", BTN_FONT_SZ)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		btn.add_theme_color_override(state, GOLD)
	btn.add_theme_color_override("font_outline_color", BLACK)
	btn.add_theme_constant_override("outline_size", 6)
	btn.pressed.connect(on_press)
	_buttons.append(btn)
	return btn
