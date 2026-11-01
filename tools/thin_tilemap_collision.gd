extends SceneTree
## Takes the work nobody sees out of the story level, so the world loads faster and lighter on a phone:
## - The foreground tiles buried in the tree (a solid full-square tile on all eight sides) lose their
##   collision: nothing can ever touch them. Each becomes a look-alike, an alternative of the same tile
##   in Main.tres with every property but its collision (its "buried_twin_of" custom data says which
##   tile it copies). About 7,000 collision shapes get built instead of about 87,000.
## - The walls' drop shadow (shadowtilemap's overlay layer) is drawn under the walls, so where the walls
##   are solid it's painted over every frame. Those shadow tiles move to a switched-off layer, "overlay
##   (hidden under walls)", which keeps them for editing. About 4,000 shadow tiles get drawn instead of
##   about 80,000.
## The level looks and plays the same. Run it again after painting the level: it thins what's newly
## buried or hidden, and puts back anything painting left exposed. tools/validate_level.gd fails until
## you do.
##   Godot --headless --path . --script res://tools/thin_tilemap_collision.gd

const SCENE := "res://scenes/Main.tscn"
const LAYER := 1  # TileMap's "foreground": the walls and floors
const TWIN_OF := "buried_twin_of"  # custom data: 0 on a normal tile, (the alternative it copies) + 1 on a look-alike
const SHADOW_LAYER := 0  # shadowtilemap's "overlay": the walls' drop shadow
const PARKED := "overlay (hidden under walls)"  # the switched-off shadowtilemap layer for the shadow nobody sees

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load(SCENE) as PackedScene).instantiate()
	var tm: TileMap = main.get_node("TileMap")
	var sh: TileMap = main.get_node("shadowtilemap")
	var ts: TileSet = tm.tile_set
	if ts.get_custom_data_layer_by_name(TWIN_OF) == -1:
		ts.add_custom_data_layer()
		var i := ts.get_custom_data_layers_count() - 1
		ts.set_custom_data_layer_name(i, TWIN_OF)
		ts.set_custom_data_layer_type(i, TYPE_INT)

	# Buried foreground tiles: look-alikes without collision (and back, if no longer buried).
	var solid := solid_cells(tm, LAYER)
	var twins := {}  # "source:x:y:alt" -> its look-alike's alternative id
	var thinned := 0
	var restored := 0
	for c in tm.get_used_cells(LAYER):
		var td := tm.get_cell_tile_data(LAYER, c)
		var source := tm.get_cell_source_id(LAYER, c)
		var coords := tm.get_cell_atlas_coords(LAYER, c)
		var alt := tm.get_cell_alternative_tile(LAYER, c)
		if is_twin(td):
			if not is_buried(solid, c):
				tm.set_cell(LAYER, c, source, coords, int(td.get_custom_data(TWIN_OF)) - 1)
				restored += 1
			continue
		if not solid.has(c) or not is_buried(solid, c):
			continue
		var key := "%d:%d:%d:%d" % [source, coords.x, coords.y, alt]
		if not twins.has(key):
			twins[key] = _twin(ts.get_source(source), coords, alt)
		tm.set_cell(LAYER, c, source, coords, twins[key])
		thinned += 1

	# Shadow under solid wall: parked in the switched-off layer (and back, if the wall's gone).
	var parked_layer := _parked_layer(sh)
	var opaque := opaque_cells(tm, LAYER)
	var parked := 0
	var unparked := 0
	for c in sh.get_used_cells(SHADOW_LAYER):
		if is_hidden(tm, sh, opaque, SHADOW_LAYER, c):
			_move_cell(sh, SHADOW_LAYER, parked_layer, c)
			parked += 1
	for c in sh.get_used_cells(parked_layer):
		if not is_hidden(tm, sh, opaque, parked_layer, c):
			_move_cell(sh, parked_layer, SHADOW_LAYER, c)
			unparked += 1

	if not _save_keeping_uids(ts):
		quit(1)
		return
	var path := ProjectSettings.globalize_path(SCENE)
	var text := FileAccess.get_file_as_string(path)
	text = _with_layer(text, "TileMap", tm, LAYER)
	text = _with_layer(text, "shadowtilemap", sh, SHADOW_LAYER)
	text = _with_layer(text, "shadowtilemap", sh, parked_layer)
	if text == "":
		quit(1)
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	main.free()
	print("Foreground: thinned %d buried tiles (%d look-alikes), gave %d exposed ones their collision back." % [thinned, twins.size(), restored])
	print("Shadow: parked %d tiles hidden under walls, brought back %d now in view." % [parked, unparked])
	quit()


