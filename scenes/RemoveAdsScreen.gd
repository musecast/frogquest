extends CanvasLayer

signal closed

var _main_panel: VBoxContainer
var _passcode_panel: VBoxContainer
var _code_input: LineEdit
var _status_label: Label
var _resize_timer: SceneTreeTimer = null
var _panel: PanelContainer = null

const BTN_HEIGHT := 38
const BTN_FONT_SZ := 16
const TITLE_FONT_SZ := 22
const GOLD := Color(0.95, 0.88, 0.65)
const BLACK := Color(0.0, 0.0, 0.0, 1.0)


func _ready() -> void:
	layer = 20
	_build_ui()
	_apply_scale()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _build_ui() -> void:
	var fibberish: Font = load("res://assets/fibberish.ttf")

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.13, 0.10, 0.08, 0.97)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.75, 0.65, 0.45, 0.9)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		panel_style.set("corner_radius_" + corner, 8)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(280, 0)
	_panel = panel
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20 if side in ["left", "right"] else 16)
	panel.add_child(margin)

	_main_panel = VBoxContainer.new()
	_main_panel.add_theme_constant_override("separation", 10)
	_main_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_main_panel)

	var frog_btn := TextureButton.new()
	frog_btn.texture_normal = load("res://assets/frog.png")
	frog_btn.ignore_texture_size = true
	frog_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	frog_btn.custom_minimum_size = Vector2(64, 64)
	frog_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frog_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
	frog_btn.pressed.connect(_on_secret_pressed)
	_main_panel.add_child(frog_btn)

	var title := Label.new()
	title.text = "Remove Ads"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fibberish:
		title.add_theme_font_override("font", fibberish)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", BLACK)
	title.add_theme_constant_override("outline_size", 6)
	_main_panel.add_child(title)

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fibberish:
		_status_label.add_theme_font_override("font", fibberish)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.visible = false
	_main_panel.add_child(_status_label)

	if not MusicManager.ads_removed:
		var store_ready := AdsManager.has_purchase_backend()

		var buy_btn := _make_button("$0.99 - Remove Ads Forever", fibberish)
		buy_btn.name = "BuyButton"
		buy_btn.disabled = not store_ready
		buy_btn.pressed.connect(_on_buy_pressed)
		_main_panel.add_child(buy_btn)

		var restore_btn := _make_button("Restore Purchases", fibberish)
		restore_btn.name = "RestoreButton"
		restore_btn.disabled = not store_ready
		restore_btn.pressed.connect(_on_restore_pressed)
		_main_panel.add_child(restore_btn)

		if not store_ready:
			var backend_note := Label.new()
			backend_note.text = "Store purchases are not configured in this build yet.\nRemove Ads product: %s" % AdsManager.get_remove_ads_product_id()
			backend_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			backend_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if fibberish:
				backend_note.add_theme_font_override("font", fibberish)
			backend_note.add_theme_font_size_override("font_size", 12)
			backend_note.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65, 0.85))
			_main_panel.add_child(backend_note)
	else:
		var already := Label.new()
		already.text = "Ads already removed!"
		already.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if fibberish:
			already.add_theme_font_override("font", fibberish)
		already.add_theme_font_size_override("font_size", 14)
		already.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		_main_panel.add_child(already)

	var close_btn := _make_button("Close", fibberish)
	close_btn.pressed.connect(_on_close_pressed)
	_main_panel.add_child(close_btn)

	_passcode_panel = VBoxContainer.new()
	_passcode_panel.add_theme_constant_override("separation", 10)
	_passcode_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_passcode_panel.visible = false
	margin.add_child(_passcode_panel)

	var secret_title := Label.new()
	secret_title.text = "???"
	secret_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if fibberish:
		secret_title.add_theme_font_override("font", fibberish)
	secret_title.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	secret_title.add_theme_color_override("font_color", GOLD)
	secret_title.add_theme_color_override("font_outline_color", BLACK)
	secret_title.add_theme_constant_override("outline_size", 6)
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


func _make_button(label_text: String, fibberish: Font) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.custom_minimum_size = Vector2(0, BTN_HEIGHT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.20, 0.16, 0.12, 1.0)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.75, 0.65, 0.45, 0.9)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		normal.set("corner_radius_" + corner, 5)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.30, 0.24, 0.18, 1.0)
	hover.border_color = Color(0.95, 0.85, 0.55, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.09, 0.07, 1.0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)

	if fibberish:
		btn.add_theme_font_override("font", fibberish)
	btn.add_theme_font_size_override("font_size", BTN_FONT_SZ)
	btn.add_theme_color_override("font_color", GOLD)
	btn.add_theme_color_override("font_hover_color", GOLD)
	btn.add_theme_color_override("font_pressed_color", GOLD)
	btn.add_theme_color_override("font_outline_color", BLACK)
	btn.add_theme_constant_override("outline_size", 6)
	return btn


func _apply_scale() -> void:
	if _panel == null or not is_inside_tree():
		return

	var vp := get_viewport().get_visible_rect().size
	var is_portrait: bool = vp.y > vp.x * 1.3
	if is_portrait:
		_panel.scale = Vector2(1.0, 1.0)
		_panel.custom_minimum_size = Vector2(vp.x * 0.82, 0)
	else:
		_panel.scale = Vector2(1.0, 1.0)
		_panel.custom_minimum_size = Vector2(vp.x * 0.38, 0)
		call_deferred("_fit_landscape_height", vp)


func _fit_landscape_height(vp: Vector2) -> void:
	if _panel == null or not is_inside_tree():
		return
	var panel_h: float = _panel.size.y
	if panel_h <= 0.0:
		return
	var max_h: float = vp.y * 0.88
	if panel_h > max_h:
		var sc: float = max_h / panel_h
		_panel.pivot_offset = _panel.size / 2.0
		_panel.scale = Vector2(sc, sc)


func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	_resize_timer = get_tree().create_timer(0.15)
	await _resize_timer.timeout
	_apply_scale()


func _on_buy_pressed() -> void:
	AdsManager.purchase_remove_ads()


func _on_restore_pressed() -> void:
	AdsManager.restore_purchases()


func _on_close_pressed() -> void:
	emit_signal("closed")


func _on_secret_pressed() -> void:
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
	for btn_name in ["BuyButton", "RestoreButton"]:
		var button := _main_panel.get_node_or_null(btn_name)
		if button:
			button.queue_free()
	_status_label.text = msg
	_status_label.visible = true
