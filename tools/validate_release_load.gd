extends SceneTree

const RESOURCES := [
	"res://Main.tres",
	"res://Shadow.tres",
	"res://scenes/BootLoader.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/EndlessMode.tscn",
	"res://scenes/player.tscn",
	"res://scenes/endlessplayer.tscn",
]


func _initialize() -> void:
	var failed := false
	for path in RESOURCES:
		var res := ResourceLoader.load(path)
		var instance: Node = null
		if res is PackedScene:
			instance = (res as PackedScene).instantiate()
			if instance:
				instance.queue_free()
		if res == null or (res is PackedScene and instance == null):
			push_error("Release validation failed to load: %s" % path)
			failed = true
		else:
			print("Release validation loaded: %s" % path)
	quit(1 if failed else 0)
