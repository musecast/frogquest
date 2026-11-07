extends Control
## Your froggy as you look right now (MusicManager: your look, your skin, your hat), standing there breathing
## (his two idle frames, as in the game): the wardrobe's mirror. refresh() after anything's put on or taken
## off: it's on him at once, with a little hop as it changes. Drawn on his own pixel grid, px screen pixels to
## each of his; his hats sit as they do in the game (as CreatorIntro has them: its HAT_Y, ART_HATS). Room is
## kept over his head for the tallest hat, so he doesn't move about as hats change.

const IDLE := ["res://assets/frog.png", "res://assets/frog2.png"]
const BREATH := 0.6  # (seconds between his two idle frames, as the game has them)
const HEAD_ROOM := 34.0  # (from his middle up to the tallest hat's top (the wiz hat), in his pixels)
const FEET := 16.0  # (and down to the bottom of his frame)
const HOP := 0.32  # (the little hop as something changes: how long, eased in and out)

var px := 2.0  ## (screen pixels to one of his)
var _frog: TextureRect
var _hat: TextureRect
var _frame := 0
var _breath := 0.0
var _worn := ""  # (what he had on, for the hop when it changes)
var _hop: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(32.0, HEAD_ROOM + FEET) * px
	_hat = _picture()
	_frog = _picture()
	_frog.texture = load(IDLE[0])
	add_child(_hat)
	add_child(_frog)
	resized.connect(_place)
	refresh(false)


func _picture() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Him as he is now: his look and skin, and his hat (his own art hats behind his head, as in the game; the
## drawn ones worn in front). With `hop`, a little hop if what he's wearing changed.
func refresh(hop := true) -> void:
	if _frog == null:
		return
	var looks: GDScript = load("res://scripts/FroggyLook.gd")
	var art_hats: Dictionary = load("res://scenes/CreatorIntro.gd").ART_HATS
	var hat := MusicManager.equipped_hat
	_frog.material = looks.material(MusicManager.look, MusicManager.equipped_skin)
	var pic: Texture2D = looks.hat_texture(hat)
	if pic == null and art_hats.has(hat):
		pic = load(art_hats[hat][0])
	_hat.texture = pic
	_hat.visible = pic != null
	_hat.material = null
	if hat == "blackcrown":
		var black := ShaderMaterial.new()
		black.shader = load("res://assets/skin_tint.gdshader")
		black.set_shader_parameter("tint_color", Color(0, 0, 0))
		black.set_shader_parameter("tint_strength", 1.0)
		_hat.material = black
	move_child(_hat, 0 if art_hats.has(hat) else 1)
	_place()
	var worn := "%s|%s|%s" % [hat, MusicManager.equipped_skin, MusicManager.look]
	if hop and worn != _worn:
		_hop_once()
	_worn = worn


func _process(delta: float) -> void:
	_breath += _real(delta)
	if _breath >= BREATH:
		_breath = 0.0
		_frame = 1 - _frame
		_frog.texture = load(IDLE[_frame])
		_place()  # (his head dips as he breathes: his hat with it)


## Where he and his hat go: him in the middle across, his middle HEAD_ROOM of his pixels down from the top;
## his hat on his head (CreatorIntro._fit's way).
func _place() -> void:
	var middle := Vector2(size.x * 0.5, HEAD_ROOM * px)
	_frog.size = Vector2(32.0, 32.0) * px
	_frog.position = (middle - _frog.size * 0.5).round()
	if _hat.texture:
		var intro: GDScript = load("res://scenes/CreatorIntro.gd")
		var hat := MusicManager.equipped_hat
		var rel := 1.0
		var off: Vector2 = load("res://scripts/FroggyLook.gd").hat_offset(hat)
		if intro.ART_HATS.has(hat):
			rel = intro.ART_HATS[hat][1]
			off = Vector2(0.0, intro.ART_HATS[hat][2])
		var drop: float = load("res://scripts/FroggyHead.gd").drop(_frog.texture)
		var at := middle + (Vector2(0.0, intro.HAT_Y + drop) + off * rel) * px
		_hat.size = _hat.texture.get_size() * rel * px
		_hat.position = (at - _hat.size * 0.5).round()
	pivot_offset = Vector2(size.x * 0.5, (HEAD_ROOM + FEET - 1.0) * px)  # (his feet: he hops off them)


## A little hop: squashed down, up tall, and back, eased in and out each way.
func _hop_once() -> void:
	if _hop:
		_hop.kill()
	scale = Vector2.ONE
	_hop = create_tween().set_ignore_time_scale(true)
	_hop.tween_property(self, "scale", Vector2(1.08, 0.92), HOP * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hop.tween_property(self, "scale", Vector2(0.95, 1.06), HOP * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hop.tween_property(self, "scale", Vector2.ONE, HOP * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A frame's time, never slower than it really went: the pause menu runs the game at a twentieth of its speed
## (Engine.time_scale), and a menu over it shouldn't crawl; sped up (the tests' fast-forward), it goes with the
## game. Steady frame to frame, as the game's own is.
func _real(delta: float) -> float:
	return delta / Engine.time_scale if Engine.time_scale > 0.0 and Engine.time_scale < 1.0 else delta
