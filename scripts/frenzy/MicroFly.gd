extends "res://scripts/frenzy/Micro.gd"
## CATCH! On his lily pad by the pond, a fly buzzing about over him: jump into it (his own jump) and he's
## caught it.

const FLY := [".WW.....WW.", "WWWW...WWWW", "WWWWW.WWWWW", ".WWWKKKWWW.", "...KBBBK...", "..KRBBBRK..", "..KBBBBBK..",
	"...KBBBK..."]
const COLOURS := {"W": Color(0.82, 0.92, 1.0, 0.9), "K": Color(0.97, 0.92, 0.80), "B": Color(0.20, 0.18, 0.26), "R": Color(0.9, 0.2, 0.2)}
const REACH := 18.0

var _fly: Node2D
var _goal := Vector2.ZERO
var _caught := -1.0


func begin() -> void:
	word = "CATCH!"
	seconds = 4.4
	uses_froggy = true
	view = Rect2(-120.0, -175.0, 240.0, 240.0)
	ledge(Vector2(0.0, 0.0), 70.0, "lilypad")
	froggy_at = Vector2(0.0, -FEET)
	_fly = Node2D.new()
	_fly.position = _anywhere()
	_fly.draw.connect(func() -> void:
		for y in FLY.size():
			for x in str(FLY[y]).length():
				var ch := str(FLY[y])[x]
				if COLOURS.has(ch):
					_fly.draw_rect(Rect2(Vector2(x - 5.5, y - 4.0), Vector2.ONE), COLOURS[ch]))
	add_child(_fly)
	_goal = _anywhere()


## Somewhere over him a jump can reach: up to about 90 over his middle, and to either side.
func _anywhere() -> Vector2:
	return Vector2(rng.randf_range(-95.0, 95.0), rng.randf_range(-100.0, -60.0))


func step(delta: float) -> void:
	super.step(delta)
	if _caught >= 0.0:
		_fly.visible = t - _caught < 0.1
		return
	if _fly.position.distance_to(_goal) < 4.0:
		_goal = _anywhere()
	_fly.position = _fly.position.move_toward(_goal, 55.0 * speed * delta)
	_fly.position.y += sin(t * 30.0) * 0.4  # (buzzing)
	if froggy_near(_fly.position, REACH):
		_caught = t
		play("res://assets/pickupCoin.wav", 1.1, -8.0)
		win()


## (The pond under his lily pad.)
func _draw() -> void:
	draw_rect(Rect2(-130.0, 4.0, 260.0, 80.0), Color(0.22, 0.55, 0.70))
	draw_rect(Rect2(-130.0, 4.0, 260.0, 2.0), Color(0.72, 0.92, 0.97))
