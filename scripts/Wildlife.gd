extends Node2D
## The world's little life round the World Tree, put into the story level by Main: flowers, grass, rocks
## and stepping stones on the ground (GroundDecor), leaves falling past the tree (Leaves), fireflies in the
## dark (Fireflies), butterflies about the flowers (Butterfly), and little birds sitting about that fly off
## when the frog comes near (Bird). None of it's solid; none of it's in the way.

## Butterflies: where their flowers are (an x, and a y over them to look down from), and their colour.
const BUTTERFLIES := [
	[Vector2(1516, -560), 0], [Vector2(1740, -560), 1], [Vector2(2186, -560), 2], [Vector2(3470, -560), 0],
	[Vector2(4140, -560), 1], [Vector2(3650, -1530), 2],
]
## Little yellow birds: on top of a sign (its node, and how far from its middle), or on whatever's solid under a
## point (on the ground, a branch, a mushroom, the castle).
const BIRDS := [
	["on", "Streetsign", 34.0], ["on", "Uturnsign", 0.0], ["under", Vector2(3612, -560)],
	["under", Vector2(2860, -610)], ["under", Vector2(3730, -1290)], ["under", Vector2(2560, -1750)],
	["under", Vector2(2800, -4040)], ["under", Vector2(3480, -4570)],
	["under", Vector2(2900, -5500)], ["under", Vector2(3700, -5650)], ["under", Vector2(1840, -6190)],
]

var level: Node = null
var birds: Array[Node2D] = []
var butterflies: Array[Node2D] = []


## Puts it all into the level (Main), behind and round everything.
static func spawn_into(into: Node) -> Node2D:
	var life: Node2D = load("res://scripts/Wildlife.gd").new()
	life.name = "Wildlife"
	life.level = into
	into.add_child(life)
	return life


func _ready() -> void:
	var tiles: TileMap = level.get_node_or_null("TileMap")
	var frog: Node2D = level.get_node_or_null("Player")
	var decor: Node2D = load("res://scripts/GroundDecor.gd").new()
	decor.name = "GroundDecor"
	decor.ground = tiles
	add_child(decor)
	var leaves: Node2D = load("res://scripts/Leaves.gd").new()
	leaves.name = "Leaves"
	add_child(leaves)
	var glow: Node2D = load("res://scripts/Fireflies.gd").new()
	glow.name = "Fireflies"
	glow.frog = frog
	glow.flies = load("res://scripts/FlyHunt.gd").SPOTS
	glow.tree = tiles
	add_child(glow)
	var ground_top := Callable(load("res://scripts/GroundDecor.gd"), "ground_top")
	var butterfly: Script = load("res://scripts/Butterfly.gd")
	for b in BUTTERFLIES:
		var top: float = ground_top.call(tiles, b[0].x, b[0].y, 300.0)
		if is_nan(top):
			continue
		var fly: Node2D = butterfly.new()
		fly.home = Vector2(b[0].x, top)
		fly.colour = b[1]
		fly.frog = frog
		add_child(fly)
		butterflies.append(fly)
	var bird: Script = load("res://scripts/Bird.gd")
	for spot in BIRDS:
		var at := _perch(spot, tiles, ground_top)
		if is_nan(at.y):
			continue
		var one: Node2D = bird.new()
		one.perch = at
		one.frog = frog
		one.set_meta("on_sign", spot[0] == "on")
		add_child(one)
		birds.append(one)


## Where a bird's feet go for one of BIRDS.
func _perch(spot: Array, tiles: TileMap, ground_top: Callable) -> Vector2:
	if spot[0] == "on":
		var sign_node := level.get_node_or_null(spot[1]) as Sprite2D
		if sign_node == null:
			return Vector2(NAN, NAN)
		var box := sign_node.get_rect()
		var top_mid: Vector2 = sign_node.global_transform * Vector2(box.get_center().x, box.position.y)
		return Vector2(top_mid.x + spot[2], top_mid.y + 1.0)
	var top: float = ground_top.call(tiles, spot[1].x, spot[1].y, 400.0)
	return Vector2(spot[1].x, top)
