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

## "New Hat Unlocked!", with the hat (or the frog wearing the skin) when item_id says which.
func show_unlock_notification(item_type: String, item_id := "") -> void:
	var icon: Control = null
	var detail := ""
	var wardrobe: GDScript = load("res://scenes/WardrobeScreen.gd")
	if wardrobe.ITEMS.has(item_id):
		icon = wardrobe.item_icon(item_id, 0.0)
		detail = "%s, in your wardrobe" % wardrobe.ITEMS[item_id]["label"]
	show_toast("New %s Unlocked!" % ("Hat" if item_type == "hat" else "Skin"), icon, detail)


var _toasts: Array = []  # waiting their turn: [text, icon, detail]
var _toast_up := false
var toast_host: Node = null  # (tools/validate_layout_fit.gd shows them in its own viewport)


## A card that drops in at the top for a few seconds (unlocks, flies caught...): words, and maybe a
## picture and a second line. One at a time: the next waits until this one's gone.
func show_toast(text: String, icon: Control = null, detail := "") -> void:
	_toasts.append([text, icon, detail])
	if not _toast_up:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		_toast_up = false
		return
	_toast_up = true
	var toast: Array = _toasts.pop_front()
	var ui: GDScript = load("res://scripts/UIStyle.gd")
	var cl := CanvasLayer.new()
	cl.layer = 100
	var host: Node = toast_host if is_instance_valid(toast_host) else self
	host.add_child(cl)

	var vp := host.get_viewport().get_visible_rect().size
	var room: Rect2 = ui.room(vp)  # (clear of the notch and any banner)
	var portrait: bool = vp.y > vp.x * 1.3
	# (the pixel font is drawn on a 16-pixel grid, so whole steps of it only: UIStyle.px)
	var title_size: int = ui.px(clampf(minf(vp.y * 0.032, vp.x * 0.058), 16.0, 32.0) if portrait else clampf(vp.y * 0.07, 16.0, 24.0))

	var box: StyleBoxFlat = ui.panel_box(10)
	box.content_margin_left = title_size * 0.7
	box.content_margin_right = title_size * 0.9
	box.content_margin_top = title_size * 0.4
	box.content_margin_bottom = title_size * 0.4
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # (if it ever has to shrink: square pixels)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(title_size * 0.5))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon: Control = null  # (the picture, in its slot)
	if toast[1]:
		icon = ui.slot(toast[1], title_size * 2.2)
		row.add_child(icon)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var title := Label.new()
	title.text = toast[0]
	ui.style_label(title, title_size, ui.GOLD)
	words.add_child(title)
	if toast[2] != "":
		var detail := Label.new()
		detail.text = toast[2]
		ui.style_label(detail, maxi(16, roundi(title_size * 0.72)), ui.CREAM)
		words.add_child(detail)
	cl.add_child(panel)

	# Centred at the top of the room, dropping in from above it (smaller, if it's wider than the room).
	var size := panel.get_combined_minimum_size()
	var s := minf(1.0, room.size.x * 0.96 / size.x)
	panel.size = size
	panel.scale = Vector2(s, s)
	size *= s
	panel.position = Vector2(room.position.x + (room.size.x - size.x) * 0.5, room.position.y - size.y - 16.0)
	var rest_y := room.position.y + (room.size.y * 0.05 if portrait else 6.0)
	var tween := cl.create_tween()
	tween.tween_property(panel, "position:y", rest_y, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if icon:
		icon.pivot_offset = icon.get_combined_minimum_size() / 2.0
		tween.tween_property(icon, "scale", Vector2.ONE * 1.25, 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_interval(2.2)
	tween.tween_property(panel, "position:y", room.position.y - size.y - 16.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_callback(_next_toast)
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
