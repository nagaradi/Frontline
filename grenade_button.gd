
extends Button

func _ready() -> void:
	text = "GRENADE"
	pressed.connect(func():
		var player = get_node_or_null("../../Player")
		if player != null:
			player.throw_grenade()
	)
