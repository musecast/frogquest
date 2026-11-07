extends TileMap
## The bouncy mushrooms (and the bed): moving sideways on one, he's thrown up hard. The rule is the
## original's, untouched (the climb was built around it): three points under his feet (below him, and a
## frog's width either side) on layer 1; any of them on a mushroom tile and he's moving sideways, up he
## goes at jump_velocity; on the bed, at half that. pad_jump_at tells it for a spot, so the aim line
## (Trajectory.shown_velocity) can show the throw before he lets go. A bounce off a mushroom throws up the
## leaves lying on it too (Leaves.bounce).

const MUSHROOMS := [Vector2i(12, 0), Vector2i(13, 0), Vector2i(14, 0), Vector2i(15, 0)]
const BED := Vector2i(16, 0)
const PAD_SOURCE := 3

@onready var player = $"../Player"
var jump_velocity = -800
var _last_bounce_ms := 0


func _process(_delta):
	var pad := pad_jump_at(player.position)
	if pad != 0.0 and player.velocity.x != 0:  # (moving sideways: landing on it, or jumping off it)
		$"../Environmental Audio/jumpPad".play()
		player.velocity.y = pad
		if pad == float(jump_velocity) and Time.get_ticks_msec() - _last_bounce_ms > 400:  # (a mushroom, not the bed: one bounce)
			_counted_bounce()
			_bounce_leaves(player.position)
		_last_bounce_ms = Time.get_ticks_msec()


## Another bounce off a mushroom: 25 and the Mushroom hat's yours.
func _counted_bounce() -> void:
	MusicManager.mushroom_bounces += 1
	if MusicManager.mushroom_bounces >= 25:
		MusicManager.unlock("mushroom")
	if MusicManager.mushroom_bounces <= 25:
		MusicManager.save_wardrobe()


## The leaves lying on the mushroom he's bouncing off thrown up off it too (Leaves.bounce): its whole cap, end
## to end, from the mushroom tiles in a row under his feet.
func _bounce_leaves(at: Vector2) -> void:
	var leaves := get_node_or_null("../Wildlife/Leaves")
	if leaves == null:
		return
	var feet := to_local(at)
	for probe in [Vector2(0, 15), Vector2(15, 15), Vector2(-15, 15)]:
		var cell := local_to_map(feet + probe)
		if not _is_mushroom(cell):
			continue
		var left := cell
		while _is_mushroom(left + Vector2i.LEFT):
			left += Vector2i.LEFT
		var right := cell
		while _is_mushroom(right + Vector2i.RIGHT):
			right += Vector2i.RIGHT
		var half := Vector2(tile_set.tile_size) * 0.5
		var a := to_global(map_to_local(left) - half)
		var b := to_global(map_to_local(right) + Vector2(half.x, -half.y))
		leaves.bounce(a.x, b.x, a.y)
		return


func _is_mushroom(cell: Vector2i) -> bool:
	return get_cell_source_id(1, cell, false) == PAD_SOURCE and get_cell_atlas_coords(1, cell, false) in MUSHROOMS


## The throw a mushroom gives him standing at at (his position): jump_velocity on a mushroom, half on the
## bed, 0 off them.
func pad_jump_at(at: Vector2) -> float:
	var feet := to_local(at)
	var cells := [local_to_map(feet + Vector2(0, 15)), local_to_map(feet + Vector2(15, 15)), local_to_map(feet + Vector2(-15, 15))]
	var on_pads := false
	for cell in cells:
		if get_cell_source_id(1, cell, false) == PAD_SOURCE:
			on_pads = true
	if not on_pads:
		return 0.0
	var mushroom := false
	var bed := false
	for cell in cells:
		var tile := get_cell_atlas_coords(1, cell, false)
		mushroom = mushroom or tile in MUSHROOMS
		bed = bed or tile == BED
	if bed:
		return jump_velocity / 2.0  # (the original checked the bed last, so it won)
	return float(jump_velocity) if mushroom else 0.0
