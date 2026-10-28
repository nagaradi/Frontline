
extends Button

func _ready() -> void:
	text = "SMOKE"
	pressed.connect(func():
		var player = get_node_or_null("../../Player")
		if player != null:
			player.throw_smoke()
	)
