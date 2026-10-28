
extends Control

@onready var base: ColorRect = $JoystickBase
@onready var knob: ColorRect = $JoystickKnob

var dragging := false
var input_vector := Vector2.ZERO
var radius := 60.0

func _ready() -> void:
	var view_size := get_viewport_rect().size
	radius = 66.0
	base.size = Vector2(176, 176)
	base.position = Vector2(34.0, view_size.y - 208.0)
	base.color = Color(0.08, 0.11, 0.10, 0.58)
	knob.size = Vector2(68, 68)
	knob.color = Color(0.58, 0.68, 0.50, 0.78)
	knob.position = base.position + (base.size - knob.size) / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and base.get_global_rect().has_point(event.position):
			dragging = true
			_update_knob(event.position)
		elif not event.pressed:
			dragging = false
			input_vector = Vector2.ZERO
			knob.position = base.position + (base.size - knob.size) / 2.0

	elif event is InputEventScreenDrag and dragging:
		_update_knob(event.position)

func _update_knob(screen_pos: Vector2) -> void:
	var center := base.global_position + base.size / 2.0
	var offset := screen_pos - center

	if offset.length() > radius:
		offset = offset.normalized() * radius

	input_vector = offset / radius
	knob.position = base.position + base.size / 2.0 + offset - knob.size / 2.0


func get_input_vector() -> Vector2:
	return input_vector
