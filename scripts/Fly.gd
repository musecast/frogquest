extends Area2D
## One of the little flies hiding around the World Tree (FlyHunt.gd puts them there). It buzzes about
## its spot like the flies Lil Froggy hunts on the desktop (same wings, same body); touch it to catch it.

const PLAYER_LAYER := 8  # player.tscn's collision_layer is 9: this is its own bit (the tiles use 1)

var fly_id := ""
var _home := Vector2.ZERO
var _t := 0.0
var _phase := 0.0
var _caught := false


func _ready() -> void:
	_home = position
	_phase = randf() * TAU
	_t = randf() * 3.0
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# Several hide in the dark stretches: they show up there anyway (just small), lantern or not.
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 3


func _process(delta: float) -> void:
	_t += delta
	if _caught:
		return
	position = _home + Vector2(sin(_t * 1.7 + _phase) * 7.0, sin(_t * 2.9 + _phase) * 4.0)
	queue_redraw()


func _draw() -> void:
	var lift := 2.2 if fmod(_t * 28.0, 2.0) < 1.0 else 0.7
	var wing := Color(0.85, 0.92, 1.0, 0.85)
	draw_rect(Rect2(Vector2(-3.6, -lift - 0.8), Vector2(2.6, 1.8)), wing)
	draw_rect(Rect2(Vector2(1.0, -lift - 0.8), Vector2(2.6, 1.8)), wing)
	draw_rect(Rect2(Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), Color(0.12, 0.12, 0.14))
	if fmod(_t + _phase, 3.4) < 0.2:
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 0.8, 0.22))  # (a glint now and then, for sharp eyes)


func _on_body_entered(body: Node) -> void:
	if _caught or not body.has_method("save_game"):
		return
	_caught = true
	queue_redraw()
	load("res://scripts/FlyHunt.gd").caught(self)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.8, 1.8), 0.08)
	pop.tween_property(self, "modulate:a", 0.0, 0.12)
	pop.tween_callback(queue_free)
