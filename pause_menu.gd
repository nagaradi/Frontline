extends Control
## Lightweight pause overlay for keyboard and touch. This UI keeps working while the game tree is paused.

var overlay: ColorRect
var panel: PanelContainer
var pause_button: Button
var resume_button: Button
var restart_button: Button
var paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_pause_button()
	_build_overlay()
	get_viewport().size_changed.connect(_layout_pause_button)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _build_pause_button() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pause game"
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.custom_minimum_size = Vector2(54, 48)
	pause_button.add_theme_font_size_override("font_size", 24)
	pause_button.pressed.connect(_toggle_pause)
	add_child(pause_button)
	_layout_pause_button()
	_style_button(pause_button, Color(0.055, 0.075, 0.085, 0.9))

func _layout_pause_button() -> void:
	if not is_instance_valid(pause_button):
		return
	var size := get_viewport_rect().size
	pause_button.position = Vector2(size.x - 72.0, 178.0)
	pause_button.size = Vector2(54.0, 48.0)

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = Color(0.015, 0.025, 0.035, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	panel = PanelContainer.new()
	panel.name = "PausePanel"
	panel.custom_minimum_size = Vector2(320, 250)
	panel.size = Vector2(320, 250)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -125)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)

	resume_button = Button.new()
	resume_button.text = "RESUME"
	resume_button.custom_minimum_size = Vector2(250, 54)
	resume_button.focus_mode = Control.FOCUS_NONE
	resume_button.pressed.connect(_resume)
	column.add_child(resume_button)
	_style_button(resume_button, Color(0.12, 0.32, 0.19, 1.0))

	restart_button = Button.new()
	restart_button.text = "RESTART MATCH"
	restart_button.custom_minimum_size = Vector2(250, 54)
	restart_button.focus_mode = Control.FOCUS_NONE
	restart_button.pressed.connect(_restart)
	column.add_child(restart_button)
	_style_button(restart_button, Color(0.28, 0.18, 0.10, 1.0))

func _style_button(button: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.72, 0.80, 0.72, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.18)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_font_size_override("font_size", 20)

func _toggle_pause() -> void:
	if paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	paused = true
	overlay.visible = true
	pause_button.text = "▶"
	pause_button.tooltip_text = "Resume game"
	get_tree().paused = true
	resume_button.grab_focus()

func _resume() -> void:
	paused = false
	get_tree().paused = false
	overlay.visible = false
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pause game"

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
