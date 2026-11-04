extends RefCounted
## The aim line, story and Endless alike: a row of little square dots out along the jump he'll make
## (it was a pink line, too like his tongue). Further and more of them the stronger the pull, cream
## turning gold as it strengthens, faint by him and bright at the far end, each with a dark edge so it
## shows on any background; on a spring, gold all along.

const STEP := 7.0  # (between dots, in his own pixels)
const SOFT := Color(1.0, 0.97, 0.86)
const STRONG := Color(1.0, 0.8, 0.28)
const SPRING := Color(1.0, 0.86, 0.3)
const EDGE := Color(0.12, 0.08, 0.06)


static func draw(canvas: CanvasItem, end: Vector2, power: float, spring := false) -> void:
	var length := end.length()
	if length < STEP:
		return
	var dir := end / length
	var n := int(length / STEP)
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var at := (dir * (i * STEP)).round()
		var side := 2.0 + roundf(t)  # (2 pixels by him, 3 at the far end)
		var colour: Color = SPRING if spring else SOFT.lerp(STRONG, clampf(power, 0.0, 1.0))
		colour.a = lerpf(0.55, 1.0, t)
		var edge := EDGE
		edge.a = colour.a * 0.85
		canvas.draw_rect(Rect2(at - Vector2.ONE * (side * 0.5 + 1.0), Vector2.ONE * (side + 2.0)), edge)
		canvas.draw_rect(Rect2(at - Vector2.ONE * side * 0.5, Vector2.ONE * side), colour)
