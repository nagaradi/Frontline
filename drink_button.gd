
extends Button

func _ready() -> void:
	text = "DRINK"
	pressed.connect(func():
		var player = get_node_or_null("../../Player")
		if player != null:
			player.use_drink()
	)
