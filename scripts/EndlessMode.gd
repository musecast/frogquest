extends Node2D

@export var platform_scene: PackedScene
@export var moving_platform_scene: PackedScene
@export var generation_ahead_distance: float = 2000.0

@export_group("Debug")
@export var debug_force_moving_platforms: bool = false
@export var debug_force_angled_platforms: bool = false
@export var debug_disable_moving_platforms: bool = false
@export var debug_disable_angled_platforms: bool = false
@export var cleanup_distance_below_player: float = 500.0
@export var min_vertical_gap: float = 70.0
@export var max_vertical_gap: float = 100.0
@export var max_horizontal_step: float = 295.0
@export var min_x: float = -220.0
@export var max_x: float = 220.0
@export var fail_y_threshold: float = 1000.0

const SAVE_PATH := "user://endless_highscore.dat"
var score: int = 0
var high_score: int = 0
var pitch_step: int = 0
var last_platform_id: int = 0
var airborne_since_landing: bool = false
var score_sound: AudioStreamPlayer
var time_since_last_landing: float = 0.0
var next_platform_id: int = 1
var highest_generated_y: float = 0.0
var last_generated_x: float = 0.0
var highest_player_y: float = 0.0
var is_resetting: bool = false

var fade_rect: ColorRect
var canvas_layer: CanvasLayer
var score_label: Label

var _resize_timer: SceneTreeTimer = null
var _zoom_tween: Tween = null
var _pending_notification: Array = []  # [label, type] or empty

@onready var player: CharacterBody2D = $EndlessPlayer
@onready var platforms: Node2D = $Platforms

func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		high_score = f.get_32()
		f.close()

func _save_high_score() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_32(high_score)
	f.close()

func _ready() -> void:
	score_sound = AudioStreamPlayer.new()
	score_sound.stream = load("res://assets/endlessscoresound.mp3")
	score_sound.volume_db = -12.0
	add_child(score_sound)
	score_sound.play()
	await get_tree().process_frame
	score_sound.stop()
	_load_high_score()
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_tree().root.content_scale_size = Vector2i(320, 180)
	_create_ui()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_on_viewport_resized)
	randomize()
	_update_score_label()
	_create_platform(Vector2(0, 0), 0.0)
	highest_generated_y = 0.0
	last_generated_x = 0.0
	for _i in range(20):
		_generate_one_platform_above()
	fade_rect.color.a = 1.0
	_fade(1.0, 0.0, 0.6)
	AdsManager.show_banner_bottom()
	AdsManager.preload_interstitial()

func _create_ui() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	score_label = $CanvasLayer/ScoreLabel
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)

func _on_viewport_resized() -> void:
	if not is_inside_tree():
		return
	_resize_timer = get_tree().create_timer(0.15)
	await _resize_timer.timeout
	if not is_inside_tree():
		return
	_fit_to_viewport()

