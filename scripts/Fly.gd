extends Node2D
## One of the little flies hiding around the World Tree (FlyHunt.gd puts them there). It buzzes about
## its spot like the flies Lil Froggy hunts on the desktop (same wings, same body). Get the frog close
## enough, with nothing solid in between, and his tongue snaps it up: out to the fly, back with it.

const TONGUE_RANGE := 64.0  # how near his mouth has to come
const TONGUE_OUT := 0.08  # seconds for the tongue to reach it
const TONGUE_BACK := 0.16  # and to reel it in
const TONGUE := Color(0.95, 0.40, 0.52)
const TONGUE_EDGE := Color(0.42, 0.09, 0.17)
const WORLD_LAYER := 1  # what a tongue can't go through (the tiles)

var fly_id := ""
var _home := Vector2.ZERO
var _t := 0.0
var _phase := 0.0
var _frog: Node2D = null  # the story's Player, beside the flies in Main
var _reel := -1.0  # seconds into the tongue snap (-1: not yet)
var _snapped_from := Vector2.ZERO  # where the fly was when the tongue got it
var _caught := false
var on_caught := Callable()  # (Endless: its own points; the story's flies go to FlyHunt)
var golden := false  # (Endless's rare gold ones, worth more)


## For a fly somewhere other than the story: which frog's tongue gets it, and what catching it does.
func hunt_for(frog: Node2D, caught: Callable) -> void:
	_frog = frog
	on_caught = caught


func _ready() -> void:
	_home = position
	_phase = randf() * TAU
	_t = randf() * 3.0
	if _frog == null:
		_frog = get_parent().get_node_or_null("Player")
	# Several hide in the dark stretches: they show up there anyway (just small), lantern or not.
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	z_index = 3


## Where the frog's tongue comes from.
static func mouth_of(frog: Node2D) -> Vector2:
	return frog.global_position + Vector2(0.0, -3.0)


## Whether a mouth at mouth can get a fly at fly_pos: near enough, and no wall in between (exclude: the
## frog himself, who's on the tiles' layer too).
static func can_catch(space: PhysicsDirectSpaceState2D, mouth: Vector2, fly_pos: Vector2, exclude: Array[RID]) -> bool:
	if mouth.distance_to(fly_pos) > TONGUE_RANGE:
		return false
	var ray := PhysicsRayQueryParameters2D.create(mouth, fly_pos, WORLD_LAYER, exclude)
	return space.intersect_ray(ray).is_empty()


func _physics_process(_delta: float) -> void:
	if _reel >= 0.0 or _frog == null or not is_instance_valid(_frog) or not _frog.is_visible_in_tree():
		return
	var exclude: Array[RID] = []
	if _frog is CollisionObject2D:
		exclude.append(_frog.get_rid())  # (he's on the tiles' layer too)
	if can_catch(get_world_2d().direct_space_state, mouth_of(_frog), global_position, exclude):
		_reel = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _caught:
		return
	if _reel < 0.0:
		position = _home + Vector2(sin(_t * 1.7 + _phase) * 7.0, sin(_t * 2.9 + _phase) * 4.0)
	else:
		_reel += delta
		if _reel <= TONGUE_OUT:
			_snapped_from = global_position
		else:
			var k := minf(1.0, (_reel - TONGUE_OUT) / TONGUE_BACK)
			global_position = _snapped_from.lerp(mouth_of(_frog), k * k)
			if k >= 1.0:
				catch_now()
				return
	queue_redraw()


## Caught: the gulp, the count and the save (FlyHunt.caught), and it pops.
func catch_now() -> void:
	if _caught:
		return
	_caught = true
	queue_redraw()
	if on_caught.is_valid():
		on_caught.call(self)
	else:
		load("res://scripts/FlyHunt.gd").caught(self)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.8, 1.8), 0.08)
	pop.tween_property(self, "modulate:a", 0.0, 0.12)
	pop.tween_callback(queue_free)


func _draw() -> void:
	if _reel >= 0.0 and not _caught and is_instance_valid(_frog):
		var mouth := to_local(mouth_of(_frog))
		var tip := mouth.lerp(Vector2.ZERO, minf(1.0, _reel / TONGUE_OUT)) if _reel <= TONGUE_OUT else Vector2.ZERO
		draw_line(mouth, tip, TONGUE_EDGE, 4.0)
		draw_line(mouth, tip, TONGUE, 2.4)
		draw_circle(tip, 2.6, TONGUE_EDGE)
		draw_circle(tip, 1.8, TONGUE)
	var lift := 2.2 if fmod(_t * 28.0, 2.0) < 1.0 else 0.7
	var wing := Color(0.85, 0.92, 1.0, 0.85)
	draw_rect(Rect2(Vector2(-3.6, -lift - 0.8), Vector2(2.6, 1.8)), wing)
	draw_rect(Rect2(Vector2(1.0, -lift - 0.8), Vector2(2.6, 1.8)), wing)
	draw_rect(Rect2(Vector2(-1.5, -1.5), Vector2(3.0, 3.0)), Color(1.0, 0.78, 0.18) if golden else Color(0.12, 0.12, 0.14))
	if golden and fmod(_t * 2.0 + _phase, 1.0) < 0.5:
		draw_rect(Rect2(Vector2(2.5, -4.0), Vector2(1.5, 1.5)), Color(1.0, 0.96, 0.7))  # (it sparkles)
	if fmod(_t + _phase, 3.4) < 0.2:
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 0.8, 0.22))  # (a glint now and then, for sharp eyes)
