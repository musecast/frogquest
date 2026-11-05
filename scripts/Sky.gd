extends Node2D
## The sky around the World Tree, behind everything: hills far off on the horizon (and, once he's up the
## tree, the land below them), and clouds in three layers that drift on the wind and move slower than the
## world the further off they are. The higher he climbs, the more clouds there are and the clearer and
## deeper the sky gets, till near the top he climbs up through a bank of cloud and comes out over a sea of it.
##
## Main puts it into "World Sprites" just after the skybox, at the skybox's depth: over the skybox, under
## everything else. The trunk's back wall (the tile map's "background" layer) is at that depth too, drawn
## before it, so wherever that wall is none of the sky is drawn (a mask, one texel a tile): inside, the tree
## keeps its look.

const ART := "res://assets/sky/"
const TEXEL := 2.4  # world px for each pixel of the sky's art (twice the tiles': softer, further off)
const GROUND := -472.0  # the ground's y (height 0; heights are tenths of a px up from it)
const WALL_LAYER := 4  # the tile map's "background" layer: the trunk's back wall
const WRAP := 2400.0  # each layer of clouds repeats across this much of its own space
const ROW := 200.0  # (clouds are kept in rows this tall, to find the ones on screen)

## In assets/sky/clouds.png, smallest first (make_sky_art.py draws and packs them).
const CLOUDS := [
	Rect2(52, 41, 20, 9), Rect2(27, 41, 24, 10), Rect2(974, 0, 28, 11), Rect2(941, 0, 32, 12),
	Rect2(904, 0, 36, 14), Rect2(0, 41, 26, 11), Rect2(860, 0, 43, 17), Rect2(807, 0, 52, 18),
	Rect2(689, 0, 60, 21), Rect2(555, 0, 68, 25), Rect2(750, 0, 56, 21), Rect2(624, 0, 64, 22),
	Rect2(472, 0, 82, 29), Rect2(375, 0, 96, 32), Rect2(264, 0, 110, 36), Rect2(0, 0, 124, 40),
	Rect2(125, 0, 138, 40),
]

