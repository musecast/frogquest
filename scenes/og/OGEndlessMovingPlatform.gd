extends StaticBody2D

var time: float = 0.0
var start_x: float = 0.0

@export var speed: float = 1.5
@export var move_range: float = 80.0

func _ready() -> void:
	time = randf_range(0.0, TAU)
	start_x = position.x
	position.x = start_x + sin(time) * move_range

func _physics_process(delta: float) -> void:
	var old_x := position.x
	time += delta * speed
	position.x = start_x + sin(time) * move_range
	# Keep constant_linear_velocity so the player is carried while standing on the platform.
	# The player script strips this out of velocity on jump so it doesn't affect launch momentum.
	constant_linear_velocity.x = (position.x - old_x) / delta
