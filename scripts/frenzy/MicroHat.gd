extends "res://scripts/frenzy/Micro.gd"
## HAT! One of his hats, floating over a mushroom across from him: jump up into it (his own jump) and he's
## wearing it.

## His hats (his own art), each [picture, how tall its art is on him].
const HATS := [["res://assets/froggycrown.png", 12.0], ["res://assets/froggywizhat.png", 20.0], ["res://assets/froggycakehat.png", 15.0]]
const REACH := 20.0

var _hat: Sprite2D
var _tall := 12.0
var _home := Vector2.ZERO
var _worn := -1.0
var _his := []  # (his own hats, hidden while he's at this one)


func begin() -> void:
	word = "HAT!"
	seconds = 4.4
	uses_froggy = true
	view = Rect2(-120.0, -175.0, 240.0, 240.0)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	ledge(Vector2(-60.0 * side, 0.0), 80.0, "mushroom")
	froggy_at = Vector2(-60.0 * side, -FEET)
	ledge(Vector2(55.0 * side, -40.0), 70.0, "mushroom")
	_home = Vector2(55.0 * side + rng.randf_range(-10.0, 10.0), rng.randf_range(-100.0, -78.0))
	var pick: Array = HATS[rng.randi_range(0, HATS.size() - 1)]
	_hat = sprite(pick[0], _home, pick[1])
	var art := _hat.texture.get_image().get_used_rect()  # (the pictures have room round the hat: sized by the hat itself)
	_tall = pick[1]
	_hat.scale = Vector2.ONE * _tall / float(maxi(1, art.size.y))
	_hat.offset = _hat.texture.get_size() * 0.5 - Vector2(art.get_center())


func froggy_placed() -> void:
	for child in froggy.get_children():
		if child is Sprite2D and child.visible:
			_his.append(child)
			child.visible = false


func froggy_left() -> void:
	for hat in _his:
		if is_instance_valid(hat):
			hat.visible = true
	_his.clear()


func step(delta: float) -> void:
	super.step(delta)
	if _worn >= 0.0:  # (on his head, wherever he goes)
		_hat.position = froggy.global_position + Vector2(0.0, -FEET - _tall * 0.5 + 2.0)
		return
	_hat.position = _home + Vector2(0.0, sin(t * 3.0) * 3.0)  # (bobbing)
	if froggy_near(_hat.position, REACH):
		_worn = t
		play("res://assets/hat_on.wav", 1.0, -8.0)
		win()
