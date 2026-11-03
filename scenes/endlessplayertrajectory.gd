extends Node2D
## Froggy's slingshot in Endless, as the story's (scripts/Trajectory.gd): the drag-to-jump numbers are the
## original's (launch_velocity), times a spring's boost; a jump let go just after leaving a platform's
## edge still goes, a press just before landing is kept for the landing, and the aim line points where
## he'll really go (gold and longer off a spring).

const COYOTE_MS := 120  # (ms after leaving a platform that a jump still goes)

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


## Where a drag sends him: the original's numbers (the sideways stretch, the push short drags get, the
## caps), times a spring's boost, for the jump and the aim line alike.
func launch_velocity(path: Vector2) -> Vector2:
	var velocity: Vector2 = path * sensitivity
	velocity.x *= 1.5
	velocity.y *= 1.1
	velocity.x = clampf(velocity.x, -800, 800)
	velocity.y = clampf(velocity.y, -450, 450)
	if absf(velocity.x) < 450:
		velocity.x = 200 * signf(velocity.x) + velocity.x
	if absf(velocity.x) < 450 and absf(velocity.y) > 350:
		velocity.x = 50 * signf(velocity.x) + velocity.x
	if get_parent().has_method("launch_boost"):
		velocity *= get_parent().launch_boost()  # (off a spring: much higher)
	return velocity


## On a platform, or only just off one (COYOTE_MS).
func can_jump() -> bool:
	return get_parent().is_on_floor() or infinijump == 1 or Time.get_ticks_msec() - _floor_ms <= COYOTE_MS


func _process(delta):
	if Engine.time_scale != 0.05 and Engine.time_scale != 0.0 and endGame == 0:
		var grounded: bool = get_parent().is_on_floor()
		if grounded:
			_floor_ms = Time.get_ticks_msec()
		var can_go := can_jump()
		if Input.is_action_just_pressed("ui_mouse"):
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
				get_parent().velocity = launch_velocity(mousePath)
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
		var launch := launch_velocity(mousePath)
		var boost: float = get_parent().launch_boost() if get_parent().has_method("launch_boost") else 1.0
		if boost > 1.0:  # on a spring: longer, in spring gold
			draw_line(Vector2(0,0), launch / 10.8, Color(1.0, 0.86, 0.3, 1), 3.0)
		else:
			var power := clampf(launch.length() / Vector2(800, 450).length(), 0.0, 1.0)
			draw_line(Vector2(0,0), launch / 10.8, Color(255, 1.2 - power, 1.2 - power, 1), 2.0)


func _on_cursor_lock_button_pressed():

	cursorLock = !cursorLock
