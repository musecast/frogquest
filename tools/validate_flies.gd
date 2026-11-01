extends SceneTree
## Headless test for the hidden flies (FlyHunt.gd, Fly.gd): every fly hovers in open air just over a
## real ledge of the story level, catching them counts and saves, a caught fly stays caught, and the
## last one unlocks the Golden Frog, once. Never touches your real save (it uses a scratch wardrobe).
##   Godot --headless --path . --script res://tools/validate_flies.gd

var FlyHunt: GDScript  # (loaded in _run: in --script mode the autoloads it uses only exist by then)

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	FlyHunt = load("res://scripts/FlyHunt.gd")
	var mm := root.get_node("MusicManager")

	# Every fly is out in the open (not in a wall) with a ledge just under it.
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	var tm: TileMap = main.get_node("TileMap")
	var bad := []
	for i in FlyHunt.total():
		var cell := tm.local_to_map(FlyHunt.SPOTS[i] / tm.scale)
		if _solid(tm, cell) or _solid(tm, cell + Vector2i(0, -1)):
			bad.append("%d is inside a wall" % i)
		var ledge := false
		for dy in range(1, 4):
			for dx in [-1, 0, 1]:
				ledge = ledge or _solid(tm, cell + Vector2i(dx, dy))
		if not ledge:
			bad.append("%d has no ledge under it" % i)
	_expect(bad.is_empty(), "every fly hovers in the open, just over a ledge " + str(bad))
	main.free()

	# Catching them all, on a fresh save (a scratch wardrobe file; your own save isn't touched).
	var real_path: String = mm.wardrobe_path
	var real_caught: Array = mm.flies_caught.duplicate()
	var real_skins: Array = mm.unlocked_skins.duplicate()
	mm.wardrobe_path = "user://test_wardrobe_flies.save"
	mm.flies_caught = []
	mm.unlocked_skins.erase(FlyHunt.REWARD)
	var frog_script := GDScript.new()
	frog_script.source_code = "extends Node\nfunc save_game() -> void:\n\tpass\n"
	frog_script.reload()
	var frog := Node.new()
	frog.set_script(frog_script)
	var level := Node2D.new()
	root.add_child(level)
	FlyHunt.spawn_into(level)
	var flies := level.get_children()
	_expect(flies.size() == FlyHunt.total(), "all %d flies are out on a fresh save" % FlyHunt.total())
	flies[0]._on_body_entered(Node.new())
	_expect(FlyHunt.count_caught() == 0, "only the frog catches one (not a tile or anything else)")
	for fly in flies.slice(0, flies.size() - 1):
		fly._on_body_entered(frog)
	_expect(FlyHunt.count_caught() == FlyHunt.total() - 1 and not (FlyHunt.REWARD in mm.unlocked_skins),
		"each catch counts, and the Golden Frog waits for the last one")
	flies[-1]._on_body_entered(frog)
	flies[-1]._on_body_entered(frog)
	_expect(FlyHunt.REWARD in mm.unlocked_skins and mm.unlocked_skins.count(FlyHunt.REWARD) == 1
		and FlyHunt.count_caught() == FlyHunt.total(), "the last fly unlocks the Golden Frog (once)")
	mm.flies_caught = []
	mm.load_wardrobe()
	_expect(mm.flies_caught.size() == FlyHunt.total(), "the catches are saved with the wardrobe")
	var again := Node2D.new()
	root.add_child(again)
	FlyHunt.spawn_into(again)
	_expect(again.get_child_count() == 0, "caught flies stay caught on the next climb")
	var caught := []
	_expect(not FlyHunt.record(caught, "fly_0") and not FlyHunt.record(caught, "fly_0") and caught.size() == 1,
		"catching the same fly twice only counts once")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(mm.wardrobe_path))
	mm.wardrobe_path = real_path
	mm.flies_caught = real_caught
	mm.unlocked_skins = real_skins
	for _i in 3:
		await process_frame
	if _failures.is_empty():
		print("Flies test passed.")
	else:
		for failure in _failures:
			push_warning("FAIL: " + failure)
		printerr("Flies test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


func _solid(tm: TileMap, cell: Vector2i) -> bool:
	for layer in tm.get_layers_count():
		if not tm.is_layer_enabled(layer):
			continue
		var td := tm.get_cell_tile_data(layer, cell)
		if td and td.get_collision_polygons_count(0) > 0:
			return true
	return false


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
