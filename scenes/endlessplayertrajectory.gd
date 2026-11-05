extends Node2D
## Froggy's slingshot in Endless, as the story's (scripts/Trajectory.gd): the drag-to-jump numbers are the
## story's (launch_velocity: the original's, joined up smoothly where they jumped), times a spring's boost;
## a jump let go just after leaving a platform's edge still goes, a press just before landing is kept for
## the landing, and the aim line points where he'll really go (flight_velocity; gold and longer off a
## spring).

const COYOTE_MS := 120  # (ms after leaving a platform that a jump still goes)
const FLOOR_FRICTION := 300.0  # (the frog's SPEED: how much standing slows him sideways each tick)

var mouseOrigin = Vector2()
var mousePosition = Vector2()
var mousePath = Vector2()
var cursorLock = false
var endGame = 0
var sensitivity = 3.5
var infinijump = 0

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
	if _supports_desktop_mouse():
		_cursor_closed = load("res://assets/cursorclosed.png")
		_cursor_open = load("res://assets/cursoropen.png")
		_cursor_x = load("res://assets/cursor-x.png")


## Where a drag sends him: the story's slingshot (Trajectory.launch_for: the original's numbers, joined up
## smoothly where they jumped), times a spring's boost, for the jump and the aim line alike.
func launch_velocity(path: Vector2) -> Vector2:
	var velocity: Vector2 = load("res://scripts/Trajectory.gd").launch_for(path, sensitivity)
	if get_parent().has_method("launch_boost"):
		velocity *= get_parent().launch_boost()  # (off a spring: much higher)
	return velocity

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


## A press on a button (pause) isn't the start of a jump.
func _over_button() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	return c != null and (c is BaseButton or c.get_parent() is BaseButton)


## On a platform, or only just off one (COYOTE_MS).
func can_jump() -> bool:
	return get_parent().is_on_floor() or infinijump == 1 or Time.get_ticks_msec() - _floor_ms <= COYOTE_MS


func _process(delta):
	if Engine.time_scale != 0.05 and Engine.time_scale != 0.0 and endGame == 0:
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
			mouseOrigin = Vector2(0, 0)
			mousePath = Vector2(0, 0)
			mousePosition = Vector2(0, 0)
			queue_redraw()


## The aim line: along the jump he'll make, longer and whiter the stronger it is; off a spring, gold.
func _draw():
	if Input.is_action_pressed("ui_mouse") and mouseOrigin != Vector2(0, 0) and can_jump():
		var launch := flight_velocity(mousePath)
		var boost: float = get_parent().launch_boost() if get_parent().has_method("launch_boost") else 1.0
		var power := clampf(launch_velocity(mousePath).length() / boost / Vector2(800, 450).length(), 0.0, 1.0)
		var mode: String = load("res://scripts/Difficulty.gd").current()
		# (as much of the jump as the difficulty shows, as the story's: AimLine; on a spring, gold all along)
		load("res://scripts/AimLine.gd").draw(self, get_parent(), launch, power, mode, mousePath, boost > 1.0)


func _on_cursor_lock_button_pressed():

	cursorLock = !cursorLock
