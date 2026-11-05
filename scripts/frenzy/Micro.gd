extends Node2D
## One of Frog Frenzy's microgames (Frenzy.gd): a few seconds, one word to say what to do, won or lost.
## Most are played as Froggy himself, with his own jump (the slingshot: drag back, the aim line, let go):
## the microgame says so (uses_froggy) and where he starts (froggy_at), Frenzy puts the real Froggy there,
## and it watches what he does. The rest are tapped or dragged (press, move, release, in its world). Each
## builds its little world round itself and says which square of it the stage shows (view); it calls win()
## or lose() as it goes; when its time's up, timeout() says how it ended for one still undecided (lost,
## unless it's one you win by lasting).

signal decided  # (won or lost before the time's up)

const CREAM := Color(0.97, 0.92, 0.80)
const INK := Color(0.10, 0.08, 0.12)
const FEET := 13.0  # (his feet, below his middle: his body's a circle 10 round at his scale of 1.2, and a pixel to spare, so he's put just over what he stands on, never in it: a one-way platform lets through what starts in it)

var word := "GO!"
var seconds := 4.0  # (its time at the first speed: the runner divides it by the speed)
var speed := 1.0
var rng := RandomNumberGenerator.new()
var won := false
var lost := false
var t := 0.0  # (seconds since it began)
var playing := false  # (the word's gone: it's on, and stepping)
var accepting := false  # (it's on and its time's not up: a finger counts)
var view := Rect2(0.0, 0.0, 240.0, 240.0)  # (the square of its world the stage shows)
var uses_froggy := false  # (played as Froggy, with his own jump)
var froggy_at := Vector2.ZERO  # (where he starts, his middle, standing)
var froggy: CharacterBody2D  # (Frenzy's Froggy: the real one, his jump and all; null till it's set)
var _down := false


## Set it up (rng and speed are set first, and froggy).
func begin() -> void:
	pass


## (Frenzy's just put him in, at froggy_at.)
func froggy_placed() -> void:
	pass


## (It's over: he's going on to the next; anything done to him undone.)
func froggy_left() -> void:
	pass


func press(_at: Vector2) -> void:
	pass


func move(_at: Vector2) -> void:
	pass


func release(_at: Vector2) -> void:
	pass


## Each frame while it's on (and through its result, to finish what it's showing).
func step(delta: float) -> void:
	t += delta


## The time's up: did he win? (Already won, yes; otherwise no, unless a lasting one says so.)
func timeout() -> bool:
	return won


func win() -> void:
	if not won and not lost:
		won = true
		decided.emit()


func lose() -> void:
	if not won and not lost:
		lost = true
		decided.emit()


## A finger, for the ones that aren't played as Froggy: in its world, while it counts.
func _unhandled_input(event: InputEvent) -> void:
	if uses_froggy or not accepting or won or lost:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at := _world_at(event.position)
		if event.pressed:
			_down = true
			press(at)
		elif _down:
			_down = false
			release(at)
	elif event is InputEventMouseMotion and _down:
		move(_world_at(event.position))


func _world_at(screen: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen


## Is Froggy (his middle) within `reach` of `at`?
func froggy_near(at: Vector2, reach: float) -> bool:
	return froggy != null and froggy.visible and froggy.global_position.distance_to(at) <= reach


## Is he standing on `body`?
func froggy_on(body: Node) -> bool:
	if froggy == null or not froggy.is_on_floor():
		return false
	for i in froggy.get_slide_collision_count():
		if froggy.get_slide_collision(i).get_collider() == body:
			return true
	return false


## A platform from Endless to stand on: `kind`'s art, `wide` across, the middle of its top at `at`.
func ledge(at: Vector2, wide: float, kind := "mushroom") -> StaticBody2D:
	var p := StaticBody2D.new()
	p.set_script(load("res://scenes/EndlessPlatform.gd"))
	p.kind = kind
	p.width = wide
	p.position = at
	add_child(p)
	return p


## Somewhere to stand that isn't drawn (the top of something drawn): `wide` across, its top at `at`.
func floor_at(at: Vector2, wide: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(wide, 8.0)
	shape.shape = box
	shape.position = Vector2(0.0, 4.0)
	shape.one_way_collision = true
	body.add_child(shape)
	add_child(body)
	return body


## A sprite of `path`, `tall` of its world's px tall (its art's pixels square), at `at`.
func sprite(path: String, at: Vector2, tall: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var k := tall / float(s.texture.get_height())
	s.scale = Vector2(k, k)
	s.position = at
	add_child(s)
	return s


## A little frog: Froggy as he's made (his look), or another frog in `colours` {body, belly}.
func frog(at: Vector2, tall: float, colours := {}) -> Sprite2D:
	var s := sprite("res://assets/frog.png", at, tall)
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	var mat: ShaderMaterial = look.material(MusicManager.look if colours.is_empty() else colours, "")
	s.material = mat
	return s


## A short sound, on the FX bus.
func play(path: String, pitch := 1.0, db := -8.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.bus = &"FX"
	p.pitch_scale = pitch
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## A word over something, staying put (no rocking): "!!", "...".
func mark(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 30
	load("res://scripts/UIStyle.gd").style_label(l, 16, colour)
	add_child(l)
	l.size = l.get_minimum_size()
	return l
