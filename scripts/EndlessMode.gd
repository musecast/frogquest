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
const WATER_Y := 5.0  # the pond's top, just under the first lily pad (EndlessSky draws it)
## Rubber banding, in a party: a stretchy band (a tether) ties you to your nearest friend. Fall, and once
## it's taut they reel you back up to them. Your jumps themselves never change.
const TETHER_SLACK := 140.0  # world units of give in the band before it catches a fall (14 m)
const TETHER_REEL := 0.8  # seconds a friend takes to pull you back up
const TETHER_FALLING := 150.0  # (falling at least this fast,
const TETHER_DROP := 80.0  # and this far below where he last stood: coming down onto a platform isn't a fall)
const TETHER_DRAWN := 1600.0  # (a band longer than this is off the screen: not drawn)
const TETHER_SNAP := 1000.0  # (a fall this long before it's caught, and the band snaps)
const TETHER_RETIE := 180.0  # (snapped: a friend back down this near ties it on again)
const SNAP_RED := Color(1.0, 0.6, 0.5)

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
var _pause_button: Button
var _pause_screen: CanvasLayer
var _splashed := false  # (gone under, in the pond)
static var _splash_sound: AudioStreamWAV
var _party_tags: CanvasLayer  # their names over them (and yours, in gold)
var _tether_peer := 0  # the friend your band is tied to (0: nobody)
var _bands: Node2D  # draws everyone's bands
var _reel := {}  # being pulled up: {path, to, t}
var _ropes := {}  # "a-b" -> TetherRope: each band showing, hanging against the platforms
var _last_floor_y := 0.0  # where he last stood (a fall is well below it)
var _fall_from_y := 0.0  # (the top of this fall: where he last stood, or the top of his jump since)
var snapped := false  # (his band snapped on a fall too far: none till a friend comes back down for him)
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
var _banner: Label  # (a word that isn't a zone's name: "PARTY OVER"; and, under it, how to play)
var _banner_sub: Label
var _titles: CanvasLayer  # (the zones' names: AreaTitle)
var _race: Node = null  # (racing your party up it: PartyRace; null climbing)
const ROOT_REACH := 320.0  # (as far below a mushroom as its stalk goes looking for a cap to grow out of)
const BOUGH_ACROSS := Vector2(26.0, 110.0)  # (how far across a bough reaches to another's stem)
const LEAN := 0.45  # (the most a stalk leans to a cap below, across for each down: about 24 degrees)
const PARTY_MAX_X := 180.0  # (in a party, the tower's as wide as an upright phone's for everyone: the same tower)
var _sky  # (EndlessSky.gd)
var _zones: Script
var _platform_script: Script
var _fly_script: Script

var _resize_timer: SceneTreeTimer = null
var _zoom_tween: Tween = null
var _pending_notification: Array = []  # [type, item id] or empty

@onready var player: CharacterBody2D = $EndlessPlayer
@onready var platforms: Node2D = $Platforms


