extends CanvasLayer

var _rock_tweens: Array = []
var _resize_timer: SceneTreeTimer = null


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_ensure_wardrobe_button()


func _on_viewport_resized() -> void:
	_resize_timer = get_tree().create_timer(0.15)
	await _resize_timer.timeout
	if not is_inside_tree():
		return
	_apply_layout()


func _apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 100.0 or vp.y < 100.0:
		return
	var is_portrait: bool = vp.y > vp.x * 1.3
	var score_size := 80 if is_portrait else 34
	var label_size := 44 if is_portrait else 16
	var btn_min := Vector2(200, 64) if is_portrait else Vector2(80, 22)
	# Apply horizontal margins so the container doesn't bleed to screen edges
	var margin := 32.0 if is_portrait else 24.0
	var half_w := vp.x * 0.5 - margin
	# Zero out minimum sizes on text nodes so their natural text width cannot
	# force the VBoxContainer to expand beyond the margins we set below.
	# This is especially important when NewBadge is visible (new-high-score path).
	$MarginContainer/ScoreDisplay.custom_minimum_size = Vector2(0, 0)
	$MarginContainer/HighScoreRow.custom_minimum_size = Vector2(0, 0)
	$MarginContainer/HighScoreRow/HighScoreDisplay.custom_minimum_size = Vector2(0, 0)
	$MarginContainer/HighScoreRow/NewBadge.custom_minimum_size = Vector2(0, 0)
	$MarginContainer.offset_left = -half_w
	$MarginContainer.offset_right = half_w
	$MarginContainer/ScoreDisplay.add_theme_font_size_override("font_size", score_size)
	for label in [$MarginContainer/HighScoreRow/HighScoreDisplay,
			$MarginContainer/HighScoreRow/NewBadge]:
		label.add_theme_font_size_override("font_size", label_size)
	$MarginContainer/TryAgainButton.custom_minimum_size = btn_min
	$MarginContainer/TryAgainButton.add_theme_font_size_override("font_size", label_size)
	$MarginContainer/BottomRow/ExitButton.custom_minimum_size = btn_min
	$MarginContainer/BottomRow/ExitButton.add_theme_font_size_override("font_size", label_size)
	var wb := $MarginContainer/BottomRow.get_node_or_null("WardrobeButton")
	if wb:
		# Fixed square — crown icon only, exit button expands to fill the rest
		wb.custom_minimum_size = Vector2(btn_min.y, btn_min.y)
		var wb_badge := wb.get_node_or_null("NewBadge") as Label
		if wb_badge:
			wb_badge.add_theme_font_size_override("font_size", int(btn_min.y * 0.33))
	var rab := $MarginContainer.get_node_or_null("RemoveAdsButton")
	if rab:
		rab.add_theme_font_size_override("font_size", int(label_size * 0.6))


