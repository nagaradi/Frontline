extends Control
## Frontline start menu, pause menu, and mobile graphics settings.

var overlay: ColorRect
var panel: PanelContainer
var pause_button: Button
var resume_button: Button
var restart_button: Button
var paused := false
var start_overlay: ColorRect
var settings_overlay: ColorRect
var settings_return_to_start := false
var quality_label: Label
var sensitivity_label: Label
var quality_high := false
var look_sensitivity := 0.004

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	_build_pause_button()
	_build_overlay()
	_build_settings_overlay()
	_build_start_menu()
	get_viewport().size_changed.connect(_layout_all_ui)
	_layout_all_ui()
	pause_button.visible = false
	start_overlay.visible = true
	overlay.visible = false
	settings_overlay.visible = false
	get_tree().paused = true

func _input(event: InputEvent) -> void:
	# Android touch fallback: route taps directly to visible menu buttons.
	# This avoids relying on mouse emulation when the SceneTree is paused.
	if event is InputEventScreenTouch and event.pressed:
		var touch_position: Vector2 = event.position
		var handled := _dispatch_menu_touch(touch_position)
		if handled:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if settings_overlay.visible:
			_close_settings()
		elif start_overlay.visible:
			return
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()

func _dispatch_menu_touch(touch_position: Vector2) -> bool:
	var buttons := get_tree().get_nodes_in_group("frontline_menu_buttons")
	# Check topmost buttons first.
	buttons.reverse()
	for item in buttons:
		if not item is Button:
			continue
		var button := item as Button
		if not button.is_visible_in_tree() or button.disabled:
			continue
		if button.get_global_rect().has_point(touch_position):
			button.emit_signal("pressed")
			return true
	return false

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
	var view_size := get_viewport_rect().size
	pause_button.position = Vector2(view_size.x - 72.0, 178.0)
	pause_button.size = Vector2(54.0, 48.0)

func _layout_all_ui() -> void:
	_layout_pause_button()
	for item in get_tree().get_nodes_in_group("frontline_menu_panels"):
		if item is Control and is_instance_valid(item):
			var menu_panel := item as Control
			menu_panel.position = (get_viewport_rect().size - menu_panel.size) * 0.5

func _make_overlay(name: String) -> ColorRect:
	var layer := ColorRect.new()
	layer.name = name
	layer.color = Color(0.015, 0.025, 0.035, 0.88)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.z_index = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	return layer

func _make_panel(parent: Control, size: Vector2) -> PanelContainer:
	var result := PanelContainer.new()
	result.custom_minimum_size = size
	result.size = size
	result.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	result.position = (get_viewport_rect().size - size) * 0.5
	result.process_mode = Node.PROCESS_MODE_ALWAYS
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	result.z_index = 20
	result.add_to_group("frontline_menu_panels")
	parent.add_child(result)
	return result

func _make_column(parent: Control, separation: int = 12) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	return column

func _make_title(parent: Control, value: String, font_size: int = 30) -> void:
	var title := Label.new()
	title.text = value
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_color_override("font_color", Color(0.82, 0.94, 0.76))
	parent.add_child(title)

func _make_action(parent: Control, value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(250, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_to_group("frontline_menu_buttons")
	button.pressed.connect(callback)
	parent.add_child(button)
	_style_button(button, Color(0.10, 0.20, 0.15, 1.0))
	return button

func _build_start_menu() -> void:
	start_overlay = _make_overlay("StartMenuOverlay")
	var start_panel := _make_panel(start_overlay, Vector2(350, 340))
	var column := _make_column(start_panel, 15)
	_make_title(column, "FRONTLINE", 38)
	_make_title(column, "OFFLINE SURVIVAL", 17)
	_make_action(column, "PLAY", _start_game)
	_make_action(column, "SETTINGS", _open_settings_from_start)
	_make_action(column, "EXIT", _exit_game)
	var note := Label.new()
	note.text = "Explore • Survive • Win"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)

func _build_overlay() -> void:
	overlay = _make_overlay("PauseOverlay")
	overlay.visible = false
	panel = _make_panel(overlay, Vector2(330, 310))
	var column := _make_column(panel, 13)
	_make_title(column, "PAUSED")
	resume_button = _make_action(column, "RESUME", _resume)
	restart_button = _make_action(column, "RESTART MATCH", _restart)
	_make_action(column, "SETTINGS", _open_settings_from_pause)
	_make_action(column, "MAIN MENU", _return_to_main_menu)

func _build_settings_overlay() -> void:
	settings_overlay = _make_overlay("SettingsOverlay")
	settings_overlay.visible = false
	var settings_panel := _make_panel(settings_overlay, Vector2(360, 360))
	var column := _make_column(settings_panel, 13)
	_make_title(column, "GAME SETTINGS", 28)
	quality_label = Label.new()
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(quality_label)
	_make_action(column, "GRAPHICS: LOW / HIGH", _toggle_quality)
	sensitivity_label = Label.new()
	sensitivity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(sensitivity_label)
	var slider := HSlider.new()
	slider.min_value = 0.002
	slider.max_value = 0.008
	slider.step = 0.0005
	slider.value = look_sensitivity
	slider.custom_minimum_size = Vector2(260, 32)
	slider.value_changed.connect(_set_sensitivity)
	column.add_child(slider)
	_make_action(column, "BACK", _close_settings)
	_update_settings_labels()

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
	button.add_theme_font_size_override("font_size", 19)

func _start_game() -> void:
	start_overlay.visible = false
	pause_button.visible = true
	paused = false
	get_tree().paused = false

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

func _resume() -> void:
	paused = false
	get_tree().paused = false
	overlay.visible = false
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pause game"

func _open_settings_from_start() -> void:
	settings_return_to_start = true
	settings_overlay.visible = true
	start_overlay.visible = false

func _open_settings_from_pause() -> void:
	settings_return_to_start = false
	settings_overlay.visible = true
	overlay.visible = false

func _close_settings() -> void:
	settings_overlay.visible = false
	if settings_return_to_start:
		start_overlay.visible = true
	else:
		overlay.visible = true

func _toggle_quality() -> void:
	quality_high = not quality_high
	var main := get_tree().current_scene
	if main != null and main.has_method("apply_graphics_preset"):
		main.apply_graphics_preset(quality_high)
	_update_settings_labels()

func _set_sensitivity(value: float) -> void:
	look_sensitivity = value
	var camera_pivot := get_tree().current_scene.get_node_or_null("Player/CameraPivot") if get_tree().current_scene != null else null
	if camera_pivot != null:
		camera_pivot.set("touch_sensitivity", value)
		camera_pivot.set("mouse_sensitivity", value * 0.625)
	_update_settings_labels()

func _update_settings_labels() -> void:
	if is_instance_valid(quality_label):
		quality_label.text = "Graphics quality: " + ("HIGH" if quality_high else "LOW")
	if is_instance_valid(sensitivity_label):
		sensitivity_label.text = "Camera sensitivity: %.4f" % look_sensitivity

func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _exit_game() -> void:
	get_tree().quit()
