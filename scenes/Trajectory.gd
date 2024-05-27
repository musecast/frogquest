extends Node2D

var mouseOrigin
var mousePosition
var mousePath


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	if Input.is_action_just_pressed("ui_mouse"):
		mouseOrigin = get_global_mouse_position()
		
	if Input.is_action_pressed("ui_mouse"):
		mousePosition = get_global_mouse_position()
		mousePath = mouseOrigin - mousePosition
		queue_redraw()
		
	if Input.is_action_just_released("ui_mouse"):
		get_parent().velocity = mousePath * 3
		print(mousePath)
		mouseOrigin = (0)
		mousePosition = (0)
		queue_redraw()
	pass


func _draw():
		if Input.is_action_pressed("ui_mouse"):
			draw_line(Vector2(0,0), mousePath/3, Color.DEEP_PINK, 2.0)