func show_scores(score: int, high_score: int, is_new_record: bool) -> void:
	$MarginContainer/ScoreDisplay.text = "Score: %d" % score
	$MarginContainer/HighScoreRow/HighScoreDisplay.text = "Best: %d" % high_score
	_ensure_wardrobe_button()
	_ensure_remove_ads_button()
	AdsManager.show_banner_top()
	AdsManager.connect("ads_removed_changed", _on_ads_removed, CONNECT_ONE_SHOT)

	for t in _rock_tweens:
		t.kill()
	_rock_tweens.clear()

	var hs_label: Label = $MarginContainer/HighScoreRow/HighScoreDisplay
	var badge: Label = $MarginContainer/HighScoreRow/NewBadge
	hs_label.rotation_degrees = 0.0
	badge.rotation_degrees = 0.0
	# Set badge visibility BEFORE _apply_layout so the container already accounts
	# for the badge's size when margins are computed (new-record badge is the widest case).
	badge.visible = is_new_record
	_apply_layout()
	# Deferred re-apply catches any layout recalculation Godot queues after
	# the visibility change is processed in the next frame.
	_apply_layout.call_deferred()

	if is_new_record:
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
		badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		badge.add_theme_constant_override("outline_size", 15)
		var sfx := AudioStreamPlayer.new()
		sfx.stream = load("res://assets/coolfind.mp3")
		add_child(sfx)
		sfx.play()
		sfx.finished.connect(sfx.queue_free)

	# fade the whole screen in
	$MarginContainer.modulate.a = 0.0
	visible = true
	# Re-apply layout after visibility change in case Godot's layout pass
	# runs after the earlier deferred call and resets the container rect.
	_apply_layout.call_deferred()
	var fade := create_tween()
	fade.tween_property($MarginContainer, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await fade.finished

	if is_new_record:
		_start_rocking(hs_label)
		_start_rocking(badge)


func _start_rocking(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	var tween := create_tween().set_loops()
	tween.tween_property(label, "rotation_degrees", 9.0, 0.28) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "rotation_degrees", -9.0, 0.28) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_rock_tweens.append(tween)


func _ensure_wardrobe_button() -> void:
	if not MusicManager.has_any_cosmetic():
		return
	var bottom_row := $MarginContainer/BottomRow
	var existing := bottom_row.get_node_or_null("WardrobeButton")
	if existing:
		_refresh_new_badge(existing)
		return
	var wb := Button.new()
	wb.name = "WardrobeButton"
	wb.icon = load("res://assets/crownicon.png")
	wb.expand_icon = true
	wb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bottom_row.add_child(wb)
	bottom_row.move_child(wb, 0)  # wardrobe left, exit right
	wb.pressed.connect(_on_wardrobe_button_pressed)
	_attach_new_badge(wb)


func _on_wardrobe_button_pressed() -> void:
	var ws = load("res://scenes/WardrobeScreen.gd").new()
	get_tree().root.add_child(ws)
	ws.closed.connect(func() -> void:
		get_tree().root.remove_child(ws)
		var wb := $MarginContainer/BottomRow.get_node_or_null("WardrobeButton")
		if wb:
			_refresh_new_badge(wb)
	)


func _attach_new_badge(btn: Button) -> void:
	if btn.get_node_or_null("NewBadge"):
		return
	var badge := Label.new()
	badge.name = "NewBadge"
	badge.text = "●"
	badge.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	badge.add_theme_constant_override("outline_size", 3)
	badge.add_theme_color_override("font_outline_color", Color(0.5, 0.0, 0.0, 0.9))
	badge.add_theme_font_size_override("font_size", 24)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Proportional anchors: top-right quadrant of the button.
	# No pixel math needed — Godot keeps this correct at any resolution.
	badge.anchor_left   = 0.78
	badge.anchor_right  = 1.0
	badge.anchor_top    = 0.0
	badge.anchor_bottom = -0.1
	badge.offset_left   = 0.0
	badge.offset_top    = 1.0
	badge.offset_right  = -20.0
	badge.offset_bottom = 0.0
	badge.visible = MusicManager.has_unseen_cosmetics()
	btn.add_child(badge)


func _refresh_new_badge(btn: Button) -> void:
	var badge := btn.get_node_or_null("NewBadge") as Label
	if badge:
		badge.visible = MusicManager.has_unseen_cosmetics()


func _on_try_again_button_pressed() -> void:
	AdsManager.hide_banner()
	get_tree().reload_current_scene()


func _on_exit_button_pressed() -> void:
	AdsManager.hide_banner()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _ensure_remove_ads_button() -> void:
	if MusicManager.ads_removed:
		var existing := $MarginContainer.get_node_or_null("RemoveAdsButton")
		if existing:
			existing.queue_free()
		return
	if $MarginContainer.get_node_or_null("RemoveAdsButton"):
		return
	var btn := Button.new()
	btn.name = "RemoveAdsButton"
	btn.text = "Remove Ads"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	$MarginContainer.add_child(btn)
	# Place it just after BottomRow
	var bottom_row := $MarginContainer/BottomRow
	$MarginContainer.move_child(btn, bottom_row.get_index() + 1)
	btn.pressed.connect(_on_remove_ads_button_pressed)


func _on_remove_ads_button_pressed() -> void:
	var screen = load("res://scenes/RemoveAdsScreen.gd").new()
	get_tree().root.add_child(screen)
	screen.closed.connect(func() -> void:
		get_tree().root.remove_child(screen)
		_ensure_remove_ads_button()
	)


func _on_ads_removed() -> void:
	_ensure_remove_ads_button()
