extends Node2D
## A friend's frog in a party: their Froggy in their hat, skin and party colour, where their phone last
## said it was (Party.frog_moved), eased between its updates. Only looks: it doesn't stand on anything,
## and nothing stands on it. Its name tag is drawn by EndlessMode, on the screen, at the pixel font's size.

const HATS := ["Froggycrown", "FroggyWizHat", "FroggyCakeHat"]

var peer := 0
var score := 0
var metres := 0
var standing := false  # (on a platform, by their animation: one who can pull a friend back up)
var tether_to := 0  # who their band is tied to (a peer id; 0: nobody), for drawing it
var where := 0  # up the World Tree, where they are in their own world (StoryParty: CLIMBING, IN_FINALE, WON, AWAY)
var seen := false  # (their phone's said where they are at least once)
var _sprite: AnimatedSprite2D
var _hats := {}
var _skin := ""
var _target := Vector2.ZERO
var _placed := false
var _head: Script = load("res://scripts/FroggyHead.gd")


## Built from his own frog (EndlessPlayer: the sprite and the hats under it), dressed as the friend is.
func setup(template: Node2D, who: int, info: Dictionary) -> void:
	peer = who
	scale = template.scale
	z_index = 0  # (just behind your own frog)
	z_as_relative = false
	var source := template.get_node("Sprite2D") as AnimatedSprite2D
	_sprite = source.duplicate(0) as AnimatedSprite2D
	_sprite.material = null
	add_child(_sprite)
	for hat_name in HATS:
		var hat := template.get_node_or_null(hat_name) as Sprite2D
		if hat:
			var copy := hat.duplicate(0) as Sprite2D
			copy.material = null
			copy.visible = false
			add_child(copy)
			_hats[hat_name] = copy
	dress(info)


## Their hat, skin and colour (the same way endlessplayer.gd dresses his own frog).
func dress(info: Dictionary) -> void:
	var hat := str(info.get("hat", ""))
	_skin = str(info.get("skin", ""))
	for hat_name in _hats:
		_hats[hat_name].visible = false
	if _hats.has("Froggycrown") and hat in ["froggycrown", "blackcrown"]:
		_hats.Froggycrown.visible = true
		_hats.Froggycrown.material = _tint(Color(0, 0, 0), 1.0) if hat == "blackcrown" else null
	if _hats.has("FroggyWizHat"):
		_hats.FroggyWizHat.visible = hat == "wizhat"
	if _hats.has("FroggyCakeHat"):
		_hats.FroggyCakeHat.visible = hat == "cakehat"
	match _skin:
		"golden_skin":
			_sprite.material = _tint(Color(1.0, 0.75, 0.0), 0.55)
		"grayscale_skin":
			_sprite.material = _shader("res://assets/grayscale.gdshader")
		"negative_skin":
			_sprite.material = _shader("res://assets/negative.gdshader")
		_:
			var c: Color = Party.COLORS[clampi(int(info.get("color", 0)), 0, Party.COLORS.size() - 1)]
			_sprite.material = _tint(c, 0.45) if c.a > 0.0 else null


## Where their phone says their frog is, and how it looks: [x, y, animation, frame, flip, turn, score,
## metres, band, where] (the band and where only from some: up the World Tree, where they are).
func show_state(state: Array) -> void:
	_target = Vector2(float(state[0]), float(state[1]))
	if not _placed:
		position = _target
		_placed = true
	var anim := StringName(str(state[2]))
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
		if _sprite.animation != anim:
			_sprite.animation = anim
		_sprite.frame = int(state[3])
	_sprite.flip_h = bool(state[4])
	_sprite.rotation = float(state[5])
	score = int(state[6])
	standing = str(state[2]) != "airborne"
	metres = int(state[7])
	tether_to = int(state[8]) if state.size() > 8 else 0
	where = int(state[9]) if state.size() > 9 else 0
	seen = true
	_place_hats()


## Where their phone last said their frog is (it eases there on the screen).
func spot() -> Vector2:
	return _target


func _process(delta: float) -> void:
	position = position.lerp(_target, 1.0 - exp(-delta * 18.0))


## Hats sit on the head as it bobs, as on his own frog (endlessplayer.gd _place_hats).
func _place_hats() -> void:
	var frame: Texture2D = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame) if _sprite.sprite_frames else null
	var hat_y := -10.66667 if _skin == "negative_skin" else -9.1667
	hat_y += _head.drop(frame) * _sprite.scale.y
	for hat_name in _hats:
		var hat: Sprite2D = _hats[hat_name]
		if hat.visible:
			hat.rotation = _sprite.rotation
			hat.position = Vector2(0, hat_y).rotated(_sprite.rotation)


static func _tint(c: Color, strength: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/skin_tint.gdshader")
	mat.set_shader_parameter("tint_color", Color(c.r, c.g, c.b))
	mat.set_shader_parameter("tint_strength", strength)
	return mat


static func _shader(path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	return mat
