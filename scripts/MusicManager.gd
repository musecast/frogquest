extends Node

var MusicPosition = 0
var froggyCrown = 0
var game_beaten: bool = false
var desktop_frog_unlocked: bool = false  # Lil Froggy has jumped out onto the desktop at least once
var ads_removed: bool = false
var has_launched_before: bool = false

var equipped_hat: String = ""
var equipped_skin: String = ""
var unlocked_skins: Array = []
var seen_cosmetics: Array = []
var flies_caught: Array = []  # the hidden flies you've caught (FlyHunt.gd): ids like "fly_3"

const WARDROBE_PATH := "user://wardrobe.save"
var wardrobe_path := WARDROBE_PATH  # (the tests point this somewhere else, so they never touch your save)

func _trace(label: String) -> void:
	print("StartupTrace: %s at %d ms" % [label, Time.get_ticks_msec()])

func has_any_cosmetic() -> bool:
	return froggyCrown != 0 or unlocked_skins.size() > 0 or _has_lil_froggy()

## Lil Froggy lives in the wardrobe too, once he's yours (on a computer): Muse Pro can bring him
## before any hat or skin, and he needs the wardrobe button to get out.
func _has_lil_froggy() -> bool:
	var link: GDScript = load("res://scripts/DesktopFrogLink.gd")
	return link.is_supported() and link.is_unlocked()

func has_unseen_cosmetics() -> bool:
	if froggyCrown != 0 and "froggycrown" not in seen_cosmetics:
		return true
	for skin in unlocked_skins:
		if skin not in seen_cosmetics:
			return true
	return false

func save_wardrobe() -> void:
	_trace("MusicManager save_wardrobe start")
	var f = FileAccess.open(wardrobe_path, FileAccess.WRITE)
	f.store_var({
		"froggyCrown": froggyCrown,
		"equipped_hat": equipped_hat,
		"equipped_skin": equipped_skin,
		"unlocked_skins": unlocked_skins,
		"seen_cosmetics": seen_cosmetics,
		"flies_caught": flies_caught,
		"game_beaten": game_beaten,
		"desktop_frog_unlocked": desktop_frog_unlocked,
		"ads_removed": ads_removed,
		"has_launched_before": has_launched_before,
	})
	f.close()
	_trace("MusicManager save_wardrobe end")

func load_wardrobe() -> void:
	_trace("MusicManager load_wardrobe start")
	if not FileAccess.file_exists(wardrobe_path):
		froggyCrown    = 0
		equipped_hat   = ""
		equipped_skin  = ""
		unlocked_skins = []
		seen_cosmetics = []
		flies_caught   = []
		_trace("MusicManager load_wardrobe end missing file")
		return
	var f = FileAccess.open(wardrobe_path, FileAccess.READ)
	if not f:
		_trace("MusicManager load_wardrobe end open failed")
		return
	var d = f.get_var()
	f.close()
	froggyCrown    = d.get("froggyCrown",    froggyCrown)
	equipped_hat   = d.get("equipped_hat",   "")
	equipped_skin  = d.get("equipped_skin",  "")
	unlocked_skins = d.get("unlocked_skins", [])
	seen_cosmetics = d.get("seen_cosmetics", [])
	flies_caught   = d.get("flies_caught", [])
	game_beaten         = d.get("game_beaten",          false)
	desktop_frog_unlocked = d.get("desktop_frog_unlocked", false)
	ads_removed         = d.get("ads_removed",          false)
	has_launched_before = d.get("has_launched_before",  false)
	_trace("MusicManager load_wardrobe end")

func show_unlock_notification(item_type: String) -> void:
	show_toast("New %s Unlocked!" % ("Hat" if item_type == "hat" else "Skin"))


## A little panel that drops in from the top for a few seconds (unlocks, flies caught...).
func show_toast(text: String) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)

	var vp_size := get_viewport().get_visible_rect().size
	var is_portrait: bool = vp_size.y > vp_size.x * 1.3

	var pw: float = vp_size.x * (0.90 if is_portrait else 0.58)
	var ph: float = vp_size.y * (0.09 if is_portrait else 0.10)
	var px: float = (vp_size.x - pw) * 0.5
	var start_y: float = -ph - 4.0
	var end_y: float = vp_size.y * (0.1 if is_portrait else 0.04)
	var font_size: int = int(min(vp_size.y * 0.028, vp_size.x * 0.050)) if is_portrait else int(vp_size.y * 0.048)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.18, 0.14, 0.11, 0.96)
	panel_style.border_width_left   = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.75, 0.65, 0.45, 0.9)
	panel_style.corner_radius_top_left     = 6
	panel_style.corner_radius_top_right    = 6
	panel_style.corner_radius_bottom_left  = 6
	panel_style.corner_radius_bottom_right = 6

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(px, start_y)
	panel.size = Vector2(pw, ph)
	cl.add_child(panel)

	var h_pad: float = 8.0

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.offset_left  =  h_pad
	lbl.offset_right = -h_pad
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("outline_size", 2)
	panel.add_child(lbl)

	var tween := create_tween()
	tween.tween_property(panel, "position:y", end_y, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(cl.queue_free)


func _ready():
	_trace("MusicManager ready start")
	load_wardrobe()
	if not has_launched_before:
		has_launched_before = true
		save_wardrobe()
	_trace("MusicManager ready end")
	print("StartupTrace: MusicManager ready at %d ms" % Time.get_ticks_msec())

func _process(_delta):
	pass
