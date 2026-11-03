extends RefCounted
## The look of the menus built in code (wardrobe, game over, Remove Ads, Muse account) and the little
## notifications that drop in: dark wood panels with a gold edge and a soft shadow, chunky buttons with
## a lip that press down when tapped, and the fibberish pixel font with a thin dark outline. Load it
## lazily:
##   var ui: GDScript = load("res://scripts/UIStyle.gd")
## The font is drawn on a 16-pixel grid, so it's only ever used at 16, 32, 48... (px() picks the
## nearest): in between, its pixels come out uneven, some one wide and some two, and the words go lumpy.

const PX := 16  # the pixel font's grid
const CAP := 9  # its capitals' height, in its own pixels (it's 10 up and 4 down: the rest is room)
const LEAD := 1  # each letter starts this many of its pixels in from where it's put (none after the last)
const GOLD := Color(1.0, 0.86, 0.42)
const CREAM := Color(0.97, 0.92, 0.80)
const INK := Color(0.07, 0.04, 0.02)  # outlines
const EDGE := Color(0.86, 0.66, 0.30)  # the gold trim on panels

## Button colours: fill, hover fill, pressed fill, and the dark rim (with the lip under it).
const KINDS := {
	"wood": [Color(0.46, 0.31, 0.18), Color(0.56, 0.39, 0.23), Color(0.36, 0.24, 0.14), Color(0.17, 0.10, 0.05)],
	"go": [Color(0.30, 0.58, 0.28), Color(0.37, 0.68, 0.34), Color(0.23, 0.47, 0.22), Color(0.09, 0.23, 0.09)],
	"gold": [Color(0.84, 0.60, 0.19), Color(0.93, 0.70, 0.27), Color(0.70, 0.49, 0.14), Color(0.36, 0.22, 0.05)],
	"quiet": [Color(0.24, 0.17, 0.11), Color(0.32, 0.23, 0.15), Color(0.18, 0.12, 0.08), Color(0.10, 0.07, 0.04)],
	"danger": [Color(0.58, 0.19, 0.14), Color(0.68, 0.25, 0.18), Color(0.46, 0.13, 0.10), Color(0.24, 0.06, 0.04)],
}

## Little pictures for buttons, as rows of "#" (drawn white: the button's icon colours tint them).
const PERSON := ["...###...", "..#####..", "..#####..", "..#####..", "...###...", ".........", ".#######.",
	"#########", "#########"]
const GEAR := ["..#.#.#..", ".#######.", "#########", ".##...##.", "###...###", ".##...##.", "#########",
	".#######.", "..#.#.#.."]
const PARTY := ["..##...##..", ".####.####.", ".####.####.", "..##...##..", "...........", ".####.####.",
	"###########", "###########", "###########"]  # (two of us: PLAY TOGETHER)


static func font() -> Font:
	return load("res://assets/fibberish.ttf")


## The size to draw the pixel font at, near size: the nearest whole step of its grid (16 at least).
static func px(size: float) -> int:
	return maxi(PX, roundi(size / PX) * PX)


## Its outline at that size: one of the font's own pixels all round. (Thicker ones round off at the
## corners and blob the letters together.)
static func outline_px(size: int) -> int:
	return maxi(2, size / 8)


## A panel's box: dark wood, a gold edge, rounded corners and a shadow under it.
static func panel_box(radius := 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.13, 0.09, 0.06, 0.97)
	box.set_border_width_all(3)
	box.border_color = EDGE
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0.0, 5.0)
	return box


## Dresses btn as a chunky button of kind ("wood", "go" for the thing to do, "gold", "quiet"), its words
## about font_size big (px). It has a lip underneath, and pressed it sinks into it.
static func style_button(btn: Button, font_size: int, kind := "wood") -> void:
	font_size = px(font_size)
	var colours: Array = KINDS.get(kind, KINDS["wood"])
	var lip := lip_px(font_size)
	btn.add_theme_stylebox_override("normal", _button_box(colours[0], colours[3], lip, false, font_size))
	btn.add_theme_stylebox_override("hover", _button_box(colours[1], colours[3], lip, false, font_size))
	btn.add_theme_stylebox_override("pressed", _button_box(colours[2], colours[3], lip, true, font_size))
	btn.add_theme_stylebox_override("hover_pressed", _button_box(colours[2], colours[3], lip, true, font_size))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var off := _button_box(colours[0].darkened(0.35), colours[3], lip, false, font_size)
	off.bg_color.a = 0.75
	btn.add_theme_stylebox_override("disabled", off)
	btn.add_theme_font_override("font", font())
	btn.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(state, CREAM)
	btn.add_theme_color_override("font_disabled_color", CREAM.darkened(0.4))
	btn.add_theme_color_override("font_outline_color", INK)
	btn.add_theme_constant_override("outline_size", outline_px(font_size))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## A picture on btn, at the left end of its face, in a square as tall as the face; its words are the
