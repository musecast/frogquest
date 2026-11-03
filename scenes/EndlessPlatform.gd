extends StaticBody2D
## One of Endless's platforms, built in code: how it looks (KINDS: a 3-slice pixel-art strip from
## assets/endless, drawn at any width, with a stalk or trunk hanging under it for the ones that grow),
## and what it does. It can stand still, sway side to side, bob up and down or drift in a loop; crumble
## a moment after you land on it; or carry a spring that sends your next jump far higher.
## Its origin is the middle of its walkable top.

const ART := "res://assets/endless/%s.png"
# kind: [end piece width, middle piece width, walkable row in the strip, what hangs under it]
const KINDS := {
	"lilypad": [14, 16, 2, ""],
	"mushroom": [12, 16, 1, "stalk"],
	"mushroom_red": [12, 16, 1, "stalk"],
	"canopy": [18, 18, 2, "trunk"],
	"twig": [8, 16, 1, ""],
	"cloud": [16, 20, 10, ""],
	"puff": [16, 20, 10, ""],
	"island": [18, 18, 1, ""],
	"island_crack": [18, 18, 1, ""],
	"asteroid": [12, 16, 1, ""],
	"asteroid_crack": [12, 16, 1, ""],
	"satellite": [10, 12, 1, ""],
}
const THICKNESS := 10.0  # how deep the solid part is under the walkable top
const UNDER_LENGTH := 150.0  # how far a stalk or trunk hangs down before it fades out
const CRUMBLE_DELAY := 0.6  # seconds from landing to falling

var kind := "mushroom"
var width := 96.0
var motion := ""  # "", "sway", "bob" or "drift"
var motion_speed := 1.0
var motion_range := 50.0
var crumbles := false
var spring := false
var coil := true  # (a spring shows as a coil set in its top, except on a kind that's bouncy itself)
var flower := false  # (the first lily pad's lotus)
var phase := -1.0  # where a moving one starts its swing (EndlessMode deals it from the tower's dice; -1: any)
var clock := Callable()  # in a party, the party's clock in seconds (Party.run_seconds): everyone's swing together

var _strip: Texture2D
var _under: Texture2D
var _under_node: Node2D
var _spring_up: Texture2D
var _spring_down: Texture2D
var _flower_tex: Texture2D
var _home := Vector2.ZERO
var _t := 0.0
var _shape: CollisionShape2D
var _crumble_left := -1.0  # seconds until it falls (-1: not yet landed on)
var _falling := false
var _fall_speed := 0.0
var _squash := 0.0  # the spring pressed down (1) or up (0)
var _spring_kick := 0.0  # the spring's boing as you leave it


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art: Array = KINDS.get(kind, KINDS["mushroom"])
	_strip = load(ART % kind)
	if art[3] != "":
		_under = load(ART % art[3])
		# (drawn by a child a layer down, so every stalk and trunk is behind every platform)
		_under_node = Node2D.new()
		_under_node.z_index = -1
		_under_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_under_node.draw.connect(_draw_under)
		add_child(_under_node)
	if spring:
		set_meta("spring", true)
		if coil:
			_spring_up = load(ART % "spring")
			_spring_down = load(ART % "spring_down")
	if flower:
		_flower_tex = load(ART % "lotus")
	var box := RectangleShape2D.new()
	box.size = Vector2(width, THICKNESS)
	_shape = CollisionShape2D.new()
	_shape.shape = box
	_shape.position = Vector2(0.0, THICKNESS * 0.5)
	_shape.one_way_collision = true
	add_child(_shape)
	_home = position
	_t = phase if phase >= 0.0 else randf() * TAU
	if clock.is_valid():
		_t = phase + float(clock.call()) * motion_speed
	if motion != "":
		position = _target(_t)


func _target(t: float) -> Vector2:
	match motion:
		"sway":
			return _home + Vector2(sin(t) * motion_range, 0.0)
		"bob":
			return _home + Vector2(0.0, sin(t) * motion_range * 0.35)
		"drift":
			return _home + Vector2(sin(t) * motion_range, sin(t * 2.0) * motion_range * 0.2)
	return _home


