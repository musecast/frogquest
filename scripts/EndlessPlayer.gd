extends CharacterBody2D

@export var launch_sensitivity: float = 3.5
@export var x_multiplier: float = 1.5
@export var y_multiplier: float = 1.1
@export var max_launch_x: float = 800.0
@export var max_launch_y: float = 450.0
@export var min_horizontal_boost_threshold: float = 450.0
@export var horizontal_boost: float = 200.0
@export var extra_boost_for_steep_shots: float = 50.0

var landed_platform_ids: Dictionary = {}

var mouse_origin: Vector2 = Vector2.ZERO
var mouse_position: Vector2 = Vector2.ZERO
var mouse_path: Vector2 = Vector2.ZERO
var _cursor_closed: Texture2D
var _cursor_open: Texture2D
var _cursor_x: Texture2D

@onready var game_root: Node = get_parent()

func _supports_desktop_mouse() -> bool:
	var platform := OS.get_name()
	return platform != "iOS" and platform != "Android"


func _set_custom_cursor(texture: Texture2D) -> void:
	if _supports_desktop_mouse():
		Input.set_custom_mouse_cursor(texture)


func _ready() -> void:
	if _supports_desktop_mouse():
		_cursor_closed = load("res://assets/cursorclosed.png")
		_cursor_open = load("res://assets/cursoropen.png")
		_cursor_x = load("res://assets/cursor-x.png")
		_set_custom_cursor(_cursor_open)

func _physics_process(delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

	if not is_on_floor():
		velocity.y += gravity * delta

	var was_on_floor: bool = is_on_floor()
	move_and_slide()

	if is_on_floor() and not was_on_floor:
		_register_landed_platform()

func _process(_delta: float) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("ui_mouse"):
			mouse_origin = get_global_mouse_position()

		if Input.is_action_pressed("ui_mouse"):
			_set_custom_cursor(_cursor_closed)
			mouse_position = get_global_mouse_position()
			if mouse_origin != Vector2.ZERO:
				mouse_path = mouse_origin - mouse_position
		else:
			_set_custom_cursor(_cursor_open)

		if Input.is_action_just_released("ui_mouse") and mouse_origin != Vector2.ZERO:
			_launch_from_mouse_drag()
	else:
		_set_custom_cursor(_cursor_x)

func _launch_from_mouse_drag() -> void:
	var launch_velocity: Vector2 = mouse_path * launch_sensitivity
	launch_velocity.x *= x_multiplier
	launch_velocity.y *= y_multiplier
	launch_velocity.x = clampf(launch_velocity.x, -max_launch_x, max_launch_x)
	launch_velocity.y = clampf(launch_velocity.y, -max_launch_y, max_launch_y)

	if absf(launch_velocity.x) < min_horizontal_boost_threshold:
		launch_velocity.x += horizontal_boost * signf(launch_velocity.x)

	if absf(launch_velocity.x) < min_horizontal_boost_threshold and absf(launch_velocity.y) > 350.0:
		launch_velocity.x += extra_boost_for_steep_shots * signf(launch_velocity.x)

	velocity = launch_velocity
	mouse_origin = Vector2.ZERO
	mouse_path = Vector2.ZERO
	mouse_position = Vector2.ZERO
	_set_custom_cursor(_cursor_open)

func _register_landed_platform() -> void:
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		if collision == null:
			continue

		# Floor collisions have an upward-facing normal.
		if collision.get_normal().y > -0.7:
			continue

		var collider: Object = collision.get_collider()
		if collider != null and collider.has_meta("platform_id"):
			var platform_id: int = int(collider.get_meta("platform_id"))
			game_root.register_platform_landing(platform_id)
			return
