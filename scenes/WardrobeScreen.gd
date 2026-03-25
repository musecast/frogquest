extends CanvasLayer

signal closed
signal cosmetic_changed

# Item definitions — add new cosmetics here
const ITEMS: Dictionary = {
	"froggycrown":    {"label": "Froggy Crown",  "type": "hat",
					  "how": "Beat Frog Quest"},
	"blackcrown":     {"label": "Black Crown",   "type": "hat",
					  "how": "Score 100 in Endless"},
	"wizhat":         {"label": "Wiz Hat",       "type": "hat",
					  "how": "Find it in the world"},
	"cakehat":        {"label": "Cake Hat",      "type": "hat",
					  "how": "Find it in the world"},
	"golden_skin":    {"label": "Golden Frog",   "type": "skin",
					  "tint": Color(1.0, 0.75, 0.0), "strength": 1.0,
					  "how": "Secret"},
	"grayscale_skin": {"label": "Grayscale",     "type": "skin",
					  "shader": "res://assets/grayscale.gdshader",
					  "how": "Score 25 in Endless"},
	"negative_skin":  {"label": "Negative",      "type": "skin",
					  "shader": "res://assets/negative.gdshader",
					  "how": "Score 50 in Endless"},
}

var _item_buttons: Dictionary = {}  # item_id -> Button
var _hint_label: Label = null
var _resize_timer: SceneTreeTimer = null

func _ready() -> void:
	layer = 10
	_mark_all_seen()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _mark_all_seen() -> void:
	var changed := false
	if MusicManager.froggyCrown != 0 and "froggycrown" not in MusicManager.seen_cosmetics:
		MusicManager.seen_cosmetics.append("froggycrown")
		changed = true
	for skin in MusicManager.unlocked_skins:
		if skin not in MusicManager.seen_cosmetics:
			MusicManager.seen_cosmetics.append(skin)
			changed = true
	if changed:
		MusicManager.save_wardrobe()

func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	_resize_timer = get_tree().create_timer(0.05)
	await _resize_timer.timeout
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_item_buttons.clear()
	_hint_label = null
	_build_ui()


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var is_portrait: bool = vp.y > vp.x * 1.3

	# Darkened backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var font_size_title: int = 28 if is_portrait else 13
	var font_size_body:  int = 22 if is_portrait else 11
	# Scale button and info sizes proportionally to viewport width so they
	# never exceed available space on any phone resolution / pixel density.
	var btn_min := Vector2(vp.x * 0.23, vp.y * 0.037) if is_portrait else Vector2(70, 18)
	var info_btn_size: float = vp.x * 0.058 if is_portrait else 18.0
	var pad: float = 10.0 if is_portrait else 5.0

	# Panel: uses a percentage-based width with a hard cap, ensuring it never
	# reaches the screen edge on any device.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.14, 0.11, 0.96)
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.55, 0.47, 0.35, 0.8)
	panel_style.corner_radius_top_left     = 8
	panel_style.corner_radius_top_right    = 8
	panel_style.corner_radius_bottom_left  = 8
	panel_style.corner_radius_bottom_right = 8

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var margin: float = vp.x * (0.06 if is_portrait else 0.017)
	var pw: float = min(vp.x - margin * 2.0, 420.0)
	var ph: float = vp.y * (0.82 if is_portrait else 0.88)
	panel.position = Vector2(floor((vp.x - pw) * 0.5), floor((vp.y - ph) * 0.5))
	panel.size = Vector2(pw, ph)
	add_child(panel)

	# Outer VBox: title | scroll-area | hint | close  (title & close never scroll off)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 6 if is_portrait else 3)
	outer.offset_left   =  pad
	outer.offset_right  = -pad
	outer.offset_top    =  pad
	outer.offset_bottom = -pad
	panel.add_child(outer)

	# Title
	var title := Label.new()
	title.text = "WARDROBE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size_title)
	outer.add_child(title)

	var sep := HSeparator.new()
	outer.add_child(sep)

	# ScrollContainer holds all the items and expands to fill available space
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8 if is_portrait else 3)
	scroll.add_child(vbox)

	# ── HATS ────────────────────────────────────────────────────────────
	var hats_label := Label.new()
	hats_label.text = "— HATS —"
	hats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hats_label.add_theme_font_size_override("font_size", font_size_body)
	vbox.add_child(hats_label)

	var any_hat := false
	for id in ITEMS:
		if ITEMS[id]["type"] != "hat":
			continue
		if not _is_unlocked(id):
			continue
		any_hat = true
		vbox.add_child(_make_item_row(id, btn_min, font_size_body, info_btn_size))

	if not any_hat:
		var none_lbl := Label.new()
		none_lbl.text = "(none yet)"
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.add_theme_font_size_override("font_size", font_size_body)
		vbox.add_child(none_lbl)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# ── SKINS ───────────────────────────────────────────────────────────
	var skins_label := Label.new()
	skins_label.text = "— SKINS —"
	skins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skins_label.add_theme_font_size_override("font_size", font_size_body)
	vbox.add_child(skins_label)

	var any_skin := false
	for id in ITEMS:
		if ITEMS[id]["type"] != "skin":
			continue
		if not _is_unlocked(id):
			continue
		any_skin = true
		vbox.add_child(_make_item_row(id, btn_min, font_size_body, info_btn_size))

	if not any_skin:
		var none_lbl2 := Label.new()
		none_lbl2.text = "(none yet)"
		none_lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl2.add_theme_font_size_override("font_size", font_size_body)
		vbox.add_child(none_lbl2)

	# ── HINT LABEL (shown when info button pressed) ──────────────────────
	_hint_label = Label.new()
	_hint_label.visible = false
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", font_size_body)
	_hint_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	outer.add_child(_hint_label)

	var sep3 := HSeparator.new()
	outer.add_child(sep3)

	# Close button — always visible at the bottom of the panel
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = btn_min
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.clip_text = true
	close_btn.add_theme_font_size_override("font_size", font_size_body)
	close_btn.pressed.connect(_play_sfx.bind("res://assets/frogjump.wav"))
	close_btn.pressed.connect(_on_close_pressed)
	_style_button(close_btn, false)
	outer.add_child(close_btn)


