extends SceneTree
## Puts an update for a store build in the update list, or takes one out, and signs the list (the update key
## is kept on this PC, outside the repo). Run by tools/ota/publish_update.ps1, which makes the update:
##   Godot --headless --path <game> --script res://tools/ota/make_update.gd -- <build> <patch.pck | take-back> <key.pem> [<list folder>]
## The list is ota/manifest.json: {"serial": n, "builds": {"33": {"update": 2, "file": "33-2.pck", "size": ...,
## "sha256": ..., "made": ...}}}. Each new update for a build is numbered one on from the last, and replaces it (an
## update holds everything changed since the build, so only the newest is needed). The serial only goes up, so an
## old list sent again isn't gone back to. ota/manifest.sig is the key's RSA signature on the list's SHA-256,
## base64: what scripts/Updater.gd checks, with the key's public half (checked here too, before it's done).

const OTA := "res://ota/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3 or args.size() > 4 or int(args[0]) <= 0:
		printerr("usage: -- <build> <patch.pck | take-back> <key.pem> [<list folder>]")
		quit(2)
		return
	var build := int(args[0])
	var dir := ProjectSettings.globalize_path(OTA) if args.size() == 3 else args[3].trim_suffix("/") + "/"  # (another: a test's)
	var data := {"serial": 0, "builds": {}}
	if FileAccess.file_exists(dir + "manifest.json"):
		var was = JSON.parse_string(FileAccess.get_file_as_string(dir + "manifest.json"))
		if was is Dictionary and was.get("builds") is Dictionary:
			data = was
	var builds: Dictionary = data.builds
	var last: Dictionary = builds.get(str(build), {})
	for f in DirAccess.get_files_at(dir):  # (the build's last update: replaced, or taken back)
		if f.begins_with("%d-" % build) and f.ends_with(".pck"):
			DirAccess.remove_absolute(dir + f)
	if args[1] == "take-back":
		builds.erase(str(build))
		print("Build %d: no update (its own again)" % build)
	else:
		var n := int(last.get("update", 0)) + 1
		var file := "%d-%d.pck" % [build, n]
		var err := DirAccess.copy_absolute(args[1], dir + file)
		if err != OK:
			printerr("couldn't copy the update: ", error_string(err))
			quit(1)
			return
		var size := FileAccess.open(dir + file, FileAccess.READ).get_length()
		builds[str(build)] = {"update": n, "file": file, "size": size, "sha256": FileAccess.get_sha256(dir + file),
			"made": Time.get_datetime_string_from_system(true) + "Z"}
		print("Build %d: update %d (%s, %d bytes)" % [build, n, file, size])
	data.serial = maxi(int(data.get("serial", 0)) + 1, int(Time.get_unix_time_from_system()))
	var text := JSON.stringify(data, "  ", true) + "\n"
	var out := FileAccess.open(dir + "manifest.json", FileAccess.WRITE)
	out.store_string(text)
	out.close()

	var key := CryptoKey.new()
	if key.load(args[2]) != OK:
		printerr("couldn't load the update key: ", args[2])
		quit(1)
		return
	var list := FileAccess.get_file_as_bytes(dir + "manifest.json")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(list)
	var digest := hashing.finish()
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256, digest, key)
	out = FileAccess.open(dir + "manifest.sig", FileAccess.WRITE)
	out.store_string(Marshalls.raw_to_base64(sig) + "\n")
	out.close()
	# (checked with the public half the game has, as the game will)
	var game_key := CryptoKey.new()
	game_key.load_from_string(load("res://scripts/Updater.gd").PUBLIC_KEY, true)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, digest, sig, game_key):
		printerr("The signature doesn't match the game's key (scripts/Updater.gd PUBLIC_KEY)")
		quit(1)
		return
	print("List signed (serial %d)" % data.serial)
	quit(0)
