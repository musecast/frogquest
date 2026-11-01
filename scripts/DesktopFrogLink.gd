extends RefCounted
## Lil Froggy, the desktop frog: the bits the game and froggy share.
##
## Froggy runs as a second copy of the game ("frogquest.exe -- --desktop-frog"). The game lets
## him out with let_out(), and the two talk through small files in user://desktop_frog/ (same
## exe, same user folder): froggy keeps state.cfg fresh while he's out, and the game leaves
## command.cfg for him to pick up.
##
## Load it lazily (load(), not a preload) so iOS never pays for it at startup.

const LAUNCH_FLAG := "--desktop-frog"
const FROM_PREFIX := "--from="
const REVEAL_FLAG := "--reveal"
const DEBUG_UNLOCK_FLAG := "--debug-froggy"  # debug builds only: let him out without beating the game

const DIR := "user://desktop_frog"
const STATE_PATH := "user://desktop_frog/state.cfg"
const COMMAND_PATH := "user://desktop_frog/command.cfg"
const SETTINGS_PATH := "user://desktop_frog/froggy.cfg"
const STALE_AFTER := 6.0  # seconds without a heartbeat before we stop believing he's out


## True in the copy of the game that is Lil Froggy.
static func is_launch() -> bool:
	return LAUNCH_FLAG in OS.get_cmdline_user_args()


## The game window he should jump out of (screen pixels), if the game handed one over.
static func from_rect() -> Rect2i:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(FROM_PREFIX):
			var parts := arg.trim_prefix(FROM_PREFIX).split(",")
			if parts.size() == 4:
				return Rect2i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
	return Rect2i()


## The big first-time version of the jump out: he looks around, then smashes through.
static func is_reveal() -> bool:
	return REVEAL_FLAG in OS.get_cmdline_user_args()


## Computers only: he needs a see-through window to live in.
static func is_supported() -> bool:
	return OS.has_feature("pc") \
		and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY) \
		and bool(ProjectSettings.get_setting_with_override("display/window/per_pixel_transparency/allowed"))


## Once he's got out (see escapes_this_time), he's yours to let out whenever you like.
static func is_unlocked() -> bool:
	if OS.is_debug_build() and DEBUG_UNLOCK_FLAG in OS.get_cmdline_user_args():
		return true
	return MusicManager.desktop_frog_unlocked or has_muse_pro()


## Getting out is a rare surprise: a win only lets him out once in a long while (every time in a
## debug build, so he can be tested).
const ESCAPE_CHANCE := 1.0 / 500.0

static func escapes_this_time() -> bool:
	return OS.is_debug_build() or randf() < ESCAPE_CHANCE


## Muse Pro on your Muse account (signed in from the title screen; see MuseAccount.gd) lets him out too.
static func has_muse_pro() -> bool:
	return MuseAccount.has_pro()


## Is froggy out on the desktop right now?
static func is_out() -> bool:
	var state := ConfigFile.new()
	if state.load(STATE_PATH) != OK:
		return false
	var pid := int(state.get_value("froggy", "pid", 0))
	var heartbeat := float(state.get_value("froggy", "heartbeat", 0.0))
	if pid <= 0 or pid == OS.get_process_id():
		return false
	return Time.get_unix_time_from_system() - heartbeat < STALE_AFTER and OS.is_process_running(pid)


## Starts Lil Froggy. Given the game window, he hops out of it; reveal plays the big version.
static func let_out(from := Rect2i(), reveal := false) -> int:
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	# Godot pulls an off-screen window back into the corner, so a 1 px tall one is as hidden as
	# the boot splash gets before froggy turns the window see-through.
	args.append_array(["--windowed", "--resolution", "1x1", "--position", "-32000,-32000"])
	if OS.get_name() == "Windows":
		# Plain OpenGL loses window transparency on many laptops (he'd sit in a black box);
		# ANGLE draws the same thing through Direct3D 11, which keeps it.
		args.append_array(["--rendering-driver", "opengl3_angle"])
	args.append_array(["--", LAUNCH_FLAG])
	if from.has_area():
		args.append(FROM_PREFIX + "%d,%d,%d,%d" % [from.position.x, from.position.y, from.size.x, from.size.y])
	if reveal:
		args.append(REVEAL_FLAG)
	return OS.create_process(OS.get_executable_path(), args)


## Leaves a note for froggy ("come", or "home" to hop back into the game window at rect).
static func send_command(command: String, rect := Rect2i()) -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var note := ConfigFile.new()
	note.set_value("command", "name", command)
	note.set_value("command", "rect", rect)
	note.save(COMMAND_PATH)


## This game's window, in screen pixels.
static func game_window_rect() -> Rect2i:
	return Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
