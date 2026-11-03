extends Node2D
## Endless mode: Froggy's climb from his pond to space. The way up goes through five zones
## (EndlessZones.gd): the mushroom swamp, the treetops, the clouds, the sunset sky and outer space,
## each with its own sky, platforms and tricks: red mushrooms and springs to bounce off, twigs and
## puffs that give way, platforms that sway and bob, and floaty low gravity in space. Flies to snap up
## with his tongue, combos for quick climbing, a bonus for skipping platforms, a banner as he reaches
## each zone and a line at his best height. Falling far below his highest point ends the run.

@export var generation_ahead_distance: float = 2000.0
@export var cleanup_distance_below_player: float = 1400.0
@export var fail_y_threshold: float = 1000.0
@export var max_horizontal_step: float = 260.0

var save_path := "user://endless_highscore.dat"  # the best score, then the best height in metres (tests redirect it)
const GRAVITY := 980.0
const JUMP_UP := 450.0  # the trajectory's fastest straight-up launch (endlessplayertrajectory.gd)
const COMBO_MS := 2500  # milliseconds between new platforms to keep a combo going (on the run's clock)
const FLY_POINTS := 2
const GOLDEN_FLY_POINTS := 5
const INK := Color(0.20784314, 0.16862746, 0.1882353)
const CREAM := Color(0.9019608, 0.83137256, 0.74509805)
const GOLD := Color(1.0, 0.86, 0.42)

var score: int = 0
var high_score: int = 0
var best_height: int = 0  # metres
var pitch_step: int = 0
var last_platform_id: int = 0
var airborne_since_landing: bool = false
var score_sound: AudioStreamPlayer
var next_platform_id: int = 1
var highest_generated_y: float = 0.0
var last_generated_x: float = 0.0
var highest_player_y: float = 0.0
var is_resetting: bool = false
var min_x: float = -220.0
var max_x: float = 220.0
var _revive_platform_id: int = 0  # the last platform he stood on before falling
var _revived: bool = false  # one "keep going" per run
var _standing_id: int = 0
var _highest_landed_id: int = 1
var _combo: int = 0
var _run_ms := 0.0  # the run's own clock, in ms: it runs while he climbs, not while the run's ended
var _last_new_ms := -100000  # when he last landed somewhere new, in whole ms on that clock (combos)
var _log_landings: Array = []  # [ms, platform id, height, off a spring] for each first landing: run_log()
var _log_flies: Array = []  # [ms, golden] for each fly caught
var _off_spring := false  # (the jump he's on was launched off a spring)
var _run_ticket := ""  # (MuseSocial.start_run's, asked for as the run starts: the server times it from then)
var _rng := RandomNumberGenerator.new()  # the tower's dice: in a party everyone's share a seed, so everyone climbs the same tower
var _party_frogs := {}  # peer id -> PartyFrog: friends climbing with you (Party)
var _party_tags: CanvasLayer  # their names over them (and yours, in gold)
var _zone_reached: int = 0
var _passed_best: bool = false
var _extra_gap: float = 0.0  # (a bobbing platform's reach, kept off the next gap)
var _last_special := ""  # (no two springs, or two crumbles, in a row)
var _cam_y: float = 0.0
var _walls: Array[StaticBody2D] = []
var _flies: Array = []  # (untyped: a caught fly frees itself, and a typed array won't let go of it)

var fade_rect: ColorRect
var canvas_layer: CanvasLayer
var score_label: Label
var _height_label: Label
var _banner: Label
var _banner_sub: Label
var _sky  # (EndlessSky.gd)
var _zones: Script
var _platform_script: Script
var _fly_script: Script

var _resize_timer: SceneTreeTimer = null
var _zoom_tween: Tween = null
var _pending_notification: Array = []  # [type, item id] or empty

@onready var player: CharacterBody2D = $EndlessPlayer
@onready var platforms: Node2D = $Platforms


