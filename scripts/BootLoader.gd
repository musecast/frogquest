extends Control
## What's on screen while the world loads: just the FROG QUEST logo, glow and all, exactly where the
## title screen puts it, so when the world arrives the title fills in around it instead of one screen
## swapping for another. Nothing waits on purpose: the world starts loading right after the first
## frame and takes over the moment it's ready. A little frog hops along the bottom only if loading
## drags on (a first launch on a phone), so it never looks stuck.

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const DESKTOP_FROG_SCENE_PATH := "res://scenes/DesktopFrog.tscn"
const BACKGROUND := Color(0.05, 0.05, 0.08)  # the title screen's dark, same as the boot splash
const HOPPER_AFTER := 1.2  # seconds of loading before the hopping frog shows up
const HOP_TIME := 0.55
const REVEAL_TIME := 0.35  # the world fading in around the logo

var _started_at := 0.0
var _loading := false
var _loading_failed := false
var _swap_queued := false
var _thread_progress := []

var _bg: ColorRect
var _title: Sprite2D
var _glow: Sprite2D
var _hopper: Sprite2D
var _status_label: Label


func _ready() -> void:
	if "--desktop-frog" in OS.get_cmdline_user_args():
		# This copy of the game is Lil Froggy (see DesktopFrogLink.gd): no world to load.
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(DESKTOP_FROG_SCENE_PATH)
		return
	_trace("BootLoader start")
	_started_at = Time.get_ticks_msec() / 1000.0
	# The story's own scale (player.gd's), so the logo comes out the size the title's will be: at the
	# project's 480x180, sideways, it was bigger, and shrank as the title took over.
	get_tree().root.content_scale_size = Vector2i(480, 270)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_begin_load.call_deferred()


func _trace(label: String) -> void:
	print("StartupTrace: %s at %d ms" % [label, Time.get_ticks_msec()])


func _process(_delta: float) -> void:
	if _loading_failed or _swap_queued:
		return
	_layout()  # (every frame: the safe area, and so the title's spot, can settle after the first)
	if _loading:
		_poll_threaded_load()
	var elapsed := Time.get_ticks_msec() / 1000.0 - _started_at
	if elapsed > HOPPER_AFTER:
		_hop(elapsed - HOPPER_AFTER)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_bg = ColorRect.new()
	_bg.color = BACKGROUND
	_bg.z_index = -10  # under the logo's glow, which sits a layer behind the logo
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# The title logo the way player.tscn builds it: wobbling logo, swinging glow, faint frog behind.
	_title = Sprite2D.new()
	_title.texture = load(MuseAccount.logo_path())  # (FROG QUEST+ with Muse Pro)
	_title.set_script(load("res://scenes/Titlewobble.gd"))
	add_child(_title)
	_glow = Sprite2D.new()
	_glow.texture = load("res://assets/shinelight.png")
	_glow.self_modulate = Color(1.0, 0.6913348, 0.21188655)
	_glow.z_index = -1
	_glow.scale = Vector2(0.927, 0.518)
	_glow.set_script(load("res://scenes/point_light_2d.gd"))
	_title.add_child(_glow)
	var shadow_frog := Sprite2D.new()
	shadow_frog.texture = load("res://assets/frog.png")
	shadow_frog.modulate = Color(0.0, 0.0, 0.0, 0.22352941)
	shadow_frog.z_index = -1
	shadow_frog.position = Vector2(-18.181702, -4.545456)
	shadow_frog.scale = Vector2(17.0, 17.0)
	_title.add_child(shadow_frog)

	_hopper = Sprite2D.new()
	_hopper.texture = load("res://assets/frog.png")
	_hopper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hopper.scale = Vector2(0.5, 0.5)
	_hopper.visible = false
	add_child(_hopper)

	_status_label = Label.new()
	_status_label.visible = false
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", load("res://assets/fibberish.ttf"))
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	_status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_status_label.add_theme_constant_override("outline_size", 2)  # (one of the font's pixels: UIStyle.outline_px)
	add_child(_status_label)


## The very spot and size the title screen gives its logo (UIStyle.title_spots, which player.gd lays
## the title out by: it had drifted from a copy of the numbers here, and the logo jumped up as the
## title arrived).
func _layout() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var spots: Dictionary = load("res://scripts/UIStyle.gd").title_spots(vp)
	_title.position = spots.logo
	_title.scale = Vector2.ONE * spots.logo_scale
	_status_label.position = Vector2(0.0, vp.y * 0.62)
	_status_label.size = Vector2(vp.x, 40.0)


func _hop(t: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var phase := fmod(t, HOP_TIME) / HOP_TIME
	_hopper.visible = true
	_hopper.position = Vector2(vp.x * 0.5, vp.y - 14.0 - sin(phase * PI) * 10.0)


func _begin_load() -> void:
	await get_tree().process_frame  # the logo gets drawn before the loading starts
	if not is_inside_tree():
		return
	_trace("BootLoader main scene load start")
	if ResourceLoader.load_threaded_request(MAIN_SCENE_PATH) != OK:
		_trace("BootLoader threaded request failed, fallback start")
		var packed := ResourceLoader.load(MAIN_SCENE_PATH) as PackedScene
		if packed == null:
			_fail_startup("BootLoader: failed to load %s" % MAIN_SCENE_PATH)
			return
		_start_scene(packed)
		return
	_loading = true


func _poll_threaded_load() -> void:
	_thread_progress.clear()
	var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH, _thread_progress)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_loading = false
		_trace("BootLoader main scene threaded load end")
		var packed := ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
		if packed == null:
			_fail_startup("BootLoader: failed to load %s" % MAIN_SCENE_PATH)
			return
		_start_scene.call_deferred(packed)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_loading = false
		_fail_startup("BootLoader: failed to load %s" % MAIN_SCENE_PATH)


## The world goes in underneath while the logo stays on top (its very first frame, before the title
## screen has arranged itself, never shows); then the world fades in around the logo, and the logo
## lifts off with the title screen's own one under it, in the same spot and wobbling in step.
func _start_scene(packed: PackedScene) -> void:
	if _swap_queued or _loading_failed or not is_inside_tree():
		return
	_swap_queued = true
	_hopper.visible = false
	_trace("BootLoader scene swap start")
	var tree := get_tree()
	var cover := CanvasLayer.new()
	cover.layer = 128
	tree.root.add_child(cover)
	reparent(cover)
	var main := packed.instantiate()
	tree.root.add_child(main)
	tree.current_scene = main
	_trace("BootLoader scene swap world added")
	var their_logo := main.get_node_or_null("Player/titlescreen/Title")
	if their_logo:
		their_logo.set("heartoffset", _title.get("heartoffset"))
		var their_glow := their_logo.get_node_or_null("PointLight2D")
		if their_glow:
			their_glow.set("heartoffset", _glow.get("heartoffset"))
	for i in 4:
		await tree.process_frame
	var reveal := create_tween()
	reveal.tween_property(_bg, "modulate:a", 0.0, REVEAL_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if their_logo and is_instance_valid(their_logo):
		# (they're in the same spot; if the screen's changed under it, this one glides onto theirs)
		reveal.parallel().tween_property(_title, "position", their_logo.position, REVEAL_TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		reveal.parallel().tween_property(_title, "scale", their_logo.scale, REVEAL_TIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await reveal.finished
	cover.queue_free()


func _fail_startup(message: String) -> void:
	_loading_failed = true
	_hopper.visible = false
	_status_label.text = "Frog Quest couldn't start.\nPlease close it and open it again."
	_status_label.visible = true
	push_error(message)
