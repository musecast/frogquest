extends Node2D
## What's in the ground under the meadow and the tree, big and quiet, as pixel art in the dirt's own colours
## (assets/dirt), each pixel the tiles' own size: the frog god's shape pressed into the earth long ago (eyes
## and a little smile), the World Tree's roots spreading under it, and a few half-sunk stones. Only where
## there's plain dirt; none of it solid; one drawing (it never moves).

const DIR := "res://assets/dirt/"
const GROUND_LAYER := 1  # the tile map's "foreground"
const FILL := Vector2i(1, 4)  # (the plain dirt tile, in the stone sheet: source 0)
const FILL_SOURCE := 0
const ACROSS := Vector2(1262.0, 4300.0)  # (the open ground, the sand wall to the U-turn sign)
const SURFACE := -462.0  # (the grass's top there)
const UNDER_GRASS := 10.0  # (just under the grass tile's own edge: where the roots come from)
const PIXEL := 2.4  # (the tiles' own)
## [picture, x of its middle, how far down its top is (px under the grass), flipped]
const THINGS := [
	["frog_fossil", 1930.0, 92.0, false],
	["roots", 2880.0, UNDER_GRASS, false],
	["boulder2", 1500.0, 196.0, false],
	["boulder1", 3620.0, 62.0, true],
	["boulder3", 4070.0, 150.0, false],
	["boulder1", 2290.0, 232.0, false],
]

var ground: TileMap = null  # (Main's tile map)
var things: Array = []  # [picture, its rect in the world, flipped]: the ones down
var _art := {}


func _ready() -> void:
	for t in THINGS:
		if not _art.has(t[0]):
			_art[t[0]] = load(DIR + t[0] + ".png")
		var tex: Texture2D = _art[t[0]]
		var size := Vector2(tex.get_size()) * PIXEL
		var box := Rect2(Vector2(roundf(t[1] - size.x * 0.5), roundf(SURFACE + t[2])), size)
		if fits(box, t[0] == "roots"):
			things.append([t[0], box, t[3]])
	queue_redraw()


func count() -> int:
	return things.size()


func _draw() -> void:
	for t in things:
		var box: Rect2 = t[1]
		if t[2]:
			box = Rect2(box.position.x + box.size.x, box.position.y, -box.size.x, box.size.y)
		draw_texture_rect(_art[t[0]], box, false)


## Whether a box is all over plain dirt (roots may start in the grass tile's own dirt edge over it).
func fits(box: Rect2, from_grass: bool) -> bool:
	if ground == null:
		return false
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var cell := ground.local_to_map(ground.to_local(corner))
		var source := ground.get_cell_source_id(GROUND_LAYER, cell)
		var dirt := source == FILL_SOURCE and ground.get_cell_atlas_coords(GROUND_LAYER, cell) == FILL
		var grass_edge: bool = from_grass and corner.y < SURFACE + UNDER_GRASS + 12.0 and source != -1
		if not (dirt or grass_edge):
			return false
	return true
