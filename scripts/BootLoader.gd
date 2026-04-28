extends Control

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const MIN_VISIBLE_TIME := 0.45
const PROGRESS_SMOOTHING := 6.0

var _started_at: float = 0.0
var _target_progress := 0.0
var _loading_failed := false
var _swap_queued := false

var _progress_bar: ProgressBar
var _status_label: Label
var _hint_label: Label


func _ready() -> void:
	_started_at = Time.get_ticks_msec() / 1000.0
	_build_ui()
	var err := ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)
	if err != OK:
		_loading_failed = true
		_status_label.text = "Finishing startup..."
		call_deferred("_fallback_to_blocking_load")
		return
	set_process(true)


func _process(delta: float) -> void:
	if _loading_failed or _swap_queued:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH, progress)
	if progress.size() > 0:
		_target_progress = clampf(progress[0], 0.0, 1.0)

	_progress_bar.value = move_toward(
		_progress_bar.value,
		_target_progress * 100.0,
		delta * PROGRESS_SMOOTHING * 100.0
	)

	var elapsed := (Time.get_ticks_msec() / 1000.0) - _started_at
	if elapsed > 6.0:
		_hint_label.text = "First launch can take a little longer."

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_status_label.text = "Loading..."
		ResourceLoader.THREAD_LOAD_LOADED:
			_target_progress = 1.0
			if elapsed >= MIN_VISIBLE_TIME and _progress_bar.value >= 99.0:
				_swap_queued = true
				call_deferred("_swap_to_main_scene")
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading_failed = true
			_status_label.text = "Finishing startup..."
			call_deferred("_fallback_to_blocking_load")


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.796, 0.929, 0.992, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(320.0, 0.0)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)

	var icon := TextureRect.new()
	icon.texture = load("res://assets/frogsplashicon.png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(192.0, 192.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(icon)

	var bar_shell := PanelContainer.new()
	bar_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_shell.custom_minimum_size = Vector2(280.0, 26.0)
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
	bar_shell.add_theme_stylebox_override("panel", shell_style)
	stack.add_child(bar_shell)

	var bar_margin := MarginContainer.new()
	bar_margin.add_theme_constant_override("margin_left", 4)
	bar_margin.add_theme_constant_override("margin_top", 4)
	bar_margin.add_theme_constant_override("margin_right", 4)
	bar_margin.add_theme_constant_override("margin_bottom", 4)
	bar_shell.add_child(bar_margin)

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
	_status_label.add_theme_color_override("font_color", Color(0.16, 0.27, 0.18, 0.95))
	stack.add_child(_status_label)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_color_override("font_color", Color(0.16, 0.27, 0.18, 0.72))
	stack.add_child(_hint_label)


func _swap_to_main_scene() -> void:
	var packed := ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_fallback_to_blocking_load()
		return
	get_tree().change_scene_to_packed(packed)


func _fallback_to_blocking_load() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
