@tool
extends AudioStreamPlayer2D

func _draw():
	if not Engine.is_editor_hint(): return
	var polys = 32 #detail of cricles
	var cricles = 4 #amout of cricles
	for i in range(cricles):
		var r = pow(float(i + 1) / cricles, attenuation)
		var vec = Vector2(max_distance * r, 0)
		for j in range(polys):
			var ang1 = 2 * PI / polys * (j)
			var ang2 = 2 * PI / polys * (j + 1)
			draw_line(vec.rotated(ang1), vec.rotated(ang2), lerp(Color.AZURE, Color.BLACK, r), 1.0, true)

func _process(_delta):
	if Engine.is_editor_hint():
		queue_redraw()
