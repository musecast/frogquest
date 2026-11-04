extends CanvasLayer

signal closed
signal cosmetic_changed

# Item definitions — add new cosmetics here. "icon" (and "tint"/"strength" or "shader") is the picture in
# its row and in the notification when it's unlocked: the hat itself, or the frog wearing the skin.
const ITEMS: Dictionary = {
	"froggycrown":    {"label": "Froggy Crown",  "type": "hat", "icon": "res://assets/froggycrown.png",
					  "how": "Beat Frog Quest"},
	"blackcrown":     {"label": "Black Crown",   "type": "hat", "icon": "res://assets/froggycrown.png",
					  "tint": Color(0.0, 0.0, 0.0), "strength": 1.0,
					  "how": "Score 100 in Endless"},
	"wizhat":         {"label": "Wiz Hat",       "type": "hat", "icon": "res://assets/froggywizhat.png",
					  "how": "Find the wizard frog in the World Tree"},
	"cakehat":        {"label": "Cake Hat",      "type": "hat", "icon": "res://assets/froggycakehat.png",
					  "how": "Find the cake in the World Tree"},
	"golden_skin":    {"label": "Golden Frog",   "type": "skin", "icon": "res://assets/frog.png",
					  "tint": Color(1.0, 0.75, 0.0), "strength": 0.55,
					  "how": "Catch every fly hiding in the World Tree"},
	"grayscale_skin": {"label": "Grayscale",     "type": "skin", "icon": "res://assets/frog.png",
					  "shader": "res://assets/grayscale.gdshader",
					  "how": "Score 25 in Endless"},
	"negative_skin":  {"label": "Negative",      "type": "skin", "icon": "res://assets/frog.png",
					  "shader": "res://assets/negative.gdshader",
					  "how": "Score 50 in Endless"},
	# (the hats drawn in code, FroggyLook.HATS: every one found by playing)
	"leaf":           {"label": "Leaf",          "type": "hat", "pixel": true, "how": "Climb 50 m up the World Tree"},
	"bow":            {"label": "Bow",           "type": "hat", "pixel": true, "how": "Climb 150 m up the World Tree"},
	"flower":         {"label": "Flower",        "type": "hat", "pixel": true, "how": "Climb 300 m up the World Tree"},
	"cap":            {"label": "Cap",           "type": "hat", "pixel": true, "how": "Bounce off a mushroom in the World Tree"},
	"beanie":         {"label": "Beanie",        "type": "hat", "pixel": true, "how": "Score 10 in Endless"},
	"tophat":         {"label": "Top Hat",       "type": "hat", "pixel": true, "how": "Score 150 in Endless"},
	"partyhat":       {"label": "Party Hat",     "type": "hat", "pixel": true, "how": "Climb with a friend (Play Together)"},
	"halo":           {"label": "Halo",          "type": "hat", "pixel": true, "how": "Beat Frog Quest in under an hour"},
	"lilypad":        {"label": "Lily Pad",      "type": "hat", "pixel": true, "how": "Catch 5 of the flies hiding in the World Tree"},
	"mushroom":       {"label": "Mushroom",      "type": "hat", "pixel": true, "how": "Bounce off 25 mushrooms in the World Tree"},
	# (the skins: effects over your froggy, FroggyLook.EFFECTS)
	"shiny":          {"label": "Shiny",         "type": "skin", "how": "Score 75 in Endless"},
	"rainbow":        {"label": "Rainbow",       "type": "skin", "how": "Score 200 in Endless"},
	"glow":           {"label": "Glow",          "type": "skin", "how": "Get pulled up by a friend's band"},
	"ghost":          {"label": "Ghost",         "type": "skin", "how": "Take a really big fall in the World Tree"},
	"starry":         {"label": "Starry",        "type": "skin", "how": "Climb all the way to space in Endless"},
	"holo":           {"label": "Holo",          "type": "skin", "how": "Climb with 3 friends at once"},
	"shadow":         {"label": "God's Shadow", "type": "skin", "how": "Beat Frog Quest"},
	# (patterns over your froggy, in his colours: found by playing; one at a time. Their colour's chosen
	# in CHANGE YOUR LOOK)
	"pattern_freckles": {"label": "Freckles",    "type": "pattern", "pattern": 3, "how": "Climb out of your bedroom"},
	"pattern_spots":    {"label": "Spots",       "type": "pattern", "pattern": 1, "how": "Climb 100 m up the World Tree"},
	"pattern_stripes":  {"label": "Stripes",     "type": "pattern", "pattern": 2, "how": "Climb 200 m up the World Tree"},
	"pattern_twotone":  {"label": "Two-Tone",    "type": "pattern", "pattern": 4, "how": "Climb 400 m up the World Tree"},
	"pattern_hearts":   {"label": "Hearts",      "type": "pattern", "pattern": 5, "how": "Climb 500 m up the World Tree"},
	"pattern_stars":    {"label": "Stars",       "type": "pattern", "pattern": 6, "how": "Climb 100 m in Endless"},
	"lil_froggy":     {"label": "Lil Froggy",    "type": "desktop", "icon": "res://assets/frog.png",
					  "how": "He lives on your desktop. Right-click him or his tray icon for more."},
}

