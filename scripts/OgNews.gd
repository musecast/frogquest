extends CanvasLayer
## "OG Mode Unlocked!": shown at the title the first time after the game's beaten on Hard. What OG mode is
## (the very first Frog Quest's aim line: Difficulty.OG_BLURB), Try OG Mode (it's chosen there and then)
## or Maybe Later (it's in the settings, under Difficulty). Read once (MusicManager.og_seen).

signal closed

var player: Node = null  # (to choose OG on: player.set_difficulty)
var _shade: Button
var _panel: PanelContainer
var _scroll: ScrollContainer


func _ready() -> void:
	name = "OgNews"
	layer = 95  # (over the title and its menus)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var difficulty: GDScript = load("res://scripts/Difficulty.gd")
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.6)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	_shade = Button.new()  # (the room round the card: a tap there is never a jump)
	_shade.flat = true
	_shade.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_shade.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	add_child(_shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	_panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("separation", 8)
	margin.add_child(frame)
	frame.add_child(_label(difficulty.OG_TITLE, 32, ui.GOLD))
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	box.add_child(_label(difficulty.OG_BLURB, 16, Color(0.95, 0.88, 0.65)))
	box.add_child(_label("(it's in the settings, under Difficulty)", 16, Color(0.78, 0.74, 0.68)))
	frame.add_child(_button("Try OG Mode", _try, "go"))
	frame.add_child(_button("Maybe Later", _close, "wood"))
	_shade.pressed.connect(func() -> void:
		if not _panel.get_global_rect().has_point(_shade.get_global_mouse_position()):
			_close())
	_fit()
	get_viewport().size_changed.connect(_fit)


func _try() -> void:
	if player and player.has_method("set_difficulty"):
		player.set_difficulty("og")
	_close()


func _close() -> void:
	MusicManager.og_seen = true
	MusicManager.save_wardrobe()
	closed.emit()
	queue_free()


func _process(_delta: float) -> void:
	_fit()  # (wrapped words settle a frame late)


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	_shade.position = room.position
	_shade.size = room.size
	ui.fit_panel(_panel, _scroll, room, ui.panel_zoom(vp, room), 0.9 if vp.y > vp.x * 1.3 else 0.62)


func _label(text: String, font_size: int, colour: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	load("res://scripts/UIStyle.gd").style_label(lbl, font_size, colour)
	return lbl


func _button(text: String, on_press: Callable, kind: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 28)
	load("res://scripts/UIStyle.gd").style_button(btn, 16, kind)
	btn.pressed.connect(on_press)
	return btn
