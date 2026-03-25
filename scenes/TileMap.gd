extends TileMap

# Assume the player node is named "Player"
@onready var player = $"../Player"
# Set the jump velocity
var jump_velocity = -800

func _process(delta):
	# Get the player's global position
	var player_global_pos = player.position #- Vector2i(0, 16)
	# Convert the global position to the TileMap's local coordinates
	var player_local_pos = to_local(player_global_pos)+ Vector2(0, 15)
	var player_local_posleft = to_local(player_global_pos)+ Vector2(15, 15)
	var player_local_posright= to_local(player_global_pos)+ Vector2(-15, 15)
	# Convert the local position to the TileMap's cell coordinates
	var player_tile_pos = local_to_map(player_local_pos)
	var player_tile_posleft = local_to_map(player_local_posleft)
	var player_tile_posright = local_to_map(player_local_posright)
	
	# Get the tile ID at the player's position
	var tile_id = get_cell_atlas_coords(1, player_tile_pos, false) # 0 is the layer, false to ignore proxies
	var tile_idleft = get_cell_atlas_coords(1, player_tile_posleft, false) # 0 is the layer, false to ignore proxies
	var tile_idright = get_cell_atlas_coords(1, player_tile_posright, false) # 0 is the layer, false to ignore proxies
	# Get the tile ID at the player's position
	var tile_source_id = get_cell_source_id(1, player_tile_pos, false) # 0 is the layer, false to ignore proxies
	var tile_source_idleft = get_cell_source_id(1, player_tile_posleft, false) # 0 is the layer, false to ignore proxies
	var tile_source_idright = get_cell_source_id(1, player_tile_posright, false) # 0 is the layer, false to ignore proxies
	
	# Debug print statements to check values
	#print("Player Global Position: ", player_global_pos)
	#print("Player Local Position: ", player_local_pos)
	#print("Player TileMap Position: ", player_tile_pos)
	#print("Tile ID: ", tile_id)
	#print("Source ID: ", tile_source_id)
	
	if tile_source_id == 3 or tile_source_idleft == 3 or tile_source_idright == 3:
		
		if tile_id == Vector2i(12, 0) or tile_id == Vector2i(13, 0) or tile_id == Vector2i(14, 0) or tile_id == Vector2i(15, 0): # The ID of the jump pad tile
			if player.velocity.x != 0: # Only apply if the player is moving downward
				$"../Environmental Audio/jumpPad".play()
				print("Jump Pad Activated")
				player.velocity.y = jump_velocity
				
		if tile_idleft == Vector2i(12, 0) or tile_idleft == Vector2i(13, 0) or tile_idleft == Vector2i(14, 0) or tile_idleft == Vector2i(15, 0): # The ID of the jump pad tile
			if player.velocity.x != 0: # Only apply if the player is moving downward
				$"../Environmental Audio/jumpPad".play()
				print("Jump Pad Activated")
				player.velocity.y = jump_velocity
				
		if tile_idright == Vector2i(12, 0) or tile_idright == Vector2i(13, 0) or tile_idright == Vector2i(14, 0) or tile_idright == Vector2i(15, 0): # The ID of the jump pad tile
			if player.velocity.x != 0: # Only apply if the player is moving downward
				$"../Environmental Audio/jumpPad".play()
				print("Jump Pad Activated")
				player.velocity.y = jump_velocity
				
		if tile_idright == Vector2i(16, 0) or tile_idleft == Vector2i(16, 0) or tile_id == Vector2i(16, 0): # The ID of the jump pad tile
			if player.velocity.x != 0: # Only apply if the player is moving downward
				$"../Environmental Audio/jumpPad".play()
				print("Bed Jump Pad Activated")
				player.velocity.y = jump_velocity / 2