func _physics_process(delta: float) -> void:
	if _falling:
		_fall_speed += 900.0 * delta
		position.y += _fall_speed * delta
		modulate.a = maxf(0.0, modulate.a - delta * 2.0)
		if modulate.a <= 0.0:
			queue_free()
		return
	if motion != "":
		var before := position
		_t = phase + float(clock.call()) * motion_speed if clock.is_valid() else _t + delta * motion_speed
		position = _target(_t)
		# (so he's carried standing on it; endlessplayer.gd takes it back off his jump)
		constant_linear_velocity = (position - before) / delta
	if _crumble_left >= 0.0:
		_crumble_left -= delta
		if _crumble_left <= 0.0:
			_fall()


func _process(delta: float) -> void:
	if spring:
		_squash = move_toward(_squash, 0.0, delta * 3.0) if _spring_kick <= 0.0 else 0.0
		_spring_kick = maxf(0.0, _spring_kick - delta)
	if spring or _crumble_left >= 0.0:
		queue_redraw()


## He's landed on it (EndlessMode.gd, the first frame he touches down).
func landed() -> void:
	if spring:
		_squash = 1.0
	if crumbles and _crumble_left < 0.0 and not _falling:
		_crumble_left = CRUMBLE_DELAY
		_sound("res://assets/glasshurt.wav", 1.6, -14.0)


## He's jumped off it.
func launched() -> void:
	if spring:
		_spring_kick = 0.25
		_squash = 0.0
		_sound("res://assets/powerUp.wav", 1.25, -10.0)
	queue_redraw()


## True while it's still there to stand on (a crumbling one isn't, once it's gone).
func is_solid() -> bool:
	return not _falling


func _fall() -> void:
	_falling = true
	_shape.set_deferred("disabled", true)
	constant_linear_velocity = Vector2.ZERO


func _sound(path: String, pitch: float, db: float) -> void:
	var s := AudioStreamPlayer.new()
	s.stream = load(path)
	s.pitch_scale = pitch
	s.volume_db = db
	add_child(s)
	s.play()
	s.finished.connect(s.queue_free)


## What hangs under it (a stalk, a trunk), fading out downward.
func _draw_under() -> void:
	var art: Array = KINDS.get(kind, KINDS["mushroom"])
	var uw: float = _under.get_width()
	var uh: float = _under.get_height()
	var ux := -roundf(uw * 0.5)
	var y: float = -float(art[2]) + _strip.get_height() - 3.0
	while y < UNDER_LENGTH:
		_under_node.draw_texture(_under, Vector2(ux, y), Color(1, 1, 1, clampf(1.0 - y / UNDER_LENGTH, 0.0, 1.0)))
		y += uh


func _draw() -> void:
	if _strip == null:
		return
	var art: Array = KINDS.get(kind, KINDS["mushroom"])
	var cap: float = art[0]
	var mid: float = art[1]
	var top_row: float = art[2]
	var h: float = _strip.get_height()
	var shake := Vector2.ZERO
	if _crumble_left >= 0.0:  # a wobble while it's about to go
		var k := 1.0 - _crumble_left / CRUMBLE_DELAY
		shake = Vector2(sin(Time.get_ticks_msec() * 0.06) * (0.6 + k * 1.6), 0.0).round()
	var x0 := -roundf(width * 0.5) + shake.x
	var y0 := -top_row
	if _under_node:
		_under_node.queue_redraw()
	# The strip: left end, the middle tiled across, right end.
	draw_texture_rect_region(_strip, Rect2(x0, y0, cap, h), Rect2(0, 0, cap, h))
	var x := x0 + cap
	var right := x0 + width - cap
	while x < right:
		var w := minf(mid, right - x)
		draw_texture_rect_region(_strip, Rect2(x, y0, w, h), Rect2(cap, 0, w, h))
		x += mid
	draw_texture_rect_region(_strip, Rect2(right, y0, cap, h), Rect2(cap + mid, 0, cap, h))
	if _flower_tex:
		draw_texture(_flower_tex, Vector2(roundf(width * 0.18), -_flower_tex.get_height() + 1.0))
	if _spring_up:
		# Its plate level with the top (he stands on it), its coil set down into the platform; pressed
		# in while he's on it, overshooting a little as it lets go.
		var tex := _spring_down if _squash > 0.5 else _spring_up
		var y := 1.0 if _squash > 0.5 else (-4.0 if _spring_kick > 0.12 else -1.0)
		draw_texture(tex, Vector2(-roundf(tex.get_width() * 0.5) + shake.x, y))
