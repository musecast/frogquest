extends SceneTree
## Headless test for the hidden flies (FlyHunt.gd, Fly.gd): every fly hovers in open air just over a
## real ledge of the story level, the frog can actually get to every one (real jumps through the real
## level, from where a new climb starts), the tongue gets them from close by but never through a wall,
## catching them counts and saves, a caught fly stays caught, and the last one unlocks the Golden Frog,
## once. Never touches your real save (it uses a scratch wardrobe and a scratch climb).
##   Godot --headless --path . --script res://tools/validate_flies.gd

const SCRATCH_WARDROBE := "user://test_wardrobe_flies.save"
const SCRATCH_SAVE := "user://test_flies_save_game.save"
# The frog's jumps, as player.gd and Trajectory.gd make them.
const GRAVITY := 980.0
const DT := 1.0 / 60.0
const FLOOR_FRICTION := 300.0  # player.gd SPEED: velocity.x eased to 0 by this much a frame on the floor
const MAX_STEPS := 240  # 4 seconds in the air at most
const MAX_PLACES := 6000

var FlyHunt: GDScript  # (loaded in _run: in --script mode the autoloads it uses only exist by then)
var Fly: GDScript

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	FlyHunt = load("res://scripts/FlyHunt.gd")
	Fly = load("res://scripts/Fly.gd")
	var mm := root.get_node("MusicManager")
	var real_path: String = mm.wardrobe_path
	mm.wardrobe_path = SCRATCH_WARDROBE

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

	# The frog can get to every one.
	await _check_reach(main)

	# The tongue: from close by, never from far off, never through a wall.
	var space := root.get_world_2d().direct_space_state
	var wall := StaticBody2D.new()
	var wall_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8.0, 40.0)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.position = Vector2(100030.0, 0.0)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	space = root.get_world_2d().direct_space_state
	var none: Array[RID] = []
	_expect(Fly.can_catch(space, Vector2(100000.0, 100.0), Vector2(100050.0, 100.0), none), "the tongue gets a fly from close by")
	_expect(not Fly.can_catch(space, Vector2(100000.0, 100.0), Vector2(100080.0, 100.0), none), "but not from far off")
	_expect(not Fly.can_catch(space, Vector2(100000.0, 0.0), Vector2(100050.0, 0.0), none), "and never through a wall")
	wall.queue_free()

	# Catching them all, on a fresh save (a scratch wardrobe file; your own save isn't touched).
	var real_caught: Array = mm.flies_caught.duplicate()
	var real_skins: Array = mm.unlocked_skins.duplicate()
	mm.flies_caught = []
	mm.unlocked_skins.erase(FlyHunt.REWARD)
	var level := Node2D.new()
	root.add_child(level)
	FlyHunt.spawn_into(level)
	var flies := level.get_children()
	_expect(flies.size() == FlyHunt.total(), "all %d flies are out on a fresh save" % FlyHunt.total())
	for fly in flies.slice(0, flies.size() - 1):
		fly.catch_now()
	_expect(FlyHunt.count_caught() == FlyHunt.total() - 1 and not (FlyHunt.REWARD in mm.unlocked_skins),
		"each catch counts, and the Golden Frog waits for the last one")
	flies[-1].catch_now()
	flies[-1].catch_now()
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

	if FileAccess.file_exists(SCRATCH_WARDROBE):
		DirAccess.remove_absolute(SCRATCH_WARDROBE)
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


