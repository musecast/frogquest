extends Node2D
## A little life on the ground round the World Tree's foot: grass, flowers, a shrub, a berry bush,
## mushrooms, two little pines, rocks, and stepping stones from the signs to the tree. None of it is solid
## and all of it is behind Froggy (and just behind the ground's own tiles, so it sits in the grass). It's
## the tiles' own art (Kenney's, as the level's), or drawn to match it (assets/critters.png).

const SCALE := 1.2  # (the tile map's)
const TILE := 18
const GROUND_LAYER := 1  # the tile map's "foreground": what's solid
const ART := {
	"tiles": "res://assets/tilemap_packed.png",
	"farm": "res://assets/farm_tilemap_packed.png",
	"critters": "res://assets/critters.png",
}
## Each kind: its sheet, and either the tile (or tiles, top first) it is or its rect in the sheet.
const KINDS := {
	"sprout": ["tiles", Vector2i(4, 6)],
	"sprout_tall": ["tiles", Vector2i(5, 6)],
	"pine": ["tiles", Vector2i(6, 6)],
	"mushroom": ["tiles", Vector2i(8, 6)],
	"grass": ["farm", Vector2i(9, 5)],
	"grass_low": ["farm", Vector2i(10, 5)],
	"grass_tall": ["farm", Vector2i(9, 4)],
	"shrub": ["farm", Vector2i(6, 3)],
	"berries": ["farm", Vector2i(9, 3)],
	"sunflower": ["farm", Vector2i(4, 1), Vector2i(4, 2)],
	"red": ["critters", Rect2(69, 0, 7, 8)],
	"yellow": ["critters", Rect2(77, 0, 7, 8)],
	"blue": ["critters", Rect2(85, 0, 7, 7)],
	"pink": ["critters", Rect2(61, 0, 7, 9)],
	"bud": ["critters", Rect2(93, 0, 5, 7)],
	"pebble": ["critters", Rect2(173, 0, 6, 4)],
	"rock": ["critters", Rect2(147, 0, 10, 6)],
	"stone": ["critters", Rect2(180, 0, 11, 3)],
	"stone_small": ["critters", Rect2(192, 0, 9, 3)],
}
## Where: [kind, x in the world, flipped]. Each stands on whatever's solid under it there (the ground).
const PLACES := [
	# By the sand wall where he comes out, and on to the signs.
	["grass_tall", 1262.0, false], ["yellow", 1281.0, false], ["grass", 1296.0, true], ["pebble", 1318.0, false],
	["sprout", 1395.0, false], ["grass_low", 1452.0, false], ["shrub", 1488.0, false], ["red", 1511.0, false],
	["blue", 1524.0, true], ["grass", 1546.0, false], ["bud", 1602.0, false],
	["pink", 1688.0, false], ["grass_low", 1702.0, true], ["red", 1744.0, true], ["yellow", 1757.0, false],
	["grass", 1790.0, false],
	# A little wood of two, a mushroom and a rock.
	["pine", 1872.0, false], ["mushroom", 1896.0, false], ["pine", 1921.0, true], ["rock", 1950.0, false],
	["grass_tall", 1974.0, true],
	# The stepping stones to the tree, flowers by them.
	["stone", 2040.0, false], ["stone_small", 2098.0, false], ["bud", 2122.0, true], ["stone", 2156.0, true],
	["yellow", 2183.0, false], ["stone_small", 2215.0, false], ["stone", 2272.0, false], ["blue", 2300.0, false],
	["stone_small", 2331.0, true], ["grass_low", 2356.0, false], ["stone", 2390.0, false],
	["stone_small", 2447.0, false], ["pink", 2470.0, true], ["stone", 2504.0, true],
	# At the tree's foot.
	["mushroom", 2530.0, true], ["berries", 2553.0, false], ["grass", 2572.0, false],
	# The far side: a meadow out to the U-turn sign.
	["mushroom", 3226.0, false], ["grass", 3250.0, true], ["sprout_tall", 3302.0, false],
	["grass_tall", 3396.0, false], ["red", 3418.0, false], ["yellow", 3431.0, true], ["pink", 3446.0, false],
	["grass_low", 3462.0, false], ["blue", 3480.0, false], ["bud", 3495.0, true], ["red", 3514.0, true],
	["grass", 3532.0, false], ["yellow", 3551.0, false],
	["pine", 3690.0, false], ["grass_low", 3712.0, true], ["pine", 3748.0, true], ["pebble", 3772.0, false],
	["shrub", 3866.0, true], ["berries", 3892.0, false], ["rock", 3921.0, true], ["grass_tall", 3942.0, false],
	["sunflower", 4062.0, false], ["grass", 4084.0, false], ["pink", 4106.0, true], ["red", 4122.0, false],
	["grass_tall", 4140.0, true], ["blue", 4158.0, false], ["yellow", 4178.0, true], ["sunflower", 4200.0, true],
	["grass_low", 4228.0, false],
]

var ground: TileMap = null  # (Main's tile map: what's solid)
var placed := 0  # how many went down (some places can have nothing under them: none there)


func _ready() -> void:
	z_index = -1
	var sheets := {}
	for key in ART:
		sheets[key] = load(ART[key])
	for p in PLACES:
		var kind: Array = KINDS[p[0]]
		var top := ground_top(ground, p[1], -500.0, 300.0)  # (from just over the ground: not onto a low branch)
		if is_nan(top):
			continue
		_put(sheets[kind[0]], kind, Vector2(p[1], top), p[2])
		placed += 1


## Lays one thing down with its bottom middle at `at` (a pixel into the ground).
func _put(sheet: Texture2D, kind: Array, at: Vector2, flip: bool) -> void:
	var parts: Array = kind.slice(1)
	var y := at.y + SCALE
	for i in range(parts.size() - 1, -1, -1):  # (bottom up)
		var region: Rect2 = parts[i] if parts[i] is Rect2 else Rect2(Vector2(parts[i]) * TILE, Vector2(TILE, TILE))
		var sprite := Sprite2D.new()
		var tex := AtlasTexture.new()
		tex.atlas = sheet
		tex.region = region
		sprite.texture = tex
		sprite.centered = false
		sprite.flip_h = flip
		sprite.scale = Vector2(SCALE, SCALE)
		sprite.position = Vector2(roundf(at.x - region.size.x * SCALE * 0.5), roundf(y - region.size.y * SCALE))
		add_child(sprite)
		y -= region.size.y * SCALE


## The y of the top of the first solid tile's art at x, going down from `from_y` (NAN if there's none in
## `reach`). The tile map's own sums: its cells are 16 px, its tiles' art 18 (a pixel over each side).
static func ground_top(tm: TileMap, x: float, from_y: float, reach: float) -> float:
	if tm == null:
		return NAN
	var start := tm.local_to_map(tm.to_local(Vector2(x, from_y)))
	var end := tm.local_to_map(tm.to_local(Vector2(x, from_y + reach)))
	for row in range(start.y, end.y + 1):
		var cell := Vector2i(start.x, row)
		var source := tm.get_cell_source_id(GROUND_LAYER, cell)
		if source == -1:
			continue
		var art_half := 0.5 * TILE
		var atlas := tm.tile_set.get_source(source) as TileSetAtlasSource
		if atlas:
			art_half = 0.5 * atlas.texture_region_size.y
		return tm.to_global(tm.map_to_local(cell) - Vector2(0.0, art_half)).y
	return NAN
