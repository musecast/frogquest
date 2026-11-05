extends Polygon2D

@export var speed: float = 0.2

func _process(delta: float) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0 * speed
	var t = (sin(time) + 1.0) / 2.0
	color = Color("ff6bacff").lerp(Color("#ff205e"), t)
