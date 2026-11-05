extends Node2D
## Froggy's slingshot: press, drag back, let go, and he jumps the other way, harder the further you
## dragged. The story was built around the original's numbers, so they're kept to the number wherever they
## ran smoothly: every short and medium drag, every upright one, and full power (launch_for). Where they
## jumped (a strong-but-not-full sideways drag suddenly flew 200 slower: the aim line hitched as you pulled),
## they're joined up evenly, with every jump the original could make still there to make. Around them:
## - A jump let go a moment after he's left a platform's edge still goes (COYOTE_MS), and a press made
##   just before he lands is kept for when he does, so a jump isn't lost to a wobble on a moving platform
##   or a tap a hair too early.
## - The aim line points where he'll actually go (flight_velocity: the launch, less the tick of standing
##   friction before he's off the platform; and off a mushroom, the mushroom's throw: shown_velocity).

const COYOTE_MS := 120  # (ms after leaving a platform that a jump still goes)
const FLOOR_FRICTION := 300.0  # (the frog's SPEED: how much standing slows him sideways each tick)
const KNEE := 350.0  # (sideways stretch up to which a jump is the original's to the number)
const FULL := 800.0  # (sideways stretch at full power: the original's cap)
const FULL_FLIGHT := 500.0  # (how fast full power sends him sideways: the original's, after the friction tick)

var mouseOrigin = Vector2()
var mousePosition = Vector2()
var mousePath = Vector2()
var cursorLock = false
var endGame = 1
var sensitivity = 4.0  # (the settings' Sensitivity: MusicManager.sensitivity, from _ready)

var _floor_ms := -100000  # when he was last on a platform
var _was_grounded := false
var _cursor_closed: Texture2D
var _cursor_open: Texture2D
var _cursor_x: Texture2D

func _supports_desktop_mouse() -> bool:
	var platform := OS.get_name()
	return platform != "iOS" and platform != "Android"


func _set_custom_cursor(texture: Texture2D) -> void:
	if _supports_desktop_mouse():
		Input.set_custom_mouse_cursor(texture)


func _ready():
	sensitivity = MusicManager.sensitivity
	if _supports_desktop_mouse():
		_cursor_closed = load("res://assets/cursorclosed.png")
		_cursor_open = load("res://assets/cursoropen.png")
		_cursor_x = load("res://assets/cursor-x.png")


## Where a drag sends him, for the jump and the aim line alike (launch_for).
func launch_velocity(path: Vector2) -> Vector2:
	return launch_for(path, sensitivity)


## The launch for a drag (before the one tick of standing friction it gets). Upward it's the original's:
## stretched 1.1, capped at 450. Sideways the original stretched 1.5, capped at 800, and gave drags under
## 450 a push of 200 (and steep ones under 250 another 50) that the friction tick takes back; past 450 the
## push stopped, so pulling further suddenly flew 200 slower. Here the flight is the original's up to KNEE
## (and for steep drags the extra 50, faded out from 200 to 300 instead of stopping at 250), then rises
## evenly to full power's 500. A near-upright drag still gets the small push, so it goes straight up and a
## mushroom still feels it moving sideways.
static func launch_for(path: Vector2, sensitivity: float) -> Vector2:
	var stretch := path * sensitivity
	var vy := clampf(stretch.y * 1.1, -450.0, 450.0)
	var ax := minf(absf(stretch.x * 1.5), FULL)
	var side := signf(stretch.x)
	var steep := smoothstep(330.0, 370.0, absf(vy))
	var fly := flight_x(ax, steep)
	if fly <= 0.0:
		return Vector2(side * minf(ax + 200.0 + 50.0 * steep, FLOOR_FRICTION), vy)
	return Vector2(side * (fly + FLOOR_FRICTION), vy)


## How fast a drag this strong sideways (0 to FULL) sends him sideways, once he's off the ground; steep is
## 0 to 1, how upright the drag is (the original's extra push for steep drags).
static func flight_x(ax: float, steep: float) -> float:
	if ax <= KNEE:
		var push := 50.0 * steep * clampf((300.0 - ax) / 100.0, 0.0, 1.0)
		return maxf(0.0, ax - 100.0 + push)
	var at_knee := KNEE - 100.0
	return at_knee + (ax - KNEE) * (FULL_FLIGHT - at_knee) / (FULL - KNEE)

