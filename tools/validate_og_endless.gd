extends SceneTree
## Headless check of OG Endless (scenes/og: the original Endless, as it was, for the secret way in: hold
## ENDLESS on the title): it loads and builds its tower (the checkerboard behind it, the pink platforms) with
## today's Froggy; he lands on its first platform and can climb; its best score is its own (never the new
## Endless's); and the title's ENDLESS, held, takes you there. Scratch saves only; yours are byte-checked.
##   Godot --headless --path . --script res://tools/validate_og_endless.gd


class ErrorCounter extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])


const SCORES := "user://test_og_endless_highscore.dat"

var _counter := ErrorCounter.new()
var _failures: Array[String] = []


func _initialize() -> void:
	OS.add_logger(_counter)
	_run.call_deferred()


func _run() -> void:
	var real_new := FileAccess.get_file_as_bytes("user://endless_highscore.dat")
	var og: Node2D = (load("res://scenes/og/OGEndlessMode.tscn") as PackedScene).instantiate()
	_expect(og.SAVE_PATH != "user://endless_highscore.dat", "OG Endless keeps its own best score")
	og.save_path = SCORES
	root.add_child(og)
	for _i in 60:
		await process_frame
	var background: ColorRect = og.get_node_or_null("Background")
	_expect(background != null and background.material is ShaderMaterial and str(background.material.shader.resource_path).ends_with("og/CHECKERBOARD.gdshader"),
		"the original checkerboard behind it")
	_expect(og.platforms.get_child_count() >= 15, "its tower built (%d platforms)" % og.platforms.get_child_count())
	var player: CharacterBody2D = og.player
	_expect(player != null and player.is_on_floor(), "Froggy (today's) standing on its first platform")
	# Up onto the next one, as a jump would land him.
	var next: Node2D = null
	for p in og.platforms.get_children():
		if int(p.get_meta("platform_id", -1)) == 2:  # (the next one up: its first, the one he starts on, is 1)
			next = p
	if next:
		player.global_position = next.global_position + Vector2(0.0, -30.0)
		player.velocity = Vector2.ZERO
		player.reset_physics_interpolation()
		for _i in 30:  # (down onto it, and his landing told: a frame after he's down)
			await physics_frame
	_expect(og.score >= 1, "landing on the next one scores (%d)" % og.score)
	og.queue_free()
	await process_frame
	_expect(FileAccess.get_file_as_bytes("user://endless_highscore.dat") == real_new, "the new Endless's best untouched")
	# The secret: the title's ENDLESS, held.
	var hero: GDScript = load("res://scripts/player.gd")
	var methods: Array = hero.get_script_method_list().map(func(m: Dictionary) -> String: return str(m.name))
	_expect(hero.OG_HOLD >= 1.5 and methods.has("_hold_for_og_endless"), "hold ENDLESS on the title (%.1f s) for it" % hero.OG_HOLD)
	if FileAccess.file_exists(SCORES):
		DirAccess.remove_absolute(SCORES)
	for err in _counter.errors:
		_failures.append("script error: " + err)
	if _failures.is_empty():
		print("OG Endless test passed.")
	else:
		for f in _failures:
			push_warning("FAIL: " + f)
		print("OG Endless test failed (%d)." % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
		push_warning("FAIL: " + what)
