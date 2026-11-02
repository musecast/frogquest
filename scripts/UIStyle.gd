extends RefCounted
## The look of the menus built in code (wardrobe, game over, Remove Ads, Muse account) and the little
## notifications that drop in: dark wood panels with a gold edge and a soft shadow, chunky buttons with
## a lip that press down when tapped, and the fibberish pixel font with a thin dark outline. Load it
## lazily:
##   var ui: GDScript = load("res://scripts/UIStyle.gd")
## The font is drawn on a 16-pixel grid, so it's only ever used at 16, 32, 48... (px() picks the
## nearest): in between, its pixels come out uneven, some one wide and some two, and the words go lumpy.

const PX := 16  # the pixel font's grid
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
}


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
	var lip := maxi(3, roundi(font_size * 0.22))
	btn.add_theme_stylebox_override("normal", _button_box(colours[0], colours[3], lip, false))
	btn.add_theme_stylebox_override("hover", _button_box(colours[1], colours[3], lip, false))
	btn.add_theme_stylebox_override("pressed", _button_box(colours[2], colours[3], lip, true))
	btn.add_theme_stylebox_override("hover_pressed", _button_box(colours[2], colours[3], lip, true))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var off := _button_box(colours[0].darkened(0.35), colours[3], lip, false)
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


static func _button_box(fill: Color, rim: Color, lip: int, pressed: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(2)
	box.border_width_bottom = 2 if pressed else lip  # the lip
	box.set_corner_radius_all(6)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 2.0 + (lip - 2 if pressed else 0)  # (the words sink with it)
	box.content_margin_bottom = 2.0
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


## Puts panel in the middle of room at the biggest whole size up to zoom that fits (2 upright on a
## phone, so it isn't tiny), and never below 1:1: shrunk, the pixel font drops pixels and its words go
## to mush (sideways on a phone they did). If it's too tall for the room even at 1:1, scroll (the
## ScrollContainer holding what's in it) is cut to fit and the rest scrolls. Nearest filtering on the
## panel keeps 2x square. Returns the size it's drawn at.
static func fit_panel(panel: Control, scroll: ScrollContainer, room: Rect2, zoom: float) -> float:
	var content := scroll.get_child(0) as Control
	scroll.custom_minimum_size.y = content.get_combined_minimum_size().y
	var need := panel.get_combined_minimum_size()
	var s := clampf(floorf(minf(zoom, minf(room.size.x * 0.96 / need.x, room.size.y * 0.94 / need.y))), 1.0, maxf(1.0, zoom))
	var over := need.y * s - room.size.y * 0.94
	if over > 0.0:
		scroll.custom_minimum_size.y = maxf(0.0, scroll.custom_minimum_size.y - over / s)
		need = panel.get_combined_minimum_size()
	panel.size = need
	panel.scale = Vector2(s, s)
	panel.position = (room.position + (room.size - need * s) / 2.0).round()
	return s


## The room a menu has on screen: in from the notch and the home indicator, and clear of the ad banners
## (they're drawn over the game, so nothing the game draws can cover them).
static func room(vp: Vector2) -> Rect2:
	var ads: Node = Engine.get_main_loop().root.get_node_or_null("AdsManager")
	var inset := Vector4.ZERO
	var top := 0.0
	var bottom := 0.0
	if ads:
		inset = ads.get_viewport_safe_insets()
		top = ads.get_viewport_top_banner_clearance()
		bottom = ads.get_viewport_bottom_banner_clearance()
	top = maxf(top, inset.y)
	bottom = maxf(bottom, inset.w)
	return Rect2(inset.x, top, vp.x - inset.x - inset.z, vp.y - top - bottom)
