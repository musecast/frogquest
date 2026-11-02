extends SceneTree

const RESOURCES := [
	"res://Main.tres",
	"res://Shadow.tres",
	"res://scenes/BootLoader.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/EndlessMode.tscn",
	"res://scenes/player.tscn",
	"res://scenes/endlessplayer.tscn",
	"res://scenes/RemoveAdsScreen.gd",
	"res://scenes/SettingsScreen.gd",
	"res://scripts/AdsManager.gd",
	"res://scripts/BootLoader.gd",
	"res://scripts/ComplianceConfig.gd",
	"res://scripts/MusicManager.gd",
	"res://scripts/PrivacyTermsPopup.gd",
]


## Script errors while loading (a script that doesn't parse still "loads", as a broken resource).
class ScriptErrors extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


func _initialize() -> void:
	var script_errors := ScriptErrors.new()
	OS.add_logger(script_errors)
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
	for e in script_errors.errors:
		printerr("Release validation script error: " + e)
		failed = true
	quit(1 if failed else 0)
