extends Control
## A thumb stick for walking in 3D places. Push the knob away from the middle: how far is how fast. It takes its own
## finger (multi-touch), so your other thumb can look around and point the light at the same time.

signal moved(v: Vector2)   ## x: right, y: down (push up = walk forward), each -1..1

const R := 70.0            ## how far the knob can go from the middle
var _finger := -2          ## the touch holding the knob (-1 = the mouse, on a computer)
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # we listen in _input, before the picture under us does
	custom_minimum_size = Vector2(R * 2 + 40, R * 2 + 40); size = custom_minimum_size


func _center() -> Vector2: return global_position + size / 2


func _input(e: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if e is InputEventScreenTouch:
		if e.pressed and _finger == -2 and e.position.distance_to(_center()) < R + 30: _finger = e.index; _put(e.position); accept()
		elif not e.pressed and e.index == _finger: _finger = -2; _put(_center()); accept()
	elif e is InputEventScreenDrag and e.index == _finger:
		_put(e.position); accept()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:   # a computer, or the phone's copy of the first touch
		if e.pressed and e.position.distance_to(_center()) < R + 30:
			if _finger == -2: _finger = -1; _put(e.position)
			accept()
		elif not e.pressed and _finger == -1: _finger = -2; _put(_center()); accept()
		elif not e.pressed and _finger == 0: accept()
	elif e is InputEventMouseMotion and (_finger == -1 or _finger == 0):
		if _finger == -1: _put(e.position)
		accept()


func accept() -> void: get_viewport().set_input_as_handled()


func _put(p: Vector2) -> void:
	_knob = (p - _center()).limit_length(R)
	moved.emit(_knob / R); queue_redraw()


func _draw() -> void:
	var c := size / 2
	draw_circle(c, R + 6, Color(0, 0, 0, 0.28))
	draw_arc(c, R + 6, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	draw_circle(c + _knob, 30, Color(1, 1, 1, 0.5 if _finger != -2 else 0.32))
	draw_arc(c + _knob, 30, 0, TAU, 32, Color(1, 1, 1, 0.75), 2.0, true)
