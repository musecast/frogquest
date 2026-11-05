extends Node2D
## One of Frog Frenzy's microgames (Frenzy.gd): a few seconds, one word to say what to do, won or lost.
## Drawn on a STAGE-square stage (the runner scales it to the screen, square pixels, and puts the
## original Endless checkerboard behind it); a finger comes in as press, move and release, in the stage's
## own coordinates. Each one calls win() or lose() as it goes; when its time's up, timeout() says how it
## ended for one still undecided (lost, unless it's one you win by lasting).

signal decided  # (won or lost before the time's up)

const STAGE := 240.0
const CREAM := Color(0.97, 0.92, 0.80)
const INK := Color(0.10, 0.08, 0.12)

var word := "GO!"
var seconds := 4.0  # (its time at the first speed: the runner divides it by the speed)
var speed := 1.0
var rng := RandomNumberGenerator.new()
var won := false
var lost := false
var t := 0.0  # (seconds since it began)
var playing := false  # (the word's gone: it's on)


## Set it up (rng and speed are set first).
func begin() -> void:
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


## A sprite of `path`, `tall` stage pixels tall (its art's pixels square), at `at`, in this stage.
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