class FloatText extends Node2D:
	## A few words floating up off him: points, combos, skips.
	var text := ""
	var colour := Color.WHITE
	var size := 16
	var font: Font
	var _t := 0.0

	func _ready() -> void:
		z_index = 20
		z_as_relative = false
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_t += delta
		position.y -= 36.0 * delta
		modulate.a = clampf(1.6 - _t * 1.6, 0.0, 1.0)
		if _t > 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(-roundf(w * 0.5), 0.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 4), Color(0.2, 0.17, 0.19))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func _load_high_score() -> void:
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		high_score = f.get_32()
		if f.get_length() >= 8:
			best_height = f.get_32()
		f.close()


func _save_high_score() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	f.store_32(high_score)
	f.store_32(best_height)
	f.close()


func _ready() -> void:
	set_process(false)  # (until it's all set up below: the HUD comes a frame in, and _process uses it)
	_zones = load("res://scripts/EndlessZones.gd")
	_platform_script = load("res://scenes/EndlessPlatform.gd")
	_fly_script = load("res://scripts/Fly.gd")
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
	_setup_camera()
	_sky = Node2D.new()
	_sky.set_script(load("res://scenes/EndlessSky.gd"))
	_sky.cam = player.get_node("Camera2D")
	_sky.best_height = best_height * 10.0
	add_child(_sky)
	_create_ui()
	_make_walls()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_on_viewport_resized)
	player.connect("launched", _on_launched)
	if Party.in_run:
		_rng.seed = Party.run_seed
	else:
		_rng.randomize()
	_update_score_label()
	_make_platform(Vector2(0, 0), _zones.ZONES[0], 0.0, true, {"kind": "lilypad", "flower": true, "width": 120.0})
	_height_label.text = "0 m"
	highest_generated_y = 0.0
	last_generated_x = 0.0
	for _i in range(20):
		_generate_one_platform_above()
	fade_rect.color.a = 1.0
	_fade(1.0, 0.0, 0.6)
	_show_banner(_zones.ZONES[0]["name"], "Climb as high as you can!")
	if Party.in_run:
		_join_party()
	set_process(true)
	MuseSocial.set_activity("endless")
	_get_ticket()
	_request_ads_after_first_frames()
	await get_tree().process_frame
	if is_inside_tree():
		AdsManager.sync_banner_with_viewport()


## The camera stays centred on the play area side to side and follows him up and down itself (it used
## to lag behind him to the screen's edge, and stopped following above about 830 m).
func _setup_camera() -> void:
	var cam := player.get_node("Camera2D") as Camera2D
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.drag_horizontal_enabled = false
	cam.limit_top = -10000000
	cam.limit_bottom = 400  # (a little of the pond below the first lily pad, no further)
	_cam_y = player.global_position.y
	cam.global_position = Vector2(0.0, _cam_y)


func _request_ads_after_first_frames() -> void:
	await get_tree().process_frame
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree():
		return
	AdsManager.show_banner_bottom()
	AdsManager.preload_interstitial()
	AdsManager.preload_rewarded()
	AdsManager.sync_banner_with_viewport()


func _create_ui() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	score_label = $CanvasLayer/ScoreLabel
	var font: Font = load("res://assets/fibberish.ttf")
	_height_label = _hud_label(font, CREAM)
	_banner = _hud_label(font, GOLD)
	_banner_sub = _hud_label(font, CREAM)
	for lbl in [_banner, _banner_sub]:
		lbl.modulate.a = 0.0
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(fade_rect)


func _hud_label(font: Font, colour: Color) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_color_override("font_color", colour)
	lbl.add_theme_color_override("font_outline_color", INK)
	lbl.anchor_left = 0.0
	lbl.anchor_right = 1.0
	$CanvasLayer.add_child(lbl)
	return lbl


