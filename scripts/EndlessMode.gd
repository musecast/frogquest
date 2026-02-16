extends Node2D

@export var platform_scene: PackedScene
@export var generation_ahead_distance: float = 900.0
@export var cleanup_distance_below_player: float = 500.0
@export var min_vertical_gap: float = 70.0
@export var max_vertical_gap: float = 110.0
@export var max_horizontal_step: float = 95.0
@export var min_x: float = -220.0
@export var max_x: float = 220.0

var score: int = 0
var next_platform_id: int = 1
var highest_generated_y: float = 0.0
var last_generated_x: float = 0.0

@onready var player: CharacterBody2D = $Player
@onready var platforms: Node2D = $Platforms
@onready var score_label: Label = $CanvasLayer/ScoreLabel

func _ready() -> void:
	randomize()
	_update_score_label()

	# Seed starter platforms.
	_create_platform(Vector2(0, 0))
	highest_generated_y = 0.0
	last_generated_x = 0.0

	for _i in range(20):
		_generate_one_platform_above()

func _process(_delta: float) -> void:
	_generate_platforms_if_needed()
	_cleanup_old_platforms()

func register_platform_landing(platform_id: int) -> void:
	if player.landed_platform_ids.has(platform_id):
		return

	player.landed_platform_ids[platform_id] = true
	score += 1
	_update_score_label()

func _generate_platforms_if_needed() -> void:
	while highest_generated_y > player.global_position.y - generation_ahead_distance:
		_generate_one_platform_above()

func _generate_one_platform_above() -> void:
	var gap := randf_range(min_vertical_gap, max_vertical_gap)
	var next_y := highest_generated_y - gap

	var x_step := randf_range(-max_horizontal_step, max_horizontal_step)
	var next_x := clamp(last_generated_x + x_step, min_x, max_x)

	_create_platform(Vector2(next_x, next_y))
	highest_generated_y = next_y
	last_generated_x = next_x

func _create_platform(platform_position: Vector2) -> void:
	if platform_scene == null:
		push_error("EndlessMode.gd requires platform_scene to be assigned.")
		return

	var platform = platform_scene.instantiate() as StaticBody2D
	platform.global_position = platform_position
	platform.set_meta("platform_id", next_platform_id)
	next_platform_id += 1
	platforms.add_child(platform)

func _cleanup_old_platforms() -> void:
	for platform in platforms.get_children():
		if platform.global_position.y > player.global_position.y + cleanup_distance_below_player:
			platform.queue_free()

func _update_score_label() -> void:
	score_label.text = "Score: %d" % score
