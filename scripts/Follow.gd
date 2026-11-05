extends Node2D
## Over someone without being part of them: where `anchor` is on its parent (in the parent's own space),
## every frame, on whole pixels, but nothing else of it (not its scale, its turn or anything done to it).
## For what pops up over Froggy's head (his "!").

var anchor := Vector2.ZERO


func _ready() -> void:
	top_level = true
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var him := get_parent() as Node2D
	if him:
		global_position = him.to_global(anchor).round()
