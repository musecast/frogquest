extends RefCounted
## How far down Froggy's head is in one of his frames, in his art pixels, from where it is when he
## stands (frog.png): a pixel as he breathes or sulks, 2 or 3 as he crouches to aim or jump. His hats
## sit on his head and come down with it (held still, they showed a gap over his head as he crouched).
## Read off the art itself (its top row), so redrawn frames stay right.

const STANDING := "res://assets/frog.png"

static var _drops := {}  # frame's resource path -> how far down


static func drop(frame: Texture2D) -> int:
	if frame == null:
		return 0
	var key := frame.resource_path
	if not _drops.has(key):
		_drops[key] = maxi(0, _top(frame) - _top(load(STANDING)))
	return _drops[key]


static func _top(texture: Texture2D) -> int:
	var image := texture.get_image()
	if image == null:
		return 0
	if image.is_compressed():
		image.decompress()
	return image.get_used_rect().position.y
