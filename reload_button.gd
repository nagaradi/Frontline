
extends Button

@onready var player = get_node_or_null("../../Player")

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if player != null:
		player.reload()