## button's own text, so they sit in the very middle of it like any button's (next to the picture, as
## a pair in the middle, they came out off to one side). A pixel-art picture (pixel) is drawn at a
## whole multiple of its size in square pixels, a smooth one (the infinity sign, the crown) at the size
## it'll fit. It sinks with the words when the button's pressed. Again on the same button, it just
## updates.
static func button_face(btn: Button, texture: Texture2D, pixel: bool, words: String, font_size: int) -> void:
	font_size = px(font_size)
	btn.text = words
	var pic := btn.get_node_or_null("Picture") as TextureRect
	if pic == null:
		pic = TextureRect.new()
		pic.name = "Picture"
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(pic)
		btn.draw.connect(func() -> void: _place_picture(btn, pic))  # (each time the button's drawn)
	pic.texture = texture
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	var w := texture.get_width()
	var side: float = w * maxi(1, roundi(font_size * 0.9 / w)) if pixel else roundf(font_size * 0.9)
	pic.size = Vector2(side, side)
	pic.set_meta("lip", lip_px(font_size))
	btn.queue_redraw()


## Where a button's picture goes (button_face): its middle at the middle of the face's left-end
## square, and level with the words' middle. Pressed, the lip's gone and the face reaches down to the
## rim, words and all.
static func _place_picture(btn: Button, pic: TextureRect) -> void:
	var lip: int = pic.get_meta("lip", 3)
	var sunk := btn.get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
	var face := Rect2(2.0, 2.0, btn.size.x - 4.0, btn.size.y - 2.0 - (2.0 if sunk else float(lip)))
	var middle := Vector2(face.position.x + roundf(face.size.y * 0.5), face.get_center().y)
	pic.position = (middle - pic.size * 0.5).round()


## How thick a button's lip is, for its words' size.
static func lip_px(font_size: int) -> int:
	return maxi(3, roundi(font_size * 0.22))


## A picture drawn from rows of "#" (PERSON, GEAR), white.
static func pixel_icon(rows: Array) -> ImageTexture:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "#":
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


## A button's box. Its words go in the very middle of its face, above the lip: a button centres its
## line of words by the font's height (10 of its pixels up, 4 down), which left the capitals a little
## high on the face, and each letter starts a pixel of the font in, which left them a little right. The
## margins make up for both, in whole pixels (the button rounds where its words go down to one, so a
## half pixel more came out a whole one). Pressed, the words sink with the face.
static func _button_box(fill: Color, rim: Color, lip: int, pressed: bool, font_size: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(2)
	box.border_width_bottom = 2 if pressed else lip  # the lip
	box.set_corner_radius_all(6)
	var f := font()
	var k := float(font_size / PX)  # (the font's pixel, in the screen's)
	var lead := floorf(LEAD * k * 0.5)
	box.content_margin_left = 10.0 - lead
	box.content_margin_right = 10.0 + lead
	box.content_margin_top = 2.0 + (lip - 2 if pressed else 0)
	box.content_margin_bottom = maxf(0.0, lip + f.get_ascent(font_size) - f.get_descent(font_size) - CAP * k)
	return box


## A label in the menus' style: about font_size big (px), the colour, and an outline to match.
static func style_label(lbl: Label, font_size: int, colour := CREAM) -> void:
	font_size = px(font_size)
	lbl.add_theme_font_override("font", font())
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", colour)
	lbl.add_theme_color_override("font_outline_color", INK)
	lbl.add_theme_constant_override("outline_size", outline_px(font_size))


## A slot for an item's picture, size across: a little tile of light wood, so dark things show on it.
## Every slot is the same size, whatever its picture (they used to fit the picture, so a list of them
## came out ragged); the picture sits in the middle at a whole multiple of its own size, so its pixels
## stay square.
static func slot(icon: Control, size: float) -> PanelContainer:
	var margin := maxf(2.0, roundf(size * 0.1))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.42, 0.30, 0.19)
	box.border_color = Color(0.17, 0.10, 0.05)
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(margin)
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", box)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.custom_minimum_size = Vector2.ONE * size
	var inner := maxf(1.0, size - margin * 2.0)
	if icon is TextureRect and icon.texture:
		inner = pixel_size(icon.texture, inner)
	icon.custom_minimum_size = Vector2.ONE * inner
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(icon)
	return tile