class Ripple extends Node2D:
	## Rings spreading on the pond where he went in, fading.
	var _t := 0.0

	func _ready() -> void:
		z_index = 6
		z_as_relative = false
		scale = Vector2(1.0, 0.32)  # (flat: rings lying on the water)

	func _process(delta: float) -> void:
		_t += delta
		if _t > 1.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		for k in 3:
			var t := _t - k * 0.18
			if t > 0.0:
				draw_arc(Vector2.ZERO, 6.0 + t * 46.0, 0.0, TAU, 32, Color(0.85, 0.96, 1.0, maxf(0.0, 0.8 - t)), 2.0)


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
	_make_pause_button()
	_make_walls()
	_fit_to_viewport()
	get_viewport().size_changed.connect(_on_viewport_resized)
	player.connect("launched", _on_launched)
	if Party.mode == "story" and (Party.is_on() or Party.online_room != ""):
		Party.leave()  # (a party up the World Tree isn't one for Endless: on your own here)
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
	if Party.in_run and Party.race != "":
		_race = load("res://scripts/PartyRace.gd").new()
		_race.endless = self
		add_child(_race)
		_titles.announce(_race.RACES[_race.kind].name)
		_show_banner("", _race.RACES[_race.kind].how)
	else:
		_titles.announce(_zones.ZONES[0]["name"])
		_show_banner("", "Climb as high as you can!")
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
	# (each zone named as he climbs into it in the story's own look: AreaTitle, its capitals, its gold line
	# and diamonds, its bell; lower down the screen than the story's, under the score)
	_titles = load("res://scripts/AreaTitle.gd").new()
	_titles.top_at = Vector2(0.27, 0.3)
	add_child(_titles)
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
	var zoom_val: float = lerp(0.55, 1.0, t)  # (the story's own, player._apply_camera_zoom: he and the art as big as there)
	# The play area: the screen's width in the world, less room for a platform, kept from getting
	# silly-wide sideways.
	var half_world: float = viewport_size.x / zoom_val * 0.5
	max_x = PARTY_MAX_X if Party.in_run else minf(half_world - 60.0, 340.0)
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
	if _pause_button:  # (as the story's: 20 across at 1.5 to 2.5 times, its middle 26 to 42 in from the corner)
		var room: Rect2 = ui.room(viewport_size)
		var side := 20.0 * lerpf(1.5, 2.5, t)
		var middle := lerpf(26.0, 42.0, t)
		_pause_button.custom_minimum_size = Vector2(side, side)
		_pause_button.size = Vector2(side, side)
		_pause_button.position = (room.position + Vector2(middle, middle) - Vector2(side, side) * 0.5).round()
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
	_banner.offset_top = viewport_size.y * (0.5 if is_portrait else 0.6)  # (under the zone's name: AreaTitle)
	_fit_banner()  # (and the line under it, just under it)

	var cam := player.get_node_or_null("Camera2D")
	if cam:
		if _zoom_tween and _zoom_tween.is_valid():
			_zoom_tween.kill()
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(cam, "zoom", Vector2(zoom_val, zoom_val), 0.3) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		_zoom_tween.finished.connect(func(): _zoom_tween = null)

	# Match anchored banner size to current viewport/orientation (same logic as Main menu).
	AdsManager.sync_banner_with_viewport()


