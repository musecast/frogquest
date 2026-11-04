extends Node
## The phone's keyboard, for a screen you type on (Friends, Muse Account, Play Together, Remove Ads),
## added to it as a child. An iPhone's keyboard has no key to put it away, and Return does what the box
## is for, so a tap anywhere off the box you're typing in puts it away, as the finger comes up (a tap on
## a button still presses it). And height_for() tells the screen how tall the keyboard is, to lift what
## you're typing above it: kept after the typing ends until the keyboard's gone and no finger's down, so
## a button tapped then (it takes the box's focus as the finger lands) doesn't drop out from under it.

var height_source := _real_height  # (a test's pretend keyboard goes here instead)
var finger_down := false  # a finger (or the mouse button) on the screen

var _from_off_box := false  # (the finger came down off the box being typed in)
var _lifting := false  # (the box was being typed in, and the keyboard isn't gone yet)
var _height := 0.0  # (how tall the keyboard was while you typed)


func _input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton  # (a finger comes as the mouse too)
	if tap == null or tap.button_index != MOUSE_BUTTON_LEFT:
		return
	finger_down = tap.pressed
	var box := get_viewport().gui_get_focus_owner() as LineEdit
	var off_box := box != null and box.is_editing() and not _over(box, tap.position)
	if tap.pressed:
		_from_off_box = off_box
	elif _from_off_box:
		_from_off_box = false
		if off_box:
			box.release_focus()  # (and the keyboard goes)


## How tall the keyboard is, in the window's pixels, for lifting box (the screen's text box, or null)
## above it: while you type in it, and after, until the keyboard's gone and no finger's down.
func height_for(box: LineEdit) -> float:
	var height := float(height_source.call())
	if box != null and box.is_editing():
		_lifting = true
		_height = height
		return height
	if _lifting and (height > 0.0 or finger_down):
		return maxf(height, _height)
	_lifting = false
	return 0.0


func _real_height() -> float:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0  # (a computer: none on the screen, and asking says so in the log every time)
	return float(DisplayServer.virtual_keyboard_get_height())


static func _over(c: Control, at: Vector2) -> bool:
	return Rect2(Vector2.ZERO, c.size).has_point(c.get_global_transform_with_canvas().affine_inverse() * at)
