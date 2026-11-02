extends CanvasLayer

signal closed

var _main_panel: VBoxContainer
var _passcode_panel: VBoxContainer
var _code_input: LineEdit
var _status_label: Label
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _close_btn: Button = null
var _secret_tap_count := 0

const BTN_HEIGHT := 28
const BTN_FONT_SZ := 16  # (the pixel font is drawn on a 16-pixel grid)
const TITLE_FONT_SZ := 32
const SECRET_TAPS_REQUIRED := 10
const GOLD := Color(0.95, 0.88, 0.65)
const BLACK := Color(0.0, 0.0, 0.0, 1.0)


func _ready() -> void:
	layer = 20
	_build_ui()
	_fit()


func _build_ui() -> void:
	var fibberish: Font = load("res://assets/fibberish.ttf")

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", load("res://scripts/UIStyle.gd").panel_box(10))
	_panel = panel
	add_child(panel)  # (placed by _fit)

	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	panel.add_child(margin)
	# What's in it (it scrolls if the room's too short: _fit), then Close, always there.
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	margin.add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	load("res://scripts/UIStyle.gd").style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	var pages := VBoxContainer.new()  # (the main page, or the passcode one)
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)

	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 10)
	_main_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	pages.add_child(_main_panel)

	var frog_btn := TextureButton.new()
	frog_btn.texture_normal = load("res://assets/frog.png")
	frog_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frog_btn.modulate = Color.WHITE
	frog_btn.self_modulate = Color.WHITE
	frog_btn.ignore_texture_size = true
	frog_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	frog_btn.custom_minimum_size = Vector2(32, 32)  # (the frog's own size: twice that upright on a phone)
	frog_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frog_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	frog_btn.pressed.connect(_on_secret_pressed)
	_main_panel.add_child(frog_btn)

	var title := Label.new()
	title.text = "Remove Ads"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fibberish:
		title.add_theme_font_override("font", fibberish)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	load("res://scripts/UIStyle.gd").style_label(title, TITLE_FONT_SZ, load("res://scripts/UIStyle.gd").GOLD)
	_main_panel.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fibberish:
		_status_label.add_theme_font_override("font", fibberish)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.visible = false
	_main_panel.add_child(_status_label)

	if not MusicManager.ads_removed:
		var store_ready := AdsManager.has_purchase_backend()

		var buy_btn := _make_button("Remove Ads - $0.99", fibberish, "go")
		buy_btn.name = "BuyButton"
		buy_btn.disabled = not store_ready
		buy_btn.pressed.connect(_on_buy_pressed)
		_main_panel.add_child(buy_btn)

		var restore_btn := _make_button("Restore Purchases", fibberish)
		restore_btn.name = "RestoreButton"
		restore_btn.disabled = not store_ready
		restore_btn.pressed.connect(_on_restore_pressed)
		_main_panel.add_child(restore_btn)

		var muse_btn := _make_button("Muse Pro? Sign In", fibberish)
		muse_btn.name = "MuseProButton"
		muse_btn.pressed.connect(_on_muse_pro_pressed)
		_main_panel.add_child(muse_btn)

		if not store_ready:
			var backend_note := Label.new()
			backend_note.text = "Store purchases are not configured in this build yet.\nRemove Ads product: %s" % AdsManager.get_remove_ads_product_id()
			backend_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			backend_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if fibberish:
				backend_note.add_theme_font_override("font", fibberish)
			backend_note.add_theme_font_size_override("font_size", 16)
			backend_note.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65, 0.85))
			_main_panel.add_child(backend_note)
	else:
		var already := Label.new()
		already.text = "Ads already removed!"
		already.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if fibberish:
			already.add_theme_font_override("font", fibberish)
		already.add_theme_font_size_override("font_size", 16)
		already.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		_main_panel.add_child(already)

	_close_btn = _make_button("Close", fibberish)
	_close_btn.pressed.connect(_on_close_pressed)

	var privacy_btn := _make_button("Privacy Policy", fibberish)
	privacy_btn.name = "PrivacyPolicyButton"
	privacy_btn.pressed.connect(_on_privacy_policy_pressed)
	_main_panel.add_child(privacy_btn)

	var terms_btn := _make_button("Terms of Use", fibberish)
	terms_btn.name = "TermsButton"
	terms_btn.pressed.connect(_on_terms_pressed)
	_main_panel.add_child(terms_btn)

	frame.add_child(_close_btn)  # (on the main page only: the passcode page has Back)

	_passcode_panel = VBoxContainer.new()
	_passcode_panel.add_theme_constant_override("separation", 10)
	_passcode_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_passcode_panel.visible = false
	pages.add_child(_passcode_panel)

	var secret_title := Label.new()
	secret_title.text = "???"
	secret_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fibberish:
		secret_title.add_theme_font_override("font", fibberish)
	secret_title.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	secret_title.add_theme_color_override("font_color", GOLD)
	secret_title.add_theme_color_override("font_outline_color", BLACK)
	secret_title.add_theme_constant_override("outline_size", load("res://scripts/UIStyle.gd").outline_px(TITLE_FONT_SZ))
	_passcode_panel.add_child(secret_title)

	_code_input = LineEdit.new()
	_code_input.placeholder_text = "Enter code..."
	_code_input.max_length = 16
	_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_input.size_flags_horizontal = Control.SIZE_FILL
	_code_input.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	_code_input.text_submitted.connect(func(_t): _on_code_confirm())
	_passcode_panel.add_child(_code_input)

	var confirm_btn := _make_button("Enter", fibberish)
	confirm_btn.pressed.connect(_on_code_confirm)
	_passcode_panel.add_child(confirm_btn)

	var back_btn := _make_button("Back", fibberish)
	back_btn.pressed.connect(_on_passcode_back)
	_passcode_panel.add_child(back_btn)

	if not AdsManager.is_connected("ads_removed_changed", _on_ads_removed_changed):
		AdsManager.connect("ads_removed_changed", _on_ads_removed_changed)