func _style_button(btn: Button, accent: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.55, 0.47, 0.38, 0.85) if not accent else Color(0.35, 0.55, 0.42, 0.9)
	normal.border_width_left   = 2
	normal.border_width_right  = 2
	normal.border_width_top    = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.0, 0.0, 0.0, 0.6)
	normal.corner_radius_top_left     = 4
	normal.corner_radius_top_right    = 4
	normal.corner_radius_bottom_left  = 4
	normal.corner_radius_bottom_right = 4
	normal.content_margin_left   = 6
	normal.content_margin_right  = 6
	normal.content_margin_top    = 2
	normal.content_margin_bottom = 2

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.72, 0.63, 0.52, 0.9) if not accent else Color(0.45, 0.72, 0.55, 0.95)
	hover.border_width_left   = 2
	hover.border_width_right  = 2
	hover.border_width_top    = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(0.0, 0.0, 0.0, 0.5)
	hover.corner_radius_top_left     = 4
	hover.corner_radius_top_right    = 4
	hover.corner_radius_bottom_left  = 4
	hover.corner_radius_bottom_right = 4
	hover.content_margin_left   = 6
	hover.content_margin_right  = 6
	hover.content_margin_top    = 2
	hover.content_margin_bottom = 2

	var pressed_sb := StyleBoxFlat.new()
	pressed_sb.bg_color = Color(0.32, 0.27, 0.22, 0.9)
	pressed_sb.border_width_left   = 2
	pressed_sb.border_width_right  = 2
	pressed_sb.border_width_top    = 2
	pressed_sb.border_width_bottom = 2
	pressed_sb.border_color = Color(0.0, 0.0, 0.0, 0.7)
	pressed_sb.corner_radius_top_left     = 4
	pressed_sb.corner_radius_top_right    = 4
	pressed_sb.corner_radius_bottom_left  = 4
	pressed_sb.corner_radius_bottom_right = 4

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	btn.add_theme_constant_override("outline_size", 2)


func _make_item_row(id: String, btn_min: Vector2, font_size: int, info_btn_size: float = 30.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = ITEMS[id]["label"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.80))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(lbl)

	var btn := Button.new()
	# Use a fixed width sized for "UNEQUIP" (the longer label) so the panel
	# width never changes when toggling between EQUIP / UNEQUIP.
	btn.custom_minimum_size = btn_min
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.clip_text = true
	btn.add_theme_font_size_override("font_size", font_size)
	_update_button_label(btn, id)
	btn.pressed.connect(_on_item_button_pressed.bind(id, btn))
	btn.pressed.connect(_play_sfx.bind("res://assets/frogaim.wav"))
	_item_buttons[id] = btn
	_style_button(btn, false)
	row.add_child(btn)

	# Info button — shows how to unlock
	var how: String = ITEMS[id].get("how", "")
	if how != "":
		var info_btn := Button.new()
		info_btn.text = "?"
		info_btn.add_theme_font_size_override("font_size", max(font_size - 4, 8))
		info_btn.custom_minimum_size = Vector2(info_btn_size, info_btn_size)
		info_btn.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.45))
		info_btn.add_theme_color_override("font_hover_color", Color(0.95, 0.90, 0.80, 0.85))
		info_btn.pressed.connect(_on_info_pressed.bind(id))
		info_btn.pressed.connect(_play_sfx.bind("res://assets/frogaim.wav"))
		_style_button(info_btn, false)
		row.add_child(info_btn)

	return row


func _play_sfx(path: String) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load(path)
	sfx.volume_db = -8.0
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _on_info_pressed(id: String) -> void:
	if not _hint_label:
		return
	var how: String = ITEMS[id].get("how", "")
	var label_text: String = ITEMS[id]["label"]
	var new_text := how
	# Toggle off if already showing the same hint
	if _hint_label.visible and _hint_label.text == new_text:
		_hint_label.visible = false
	else:
		_hint_label.text = new_text
		_hint_label.visible = true


func _is_unlocked(id: String) -> bool:
	if id == "froggycrown":
		return MusicManager.froggyCrown != 0
	return id in MusicManager.unlocked_skins


func _is_equipped(id: String) -> bool:
	var def = ITEMS[id]
	if def["type"] == "hat":
		return MusicManager.equipped_hat == id
	return MusicManager.equipped_skin == id


func _update_button_label(btn: Button, id: String) -> void:
	btn.text = "UNEQUIP" if _is_equipped(id) else "EQUIP"


func _on_item_button_pressed(id: String, btn: Button) -> void:
	var def = ITEMS[id]
	if def["type"] == "hat":
		MusicManager.equipped_hat = "" if _is_equipped(id) else id
	else:
		MusicManager.equipped_skin = "" if _is_equipped(id) else id
	MusicManager.save_wardrobe()
	# Refresh all item buttons
	for item_id in _item_buttons:
		_update_button_label(_item_buttons[item_id], item_id)
	cosmetic_changed.emit()


func _on_close_pressed() -> void:
	closed.emit()
