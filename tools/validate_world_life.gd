extends SceneTree
## The sky and the little life round the World Tree (Sky.gd, Wildlife.gd and the rest), in the real level:
## the sky just over the skybox and under everything else, none of it drawn on the trunk's wall, none of it
## underground, more clouds the higher he climbs; the flowers and grass sitting in the grass, nothing of it
## solid; little birds on something solid and off when the frog comes near (and back once he's far off);
## butterflies about their flowers, off up when he's near; fireflies inside the tree, clear of the hidden
## flies; leaves only where there's tree and light. Scratch save and wardrobe; yours are byte-checked by the
## caller.
##   Godot --headless --path . --script res://tools/validate_world_life.gd

const SAVE := "user://test_world_life_save_game.save"
const WARDROBE := "user://test_world_life_wardrobe.save"
const PORTRAIT := Vector2(480, 698)

var _failures: Array[String] = []
var _view: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		_failures.append("timed out")
		_finish())
	var mm := root.get_node("MusicManager")
	var real := [mm.wardrobe_path, mm.look_made]
	mm.wardrobe_path = WARDROBE
	mm.look_made = true
	_view = SubViewport.new()
	_view.size = Vector2i(PORTRAIT)
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	var player: CharacterBody2D = main.get_node("Player")
	player.save_path = SAVE
	_view.add_child(main)
	for _i in 10:
		await process_frame
	player._on_button_pressed()
	player.waking = false
	main._tv_listening = false
	player.set_physics_process(false)
	var tiles: TileMap = main.get_node("TileMap")
	var sprites: Node = main.get_node("World Sprites")
	var sky: Node2D = sprites.get_node_or_null("Sky")
	var life: Node2D = main.get_node_or_null("Wildlife")
	_expect(sky != null and life != null, "the sky and the little life are in the level")
	if sky == null or life == null:
		_finish()
		return

	# The sky: just over the skybox (at its depth), so under everything else in the world.
	var skybox: Node = sprites.get_node("BlueSkySkybox")
	_expect(sky.get_index() == skybox.get_index() + 1 and sky.z_index == skybox.z_index,
		"the sky's drawn just over the skybox, at its depth (index %d after %d, z %d)" % [sky.get_index(), skybox.get_index(), sky.z_index])
	var mask: ShaderMaterial = sky.material
	var wall: Texture2D = mask.get_shader_parameter("wall")
	_expect(wall != null, "the trunk's wall is a mask for the sky")
	if wall:
		var origin: Vector2 = mask.get_shader_parameter("wall_origin")
		var cell: float = mask.get_shader_parameter("cell")
		_expect(is_equal_approx(cell, tiles.tile_set.tile_size.x * tiles.global_scale.x),
			"a mask texel a cell, at the tile map's own size (%s)" % cell)
		var img := wall.get_image()
		var kinds := {}
		var solid: Array[Vector2i] = []
		for c in tiles.get_used_cells(sky.WALL_LAYER):
			var key := Vector3i(tiles.get_cell_source_id(sky.WALL_LAYER, c), tiles.get_cell_atlas_coords(sky.WALL_LAYER, c).x,
				tiles.get_cell_atlas_coords(sky.WALL_LAYER, c).y)
			if not kinds.has(key):
				kinds[key] = sky._solid(key.x, Vector2i(key.y, key.z))
			if kinds[key]:
				solid.append(c)
		var wrong := 0
		for c: Vector2i in solid.slice(0, 400):
			var middle := tiles.to_global(tiles.map_to_local(c))
			var texel := Vector2i(((middle - origin) / cell).floor())
			if img.get_pixel(texel.x, texel.y).r < 0.5:
				wrong += 1
		_expect(wrong == 0 and solid.size() > 1000, "the trunk's wall is all in the mask (%d of %d out)" % [wrong, solid.size()])
		var trunk := tiles.to_global(tiles.map_to_local(Vector2i(150, -60)))  # (inside the trunk)
		var texel := Vector2i(((trunk - origin) / cell).floor())
		_expect(tiles.get_cell_source_id(sky.WALL_LAYER, Vector2i(150, -60)) != -1 and img.get_pixel(texel.x, texel.y).r > 0.5,
			"in the trunk: no sky")
	var again: TileMapLayer = sky.get_node_or_null("TilesAgain")
	_expect(again != null and again.get_used_cells().size() > 0 and not again.collision_enabled,
		"the see-through tiles of the back wall's layer drawn again over the sky (with no collisions)")

	# More clouds the higher he climbs: each layer, the ones he'd see low down against high up.
	var layers: Array = sky._layers.filter(func(l: Node) -> bool: return l.has_method("count"))
	_expect(layers.size() == 3, "three layers of clouds (%d)" % layers.size())
	for layer in layers:
		var low := 0
		var high := 0
		for at: Vector2 in layer._at:
			var h: float = sky.height_at(at.y / layer.f)
			if h >= 0.0 and h < 300.0:
				low += 1
			elif h >= 450.0 and h < 750.0:
				high += 1
		_expect(high > low, "more clouds up high than low down (layer moving %.2f: %d low, %d high)" % [layer.f, low, high])
	_expect(sky.odds(sky.LAYERS[2].odds, 100.0) == 0.0, "none of the nearest clouds low down: the sky he knows")
	_expect(sky.tint_at(50.0)[0].a == 0.0 and sky.tint_at(50.0)[1].a == 0.0, "no tint on the sky low down")
	_expect(sky.tint_at(740.0)[0].a > 0.2, "a deeper sky over the sea of clouds")

	# None of it underground (home), all of it out on the ground.
	await _look(player, Vector2(1290, 260))
	_expect(not sky.visible, "no sky drawn with him underground, at home")
	await _look(player, Vector2(1700, -472))
	_expect(sky.visible, "the sky's out with him on the ground")

	# The ground's things: every one down, sitting in the grass (its bottom a pixel or so into the top of
	# the ground's art), none of it solid.
	var decor: Node2D = life.get_node("GroundDecor")
	_expect(decor.placed == decor.PLACES.size(), "every flower, tuft and stone put down (%d of %d)" % [decor.placed, decor.PLACES.size()])
	var off := 0
	for s in decor.get_children():
		var sprite := s as Sprite2D
		var bottom := sprite.position.y + sprite.texture.get_height() * sprite.scale.y
		var x := sprite.position.x + sprite.texture.get_width() * sprite.scale.y * 0.5
		var top: float = decor.ground_top(tiles, x, -500.0, 300.0)
		if absf(bottom - top) > 2.5 and not _stacked(decor, sprite):
			off += 1
	_expect(off == 0, "everything on the ground sits in the grass (%d not)" % off)
	_expect(_solid_bits(life) == 0 and _solid_bits(sky) == 0, "nothing of the sky or the little life is solid")
	_expect(decor.z_index < 0, "the ground's things behind Froggy and the ground's own tiles")
	# What's in the dirt: a few big, quiet things (the frog fossil, stones), every one of them down, all over
	# plain dirt, none up in the air; no roots (scrapped).
	var dirt: Node2D = life.get_node("DirtDecor")
	_expect(dirt.count() == dirt.THINGS.size(), "everything in the dirt put down (%d of %d)" % [dirt.count(), dirt.THINGS.size()])
	var names: Array = dirt.things.map(func(t: Array) -> String: return t[0])
	_expect("frog_fossil" in names and "roots" not in names, "the frog fossil, and no roots")
	var astray := 0
	for t in dirt.things:
		if not dirt.fits(t[1]) or t[1].position.y < dirt.SURFACE + 12.0:
			astray += 1
	_expect(astray == 0, "every one of them in the dirt (%d not)" % astray)
	var art: Script = load("res://scripts/CritterArt.gd")
	var off_grid := 0
	for s in decor.get_children():
		var sprite := s as Sprite2D
		var region: Rect2 = (sprite.texture as AtlasTexture).region
		var is_tile: bool = region.size == Vector2(18, 18)
		if not is_equal_approx(sprite.scale.x, 1.2 if is_tile else art.PIXEL):
			off_grid += 1
	_expect(off_grid == 0, "the flowers and stones drawn at the tiles' own pixel (%d not)" % off_grid)

	# The birds: each on something solid, none where a hidden fly is.
	var flies: Array = load("res://scripts/FlyHunt.gd").SPOTS
	var ground_top := Callable(load("res://scripts/GroundDecor.gd"), "ground_top")
	_expect(life.birds.size() >= 8, "birds about (%d)" % life.birds.size())
	for b in life.birds:
		if b.get_meta("on_sign", false):
			continue  # (on top of a sign: Wildlife puts it there)
		var under: float = ground_top.call(tiles, b.perch.x, b.perch.y - 30.0, 60.0)
		_expect(absf(under - b.perch.y) < 1.0, "a bird on something solid at %s (%s under it)" % [b.perch, under])
		for f in flies:
			_expect(b.perch.distance_to(f) > 150.0, "a bird well away from the fly hiding at %s (%s)" % [f, b.perch])
	# One flies off when he comes near (a flutter and a chirp), and isn't back while he's still about.
	var bird: Node2D = life.birds[2]
	await _look(player, bird.perch + Vector2(300, -10))
	_expect(bird.state == bird.SITTING and bird.visible, "a bird sitting with him a way off")
	player.global_position = bird.perch + Vector2(40, -10)
	for _i in 3:
		await process_frame
	_expect(bird.state == bird.FLYING and bird._sound.playing, "and off it goes when he comes near, with a flutter and a chirp")
	var from: Vector2 = bird.position
	for _i in 20:
		await process_frame
	_expect(bird.position.y < from.y - 5.0, "up and away")
	bird._t = 99.0
	await process_frame
	await process_frame
	_expect(bird.state == bird.GONE and not bird.visible, "gone")
	bird._gone = 99.0
	await process_frame
	_expect(bird.state == bird.GONE, "not back with him still about")
	await _look(player, bird.perch + Vector2(-1600, -1000))
	_expect(bird.state == bird.SITTING and bird.position == bird.perch, "back on its perch once he's far off (and it's not on the screen) (state %d, at %s, perch %s, him %s, view %s)" % [bird.state, bird.position, bird.perch, player.global_position, bird._view()])
	# Every bird, startled from either side, flies the way that's open: never into a wall or a ceiling
	# (its middle never inside anything solid), and shut in, it fades rather than fly through.
	var space: PhysicsDirectSpaceState2D = bird.get_world_2d().direct_space_state
	var into_walls := []
	var flown := 0
	for b in life.birds:
		for side in [-40.0, 40.0]:
			await _look(player, b.perch + Vector2(side * 8.0, -10.0))
			b.state = b.SITTING
			b.position = b.perch
			b.visible = true
			player.global_position = b.perch + Vector2(side, -10.0)
			b.fly_off()
			for _i in 90:
				b._fly(1.0 / 60.0)
				if b.state != b.FLYING:
					break
				flown += 1
				var q := PhysicsPointQueryParameters2D.new()
				q.position = b.global_position + Vector2(0.0, -4.0 * b.scale.y)
				q.exclude = [player.get_rid()]
				if not space.intersect_point(q, 1).is_empty():
					into_walls.append(b.perch)
					break
			b.state = b.GONE
			b.visible = false
	_expect(into_walls.is_empty() and flown >= life.birds.size() * 2 * 20,
		"birds fly the way that's open, never into a wall (%s; %d frames flown)" % [into_walls, flown])

	# Butterflies about their flowers; off up when he comes near.
	_expect(life.butterflies.size() >= 5, "butterflies about (%d)" % life.butterflies.size())
	var fly: Node2D = life.butterflies[3]
	await _look(player, fly.home + Vector2(320, 0))
	for _i in 240:
		await process_frame
	_expect(absf(fly.position.x - fly.home.x) < fly.ROAM.x + 30.0 and fly.position.y < fly.home.y + 2.0
		and fly.position.y > fly.home.y - fly.ROAM.y - 40.0, "a butterfly about its flowers (%s, home %s)" % [fly.position, fly.home])
	player.global_position = fly.position + Vector2(20, 0)
	await process_frame
	await process_frame
	_expect(fly._scared > 0.0 and fly._target.y < fly.position.y, "it flutters off up when he comes near")

	# Fireflies: inside the tree, clear of every hidden fly, their own light in the dark.
	var glow: Node2D = life.get_node("Fireflies")
	_expect(glow.count() >= 12, "fireflies in the dark (%d)" % glow.count())
	var outside := 0
	var by_fly := 0
	for bug in glow._bugs:
		if tiles.get_cell_source_id(4, tiles.local_to_map(tiles.to_local(bug.home))) == -1:
			outside += 1
		for f in flies:
			if bug.home.distance_to(f) < glow.CLEAR_OF:
				by_fly += 1
	_expect(outside == 0, "the fireflies are all inside the tree (%d out)" % outside)
	_expect(by_fly == 0, "none by a hidden fly (its glint stays its own)")
	var light := glow.material as CanvasItemMaterial
	_expect(light != null and light.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, "they shine in the dark")

	# Leaves: falling past the tree low down, none in the dark.
	var leaves: Node2D = life.get_node("Leaves")
	await _look(player, Vector2(2900, -900))
	leaves._leaves.clear()
	leaves._wait = 0.0
	for _i in 300:
		await process_frame
	_expect(leaves._leaves.size() > 0, "leaves falling past the tree (%d)" % leaves._leaves.size())
	await _look(player, Vector2(2800, -2700))
	leaves._leaves.clear()
	leaves._wait = 0.0
	for _i in 300:
		await process_frame
	_expect(leaves._leaves.is_empty(), "none in the dark (%d)" % leaves._leaves.size())
	_expect(leaves._petals.size() == 2, "the white petals drawn, two ways up")
	var petal_img: Image = leaves._petals[0].get_image()
	var petal_colours := {}
	for py in petal_img.get_height():
		for px in petal_img.get_width():
			var pc := petal_img.get_pixel(px, py)
			if pc.a > 0.0:
				petal_colours[pc.to_html(false)] = true
	_expect(petal_colours.has("fefefe") and petal_colours.has("e8fbfa") and petal_colours.has("444b60")
		and petal_colours.keys().all(func(h: String) -> bool: return h in ["fefefe", "e8fbfa", "444b60"]),
		"the falling petals are the ledges' white petals' own colours, no green left (%s)" % [petal_colours.keys()])
	await _look(player, Vector2(2800, -5650))  # (the castle: where the petals have fallen)
	leaves._leaves.clear()
	leaves._wait = 0.0
	for _i in 300:
		await process_frame
	_expect(not main.way_open and leaves._leaves.is_empty(),
		"at the castle, before its frog has opened the way: nothing falling yet (%d)" % leaves._leaves.size())
	main._open_the_way()
	main.get_node("finale/Control/froggod").stop()  # (quiet: it's the petals this is about)
	leaves._wait = 0.0
	for _i in 300:
		await process_frame
	_expect(not leaves._leaves.is_empty() and leaves._leaves.all(func(l: Dictionary) -> bool: return l.petal),
		"once he has, it's white petals that fall (%d, %s)" % [leaves._leaves.size(), leaves._leaves.map(func(l: Dictionary) -> bool: return l.petal)])
	await _look(player, Vector2(3950, -5620))  # (the castle's east end, past the tree)
	leaves._leaves.clear()
	for _i in 30:  # (as many as there can be: where each comes in is chance, across what's seen)
		leaves._wait = 0.0
		await process_frame
	_expect(leaves._leaves.any(func(l: Dictionary) -> bool: return l.petal and l.x0 > 3700.0),
		"and across the castle's whole width, not just the tree's (%s)" % [leaves._leaves.map(func(l: Dictionary) -> int: return int(l.x0))])
	# Petals fall in front of the platforms (the leaves behind them); what falls comes to rest on the floor it
	# lands on, lies there, and slowly fades; Froggy landing by it throws it up, and it flutters back down.
	_expect(leaves._petal_layer.z_index > 0 and not leaves._petal_layer.z_as_relative and leaves.z_index < 0,
		"the petals fall in front of the platforms, the leaves behind them")
	await _look(player, Vector2(2780, -5650))  # (the castle door: its floor)
	leaves._leaves.clear()
	leaves._wait = 9999.0  # (just this one)
	var petal := {"x0": 2740.0, "x": 2740.0, "y": -5660.0, "t": 0.0, "phase": 0.0, "fall": 200.0, "sway": 1.5,
		"wide": 0.0, "gold": false, "flip": false, "petal": true, "vx": 0.0, "vy": 0.0, "down": false, "rest": 0.0,
		"lies": 8.0}
	leaves._leaves.append(petal)
	for _i in 600:
		if petal.down:
			break
		await process_frame
	var floor_hit: Dictionary = main.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(
		Vector2(petal.x, petal.y - 4.0), Vector2(petal.x, petal.y + 40.0), 1, [player.get_rid()]))
	_expect(petal.down and not floor_hit.is_empty() and absf(floor_hit.position.y - (petal.y + leaves._half_height())) < 2.0,
		"a petal lands on the floor, and lies on it (%s, %s)" % [Vector2(petal.x, petal.y).round(), floor_hit.get("position")])
	var lay_at: float = petal.y
	for _i in 30:
		await process_frame
	_expect(petal.down and petal.y == lay_at and petal in leaves._leaves, "it stays there a while")
	leaves.kick(Vector2(petal.x + 12.0, petal.y + leaves._half_height()), 600.0)
	_expect(not petal.down and petal.vy < 0.0 and petal.vx < 0.0, "Froggy landing by it throws it up, away from him")
	for _i in 900:
		if petal.down:
			break
		await process_frame
	_expect(petal.down, "and it flutters back down, to lie where it lands")
	petal.rest = petal.lies + leaves.FADE + 0.1
	for _i in 3:
		await process_frame
	_expect(not petal in leaves._leaves, "it fades away in time")
	leaves._wait = 0.0

	await _look(player, Vector2(2900, -900))
	leaves._leaves.clear()
	leaves._wait = 0.0
	for _i in 300:
		await process_frame
	_expect(leaves._leaves.all(func(l: Dictionary) -> bool: return not l.petal), "lower down, still leaves")

	main.queue_free()
	for _i in 3:
		await process_frame
	mm.wardrobe_path = real[0]
	mm.look_made = real[1]
	_finish()


## Puts him (and the camera) at `at`, held there, and lets a few frames go by.
func _look(player: CharacterBody2D, at: Vector2) -> void:
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	player.currentHeight = (-at.y - 472) / 10
	player.fade_darkness()
	player.get_node("Camera2D").reset_smoothing()
	for _i in 6:
		await process_frame


## Whether a sprite is the top part of a tall thing (a sunflower's head, on its stem).
func _stacked(decor: Node2D, sprite: Sprite2D) -> bool:
	for other in decor.get_children():
		if other != sprite and absf(other.position.x - sprite.position.x) < 1.0 and absf(other.position.y - (sprite.position.y + 21.6)) < 1.5:
			return true
	return false


func _solid_bits(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is CollisionObject2D:
			n += 1
		n += _solid_bits(c)
	return n


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _finish() -> void:
	Engine.time_scale = 1.0
	for f in [SAVE, WARDROBE]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	if _failures.is_empty():
		print("World life test passed.")
	else:
		for f in _failures:
			print("  FAILED: ", f)
		print("World life test failed (%d)." % _failures.size())
	quit(1 if not _failures.is_empty() else 0)
