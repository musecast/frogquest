extends "res://scripts/frenzy/Micro.gd"
## UNLOCK! He's got the key (over his head); the lock's up across from him: jump up into its keyhole (his
## own jump) and the key turns and the lock gives.

const REACH := 20.0

var _lock: Sprite2D
var _key: Sprite2D
var _hole := Vector2.ZERO
var _turn := -1.0


func begin() -> void:
	word = "UNLOCK!"
	seconds = 4.4
	uses_froggy = true
	view = Rect2(-120.0, -175.0, 240.0, 240.0)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	ledge(Vector2(-55.0 * side, 0.0), 80.0, "island")
	froggy_at = Vector2(-55.0 * side, -FEET)
	_lock = sprite("res://assets/keyhole.png", Vector2(60.0 * side, rng.randf_range(-92.0, -72.0)), 34.0)
	_hole = _lock.position
	_key = sprite("res://assets/key.png", froggy_at + Vector2(0.0, -24.0), 14.0)


func step(delta: float) -> void:
	super.step(delta)
	if _turn >= 0.0:  # (in, and turning; the lock giving)
		var k := smoothstep(0.0, 0.25, t - _turn)
		_key.position = _hole
		_key.rotation = k * PI * 0.5
		_lock.modulate.a = 1.0 - smoothstep(0.25, 0.6, t - _turn)
		return
	if froggy:  # (held up over his head)
		_key.position = froggy.global_position + Vector2(0.0, -FEET - 10.0)
	if froggy_near(_hole, REACH):
		_turn = t
		play("res://assets/pathopen.mp3", 1.2, -10.0)
		win()
