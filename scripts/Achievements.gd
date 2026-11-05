extends RefCounted
## Achievements: earned once, kept with the wardrobe (MusicManager.achievements), shown with a toast, and
## told to Game Center (on an iPhone with the Game Center plugin in the build) and to your Muse account
## (signed in). Either one missing, it's still yours here, and it's told again next time the game starts.
##
## Game Center's own ids (they're set up in App Store Connect, under Game Center): GC below.

const LIST := {
	"beat_game": {"name": "Top of the Tree", "about": "Climb the World Tree all the way to the top.",
		"gc": "frogquest.top_of_the_tree"},
	"beat_hard": {"name": "Hard Hopper", "about": "Beat Frog Quest on Hard.", "gc": "frogquest.hard_hopper"},
	"beat_og": {"name": "True OG", "about": "Beat Frog Quest in OG mode.", "gc": "frogquest.true_og"},
}
const MUSE_RPC := "muse_game_achievement_earn"  # (p_game, p_achievement)


## Earns one: true the first time (a toast says so, and it's told to Game Center and Muse).
static func earn(id: String) -> bool:
	if not LIST.has(id) or id in MusicManager.achievements:
		return false
	MusicManager.achievements.append(id)
	MusicManager.save_wardrobe()
	MusicManager.show_toast("Achievement!", trophy(), LIST[id].name + "\n" + LIST[id].about)
	_tell(id)
	return true


## A little gold trophy (pixel art, for the toast).
static func trophy() -> Control:
	var rows := ["##.###.##", "#########", "##.###.##", ".#######.", "..#####..", "...###...", "....#....",
		"...###...", "..#####.."]
	var pic := TextureRect.new()
	pic.texture = load("res://scripts/UIStyle.gd").pixel_icon(rows)
	pic.modulate = Color(1.0, 0.82, 0.3)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.custom_minimum_size = Vector2(18, 18)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


static func has(id: String) -> bool:
	return id in MusicManager.achievements


## At the start: signs in to Game Center (if it's there) and tells it, and Muse, every one already earned
## (they might have been earned offline, or before this was here).
static func start() -> void:
	var gc := _game_center()
	if gc and gc.has_method("authenticate"):
		gc.authenticate()
	for id in MusicManager.achievements:
		_tell(id)


static func _tell(id: String) -> void:
	var gc := _game_center()
	if gc and gc.has_method("award_achievement"):
		gc.award_achievement({"name": LIST[id].gc, "progress": 100.0, "show_completion_banner": true})
	if not OS.has_feature("template"):
		return  # (only the game itself tells your Muse account: never the editor, never a test)
	var muse: Node = Engine.get_main_loop().root.get_node_or_null("MuseAccount") if Engine.get_main_loop() else null
	if muse and muse.has_method("is_signed_in") and muse.is_signed_in():
		muse.call_rpc(MUSE_RPC, {"p_game": "frog-quest", "p_achievement": id})  # (its answer doesn't matter)


static func _game_center() -> Object:
	return Engine.get_singleton("GameCenter") if Engine.has_singleton("GameCenter") else null
