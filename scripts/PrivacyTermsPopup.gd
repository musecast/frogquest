class_name PrivacyTermsPopup
extends CanvasLayer
## Displays bundled plain-text legal docs from res://legal/

enum Doc { PRIVACY, TERMS }

const PATH_PRIVACY := "res://legal/privacy_policy.txt"
const PATH_TERMS := "res://legal/terms_of_use.txt"

static func present(tree: SceneTree, doc: Doc) -> void:
	if tree == null or tree.root == null:
		return
	var layer := new()
	tree.root.add_child(layer)
	layer._build(doc)


func _build(doc: Doc) -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var panel_w := clampf(vp.x * 0.92, 280.0, 560.0)
	var panel_h := clampf(vp.y * 0.82, 280.0, 720.0)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.76)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_clicked)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var shell := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.11, 0.1, 0.98)
	pstyle.border_color = Color(0.52, 0.82, 0.41, 0.9)
	pstyle.border_width_left = 2
	pstyle.border_width_top = 2
	pstyle.border_width_right = 2
	pstyle.border_width_bottom = 2
	pstyle.corner_radius_top_left = 10
	pstyle.corner_radius_top_right = 10
	pstyle.corner_radius_bottom_left = 10
	pstyle.corner_radius_bottom_right = 10
	shell.add_theme_stylebox_override("panel", pstyle)
	shell.custom_minimum_size = Vector2(panel_w, panel_h)
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(shell)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		var n := 14 if side in ["left", "right"] else 12
		margin.add_theme_constant_override("margin_" + side, n)
	shell.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title_txt := "Privacy Policy" if doc == Doc.PRIVACY else "Terms of Use"
	var title := Label.new()
	title.text = title_txt
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", clampi(int(vp.y * 0.045), 16, 26))
	vb.add_child(title)

	var path := PATH_PRIVACY if doc == Doc.PRIVACY else PATH_TERMS
	var body_txt := "(This document could not be loaded from the app data.)"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			body_txt = f.get_as_text()
			f.close()

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = false
	rtl.text = body_txt
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.scroll_active = true
	rtl.custom_minimum_size = Vector2(panel_w - 56.0, panel_h - 110.0)
	rtl.selection_enabled = true
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(rtl)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(row)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.focus_mode = Control.FOCUS_CLICK
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var btn_w := minf(220.0, panel_w - 48.0)
	var btn_h := maxf(40.0, vp.y * 0.068)
	close_btn.custom_minimum_size = Vector2(btn_w, btn_h)
	close_btn.pressed.connect(_close_self)
	row.add_child(close_btn)


func _on_backdrop_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close_self()


func _close_self() -> void:
	queue_free()
