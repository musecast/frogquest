extends SceneTree
## Makes scenes/frenzy/Bedroom.tscn: Froggy's bedroom just as the story has it (Main.tscn), for Frog
## Frenzy's SCARE!. Its walls and floor are the tile map's own cells round it (and their shadows), so the
## floor's solid for him. Its things are copied as they are: the bookshelf, the lava lamp, the lanterns,
## the sunflower, the beanbag, the Muse TV and the picture on the shelf. The room's middle is at the
## origin. Run it again if the bedroom changes.
##   Godot --headless --path . --script res://tools/make_frenzy_bedroom.gd

const ROOM := Rect2(1124.0, 34.0, 352.0, 352.0)  # (the bedroom, and the dirt round it to make a square, in the story's world)
const THINGS := ["Bookshelves", "lavalamp", "Lantern2", "Lantern3", "Sunflower", "Beanbag", "Beanbag2", "Bae", "Musecrtquarterview",
	"ExitEntrance"]
const OUT := "res://scenes/frenzy/Bedroom.tscn"


func _initialize() -> void:
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	var room := Node2D.new()
	room.name = "Bedroom"
	var middle := ROOM.get_center().round()
	room.set_meta("story_middle", middle)  # (where it is in the story's world)
	var cells := 0
	for map_name in ["TileMap", "shadowtilemap"]:
		var from: TileMap = main.get_node(map_name)
		var map := TileMap.new()
		map.name = map_name
		map.tile_set = from.tile_set
		map.texture_filter = from.texture_filter
		map.scale = from.scale
		map.position = from.position - middle
		map.modulate = from.modulate
		map.z_index = from.z_index
		for layer in from.get_layers_count():
			if layer > 0:
				map.add_layer(-1)
			map.set_layer_name(layer, from.get_layer_name(layer))
			map.set_layer_enabled(layer, from.is_layer_enabled(layer))
			map.set_layer_modulate(layer, from.get_layer_modulate(layer))
			map.set_layer_z_index(layer, from.get_layer_z_index(layer))
			map.set_layer_y_sort_enabled(layer, from.is_layer_y_sort_enabled(layer))
			for cell in from.get_used_cells(layer):
				var at: Vector2 = from.position + from.map_to_local(cell) * from.scale
				if ROOM.grow(24.0).has_point(at):
					map.set_cell(layer, cell, from.get_cell_source_id(layer, cell), from.get_cell_atlas_coords(layer, cell),
						from.get_cell_alternative_tile(layer, cell))
					cells += 1
		room.add_child(map)
		map.owner = room
	for thing in THINGS:
		var node: Node2D = main.get_node(thing)
		var copy: Node2D = node.duplicate()
		copy.position = node.position - middle
		if thing == "Bae":
			copy.set_script(null)  # (it looks for the story's Froggy to sort itself in front or behind)
		room.add_child(copy)
		_own(copy, room)
	var scene := PackedScene.new()
	var packed := scene.pack(room)
	var saved := ResourceSaver.save(scene, OUT)
	print("bedroom: ", cells, " cells, ", THINGS.size(), " things; pack ", packed, ", save ", saved, " -> ", OUT)
	main.free()
	room.free()
	quit(0 if packed == OK and saved == OK else 1)


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node
	for child in node.get_children():
		_own(child, owner_node)
