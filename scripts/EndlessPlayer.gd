extends CharacterBody2D

@export var move_speed: float = 250.0
@export var jump_velocity: float = -430.0
@export var gravity_scale: float = 1.0

var landed_platform_ids: Dictionary = {}

@onready var game_root: Node = get_parent()

func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale

	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * move_speed

	if is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		velocity.y = jump_velocity

	var was_on_floor := is_on_floor()
	move_and_slide()

	if is_on_floor() and not was_on_floor:
		_register_landed_platform()

func _register_landed_platform() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision == null:
			continue

		# Floor collisions have an upward-facing normal.
		if collision.get_normal().y > -0.7:
			continue

		var collider := collision.get_collider()
		if collider != null and collider.has_meta("platform_id"):
			var platform_id: int = int(collider.get_meta("platform_id"))
			game_root.register_platform_landing(platform_id)
			return