## The clouds, far to near. f: how much of the camera's moving it takes (1: as the world, 0: stuck to the
## screen). cell: at most one cloud in each cell this big (in its own space). sizes: which of CLOUDS.
## scale: how big they're drawn. tint: their colour and how see-through. drift: px a second on the wind.
## odds: how likely a cell gets one, by the height he'd be at to see it in the middle of the screen
## ([height, odds] pairs, straight lines in between).
const LAYERS := [
	{"f": 0.08, "cell": Vector2(120, 80), "sizes": [0, 1, 2, 3, 4, 5, 6, 7], "scale": 0.75,
		"tint": Color(0.88, 0.93, 1.0, 0.42), "drift": 2.0,
		"odds": [[0.0, 0.12], [200.0, 0.18], [450.0, 0.3], [650.0, 0.4], [800.0, 0.25], [1000.0, 0.1]]},
	{"f": 0.2, "cell": Vector2(200, 130), "sizes": [5, 6, 7, 8, 9, 10, 11, 12], "scale": 1.0,
		"tint": Color(0.95, 0.97, 1.0, 0.72), "drift": 4.0,
		"odds": [[0.0, 0.05], [150.0, 0.1], [350.0, 0.22], [550.0, 0.38], [700.0, 0.3], [850.0, 0.12]]},
	{"f": 0.4, "cell": Vector2(300, 170), "sizes": [11, 12, 13, 14, 15, 16], "scale": 1.0,
		"tint": Color(0.95, 0.97, 1.0, 0.86), "drift": 7.0,
		"odds": [[300.0, 0.0], [400.0, 0.12], [550.0, 0.28], [630.0, 0.45], [660.0, 0.85], [712.0, 0.85],
			[722.0, 0.0]]},
]
## The sea of clouds near the top, in the near layer: its top's y in that layer's space. With the camera at
## the very top it's a little under the middle of the screen; he's level with it at height ~720.
const SEA_Y := -3080.0
## The hills: their strip's top in their own space (with him on the ground, the far ones' tops are
## 80-120 px over it, the near ones' 50-80), and what's under them.
const HILLS := [
	{"art": "hills_far.png", "f": 0.04, "top": -117.0, "fill": Color(0.49, 0.59, 0.70)},
	{"art": "hills_near.png", "f": 0.09, "top": -110.0, "under": "land.png", "fill": Color(0.26, 0.5, 0.4)},
]
## The sky's own tint, by height: [height, colour at the top of the screen, at the bottom]. None at all
## low down (the sky he knows); clearer and bluer over the dark; deep blue and a warm glow over the sea.
const TINTS := [
	[300.0, Color(0.55, 0.75, 0.95, 0.0), Color(0.8, 0.88, 0.97, 0.0)],
	[420.0, Color(0.55, 0.75, 0.95, 0.12), Color(0.8, 0.88, 0.97, 0.06)],
	[600.0, Color(0.42, 0.62, 0.95, 0.22), Color(0.92, 0.95, 1.0, 0.16)],
	[720.0, Color(0.26, 0.42, 0.86, 0.34), Color(1.0, 0.86, 0.64, 0.2)],
]
## The skybox's edges fade into the plain sky round it over this many px (it turns, slowly, so an edge
## can be anywhere): no hard line across the sky.
const EDGE_FADE := 420.0
## The faint swirl far behind the sky (earthboundbattleFX3) gets soft edges too: this much of its frame,
## each side.
const SWIRL_EDGE := 0.1
const SOFT_EDGES := """shader_type canvas_item;
// Fades out towards the edges of the frame (no hard line where it ends).
uniform float edge = 0.1;
void fragment() {
	vec2 d = min(UV, 1.0 - UV);
	COLOR.a *= smoothstep(0.0, edge, d.x) * smoothstep(0.0, edge, d.y);
}
"""
const MASK_SHADER := """shader_type canvas_item;
// None of the sky where the trunk's back wall is: a texel of the mask for each of the tile map's cells.
uniform sampler2D wall : filter_nearest;
uniform vec2 wall_origin;
uniform float cell = 21.6;
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	ivec2 c = ivec2(floor((world - wall_origin) / cell));
	ivec2 size = textureSize(wall, 0);
	float inside = 0.0;
	if (c.x >= 0 && c.y >= 0 && c.x < size.x && c.y < size.y) {
		inside = texelFetch(wall, c, 0).r;
	}
	COLOR.a *= 1.0 - inside;  // (COLOR is already the texture's colour times the draw's)
}
"""

var wall: TileMap = null  # (Main's tile map: the trunk's back wall is in it)
var skybox: Sprite2D = null  # (the turning skybox just under it: its edges fade out)
var time := 0.0
var cloud_art: Texture2D
var _tint: Node2D
var _layers: Array[Node2D] = []
var _again: TileMapLayer = null  # (the see-through tiles of the back wall's layer, drawn again on top)


func _ready() -> void:
	process_priority = 100  # (after the camera's moved, this frame)
	z_index = -5
	if skybox == null and get_parent():
		skybox = get_parent().get_node_or_null("BlueSkySkybox") as Sprite2D
	var swirl := get_parent().get_node_or_null("earthboundbattleFX3") as CanvasItem if get_parent() else null
	if swirl and swirl.material == null:
		var soft := ShaderMaterial.new()
		soft.shader = Shader.new()
		soft.shader.code = SOFT_EDGES
		soft.set_shader_parameter("edge", SWIRL_EDGE)
		swirl.material = soft
	cloud_art = load(ART + "clouds.png")
	var mask := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = MASK_SHADER
	mask.shader = shader
	_wall_mask(mask)
	material = mask
	_tint = Tint.new()
	_tint.sky = self
	_add(_tint)
	_add_hills(HILLS[0])
	_add_clouds(LAYERS[0], 1)
	_add_hills(HILLS[1])
	_add_clouds(LAYERS[1], 2)
	_add_clouds(LAYERS[2], 3).sea = load(ART + "cloud_sea.png")
	if _again:
		add_child(_again)  # (last: over all of the sky, with no mask)
	_process(0.0)