## Searches out from where a new climb starts, jumping the way the frog jumps (every pull direction
## and strength, a step apart), landing to jump again, until the tongue has been in reach of every
## fly. The world's scripts don't run meanwhile, and its few solid bodies are left out with them: the
## blocked path (it breaks when he bumps it) and the keyhole (the key opens it) open in play anyway,
## and the rest belong to the finale, above every fly. Its walls and floors are the TileMap's.
func _check_reach(main: Node) -> void:
	var player: CharacterBody2D = main.get_node("Player")
	player.save_path = SCRATCH_SAVE
	var start := player.position
	player.collision_layer = 0  # (out of the way: a stand-in does the jumping)
	player.collision_mask = 0
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	var body := CharacterBody2D.new()
	body.collision_layer = 0
	body.collision_mask = 9  # player.tscn's: the tiles and the rest of the world
	for prop in ["floor_max_angle", "floor_snap_length", "floor_stop_on_slope", "floor_block_on_wall",
			"floor_constant_speed", "wall_min_slide_angle", "safe_margin", "max_slides", "motion_mode", "up_direction"]:
		body.set(prop, player.get(prop))
	body.scale = player.scale
	body.process_mode = Node.PROCESS_MODE_ALWAYS  # (a disabled body is taken out of the physics)
	var shape: CollisionShape2D = player.get_node("CollisionShape2D").duplicate()
	body.add_child(shape)
	main.add_child(body)
	for _i in 4:
		await physics_frame  # (the level's collision gets built)
	await physics_frame  # (the search runs inside a physics frame, as move_and_slide expects)
	var began := Time.get_ticks_msec()
	if not Engine.is_in_physics_frame():
		_failures.append("the jump search has to run inside a physics frame")
	var spots: Array = FlyHunt.SPOTS
	var reached := {}
	var standing := {}  # (and caught from where he comes to stand: not only by a lucky shot in passing)
	var space := body.get_world_2d().direct_space_state
	var tm: TileMap = main.get_node("TileMap")
	var launches := _launches()
	var first: Variant = _jump(body, tm, start, Vector2.ZERO, spots, reached, space)
	if first == null:
		_failures.append("the frog never lands from where a new climb starts")
		main.queue_free()
		return
	_stood(first, spots, standing, space, body)
	var places: Array = [first]
	var seen := {_key(first): true}
	var i := 0
	while i < places.size() and standing.size() < spots.size() and places.size() < MAX_PLACES:
		# (nearest to a fly not yet caught from where he can stand first: the search heads for them)
		var best := i
		var best_d := INF
		for j in range(i, mini(places.size(), i + 400)):
			for k in spots.size():
				if not standing.has(k):
					var d: float = places[j].distance_squared_to(spots[k])
					if d < best_d:
						best_d = d
						best = j
		var from: Vector2 = places[best]
		places[best] = places[i]
		places[i] = from
		i += 1
		if i % 100 == 0:
			print("  ...%d places jumped from, %d found, %d of %d flies in reach, %.0f s" % [
				i, places.size(), reached.size(), spots.size(), (Time.get_ticks_msec() - began) / 1000.0])
		for launch in launches:
			var land: Variant = _jump(body, tm, from, launch, spots, reached, space)
			if land != null and not seen.has(_key(land)):
				seen[_key(land)] = true
				places.append(land)
				_stood(land, spots, standing, space, body)
	var missing := []
	for k in spots.size():
		if not reached.has(k):
			var nearest: Vector2 = places[0]
			for p in places:
				if p.distance_squared_to(spots[k]) < nearest.distance_squared_to(spots[k]):
					nearest = p
			missing.append("%d at %s (nearest place he can stand: %s, %.0f away)" % [
				k, spots[k], nearest.round(), nearest.distance_to(spots[k])])
	_expect(missing.is_empty(), "the frog can get to every fly (out of reach: %s; searched %d places)" % [missing, i])
	var only_in_passing := []
	for k in spots.size():
		if reached.has(k) and not standing.has(k):
			only_in_passing.append("%d at %s" % [k, spots[k]])
	_expect(only_in_passing.is_empty(),
		"and every one from somewhere he can stand, not only by a lucky shot (only in passing: %s)" % [only_in_passing])
	print("  Jumped from %d landing places (%d found) in %.1f s." % [i, places.size(), (Time.get_ticks_msec() - began) / 1000.0])
	main.queue_free()
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(SCRATCH_SAVE)


