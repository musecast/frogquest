extends Node
## Updates over the air: changes to the game (its scripts, scenes, art, sounds) reaching phones without a new
## build. A store build knows its number (res://build_info.cfg, written by the TestFlight workflow). An update
## made for it is a patch pack holding only what's changed since that build (tools/ota/publish_update.ps1),
## named, with its size and hash, in a list signed with the key whose public half is below (ota/manifest.json
## and manifest.sig, on GitHub).
## - A few seconds after the game opens it looks at the list, quietly. An update for this build it hasn't got
##   is downloaded, checked (the list's signature, the update's size and hash), and kept for the next time the
##   game opens.
## - Then it's loaded first thing, before anything else is (this is the first autoload), so the rest of the
##   game comes from it.
## - Safe: nothing unsigned is taken, nor anything made for another build. If the game stops BAD_AFTER times
##   in a row before the world's loaded with an update in, that update's dropped, never taken again, and the
##   game's back to its own. One the list stops naming is dropped too (the way to take one back). A new build
##   from the store starts clean.
## - What an update can't change: this script (it's loaded before any update is), the engine, the plugins
##   (Game Center, ads, purchases), the app's icon, name and settings (project.godot), its privacy manifest.
## In the editor and the tests there's no build number, so it does nothing. (Or, for a test of the real thing,
## the command line says where: --ota-dir <folder> --ota-url <url>.)

signal checked(outcome: String)  ## (a look at the list done: "none", "same", "kept", "dropped", "bad", or "failed: why")