var _item_buttons: Dictionary = {}  # item_id -> Button
var _item_rows: Dictionary = {}  # item_id -> its row (lit up while worn)
var _hint_label: Label = null
var _hint_box: PanelContainer = null
var _resize_timer: SceneTreeTimer = null
var _froggy_link = null  # DesktopFrogLink.gd, loaded on first use
var _froggy_busy_until := 0  # msec; LET OUT / CALL IN waits while froggy starts up or heads home
var _froggy_refresh_in := 0.0
var _built_for := []  # [screen size, room] the panel was last built for

func _compute_action_button_size(base_size: Vector2, font_size: int) -> Vector2:
	var button_font := load("res://assets/fibberish.ttf") as Font
	if button_font == null:
		return base_size

	var text_width: float = 0.0
	for label in ["UNEQUIP", "LET OUT", "CALL IN"]:
		text_width = max(text_width, button_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	# Account for the button style's horizontal padding and a little extra
	# headroom so the longest label never clips on scaled layouts.
	var padded_width: float = ceil(text_width + 28.0)
	return Vector2(max(base_size.x, padded_width), base_size.y)

func _ready() -> void:
	layer = 10
	_mark_all_seen()
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	add_to_group("banner_reserve_ui")  # (AdsManager calls _apply_ui_layout when a banner comes or goes)


func _apply_ui_layout() -> void:
	_on_viewport_resized()

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
	var vp := get_viewport().get_visible_rect().size
	if [vp, load("res://scripts/UIStyle.gd").room(vp)] == _built_for:
		return  # (a banner came again, same room: built afresh, the list lost its place)
	for child in get_children():
		child.queue_free()
	_item_buttons.clear()
	_item_rows.clear()
	_hint_label = null
	_hint_box = null
	_build_ui()


func _build_ui() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var vp := get_viewport().get_visible_rect().size
	var room: Rect2 = ui.room(vp)  # clear of the notch and the ad banners, which draw over everything
	var is_portrait: bool = vp.y > vp.x * 1.3

	# Darkened backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# (the pixel font is drawn on a 16-pixel grid, so whole steps of it only: UIStyle.px. Upright, the
	# step that suits the width: 32 on the story's 480, 16 on Endless's 320, where 32 left room for two.)
	var font_size_title: int = ui.px(vp.x / 10.0) if is_portrait else 16
	var font_size_body:  int = ui.px(vp.x / 15.0) if is_portrait else 16
	# Buttons and pictures scale with the room so they fit any phone.
	# (whole pixels, so their words land dead in the middle)
	var btn_min := Vector2(room.size.x * 0.27, maxf(room.size.y * 0.05, font_size_body * 1.9)).round() if is_portrait else Vector2(70, 20)
	var action_btn_min := _compute_action_button_size(btn_min, font_size_body)
	var info_btn_size: float = btn_min.y
	var icon_size: float = roundf(btn_min.y * 1.1)
	var pad: float = 14.0 if is_portrait else 7.0

	# Panel: a share of the room, capped, in the middle of the screen (UIStyle.across).
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	var margin: float = room.size.x * (0.05 if is_portrait else 0.017)
	var across: Vector2 = ui.across(vp, room, minf(room.size.x - margin * 2.0, 440.0))
	var pw: float = floorf(across.y)
	var ph: float = room.size.y * (0.88 if is_portrait else 0.92)
	panel.position = Vector2(across.x, room.position.y + (room.size.y - ph) * 0.5).floor()
	panel.size = Vector2(pw, ph)
	_built_for = [vp, room]
	add_child(panel)

	# Outer VBox: title | scroll-area | hint | close  (title & close never scroll off)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 8 if is_portrait else 4)
	outer.offset_left   =  pad
	outer.offset_right  = -pad
	outer.offset_top    =  pad
	outer.offset_bottom = -pad
	panel.add_child(outer)

	# Title, with the crown
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	var crown := item_icon("froggycrown", 0.0)
	crown.custom_minimum_size = Vector2.ONE * ui.pixel_size(crown.texture, font_size_title * 1.2)
	title_row.add_child(crown)
	var title := Label.new()
	title.text = "WARDROBE"
	ui.style_label(title, font_size_title, ui.GOLD)
	title_row.add_child(title)
	outer.add_child(title_row)
	var look_btn := Button.new()  # (back to the frog god, to choose again: CreatorIntro)
	look_btn.name = "ChangeLookButton"
	look_btn.text = "CHANGE YOUR LOOK"
	look_btn.focus_mode = Control.FOCUS_NONE
	look_btn.custom_minimum_size = Vector2(0, btn_min.y)
	ui.style_button(look_btn, font_size_body, "wood")
	look_btn.pressed.connect(_change_look)
	outer.add_child(look_btn)

	# ScrollContainer holds all the items and expands to fill available space
	# (what a row gets across: the panel less its padding, the scroll bar and a row's own lit box)
	var row_width: float = pw - pad * 2.0 - 18.0
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	ui.style_scrollbar(scroll.get_v_scroll_bar())
	outer.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8 if is_portrait else 3)
	scroll.add_child(vbox)

	# Every row laid out the same way: if any name doesn't fit beside its buttons, they all go over them
	# (one short name beside its buttons, among the rest over theirs, looked like a mistake).
	var stack_rows := false
	for id in ITEMS:
		if _is_unlocked(id) and not _fits_beside(id, action_btn_min, font_size_body, info_btn_size, icon_size, row_width):
			stack_rows = true

	for section in [["HATS", "hat"], ["PATTERNS", "pattern"], ["SKINS", "skin"], ["DESKTOP", "desktop"]]:
		var ids := []
		for id in ITEMS:
			if ITEMS[id]["type"] == section[1] and _is_unlocked(id):
				ids.append(id)
		if ids.is_empty() and section[1] == "desktop":
			continue  # (computers only, once he's unlocked)
		vbox.add_child(_section_header(section[0], font_size_body))
		for id in ids:
			vbox.add_child(_make_item_row(id, action_btn_min, font_size_body, info_btn_size, icon_size, row_width, stack_rows))
		if ids.is_empty():
			var none_lbl := Label.new()
			none_lbl.text = "(none yet)"
			none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ui.style_label(none_lbl, font_size_body, ui.CREAM.darkened(0.3))
			vbox.add_child(none_lbl)
	var locked := []
	for id in ITEMS:
		if ITEMS[id]["type"] != "desktop" and not _is_unlocked(id):
			locked.append(id)
	if not locked.is_empty():
		vbox.add_child(_section_header("STILL TO FIND", font_size_body))
		for id in locked:
			vbox.add_child(_locked_row(id, font_size_body, icon_size))
	ui.finger_scroll(scroll)  # (the rows and their buttons kept every touch: only the bar scrolled it)

	# ── HINT (shown when an info button is pressed) ──────────────────────
	_hint_box = PanelContainer.new()
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	hint_style.set_corner_radius_all(6)
	hint_style.set_content_margin_all(6.0)
	_hint_box.add_theme_stylebox_override("panel", hint_style)
	_hint_box.visible = false
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.style_label(_hint_label, font_size_body, ui.GOLD)
	_hint_box.add_child(_hint_label)
	outer.add_child(_hint_box)

	outer.add_child(ui.rule())

	# Close button — always visible at the bottom of the panel
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = btn_min
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.clip_text = true
	ui.style_button(close_btn, font_size_body, "wood")
	close_btn.pressed.connect(_play_sfx.bind("res://assets/frogjump.wav"))
	close_btn.pressed.connect(_on_close_pressed)
	outer.add_child(close_btn)

	# Only as tall as it needs (up to the room's share above), the list scrolling past that.
	var fit_h: float = minf(ph, outer.get_combined_minimum_size().y + vbox.get_combined_minimum_size().y + pad * 2.0 + 6.0)
	panel.size.y = fit_h
	panel.position.y = floorf(room.position.y + (room.size.y - fit_h) * 0.5)


