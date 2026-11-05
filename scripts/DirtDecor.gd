extends Node2D
## Things in the ground under the meadow and the tree, drawn over the dirt (none of it solid), each pixel
## the tiles' own size (CritterArt):
## - specks all through it, darker and lighter, as Kenney's own speckled dirt has;
## - clods, stones, now and then a bone, a little fossil or a worm;
## - roots hanging down from the grass, more of them under the World Tree.
## Only where there's plain dirt all round them (none in the bedroom, none poking out of the grass). One
## drawing (it never moves).

const ART := "res://assets/critters.png"
const GROUND_LAYER := 1  # the tile map's "foreground"
const FILL := Vector2i(1, 4)  # (the plain dirt tile, in the stone sheet: source 0)
const FILL_SOURCE := 0
const ACROSS := Vector2(1260.0, 4300.0)  # (the open ground, the sand wall to the U-turn sign)
const SURFACE := -462.0  # (the grass's top there)
const DEPTH := Vector2(26.0, 300.0)  # how far under the grass the things in it are (px)
const UNDER_GRASS := 11.0  # (where the grass tile's own dirt edge is: roots hang from just under it)
const SPECKS := Vector2(40.0, 34.0)  # (one patch of specks in each of these, give or take)
const APART := 30.0  # (no two things closer than this)
const TREE := Vector2(2560.0, 3200.0)  # (under the World Tree's foot: more roots)
## What, and how likely: [name in CritterArt, weight, hangs from the grass].
const KINDS := [
	["clods", 6, false], ["clod2", 4, false], ["clod3", 3, false], ["dirt_stone", 18, false],
	["pebble", 12, false], ["rock", 8, false], ["root", 10, true], ["root2", 8, true], ["bone", 5, false],
	["fossil", 5, false], ["worm", 6, false],
]

var ground: TileMap = null  # (Main's tile map)
var things: Array = []  # [name, its rect in the world, flipped]
var _sheet: Texture2D
var _art: Script


func _ready() -> void:
	_sheet = load(ART)
	_art = load("res://scripts/CritterArt.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150  # (the same ground every time)
	# Specks all through.
	var y := SURFACE + 16.0
	while y < SURFACE + DEPTH.y + 30.0:
		var x := ACROSS.x
		while x < ACROSS.y:
			var at := Vector2(x + rng.randf_range(0.0, SPECKS.x * 0.6), y + rng.randf_range(0.0, SPECKS.y * 0.5))
			_try(["specks1", "specks2", "specks3"][rng.randi() % 3], at, rng.randf() < 0.5, false, false)
			x += SPECKS.x * rng.randf_range(0.8, 1.3)
		y += SPECKS.y
	# Clods, stones and finds; roots from the grass.
	var total := 0
	for k in KINDS:
		total += k[1]
	var x := ACROSS.x
	while x < ACROSS.y:
		var under_tree := x > TREE.x and x < TREE.y
		x += rng.randf_range(22.0, 50.0) if under_tree else rng.randf_range(30.0, 74.0)
		var kind: Array = KINDS[0]
		if under_tree and rng.randf() < 0.6:
			kind = ["root_long", 0, true] if rng.randf() < 0.5 else KINDS[6 + rng.randi() % 2]
		else:
			var roll := rng.randi() % total
			for k in KINDS:
				roll -= k[1]
				if roll < 0:
					kind = k
					break
		var size: Vector2 = _art.RECTS[kind[0]].size * _art.PIXEL
		var top := SURFACE + (UNDER_GRASS if kind[2] else rng.randf_range(DEPTH.x, DEPTH.y))
		_try(kind[0], Vector2(x - size.x * 0.5, top), rng.randf() < 0.5, kind[2], true)
	queue_redraw()


## Puts one down at `at` (its top left) if it's all in plain dirt (a root's top may be in the grass's edge)
## and, if `spaced`, not on top of another thing.
func _try(called: String, at: Vector2, flip: bool, hangs: bool, spaced: bool) -> void:
	var box := Rect2(at.round(), _art.RECTS[called].size * _art.PIXEL)
	if not _fits(box, hangs):
		return
	if spaced:
		for other in things:
			if not other[0].begins_with("specks") and other[1].position.distance_to(box.position) < APART:
				return
	things.append([called, box, flip])


func count() -> int:
	return things.filter(func(t: Array) -> bool: return not t[0].begins_with("specks")).size()


func _draw() -> void:
	for t in things:
		var box: Rect2 = t[1]
		if t[2]:
			box = Rect2(box.position.x + box.size.x, box.position.y, -box.size.x, box.size.y)
		draw_texture_rect_region(_sheet, box, _art.RECTS[t[0]])


## Whether a box is all in plain dirt (a root's top in the grass tile over it, too).
func _fits(box: Rect2, hangs: bool) -> bool:
	if ground == null:
		return false
	for corner in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var cell := ground.local_to_map(ground.to_local(corner))
		var source := ground.get_cell_source_id(GROUND_LAYER, cell)
		var dirt := source == FILL_SOURCE and ground.get_cell_atlas_coords(GROUND_LAYER, cell) == FILL
		var grass_edge: bool = hangs and corner.y < SURFACE + UNDER_GRASS + 12.0 and source != -1
		if not (dirt or grass_edge):
			return false
	return true
