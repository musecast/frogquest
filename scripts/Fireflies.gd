extends Node2D
## Fireflies in the dark inside the tree: soft yellow-green lights drifting about, slowly glowing and
## fading. They're their own light (unshaded, added on), so the dark doesn't hide them; they keep well
## away from where the little flies hide (whose glint is paler), and drift off if the frog comes close.

const ART := "res://assets/critters.png"
const GLOW := Rect2(0, 0, 16, 16)
const COUNT := 22
const COLOUR := Color(0.78, 1.0, 0.42)
## Where: inside the trunk, through the dark (heights 148-313).
const AREA := Rect2(2440.0, -3560.0, 1060.0, 1560.0)
const CLEAR_OF := 130.0  # this far, at least, from a hidden fly
const SHY := 60.0
const WALL_LAYER := 4  # the tile map's "background" layer: the inside of the tree
const AWAKE := 700.0  # (they only bother with the camera this near the dark)

var flies: Array = []  # (FlyHunt's spots: they keep clear of them)
var tree: TileMap = null  # (Main's tile map: they stay where the trunk's back wall is, inside the tree)
var frog: Node2D = null
var _art: Texture2D
var _bugs: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	_art = load(ART)
	z_index = 2
	var glow := CanvasItemMaterial.new()
	glow.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var tries := 0
	while _bugs.size() < COUNT and tries < 2000:
		tries += 1
		var at := Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(AREA.position.y, AREA.end.y))
		if tree and tree.get_cell_source_id(WALL_LAYER, tree.local_to_map(tree.to_local(at))) == -1:
			continue
		var clear := true
		for f in flies:
			if at.distance_to(f) < CLEAR_OF:
				clear = false
				break
		if not clear:
			continue
		_bugs.append({"home": at, "at": at, "phase": rng.randf() * TAU, "speed": rng.randf_range(0.5, 1.1),
			"wander": rng.randf_range(16.0, 34.0), "glow": rng.randf_range(0.35, 0.8), "away": Vector2.ZERO})


func count() -> int:
	return _bugs.size()


func _process(delta: float) -> void:
	if not _view().grow(AWAKE).intersects(AREA):
		return
	_t += delta
	var near: Vector2 = frog.global_position if frog and is_instance_valid(frog) else Vector2(INF, INF)
	for bug in _bugs:
		var p: float = _t * bug.speed + bug.phase
		var drift: Vector2 = Vector2(sin(p * 0.7) + 0.5 * sin(p * 1.9), cos(p * 0.5) + 0.4 * sin(p * 1.3)) * bug.wander
		if bug.at.distance_to(near) < SHY:
			bug.away += (bug.at - near).normalized() * 40.0 * delta
		else:
			bug.away = bug.away.move_toward(Vector2.ZERO, 6.0 * delta)
		bug.at = bug.home + drift + bug.away
	queue_redraw()


## How bright one is now: a slow glow, then dark a while.
func brightness(bug: Dictionary) -> float:
	var s := sin(_t * bug.glow + bug.phase)
	return 0.12 + 0.88 * pow(maxf(0.0, s), 1.4)


func _draw() -> void:
	for bug in _bugs:
		var b := brightness(bug)
		if b < 0.1:
			continue
		draw_texture_rect_region(_art, Rect2(bug.at - Vector2(22, 22), Vector2(44, 44)), GLOW, Color(COLOUR, b * 0.55))
		draw_texture_rect_region(_art, Rect2(bug.at - Vector2(9, 9), Vector2(18, 18)), GLOW, Color(COLOUR, b))
		draw_rect(Rect2(bug.at.round() - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 1.0, 0.85, b))


## What the camera sees, in the world.
func _view() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var inv := vp.get_canvas_transform().affine_inverse()
	return Rect2(inv * Vector2.ZERO, Vector2.ZERO).expand(inv * vp.get_visible_rect().size)