const LIST_URL := "https://raw.githubusercontent.com/musecast/frogquest/main/ota/"
const PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAm9uYeeje6tkV2S9tQKgb
XWWEi0UcsElmkDlEkiqbc2MsafN2vft8fdvy8n2rnOg9AUTWtNXxPz+vkKCVYxD+
7V0NFidwD4dGsAkisrH6/43va3tnM7JIHVDUwI0kEodT9l8+jImDc057Avuza2AP
NfeRLecJK69/bYKdNNpXdPb8qMqF0Gn+7pAUT4xDbrjRC7Hml0HkVYcIBqZVlzo+
uI8uweX0rwX19Pxj7yIuzvqzUOngexuiBbaxZg17w1Cwi6nsA38iqviYa1aMWKKY
qcVs8iXrcKbvbW32jm5L+s/bi8j0oSbIAisWkyzmMGrjYQFX4kijQonqEqV44lK/
nQIDAQAB
-----END PUBLIC KEY-----
"""
const CHECK_AFTER := 4.0  # (seconds after the game opens before it looks: clear of the loading)
const BAD_AFTER := 2  # (starts in a row that stop before the world's loaded, an update in, before it's dropped)
const STATE := "state.cfg"

var build := 0  ## this build's number (0: not a store build: the editor, the tests)
var version := ""  ## its version, as the App Store shows it (1.1)
var update := 0  ## the update the game's running now (0: none, the build's own)
var dir := "user://ota/"  ## (where updates are kept, and what's known about them)
var url := LIST_URL  ## (where the list and the updates are)
var public_key := PUBLIC_KEY
var _checking := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--ota-dir")
	if at >= 0 and at + 1 < args.size():
		dir = args[at + 1].trim_suffix("/") + "/"
	at = args.find("--ota-url")
	if at >= 0 and at + 1 < args.size():
		url = args[at + 1].trim_suffix("/") + "/"
	var info := ConfigFile.new()
	if FileAccess.file_exists("res://build_info.cfg") and info.load("res://build_info.cfg") == OK:
		build = int(info.get_value("build", "number", 0))
		version = str(info.get_value("build", "version", ""))
	if build > 0:
		load_kept()


func _ready() -> void:
	if build <= 0:
		return
	await get_tree().create_timer(CHECK_AFTER).timeout
	check()


## The update kept for this build, loaded (at the start: before anything's loaded from the game itself). Not if
## it's stopped the game BAD_AFTER times in a row before the world loaded: then it's dropped for good.
func load_kept() -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var state := _state()
	if int(state.get_value("ota", "build", 0)) != build:
		_start_clean(state)  # (a new build from the store: the last one's updates are no good to it)
		return
	_tidy(state)
	var file := str(state.get_value("ota", "file", ""))
	if file.is_empty():
		return
	var n := int(state.get_value("ota", "update", 0))
	var starts := int(state.get_value("ota", "starts", 0))
	var path := dir + file
	if starts >= BAD_AFTER:
		var bad: Array = state.get_value("ota", "bad", [])
		bad.append(n)
		state.set_value("ota", "bad", bad)
		_forget(state)
		DirAccess.remove_absolute(path)  # (not loaded: cleared away now)
		push_warning("Update %d stopped the game %d times as it started: dropped, the game's own again." % [n, starts])
		return
	if FileAccess.get_sha256(path) != str(state.get_value("ota", "sha256", "")):
		_forget(state)  # (gone, or not the file it was: it'll come again)
		DirAccess.remove_absolute(path)
		return
	state.set_value("ota", "starts", starts + 1)
	_save(state)
	if ProjectSettings.load_resource_pack(path, true):
		update = n
		print("Updater: build %d, update %d in" % [build, n])
	else:
		_forget(state)


## The world's loaded (the end of Main._ready): the update in got the game going, so it counts as working.
func started() -> void:
	if update <= 0:
		return
	var state := _state()
	if int(state.get_value("ota", "starts", 0)) != 0:
		state.set_value("ota", "starts", 0)
		_save(state)


## Looks for an update for this build, once at a time. A new one's downloaded, checked, and kept for the next
## time the game opens. Ends with `checked`.
func check() -> void:
	if _checking or build <= 0:
		return
	_checking = true
	var outcome: String = await _check()
	_checking = false
	print("Updater: looked for an update (", outcome, ")")
	checked.emit(outcome)


func _check() -> String:
	var t := int(Time.get_unix_time_from_system())
	var list = await _fetch(url + "manifest.json?t=%d" % t, "")
	var sig = await _fetch(url + "manifest.sig?t=%d" % t, "")
	if not list is PackedByteArray or not sig is PackedByteArray:
		return "failed: no list"
	if not _signed(list, sig):
		return "failed: not signed"
	var data = JSON.parse_string((list as PackedByteArray).get_string_from_utf8())
	if not data is Dictionary or not data.get("builds") is Dictionary:
		return "failed: unreadable list"
	var state := _state()
	var serial := int(data.get("serial", 0))
	if serial < int(state.get_value("ota", "serial", 0)):
		return "failed: an older list"  # (one from before, sent again: not gone back to)
	state.set_value("ota", "serial", serial)
	_save(state)  # (the newest list seen, kept: one older is never gone back to)
	var entry = data.builds.get(str(build))
	var kept := str(state.get_value("ota", "file", ""))
	if not entry is Dictionary or int(entry.get("update", 0)) <= 0:
		if kept.is_empty():
			return "none"
		_forget(state)  # (taken back: the game's own again, from the next time it opens)
		return "dropped"
	var n := int(entry.update)
	if n == int(state.get_value("ota", "update", 0)) and not kept.is_empty():
		return "same"
	if n in (state.get_value("ota", "bad", []) as Array):
		return "bad"
	var file := "%d-%d.pck" % [build, n]
	var part := dir + file + ".part"
	var got = await _fetch(url + str(entry.get("file", "")), part)
	var size := -1
	var f := FileAccess.open(part, FileAccess.READ)
	if f:
		size = f.get_length()
		f.close()
	if not got is PackedByteArray or size != int(entry.get("size", -2)) \
			or FileAccess.get_sha256(part) != str(entry.get("sha256", "")):
		DirAccess.remove_absolute(part)
		return "failed: not the update the list names"
	if FileAccess.file_exists(dir + file):
		DirAccess.remove_absolute(dir + file)
	if DirAccess.rename_absolute(part, dir + file) != OK:
		DirAccess.remove_absolute(part)
		return "failed: couldn't keep it"
	state.set_value("ota", "file", file)
	state.set_value("ota", "update", n)
	state.set_value("ota", "sha256", str(entry.sha256))
	state.set_value("ota", "starts", 0)
	_save(state)
	return "kept"


## A file from `from`: its bytes, or saved to `to_file` (then empty bytes); null if it couldn't be had.
func _fetch(from: String, to_file: String) -> Variant:
	var http := HTTPRequest.new()
	http.timeout = 30.0
	http.download_file = to_file
	add_child(http)
	if http.request(from) != OK:
		http.queue_free()
		return null
	var r: Array = await http.request_completed
	http.queue_free()
	if int(r[0]) != HTTPRequest.RESULT_SUCCESS or int(r[1]) != 200:
		return null
	return r[3]


## Whether the list's signature is the key's (its public half: public_key) on just these bytes.
func _signed(list: PackedByteArray, sig: PackedByteArray) -> bool:
	var key := CryptoKey.new()
	if key.load_from_string(public_key, true) != OK:
		return false
	var raw := Marshalls.base64_to_raw(sig.get_string_from_utf8().strip_edges())
	if raw.size() != 256:  # (a 2048-bit key's)
		return false
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(list)
	return Crypto.new().verify(HashingContext.HASH_SHA256, hashing.finish(), raw, key)


func _state() -> ConfigFile:
	var state := ConfigFile.new()
	state.load(dir + STATE)
	return state


func _save(state: ConfigFile) -> void:
	state.save(dir + STATE)


## No update from the next time the game opens (the file's cleared away then: it may be in use now).
func _forget(state: ConfigFile) -> void:
	for k in ["file", "update", "sha256", "starts"]:
		if state.has_section_key("ota", k):
			state.erase_section_key("ota", k)
	_save(state)


## A new build: nothing kept from the last one's updates but the list's place (so an old list isn't gone back to).
func _start_clean(state: ConfigFile) -> void:
	var serial := int(state.get_value("ota", "serial", 0))
	var fresh := ConfigFile.new()
	fresh.set_value("ota", "build", build)
	fresh.set_value("ota", "serial", serial)
	_save(fresh)
	_tidy(fresh)


## Clears away every file but what's known (the state) and the update kept (before it's loaded).
func _tidy(state: ConfigFile) -> void:
	var keep := str(state.get_value("ota", "file", ""))
	for name in DirAccess.get_files_at(dir):
		if name != STATE and name != keep:
			DirAccess.remove_absolute(dir + name)
