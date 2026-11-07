extends SceneTree
## Updates over the air (scripts/Updater.gd), with no network: a copy of the updater whose GitHub is pretend
## (its _fetch answered from files made here), a key made for the test, and little update packs (PCKPacker),
## each with one file in it to read once it's in. Its files go in user://test_ota/, cleared away at the end.
## Also: the updater's set up to load first, the world tells it when it's loaded, the iOS export packs the
## build's details and makes small updates, and the list in the repo is signed with the game's own key.

const DIR := "user://test_ota/"

var _failures := []


class PretendUpdater extends "res://scripts/Updater.gd":
	var files := {}  # (what's on the pretend GitHub: name -> bytes)

	func _fetch(from: String, to_file: String) -> Variant:
		await get_tree().process_frame  # (an answer takes a while, as GitHub's does)
		var name := from.get_file().split("?")[0]
		if not files.has(name):
			return null
		if to_file.is_empty():
			return files[name]
		var f := FileAccess.open(to_file, FileAccess.WRITE)
		f.store_buffer(files[name])
		f.close()
		return PackedByteArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_clear(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	var key := Crypto.new().generate_rsa(2048)
	var stranger := Crypto.new().generate_rsa(2048)
	var pub := key.save_to_string(true)
	var packs := []
	for n in range(1, 4):
		packs.append(_pack(n))

	# Set up: first to load (so an update's in before anything else is), told by the world it's loaded.
	var project := FileAccess.get_file_as_string("res://project.godot")
	var autoloads := project.substr(project.find("[autoload]")).split("\n", false)
	_expect(autoloads.size() > 1 and autoloads[1].begins_with("Updater=\"*res://scripts/Updater.gd\""),
		"the updater loads first of all (%s)" % (autoloads[1] if autoloads.size() > 1 else "-"))
	_expect(FileAccess.get_file_as_string("res://scripts/Main.gd").contains("Updater.started()"),
		"the world tells it once it's loaded")
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	_expect(str(presets.get_value("preset.0", "name")) == "iOS"
		and str(presets.get_value("preset.0", "include_filter")).split(",").has("build_info.cfg")
		and str(presets.get_value("preset.0", "exclude_filter")).split(",").has("tools/*")
		and bool(presets.get_value("preset.0", "patch_delta_encoding")),
		"the iOS export packs the build's details, leaves the tools out, and makes updates of just what's changed")
	_expect(not FileAccess.file_exists("res://build_info.cfg"), "no build's details in the game folder (only ever a build's own)")
	_expect(FileAccess.file_exists("res://ota/.gdignore"), "the update list's folder is no part of the game")
	var real := PretendUpdater.new()
	real.files = {"manifest.json": FileAccess.get_file_as_bytes("res://ota/manifest.json"),
		"manifest.sig": FileAccess.get_file_as_bytes("res://ota/manifest.sig")}
	_expect(real._signed(real.files["manifest.json"], real.files["manifest.sig"]),
		"the update list in the repo is signed with the game's own key")
	real.free()
	var updater: Node = root.get_node_or_null("Updater")
	_expect(updater != null and updater.build == 0 and updater.update == 0,
		"in the editor and the tests: no build, so nothing loaded or looked for")

	# An update for build 33, listed and signed: downloaded, checked, and kept for the next time the game opens.
	var up := _updater(pub)
	up.load_kept()
	_expect(up.update == 0 and _state().get_value("ota", "build", 0) == 33, "at first, the build's own")
	up.files = _published(key, 100, {"33": [1, packs[0]]})
	var outcome: String = await _look(up)
	var state := _state()
	_expect(outcome == "kept" and state.get_value("ota", "file", "") == "33-1.pck"
		and FileAccess.get_sha256(DIR + "state/33-1.pck") == FileAccess.get_sha256(packs[0]) and up.update == 0,
		"a new update downloaded, checked, and kept for next time (%s)" % outcome)
	outcome = await _look(up)
	_expect(outcome == "same", "and not downloaded again (%s)" % outcome)

	# The next time the game opens: it's in, first thing.
	var next := _updater(pub)
	next.load_kept()
	_expect(next.update == 1 and FileAccess.get_file_as_string("res://ota_test_marker_1.txt") == "update 1",
		"the next time the game opens, it's in (update %d)" % next.update)
	_expect(int(_state().get_value("ota", "starts", -1)) == 1, "counted as a start not yet got going")
	next.started()
	_expect(int(_state().get_value("ota", "starts", -1)) == 0, "and once the world's loaded, as working")

	# Not signed with the game's key, or not the file the list names, or an older list: nothing taken.
	up.files = _published(stranger, 200, {"33": [2, packs[1]]})
	outcome = await _look(up)
	_expect(outcome == "failed: not signed" and _state().get_value("ota", "update", 0) == 1,
		"a list not signed with the game's key: refused (%s)" % outcome)
	up.files = _published(key, 300, {"33": [2, packs[1]]})
	var changed: PackedByteArray = up.files["33-2.pck"]
	changed[changed.size() - 1] ^= 0xFF
	up.files["33-2.pck"] = changed
	outcome = await _look(up)
	_expect(outcome == "failed: not the update the list names" and not FileAccess.file_exists(DIR + "state/33-2.pck.part")
		and _state().get_value("ota", "update", 0) == 1, "an update changed on the way: refused, nothing kept (%s)" % outcome)
	up.files = _published(key, 250, {"33": [2, packs[1]]})
	outcome = await _look(up)
	_expect(outcome == "failed: an older list", "an older list, sent again: not gone back to (%s)" % outcome)
	up.files = _published(key, 400, {"34": [1, packs[1]]})
	outcome = await _look(up)
	_expect(outcome == "dropped" and _state().get_value("ota", "file", "") == "",
		"a list with nothing for this build takes its update back (%s)" % outcome)
	var own := _updater(pub)
	own.load_kept()
	_expect(own.update == 0 and DirAccess.get_files_at(DIR + "state").size() == 1,
		"so the next time, the build's own, and the update cleared away (%s)" % [DirAccess.get_files_at(DIR + "state")])

	# One that stops the game as it starts, twice in a row: dropped, and never taken again.
	up.files = _published(key, 500, {"33": [2, packs[1]]})
	outcome = await _look(up)
	_expect(outcome == "kept", "a new update kept (%s)" % outcome)
	for start in 2:
		var stops := _updater(pub)
		stops.load_kept()  # (and no started(): it stopped before the world loaded)
		_expect(stops.update == 2, "start %d: it's in" % (start + 1))
	var after := _updater(pub)
	after.load_kept()
	state = _state()
	_expect(after.update == 0 and state.get_value("ota", "file", "") == "" and 2 in (state.get_value("ota", "bad", []) as Array),
		"stopped the game twice as it started: dropped, the game's own again")
	after.files = up.files
	outcome = await _look(after)
	_expect(outcome == "bad" and not FileAccess.file_exists(DIR + "state/33-2.pck"), "and not taken again (%s)" % outcome)

	# A new build from the store: the last one's update cleared away; its own updates only.
	up.files = _published(key, 600, {"33": [3, packs[2]]})
	outcome = await _look(up)
	_expect(outcome == "kept", "another update kept (%s)" % outcome)
	var newer := _updater(pub, 34)
	newer.load_kept()
	state = _state()
	_expect(newer.update == 0 and state.get_value("ota", "build", 0) == 34 and state.get_value("ota", "file", "") == ""
		and DirAccess.get_files_at(DIR + "state").size() == 1 and int(state.get_value("ota", "serial", 0)) == 600,
		"a new build from the store starts clean (keeping only the list's place)")

	_clear(DIR)
	if _failures.is_empty():
		print("OTA test passed.")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		quit(1)


## A copy of the updater for build `build` (33), keeping its files in the test's folder, the test key's.
func _updater(pub: String, build := 33) -> Node:
	var up := PretendUpdater.new()
	up.dir = DIR + "state/"
	up.public_key = pub
	root.add_child(up)  # (its _ready: no build yet, so it doesn't look by itself)
	up.build = build
	return up


func _look(up: Node) -> String:
	up.check()
	var r = await up.checked
	return str(r)


func _state() -> ConfigFile:
	var state := ConfigFile.new()
	state.load(DIR + "state/state.cfg")
	return state


## A little update pack holding one file, res://ota_test_marker_<n>.txt, saying "update <n>".
func _pack(n: int) -> String:
	var src := DIR + "marker_%d.txt" % n
	var f := FileAccess.open(src, FileAccess.WRITE)
	f.store_string("update %d" % n)
	f.close()
	var path := DIR + "made_%d.pck" % n
	var packer := PCKPacker.new()
	packer.pck_start(path)
	packer.add_file("res://ota_test_marker_%d.txt" % n, src)
	packer.flush()
	return path


## What the pretend GitHub has: a list (serial, and for each build [its update's number, its pack]) signed
## with `key`, and the packs.
func _published(key: CryptoKey, serial: int, builds: Dictionary) -> Dictionary:
	var files := {}
	var listed := {}
	for b in builds:
		var n: int = builds[b][0]
		var pack: String = builds[b][1]
		var name := "%s-%d.pck" % [b, n]
		files[name] = FileAccess.get_file_as_bytes(pack)
		listed[b] = {"update": n, "file": name, "size": files[name].size(), "sha256": FileAccess.get_sha256(pack)}
	var list := (JSON.stringify({"serial": serial, "builds": listed}, "  ", true) + "\n").to_utf8_buffer()
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(list)
	files["manifest.json"] = list
	files["manifest.sig"] = Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, hashing.finish(), key)).to_utf8_buffer()
	return files


func _clear(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		_clear(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
