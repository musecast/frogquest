extends SceneTree
## Headless check that the story level's thinned-out work (tools/thin_tilemap_collision.gd) still fits
## the level: no collision-less look-alike is anywhere the frog could touch it, every look-alike draws
## just like the tile it copies, and no parked shadow tile is anywhere it would show. After painting the
## level, this fails until the thinning tool is run again.
##   Godot --headless --path . --script res://tools/validate_level.gd

const THIN := "res://tools/thin_tilemap_collision.gd"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var thin: GDScript = load(THIN)
	var main: Node = (load(thin.SCENE) as PackedScene).instantiate()
	var tm: TileMap = main.get_node("TileMap")
	var sh: TileMap = main.get_node("shadowtilemap")
	var layer: int = thin.LAYER

	# Look-alikes: buried, and drawn like the tile they copy.
	var solid: Dictionary = thin.solid_cells(tm, layer)
	var twins := 0
	var shapes := 0
	var could_thin := 0
	var exposed := []
	var unlike := {}
	for c in tm.get_used_cells(layer):
		var td := tm.get_cell_tile_data(layer, c)
		shapes += td.get_collision_polygons_count(0)
		if not thin.is_twin(td):
			if solid.has(c) and thin.is_buried(solid, c):
				could_thin += 1
			continue
		twins += 1
		if not thin.is_buried(solid, c):
			exposed.append(c)
		var src: TileSetAtlasSource = tm.tile_set.get_source(tm.get_cell_source_id(layer, c))
		var coords := tm.get_cell_atlas_coords(layer, c)
		var base_alt := int(td.get_custom_data(thin.TWIN_OF)) - 1
		var key := "%d %s %d" % [tm.get_cell_source_id(layer, c), coords, base_alt]
		if not unlike.has(key):
			unlike[key] = _drawn_differently(src.get_tile_data(coords, base_alt), td)
	_expect(exposed.is_empty(), "%d look-alike tiles without collision can be reached (the first at %s): run %s" % [
		exposed.size(), exposed[0] if exposed else Vector2i.ZERO, THIN])
	for key in unlike:
		_expect(unlike[key] == "", "the look-alike of tile %s draws differently (%s)" % [key, unlike[key]])

	# Parked shadow: all of it out of sight.
	var parked_layer := -1
	for i in sh.get_layers_count():
		if sh.get_layer_name(i) == thin.PARKED:
			parked_layer = i
	var showing := []
	var opaque: Dictionary = thin.opaque_cells(tm, layer)
	var could_park := 0
	if parked_layer != -1:
		_expect(not sh.is_layer_enabled(parked_layer), "the parked shadow layer is switched on")
		for c in sh.get_used_cells(parked_layer):
			if not thin.is_hidden(tm, sh, opaque, parked_layer, c):
				showing.append(c)
	for c in sh.get_used_cells(thin.SHADOW_LAYER):
		if thin.is_hidden(tm, sh, opaque, thin.SHADOW_LAYER, c):
			could_park += 1
	_expect(showing.is_empty(), "%d parked shadow tiles are where they'd show (the first at %s): run %s" % [
		showing.size(), showing[0] if showing else Vector2i.ZERO, THIN])

	var drawn := sh.get_used_cells(thin.SHADOW_LAYER).size()
	var parked := sh.get_used_cells(parked_layer).size() if parked_layer != -1 else 0
	main.free()
	if _failures.is_empty():
		print("Level test passed: %d collision shapes on the foreground (%d buried tiles thinned), %d shadow tiles drawn (%d parked)." % [
			shapes, twins, drawn, parked])
		if could_thin or could_park:
			print("  (%d more buried tiles and %d more hidden shadow tiles could be thinned: run %s.)" % [could_thin, could_park, THIN])
	else:
		for failure in _failures:
			push_warning("FAIL: " + failure)
		printerr("Level test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)


## "" when twin draws the same as base, else which property differs.
func _drawn_differently(base: TileData, twin: TileData) -> String:
	for prop in ["flip_h", "flip_v", "transpose", "texture_origin", "modulate", "material", "z_index", "y_sort_origin"]:
		if base.get(prop) != twin.get(prop):
			return prop
	if twin.get_collision_polygons_count(0) != 0:
		return "it has collision"
	return ""


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
