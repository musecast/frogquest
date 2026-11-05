extends "res://scripts/frenzy/Micro.gd"
## CATCH! A fly zips about over him: tap it, and his tongue's out after it.

const FLY := [".WW.....WW.", "WWWW...WWWW", "WWWWW.WWWWW", ".WWWKKKWWW.", "...KBBBK...", "..KRBBBRK..", "..KBBBBBK..",
	"...KBBBK..."]
const COLOURS := {"W": Color(0.82, 0.92, 1.0, 0.9), "K": Color(0.97, 0.92, 0.80), "B": Color(0.20, 0.18, 0.26), "R": Color(0.9, 0.2, 0.2)}

var _fly: Node2D
var _goal := Vector2.ZERO
var _him: Sprite2D
var _tongue := -1.0
var _caught_at := Vector2.ZERO


func begin() -> void:
	word = "CATCH!"
	seconds = 3.6
	_him = frog(Vector2(120.0, 206.0), 44.0)
	_fly = Node2D.new()
	_fly.position = Vector2(rng.randf_range(50, 190), rng.randf_range(40, 120))
	_fly.draw.connect(func() -> void:
		for y in FLY.size():
			for x in str(FLY[y]).length():
				var ch := str(FLY[y])[x]
				if COLOURS.has(ch):
					_fly.draw_rect(Rect2(Vector2(x - 5.5, y - 4.0) * 1.6, Vector2(1.6, 1.6)), COLOURS[ch]))
	add_child(_fly)
	_goal = _fly.position


func press(at: Vector2) -> void:
	if won or lost:
		return
	if at.distance_to(_fly.position) <= 22.0:
		_tongue = t
		_caught_at = _fly.position
		play("res://assets/pickupCoin.wav", 1.1, -8.0)
		win()


func step(delta: float) -> void:
	super.step(delta)
	queue_redraw()
	if won:
		_fly.visible = t - _tongue < 0.08
		return
	if _fly.position.distance_to(_goal) < 6.0:
		_goal = Vector2(rng.randf_range(30, 210), rng.randf_range(30, 140))
	_fly.position = _fly.position.move_toward(_goal, 130.0 * speed * delta)
	_fly.position.y += sin(t * 30.0) * 0.6  # (buzzing)


func _draw() -> void:
	if _tongue >= 0.0 and t - _tongue < 0.18:  # (his tongue, out to it and back)
		var reach := sin(clampf((t - _tongue) / 0.18, 0.0, 1.0) * PI)
		var mouth := Vector2(120.0, 198.0)
		draw_line(mouth, mouth.lerp(_caught_at, reach), Color(0.95, 0.45, 0.55), 3.0)
