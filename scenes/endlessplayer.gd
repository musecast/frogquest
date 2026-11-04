extends CharacterBody2D

signal launched(platform: Node)  # (he's jumped off a platform: EndlessMode pops its spring)

const SPEED = 300.0
const SPRING_BOOST := 1.55  # a jump off a spring: this much faster, so about 2.4 times as high
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

var _froggy_head: Script = load("res://scripts/FroggyHead.gd")


func _ready() -> void:
	trajectory = $Trajectory
	_apply_equipped_cosmetics()
	sprite.frame_changed.connect(_place_hats)
	sprite.animation_changed.connect(_place_hats)


## His hat sits on his head: it comes down with his head when he breathes and when he crouches to aim
## (see FroggyHead.gd), and turns with him. Placed every physics frame and as soon as his frame
## changes, so it's never a frame behind his head.
func _place_hats() -> void:
	var frame: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) if sprite.sprite_frames else null
	# (the negative skin shows the screen behind him, hats and all, so its hat sits a bit higher)
	var hat_y := -10.66667 if MusicManager.equipped_skin == "negative_skin" else -9.1667
	hat_y += _froggy_head.drop(frame) * sprite.scale.y
	for hat_name in ["Froggycrown", "FroggyWizHat", "FroggyCakeHat", "LookHat"]:
		var hat := get_node_or_null(hat_name) as Sprite2D
		if hat and hat.visible:
			hat.rotation = sprite.rotation
			hat.position = Vector2(0, hat_y).rotated(sprite.rotation)


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

	# (the hats drawn in code, on his own grid, and your froggy with your skin over him: FroggyLook)
	var look: GDScript = load("res://scripts/FroggyLook.gd")
	var look_hat := _look_hat()
	look_hat.texture = look.hat_texture(hat)
	look_hat.offset = look.hat_offset(hat)
	look_hat.visible = look_hat.texture != null
	sprite.material = look.material(MusicManager.look, MusicManager.equipped_skin)
	shadow.visible = MusicManager.equipped_skin != "negative_skin"


## The hat that's drawn in code (FroggyLook.HATS), sized and placed as his others are.
func _look_hat() -> Sprite2D:
	var h := get_node_or_null("LookHat") as Sprite2D
	if h == null:
		h = Sprite2D.new()
		h.name = "LookHat"
		var like := get_node_or_null("FroggyWizHat") as Sprite2D
		h.scale = like.scale if like else sprite.scale
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(h)  # (after his body: worn in front of his head; his other hats are behind it)
	return h

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

	_place_hats()

	move_and_slide()

	# If we just left a moving platform (jumped), strip out the platform's velocity so it doesn't
	# add to the jump: he goes where he aimed.
	if was_on_floor and not is_on_floor() and _floor_body != null:
		velocity -= _floor_body.constant_linear_velocity
		if velocity.y < 0.0 and is_instance_valid(_floor_body):
			launched.emit(_floor_body)
		_floor_body = null


## How much a jump from where he stands is boosted: a spring's, or none.
func launch_boost() -> float:
	if is_on_floor() and _floor_body != null and is_instance_valid(_floor_body) and _floor_body.has_meta("spring"):
		return SPRING_BOOST
	return 1.0
