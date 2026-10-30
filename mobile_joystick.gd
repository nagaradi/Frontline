extends Control

@onready var base: ColorRect = $JoystickBase
@onready var knob: ColorRect = $JoystickKnob

var dragging := false
var drag_touch_id := -1
var input_vector := Vector2.ZERO
var radius := 66.0

func _ready() -> void:
	# Keep the joystick sized and placed relative to the actual mobile viewport.
	var view_size := get_viewport_rect().size
	base.size = Vector2(176, 176)
	base.position = Vector2(24.0, maxf(24.0, view_size.y - 200.0))
	base.color = Color(0.08, 0.11, 0.10, 0.58)
	knob.size = Vector2(68, 68)
	knob.color = Color(0.58, 0.68, 0.50, 0.82)
	knob.position = base.position + (base.size - knob.size) / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not dragging and base.get_global_rect().has_point(event.position):
				dragging = true
				drag_touch_id = event.index
				_update_knob(event.position)
		elif dragging and event.index == drag_touch_id:
			_reset_joystick()
	elif event is InputEventScreenDrag and dragging and event.index == drag_touch_id:
		_update_knob(event.position)

func _reset_joystick() -> void:
	dragging = false
	drag_touch_id = -1
	input_vector = Vector2.ZERO
	knob.position = base.position + (base.size - knob.size) / 2.0

func _update_knob(screen_pos: Vector2) -> void:
	var center := base.global_position + base.size / 2.0
	var offset := screen_pos - center
	if offset.length() > radius:
		offset = offset.normalized() * radius
	input_vector = offset / radius
	knob.position = base.position + base.size / 2.0 + offset - knob.size / 2.0

func get_input_vector() -> Vector2:
	return input_vector