## Where he really goes: the launch, less the one tick of standing friction it gets before he's off the
## platform (on the frame he jumps he's still standing, and standing he's slowed by his SPEED sideways;
## the push short drags get makes up for it). So a near-upright drag goes, and shows, near straight up.
func flight_velocity(path: Vector2) -> Vector2:
	var v := launch_velocity(path)
	v.x = move_toward(v.x, 0.0, FLOOR_FRICTION)
	return v


## What letting go gives him: on the ground, the launch (the friction tick takes the push back); just off
## an edge, where there's no friction tick, the flight itself, so he goes where the line showed.
func release_velocity(path: Vector2) -> Vector2:
	return launch_velocity(path) if get_parent().is_on_floor() else flight_velocity(path)


## What the aim line shows: the flight, and standing on a mushroom (or the bed), the mushroom's throw
## instead of his own upward speed, the way the TileMap gives it the moment he lets go moving sideways
## (scenes/TileMap.gd). Before, the line showed a little hop and the mushroom threw him sky high.
func shown_velocity(path: Vector2) -> Vector2:
	var v := flight_velocity(path)
	var frog := get_parent()
	var map := frog.get_node_or_null("../TileMap")
	if map and map.has_method("pad_jump_at") and frog.is_on_floor() and launch_velocity(path).x != 0.0:
		var pad: float = map.pad_jump_at(frog.position)
		if pad != 0.0:
			v.y = pad
	return v


## A press on a button (pause) isn't the start of a jump.
func _over_button() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	return c != null and (c is BaseButton or c.get_parent() is BaseButton)


## On a platform, or only just off one (COYOTE_MS).
func can_jump() -> bool:
	return get_parent().is_on_floor() or Time.get_ticks_msec() - _floor_ms <= COYOTE_MS


func _process(delta):
	# (not while he's waking up at home, a tap's for the TV's words till the tutorial's up; nor while he's
	# shivering after a hard landing)
	var free: bool = not get_parent().has_method("can_act") or get_parent().can_act()
	if Engine.time_scale != 0.05 and Engine.time_scale != 0.0 and endGame == 0 and free:
		var grounded: bool = get_parent().is_on_floor()
		if grounded:
			_floor_ms = Time.get_ticks_msec()
		var can_go := can_jump()
		if Input.is_action_just_pressed("ui_mouse") and not _over_button():
			if cursorLock == true and _supports_desktop_mouse():
				Input.mouse_mode = 4
				get_viewport().warp_mouse(Vector2(160,15))
			elif _supports_desktop_mouse():
				Input.mouse_mode = 0
			mouseOrigin = get_global_mouse_position()  # (in the air too: kept for when he lands)
			if can_go:
				$"../frogaim".play()
		elif grounded and not _was_grounded and Input.is_action_pressed("ui_mouse") and mouseOrigin != Vector2(0, 0):
			$"../frogaim".play()  # (pressed just before landing: now it's an aim)
		_was_grounded = grounded

		if Input.is_action_pressed("ui_mouse") and mouseOrigin != Vector2(0, 0):
			mousePosition = get_global_mouse_position()
			mousePath = mouseOrigin - mousePosition
			queue_redraw()
		_set_custom_cursor(_cursor_x if not can_go else (_cursor_closed if Input.is_action_pressed("ui_mouse") else _cursor_open))

		if Input.is_action_just_released("ui_mouse"):
			if can_go and mouseOrigin != Vector2(0, 0):
				get_parent().velocity = release_velocity(mousePath)
				_floor_ms = -100000  # (one jump per moment off the edge)
				$"../frogjump".pitch_scale = randf_range(0.8, 1.2)
				$"../frogjump".play()
				$"..".jumpCount += 1
				if get_parent().has_method("jumped"):
					get_parent().jumped()  # (a little puff of dust from under him)
			mouseOrigin = Vector2(0, 0)
			mousePath = Vector2(0, 0)
			mousePosition = Vector2(0, 0)
			queue_redraw()


## The aim line: as much of the jump as the difficulty shows, redder the stronger it is (AimLine).
func _draw():
	if Input.is_action_pressed("ui_mouse") and mouseOrigin != Vector2(0, 0) and can_jump():
		var launch := shown_velocity(mousePath)
		var power := clampf(launch_velocity(mousePath).length() / Vector2(800, 450).length(), 0.0, 1.0)
		var mode: String = load("res://scripts/Difficulty.gd").current()
		load("res://scripts/AimLine.gd").draw(self, get_parent(), launch, power, mode, mousePath, sensitivity)


func _on_cursor_lock_button_pressed():
	cursorLock = !cursorLock