## Invisible walls at the sides of the screen, so he bounces back into play instead of off the edge.
func _make_walls() -> void:
	for side in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(40.0, 4000.0)
		shape.shape = box
		wall.add_child(shape)
		wall.set_meta("side", side)
		add_child(wall)
		_walls.append(wall)


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
	var is_portrait: bool = viewport_size.y > viewport_size.x * 1.3
	var ratio: float = viewport_size.y / viewport_size.x
	var t: float = inverse_lerp(0.65, 1.3, clamp(ratio, 0.65, 1.3))
	var zoom_val: float = lerp(0.42, 0.7, t)  # (closer than it was: he and the art were tiny on a phone)
	# The play area: the screen's width in the world, less room for a platform, kept from getting
	# silly-wide sideways.
	var half_world: float = viewport_size.x / zoom_val * 0.5
	max_x = minf(half_world - 60.0, 340.0)
	min_x = -max_x
	generation_ahead_distance = viewport_size.y / zoom_val * 1.6
	cleanup_distance_below_player = maxf(1400.0, viewport_size.y / zoom_val * 1.3)
	for wall in _walls:
		wall.position.x = float(wall.get_meta("side")) * (half_world + 20.0)
	# (the pixel font in whole steps of its 16-pixel grid only, with a one-pixel outline: UIStyle)
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var big := 48 if is_portrait else 16
	var small := 32 if is_portrait else 16
	score_label.add_theme_font_size_override("font_size", big)
	score_label.add_theme_constant_override("outline_size", ui.outline_px(big))
	if is_portrait:
		score_label.offset_top = viewport_size.y * 0.1
		score_label.offset_bottom = score_label.offset_top + 24.0
	else:
		score_label.offset_top = 10.0
		score_label.offset_bottom = 21.0
	_height_label.add_theme_font_size_override("font_size", small)
	_height_label.add_theme_constant_override("outline_size", ui.outline_px(small))
	_height_label.offset_top = score_label.offset_top + (52.0 if is_portrait else 20.0)
	_banner.offset_top = viewport_size.y * (0.3 if is_portrait else 0.32)
	_fit_banner()  # (and the line under it, just under it)

	var cam := player.get_node_or_null("Camera2D")
	if cam:
		if _zoom_tween and _zoom_tween.is_valid():
			_zoom_tween.kill()
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(cam, "zoom", Vector2(zoom_val, zoom_val), 0.3) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		_zoom_tween.finished.connect(func(): _zoom_tween = null)

	# Match anchored banner size to current viewport/orientation (same logic as Main menu).
	AdsManager.sync_banner_with_viewport()


func _process(delta: float) -> void:
	_follow(delta)
	if Party.in_run:
		_party_frame(delta)
	if is_resetting:
		return
	if not player.is_on_floor():
		airborne_since_landing = true
	_run_ms += delta * 1000.0
	if _combo > 0 and int(_run_ms) - _last_new_ms > COMBO_MS:
		_combo = 0
		pitch_step = 0
	var height := -player.global_position.y
	player.set("gravity", GRAVITY * _zones.gravity_at(height))
	if player.global_position.y < highest_player_y:
		highest_player_y = player.global_position.y
		_climbed()
	if player.global_position.y > highest_player_y + fail_y_threshold:
		_trigger_reset()
	_generate_platforms_if_needed()
	_cleanup_old_platforms()


## The camera and the walls keep up with him.
func _follow(delta: float) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	_cam_y = lerpf(_cam_y, player.global_position.y, 1.0 - exp(-delta * 6.0))
	cam.global_position = Vector2(0.0, _cam_y)
	for wall in _walls:
		wall.position.y = _cam_y


## The zone's banner and the line under it, each as big as fits across the screen (in whole steps of
## the pixel font's grid: "Climb as high as you can!" ran off an upright phone).
func _fit_banner() -> void:
	var vp := get_viewport().get_visible_rect().size
	var room: float = vp.x * 0.92
	var portrait := vp.y > vp.x * 1.3
	for each in [[_banner, 48 if portrait else 32], [_banner_sub, 32 if portrait else 16]]:
		var lbl: Label = each[0]
		var size: int = each[1]
		var font := lbl.get_theme_font("font")
		while size > 16 and font.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 28.0 > room:
			size -= 16
		lbl.add_theme_font_size_override("font_size", size)
		lbl.add_theme_constant_override("outline_size", load("res://scripts/UIStyle.gd").outline_px(size))
	var title_size: int = _banner.get_theme_font_size("font_size")
	_banner_sub.offset_top = _banner.offset_top + _banner.get_theme_font("font").get_height(title_size) + title_size * 0.25


