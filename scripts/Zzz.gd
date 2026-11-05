extends Node2D
## Asleep: little z's drifting up off him one after another (each a little bigger than the last, then
## small again), swaying as they rise, fading as they go, and his little breath with every third (a croaky
## snore in, a tiny whistle out). stop(): no more, the last ones fade quickly, and it's gone. Drawn over
## the beanbag he's sunk in. Its own, not his: it follows the top of his head (anchor, in his own space)
## but takes nothing else of him, so the z's stay their shape and drawn at whole-pixel sizes, crisp.

const EVERY := 1.35  # (seconds between them)
const RISE := Vector2(19.0, -48.0)  # (how far each drifts, in the world's pixels)
const LIFE := 3.4  # (slow: drifting up, sleepily)
const BREATH_DB := -20.0  # (his breath, every third z: its file's at -15 LUFS, so about -35 here: little, soft)

var anchor := Vector2.ZERO  # (where it is on him: just over the top of his head)
var _left := 0.25
var _n := 0
var _on := true
var _breath: AudioStreamPlayer
var breaths := 0  # (how many he's taken)


func _ready() -> void:
	z_index = 25
	z_as_relative = false
	top_level = true
	_follow()
	_breath = AudioStreamPlayer.new()  # (a little snore in, a tiny whistle out: assets/sleep_breath.wav)
	_breath.stream = load("res://assets/sleep_breath.wav")
	_breath.bus = &"FX"
	_breath.volume_db = BREATH_DB
	add_child(_breath)


func _follow() -> void:
	var him := get_parent() as Node2D
	if him:
		global_position = him.to_global(anchor).round()


func _process(delta: float) -> void:
	_follow()
	if not _on:
		return
	_left -= delta
	if _left <= 0.0:
		_left = EVERY
		_puff()


func _puff() -> void:
	var z := Label.new()
	z.text = "z"
	load("res://scripts/UIStyle.gd").style_label(z, 16, Color(0.96, 0.97, 1.0))
	z.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _n % 3 == 0:  # (a breath in and out with every third z: about every four seconds, as a sleeper's are)
		_breath.pitch_scale = randf_range(0.94, 1.05)
		_breath.volume_db = BREATH_DB
		_breath.play()
		breaths += 1
	var size: float = [2.0, 2.0, 3.0][_n % 3]  # (whole pixels: crisp)
	_n += 1
	z.pivot_offset = z.get_minimum_size() * 0.5
	z.scale = Vector2(size, size)
	z.modulate.a = 0.0
	add_child(z)
	var start := (Vector2(0.0, -4.0) - z.pivot_offset).round()  # (from just over his head)
	z.position = start
	var go := z.create_tween().set_parallel(true)
	go.tween_property(z, "position", start + RISE, LIFE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	go.tween_property(z, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	go.tween_property(z, "modulate:a", 0.0, LIFE * 0.45).set_delay(LIFE * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	go.chain().tween_callback(z.queue_free)


## No more z's: the ones drifting fade out quickly, then this goes.
func stop() -> void:
	_on = false
	if _breath.playing:  # (his breath fades as he wakes, not cut off)
		_breath.create_tween().tween_property(_breath, "volume_db", -60.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for z in get_children():
		if z is CanvasItem:
			z.create_tween().tween_property(z, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bye := create_tween()
	bye.tween_interval(0.3)
	bye.tween_callback(queue_free)
