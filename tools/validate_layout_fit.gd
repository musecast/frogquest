extends SceneTree
## Headless check that the menus fit every screen shape the game meets (phones, foldables, iPads and
## computers, upright and sideways): the Endless game over screen with every button it can have,
## squeezed between both banners; the story's title screen (its whole menu), pause menu, settings
## from both and the delete-everything question (in the whole world, over the bottom banner); the
## Remove Ads, Muse account, settings, privacy policy and wardrobe screens (with every hat and skin)
## between both banners, since the ads draw over everything (a banner over the privacy policy's Close
## left no way out); and the notifications that drop in. Nothing may hang off the screen or sit under a banner, and the pixel
## font's words must be crisp (whole steps of its grid, 1:1, a one-pixel outline). The menus sit in the
## middle of the screen across, even beside an upright iPhone Duo's side strip (and clear of it); a
## finger slides their lists from anywhere on them; and nothing on the title moves when its banner's
## asked for or turns up, its logo just where the loading screen put its own. Each screen is laid
## out in a SubViewport the size the game's stretch settings (viewport, expand) would give that window.
## The story climb saves to scratch files meanwhile, so yours is never touched.
##   Godot --headless --path . --script res://tools/validate_layout_fit.gd

const PIXEL_FONT := "res://assets/fibberish.ttf"
const ENDLESS_BASE := Vector2(320, 180)  # EndlessMode.gd's content_scale_size
const STORY_BASE := Vector2(480, 270)  # player.gd's
const WINDOWS := {  # window sizes, in points
	"phone upright": Vector2(390, 844),
	"phone sideways": Vector2(844, 390),
	"tall phone": Vector2(360, 800),
	"small phone sideways": Vector2(667, 375),
	"foldable inner upright": Vector2(1407, 2000),
	"foldable inner sideways": Vector2(2000, 1407),
	"iPad upright": Vector2(1024, 1366),
	"iPad sideways": Vector2(1366, 1024),
	"square": Vector2(1000, 1000),
	"computer": Vector2(1280, 720),
	"ultrawide": Vector2(2560, 1080),
	"iPhone Duo upright": Vector2(1375, 2000),
}
## Screens whose safe area stops short of a strip down one side (a share of the width): an upright
## iPhone Duo's, its camera at the top of it. Menus go in the middle of the screen all the same, clear
## of the strip.
const STRIPS := {"iPhone Duo upright": 0.18}
const LONG_EMAIL := "someone.with.a.really.long.name@example.com"
const SCRATCH_SAVE := "user://test_layout_save_game.save"
const SCRATCH_WARDROBE := "user://test_layout_wardrobe.save"

var _failures: Array[String] = []
var _checked := 0  # buttons, labels and text boxes looked at
var _script_errors := ScriptErrors.new()
var _strip := 0.0  # (the screen shape being checked: its side strip, a share of the width)
var _camera := Rect2()  # (and the camera at the top of it, which nothing may be under)


## Script errors while it runs, any at all: a player.gd that didn't parse once left the story's
## menus unchecked, and the test said it passed.
class ScriptErrors extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


func _initialize() -> void:
	OS.add_logger(_script_errors)
	_run.call_deferred()