func _add(child: Node2D) -> void:
	child.use_parent_material = true
	add_child(child)


func _add_hills(spec: Dictionary) -> void:
	var hills := Hills.new()
	hills.sky = self
	hills.f = spec.f
	hills.top = spec.top
	hills.art = load(ART + spec.art)
	hills.under = load(ART + spec.under) if spec.has("under") else null
	hills.fill = spec.fill
	hills.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_add(hills)
	_layers.append(hills)


func _add_clouds(spec: Dictionary, seed_n: int) -> CloudLayer:
	var layer := CloudLayer.new()
	layer.sky = self
	layer.f = spec.f
	layer.size_k = spec.scale
	layer.tint = spec.tint
	layer.drift = spec.drift
	layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137 * seed_n  # (the same sky every time)
	var cell: Vector2 = spec.cell
	var across := maxi(1, roundi(WRAP / cell.x))
	var step_x := WRAP / across
	# Its own space, from what the camera sees of it at the very top down to the bedroom.
	var y := -8600.0 * layer.f - 700.0
	while y < 500.0 * layer.f + 700.0:
		for i in across:
			var at := Vector2((i + rng.randf()) * step_x, y + rng.randf() * cell.y)
			if rng.randf() < odds(spec.odds, height_at(at.y / layer.f)):
				var sizes: Array = spec.sizes
				layer.add_cloud(at, sizes[rng.randi() % sizes.size()], rng.randf() < 0.5)
		y += cell.y
	_add(layer)
	_layers.append(layer)
	return layer


## The tile map's back wall as a mask for the shader: a texel for each cell, 1 where there's a solid tile.
## The see-through tiles in that layer (sunflowers, wisps of cloud) aren't in it: the sky goes behind them
## and they're drawn again over it (_tiles_again).
func _wall_mask(mask: ShaderMaterial) -> void:
	mask.set_shader_parameter("wall_origin", Vector2(1e9, 1e9))
	if wall == null:
		return
	var cells: Array[Vector2i] = wall.get_used_cells(WALL_LAYER)
	var solid: Array[Vector2i] = []
	var see_through: Array[Vector2i] = []
	var known := {}
	for c in cells:
		var key := Vector3i(wall.get_cell_source_id(WALL_LAYER, c), wall.get_cell_atlas_coords(WALL_LAYER, c).x,
			wall.get_cell_atlas_coords(WALL_LAYER, c).y)
		if not known.has(key):
			known[key] = _solid(key.x, Vector2i(key.y, key.z))
		if known[key]:
			solid.append(c)
		else:
			see_through.append(c)
	_tiles_again(see_through)
	if solid.is_empty():
		return
	var lo := solid[0]
	var hi := solid[0]
	for c in solid:
		lo = lo.min(c)
		hi = hi.max(c)
	var img := Image.create_empty(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_R8)
	for c in solid:
		img.set_pixel(c.x - lo.x, c.y - lo.y, Color(1, 0, 0))
	var size: Vector2 = Vector2(wall.tile_set.tile_size) * wall.global_scale
	var corner: Vector2 = wall.to_global(wall.map_to_local(lo)) - size * 0.5
	mask.set_shader_parameter("wall", ImageTexture.create_from_image(img))
	mask.set_shader_parameter("wall_origin", corner)
	mask.set_shader_parameter("cell", size.x)


## Whether a tile's art fills its square (hardly a see-through pixel in it).
func _solid(source_id: int, coords: Vector2i) -> bool:
	var atlas := wall.tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		return false
	var img := atlas.texture.get_image()
	if img == null:
		return false
	if img.is_compressed():
		img.decompress()
	var region := atlas.get_tile_texture_region(coords)
	var clear := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if img.get_pixel(x, y).a < 0.5:
				clear += 1
	return clear <= region.get_area() * 0.02


