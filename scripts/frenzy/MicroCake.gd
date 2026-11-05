extends "res://scripts/frenzy/Micro.gd"
## EAT! The upside-down pineapple race: him and the farmer frog, a cake each. Every tap's a bite; finish his
## before the farmer frog finishes theirs.

var _mine: Sprite2D
var _theirs: Sprite2D
var _him: Sprite2D
var _them: Sprite2D
var _bites := 0
var _need := 8
var _rival := 0.0  # (how far through theirs the farmer frog is: 0 to 1)


func begin() -> void:
	word = "EAT!"
	seconds = 4.0
	_need = 8 + int((speed - 1.0) * 10.0)
	_him = frog(Vector2(66.0, 138.0), 44.0)
	_them = sprite("res://assets/farmerfrog.png", Vector2(174.0, 134.0), 52.0)
	_mine = sprite("res://assets/Pineapple_Upside-Down_Cake.png", Vector2(66.0, 190.0), 62.0)
	_theirs = sprite("res://assets/Pineapple_Upside-Down_Cake.png", Vector2(174.0, 190.0), 62.0)
	for c in [_mine, _theirs]:
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # (the cake's a painting, not pixel art)


func press(_at: Vector2) -> void:
	if won or lost:
		return
	_bites += 1
	play("res://assets/jump.wav", randf_range(1.5, 1.8), -12.0)
	_him.scale = Vector2(1.15, 0.85) * 44.0 / 32.0
	_show(_mine, float(_bites) / _need)
	if _bites >= _need:
		play("res://assets/pickupCoin.wav", 1.0, -8.0)
		win()


func step(delta: float) -> void:
	super.step(delta)
	_him.scale = _him.scale.lerp(Vector2.ONE * 44.0 / 32.0, 1.0 - exp(-delta * 14.0))
	if won or lost:
		return
	_rival = clampf(t / (seconds / speed * 0.82), 0.0, 1.0)
	_show(_theirs, _rival)
	_them.position.y = 134.0 - absf(sin(t * 14.0)) * 2.0
	if _rival >= 1.0:
		lose()


## A cake that much eaten: smaller and smaller, then just its plate.
func _show(cake: Sprite2D, eaten: float) -> void:
	if eaten >= 1.0:
		cake.texture = load("res://assets/Pineapple_Upside-Down_Cake_EATEN.png")
		cake.scale = Vector2.ONE * 62.0 / 360.0
		return
	cake.scale = Vector2.ONE * (62.0 / 360.0) * (1.0 - 0.45 * eaten)
