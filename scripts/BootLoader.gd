extends Control

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const MIN_VISIBLE_TIME := 0.45
const PROGRESS_SMOOTHING := 6.0

var _started_at: float = 0.0
var _target_progress := 0.0
var _loading_failed := false
var _swap_queued := false
var _blocking_load_started := false

var _progress_bar: ProgressBar
var _status_label: Label
var _hint_label: Label

var _loader_stack: VBoxContainer
var _icon_cell: MarginContainer
var _bar_shell: PanelContainer
var _icon_ideal_px: float = 192.0


func _ready() -> void:
	_started_at = Time.get_ticks_msec() / 1000.0
	_build_ui()
	set_process(true)
	call_deferred("_begin_blocking_load")


func _process(delta: float) -> void:
	if _loading_failed or _swap_queued:
		return

	if not _blocking_load_started:
		_target_progress = minf(_target_progress + delta * 0.55, 0.82)

	_progress_bar.value = move_toward(
		_progress_bar.value,
		_target_progress * 100.0,
		delta * PROGRESS_SMOOTHING * 100.0
	)

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _started_at
	if elapsed > 6.0:
		_hint_label.text = "First launch can take a little longer."


func _fit_loader_layout() -> void:
	if not is_inside_tree() or _loader_stack == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var pad_x := 20.0
	var pad_y := 16.0
	var stack_w := clampf(vp.x - pad_x * 2.0, 96.0, 400.0)
	_loader_stack.custom_minimum_size.x = stack_w

	var sep := 18 if vp.y >= 220.0 else 10
	_loader_stack.add_theme_constant_override("separation", sep)
	# Rough space below the icon: progress shell + gaps + two label lines + margin.
	var below_icon := 26.0 + float(sep) * 3.0 + 56.0 + pad_y * 2.0
	var icon_budget_y := maxf(0.0, vp.y - below_icon)
	var icon_cap_x := stack_w - pad_x
	var side := minf(_icon_ideal_px, minf(icon_cap_x, icon_budget_y))
	side = maxf(side, 20.0)
	_icon_cell.custom_minimum_size = Vector2(side, side)

	var bar_min_w := clampf(stack_w - 16.0, 96.0, 280.0)
	_bar_shell.custom_minimum_size = Vector2(bar_min_w, 26.0)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.14, 0.14, 0.15, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_loader_stack = VBoxContainer.new()
	_loader_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_loader_stack.add_theme_constant_override("separation", 18)
	center.add_child(_loader_stack)

	var icon_tex := load("res://assets/frogsplashicon.png") as Texture2D
	var icon_px := icon_tex.get_size() * 2.0 if icon_tex else Vector2(192.0, 192.0)
	_icon_ideal_px = icon_px.x
	var icon_row := HBoxContainer.new()
	icon_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var icon_spacer_l := Control.new()
	icon_spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_row.add_child(icon_spacer_l)

	_icon_cell = MarginContainer.new()
	_icon_cell.add_theme_constant_override("margin_left", 0)
	_icon_cell.add_theme_constant_override("margin_top", 0)
	_icon_cell.add_theme_constant_override("margin_right", 0)
	_icon_cell.add_theme_constant_override("margin_bottom", 0)
	_icon_cell.custom_minimum_size = icon_px
	_icon_cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon_cell.clip_contents = true
	icon_row.add_child(_icon_cell)

	var icon_spacer_r := Control.new()
	icon_spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_row.add_child(icon_spacer_r)

	_loader_stack.add_child(icon_row)

	var icon := TextureRect.new()
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.texture = icon_tex
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_cell.add_child(icon)

	_bar_shell = PanelContainer.new()
	_bar_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_shell.custom_minimum_size = Vector2(280.0, 26.0)
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.16, 0.27, 0.18, 0.45)
	shell_style.border_color = Color(1.0, 1.0, 1.0, 0.4)
	shell_style.border_width_left = 2
	shell_style.border_width_top = 2
	shell_style.border_width_right = 2
	shell_style.border_width_bottom = 2
	shell_style.corner_radius_top_left = 12
	shell_style.corner_radius_top_right = 12
	shell_style.corner_radius_bottom_right = 12
	shell_style.corner_radius_bottom_left = 12
	_bar_shell.add_theme_stylebox_override("panel", shell_style)
	_loader_stack.add_child(_bar_shell)

	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 4)
	bar_margin.add_theme_constant_override("margin_top", 4)
	bar_margin.add_theme_constant_override("margin_right", 4)
	bar_margin.add_theme_constant_override("margin_bottom", 4)
	_bar_shell.add_child(bar_margin)

	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 3.0
	_progress_bar.custom_minimum_size = Vector2(0.0, 18.0)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.43, 0.78, 0.39, 1.0)
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_right = 8
	fill_style.corner_radius_bottom_left = 8
	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	empty_style.corner_radius_top_left = 8
	empty_style.corner_radius_top_right = 8
	empty_style.corner_radius_bottom_right = 8
	empty_style.corner_radius_bottom_left = 8
	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	_progress_bar.add_theme_stylebox_override("background", empty_style)
	bar_margin.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.text = "Loading..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.9, 0.95))
	_loader_stack.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.88, 0.82, 0.75))
	_loader_stack.add_child(_hint_label)

	get_viewport().size_changed.connect(_fit_loader_layout)
	call_deferred("_fit_loader_layout")


func _begin_blocking_load() -> void:
	_blocking_load_started = true
	_status_label.text = "Loading..."
	await get_tree().process_frame
	await get_tree().process_frame

	var packed := ResourceLoader.load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_loading_failed = true
		_status_label.text = "Startup failed"
		push_error("BootLoader: failed to load %s" % MAIN_SCENE_PATH)
		return

	_target_progress = 1.0
	_progress_bar.value = 100.0
	var elapsed := (Time.get_ticks_msec() / 1000.0) - _started_at
	if elapsed < MIN_VISIBLE_TIME:
		await get_tree().create_timer(MIN_VISIBLE_TIME - elapsed).timeout
	_swap_queued = true
	get_tree().change_scene_to_packed(packed)