## One jump from on the floor at from with launch velocity launch (player.gd's rules: on the floor,
## friction; in the air, gravity, and a wall bounces him back at 40%; jump pads, as TileMap.gd), until
## he stops on a floor. Marks the flies his tongue could get on the way in reached. Where he stops, or
## null if he never does.
func _jump(body: CharacterBody2D, tm: TileMap, from: Vector2, launch: Vector2, spots: Array, reached: Dictionary,
		space: PhysicsDirectSpaceState2D) -> Variant:
	body.global_position = from
	body.velocity = launch
	var exclude: Array[RID] = [body.get_rid()]
	var temp_vx := 0.0
	var airborne := 0
	for step in MAX_STEPS:
		if not body.is_on_floor() and step > 0:
			body.velocity.y += GRAVITY * DT
			if body.is_on_wall():
				body.velocity.x = -temp_vx
		else:
			body.velocity.x = move_toward(body.velocity.x, 0.0, FLOOR_FRICTION)
		temp_vx = body.velocity.x / 2.5
		_jump_pads(body, tm)
		body.move_and_slide()
		var mouth: Vector2 = Fly.mouth_of(body)
		for k in spots.size():
			if not reached.has(k) and mouth.distance_squared_to(spots[k]) <= Fly.TONGUE_RANGE * Fly.TONGUE_RANGE \
					and Fly.can_catch(space, mouth, spots[k], exclude):
				reached[k] = true
		if body.is_on_floor():
			if step > 0 and is_zero_approx(body.velocity.x) and (airborne > 0 or launch == Vector2.ZERO):
				return body.global_position
		else:
			airborne += 1
	return null


## Where he's come to stand (at): the flies his tongue gets from there, marked in standing. Not from a scrap of
## floor shut in under something (a mushroom's stem, under its cap: narrower than a frog's width either side of
## him, and a ceiling close over him), which only a lucky shot lands on.
func _stood(at: Vector2, spots: Array, standing: Dictionary, space: PhysicsDirectSpaceState2D, body: CharacterBody2D) -> void:
	var mouth: Vector2 = at + Fly.mouth_of(body) - body.global_position
	var exclude: Array[RID] = [body.get_rid()]
	var narrow := false
	for dx in [-18.0, 18.0]:
		var under := space.intersect_ray(PhysicsRayQueryParameters2D.create(at + Vector2(dx, 0.0), at + Vector2(dx, 40.0), body.collision_mask, exclude))
		narrow = narrow or under.is_empty() or under.normal.y > -0.5
	var shut_in := not space.intersect_ray(PhysicsRayQueryParameters2D.create(at, at + Vector2(0.0, -90.0), body.collision_mask, exclude)).is_empty()
	if narrow and shut_in:
		return
	for k in spots.size():
		if not standing.has(k) and Fly.can_catch(space, mouth, spots[k], exclude):
			standing[k] = true


## TileMap.gd: the jump pad tiles (source 3, atlas 12-15 by 0; the bed is 16 by 0) send him up, if
## he's moving across them.
func _jump_pads(body: CharacterBody2D, tm: TileMap) -> void:
	if body.velocity.x == 0.0:
		return
	for offset in [Vector2(0, 15), Vector2(15, 15), Vector2(-15, 15)]:
		var cell := tm.local_to_map(tm.to_local(body.global_position) + offset)
		if tm.get_cell_source_id(1, cell) != 3:
			continue
		var atlas := tm.get_cell_atlas_coords(1, cell)
		if atlas.y == 0 and atlas.x >= 12 and atlas.x <= 15:
			body.velocity.y = -800.0
		elif atlas == Vector2i(16, 0):
			body.velocity.y = -400.0


## Every launch a pull can make, a step apart (Trajectory.gd: x times 1.5 and y times 1.1, clamped to
## 800 and 450, then a push for the gentle ones).
func _launches() -> Array:
	var out := {}
	for raw_x in range(-800, 801, 100):
		for raw_y in [-450, -390, -330, -270, -210, -150, -90, -30]:
			var v := Vector2(clampf(raw_x, -800.0, 800.0), clampf(raw_y, -450.0, 450.0))
			if absf(v.x) < 450.0:
				v.x += 200.0 * signf(v.x)
			if absf(v.x) < 450.0 and absf(v.y) > 350.0:
				v.x += 50.0 * signf(v.x)
			out[v] = true
	return out.keys()


func _key(p: Vector2) -> Vector2i:
	return Vector2i((p / 12.0).floor())


func _solid(tm: TileMap, cell: Vector2i) -> bool:
	for layer in tm.get_layers_count():
		if not tm.is_layer_enabled(layer):
			continue
		var td := tm.get_cell_tile_data(layer, cell)
		if td and (td.get_collision_polygons_count(0) > 0 or _buried_wall(td)):
			return true
	return false


## A wall tile buried in the tree (tools/thin_tilemap_collision.gd took its collision: nothing reaches it).
func _buried_wall(td: TileData) -> bool:
	return td.has_custom_data("buried_twin_of") and int(td.get_custom_data("buried_twin_of")) > 0


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
