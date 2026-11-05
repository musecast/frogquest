extends CanvasLayer
## Endless paused: Resume, Try Again, Main Menu, over the climb (stopped where it is). In a party, the others
## keep climbing; your frog waits for you. Opened by the pause button and when the game goes to the
## background (EndlessMode.pause). Built in code and dressed like the other menus.

signal resumed
signal try_again
signal main_menu

const BTN_HEIGHT := 28
const BTN_FONT_SZ := 16  # (the pixel font is drawn on a 16-pixel grid)
const DIM := Color(0.78, 0.74, 0.68)

var _panel: PanelContainer
var _scroll: ScrollContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # (the climb's paused; this isn't)
	layer = 70
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	_panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 10)
	margin.add_child(frame)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.style_label(title, 32, ui.GOLD)
	frame.add_child(title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(box)
	box.add_child(_button("Resume", func() -> void: resumed.emit(), "go"))
	if Party.race == "" or not Party.in_run:  # (in a race it'd start you over, out of step with everyone)
		box.add_child(_button("Try Again", func() -> void: try_again.emit(), "wood"))
	box.add_child(_button("Main Menu", func() -> void: main_menu.emit(), "quiet"))
	if Party.in_run and Party.players.size() > 1:
		var note := Label.new()
		note.text = "The race goes on without you!" if Party.race != "" else "Your friends keep climbing; your frog waits for you."
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui.style_label(note, 16, DIM)
		box.add_child(note)
	_fit()


func _process(_delta: float) -> void:
	_fit()


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0 or vp.y < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	ui.fit_panel(_panel, _scroll, room, ui.panel_zoom(vp, room), 0.8 if portrait else 0.5)


func _button(text: String, on_press: Callable, kind: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_FILL
	btn.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	load("res://scripts/UIStyle.gd").style_button(btn, BTN_FONT_SZ, kind)
	btn.pressed.connect(on_press)
	return btn
