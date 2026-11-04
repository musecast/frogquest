extends CanvasLayer
## Endless's leaderboards (MuseSocial.leaderboard): your friends', and everyone's. Everyone's lists only
## those who chose to show there (the switch at its top, muse_game_set_global). Anyone listed can be
## blocked or reported. Opened from the Muse Account screen and from Endless's game over; built in code
## and dressed like MuseAccountScreen.

signal closed

const BTN_HEIGHT := 28
const BTN_FONT_SZ := 16  # (the pixel font is drawn on a 16-pixel grid)
const TITLE_FONT_SZ := 32
const BODY_FONT_SZ := 16
const GOLD := Color(0.95, 0.88, 0.65)
const GREEN := Color(0.5, 1.0, 0.5)
const RED := Color(1.0, 0.6, 0.5)
const DIM := Color(0.78, 0.74, 0.68)

var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _scope := "friends"  # or "global"
var _board := {}  # what MuseSocial.leaderboard last gave
var _loading := false
var _failed := false
var _open := ""  # the player whose Block and Report are showing
var _reporting := ""
var _note := ""
var _note_colour := GOLD


func _ready() -> void:
	layer = 61
	_build_ui()
	_load()


func _build_ui() -> void:
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
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
	frame.add_child(_label("Leaderboard", TITLE_FONT_SZ, ui.GOLD))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for each in [["Friends", "friends"], ["Everyone", "global"]]:
		var tab := _button(each[0], _pick.bind(each[1]), "go" if each[1] == _scope else "quiet")
		tab.name = "Tab_" + each[1]
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
	frame.add_child(tabs)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.style_scrollbar(_scroll.get_v_scroll_bar())
	frame.add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)
	frame.add_child(_button("Close", func() -> void: closed.emit()))


func _pick(scope: String) -> void:
	if scope == _scope:
		return
	_scope = scope
	for tab in _panel.find_children("Tab_*", "Button", true, false):
		load("res://scripts/UIStyle.gd").style_button(tab, BTN_FONT_SZ, "go" if tab.name == "Tab_" + _scope else "quiet")
	_open = ""
	_load()


func _load() -> void:
	_loading = true
	_failed = false
	_show()
	var scope := _scope
	var board: Dictionary = await MuseSocial.leaderboard(scope)
	if scope != _scope:
		return  # (switched meanwhile)
	_board = board
	_loading = false
	_failed = board.is_empty()
	_show()


func _show() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	if not MuseSocial.is_member():
		_box.add_child(_label("Sign in to your Muse account and pick an @handle to see the leaderboards.", BODY_FONT_SZ, GOLD))
		_finish()
		return
	if _scope == "global":
		_box.add_child(_button("Show Me Here: %s" % ("On" if MuseSocial.on_global else "Off"), _toggle_global, "quiet"))
	if _note != "":
		_box.add_child(_label(_note, BODY_FONT_SZ, _note_colour))
	if _loading:
		_box.add_child(_label("Loading...", BODY_FONT_SZ, DIM))
	elif _failed:
		_box.add_child(_label("Couldn't reach Muse. Check your connection and try again.", BODY_FONT_SZ, RED))
		_box.add_child(_button("Try Again", _load, "quiet"))
	else:
		var rows: Array = _board.get("rows", [])
		if rows.is_empty():
			_box.add_child(_label("No scores here yet. Climb in Endless to be the first!" if _scope == "friends"
				else "Nobody's chosen to show here yet.", BODY_FONT_SZ, DIM))
		for row in rows:
			_row(row)
		var mine = _board.get("me")
		var listed: bool = rows.any(func(r) -> bool: return r is Dictionary and r.get("me") == true)
		if mine is Dictionary and not listed:
			var rank = mine.get("rank")
			_box.add_child(_label(("You: #%d, %d points" % [int(rank), int(mine.get("score", 0))]) if rank != null
				else "You: %d points (not shown here)" % int(mine.get("score", 0)), BODY_FONT_SZ, GREEN))
	_finish()


## One place on the board: rank, @handle, score and height; anyone else's opens Block and Report.
func _row(row: Dictionary) -> void:
	var card: Dictionary = row.get("card", {}) if row.get("card") is Dictionary else {}
	var who := str(card.get("handle", ""))
	var me: bool = row.get("me") == true
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	var words := _label("#%d @%s  %d" % [int(row.get("rank", 0)), who, int(row.get("score", 0))], BODY_FONT_SZ, GREEN if me else GOLD)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(words)
	if not me and who != "":
		var more := _button("...", func() -> void:
			_open = "" if _open == who else who
			_reporting = ""
			_show(), "quiet")
		more.custom_minimum_size = Vector2(BTN_HEIGHT * 1.5, BTN_HEIGHT)
		line.add_child(more)
	_box.add_child(line)
	var height := _label("%d m" % int(row.get("height", 0)), BODY_FONT_SZ, DIM)
	height.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_box.add_child(height)
	if _open == who and who != "":
		if _reporting == who:
			for reason in MuseSocial.REPORT_REASONS:
				_box.add_child(_button(MuseSocial.reason_words(reason), _report.bind(who, reason), "quiet"))
		else:
			_box.add_child(_button("Block @%s" % who, _block.bind(who), "quiet"))
			_box.add_child(_button("Report @%s" % who, func() -> void:
				_reporting = who
				_show(), "quiet"))


func _toggle_global() -> void:
	var problem: String = await MuseSocial.set_global(not MuseSocial.on_global)
	_note = problem
	_note_colour = RED
	_load()


func _block(who: String) -> void:
	_open = ""
	var problem: String = await MuseSocial.block(who)
	_note = "Blocked @%s." % who if problem == "" else problem
	_note_colour = GREEN if problem == "" else RED
	_load()


func _report(who: String, reason: String) -> void:
	_open = ""
	_reporting = ""
	var problem: String = await MuseSocial.report(who, reason)
	_note = "Thanks: the Muse team will look at @%s." % who if problem == "" else problem
	_note_colour = GREEN if problem == "" else RED
	_show()


func _finish() -> void:
	load("res://scripts/UIStyle.gd").finger_scroll(_scroll)
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
	ui.fit_panel(_panel, _scroll, room, ui.panel_zoom(vp, room), 0.9 if portrait else 0.62)


func _label(text: String, font_size: int, color: Color) -> Label:
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
	return btn
