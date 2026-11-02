extends CanvasLayer
## The privacy policy or the terms of use (bundled plain text, res://legal/), over everything. It stays
## in the room clear of the ad banners and the notch: a banner drawn over its Close button left no way
## out. The words scroll with a finger (they used to get selected instead), and Close or a tap outside
## the panel puts it away. Dressed like the other menus (UIStyle); the long text itself is in the
## plain font, easier to read than the pixel one.

enum Doc { PRIVACY, TERMS }

const PATH_PRIVACY := "res://legal/privacy_policy.txt"
const PATH_TERMS := "res://legal/terms_of_use.txt"

var doc := Doc.PRIVACY
var _panel: PanelContainer
var _title: Label
var _body: Label
var _close: Button
var _laid_out_for := Vector2.ZERO


static func present(tree: SceneTree, which: Doc) -> void:
	if tree == null or tree.root == null:
		return
	var popup := new()
	popup.doc = which
	tree.root.add_child(popup)


func _ready() -> void:
	layer = 125  # (over every other menu)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_fit()


func _build() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.76)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui.panel_box(10))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)  # (placed by _fit)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left", "right"] else 10)
	_panel.add_child(margin)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 8)
	margin.add_child(frame)

	_title = Label.new()
	_title.text = "Privacy Policy" if doc == Doc.PRIVACY else "Terms of Use"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(_title)

	var scroll := ScrollContainer.new()  # (a finger drags it; the words don't get selected)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.style_scrollbar(scroll.get_v_scroll_bar())
	frame.add_child(scroll)
	_body = Label.new()
	_body.text = _read(PATH_PRIVACY if doc == Doc.PRIVACY else PATH_TERMS)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override("font_color", ui.CREAM)
	scroll.add_child(_body)

	_close = Button.new()
	_close.text = "Close"
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(queue_free)
	frame.add_child(_close)


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "(This document could not be loaded from the app data.)"
	var text := f.get_as_text()
	f.close()
	return text


## Most of the room there is (UIStyle.room: clear of the notch and the ad banners, which are drawn over
## everything), centred in it. Every frame: banners come and go, and the phone turns.
func _process(_delta: float) -> void:
	_fit()


func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0 or vp.y < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var portrait := vp.y > vp.x * 1.3
	if vp != _laid_out_for:
		_laid_out_for = vp
		var size: int = ui.px(vp.x / 15.0) if portrait else 16
		ui.style_label(_title, size, ui.GOLD)
		ui.style_button(_close, size, "wood")
		_close.custom_minimum_size = Vector2(0, size * 1.75)
		_body.add_theme_font_size_override("font_size", 16 if vp.y >= 300.0 else 12)
	var w := minf(room.size.x * (0.94 if portrait else 0.8), 640.0)
	var h := room.size.y * 0.94
	_panel.size = Vector2(w, h)
	_panel.position = (room.position + (room.size - _panel.size) / 2.0).round()


func _on_backdrop_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventScreenTouch
	if tap and event.pressed:
		queue_free()
