
extends ProgressBar

@onready var enemy = get_node_or_null("../../Enemy")

func _ready() -> void:
	min_value = 0
	max_value = 100
	value = 100

func _process(_delta: float) -> void:
	if not is_instance_valid(enemy):
		value = 0
		return

	value = enemy.health
