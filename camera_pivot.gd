extends Node3D

@export var mouse_sensitivity: float = 0.0025
@export var touch_sensitivity: float = 0.0040
@export var min_pitch: float = -35.0
@export var max_pitch: float = 25.0

var pitch: float = 0.0
var camera_touch_ids: Dictionary = {}

func _ready() -> void:
	pitch = rotation.x
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	# Use most of the right side for camera look. The previous narrow zone
	# made camera movement unreliable on different phone aspect ratios.
	if event is InputEventScreenTouch:
		if event.pressed:
			var view_size := get_viewport().get_visible_rect().size
			var p: Vector2 = event.position
			var in_look_area := (
				p.x >= view_size.x * 0.38
				and p.y >= view_size.y * 0.08
				and p.y <= view_size.y * 0.88
			)
			if in_look_area:
				camera_touch_ids[event.index] = true
		else:
			camera_touch_ids.erase(event.index)
	elif event is InputEventScreenDrag and camera_touch_ids.has(event.index):
		_rotate_camera(event.relative * touch_sensitivity)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative * mouse_sensitivity)

func _rotate_camera(delta_rotation: Vector2) -> void:
	rotate_y(-delta_rotation.x)
	pitch -= delta_rotation.y
	pitch = clamp(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	rotation.x = pitch
