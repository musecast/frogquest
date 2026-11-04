extends SceneTree
## Draws the menus and checks every button's words sit in the very middle of its face, across and up
## and down, with any picture (the title's) level with them at its left end and clear of them. A
## button's words came out a few pixels high, and the title's ENDLESS, WARDROBE, MUSE ACCOUNT and
## SETTINGS well right of CONTINUE's. Measured off the pixels drawn: the face is the button's fill
## colour above its lip, the words its cream ones. Up and down, with capitals in place of the words
## (their middle is what's centred; a "g" or a "y" hangs below it), to half a pixel; across, the words
## themselves, to a pixel (an odd number of pixels wide can't sit dead in the middle of an even one).
## It draws, so it runs with a window, not headless:
##   Godot --path . --script res://tools/validate_button_words.gd

const STORY_BASE := Vector2(480, 270)
const ENDLESS_BASE := Vector2(320, 180)
const SHAPES := {  # window sizes, in points; and the safe area's side strip, a share of the width
	"phone upright": [Vector2(390, 844), 0.0],
	"phone sideways": [Vector2(844, 390), 0.0],
	"iPhone Duo upright": [Vector2(1375, 2000), 0.18],
	"iPad upright": [Vector2(1024, 1366), 0.0],
}
const SCRATCH_SAVE := "user://test_words_save_game.save"
const SCRATCH_WARDROBE := "user://test_words_wardrobe.save"

