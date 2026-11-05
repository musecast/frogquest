extends "res://scripts/frenzy/Micro.gd"
## HAT! One of his hats, up there: drag it onto his head.

## His hats (his own art), each [picture, how tall its art is on him, in stage px].
const HATS := [["res://assets/froggycrown.png", 18.0], ["res://assets/froggywizhat.png", 32.0], ["res://assets/froggycakehat.png", 24.0]]
const HEAD := Vector2(120.0, 160.0)  # (his head: _on_head puts a hat's foot on top of it)

var _hat: Sprite2D
var _tall := 20.0  # (its art's height on the stage)
var _held := false
var _grab := Vector2.ZERO


func begin() -> void:
	word = "HAT!"
	seconds = 4.0
	frog(Vector2(120.0, 190.0), 56.0)
	var pick: Array = HATS[rng.randi_range(0, HATS.size() - 1)]
	_hat = sprite(pick[0], Vector2(rng.randf_range(40, 200), rng.randf_range(36, 80)), pick[1])
	# (the pictures have room round the hat: sized by the hat itself, and held by its middle)
	var art := _hat.texture.get_image().get_used_rect()
	_tall = pick[1]
	_hat.scale = Vector2.ONE * _tall / float(maxi(1, art.size.y))
	_hat.offset = _hat.texture.get_size() * 0.5 - Vector2(art.get_center())
	if absf(_hat.position.x - HEAD.x) < 40.0:
		_hat.position.x += 60.0 if _hat.position.x < HEAD.x + 20.0 else -60.0


func press(at: Vector2) -> void:
	if not won and not lost and at.distance_to(_hat.position) <= 30.0:
		_held = true
		_grab = _hat.position - at


## Where this hat's middle is when it's on: its foot just over the top of his head.
func _on_head() -> Vector2:
	return Vector2(HEAD.x, 169.0 - _tall * 0.5)


func move(at: Vector2) -> void:
	if _held:
		_hat.position = at + _grab


func release(_at: Vector2) -> void:
	if not _held:
		return
	_held = false
	if _hat.position.distance_to(_on_head()) <= 20.0:
		_hat.position = _on_head()
		play("res://assets/hat_on.wav", 1.0, -8.0)
		win()