## The see-through tiles of the back wall's layer, again, over the sky (a copy of just them: no collisions).
func _tiles_again(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var again := TileMapLayer.new()
	again.name = "TilesAgain"
	again.tile_set = wall.tile_set
	again.collision_enabled = false
	again.navigation_enabled = false
	again.transform = wall.global_transform
	again.modulate = wall.get_layer_modulate(WALL_LAYER)
	for c in cells:
		again.set_cell(c, wall.get_cell_source_id(WALL_LAYER, c), wall.get_cell_atlas_coords(WALL_LAYER, c),
			wall.get_cell_alternative_tile(WALL_LAYER, c))
	_again = again


func _process(delta: float) -> void:
	time += delta
	visible = view().position.y < GROUND + 40.0  # (none of it underground)
	if visible:
		for layer in _layers:
			layer.queue_redraw()
		_tint.queue_redraw()


## What the camera sees, in the world, as it's drawn: worked out when the layers draw (by then the camera
## has moved, this frame), with a little to spare round the edges.
func view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * vp.get_visible_rect().size
	return Rect2(a, Vector2.ZERO).expand(b).grow(8.0)


## Where a layer that takes f of the camera's moving is, this frame (its own space's origin in the world).
func shift_of(f: float, v: Rect2) -> Vector2:
	return v.get_center() * (1.0 - f)


## The height (tenths of a px over the ground) of a point at y.
static func height_at(y: float) -> float:
	return (-y + GROUND) / 10.0


## How likely, at height h, by [height, odds] pairs (straight lines between them, flat past the ends).
static func odds(table: Array, h: float) -> float:
	if h <= table[0][0]:
		return table[0][1]
	for i in range(1, table.size()):
		if h <= table[i][0]:
			var a: Array = table[i - 1]
			var b: Array = table[i]
			return lerpf(a[1], b[1], (h - a[0]) / (b[0] - a[0]))
	return table[-1][1]


## The sky's tint at the top and the bottom of the screen, with the middle of it at height h.
static func tint_at(h: float) -> Array:
	if h <= TINTS[0][0]:
		return [TINTS[0][1], TINTS[0][2]]
	for i in range(1, TINTS.size()):
		if h <= TINTS[i][0]:
			var a: Array = TINTS[i - 1]
			var b: Array = TINTS[i]
			var t: float = (h - a[0]) / (b[0] - a[0])
			return [a[1].lerp(b[1], t), a[2].lerp(b[2], t)]
	return [TINTS[-1][1], TINTS[-1][2]]


## The colour washed over the sky (not the clouds), top to bottom of the screen.
class Tint extends Node2D:
	var sky: Node2D

	func _draw() -> void:
		var r: Rect2 = sky.view()
		_skybox_edges(r)
		var cols: Array = sky.tint_at(sky.height_at(r.get_center().y))
		if cols[0].a <= 0.003 and cols[1].a <= 0.003:
			return
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([cols[0], cols[0], cols[1], cols[1]]))

	## The plain sky's colour drawn in over the skybox's edges, fading out inwards.
	func _skybox_edges(r: Rect2) -> void:
		var box: Sprite2D = sky.skybox
		if box == null or not box.is_visible_in_tree():
			return
		var xf := box.global_transform
		var rect := box.get_rect()
		var corners := [xf * rect.position, xf * Vector2(rect.end.x, rect.position.y), xf * rect.end,
			xf * Vector2(rect.position.x, rect.end.y)]
		var middle: Vector2 = xf * rect.get_center()
		var plain: Color = RenderingServer.get_default_clear_color()
		var gone := Color(plain, 0.0)
		var near := r.grow(EDGE_FADE)
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			if not near.intersects(Rect2(a, Vector2.ZERO).expand(b).grow(1.0)):
				continue
			var inward := (b - a).orthogonal().normalized()
			if inward.dot(middle - a) < 0.0:
				inward = -inward
			draw_polygon(PackedVector2Array([a, b, b + inward * EDGE_FADE, a + inward * EDGE_FADE]),
				PackedColorArray([plain, plain, gone, gone]))