var _failures: Array[String] = []
var _measured := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("validate_button_words draws the menus: run it with a window (without --headless).")
		quit(2)
		return
	var mm := root.get_node("MusicManager")
	var ads := root.get_node("AdsManager")
	var real_wardrobe: String = mm.wardrobe_path
	var real_bytes := FileAccess.get_file_as_bytes(real_wardrobe) if FileAccess.file_exists(real_wardrobe) else PackedByteArray()
	mm.wardrobe_path = SCRATCH_WARDROBE
	var real := [mm.froggyCrown, mm.ads_removed, mm.unlocked_skins.duplicate(), mm.seen_cosmetics.duplicate(), mm.look_made]
	mm.froggyCrown = 1
	mm.look_made = true  # (he's made his froggy already: the title, not the frog god's intro over it)
	mm.ads_removed = false
	for id in load("res://scenes/WardrobeScreen.gd").ITEMS:
		if id != "froggycrown" and id not in mm.unlocked_skins:
			mm.unlocked_skins.append(id)

	for shape in SHAPES:
		var window: Vector2 = SHAPES[shape][0]
		for base in [STORY_BASE, ENDLESS_BASE]:
			var vp := _viewport_for(window, base)
			var upright := window.y > window.x
			ads.test_banner_clearance = Vector2(0.0, vp.y * (0.09 if upright else 0.13) + 6.0)
			ads.test_safe_insets = Vector4(0.0, 0.0, vp.x * SHAPES[shape][1], 0.0)
			var where := "%s, %s" % [shape, "story" if base == STORY_BASE else "Endless"]
			for each in [["Remove Ads", "res://scenes/RemoveAdsScreen.gd"], ["Muse account", "res://scenes/MuseAccountScreen.gd"],
					["settings", "res://scenes/SettingsScreen.gd"], ["wardrobe", "res://scenes/WardrobeScreen.gd"],
					["privacy policy", "res://scripts/PrivacyTermsPopup.gd"], ["online's full today", "res://scenes/RoomFullPopup.gd"]]:
				var view := _view(vp)
				view.add_child(load(each[1]).new())
				await _frames(5)
				await _check_buttons(view, "%s: %s" % [where, each[0]])
				view.queue_free()
			if base == STORY_BASE:
				await _check_story(vp, where)
			else:
				await _check_game_over(vp, where)

	ads.test_banner_clearance = Vector2(-1.0, -1.0)
	ads.test_safe_insets = Vector4(-1.0, -1.0, -1.0, -1.0)
	mm.froggyCrown = real[0]
	mm.ads_removed = real[1]
	mm.unlocked_skins = real[2]
	mm.seen_cosmetics = real[3]
	mm.look_made = real[4]
	mm.wardrobe_path = real_wardrobe
	for f in [SCRATCH_SAVE, SCRATCH_WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	var now := FileAccess.get_file_as_bytes(real_wardrobe) if FileAccess.file_exists(real_wardrobe) else PackedByteArray()
	if now != real_bytes:
		var f := FileAccess.open(real_wardrobe, FileAccess.WRITE)
		f.store_buffer(real_bytes)
		f.close()
		_failures.append("the test wrote your real wardrobe save (put back as it was): find what saved it")
	if _measured < 100:
		_failures.append("only %d buttons measured: the menus didn't draw" % _measured)
	if _failures.is_empty():
		print("Button words test passed (%d buttons measured)." % _measured)
	else:
		for failure in _failures:
			push_warning("FAIL: " + failure)
		printerr("Button words test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## The story's title (its whole menu), pause menu and win screen, in the whole world.
func _check_story(vp: Vector2, where: String) -> void:
	var view := _view(vp)
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	var player: Node = main.get_node("Player")
	player.save_path = SCRATCH_SAVE
	view.add_child(main)
	await _frames(45)
	var title: CanvasLayer = player.get_node("titlescreen")
	var pause: CanvasLayer = player.get_node("PauseScreen")
	var win: CanvasLayer = player.get_node("winscreen")
	player._apply_ui_layout()
	title.visible = true
	await _frames(4)
	await _check_buttons(title, "%s: title" % where)
	title.visible = false
	pause.visible = true
	await _frames(4)
	await _check_buttons(pause, "%s: pause menu" % where)
	pause.visible = false
	player._apply_win_layout()
	win.visible = true
	win.get_node("thanksforplayingButton").visible = true
	for c in win.get_children():  # (just its button: the rest plays out over the credits)
		if c is CanvasItem and c.name != "thanksforplayingButton":
			c.visible = false
	await _frames(4)
	await _check_buttons(win, "%s: win screen" % where)
	view.queue_free()
	await _frames(3)


## Endless's game over, every button it can have.
func _check_game_over(vp: Vector2, where: String) -> void:
	var view := _view(vp)
	var endless: Node = load("res://scenes/EndlessMode.tscn").instantiate()
	var screen: CanvasLayer = endless.get_node("GameOverScreen")
	endless.remove_child(screen)
	var run := Node.new()  # (stands in for EndlessMode: a run that can be revived)
	var run_script := GDScript.new()
	run_script.source_code = "extends Node\nfunc can_revive() -> bool:\n\treturn true\nfunc revive() -> void:\n\tpass\n"
	run_script.reload()
	run.set_script(run_script)
	run.add_child(screen)
	view.add_child(run)
	screen.show_scores(12345, 67890, true)
	screen._apply_layout()
	await create_timer(0.8).timeout  # (it fades in)
	await _check_buttons(screen, "%s: game over" % where)
	view.queue_free()
	endless.free()
	await _frames(2)


## Every whole, visible button under node: its words, and its picture if it has one, measured where
## they're drawn; then again with capitals in place of its words.
func _check_buttons(node: Node, what: String) -> void:
	var buttons: Array[Button] = []
	_collect(node, buttons)
	if buttons.is_empty():
		_failures.append("%s: no buttons to measure" % what)
		return
	var words := {}
	var off := {}
	for b in buttons:
		words[b] = b.text
		off[b] = b.disabled
		b.disabled = false  # (a greyed-out one's face is see-through: same words, same place)
	var img := await _grab(node)
	for b in buttons:
		_measure(img, b, what, false)
	for b in buttons:
		b.text = "HH"  # (short: the "?" buttons are only a little wider than tall)
	img = await _grab(node)
	for b in buttons:
		_measure(img, b, what, true)
		b.text = words[b]
		b.disabled = off[b]


func _collect(node: Node, into: Array[Button]) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child.is_visible_in_tree():
			continue
		if child is Button and child.text != "" and _whole(child):
			into.append(child)
		_collect(child, into)


## Not cut off by the edge of a scroll box it's in.
func _whole(b: Control) -> bool:
	var n := b.get_parent()
	while n:
		if n is ScrollContainer:
			return (n as Control).get_global_rect().grow(0.5).encloses(b.get_global_rect())
		n = n.get_parent()
	return true


func _grab(node: Node) -> Image:
	await _frames(3)
	return node.get_viewport().get_texture().get_image()


## Where b's words (cream) are on its face (its fill colour), off the drawn pixels.
func _measure(img: Image, b: Button, what: String, capitals: bool) -> void:
	var xf: Transform2D = b.get_global_transform_with_canvas()
	var zoom := absf(xf.get_scale().y)
	var r := Rect2i((xf * Rect2(Vector2.ZERO, b.size)).abs())
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var box := b.get_theme_stylebox("disabled" if b.disabled else "normal") as StyleBoxFlat
	if box == null:
		_failures.append("%s: %s \"%s\" isn't dressed like the menus' buttons" % [what, b.name, b.text])
		return
	var cream: Color = b.get_theme_color("font_disabled_color" if b.disabled else "font_color")
	var pic := b.get_node_or_null("Picture") as Control
	var pic_rect := Rect2i()
	if pic and pic.visible:
		pic_rect = Rect2i((pic.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, pic.size)).abs())
	var face0 := Vector2i(99999, 99999)  # (its first and last pixels, both ways)
	var face1 := Vector2i(-1, -1)
	var ink0 := Vector2i(99999, 99999)
	var ink1 := Vector2i(-1, -1)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if _near(c, box.bg_color):
				face0 = face0.min(Vector2i(x, y))
				face1 = face1.max(Vector2i(x, y))
			elif _near(c, cream) and not pic_rect.has_point(Vector2i(x, y)):
				ink0 = ink0.min(Vector2i(x, y))
				ink1 = ink1.max(Vector2i(x, y))
	if face1.x < 0 or ink1.x < 0:
		_failures.append("%s: %s \"%s\": couldn't find its face or its words drawn" % [what, b.name, b.text])
		return
	var face_mid := Vector2(face0 + face1 + Vector2i.ONE) * 0.5
	var ink_rect := Rect2i(ink0, ink1 - ink0 + Vector2i.ONE)
	_measured += 1
	var off := Vector2(ink0 + ink1 + Vector2i.ONE) * 0.5 - face_mid
	var label := "%s: %s \"%s\" (at %s, face %s-%s, words %s-%s)" % [what, b.name, b.text,
		xf * Rect2(Vector2.ZERO, b.size), face0, face1, ink0, ink1]
	if capitals:
		if absf(off.y) > 0.5 * zoom + 0.01:
			_failures.append("%s: its words are %+.1f px off the middle of its face up and down" % [label, off.y])
		if absf(off.x) > 0.5 * zoom + 0.01:
			_failures.append("%s: capitals %+.1f px off the middle across" % [label, off.x])
	else:
		if absf(off.x) > 1.0 * zoom + 0.01:
			_failures.append("%s: its words are %+.1f px off the middle of its face across" % [label, off.x])
		if pic_rect.size != Vector2i.ZERO:
			var level := (pic_rect.position.y + pic_rect.end.y) * 0.5 - face_mid.y
			if absf(level) > 0.5 * zoom + 0.01:
				_failures.append("%s: its picture is %+.1f px off the middle of its face" % [label, level])
			if pic_rect.end.x > ink_rect.position.x - 4:
				_failures.append("%s: its picture runs into its words" % label)


## The very colour, to a step or so of 8-bit rounding (a worn wardrobe row's faint gold over the panel
## comes within 0.02 of the dark buttons' fill).
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.012 and absf(a.g - b.g) < 0.012 and absf(a.b - b.b) < 0.012


func _view(size: Vector2) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(size)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var bg := ColorRect.new()  # (a backdrop no button is coloured like)
	bg.color = Color(0.0, 0.0, 1.0)
	bg.size = size
	view.add_child(bg)
	return view


## The viewport a window gets with stretch mode "viewport" and aspect "expand" on base.
static func _viewport_for(window: Vector2, base: Vector2) -> Vector2:
	var aspect := window.x / window.y
	if aspect >= base.x / base.y:
		return Vector2(roundf(base.y * aspect), base.y)
	return Vector2(base.x, roundf(base.x / aspect))
