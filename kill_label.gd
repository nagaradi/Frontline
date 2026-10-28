
extends Label

func _ready() -> void:
	text = "KILLS: 0"

func _process(_delta: float) -> void:
	var manager = get_node_or_null("../../GameManager")

	if manager != null:
		text = "KILLS: %d" % manager.kills