## A strip of hills that repeats across, the land under it (if any), and its colour on down.
class Hills extends Node2D:
	var sky: Node2D
	var f := 0.05
	var top := -100.0  # (in its own space)
	var art: Texture2D
	var under: Texture2D
	var fill := Color.WHITE
	var origin := Vector2.ZERO  # (where its own space is, this frame)

	func _draw() -> void:
		var v: Rect2 = sky.view()
		var at: Vector2 = sky.shift_of(f, v)
		var lv := Rect2(v.position - at, v.size)  # what's on screen, in its own space
		var px := TEXEL
		var y := top
		origin = at
		y = _strip(art, y, lv, px)
		if under:
			y = _strip(under, y, lv, px)
		if y < lv.end.y:
			draw_set_transform(origin)
			draw_rect(Rect2(lv.position.x, y, lv.size.x, lv.end.y - y + 1.0), fill)
			draw_set_transform(Vector2.ZERO)

	func _strip(tex: Texture2D, y: float, lv: Rect2, px: float) -> float:
		var w := tex.get_width() * px
		var h := tex.get_height() * px
		if y < lv.end.y and y + h > lv.position.y:
			var x0 := floorf(lv.position.x / w) * w
			var across := ceilf((lv.end.x - x0) / w)
			draw_set_transform(origin + Vector2(x0, y), 0.0, Vector2(px, px))
			draw_texture_rect(tex, Rect2(0, 0, tex.get_width() * across, tex.get_height()), true)
			draw_set_transform(Vector2.ZERO)
		return y + h


## One layer of clouds: where each one is (in its own space, its base's middle), which, and flipped or not.
class CloudLayer extends Node2D:
	var sky: Node2D
	var f := 0.1
	var size_k := 1.0
	var tint := Color.WHITE
	var drift := 3.0
	var sea: Texture2D = null  # (the near layer: the sea of clouds)
	var origin := Vector2.ZERO  # (where its own space is, this frame)
	var _at: PackedVector2Array = []
	var _kind: PackedInt32Array = []
	var _flip: PackedByteArray = []
	var _rows := {}  # row → the clouds in it (an Array of their indices)

	func add_cloud(at: Vector2, kind: int, flip: bool) -> void:
		var row := floori(at.y / ROW)
		if not _rows.has(row):
			_rows[row] = []
		_rows[row].append(_at.size())
		_at.append(at)
		_kind.append(kind)
		_flip.append(1 if flip else 0)

	func count() -> int:
		return _at.size()

	func _draw() -> void:
		var v: Rect2 = sky.view()
		var at: Vector2 = sky.shift_of(f, v)
		var lv := Rect2(v.position - at, v.size)
		draw_set_transform(at)
		var shift: float = sky.time * drift
		var mid := lv.get_center().x
		var wrap := WRAP
		var left := mid - wrap * 0.5
		var reach := lv.size.x * 0.5 + 360.0
		origin = at
		if sea:
			_draw_sea(lv, shift)
		var art: Texture2D = sky.cloud_art
		var px := TEXEL * size_k
		for row in range(floori((lv.position.y - 10.0) / ROW), floori((lv.end.y + 120.0) / ROW) + 1):
			if not _rows.has(row):
				continue
			for i in _rows[row]:
				var r: Rect2 = CLOUDS[_kind[i]]
				var size := r.size * px
				var x := fposmod(_at[i].x + shift - left, wrap) + left
				if absf(x - mid) > reach or _at[i].y - size.y > lv.end.y or _at[i].y < lv.position.y:
					continue
				var rect := Rect2(Vector2(x - size.x * 0.5, _at[i].y - size.y).round(), size)
				if _flip[i]:
					rect = Rect2(rect.position.x + size.x, rect.position.y, -size.x, size.y)
				draw_texture_rect_region(art, rect, r, tint)

	func _draw_sea(lv: Rect2, shift: float) -> void:
		var px := TEXEL
		var w := sea.get_width() * px
		var h := sea.get_height() * px
		var y := SEA_Y
		if y > lv.end.y or y + h < lv.position.y:
			return
		var x0 := floorf((lv.position.x - shift) / w) * w + shift
		var across := ceilf((lv.end.x - x0) / w) + 1.0
		draw_set_transform(origin + Vector2(x0, y).round(), 0.0, Vector2(px, px))
		draw_texture_rect(sea, Rect2(0, 0, sea.get_width() * across, sea.get_height()), true, tint)
		draw_set_transform(origin)
