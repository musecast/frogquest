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

var _started_at := 0.0
var _loading := false
var _loading_failed := false
var _swap_queued := false
var _thread_progress := []

var _title: Sprite2D
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
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_begin_load.call_deferred()


func _trace(label: String) -> void:
	print("StartupTrace: %s at %d ms" % [label, Time.get_ticks_msec()])


func _process(_delta: float) -> void:
	if _loading_failed or _swap_queued:
		return
	if _loading:
		_poll_threaded_load()
	var elapsed := Time.get_ticks_msec() / 1000.0 - _started_at
	if elapsed > HOPPER_AFTER:
		_hop(elapsed - HOPPER_AFTER)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = BACKGROUND
	bg.z_index = -10  # under the logo's glow, which sits a layer behind the logo
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# The title logo the way player.tscn builds it: wobbling logo, swinging glow, faint frog behind.
	_title = Sprite2D.new()
	_title.texture = load(MuseAccount.logo_path())  # (FROG QUEST+ with Muse Pro)
	_title.set_script(load("res://scenes/Titlewobble.gd"))
	add_child(_title)
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/shinelight.png")
	glow.self_modulate = Color(1.0, 0.6913348, 0.21188655)
	glow.z_index = -1
	glow.scale = Vector2(0.927, 0.518)
	glow.set_script(load("res://scenes/point_light_2d.gd"))
	_title.add_child(glow)
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
	_status_label.add_theme_constant_override("outline_size", 4)
	add_child(_status_label)


## Same spot and size as player.gd's title screen layout.
func _layout() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.y > vp.x * 1.3
	_title.position = Vector2(vp.x * 0.5, vp.y * 0.25 if portrait else 85.0)
	_title.scale = Vector2.ONE * (0.5 if portrait else 0.3)
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


## The world goes in underneath while the logo stays on top for a few frames (its very first frame,
## before the title screen has arranged itself, never shows); then the logo lifts off and the title
## screen's own logo is sitting in exactly the same spot.
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
	for i in 4:
		await tree.process_frame
	cover.queue_free()


func _fail_startup(message: String) -> void:
	_loading_failed = true
	_hopper.visible = false
	_status_label.text = "Frog Quest couldn't start.\nPlease close it and open it again."
	_status_label.visible = true
	push_error(message)
