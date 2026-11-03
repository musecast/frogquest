extends CanvasLayer
## "@friend invited you to climb together": Join or Not Now, over whatever's on the screen (MuseSocial
## shows it when an invite turns up). Join goes into their online party; if they're already climbing, the
## climb starts for you too, otherwise it waits here until they start. It goes by itself after a while.

const BTN_HEIGHT := 28
const BTN_FONT_SZ := 16
const GOLD := Color(0.95, 0.88, 0.65)
const GREEN := Color(0.5, 1.0, 0.5)
const RED := Color(1.0, 0.6, 0.5)
const SHOWN_FOR := 30.0  # seconds before an unanswered one goes

var invite := {}

var _panel: PanelContainer
var _words: Label
var _join: Button
var _no: Button
var _left := SHOWN_FOR
var _waiting := false  # said yes; waiting for them to start


func _ready() -> void:
	layer = 90  # (over everything, the menus too)
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui.panel_box(8))
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var from: Dictionary = invite.get("from", {}) if invite.get("from") is Dictionary else {}
	_words = Label.new()
	_words.text = "@%s invited you to climb together!" % str(from.get("handle", "a friend"))
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.style_label(_words, 16, GOLD)
	box.add_child(_words)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_join = _button("Join", _on_join, "go")
	_no = _button("Not Now", _on_no, "quiet")
	row.add_child(_join)
	row.add_child(_no)
	Party.started.connect(queue_free)  # (the climb's on: Endless takes over)
	Party.ended.connect(func(why: String) -> void:
		if _waiting:
			_say(why if why != "" else "The party ended.", RED)
			_waiting = false
			_left = 4.0)
	_place()


func _on_join() -> void:
	_join.disabled = true
	_no.disabled = true
	_say("Joining...", GOLD)
	var problem: String = await MuseSocial.answer_invite(invite, true)
	if problem != "":
		_say(problem, RED)
		_left = 4.0
		return
	_waiting = true
	_say("You're in! Waiting for them to start the climb...", GREEN)
	_no.text = "Leave"
	_no.disabled = false


func _on_no() -> void:
	if _waiting:
		Party.leave()
		queue_free()
		return
	MuseSocial.answer_invite(invite, false)
	queue_free()


func _say(what: String, colour: Color) -> void:
	_words.text = what
	_words.add_theme_color_override("font_color", colour)


func _process(delta: float) -> void:
	_place()
	if _waiting:
		return
	_left -= delta
	if _left <= 0.0:
		queue_free()


## Across the top of the room the screen has (clear of the notch and a top banner), at the menus' size.
func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 50.0:
		return
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var room: Rect2 = ui.room(vp)
	var s: float = ui.panel_zoom(vp, room)
	var width := floorf(ui.across(vp, room, room.size.x * 0.9).y / s)
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.scale = Vector2.ONE * s
	_panel.size = _panel.get_combined_minimum_size()
	_panel.position = Vector2(roundf((vp.x - width * s) * 0.5), roundf(room.position.y + 8.0))


func _button(text: String, on_press: Callable, kind: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, BTN_HEIGHT)
	load("res://scripts/UIStyle.gd").style_button(btn, BTN_FONT_SZ, kind)
	btn.pressed.connect(on_press)
	return btn
