
extends ProgressBar

func _ready() -> void:
	min_value = 0.0
	max_value = 100.0
	show_percentage = false
	update_health_bar()

func _process(_delta: float) -> void:
	update_health_bar()

func update_health_bar() -> void:
	var player = get_node_or_null("../../Player")

	if player == null:
		return

	max_value = player.max_health
	value = player.health

	var fill_style := StyleBoxFlat.new()

	if value <= 30.0:
		fill_style.bg_color = Color.RED
	else:
		fill_style.bg_color = Color.GREEN

	add_theme_stylebox_override("fill", fill_style)