## The size to show a pixel-art picture near target: a whole multiple of its own size (or a half or a
## quarter), so each of its pixels comes out the same size on screen.
static func pixel_size(texture: Texture2D, target: float) -> float:
	var own := float(maxi(texture.get_width(), texture.get_height()))
	var best := own * 0.25
	for k in [0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		if own * k <= target * 1.1:
			best = own * k
	return best


## A thin gold scroll bar.
static func style_scrollbar(bar: ScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	track.set_corner_radius_all(3)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	for state in ["scroll", "scroll_focus"]:
		bar.add_theme_stylebox_override(state, track)
	for state in [["grabber", 0.75], ["grabber_highlight", 0.95], ["grabber_pressed", 1.0]]:
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(EDGE, state[1])
		grab.set_corner_radius_all(3)
		grab.content_margin_left = 3.0
		grab.content_margin_right = 3.0
		bar.add_theme_stylebox_override(state[0], grab)


## A thin gold line, for between sections.
static func rule() -> HSeparator:
	var line := HSeparator.new()
	var box := StyleBoxLine.new()
	box.color = Color(EDGE, 0.55)
	box.thickness = 2
	line.add_theme_stylebox_override("separator", box)
	return line


## How many times as big a menu panel is drawn: twice upright on a phone, where the room's tall
## enough for it (an upright iPad's isn't: its settings came out a narrow strip), else 1:1.
static func panel_zoom(vp: Vector2, room: Rect2) -> float:
	return 2.0 if vp.y > vp.x * 1.3 and room.size.y >= 760.0 else 1.0


## Puts panel in the middle of the screen across and of room up and down (across(): it keeps clear of
## the notch), drawn zoom times as big (panel_zoom; a whole number, so with nearest filtering on the
## panel its pixels stay square) and share of the room's width across. Never shrunk to fit: the pixel
## font drops pixels and its words go to mush (sideways on a phone they did). If it's too tall, scroll
## (the ScrollContainer holding what's in it) is cut to fit and the rest scrolls, by a finger too.
static func fit_panel(panel: Control, scroll: ScrollContainer, room: Rect2, zoom: float, share: float) -> void:
	var s := maxf(1.0, floorf(zoom))
	var vp := panel.get_viewport_rect().size
	# (a whole number of pixels wide, so what's in it lands on whole pixels: words dead in the middle)
	panel.custom_minimum_size = Vector2(floorf(across(vp, room, room.size.x * share).y / s), 0)
	scroll.custom_minimum_size.y = (scroll.get_child(0) as Control).get_combined_minimum_size().y
	var need := panel.get_combined_minimum_size()
	var over := need.y * s - room.size.y * 0.94
	if over > 0.0:
		scroll.custom_minimum_size.y = maxf(0.0, scroll.custom_minimum_size.y - over / s)
		need = panel.get_combined_minimum_size()
	panel.size = need
	panel.scale = Vector2(s, s)
	var at := Rect2(Vector2((vp.x - need.x * s) / 2.0, room.position.y + (room.size.y - need.y * s) / 2.0), need * s)
	# (what's in it can need more than fits in the middle clear of a side strip: then it's in the middle
	# all the same, a little into the strip, as long as it's clear of the camera at the end of it; if not,
	# it keeps to the room)
	if (at.position.x < room.position.x or at.end.x > room.end.x) and at.intersects(camera_corner(vp, room)):
		at.position.x = clampf(at.position.x, room.position.x, maxf(room.position.x, room.end.x - at.size.x))
	panel.position = at.position.round()
	finger_scroll(scroll)


## The room a menu has on screen: in from the notch and the home indicator, and clear of the ad banners
## (they're drawn over the game, so nothing the game draws can cover them). With banner_to_come, the
## bottom banner's room is kept even before one's been asked for, wherever there are ads (the title's,
## from its very first frame: its banner's asked for a moment in, and turns up seconds after that).
static func room(vp: Vector2, banner_to_come := false) -> Rect2:
	var ads: Node = Engine.get_main_loop().root.get_node_or_null("AdsManager")
	var inset := Vector4.ZERO
	var top := 0.0
	var bottom := 0.0
	if ads:
		inset = ads.get_viewport_safe_insets()
		top = ads.get_viewport_top_banner_clearance()
		bottom = ads.get_viewport_bottom_banner_reserve() if banner_to_come else ads.get_viewport_bottom_banner_clearance()
	top = maxf(top, inset.y)
	bottom = maxf(bottom, inset.w)
	return Rect2(inset.x, top, vp.x - inset.x - inset.z, vp.y - top - bottom)


## Where something centred on the screen goes across, want wide at most, inside room: [its left edge,
## its width]. In the middle of the screen, not of the room: on an upright iPhone Duo the safe area
## stops short of a strip down one side (its camera's at the top of it), and centred in the room every
## menu sat off to the other side. It keeps out of the strip all the same, so nothing tall reaches the
## camera.
static func across(vp: Vector2, room: Rect2, want: float) -> Vector2:
	var mid := vp.x * 0.5
	var w := maxf(0.0, minf(want, 2.0 * minf(mid - room.position.x, room.end.x - mid)))
	return Vector2(mid - w * 0.5, w)


## The camera's end of a side strip (across()): the safe area stops short of it all the way down, but
## it's only the top of it, the camera, that's ever in the way; taken as a square as deep as the strip
## is wide. Empty where the safe area's even both sides.
static func camera_corner(vp: Vector2, room: Rect2) -> Rect2:
	var left := room.position.x
	var right := vp.x - room.end.x
	var w := absf(left - right)
	if w < 1.0:
		return Rect2()
	return Rect2(0.0 if left > right else vp.x - w, 0.0, w, w)


## The title screen's spots, worked out here so the loading screen (BootLoader.gd) can put its logo
## exactly where the title's will be, and the title fills in around it: "logo" (its middle) and
## "logo_scale"; "byline_size" and "byline_gap" ("made by muse": its size, and how far up from the
## screen's bottom edge it sits); "floor" (how far down the menu may come: just over "made by muse");
## and "room". The bottom banner's room is kept from the very first frame wherever there are ads
## (room(vp, true)), so nothing moves when the banner turns up, seconds in.
static func title_spots(vp: Vector2) -> Dictionary:
	var portrait := vp.y > vp.x * 1.3
	var r := room(vp, true)
	var ads: Node = Engine.get_main_loop().root.get_node_or_null("AdsManager")
	var banner: float = ads.get_viewport_bottom_banner_reserve() if ads else 0.0
	var size := 32 if portrait else 16
	# (just over the banner, sideways tucked a little into its breathing room; with none, just over the
	# screen's edge and the home indicator)
	var gap: float = banner - (0.0 if portrait else 6.0) if banner > 0.0 \
		else (ads.get_viewport_bottom_safe_inset() if ads else 0.0) + 3.0
	var floor_y := vp.y - gap - (font().get_height(size) + outline_px(size)) - 8.0
	var logo := Vector2(vp.x * 0.5, r.position.y + 375.0 * 0.25 + vp.y * 0.06) if portrait \
		else Vector2(vp.x * 0.29, (r.position.y + floor_y) * 0.5)
	return {"logo": logo, "logo_scale": 0.5 if portrait else 0.3, "byline_size": size,
		"byline_gap": gap, "floor": floor_y, "room": r}


## Lets a finger slide what's in scroll up and down from anywhere on it, buttons and all: they pass the
## touch on to it as well as taking it (a slide that's started on a button doesn't press it). Only its
## bar moved it before: the wardrobe's rows and buttons kept every touch to themselves. Again after
## what's in it changes. (Text boxes keep theirs, for picking where to type.)
static func finger_scroll(scroll: ScrollContainer) -> void:
	scroll.scroll_deadzone = 6  # (how far a finger goes before it's a slide, not a tap)
	_pass_touches(scroll)


static func _pass_touches(node: Node) -> void:
	for child in node.get_children():
		if child is Control and child.mouse_filter == Control.MOUSE_FILTER_STOP \
				and not (child is LineEdit or child is TextEdit):
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_pass_touches(child)