## The cells holding a solid tile: collision that's a full, two-way square (a look-alike counts too:
## it's still a wall, it just doesn't need its own collision).
static func solid_cells(tm: TileMap, layer: int) -> Dictionary:
	var half := Vector2(tm.tile_set.tile_size) / 2.0
	var solid := {}
	for c in tm.get_used_cells(layer):
		var td := tm.get_cell_tile_data(layer, c)
		if is_twin(td) or _full_square(td, half):
			solid[c] = true
	return solid


## Walled in on all eight sides: nothing can reach it.
static func is_buried(solid: Dictionary, c: Vector2i) -> bool:
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and not solid.has(c + Vector2i(dx, dy)):
				return false
	return true


static func is_twin(td: TileData) -> bool:
	return td != null and td.has_custom_data(TWIN_OF) and int(td.get_custom_data(TWIN_OF)) > 0


## Whether the shadow tile at c (on layer) is drawn entirely over by solid foreground tiles: every
## foreground cell its picture reaches (it's drawn a little bigger than its cell) holds a tile with no
## see-through pixel. opaque is opaque_cells(tm, LAYER).
static func is_hidden(tm: TileMap, sh: TileMap, opaque: Dictionary, layer: int, c: Vector2i) -> bool:
	var src: TileSetAtlasSource = sh.tile_set.get_source(sh.get_cell_source_id(layer, c))
	var cell := Vector2(sh.tile_set.tile_size)
	var margin := (Vector2(src.texture_region_size) - cell) / 2.0
	var top_left := sh.position + sh.scale * (Vector2(c) * cell - margin)
	var bottom_right := sh.position + sh.scale * (Vector2(c + Vector2i.ONE) * cell + margin)
	var wall := Vector2(tm.tile_set.tile_size) * tm.scale
	var first := Vector2i(((top_left - tm.position) / wall).floor())
	var last := Vector2i(((bottom_right - tm.position) / wall - Vector2(0.0001, 0.0001)).floor())
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			if not opaque.has(Vector2i(x, y)):
				return false
	return true


## The cells on layer whose tile has no see-through pixel in its cell.
static func opaque_cells(tm: TileMap, layer: int) -> Dictionary:
	var by_tile := {}
	var images := {}  # atlas texture -> its Image
	var opaque := {}
	for c in tm.get_used_cells(layer):
		var source := tm.get_cell_source_id(layer, c)
		var coords := tm.get_cell_atlas_coords(layer, c)
		var key := "%d %s" % [source, coords]
		if not by_tile.has(key):
			by_tile[key] = _solid_picture(tm.tile_set.get_source(source), coords, tm.tile_set.tile_size, images)
		if by_tile[key]:
			opaque[c] = true
	return opaque


static func _solid_picture(src: TileSetAtlasSource, coords: Vector2i, cell: Vector2i, images: Dictionary) -> bool:
	if not images.has(src.texture):
		var image := src.texture.get_image()
		if image.is_compressed():
			image.decompress()
		images[src.texture] = image
	var img: Image = images[src.texture]
	var r := src.get_tile_texture_region(coords)
	var pad := (r.size - cell) / 2
	for y in range(r.position.y + pad.y, r.position.y + pad.y + cell.y):
		for x in range(r.position.x + pad.x, r.position.x + pad.x + cell.x):
			if img.get_pixel(x, y).a < 1.0:
				return false
	return true


static func _parked_layer(sh: TileMap) -> int:
	for i in sh.get_layers_count():
		if sh.get_layer_name(i) == PARKED:
			return i
	sh.add_layer(-1)
	var i := sh.get_layers_count() - 1
	sh.set_layer_name(i, PARKED)
	sh.set_layer_enabled(i, false)
	sh.set_layer_z_index(i, sh.get_layer_z_index(SHADOW_LAYER))
	sh.set_layer_modulate(i, sh.get_layer_modulate(SHADOW_LAYER))
	return i


static func _move_cell(tm: TileMap, from: int, to: int, c: Vector2i) -> void:
	tm.set_cell(to, c, tm.get_cell_source_id(from, c), tm.get_cell_atlas_coords(from, c), tm.get_cell_alternative_tile(from, c))
	tm.erase_cell(from, c)