func _make_button(label_text: String, _fibberish: Font, kind := "wood") -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	load("res://scripts/UIStyle.gd").style_button(btn, BTN_FONT_SZ, kind)
	return btn


func _process(_delta: float) -> void:
	_fit()


## Centres the panel in the room the screen has (clear of the notch and the ad banners, which are
## drawn over everything) at a whole size, twice as big upright on a phone, so the pixel font and the
## pictures stay on their pixel grid; never shrunk (its words went to mush sideways on a phone): if
## it's too tall at 1:1, what's in it scrolls (UIStyle.fit_panel). Every frame: wrapped text settles
## a frame late, and banners come and go.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if _panel == null or vp.x < 50.0 or vp.y < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	_close_btn.visible = _main_panel.visible
	ui.fit_panel(_panel, _scroll, room, ui.panel_zoom(vp, room), 0.9 if portrait else 0.5)


func _on_buy_pressed() -> void:
	AdsManager.purchase_remove_ads()


func _on_restore_pressed() -> void:
	AdsManager.restore_purchases()


## Muse Pro takes the ads away too: sign in with the Muse account (MuseAccountScreen, over this one).
func _on_muse_pro_pressed() -> void:
	var screen = load("res://scenes/MuseAccountScreen.gd").new()
	add_child(screen)
	screen.closed.connect(screen.queue_free)


func _on_privacy_policy_pressed() -> void:
	ComplianceConfig.open_privacy_policy()


func _on_terms_pressed() -> void:
	ComplianceConfig.open_terms_of_use()


func _on_close_pressed() -> void:
	emit_signal("closed")


func _on_secret_pressed() -> void:
	_secret_tap_count += 1
	if _secret_tap_count < SECRET_TAPS_REQUIRED:
		return
	_secret_tap_count = 0
	_main_panel.visible = false
	_passcode_panel.visible = true
	_code_input.text = ""
	_code_input.grab_focus()


func _on_passcode_back() -> void:
	_passcode_panel.visible = false
	_main_panel.visible = true


func _on_code_confirm() -> void:
	if AdsManager.try_code(_code_input.text):
		_show_success("Ads removed! Thanks :)")
	else:
		_code_input.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		var tree := get_tree()
		if tree:
			await tree.create_timer(0.5).timeout
		if not is_inside_tree():
			return
		_code_input.remove_theme_color_override("font_color")
		_code_input.text = ""


func _on_ads_removed_changed() -> void:
	_show_success("Ads removed! Thanks :)")


func _show_success(msg: String) -> void:
	_passcode_panel.visible = false
	_main_panel.visible = true
	for btn_name in ["BuyButton", "RestoreButton", "MuseProButton"]:
		var button := _main_panel.get_node_or_null(btn_name)
		if button:
			button.queue_free()
	_status_label.text = msg
	_status_label.visible = true