func _run() -> void:
	var mm := root.get_node("MusicManager")
	var acct := root.get_node("MuseAccount")
	# Nothing here may write your wardrobe (opening the wardrobe marks things seen and saves): it saves
	# to a scratch file, and if your real one changes anyway, it's put back and the test fails.
	var real_wardrobe: String = mm.wardrobe_path
	var real_bytes := FileAccess.get_file_as_bytes(real_wardrobe) if FileAccess.file_exists(real_wardrobe) else PackedByteArray()
	mm.wardrobe_path = SCRATCH_WARDROBE
	# Every button there can be: a crown (so the wardrobe button shows), and ads not removed.
	var real_crown: int = mm.froggyCrown
	var real_ads_removed: bool = mm.ads_removed
	var real_unlocked: Array = mm.unlocked_skins.duplicate()
	var real_seen: Array = mm.seen_cosmetics.duplicate()
	mm.froggyCrown = 1
	mm.ads_removed = false
	for id in load("res://scenes/WardrobeScreen.gd").ITEMS:
		if id != "froggycrown" and id not in mm.unlocked_skins:
			mm.unlocked_skins.append(id)  # (the fullest wardrobe; in memory only, never saved)
	var signed_in := func(_screen: Node) -> void:
		acct.email = LONG_EMAIL
		acct._refresh_token = "test"
		acct._pro = true
		acct._pro_checked_at = acct._now()
	var code_sent := func(screen: Node) -> void:
		screen._sent_to = LONG_EMAIL
		screen._mode = "code"
		screen._show_state()
	var typing_email := func(screen: Node) -> void:
		screen._mode = "email"
		screen._show_state()
	var linking := func(screen: Node) -> void:  # (waiting on Muse Shelf, its code shown big)
		acct.linking = {"code": "WWWW-WWWW", "secret": "test", "approve_url": "https://example.com", "app_url": ""}
		screen._mode = "link"
		screen._show_state()
	var linking_opened_app := func(screen: Node) -> void:  # (back from a Muse Shelf that didn't show it)
		acct.linking = {"code": "WWWW-WWWW", "secret": "test", "approve_url": "https://example.com",
			"app_url": "jasonmuse-mediatracker://link?code=WWWW-WWWW", "opened_app": true}
		screen._mode = "link"
		screen._show_state()
	var real_session := [acct.email, acct._refresh_token, acct._pro, acct._pro_checked_at]

	for shape in WINDOWS:
		var window: Vector2 = WINDOWS[shape]
		_strip = STRIPS.get(shape, 0.0)
		var endless_vp := _viewport_for(window, ENDLESS_BASE)
		var story_vp := _viewport_for(window, STORY_BASE)
		var up := window.y > window.x
		await _check_game_over(shape, endless_vp, up)
		await _check_panel("%s, story: Remove Ads" % shape, load("res://scenes/RemoveAdsScreen.gd"), story_vp, up)
		await _check_panel("%s, Endless: Remove Ads" % shape, load("res://scenes/RemoveAdsScreen.gd"), endless_vp, up)
		await _check_panel("%s, story: wardrobe" % shape, load("res://scenes/WardrobeScreen.gd"), story_vp, up)
		await _check_panel("%s, Endless: wardrobe" % shape, load("res://scenes/WardrobeScreen.gd"), endless_vp, up)
		var muse: GDScript = load("res://scenes/MuseAccountScreen.gd")
		await _check_panel("%s: Muse account" % shape, muse, story_vp, up)
		await _check_panel("%s, Endless: Muse account" % shape, muse, endless_vp, up)
		await _check_panel("%s: Muse account, typing an email" % shape, muse, story_vp, up, typing_email)
		await _check_panel("%s: Muse account, code sent" % shape, muse, story_vp, up, code_sent)
		await _check_panel("%s: Muse account, waiting on Muse Shelf" % shape, muse, story_vp, up, linking)
		await _check_panel("%s, Endless: Muse account, waiting on Muse Shelf" % shape, muse, endless_vp, up, linking)
		await _check_panel("%s: Muse account, offering the website" % shape, muse, story_vp, up, linking_opened_app)
		await _check_panel("%s, Endless: Muse account, offering the website" % shape, muse, endless_vp, up, linking_opened_app)
		acct.linking = {}
		await _check_panel("%s: Muse account, signed in" % shape, muse, story_vp, up, signed_in)
		await _check_toast("%s, story" % shape, story_vp, up)
		await _check_toast("%s, Endless" % shape, endless_vp, up)
		await _check_panel("%s: settings" % shape, load("res://scenes/SettingsScreen.gd"), story_vp, up)
		var popup: GDScript = load("res://scripts/PrivacyTermsPopup.gd")
		await _check_panel("%s, story: privacy policy" % shape, popup, story_vp, up)
		await _check_panel("%s, Endless: privacy policy" % shape, popup, endless_vp, up)
		acct.email = real_session[0]
		acct._refresh_token = real_session[1]
		acct._pro = real_session[2]
		acct._pro_checked_at = real_session[3]
	await _check_story_menus()

	mm.froggyCrown = real_crown
	mm.ads_removed = real_ads_removed
	mm.unlocked_skins = real_unlocked
	mm.seen_cosmetics = real_seen
	mm.wardrobe_path = real_wardrobe
	if FileAccess.file_exists(SCRATCH_WARDROBE):
		DirAccess.remove_absolute(SCRATCH_WARDROBE)
	var now := FileAccess.get_file_as_bytes(real_wardrobe) if FileAccess.file_exists(real_wardrobe) else PackedByteArray()
	if now != real_bytes:
		var f := FileAccess.open(real_wardrobe, FileAccess.WRITE)
		f.store_buffer(real_bytes)
		f.close()
		_failures.append("the test wrote your real wardrobe save (put back as it was): find what saved it")
	root.get_node("AdsManager").test_banner_clearance = Vector2(-1.0, -1.0)
	root.get_node("AdsManager").test_safe_insets = Vector4(-1.0, -1.0, -1.0, -1.0)
	for _i in 3:
		await process_frame
	for e in _script_errors.errors:
		_failures.append("script error: " + e)
	if _failures.is_empty():
		print("Layout fit test passed (%d screen shapes, %d buttons and labels)." % [WINDOWS.size(), _checked])
	else:
		for failure in _failures:
			push_warning("FAIL: " + failure)
		printerr("Layout fit test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## The game over screen as it is at its fullest: a new best with a big score, "keep going (watch
## ad)", the wardrobe crown and Remove Ads, with a banner at the top and the bottom.
func _check_game_over(shape: String, vp: Vector2, upright: bool) -> void:
	var banner := _banner_height(vp, upright)
	root.get_node("AdsManager").test_banner_clearance = Vector2(banner + 6.0, banner + 6.0)
	var room := _room(vp, banner, banner)
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
	var box: VBoxContainer = screen.get_node("MarginContainer")
	var keep_going: Button = box.get_node_or_null("KeepGoingButton")
	if keep_going == null:
		keep_going = Button.new()
		keep_going.name = "KeepGoingButton"
		keep_going.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(keep_going)
		box.move_child(keep_going, box.get_node("TryAgainButton").get_index())
	keep_going.text = "KEEP GOING (WATCH AD)"  # (the long one, as on a phone with ads)
	if box.get_node_or_null("RemoveAdsButton") == null:
		var remove_ads := Button.new()
		remove_ads.name = "RemoveAdsButton"
		remove_ads.text = "Remove Ads"
		remove_ads.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(remove_ads)
		box.move_child(remove_ads, box.get_node("BottomRow").get_index() + 1)
	screen._apply_layout()
	for _i in 3:
		await process_frame
	_check_inside(box, room, "%s: game over" % shape)
	if absf(box.get_global_rect().get_center().x - vp.x * 0.5) > 1.0:
		_failures.append("%s: game over: its column isn't in the middle of the screen" % shape)
	view.queue_free()
	endless.free()
	await process_frame


## The story's menus, in the whole world (Main.tscn) as the game has them, at every shape, with its
## bottom banner up.
func _check_story_menus() -> void:
	var ads := root.get_node("AdsManager")
	var view := _view(_viewport_for(WINDOWS["computer"], STORY_BASE))
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	var player: Node = main.get_node("Player")
	player.save_path = SCRATCH_SAVE
	view.add_child(main)
	await _frames(45)  # (the title gets laid out after half a second)
	var title: CanvasLayer = player.get_node("titlescreen")
	var pause: CanvasLayer = player.get_node("PauseScreen")
	for shape in WINDOWS:
		var window: Vector2 = WINDOWS[shape]
		_strip = STRIPS.get(shape, 0.0)
		var vp := _viewport_for(window, STORY_BASE)
		var banner := _banner_height(vp, window.y > window.x)
		ads.test_banner_clearance = Vector2(0.0, banner + 6.0)  # (AdsManager adds 6 of breathing room)
		var room := _room(vp, 0.0, banner)
		# (paused with the screen wider than tall, the game takes the banner down)
		var pause_room := room if vp.x < vp.y else _room(vp, 0.0, 0.0)
		view.size = Vector2i(vp)
		pause.visible = false
		title.visible = true
		player._apply_ui_layout()
		await _frames(3)
		_check_inside(title, room, "%s: title screen" % shape)
		await _expect_title_steady(player, vp, shape)
		var menu: Control = title.get_node("TitleMenu")
		for button in ["PlayButton", "EndlessButton", "WardrobeButton", "MuseButton", "SettingsButton"]:
			if not menu.get_node(button).visible:
				_failures.append("%s: the title's %s isn't showing" % [shape, button])
		var settings: CanvasLayer = player._open_settings()  # (from the title)
		await _frames(4)
		_check_inside(settings, room, "%s: settings from the title" % shape)
		settings._ask_first("all")  # (only asks; nothing's deleted unless YES)
		await _frames(4)
		_check_inside(settings, room, "%s: delete all data?" % shape)
		settings.closed.emit()
		title.visible = false
		pause.visible = true  # (lays itself out)
		await _frames(3)
		_check_inside(pause, pause_room, "%s: pause menu" % shape)
		if (pause.get_node("RestartButton") as Button).text != "MAIN MENU":
			_failures.append("%s: the pause menu's way back to the title doesn't say MAIN MENU" % shape)
		player._on_settings_button_pressed()
		await _frames(4)
		settings = player.get_node_or_null("SettingsScreen")
		if settings == null:
			_failures.append("%s: SETTINGS in the pause menu opened nothing" % shape)
		else:
			_check_inside(settings, room, "%s: settings from the pause menu" % shape)
			settings.closed.emit()
		await _frames(2)
	pause.visible = false
	ads.test_banner_clearance = Vector2(-1.0, -1.0)
	view.queue_free()
	await _frames(3)
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(SCRATCH_SAVE)


## Nothing on the title moves when its banner's asked for, or when it turns up (its room's kept from
## the very first frame: the menu and "made by muse" jumped as the ad came in), and the loading screen
## puts its logo just where the title's is (it had drifted, and the logo jumped up as the title came).
func _expect_title_steady(player: Node, vp: Vector2, shape: String) -> void:
	var ads := root.get_node("AdsManager")
	var title: CanvasLayer = player.get_node("titlescreen")
	var real := [ads.test_banner_clearance, ads._ads_active, ads._banner_show_bottom,
		ads._native_bottom_banner_loaded, title.visible]
	ads.test_banner_clearance = Vector2(-1.0, -1.0)  # (AdsManager's own reckoning, a phone's with ads)
	ads._ads_active = true
	title.visible = false  # (so it's placed straight there, not in a glide)
	var seen := []
	for state in [[false, false], [true, false], [true, true]]:  # (asked for yet, turned up yet)
		ads._banner_show_bottom = state[0]
		ads._native_bottom_banner_loaded = state[1]
		player._apply_ui_layout()
		await _frames(2)
		var menu: Control = title.get_node("TitleMenu")
		seen.append([title.get_node("Title").position, menu.position, menu.size, title.get_node("by muse").offset_top])
	if seen[1] != seen[0] or seen[2] != seen[0]:
		_failures.append("%s: the title moves as its banner's asked for and turns up: %s" % [shape, seen])
	var spot: Vector2 = load("res://scripts/UIStyle.gd").title_spots(vp).logo
	if not spot.is_equal_approx(title.get_node("Title").position):
		_failures.append("%s: the loading screen puts its logo at %s, the title at %s" % [shape, spot,
			title.get_node("Title").position])
	ads.test_banner_clearance = real[0]
	ads._ads_active = real[1]
	ads._banner_show_bottom = real[2]
	ads._native_bottom_banner_loaded = real[3]
	title.visible = real[4]
	player._apply_ui_layout()
	await _frames(2)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame


func _check_panel(what: String, script: GDScript, vp: Vector2, upright: bool, prepare := Callable()) -> void:
	var banner := _banner_height(vp, upright)
	root.get_node("AdsManager").test_banner_clearance = Vector2(banner + 6.0, banner + 6.0)
	var room := _room(vp, banner, banner)
	var view := _view(vp)
	var screen: CanvasLayer = script.new()
	view.add_child(screen)
	if prepare.is_valid():
		prepare.call(screen)
		if screen.has_method("_show_state"):
			screen._show_state()
	for _i in 4:
		await process_frame
	_check_inside(screen, room, what)
	_expect_centred(screen, vp, what)
	_expect_finger_scroll(screen, what)
	view.queue_free()
	await process_frame


## The room on a screen of the shape being checked, clear of banners top and bottom this tall. If it
## has a side strip, AdsManager's safe area is set to stop short of it, and nothing may be under the
## camera at the top end of it (_camera, UIStyle.camera_corner); the rest of the strip's clear.
func _room(vp: Vector2, top_banner: float, bottom_banner: float) -> Rect2:
	var inset := Vector4(0.0, 0.0, vp.x * _strip, 0.0)
	root.get_node("AdsManager").test_safe_insets = inset
	var strip := vp.x * _strip
	_camera = Rect2(vp.x - strip, 0.0, strip, strip) if strip > 0.0 else Rect2()
	return Rect2(0.0, top_banner, vp.x, vp.y - top_banner - bottom_banner)


## The menu's panel (the biggest one on its screen) is in the middle of the screen across, side strip
## or not: on an upright iPhone Duo every menu sat off to one side, centred in the room left of its
## strip.
func _expect_centred(screen: Node, vp: Vector2, what: String) -> void:
	var panel: Control = null
	for child in screen.get_children():
		if (child is Panel or child is PanelContainer) and child.visible:
			if panel == null or child.get_global_rect().get_area() > panel.get_global_rect().get_area():
				panel = child
	if panel == null:
		_failures.append("%s: no panel to check" % what)
		return
	var r := panel.get_global_rect()
	if absf(r.get_center().x - vp.x * 0.5) > 1.0:
		_failures.append("%s: its panel's middle is at %.1f, not the screen's %.1f" % [what, r.get_center().x, vp.x * 0.5])
	if r.intersects(_camera):
		_failures.append("%s: its panel at %s is under the camera at the top of the side strip" % [what, r])


## Everything in a scroll box lets a finger slide it from anywhere (UIStyle.finger_scroll): in the
## wardrobe the rows and their buttons kept every touch, and only the bar moved the list.
func _expect_finger_scroll(node: Node, what: String) -> void:
	for scroll in node.find_children("*", "ScrollContainer", true, false):
		if not (scroll as ScrollContainer).is_visible_in_tree():
			continue
		if scroll.scroll_deadzone <= 0:
			_failures.append("%s: its scroll box has no dead zone: a tap that wobbles would scroll instead" % what)
		for c in scroll.find_children("*", "Control", true, false):
			if c.mouse_filter == Control.MOUSE_FILTER_STOP and not (c is LineEdit or c is TextEdit or c is ScrollBar):
				_failures.append("%s: %s \"%s\" keeps a finger's touch to itself: the list won't slide under it" % [
					what, c.name, str(c.get("text")).left(24)])
				return


## The widest notification there is (a picture, a long title and a second line), once it's dropped in,
## between both banners.
func _check_toast(what: String, vp: Vector2, upright: bool) -> void:
	var mm := root.get_node("MusicManager")
	var banner := _banner_height(vp, upright)
	root.get_node("AdsManager").test_banner_clearance = Vector2(banner + 6.0, banner + 6.0)
	var view := _view(vp)
	mm.toast_host = view
	var room := _room(vp, banner, banner)
	mm.show_unlock_notification("hat", "blackcrown")
	await create_timer(0.75).timeout
	_check_inside(view, room, "%s: notification" % what)
	for layer in view.get_children():
		if layer is CanvasLayer:
			_expect_centred(layer, vp, "%s: notification" % what)
	view.queue_free()
	mm.toast_host = null
	mm._toasts.clear()
	mm._toast_up = false  # (its card went with the view)
	await process_frame


## _expect_inside, and there was something to check (an empty screen would pass otherwise).
func _check_inside(node: Node, room: Rect2, what: String) -> void:
	var before := _checked
	_expect_inside(node, room, what)
	if _checked == before:
		_failures.append("%s: nothing on screen to check" % what)


## Every visible button and text box, and every label's words, under node lie inside room (a scroll
## box counts as one: what scrolls inside it may go past its edges). 2 pixels of give, for the menus
## that wobble.
func _expect_inside(node: Node, room: Rect2, what: String) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child.visible:
			continue
		if child is Control and (child is BaseButton or child is Label or child is LineEdit or child is ScrollContainer):
			_checked += 1
			if not _expect_crisp(child, what):
				return
			var r: Rect2 = _words_rect(child) if child is Label else child.get_global_rect()
			if not room.grow(2.0).encloses(r):
				_failures.append("%s: %s \"%s\" at %s is outside %s" % [what, child.name,
					str(child.get("text")).left(24).replace("\n", " "), r, room])
				return
			if r.intersects(_camera):
				_failures.append("%s: %s \"%s\" at %s is under the camera at the top of the side strip" % [
					what, child.name, str(child.get("text")).left(24).replace("\n", " "), r])
				return
			if _cut_off(child):
				_failures.append("%s: %s \"%s\" doesn't fit its %.0f px: its words are cut off" % [what,
					child.name, str(child.get("text")).left(24).replace("\n", " "), child.size.x])
				return
			if child is ScrollContainer:
				_expect_words_fit(child, what)  # (what scrolls may go past the edges, but not past its own box)
				continue
		_expect_inside(child, room, what)


## Every visible label and button under node has room for its words, crisp ones.
func _expect_words_fit(node: Node, what: String) -> void:
	for child in node.get_children():
		if child is CanvasItem and not child.visible:
			continue
		if child is BaseButton or child is Label or child is LineEdit:
			_checked += 1
		if child is Control and _cut_off(child):
			_failures.append("%s: %s \"%s\" doesn't fit its %.0f px: its words are cut off" % [what,
				child.name, str(child.get("text")).left(24).replace("\n", " "), child.size.x])
			return
		if child is Control and not _expect_crisp(child, what):
			return
		_expect_words_fit(child, what)


## The pixel font only at whole steps of its 16-pixel grid (UIStyle.px), drawn 1:1 (or blown up a
## whole number of times, square: nearest filtering), with a one-pixel outline (UIStyle.outline_px)
## or none: anything else and its pixels come out uneven, some one wide and some two, and the words
## look lumpy (they did, in the wardrobe on an iPad; shrunk, sideways on a phone, they went to mush).
## False if not.
func _expect_crisp(c: Control, what: String) -> bool:
	if not (c is Label or c is Button or c is LineEdit):
		return true
	var words := str(c.get("text")) + (str(c.placeholder_text) if c is LineEdit else "")
	if words.strip_edges() == "":
		return true
	var font: Font = c.get_theme_font("font")
	if font is FontVariation:
		font = font.base_font
	if font == null or font.resource_path != PIXEL_FONT:
		return true
	var size: int = c.get_theme_font_size("font_size")
	var scale: Vector2 = c.get_global_transform_with_canvas().get_scale()
	var outline: int = c.get_theme_constant("outline_size")
	var label := "%s: %s \"%s\"" % [what, c.name, words.left(24).replace("\n", " ")]
	var k := absf(scale.y)
	var square := absf(absf(scale.x) - k) < 0.001 and absf(k - roundf(k)) < 0.001 and k > 0.999
	if size % 16 != 0 or not square or (k > 1.001 and not _draws_nearest(c)):
		_failures.append("%s draws the pixel font at %d x %.3f: whole steps of 16, 1:1 (or whole times, square), only" % [label, size, scale.y])
		return false
	if outline != 0 and outline != size / 8:
		_failures.append("%s has a %d outline at size %d: one font pixel (%d) or none" % [label, outline, size, size / 8])
		return false
	return true


## Whether c is drawn with nearest filtering (its own, a parent's, or the viewport's default).
static func _draws_nearest(c: CanvasItem) -> bool:
	var n: Node = c
	while n is CanvasItem:
		if n.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return n.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		n = n.get_parent()
	return c.get_viewport().canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST


## A label or button whose words are wider than it is: clip_text cuts them off without a sound (the
## wardrobe's names came out "Frog" and "Wiz |" on a phone, all inside the screen).
func _cut_off(c: Control) -> bool:
	if not (c is Label or c is Button) or not c.get("clip_text"):
		return false
	var text := str(c.get("text"))
	if text == "" or (c is Label and c.autowrap_mode != TextServer.AUTOWRAP_OFF):
		return false
	var words: float = c.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		c.get_theme_font_size("font_size")).x
	var room: float = c.size.x
	if c is Button:
		var box: StyleBox = c.get_theme_stylebox("normal")
		room -= box.get_margin(SIDE_LEFT) + box.get_margin(SIDE_RIGHT)
	return words > room + 1.0


## Where a label's words are: its box can be far wider than they are, with them anywhere in it.
func _words_rect(label: Label) -> Rect2:
	var r := label.get_global_rect()
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return r
	var words := label.get_minimum_size() * label.get_global_transform().get_scale()
	words = Vector2(minf(words.x, r.size.x), minf(words.y, r.size.y))
	var x: float = r.position.x + (r.size.x - words.x) * [0.0, 0.5, 1.0, 0.0][label.horizontal_alignment]
	var y: float = r.position.y + (r.size.y - words.y) * [0.0, 0.5, 1.0, 0.0][label.vertical_alignment]
	return Rect2(x, y, words.x, words.y)


## A banner's height in viewport pixels: adaptive banners are about 50 points tall (90 on an iPad).
static func _banner_height(vp: Vector2, upright: bool) -> float:
	return vp.y * (0.09 if upright else 0.13)


func _view(size: Vector2) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(size)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(view)
	return view


## The viewport a window gets with stretch mode "viewport" and aspect "expand" on base.
static func _viewport_for(window: Vector2, base: Vector2) -> Vector2:
	var aspect := window.x / window.y
	if aspect >= base.x / base.y:
		return Vector2(roundf(base.y * aspect), base.y)
	return Vector2(base.x, roundf(base.x / aspect))