## He's higher than he's been this run: the height readout, a new zone's banner, passing his best.
func _climbed() -> void:
	var metres := int(-highest_player_y / 10.0)
	_height_label.text = "%d m" % maxi(metres, 0)
	var zone: int = _zones.index_at(-highest_player_y)
	if zone > _zone_reached:
		_zone_reached = zone
		_show_banner(_zones.ZONES[zone]["name"], "%d m" % int(_zones.ZONES[zone]["from"] / 10.0))
		_play("res://assets/appear.mp3", 1.0, -6.0)
	if best_height > 0 and not _passed_best and metres > best_height:
		_passed_best = true
		_popup(player.global_position + Vector2(0, -50), "NEW BEST HEIGHT!", GOLD, 24)
		_play("res://assets/coolfind.mp3", 1.0, -6.0)


func _show_banner(title: String, sub: String) -> void:
	_banner.text = title
	_banner_sub.text = sub
	_fit_banner()
	for lbl in [_banner, _banner_sub]:
		var tw: Tween = lbl.create_tween()
		tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
		tw.tween_interval(1.8)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.6)


func _trigger_reset() -> void:
	is_resetting = true
	pitch_step = 0  # (the combo itself goes by the run's clock alone, stopped now, as score_of_log does)
	_revive_platform_id = last_platform_id
	last_platform_id = 0
	airborne_since_landing = false
	$EndlessPlayer.velocity.x = 0
	var is_new_record := score > high_score
	if is_new_record:
		high_score = score
	var metres := int(-highest_player_y / 10.0)
	if is_new_record or metres > best_height:
		best_height = maxi(best_height, metres)
		_save_high_score()
	var label_fade := create_tween()
	label_fade.tween_property(score_label, "modulate:a", 0.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Inline ads: preserve bottom stripe and add top banner via GameOverScreen (no interim hide_banner).
	AdsManager.on_game_over()
	$GameOverScreen.show_scores(score, high_score, is_new_record)
	if _pending_notification.size() > 0:
		MusicManager.show_unlock_notification(_pending_notification[0], _pending_notification[1])
		_pending_notification = []
	if not can_revive():
		finish_run()


## True if this run can still "keep going" (once per run, with a platform to put him back on).
func can_revive() -> bool:
	return is_resetting and not _revived and _revive_spot() != null


## Where a revive puts him: the last platform he stood on, or, if that crumbled away, the highest one
## still there below his best.
## A steady one, though: one that moves can slide out from under him as he's put back, and one that
## crumbles gives way under him straight after. (Only if there's no steady one does he go on one of those.)
func _revive_spot() -> Node2D:
	var last = _find_platform(_revive_platform_id)
	if last and last.is_solid() and _steady(last):
		return last
	var best: Node2D = null
	for p in platforms.get_children():
		if p.is_queued_for_deletion() or not p.is_solid() or not _steady(p) or p.global_position.y < highest_player_y - 40.0:
			continue
		if best == null or p.global_position.y < best.global_position.y:
			best = p
	if best == null and last and last.is_solid():
		return last
	return best


static func _steady(p: Node) -> bool:
	return p.motion == "" and not p.crumbles


## Puts him back on the last platform he stood on, score and all.
func revive() -> void:
	if not can_revive():
		return
	_revived = true
	await _fade(0.0, 1.0, 0.25)
	var platform := _revive_spot()
	if platform == null or not is_inside_tree():
		return
	player.global_position = platform.global_position + Vector2(0.0, -40.0)
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	_cam_y = player.global_position.y
	_follow(0.0)
	highest_player_y = player.global_position.y
	last_platform_id = int(platform.get_meta("platform_id", 0))
	airborne_since_landing = false
	is_resetting = false
	var label_fade := create_tween()
	label_fade.tween_property(score_label, "modulate:a", 1.0, 0.3)
	AdsManager.show_banner_bottom()
	await _fade(1.0, 0.0, 0.35)


func _find_platform(platform_id: int) -> Node2D:
	if platform_id <= 0:
		return null
	for platform in platforms.get_children():
		if not platform.is_queued_for_deletion() and int(platform.get_meta("platform_id", 0)) == platform_id:
			return platform as Node2D
	return null


func _fade(from: float, to: float, duration: float) -> void:
	var t = 0.0
	while t < duration:
		t += get_process_delta_time()
		fade_rect.color.a = lerp(from, to, t / duration)
		await get_tree().process_frame
	fade_rect.color.a = to


## endlessplayer.gd, every physics frame he's standing on a platform.
func register_platform_landing(platform_id: int) -> void:
	var touchdown := airborne_since_landing or platform_id != _standing_id
	_standing_id = platform_id
	airborne_since_landing = false
	var platform = _find_platform(platform_id)
	if touchdown and platform:
		platform.landed()
		_dust(player.global_position + Vector2(0, 14))
	if player.landed_platform_ids.has(platform_id):
		last_platform_id = platform_id
		return
	player.landed_platform_ids[platform_id] = true
	last_platform_id = platform_id
	var now := int(_run_ms)
	var top: float = platform.global_position.y if platform else player.global_position.y
	_log_landings.append([now, platform_id, roundi(-top), int(_off_spring)])
	if platform_id == 1:
		return
	# Points: one for the platform, one more for each he jumped right past, times the combo.
	var skipped := maxi(0, platform_id - _highest_landed_id - 1)
	_highest_landed_id = maxi(_highest_landed_id, platform_id)
	_combo = _combo + 1 if now - _last_new_ms <= COMBO_MS else 1
	_last_new_ms = now
	var mult := 1 + int(_combo >= 4) + int(_combo >= 8)
	var points := (1 + skipped) * mult
	score += points
	score_sound.pitch_scale = pow(2.0, mini(pitch_step, 12) / 12.0)
	score_sound.play()
	pitch_step += 1
	var text := "+%d" % points
	var colour := CREAM
	if skipped > 0:
		text = "+%d SKIP!" % points
		colour = Color(0.55, 0.95, 0.55)
	if mult > 1:
		text += " x%d" % mult
		colour = GOLD
	_popup(player.global_position + Vector2(0, -40), text, colour, 16 if points == 1 else 20)
	_update_score_label()
	_check_score_unlocks()


## Off a platform: a spring pops back up.
func _on_launched(platform: Node) -> void:
	_off_spring = platform != null and platform.get("spring") == true
	if platform and platform.has_method("launched"):
		platform.launched()


func _generate_platforms_if_needed() -> void:
	while highest_generated_y > player.global_position.y - generation_ahead_distance:
		_generate_one_platform_above()


func _generate_one_platform_above() -> void:
	var height := -highest_generated_y
	var zone: Dictionary = _zones.ZONES[_zones.index_at(height)]
	var t: float = _zones.progress_at(height)
	# The gap up to the next one: the zone's, but never more than a full jump reaches (with room to
	# spare) in the gravity up there, less whatever the last one bobs.
	var g: float = _zones.gravity_at(height + 80.0)
	var reach := 0.85 * JUMP_UP * JUMP_UP / (2.0 * GRAVITY * g)
	var gaps: Array = _zones.ramp(zone["gap"], t)
	var gap := minf(_rng.randf_range(gaps[0], gaps[1]), reach - _extra_gap)
	# Off to one side of the last one (never straight on top of it), turning back at the play area's
	# edge rather than piling up against it.
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var step := _rng.randf_range(50.0, minf(max_horizontal_step, max_x - min_x - 20.0))
	var next_x: float = last_generated_x + side * step
	if next_x < min_x or next_x > max_x:
		next_x = last_generated_x - side * step
	next_x = clampf(next_x, min_x, max_x)
	var next_y: float = highest_generated_y - gap
	var platform = _make_platform(Vector2(next_x, next_y), zone, t, false, {}, reach - gap - _extra_gap)
	highest_generated_y = next_y
	last_generated_x = next_x
	if next_platform_id > 4 and _rng.randf() < float(zone["flies"]):
		_spawn_fly(Vector2(next_x + _rng.randf_range(-40.0, 40.0), next_y - _rng.randf_range(34.0, 80.0)))
	if platform.motion == "bob":
		_extra_gap = platform.motion_range * 0.35
	else:
		_extra_gap = 0.0


## A platform for a zone at t through it (plain: no tricks). spare: how much higher than its spot it
## could be and still be jumpable from the one below, which is all a bobbing one may rise.
func _make_platform(at: Vector2, zone: Dictionary, t: float, plain: bool, overrides := {}, spare := 0.0) -> Node2D:
	var platform = StaticBody2D.new()
	platform.set_script(_platform_script)
	var widths: Array = _zones.ramp(zone["width"], t)
	platform.width = roundf(_rng.randf_range(widths[0], widths[1]))
	platform.kind = _pick_kind(zone["kinds"], _rng)
	platform.phase = _rng.randf() * TAU  # (where a moving one starts its swing)
	if Party.in_run:
		platform.clock = Party.run_seconds  # (and everyone's swing in time together)
	if not plain and next_platform_id > 3:
		var r := _rng.randf()
		var spring_chance: float = _zones.ramp(zone["spring"], t)
		var crumble_chance: float = _zones.ramp(zone["crumble"], t) if zone["crumble_kind"] != "" else 0.0
		# (a second spring in a row is a plain one: it used to fall through to a crumbling one, even in
		# the swamp, which has none, and came out an invisible platform you could stand on)
		if r < spring_chance:
			if _last_special != "spring":
				platform.spring = true
				if zone["spring_kind"] != "":
					platform.kind = zone["spring_kind"]
					platform.coil = false
				_last_special = "spring"
			else:
				_last_special = ""
		elif r < spring_chance + crumble_chance and _last_special != "crumble":
			platform.crumbles = true
			platform.kind = zone["crumble_kind"]
			_last_special = "crumble"
		else:
			_last_special = ""
		if _rng.randf() < float(_zones.ramp(zone["moving"], t)):
			var speeds: Array = zone["speed"]
			var ranges: Array = zone["range"]
			platform.motion_speed = lerpf(speeds[0], speeds[1], t) * _rng.randf_range(0.8, 1.2)
			platform.motion_range = lerpf(ranges[0], ranges[1], t)
			if _rng.randf() < float(zone["bob"]) and spare >= 12.0:
				platform.motion = "bob"
				platform.motion_range = minf(platform.motion_range, spare / 0.35)
			else:
				platform.motion = "drift" if zone["name"] == "OUTER SPACE" else "sway"
				# (kept inside the play area as it swings)
				var room := maxf(0.0, max_x - platform.width * 0.5)
				platform.motion_range = minf(platform.motion_range, room)
				at.x = clampf(at.x, min_x + platform.motion_range, max_x - platform.motion_range)
		var tilt: float = _zones.ramp(zone["tilt"], t)
		if tilt > 0.0 and _rng.randf() < 0.5:
			platform.rotation = _rng.randf_range(-tilt, tilt)
	for key in overrides:
		platform.set(key, overrides[key])
	platform.position = at
	platform.set_meta("platform_id", next_platform_id)
	next_platform_id += 1
	platforms.add_child(platform)
	return platform


static func _pick_kind(kinds: Array, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in kinds:
		total += float(k[1])
	var r := rng.randf() * total
	for k in kinds:
		r -= float(k[1])
		if r <= 0.0:
			return k[0]
	return kinds[0][0]


## A fly near a platform: his tongue snaps it up when he comes close.
func _spawn_fly(at: Vector2) -> void:
	var fly = Node2D.new()
	fly.set_script(_fly_script)
	fly.position = at
	fly.golden = _rng.randf() < 0.1
	fly.hunt_for(player, _on_fly_caught)
	add_child(fly)
	_flies.append(fly)


func _on_fly_caught(fly) -> void:
	var points := GOLDEN_FLY_POINTS if fly.golden else FLY_POINTS
	score += points
	_log_flies.append([int(_run_ms), int(fly.golden)])
	_popup(fly.global_position + Vector2(0, -12), "+%d" % points, GOLD if fly.golden else Color(1.0, 0.6, 0.72), 20 if fly.golden else 16)
	_play("res://assets/pickupCoin.wav", 1.2 if fly.golden else 1.0, -8.0)
	_update_score_label()
	_check_score_unlocks()


func _popup(at: Vector2, text: String, colour: Color, size: int) -> void:
	var p := FloatText.new()
	p.text = text
	p.colour = colour
	p.size = size
	p.font = load("res://assets/fibberish.ttf")
	p.position = at
	add_child(p)


## A little puff where he lands, in the zone's colours.
func _dust(at: Vector2) -> void:
	var zone: Dictionary = _zones.ZONES[_zones.index_at(-at.y)]
	var puff := CPUParticles2D.new()
	puff.position = at
	puff.z_index = 5
	puff.one_shot = true
	puff.explosiveness = 0.9
	puff.amount = 8
	puff.lifetime = 0.45
	puff.direction = Vector2(0, -1)
	puff.spread = 70.0
	puff.initial_velocity_min = 30.0
	puff.initial_velocity_max = 70.0
	puff.gravity = Vector2(0, 160)
	puff.scale_amount_min = 2.0
	puff.scale_amount_max = 3.5
	puff.color = zone["dust"]
	puff.emitting = true
	add_child(puff)
	get_tree().create_timer(1.0).timeout.connect(puff.queue_free)


func _play(path: String, pitch: float, db: float) -> void:
	var s := AudioStreamPlayer.new()
	s.stream = load(path)
	s.pitch_scale = pitch
	s.volume_db = db
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


func _cleanup_old_platforms() -> void:
	var limit := player.global_position.y + cleanup_distance_below_player
	for platform in platforms.get_children():
		if platform.global_position.y > limit:
			platform.queue_free()
	var kept := []
	for fly in _flies:
		if not is_instance_valid(fly):
			continue
		if fly.global_position.y > limit:
			fly.queue_free()
		else:
			kept.append(fly)
	_flies = kept


## The score unlocks: passing 25, 50 and 100 (points come in more than ones now, so "passing").
func _check_score_unlocks() -> void:
	var milestones := {25: ["skin", "grayscale_skin"], 50: ["skin", "negative_skin"], 100: ["hat", "blackcrown"]}
	for need in milestones:
		var id: String = milestones[need][1]
		if score >= need and id not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append(id)
			MusicManager.save_wardrobe()
			_pending_notification = [milestones[need][0], id]


func _update_score_label() -> void:
	score_label.text = "Score: %d" % score


# ── the run, for the leaderboards ───────────────────────────────────────────────────────────────

## A ticket for this run from Muse (only when you're signed in with an @handle and Muse Social is
## there): the server times the run from when it handed this out.
func _get_ticket() -> void:
	_run_ticket = await MuseSocial.start_run()


## The run's over for good (no "keep going" left, or Try Again or Exit): MuseSocial posts its log to the
## leaderboards, if it got a ticket as it started. Once only.
func finish_run() -> void:
	if _run_ticket == "":
		return
	var ticket := _run_ticket
	_run_ticket = ""
	MuseSocial.post_run(ticket, run_log())


## What happened this run, for the server to work the score out from and check (EndlessMode.score_of_log
## is the same rule): each first landing [ms, platform id, height in world units, off a spring] and each fly
## caught [ms, golden], on the run's own clock.
func run_log() -> Dictionary:
	return {"v": 1, "landings": _log_landings.duplicate(true), "flies": _log_flies.duplicate(true), "end_ms": int(_run_ms)}


## A run's score from its log, by the game's own rule (register_platform_landing, _on_fly_caught): the
## leaderboard's server recomputes it the same way, so the score is never just taken from the phone.
static func score_of_log(log: Dictionary) -> int:
	var total := 0
	var highest := 1
	var combo := 0
	var last_ms := -100000
	for landing in log.get("landings", []):
		var id := int(landing[1])
		if id == 1:
			continue
		var ms := int(landing[0])
		var skipped := maxi(0, id - highest - 1)
		highest = maxi(highest, id)
		combo = combo + 1 if ms - last_ms <= COMBO_MS else 1
		last_ms = ms
		total += (1 + skipped) * (1 + int(combo >= 4) + int(combo >= 8))
	for fly in log.get("flies", []):
		total += GOLDEN_FLY_POINTS if int(fly[1]) == 1 else FLY_POINTS
	return total


# ── a party ─────────────────────────────────────────────────────────────────────────────────────

## Climbing with friends (Party): their frogs come and go as they do, and yours goes to them.
func _join_party() -> void:
	_party_tags = CanvasLayer.new()
	_party_tags.layer = 2
	add_child(_party_tags)
	Party.frog_moved.connect(_on_frog_moved)
	Party.players_changed.connect(_on_party_changed)
	Party.ended.connect(_on_party_ended)
	var c: Color = Party.COLORS[Party.color]
	if c.a > 0.0 and not str(MusicManager.equipped_skin) in ["golden_skin", "grayscale_skin", "negative_skin"]:
		player.sprite.material = load("res://scripts/PartyFrog.gd")._tint(c, 0.45)


func _party_frame(delta: float) -> void:
	var sprite: AnimatedSprite2D = player.sprite
	Party.send_frog([snappedf(player.global_position.x, 0.1), snappedf(player.global_position.y, 0.1), str(sprite.animation),
		sprite.frame, sprite.flip_h, snappedf(sprite.rotation, 0.01), score, maxi(0, int(-highest_player_y / 10.0))], delta)
	_place_tags()


func _on_frog_moved(peer: int, state: Array) -> void:
	if not Party.players.has(peer):
		return
	var frog = _party_frogs.get(peer)
	if frog == null:
		frog = Node2D.new()
		frog.set_script(load("res://scripts/PartyFrog.gd"))
		add_child(frog)
		frog.setup(player, peer, Party.players[peer])
		_party_frogs[peer] = frog
	frog.show_state(state)


## Someone left (their frog goes) or changed their look (it's dressed again).
func _on_party_changed() -> void:
	for peer in _party_frogs.keys():
		if not Party.players.has(peer):
			_party_frogs[peer].queue_free()
			_party_frogs.erase(peer)
		else:
			_party_frogs[peer].dress(Party.players[peer])


func _on_party_ended(why: String) -> void:
	for peer in _party_frogs:
		_party_frogs[peer].queue_free()
	_party_frogs.clear()
	_place_tags()
	if why != "":
		_show_banner("PARTY OVER", why)


## Each frog's name just over its head, on the screen at the pixel font's size (so it's crisp at any
## zoom): friends' in cream, yours in gold. Off with the name tags setting.
func _place_tags() -> void:
	if _party_tags == null:
		return
	var want := {}
	if Party.name_tags and Party.in_run and Party.players.size() > 1:
		want[0] = [player, Party.display_name(), GOLD]
		for peer in _party_frogs:
			want[peer] = [_party_frogs[peer], str(Party.players.get(peer, {}).get("name", "Froggy")), CREAM]
	for tag in _party_tags.get_children():
		if not want.has(int(tag.get_meta("peer", -1))):
			tag.queue_free()
	var xf := get_viewport().get_canvas_transform()
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	for peer in want:
		var tag := _party_tags.get_node_or_null("Tag%d" % peer) as Label
		if tag == null:
			tag = Label.new()
			tag.name = "Tag%d" % peer
			tag.set_meta("peer", peer)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui.style_label(tag, 16, want[peer][2])
			_party_tags.add_child(tag)
		tag.text = want[peer][1]
		var frog: Node2D = want[peer][0]
		var head: Vector2 = xf * (frog.global_position + Vector2(0.0, -18.0 * frog.scale.y))
		tag.position = (head - Vector2(tag.size.x * 0.5, tag.size.y)).round()