## A section's name between two gold lines.
func _section_header(text: String, font_size: int) -> HBoxContainer:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in 3:
		if i == 1:
			var lbl := Label.new()
			lbl.text = text
			ui.style_label(lbl, font_size, ui.GOLD)
			row.add_child(lbl)
		else:
			var line: HSeparator = ui.rule()
			line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(line)
	return row


## Whether an item's name fits on its row beside its buttons (else it goes on a line of its own).
func _fits_beside(id: String, btn_min: Vector2, font_size: int, info_btn_size: float, icon_size: float,
		row_width: float) -> bool:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var name_w: float = ui.font().get_string_size(ITEMS[id]["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size * 0.6
	var buttons_w: float = btn_min.x + (info_btn_size + 8.0 if ITEMS[id].get("how", "") != "" else 0.0)
	return icon_size + 8.0 + name_w + 8.0 + buttons_w <= row_width


## An item: its picture, its name, its button and a "?" for how it's won. On a narrow screen the names
## don't fit beside the buttons (they came out "Frog", or not at all), so with stacked each goes on a
## line of its own over them, beside the picture.
func _make_item_row(id: String, btn_min: Vector2, font_size: int, info_btn_size: float, icon_size: float,
		row_width: float, stacked: bool) -> PanelContainer:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var box := PanelContainer.new()  # (lit up while you're wearing it)
	_item_rows[id] = box
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	row.add_child(ui.slot(item_icon(id, 0.0), icon_size))

	var lbl := Label.new()
	lbl.text = ITEMS[id]["label"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.style_label(lbl, font_size)
	var how: String = ITEMS[id].get("how", "")
	var buttons_w: float = btn_min.x + (info_btn_size + 8.0 if how != "" else 0.0)
	var button_row: HBoxContainer = row
	if stacked:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		row.add_child(column)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # (and if it's too long even there, two lines)
		column.add_child(lbl)
		button_row = HBoxContainer.new()
		button_row.add_theme_constant_override("separation", 8)
		column.add_child(button_row)
	else:
		lbl.clip_text = true
		row.add_child(lbl)

	var btn := Button.new()
	# Use a fixed width sized for "UNEQUIP" (the longer label) so the panel
	# width never changes when toggling between EQUIP / UNEQUIP.
	btn.custom_minimum_size = btn_min
	if stacked:
		btn.custom_minimum_size.x = minf(btn_min.x, row_width - icon_size - 8.0 - (buttons_w - btn_min.x))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL if stacked else Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.clip_text = false
	btn.add_theme_font_size_override("font_size", font_size)
	btn.pressed.connect(_on_item_button_pressed.bind(id, btn))
	btn.pressed.connect(_play_sfx.bind("res://assets/frogaim.wav"))
	_item_buttons[id] = btn
	button_row.add_child(btn)
	_update_button_label(btn, id)

	# Info button — shows how to unlock
	if how != "":
		var info_btn := Button.new()
		info_btn.text = "?"
		info_btn.custom_minimum_size = Vector2(info_btn_size, info_btn_size)
		info_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ui.style_button(info_btn, font_size, "quiet")
		info_btn.pressed.connect(_on_info_pressed.bind(id))
		info_btn.pressed.connect(_play_sfx.bind("res://assets/frogaim.wav"))
		button_row.add_child(info_btn)

	return box


## The item's picture: the hat itself, or the frog wearing the skin (size 0: no minimum size).
static func item_icon(id: String, size: float) -> TextureRect:
	var def: Dictionary = ITEMS.get(id, {})
	var icon := TextureRect.new()
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	if def.get("pixel", false):
		icon.texture = look.hat_texture(id)  # (drawn in code, on his grid)
	else:
		icon.texture = _trimmed(load(def.get("icon", "res://assets/frog.png")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if def.get("type") == "skin":
		icon.material = look.material(MusicManager.look, id)  # (your froggy, wearing it)
	elif def.get("type") == "pattern":
		var with_it: Dictionary = look.clean(MusicManager.look)  # (your froggy, in it)
		with_it.pattern = int(def["pattern"])
		icon.material = look.material(with_it)
	elif def.has("shader"):
		var mat := ShaderMaterial.new()
		mat.shader = load(def["shader"])
		icon.material = mat
	elif def.has("tint"):
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/skin_tint.gdshader")
		mat.set_shader_parameter("tint_color", def["tint"])
		mat.set_shader_parameter("tint_strength", def.get("strength", 1.0))
		icon.material = mat
	return icon


## The picture cut down to the art in it: hats are drawn with room around them for wearing (the wiz
## hat sits in the top of a 46 px square), which left their icons small and off-centre in a slot.
static func _trimmed(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if used.size == Vector2i(texture.get_size()) or used.size.x <= 0:
		return texture
	var cut := AtlasTexture.new()
	cut.atlas = texture
	cut.region = Rect2(used)
	return cut


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
	var flies: GDScript = load("res://scripts/FlyHunt.gd")
	if id == flies.REWARD:
		how += " (%d/%d)" % [flies.count_caught(), flies.total()]
	var label_text: String = ITEMS[id]["label"]
	var new_text := how
	# Toggle off if already showing the same hint
	if _hint_box.visible and _hint_label.text == new_text:
		_hint_box.visible = false
	else:
		_hint_label.text = new_text
		_hint_box.visible = true


## Something still to find: its picture in shadow, its name, and how to find it.
func _locked_row(id: String, font_size: int, icon_size: float) -> Control:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := item_icon(id, icon_size)
	icon.modulate = Color(0.0, 0.0, 0.0, 0.55)
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.text = ITEMS[id]["label"]
	ui.style_label(name_label, font_size, ui.CREAM.darkened(0.25))
	words.add_child(name_label)
	var how := Label.new()
	how.text = ITEMS[id].get("how", "")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.style_label(how, 16, ui.CREAM.darkened(0.45))
	words.add_child(how)
	row.add_child(words)
	return row


## Back to the frog god, to choose your look again (CreatorIntro, just the choosing); then this again,
## with it.
func _change_look() -> void:
	var intro: CanvasLayer = load("res://scenes/CreatorIntro.gd").new()
	intro.from_wardrobe = true
	get_tree().root.add_child(intro)
	intro.done.connect(func() -> void:
		cosmetic_changed.emit()
		_rebuild())


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		child.queue_free()
	_item_buttons.clear()
	_item_rows.clear()
	_hint_label = null
	_hint_box = null
	_build_ui()


func _is_unlocked(id: String) -> bool:
	if id == "froggycrown":
		return MusicManager.froggyCrown != 0
	if id == "lil_froggy":
		var link = _desktop_frog_link()
		return link.is_supported() and link.is_unlocked()
	return id in MusicManager.unlocked_skins


func _desktop_frog_link():
	if _froggy_link == null:
		_froggy_link = load("res://scripts/DesktopFrogLink.gd")
	return _froggy_link


func _is_equipped(id: String) -> bool:
	var def = ITEMS[id]
	if def["type"] == "hat":
		return MusicManager.equipped_hat == id
	if def["type"] == "pattern":
		return int(load("res://scripts/FroggyLook.gd").clean(MusicManager.look).pattern) == int(def["pattern"])
	return MusicManager.equipped_skin == id


func _update_button_label(btn: Button, id: String) -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var font_size: int = btn.get_theme_font_size("font_size") if btn.has_theme_font_size_override("font_size") else 0
	if font_size == 0:
		var vp := get_viewport().get_visible_rect().size
		font_size = ui.px(vp.x / 15.0) if vp.y > vp.x * 1.3 else 16  # (as _build_ui sizes them)
	if id == "lil_froggy":
		var waiting := Time.get_ticks_msec() < _froggy_busy_until
		btn.disabled = waiting
		var out: bool = _desktop_frog_link().is_out()
		btn.text = "..." if waiting else ("CALL IN" if out else "LET OUT")
		ui.style_button(btn, font_size, "go" if out else "wood")
		return
	var worn := _is_equipped(id)
	btn.text = "UNEQUIP" if worn else "EQUIP"
	ui.style_button(btn, font_size, "go" if worn else "wood")
	var row: PanelContainer = _item_rows.get(id)
	if row:
		var lit := StyleBoxFlat.new()
		lit.bg_color = Color(1.0, 0.86, 0.42, 0.13) if worn else Color(0, 0, 0, 0)
		lit.set_corner_radius_all(6)
		lit.set_content_margin_all(4.0)
		row.add_theme_stylebox_override("panel", lit)


func _process(delta: float) -> void:
	# Froggy comes and goes on his own (tray menu, startup), so keep his button honest.
	var btn: Button = _item_buttons.get("lil_froggy")
	if btn == null:
		return
	_froggy_refresh_in -= delta
	if _froggy_refresh_in <= 0.0:
		_froggy_refresh_in = 0.5
		_update_button_label(btn, "lil_froggy")


func _on_item_button_pressed(id: String, btn: Button) -> void:
	if id == "lil_froggy":
		var link = _desktop_frog_link()
		if link.is_out():
			link.send_command("home", link.game_window_rect())  # he hops back into this window
		else:
			link.let_out(link.game_window_rect())  # he hops out of this window
		_froggy_busy_until = Time.get_ticks_msec() + 3000
		_update_button_label(btn, id)
		return
	var def = ITEMS[id]
	if def["type"] == "hat":
		MusicManager.equipped_hat = "" if _is_equipped(id) else id
	elif def["type"] == "pattern":
		var l: Dictionary = load("res://scripts/FroggyLook.gd").clean(MusicManager.look)
		l.pattern = 0 if _is_equipped(id) else int(def["pattern"])
		MusicManager.look = l
	else:
		MusicManager.equipped_skin = "" if _is_equipped(id) else id
	MusicManager.save_wardrobe()
	# Refresh all item buttons
	for item_id in _item_buttons:
		_update_button_label(_item_buttons[item_id], item_id)
	cosmetic_changed.emit()


func _on_close_pressed() -> void:
	closed.emit()