## text with node_name's layer written as tm has it now (only that layer's lines change; a layer the
## scene doesn't have yet gets its name, switched-off-ness, z index, modulate and tiles added). "" if
## the node isn't there.
static func _with_layer(text: String, node_name: String, tm: TileMap, layer: int) -> String:
	if text == "":
		return ""
	var start := text.find('[node name="%s" type="TileMap"' % node_name)
	if start == -1:
		printerr("Couldn't find the %s TileMap in %s." % [node_name, SCENE])
		return ""
	var end := text.find("\n[node ", start + 1)
	var block := text.substr(start, end - start)
	# (Cells erased while the TileMap's out of the tree still come out, as empty ones: leave them out.)
	var all: PackedInt32Array = tm.get("layer_%d/tile_data" % layer)
	var data := PackedInt32Array()
	for i in range(0, all.size(), 3):
		if all[i + 1] & 0xFFFF != 0xFFFF:  # (source id -1: empty)
			data.append_array(all.slice(i, i + 3))
	var line := "layer_%d/tile_data = %s" % [layer, var_to_str(data)]
	var lines := block.split("\n")
	var at := -1
	var last_layer_line := -1
	for i in lines.size():
		if lines[i].begins_with("layer_%d/tile_data = " % layer):
			at = i
		if lines[i].begins_with("layer_"):
			last_layer_line = i
	if at != -1:
		lines[at] = line
	else:
		var props := PackedStringArray(['layer_%d/name = "%s"' % [layer, tm.get_layer_name(layer)]])
		if not tm.is_layer_enabled(layer):
			props.append("layer_%d/enabled = false" % layer)
		if tm.get_layer_modulate(layer) != Color.WHITE:
			props.append("layer_%d/modulate = %s" % [layer, var_to_str(tm.get_layer_modulate(layer))])
		if tm.get_layer_z_index(layer) != 0:
			props.append("layer_%d/z_index = %d" % [layer, tm.get_layer_z_index(layer)])
		props.append(line)
		for p in range(props.size() - 1, -1, -1):
			lines.insert(last_layer_line + 1, props[p])
	return text.substr(0, start) + "\n".join(lines) + text.substr(end)


static func _full_square(td: TileData, half: Vector2) -> bool:
	if td == null or td.get_collision_polygons_count(0) != 1 or td.is_collision_polygon_one_way(0, 0):
		return false
	var pts := td.get_collision_polygon_points(0, 0)
	if pts.size() != 4:
		return false
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r.position.distance_to(-half) < 0.6 and r.end.distance_to(half) < 0.6


## A new alternative of the tile: the same to look at, without collision (or terrain, and never picked
## when painting, so the editor won't put one anywhere by itself), noting which tile it copies.
static func _twin(src: TileSetAtlasSource, coords: Vector2i, alt: int) -> int:
	var twin_id := src.create_alternative_tile(coords)
	var base := src.get_tile_data(coords, alt)
	var twin := src.get_tile_data(coords, twin_id)
	for prop in base.get_property_list():
		var prop_name: String = prop.name
		if not (prop.usage & PROPERTY_USAGE_STORAGE) or prop_name.begins_with("physics_layer_") \
				or prop_name.begins_with("terrain") or prop_name == "probability":
			continue
		twin.set(prop_name, base.get(prop_name))
	twin.probability = 0.0
	twin.set_custom_data(TWIN_OF, alt + 1)
	return twin_id


## Saves the TileSet. Saved from a script, Godot leaves out its uid and its textures' uids, so the
## ones it had go back in (otherwise Main.tscn's uid for it, and the editor, would lose track of it).
static func _save_keeping_uids(ts: TileSet) -> bool:
	var path := ProjectSettings.globalize_path(ts.resource_path)
	var before := FileAccess.get_file_as_string(path).split("\n")
	var err := ResourceSaver.save(ts, ts.resource_path)
	if err != OK:
		printerr("Couldn't save %s: %s" % [ts.resource_path, error_string(err)])
		return false
	var had := {}  # ext_resource id (or "header") -> its line as it was
	for line in before:
		if line.begins_with("[gd_resource "):
			had["header"] = line
		elif line.begins_with("[ext_resource "):
			had[line.get_slice(' id="', 1).get_slice('"', 0)] = line
	var after := FileAccess.get_file_as_string(path).split("\n")
	for i in after.size():
		var line := after[i]
		if line.begins_with("[gd_resource ") and had.has("header"):
			after[i] = had["header"]
		elif line.begins_with("[ext_resource "):
			var id := line.get_slice(' id="', 1).get_slice('"', 0)
			if had.has(id):
				after[i] = had[id]
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(after))
	f.close()
	return true
