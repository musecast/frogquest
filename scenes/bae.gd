extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	if $"../Player".velocity.y > 0:
		$".".z_index = 3
	elif $"../Player".position.y > position.y:
		await get_tree().create_timer(0.25).timeout
		$".".z_index = 0
	else:
		$".".z_index = 3
