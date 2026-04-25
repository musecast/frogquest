extends CharacterBody2D

const SPEED = 300.0
var landed_platform_ids: Dictionary = {}
var tempVelocityx = 0.0
var jumpCount = 0
var _floor_body: StaticBody2D = null

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@export var trajectory: Node
@export var jump_sound: AudioStreamPlayer
@export var aim_sound: AudioStreamPlayer
@export var sad_timer: Timer

@onready var sprite = $Sprite2D
@onready var shadow = $Shadow

func _ready() -> void:
	trajectory = $Trajectory
	_apply_equipped_cosmetics()


func _apply_equipped_cosmetics() -> void:
	var hat := MusicManager.equipped_hat
	if has_node("Froggycrown"):
		$Froggycrown.visible = (hat == "froggycrown" or hat == "blackcrown")
		if hat == "blackcrown":
			var hat_mat := ShaderMaterial.new()
			hat_mat.shader = load("res://assets/skin_tint.gdshader")
			hat_mat.set_shader_parameter("tint_color", Color(0.0, 0.0, 0.0))
			hat_mat.set_shader_parameter("tint_strength", 1.0)
			$Froggycrown.material = hat_mat
		else:
			$Froggycrown.material = null
	if has_node("FroggyWizHat"):
		$FroggyWizHat.visible = (hat == "wizhat")
	if has_node("FroggyCakeHat"):
		$FroggyCakeHat.visible = (hat == "cakehat")

	match MusicManager.equipped_skin:
		"golden_skin":
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/skin_tint.gdshader")
			mat.set_shader_parameter("tint_color", Color(1.0, 0.75, 0.0))
			mat.set_shader_parameter("tint_strength", 0.55)
			sprite.material = mat
		"grayscale_skin":
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/grayscale.gdshader")
			sprite.material = mat
		"negative_skin":
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/negative.gdshader")
			sprite.material = mat
		_:
			sprite.material = null
	shadow.visible = MusicManager.equipped_skin != "negative_skin"

func _physics_process(delta):
	var was_on_floor := is_on_floor()
	if was_on_floor:
		# Find which StaticBody2D we're standing on (from last frame's move_and_slide collisions)
		_floor_body = null
		for i in get_slide_collision_count():
			var body = get_slide_collision(i).get_collider()
			if body is StaticBody2D:
				_floor_body = body
				break

	if not is_on_floor():
		velocity.y += gravity * delta
		sprite.play("airborne")
		shadow.play("airborne")
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, 10.0 * delta)
		shadow.rotation = sprite.rotation
		if is_on_wall():
			velocity.x = -tempVelocityx

	if is_on_floor():
		sprite.rotation = lerp_angle(sprite.rotation, get_floor_normal().angle() + PI / 2, 25.0 * delta)
		shadow.rotation = sprite.rotation
		if trajectory and trajectory.mousePath.length() > 200:
			sprite.play("prejump")
		else:
			sprite.play("default")
			shadow.play("default")


		# Report landing to main scene for scoring
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider and collider.has_meta("platform_id"):
				var pid = collider.get_meta("platform_id")
				var main = get_parent()
				if main.has_method("register_platform_landing"):
					main.register_platform_landing(pid)

		velocity.x = move_toward(velocity.x, 0, SPEED)

	tempVelocityx = velocity.x / 2.5

	var _is_negative := MusicManager.equipped_skin == "negative_skin"
	var _hat_y := (-9.16667 if sprite.animation == "prejump" else -10.66667) if _is_negative else -9.1667
	if has_node("Froggycrown") and $Froggycrown.visible:
		$Froggycrown.rotation = sprite.rotation
		$Froggycrown.position = Vector2(0, _hat_y).rotated(sprite.rotation)
	if has_node("FroggyWizHat") and $FroggyWizHat.visible:
		$FroggyWizHat.rotation = sprite.rotation
		$FroggyWizHat.position = Vector2(0, _hat_y).rotated(sprite.rotation)
	if has_node("FroggyCakeHat") and $FroggyCakeHat.visible:
		$FroggyCakeHat.rotation = sprite.rotation
		$FroggyCakeHat.position = Vector2(0, _hat_y).rotated(sprite.rotation)

	move_and_slide()

	# If we just left a moving platform (jumped), strip out the platform's lateral velocity
	# so it doesn't contribute to launch momentum.
	if was_on_floor and not is_on_floor() and _floor_body != null:
		velocity.x -= _floor_body.constant_linear_velocity.x
		_floor_body = null
