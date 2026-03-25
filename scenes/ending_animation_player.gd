extends AnimationPlayer

signal last_keyframe_reached

const BLEND_DURATION: float = 3.2

@export_range(0.3, 0.8, 0.01) var landscape_zoom: float = 0.50
@export var portrait_y_offset: float = 0.0   # extra Y on position track in portrait (negative = higher)
@export var landscape_y_offset: float = 0.0  # extra Y on position track in landscape

var _zoom_correction: float = 1.0
var _y_offset: float = 0.0
var _camera: Camera2D = null
var _zoom_start: float = 0.55
var _zoom_anim_start: float = 0.55
var _elapsed: float = 0.0
var _last_keyframe_time: float = 0.0
var _keyframe_triggered: bool = false
var _final_zoom: float = 0.55
var _final_pos: Vector2 = Vector2.ZERO
var _done: bool = false


func _ready() -> void:
	process_priority = 10
	_camera = get_parent() as Camera2D
	animation_started.connect(_on_animation_started)
	animation_finished.connect(_on_animation_finished)


func _on_animation_started(anim_name: String) -> void:
	if anim_name != "end":
		_zoom_correction = 1.0
		_y_offset = 0.0
		return

	var anim_res: Animation = get_animation("end")
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_NONE

	_zoom_start = _camera.zoom.x if _camera else 0.55
	_elapsed = 0.0
	_keyframe_triggered = false
	_final_zoom = _zoom_start
	_final_pos = _camera.position if _camera else Vector2.ZERO

	var vp := get_viewport().get_visible_rect().size
	var ratio: float = vp.y / vp.x
	var t: float = inverse_lerp(0.65, 1.3, clamp(ratio, 0.65, 1.3))
	_zoom_correction = lerp(landscape_zoom, 0.75, t) / 0.55
	_y_offset = lerp(landscape_y_offset, portrait_y_offset, t)

	_zoom_anim_start = _zoom_start
	var anim: Animation = get_animation("end")
	if anim:
		_last_keyframe_time = 0.0
		for i in anim.get_track_count():
			var kcount := anim.track_get_key_count(i)
			if kcount > 0:
				_last_keyframe_time = max(_last_keyframe_time, anim.track_get_key_time(i, kcount - 1))
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_VALUE \
					and str(anim.track_get_path(i)).contains("zoom"):
				var v = anim.value_track_interpolate(i, 0.0)
				if v is Vector2:
					_zoom_anim_start = v.x * _zoom_correction
				break


func release_zoom_lock() -> void:
	_keyframe_triggered = false
	_done = true


func _on_animation_finished(anim_name: String) -> void:
	if anim_name != "end":
		_zoom_correction = 1.0
		_y_offset = 0.0


func _process(delta: float) -> void:
	if _camera == null or _done:
		return
	# Keep enforcing the last corrected zoom and position so the paused
	# animation can't overwrite them with raw uncorrected values every frame.
	if _keyframe_triggered:
		_camera.zoom = Vector2(_final_zoom, _final_zoom)
		_camera.position = _final_pos
		return
	if not is_playing() or current_animation != "end":
		return

	_elapsed += delta

	var anim: Animation = get_animation("end")

	# ── ZOOM correction ───────────────────────────────────────────────────
	# Use -1 as sentinel: if the zoom track can't be read we skip updating
	# rather than falling back to _camera.zoom.x, which would cause the zoom
	# to accumulate each frame (runaway zoom-in glitch on the win screen).
	var corrected_zoom: float = -1.0
	if anim:
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_VALUE \
					and str(anim.track_get_path(i)).contains("zoom"):
				var base_zoom = anim.value_track_interpolate(i, current_animation_position)
				if base_zoom is Vector2:
					corrected_zoom = base_zoom.x * _zoom_correction
				break

	if corrected_zoom < 0.0:
		return  # zoom track unreadable this frame — leave zoom as-is

	var blend_t: float = clamp(_elapsed / BLEND_DURATION, 0.0, 1.0)
	blend_t = blend_t * blend_t * (3.0 - 2.0 * blend_t)
	_camera.zoom = Vector2(corrected_zoom + lerp(_zoom_start - _zoom_anim_start, 0.0, blend_t),
			corrected_zoom + lerp(_zoom_start - _zoom_anim_start, 0.0, blend_t))

	# ── POSITION Y correction ─────────────────────────────────────────────
	if anim and _y_offset != 0.0:
		for i in anim.get_track_count():
			if anim.track_get_type(i) == Animation.TYPE_VALUE \
					and str(anim.track_get_path(i)).contains("position"):
				var base_pos = anim.value_track_interpolate(i, current_animation_position)
				if base_pos is Vector2:
					_camera.position = Vector2(base_pos.x, base_pos.y + _y_offset)
				break

	if current_animation_position >= _last_keyframe_time:
		_final_zoom = corrected_zoom + lerp(_zoom_start - _zoom_anim_start, 0.0, blend_t)
		_final_pos = _camera.position
		_keyframe_triggered = true
		last_keyframe_reached.emit()
