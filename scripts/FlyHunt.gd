## The little flies hiding around the World Tree (like the ones Lil Froggy hunts on the desktop).
## Get close and the frog's tongue snaps one up (Fly.gd); it stays caught (MusicManager.flies_caught,
## in the wardrobe save, so a new climb doesn't bring them back). Catch every one of them and the
## Golden Frog skin is yours.

const REWARD := "golden_skin"
const CATCH_SOUND := "res://assets/pickupCoin.wav"
# Where they buzz, in the story level's coordinates (Main.tscn): one tucked-in spot (a corner, under
# an overhang, on a side ledge) for every stretch of the climb, from the cave at the bottom to just
# under the top. Each hovers a little over a real ledge the frog can get to; tools/validate_flies.gd
# keeps it that way (it jumps the climb the way he does).
const SPOTS := [
	Vector2(-134.0, 89.0),
	Vector2(749.0, -333.0),
	Vector2(2477.0, -852.0),
	Vector2(3226.0, -1408.0),
	Vector2(2918.0, -1696.0),
	Vector2(2957.0, -2176.0),
	Vector2(3782.0, -2484.0),
	Vector2(2486.0, -3082.0),
	Vector2(2966.0, -3350.0),
	Vector2(3130.0, -3847.0),
	Vector2(2477.0, -4154.0),
	Vector2(3100.0, -4571.0),  # (over the mushroom by THE MUSHROOMS' wide one: under its cap, only a lucky shot got it)
	Vector2(4243.0, -5076.0),
	Vector2(4243.0, -5632.0),
]


static func id_of(i: int) -> String:
	return "fly_%d" % i


static func total() -> int:
	return SPOTS.size()


static func count_caught() -> int:
	var n := 0
	for i in total():
		if id_of(i) in MusicManager.flies_caught:
			n += 1
	return n


## Puts the flies nobody's caught yet into the level.
static func spawn_into(level: Node) -> void:
	var fly_script: Script = load("res://scripts/Fly.gd")
	for i in total():
		if id_of(i) in MusicManager.flies_caught:
			continue
		var fly: Node2D = fly_script.new()
		fly.fly_id = id_of(i)
		fly.position = SPOTS[i]
		fly.name = "HiddenFly%d" % i
		level.add_child(fly)


## Adds a catch to the list; true if that was the last one (and the reward is new). Pure: no saving.
static func record(caught: Array, id: String) -> bool:
	if id in caught:
		return false
	caught.append(id)
	for i in total():
		if not (id_of(i) in caught):
			return false
	return true


## A fly got caught: the gulp, the count, the save, and (for the last one) the Golden Frog.
static func caught(fly: Node) -> void:
	var tree := fly.get_tree()
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load(CATCH_SOUND)
	sfx.bus = &"FX"
	sfx.pitch_scale = randf_range(1.15, 1.35)
	tree.root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	var all_done := record(MusicManager.flies_caught, str(fly.fly_id))
	if MusicManager.flies_caught.size() >= 5:
		MusicManager.unlock("lilypad")  # (5 caught: the Lily Pad hat)
	var unlocked := all_done and not (REWARD in MusicManager.unlocked_skins)
	if unlocked:
		MusicManager.unlocked_skins.append(REWARD)
	MusicManager.save_wardrobe()
	if unlocked:
		MusicManager.show_toast("All %d flies caught!" % total(), icon(), "Every last one!")
		MusicManager.show_unlock_notification("skin", REWARD)  # (it waits its turn)
		var player := fly.get_parent().get_node_or_null("Player")
		if player and player.has_method("_refresh_all_wardrobe_badges"):
			player._refresh_all_wardrobe_badges()  # (the NEW badge on the wardrobe button)
	else:
		MusicManager.show_toast("Fly caught!", icon(), "%d of %d" % [count_caught(), total()])


## A fly to show in the notification: the one from the world, wings up.
static func icon() -> TextureRect:
	var rows := [  # w wing, b body, e eye
		"..ww...ww..",
		".wwww.wwww.",
		".wwwwbwwww.",
		"..wwebeww..",
		"...bbbbb...",
		"...bbbbb...",
		"....bbb....",
		"...b...b...",
	]
	var colours := {"w": Color(0.86, 0.94, 1.0, 0.95), "b": Color(0.12, 0.12, 0.14), "e": Color(0.85, 0.15, 0.15)}
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			if colours.has(rows[y][x]):
				img.set_pixel(x, y, colours[rows[y][x]])
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(img)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return rect
