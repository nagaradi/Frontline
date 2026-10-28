
extends Button

func _ready() -> void:
	text = "FIRST AID"
	pressed.connect(func():
		var player = get_node_or_null("../../Player")
		if player != null:
			player.use_first_aid()
	)