func _fit_to_viewport() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var half_width = (viewport_size.x / 2.0) * 0.85
	min_x = -half_width
	max_x = half_width
	generation_ahead_distance = viewport_size.y * 1.5
	cleanup_distance_below_player = viewport_size.y * 1.25
	var is_portrait: bool = viewport_size.y > viewport_size.x * 1.3
	if is_portrait:
		score_label.add_theme_font_size_override("font_size", 48)
		score_label.offset_top = viewport_size.y * 0.1
		score_label.offset_bottom = score_label.offset_top + 24.0
	else:
		score_label.add_theme_font_size_override("font_size", 24)
		score_label.offset_top = 10.0
		score_label.offset_bottom = 21.0

	var cam := player.get_node_or_null("Camera2D")
	if cam:
		var ratio: float = viewport_size.y / viewport_size.x
		var t: float = inverse_lerp(0.65, 1.3, clamp(ratio, 0.65, 1.3))
		var zoom_val: float = lerp(0.35, 0.55, t)
		if _zoom_tween and _zoom_tween.is_valid():
			_zoom_tween.kill()
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(cam, "zoom", Vector2(zoom_val, zoom_val), 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_zoom_tween.finished.connect(func(): _zoom_tween = null)

func _process(delta: float) -> void:
	if is_resetting:
		return
	if not player.is_on_floor():
		airborne_since_landing = true
	if time_since_last_landing < 3.0:
		time_since_last_landing += delta
		if time_since_last_landing >= 3.0:
			pitch_step = 0
	if player.global_position.y < highest_player_y:
		highest_player_y = player.global_position.y
	if player.global_position.y > highest_player_y + fail_y_threshold:
		_trigger_reset()
	_generate_platforms_if_needed()
	_cleanup_old_platforms()

func _trigger_reset() -> void:
	is_resetting = true
	pitch_step = 0
	last_platform_id = 0
	airborne_since_landing = false
	$EndlessPlayer.velocity.x = 0
	var is_new_record := score > high_score
	if is_new_record:
		high_score = score
		_save_high_score()
	var label_fade := create_tween()
	label_fade.tween_property(score_label, "modulate:a", 0.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	AdsManager.hide_banner()
	AdsManager.on_game_over()
	$GameOverScreen.show_scores(score, high_score, is_new_record)
	if _pending_notification.size() > 0:
		MusicManager.show_unlock_notification(_pending_notification[0])
		_pending_notification = []

func _fade(from: float, to: float, duration: float) -> void:
	var t = 0.0
	while t < duration:
		t += get_process_delta_time()
		fade_rect.color.a = lerp(from, to, t / duration)
		await get_tree().process_frame
	fade_rect.color.a = to

func register_platform_landing(platform_id: int) -> void:
	if player.landed_platform_ids.has(platform_id):
		# Revisiting a platform — only reset pitch if the player actually jumped and came back
		if airborne_since_landing and platform_id <= last_platform_id:
			pitch_step = 0
		last_platform_id = platform_id
		airborne_since_landing = false
		return

	player.landed_platform_ids[platform_id] = true
	airborne_since_landing = false

	if platform_id == 1:
		last_platform_id = platform_id
		return

	# New platform below the last scored one (shouldn't normally happen, but just in case)
	if platform_id < last_platform_id:
		pitch_step = 0
	last_platform_id = platform_id

	score += 1
	time_since_last_landing = 0.0
	score_sound.pitch_scale = pow(2.0, pitch_step / 12.0)
	score_sound.play()
	pitch_step += 1
	_update_score_label()
	_check_score_unlocks()

func _get_difficulty() -> float:
	return clampf(float(max(score, 0)) / 50.0, 0.0, 1.0)

func _generate_platforms_if_needed() -> void:
	while highest_generated_y > player.global_position.y - generation_ahead_distance:
		_generate_one_platform_above()

func _generate_one_platform_above() -> void:
	var difficulty := _get_difficulty()
	var gap: float = randf_range(min_vertical_gap, max_vertical_gap)
	var x_step: float = randf_range(-max_horizontal_step, max_horizontal_step)
	var next_x: float = clampf(last_generated_x + x_step, min_x, max_x)
	var next_y: float = highest_generated_y - gap
	_create_platform(Vector2(next_x, next_y), difficulty)
	highest_generated_y = next_y
	last_generated_x = next_x

func _create_platform(platform_position: Vector2, difficulty: float = 0.0) -> void:
	var want_moving: bool
	if debug_force_moving_platforms:
		want_moving = true
	elif debug_disable_moving_platforms:
		want_moving = false
	else:
		want_moving = (difficulty > 0.25 and randf() < (difficulty - 0.25) * 1.0)
	var use_moving := want_moving and moving_platform_scene != null

	var platform: Node2D
	if use_moving:
		var mp = moving_platform_scene.instantiate()
		var t := clampf((difficulty - 0.25) / 0.75, 0.0, 1.0)
		mp.speed = lerp(0.9, 2.8, t)
		mp.move_range = lerp(45.0, 120.0, t)
		platform = mp
	else:
		platform = platform_scene.instantiate() as Node2D

	platform.global_position = platform_position
	platform.set_meta("platform_id", next_platform_id)
	next_platform_id += 1

	var do_angle: bool
	if debug_force_angled_platforms:
		do_angle = true
	elif debug_disable_angled_platforms:
		do_angle = false
	else:
		do_angle = difficulty > 0.2
	if do_angle:
		var tilt_t := clampf((difficulty - 0.2) / 0.8, 0.0, 1.0)
		var max_angle := deg_to_rad(lerp(5.0, 45.0, tilt_t))
		var min_angle := deg_to_rad(5.0)
		var tilt_sign := 1.0 if randf() > 0.5 else -1.0
		platform.rotation = tilt_sign * randf_range(min_angle, max_angle)

	if difficulty > 0.5:
		var narrow_t := (difficulty - 0.5) / 0.5
		var min_scale: float = lerp(1.0, 0.6, narrow_t)
		platform.scale.x = randf_range(min_scale, 1.0)

	platforms.add_child(platform)

	for child in platform.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.one_way_collision = true

func _cleanup_old_platforms() -> void:
	for platform in platforms.get_children():
		if platform.global_position.y > player.global_position.y + cleanup_distance_below_player:
			platform.queue_free()

func _check_score_unlocks() -> void:
	var milestones := {25: "grayscale_skin", 50: "negative_skin", 100: "blackcrown"}
	var milestone_types := {25: "skin", 50: "skin", 100: "hat"}
	if score in milestones:
		var id: String = milestones[score]
		if id not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append(id)
			MusicManager.save_wardrobe()
			_pending_notification = [milestone_types[score]]

func _update_score_label() -> void:
	score_label.text = "Score: %d" % score
