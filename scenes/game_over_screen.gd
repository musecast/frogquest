extends CanvasLayer

var _rock_tweens: Array = []
var _resize_timer: SceneTreeTimer = null
const MODAL_LAYER_OFFSET := 20


func _ready() -> void:
	layer = AdsManager.canvas_layer_above_banner_placeholder()
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
	# The room there is: in from the notch and the home indicator, and between the two banners when
	# they're up (dual ads), with a little margin. The column fills it, centred.
	var inset: Vector4 = AdsManager.get_viewport_safe_insets()
	var top: float = maxf(inset.y, AdsManager.get_viewport_top_banner_clearance())
	var bottom: float = maxf(inset.w, AdsManager.get_viewport_bottom_banner_clearance())
	var margin := 16.0 if is_portrait else 10.0
	var box: VBoxContainer = $MarginContainer
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = inset.x + margin
	box.offset_right = -(inset.z + margin)
	box.offset_top = top + margin * 0.5
	box.offset_bottom = -(bottom + margin * 0.5)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var room := Vector2(vp.x - inset.x - inset.z - margin * 2.0, vp.y - top - bottom - margin)
	# Full size for the shape of the screen, then everything smaller together until it all fits
	# the room (Endless is only 320 wide, and a foldable's inner screen is short for its width).
	var fit := 1.0
	for _try in 5:
		_size_column(is_portrait, fit)
		var need: Vector2 = box.get_combined_minimum_size()
		var shrink := minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0))
		if shrink >= 1.0:
			break
		fit = maxf(0.2, fit * shrink * 0.97)


## The column's sizes for portrait or landscape, times fit (1 is full size).
func _size_column(is_portrait: bool, fit: float) -> void:
	var score_size := maxi(8, roundi((80.0 if is_portrait else 34.0) * fit))
	var label_size := maxi(8, roundi((44.0 if is_portrait else 16.0) * fit))
	var btn_min := (Vector2(200, 64) if is_portrait else Vector2(80, 22)) * fit
	# Zero out minimum sizes on text nodes so only their text decides how wide they are (the fit
	# above measures that; NewBadge, on a new best, makes that row the widest).
	$MarginContainer/ScoreDisplay.custom_minimum_size = Vector2(0, 0)
	$MarginContainer/HighScoreRow.custom_minimum_size = Vector2(0, 0)
	$MarginContainer/HighScoreRow/HighScoreDisplay.custom_minimum_size = Vector2(0, 0)
	$MarginContainer/HighScoreRow/NewBadge.custom_minimum_size = Vector2(0, 0)
	$MarginContainer/ScoreDisplay.add_theme_font_size_override("font_size", score_size)
	for label in [$MarginContainer/HighScoreRow/HighScoreDisplay,
			$MarginContainer/HighScoreRow/NewBadge]:
		label.add_theme_font_size_override("font_size", label_size)
	$MarginContainer/TryAgainButton.custom_minimum_size = btn_min
	$MarginContainer/TryAgainButton.add_theme_font_size_override("font_size", label_size)
	var kgb := $MarginContainer.get_node_or_null("KeepGoingButton")
	if kgb:
		kgb.custom_minimum_size = btn_min
		kgb.add_theme_font_size_override("font_size", int(label_size * 0.75))
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
	_ensure_keep_going_button()
	AdsManager.show_banners_top_and_bottom()
	# After a "keep going" this screen can come back in the same run, still connected.
	if not AdsManager.is_connected("ads_removed_changed", _on_ads_removed):
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
	ws.layer = AdsManager.canvas_layer_above_banner_placeholder() + MODAL_LAYER_OFFSET
	$MarginContainer.visible = false
	AdsManager.hide_banner()
	ws.closed.connect(func() -> void:
		if is_instance_valid(ws):
			ws.queue_free()
		if not is_inside_tree():
			return
		$MarginContainer.visible = true
		var wb := $MarginContainer/BottomRow.get_node_or_null("WardrobeButton")
		if wb:
			_refresh_new_badge(wb)
		AdsManager.show_banners_top_and_bottom()
		_apply_layout()
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


## "Keep going": once per run, watch a rewarded video (or nothing, with Remove Ads) to carry on
## from the last platform with the same score.
func _ensure_keep_going_button() -> void:
	var existing := $MarginContainer.get_node_or_null("KeepGoingButton")
	var offer: bool = get_parent().has_method("can_revive") and get_parent().can_revive() \
		and (AdsManager.is_ad_free() or AdsManager.is_rewarded_ready())
	if not offer:
		if existing:
			existing.queue_free()
		return
	if existing:
		existing.disabled = false
		return
	var btn := Button.new()
	btn.name = "KeepGoingButton"
	btn.text = "KEEP GOING" if AdsManager.is_ad_free() else "KEEP GOING (WATCH AD)"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$MarginContainer.add_child(btn)
	$MarginContainer.move_child(btn, $MarginContainer/TryAgainButton.get_index())
	btn.pressed.connect(_on_keep_going_button_pressed)


func _on_keep_going_button_pressed() -> void:
	var btn := $MarginContainer.get_node_or_null("KeepGoingButton") as Button
	if btn:
		btn.disabled = true
	if AdsManager.is_ad_free():
		_keep_going()
	elif not AdsManager.show_rewarded(_on_rewarded_ad_done):
		if btn:
			btn.queue_free()  # the video went away in the meantime


func _on_rewarded_ad_done(earned: bool) -> void:
	if not is_inside_tree():
		return
	if earned:
		_keep_going()
	else:
		var btn := $MarginContainer.get_node_or_null("KeepGoingButton")
		if btn:
			btn.queue_free()


func _keep_going() -> void:
	var btn := $MarginContainer.get_node_or_null("KeepGoingButton")
	if btn:
		btn.queue_free()
	for t in _rock_tweens:
		t.kill()
	_rock_tweens.clear()
	visible = false
	get_parent().revive()


func _on_try_again_button_pressed() -> void:
	AdsManager.hide_banner()
	get_tree().reload_current_scene()


func _on_exit_button_pressed() -> void:
	AdsManager.hide_banner()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _ensure_remove_ads_button() -> void:
	if AdsManager.is_ad_free():  # bought already, or no ads on this platform (desktop/web)
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
	screen.layer = AdsManager.canvas_layer_above_banner_placeholder() + MODAL_LAYER_OFFSET
	$MarginContainer.visible = false
	AdsManager.hide_banner()
	screen.closed.connect(func() -> void:
		if is_instance_valid(screen):
			screen.queue_free()
		if not is_inside_tree():
			return
		$MarginContainer.visible = true
		_ensure_remove_ads_button()
		AdsManager.show_banners_top_and_bottom()
		_apply_layout()
	)


func _on_ads_removed() -> void:
	_ensure_remove_ads_button()
