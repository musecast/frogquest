extends SceneTree

## Adds Google's ads Swift package to an exported Xcode project, using the AdMob addon's own patcher.
## The addon's exporter does this in a deferred step, and a --headless export quits before it runs.
## usage: Godot --headless --path . --script res://tools/ci/patch_admob_pbxproj.gd -- <path to project.pbxproj>

const PbxprojService := preload("res://addons/admob/internal/services/pbxproj_service.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not FileAccess.file_exists(args[0]):
		push_error("patch_admob_pbxproj: pass the exported project.pbxproj after --")
		quit(1)
		return
	PbxprojService.patch(args[0], "PoingGodotAdMobDepsPackage")
	var patched := FileAccess.get_file_as_string(args[0]).contains("PoingGodotAdMobDeps in Frameworks")
	if not patched:
		push_error("patch_admob_pbxproj: the AdMob Swift package is still missing from " + args[0])
	quit(0 if patched else 1)
