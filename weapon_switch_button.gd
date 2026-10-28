
extends Button

@onready var player = get_node_or_null("../../Player")

func _ready() -> void:
	text = "SWITCH"
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if player != null and player.has_method("switch_weapon"):
		player.switch_weapon()