func _process(delta: float) -> void:
	_follow(delta)
	if not _splashed and player.visible and player.global_position.y > WATER_Y + 8.0 and _water_on_screen():
		_splash()
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
	var follow := player.global_position.y
	if _race and _race.out:  # (knocked out of a race: watching the highest frog still in it)
		var leader = _race.watch_y()
		if leader != null:
			follow = leader
	_cam_y = lerpf(_cam_y, follow, 1.0 - exp(-delta * 6.0))
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
	if _race:
		_race.climbed(maxi(metres, 0))
	var zone: int = _zones.index_at(-highest_player_y)
	if zone > _zone_reached:
		_zone_reached = zone
		_titles.announce(_zones.ZONES[zone]["name"])  # (with its own bell)
		if zone == _zones.ZONES.size() - 1 and "starry" not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append("starry")  # (all the way to space: the Starry skin)
			MusicManager.save_wardrobe()
			_pending_notification = ["skin", "starry"]
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
		tw.tween_property(lbl, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(1.8)
		tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _trigger_reset() -> void:
	if _race and _race.fell():
		return  # (no game over in a race: back on your last platform, or, in a knockout, out)
	if Party.in_run and _pull_up():
		return
	is_resetting = true
	_pause_button.visible = false
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
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
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
	player.visible = true  # (out of the pond, if he'd gone in)
	player.set_physics_process(true)
	_splashed = false
	_pause_button.visible = true
	_cam_y = player.global_position.y
	_follow(0.0)
	highest_player_y = player.global_position.y
	last_platform_id = int(platform.get_meta("platform_id", 0))
	airborne_since_landing = false
	is_resetting = false
	var label_fade := create_tween()
	label_fade.tween_property(score_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	AdsManager.show_banner_bottom()
	await _fade(1.0, 0.0, 0.35)


## In a race (PartyRace), a moment after a fall: back on the platform he last stood on (or the highest
## one still there under his best). No game over: the time it cost is the price.
func race_respawn() -> void:
	_revive_platform_id = last_platform_id
	var platform := _revive_spot()
	if platform == null:
		return
	player.global_position = platform.global_position + Vector2(0.0, -40.0)
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	player.visible = true  # (out of the pond, if he'd gone in)
	player.set_physics_process(true)
	_splashed = false
	highest_player_y = minf(platform.global_position.y, player.global_position.y)
	last_platform_id = int(platform.get_meta("platform_id", 0))
	airborne_since_landing = false


## Knocked out of a race: he's gone from it, and the camera watches whoever's highest still in it.
func race_out() -> void:
	player.visible = false
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO


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
		fade_rect.color.a = lerp(from, to, smoothstep(0.0, 1.0, t / duration))
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
	var top := minf(player.global_position.y, _cam_y)  # (watching from out of a race: as far as the camera goes)
	while highest_generated_y > top - generation_ahead_distance:
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
	var fly_chance := float(zone["flies"]) if not (Party.in_run and Party.race == "flies") else 0.85  # (PartyRace.FLY_CHANCE)
	if next_platform_id > 4 and _rng.randf() < fly_chance:
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
	if not plain and not overrides.has("variant"):
		platform.variant = _variant_for(platform.kind, at, t)
	platform.set_meta("platform_id", next_platform_id)
	next_platform_id += 1
	if platform.kind.begins_with("mushroom"):
		_plant(platform, at)  # (its stalk grows out of a cap below it, or another's stem, not on down to the pond)
	platforms.add_child(platform)
	return platform


## Where a mushroom at `at` grows from, the tidiest way there is (EndlessPlatform draws it):
## - straight down onto a cap right under it;
## - out of the side of an upright stem beside it, like a bough;
## - leaning a little (LEAN) onto a cap below: down from its cap, easing over, down onto the other;
## - or out of the pond right under it, near the bottom.
## Never behind another cap or across another stem on the way; with none of those to be had, it's just
## its cap. Worked out from where the platforms are, so the same for everyone in a party.
func _plant(platform: Node2D, at: Vector2) -> void:
	var stems := {}  # (every stalk there is, as points: EndlessPlatform.stem_points)
	for p in platforms.get_children():
		if not p.is_queued_for_deletion() and str(p.kind).begins_with("mushroom"):
			stems[p] = p.stem_points()
	var top := at + Vector2(0.0, platform.stalk_top().y - platform.position.y)
	var best_score := INF
	for p in platforms.get_children():  # (onto a cap below)
		if p.is_queued_for_deletion():
			continue
		var drop: float = p.position.y - at.y
		if drop < 24.0 or drop > ROOT_REACH:
			continue
		var half := float(p.width) * 0.5 - 12.0
		var x := clampf(at.x, p.position.x - half, p.position.x + half)
		var across := absf(x - at.x)
		if across > drop * LEAN or across > 90.0:
			continue
		var score := drop + across * 2.5
		if score < best_score and _stalk_clear(platform, top, Vector2(x, p.position.y), p, stems):
			best_score = score
			platform.stalk_root = Vector2(x, p.position.y)
	var bough: Array = _bough_from(at, stems)  # (out of a stem beside it: a touch preferred, they're the prettiest)
	if not bough.is_empty():
		var j: Vector2 = bough[0]
		var score: float = (j.y - at.y) + absf(j.x - at.x) * 1.4 - 20.0
		if score < best_score:
			best_score = score
			platform.stalk_root = j
			platform.stalk_lean = bough[1]
			platform.stalk_branch = true
	var pond := Vector2(at.x, WATER_Y)  # (out of the pond, right under it)
	if WATER_Y - at.y <= ROOT_REACH and WATER_Y - at.y + 40.0 < best_score and _stalk_clear(platform, top, pond, null, stems):
		platform.stalk_root = pond
		platform.stalk_branch = false


## A stalk from `top` (under a cap) curving down to `root` (EndlessPlatform's lean): clear of every cap but
## the one it grows out of (`into`), and of every other stem?
func _stalk_clear(platform: Node2D, top: Vector2, root: Vector2, into: Node2D, stems: Dictionary) -> bool:
	for k in range(1, 12):
		var u := k / 12.0
		var spot := Vector2(top.x + (root.x - top.x) * smoothstep(0.0, 1.0, u), lerpf(top.y, root.y, u))
		for q in platforms.get_children():
			if q == into or q == platform or q.is_queued_for_deletion():
				continue
			if Rect2(q.position.x - float(q.width) * 0.5 - 8.0, q.position.y - 10.0, float(q.width) + 16.0, 28.0).has_point(spot):
				return false
		for q in stems:
			for p in stems[q]:
				if spot.distance_squared_to(p) < 144.0:
					return false
	return true


## A spot on the side of a mushroom's stem below, on an upright bit of it and clear of both its ends, that a
## stalk from `at` can reach going down and then bending across to it (BOUGH_ACROSS across), without
## running into a cap or another stem: the nearest such, [where, that stem's lean there]; [] if none.
func _bough_from(at: Vector2, stems := {}) -> Array:
	if stems.is_empty():
		for p in platforms.get_children():
			if not p.is_queued_for_deletion() and str(p.kind).begins_with("mushroom"):
				stems[p] = p.stem_points()
	var best := []
	var shortest := INF
	for p in stems:
		var pts: PackedVector2Array = stems[p]
		for i in range(1, pts.size() - 1):
			var j := pts[i]
			var down := pts[i + 1].y - pts[i - 1].y
			if down < 4.0:
				continue
			var lean := (pts[i + 1].x - pts[i - 1].x) / down
			if absf(lean) > 0.6 or j.y < p.position.y + 28.0 or j.y > p.stalk_root.y - 16.0:
				continue
			var across := absf(j.x - at.x)
			var drop := j.y - at.y
			if across < BOUGH_ACROSS.x or across > BOUGH_ACROSS.y or drop < 50.0 or drop > 230.0:
				continue
			var length := drop + across * 1.4
			if length < shortest and _bough_clear(at, j, p, stems):
				shortest = length
				best = [j, lean]
	return best


## A bough from `at` down and across to `j` on `into`'s stem: clear of every cap, and of every other stem?
func _bough_clear(at: Vector2, j: Vector2, into: Node2D, stems: Dictionary) -> bool:
	var down := Rect2(at.x - 10.0, at.y + 8.0, 20.0, j.y - at.y)
	var across := Rect2(minf(at.x, j.x), j.y - 10.0, absf(j.x - at.x), 20.0)
	for q in platforms.get_children():
		if q.is_queued_for_deletion():
			continue
		var cap := Rect2(q.position.x - float(q.width) * 0.5 - 6.0, q.position.y - 10.0, float(q.width) + 12.0, 28.0)
		if cap.intersects(down) or cap.intersects(across):
			return false
	for q in stems:
		if q == into:
			continue
		for spot in stems[q]:
			if down.grow(8.0).has_point(spot) or across.grow(8.0).has_point(spot):
				return false
	return true


## A platform's colours: now and then one of its kind's others (EndlessPlatform.VARIANTS), more often and
## rarer ones the higher up its zone it is, the rarest (gold) only near the top. Worked out from where it
## is, so the same for everyone in a party.
func _variant_for(kind: String, at: Vector2, t: float) -> int:
	var shades: Array = _platform_script.VARIANTS.get(kind, [])
	if shades.is_empty() or _hash01(at, 7) >= 0.06 + 0.34 * t:
		return 0
	var weights := [1.0, 0.9 * t, 0.8 * maxf(0.0, t - 0.35), 0.6 * maxf(0.0, t - 0.65)]
	var total := 0.0
	for i in shades.size():
		total += float(weights[i])
	var pick := _hash01(at, 11) * total
	for i in shades.size():
		pick -= float(weights[i])
		if pick < 0.0:
			return i + 1
	return 1


## A repeatable "random" 0..1 for a spot (whole numbers only, so every phone gets the same).
static func _hash01(at: Vector2, salt: int) -> float:
	var k := int(round(at.x)) * 73856093 ^ int(round(at.y)) * 19349663 ^ salt * 83492791
	k = (k ^ (k >> 13)) * 1274126177
	return float(absi(k) % 10000) / 10000.0


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
	if _race:
		_race.caught_fly()
	var points := GOLDEN_FLY_POINTS if fly.golden else FLY_POINTS
	score += points
	_log_flies.append([int(_run_ms), int(fly.golden)])
	_popup(fly.global_position + Vector2(0, -12), "+%d" % points, GOLD if fly.golden else Color(1.0, 0.6, 0.72), 20 if fly.golden else 16)
	_play("res://assets/pickupCoin.wav", 1.2 if fly.golden else 1.0, -8.0)
	_update_score_label()
	_check_score_unlocks()
	if "cap" not in MusicManager.unlocked_skins:
		MusicManager.unlocked_skins.append("cap")  # (a fly caught: the Cap)
		MusicManager.save_wardrobe()
		_pending_notification = ["hat", "cap"]


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


## The score unlocks: passing 10, 25, 50, 75, 100, 150 and 200 (points come in more than ones now, so
## "passing").
func _check_score_unlocks() -> void:
	var milestones := {10: ["hat", "beanie"], 25: ["skin", "grayscale_skin"], 50: ["skin", "negative_skin"], 75: ["skin", "shiny"],
		100: ["hat", "blackcrown"], 150: ["hat", "tophat"], 200: ["skin", "rainbow"]}
	for need in milestones:
		var id: String = milestones[need][1]
		if score >= need and id not in MusicManager.unlocked_skins:
			MusicManager.unlocked_skins.append(id)
			MusicManager.save_wardrobe()
			_pending_notification = [milestones[need][0], id]


func _update_score_label() -> void:
	if _race:
		return  # (a race's clock is up there: PartyRace)
	score_label.text = "Score: %d" % score


# ── the run, for the leaderboards ───────────────────────────────────────────────────────────────

## A ticket for this run from Muse (only when you're signed in with an @handle and Muse Social is
## there): the server times the run from when it handed this out.
func _get_ticket() -> void:
	if Party.in_run:
		return  # (party climbs, with their catching up and rescues, aren't for the leaderboards)
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
	_bands = Node2D.new()
	_bands.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bands.draw.connect(_draw_bands)
	add_child(_bands)
	Party.frog_moved.connect(_on_frog_moved)
	Party.players_changed.connect(_on_party_changed)
	Party.ended.connect(_on_party_ended)
	# (you're your froggy here too, as you made him: no party colour over him)


func _party_frame(delta: float) -> void:
	var sprite: AnimatedSprite2D = player.sprite
	Party.send_frog([snappedf(player.global_position.x, 0.1), snappedf(player.global_position.y, 0.1), str(sprite.animation),
		sprite.frame, sprite.flip_h, snappedf(sprite.rotation, 0.01), score, maxi(0, int(-highest_player_y / 10.0)),
		_tether_peer if Party.tethers and _race == null else 0, _race.flies if _race else 0, int(_race.out) if _race else 0], delta)
	if _race == null:  # (no bands in a race: everyone for themselves)
		_tether(delta)
		_step_ropes(delta)
	_place_tags()
	_bands.queue_redraw()


## The band: tied to your nearest friend (chosen again whenever you're standing). Falling, once you're
## its slack below a friend who's standing, they reel you up; unless you'd fallen way too far by then
## (TETHER_SNAP): it snaps, and there's none till a friend comes back down for you (TETHER_RETIE).
func _tether(delta: float) -> void:
	if not _reel.is_empty():
		_reel_in(delta)
		return
	if not Party.tethers:
		_tether_peer = 0
		return
	if player.is_on_floor() and player.velocity.y <= 1.0:  # (standing: not on the way down)
		_last_floor_y = player.global_position.y
		_fall_from_y = player.global_position.y
	else:
		_fall_from_y = minf(_fall_from_y, player.global_position.y)  # (the top of his jump)
	if snapped:
		_tether_peer = 0
		for peer in _party_frogs:
			if _party_frogs[peer].position.distance_to(player.global_position) <= TETHER_RETIE:
				_retie(peer)
				break
		return
	if player.velocity.y <= TETHER_FALLING:  # (standing, or on the way up: tie to whoever's nearest)
		var nearest := 0
		for peer in _party_frogs:
			if nearest == 0 or _party_frogs[peer].position.distance_to(player.global_position) \
					< _party_frogs[nearest].position.distance_to(player.global_position):
				nearest = peer
		_tether_peer = nearest
	elif not is_resetting:
		var friend = _party_frogs.get(_tether_peer)
		if friend and friend.standing and player.global_position.y > _last_floor_y + TETHER_DROP 				and player.global_position.y > friend.position.y + TETHER_SLACK:
			if player.global_position.y - _fall_from_y >= TETHER_SNAP:
				_snap(friend)
			else:
				_start_reel(friend)


## A fall way too far for the band: it snaps (a crack and a twang, bits of it flying, there and gone), and
## down he goes; no band now till a friend comes back down for him.
func _snap(friend: Node2D) -> void:
	snapped = true
	_tether_peer = 0
	var colour: Color = load("res://scripts/FroggyLook.gd").band_colour(MusicManager.look)
	_popup(player.global_position + Vector2(0, -40), "your band snapped!", SNAP_RED, 16)
	_band_bits(player.global_position + Vector2(0.0, -8.0), colour)
	if friend:
		_band_bits(friend.position + Vector2(0.0, -8.0), colour)
	_play("res://assets/band_snap.wav", 1.0, -4.0)


## A friend back down beside him: the band's tied on again.
func _retie(peer: int) -> void:
	snapped = false
	_tether_peer = peer
	var who := str(Party.players.get(peer, {}).get("name", "A friend"))
	_popup(player.global_position + Vector2(0, -40), "%s tied your band back on!" % who, GOLD, 16)
	_play("res://assets/coolfind.mp3", 1.35, -9.0)


## Bits of band flying out from `at`, in its colour, gone in a moment.
func _band_bits(at: Vector2, colour: Color) -> void:
	var bits := CPUParticles2D.new()
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = 14
	bits.lifetime = 0.6
	bits.direction = Vector2(0.0, -1.0)
	bits.spread = 180.0
	bits.initial_velocity_min = 90.0
	bits.initial_velocity_max = 190.0
	bits.gravity = Vector2(0.0, 420.0)
	bits.scale_amount_min = 2.0
	bits.scale_amount_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	bits.color_ramp = fade
	bits.z_index = 22
	bits.z_as_relative = false
	add_child(bits)
	bits.global_position = at
	bits.emitting = true
	bits.finished.connect(bits.queue_free)


## Pulled back up by the band, to the steady platform nearest the friend (no skip points for it).
func _start_reel(friend: Node2D) -> bool:
	while highest_generated_y > friend.position.y - generation_ahead_distance:
		_generate_one_platform_above()
	var spot: Node2D = null
	for p in platforms.get_children():
		if p.is_queued_for_deletion() or not p.is_solid() or not _steady(p) or p.global_position.y < friend.position.y - 10.0:
			continue
		if spot == null or p.global_position.distance_to(friend.position) < spot.global_position.distance_to(friend.position):
			spot = p
	if spot == null:
		return false
	_highest_landed_id = maxi(_highest_landed_id, int(spot.get_meta("platform_id", 0)) - 1)
	player.visible = true  # (pulled out of the pond, if he'd gone in)
	_splashed = false
	var to := spot.global_position + Vector2(0.0, -16.0)
	var rope = _ropes.get(_rope_key(Party.me(), friend.peer))
	var band: PackedVector2Array = rope.way() if rope != null and rope.mine else PackedVector2Array()
	# (the way the band goes, round the platforms it's caught on, wide enough for all of him: TetherRope)
	var path: PackedVector2Array = load("res://scripts/TetherRope.gd").body_path(player, player.global_position, to, band)
	_reel = {"path": path, "to": to, "t": 0.0}
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var who := str(Party.players.get(friend.peer, {}).get("name", "A friend"))
	_popup(friend.position + Vector2(0, -40), "%s pulled you up!" % who, GOLD, 16)
	MusicManager.unlock("glow")  # (pulled up by a friend's band: the Glow skin)
	_play("res://assets/coolfind.mp3", 1.2, -6.0)
	return true


## Up the band, quickly at first and gently at the end, along his way round the platforms it's caught
## on, then down onto the platform: moved only as his body can go (up through a platform, as when he
## jumps, never into one from above); caught on something on the way, he's put there at the end anyway.
func _reel_in(delta: float) -> void:
	_reel.t = minf(1.0, float(_reel.t) + delta / TETHER_REEL)
	var k := 1.0 - pow(1.0 - float(_reel.t), 3.0)
	var to: Vector2 = _reel.to
	_slide_to(load("res://scripts/TetherRope.gd").along(_reel.path, k) + Vector2(0.0, -sin(k * PI) * 10.0))
	if _reel.t >= 1.0:
		_reel = {}
		_slide_to(to)
		player.global_position = to
		player.reset_physics_interpolation()
		player.set_physics_process(true)
		if player.global_position.y < highest_player_y:
			highest_player_y = player.global_position.y
			_climbed()


## Toward a spot as his body can go: up against anything in the way and along it, never into it.
func _slide_to(spot: Vector2) -> void:
	var hit := player.move_and_collide(spot - player.global_position)
	if hit:
		player.move_and_collide(hit.get_remainder().slide(hit.get_normal()))
	player.reset_physics_interpolation()


## Falling past the point of no return with nobody to have caught you yet: a friend standing above you
## (not far below your best) still pulls you up. (Usually the band's caught you long before.)
func _pull_up() -> bool:
	if not Party.tethers or not _reel.is_empty():
		return not _reel.is_empty()
	var catcher: Node2D = null
	for frog in _party_frogs.values():
		if not frog.standing or frog.position.y > player.global_position.y - 100.0 \
				or frog.position.y > highest_player_y + fail_y_threshold * 0.5:
			continue
		if catcher == null or absf(frog.position.y - highest_player_y) < absf(catcher.position.y - highest_player_y):
			catcher = frog
	return catcher != null and _start_reel(catcher)


## Every band in the party, as a rope hanging against the platforms (TetherRope): yours to your friend,
## in your band's colour, and each friend's to theirs, in theirs. A frame of each, then drawn.
func _step_ropes(delta: float) -> void:
	var want := {}  # key -> [from node, to node, owner peer]
	var mine := Party.me()
	if Party.tethers:
		if _party_frogs.has(_tether_peer):
			want[_rope_key(mine, _tether_peer)] = [player, _party_frogs[_tether_peer], mine]
		for peer in _party_frogs:
			var to := int(_party_frogs[peer].tether_to)
			if to == 0:
				continue
			var other = player if to == mine else _party_frogs.get(to)
			var key := _rope_key(to, peer)
			if other == null or want.has(key):
				continue
			want[key] = [_party_frogs[peer], other, peer]
	for key in _ropes.keys():
		if not want.has(key):
			_ropes.erase(key)
	var space := player.get_world_2d().direct_space_state
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	for key in want:
		var a: Vector2 = want[key][0].global_position + Vector2(0.0, -8.0)
		var b: Vector2 = want[key][1].global_position + Vector2(0.0, -8.0)
		if a.distance_to(b) > TETHER_DRAWN:
			_ropes.erase(key)
			continue
		var rope = _ropes.get(key)
		if rope == null:
			rope = load("res://scripts/TetherRope.gd").new()
			rope.exclude = [player.get_rid()]  # (an end of it's inside him: it isn't caught on him)
			_ropes[key] = rope
		var owner: int = want[key][2]
		rope.mine = owner == mine
		rope.colour = look.band_colour(MusicManager.look if owner == mine else Party.players.get(owner, {}).get("look"))
		rope.step(a, b, TETHER_SLACK, delta, space, player.collision_mask)


func _rope_key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


func _draw_bands() -> void:
	for rope in _ropes.values():
		rope.draw(_bands)


func _on_frog_moved(peer: int, state: Array) -> void:
	if not Party.players.has(peer):
		return
	if _race:
		_race.saw(peer, state)
	MusicManager.unlock("partyhat")  # (climbing with a friend: the Party Hat)
	if Party.players.size() >= 4:
		MusicManager.unlock("holo")  # (with 3 friends at once: the Holo skin)
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
	_tether_peer = 0
	snapped = false
	_ropes.clear()
	if not _reel.is_empty():
		_reel = {}
		player.set_physics_process(true)
	if _bands:
		_bands.queue_redraw()
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
			want[peer] = [_party_frogs[peer], str(Party.players.get(peer, {}).get("name", Party.NAME)), CREAM]
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
		tag.size = tag.get_combined_minimum_size()
		var frog: Node2D = want[peer][0]
		var head: Vector2 = xf * (frog.global_position + Vector2(0.0, -18.0 * frog.scale.y))
		tag.position = (head - Vector2(tag.size.x * 0.5, tag.size.y)).round()
	# (frogs side by side: a name that would run into another's goes up over it, as up the tree)
	var placed: Array[Rect2] = []
	for peer in want:
		var tag := _party_tags.get_node_or_null("Tag%d" % peer) as Control
		if tag == null:
			continue
		for _try in 4:
			var bumped := false
			for r in placed:
				if r.grow(1.0).intersects(Rect2(tag.position, tag.size)):
					tag.position.y = r.position.y - tag.size.y - 1.0
					bumped = true
			if not bumped:
				break
		placed.append(Rect2(tag.position, tag.size))


# ── pause ───────────────────────────────────────────────────────────────────────────────────────

## The pause button, top left of the room the screen has (clear of a notch, and of an iPhone Duo's camera,
## top right). Pressing it doesn't start a jump (the slingshot leaves presses on buttons alone).
## The story's own pause button (player.tscn's TouchScreenButtonPause): a white square, two black bars in
## it, 6 of its 20 across and 14 down, 3 in; as big and as far in from its corner as there (_fit_to_viewport).
func _make_pause_button() -> void:
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var face := StyleBoxFlat.new()
		face.bg_color = Color(0.8, 0.8, 0.8) if state.contains("pressed") else Color.WHITE
		_pause_button.add_theme_stylebox_override(state, face)
	for left in [3.0, 11.0]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = left / 20.0
		bar.anchor_right = (left + 6.0) / 20.0
		bar.anchor_top = 3.0 / 20.0
		bar.anchor_bottom = 17.0 / 20.0
		_pause_button.add_child(bar)
	_pause_button.pressed.connect(pause)
	$CanvasLayer.add_child(_pause_button)


## Paused: the climb stops where it is under a menu (Resume, Try Again, Main Menu). In a party the others
## keep climbing and your frog waits. Also when the game goes to the background.
func pause() -> void:
	if is_resetting or _pause_screen != null or not is_inside_tree() or not _reel.is_empty():
		return
	get_tree().paused = true
	_pause_screen = load("res://scenes/EndlessPauseScreen.gd").new()
	_pause_screen.resumed.connect(_unpause)
	_pause_screen.try_again.connect(func() -> void:
		_unpause()
		$GameOverScreen._on_try_again_button_pressed())
	_pause_screen.main_menu.connect(func() -> void:
		_unpause()
		$GameOverScreen._on_exit_button_pressed())
	add_child(_pause_screen)


func _unpause() -> void:
	get_tree().paused = false
	if _pause_screen:
		_pause_screen.queue_free()
		_pause_screen = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause.call_deferred()  # (back to it paused, not mid-air; just after: a notification can come while the tree's busy, and the menu can't be added then)


# ── the pond ────────────────────────────────────────────────────────────────────────────────────

## Is the pond on the screen?
func _water_on_screen() -> bool:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return false
	return WATER_Y < _cam_y + get_viewport().get_visible_rect().size.y / cam.zoom.y * 0.5


## Into the pond (missed the lily pad, or fell all the way back): a splash, he goes under, and the run's
## over (unless "keep going", or a friend's tether, pulls him out).
func _splash() -> void:
	_splashed = true
	var at := Vector2(player.global_position.x, WATER_Y)
	var drops := CPUParticles2D.new()
	drops.position = at
	drops.z_index = 6
	drops.one_shot = true
	drops.explosiveness = 1.0
	drops.amount = 28
	drops.lifetime = 0.8
	drops.direction = Vector2(0, -1)
	drops.spread = 55.0
	drops.initial_velocity_min = 90.0
	drops.initial_velocity_max = 190.0
	drops.gravity = Vector2(0, 520)
	drops.scale_amount_min = 1.5
	drops.scale_amount_max = 3.0
	drops.color = Color(0.82, 0.95, 1.0)
	drops.emitting = true
	add_child(drops)
	get_tree().create_timer(1.4).timeout.connect(drops.queue_free)
	var ripple := Ripple.new()
	ripple.position = at
	add_child(ripple)
	var sound := AudioStreamPlayer.new()
	sound.stream = _splash_stream()
	sound.volume_db = -3.0
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
	player.visible = false
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	if not is_resetting:
		_trigger_reset()


## A splash, made here once (there's no recording of one): a short hiss of water, and a bloop that falls.
static func _splash_stream() -> AudioStreamWAV:
	if _splash_sound:
		return _splash_sound
	var rate := 22050
	var count := int(rate * 0.45)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var cutoff := lerpf(0.55, 0.08, minf(1.0, t / 0.35))
		low += (rng.randf_range(-1.0, 1.0) - low) * cutoff
		var hiss := low * minf(1.0, t / 0.005) * exp(-t * 9.0)
		phase += TAU * lerpf(420.0, 160.0, minf(1.0, t / 0.18)) / rate
		var bloop := sin(phase) * exp(-t * 18.0) * 0.5
		data.encode_s16(i * 2, int(clampf(hiss * 0.9 + bloop, -1.0, 1.0) * 30000.0))
	_splash_sound = AudioStreamWAV.new()
	_splash_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_splash_sound.mix_rate = rate
	_splash_sound.stereo = false
	_splash_sound.data = data
	return _splash_sound
