extends "res://scripts/frenzy/Micro.gd"
## UNLOCK! The key, and the keyhole somewhere about: drag the key into it.

var _lock: Sprite2D
var _key: Sprite2D
var _held := false
var _grab := Vector2.ZERO
var _turn := -1.0


func begin() -> void:
	word = "UNLOCK!"
	seconds = 4.0
	_lock = sprite("res://assets/keyhole.png", Vector2(rng.randf_range(140, 196), rng.randf_range(70, 150)), 56.0)
	_key = sprite("res://assets/key.png", Vector2(rng.randf_range(40, 80), rng.randf_range(170, 206)), 34.0)


func press(at: Vector2) -> void:
	if not won and not lost and at.distance_to(_key.position) <= 26.0:
		_held = true
		_grab = _key.position - at


func move(at: Vector2) -> void:
	if _held:
		_key.position = at + _grab


func release(_at: Vector2) -> void:
	if not _held:
		return
	_held = false
	if _key.position.distance_to(_lock.position + Vector2(-14.0, 0.0)) <= 20.0:  # (the key's blade in the hole)
		_key.position = _lock.position + Vector2(-14.0, 0.0)
		_turn = t
		play("res://assets/pathopen.mp3", 1.2, -10.0)
		win()


func step(delta: float) -> void:
	super.step(delta)
	if _turn >= 0.0:  # (it turns, and the lock gives)
		var k := smoothstep(0.0, 0.25, t - _turn)
		_key.rotation = k * PI * 0.5
		_lock.modulate.a = 1.0 - smoothstep(0.25, 0.6, t - _turn)
