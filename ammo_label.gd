
extends Label

func _ready() -> void:
	add_theme_font_size_override("font_size", 24)
	update_ammo_text()


func _process(_delta: float) -> void:
	update_ammo_text()


func update_ammo_text() -> void:
	var player = get_node_or_null("../../Player")

	if player == null:
		text = "AMMO: --"
		return

	if player.reloading:
		text = "RELOADING..."
	else:
		text = "AMMO: %d / %d" % [
			player.ammo,
			player.reserve_ammo
		]
