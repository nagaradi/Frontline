
extends CanvasLayer

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var kills_label: Label = $Panel/KillsLabel
@onready var restart_button: Button = $Panel/RestartButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = false

	title_label.text = "GAME OVER"
	title_label.visible = true
	title_label.position = Vector2(100, 150)
	title_label.add_theme_font_size_override("font_size", 48)

	kills_label.text = "KILLS: 0"
	kills_label.visible = true
	kills_label.position = Vector2(100, 230)
	kills_label.add_theme_font_size_override("font_size", 28)

	restart_button.text = "RESTART"
	restart_button.visible = true
	restart_button.position = Vector2(100, 300)
	restart_button.size = Vector2(220, 60)

	if not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)

func show_game_over(kills: int) -> void:
	panel.visible = true
	title_label.text = "GAME OVER"
	kills_label.text = "KILLS: %d" % kills
	print("GAME OVER KILLS: ", kills)
	restart_button.grab_focus()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
