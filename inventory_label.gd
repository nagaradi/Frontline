extends Label

func _ready() -> void:
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	update_inventory_text()

func _process(_delta: float) -> void:
	update_inventory_text()

func update_inventory_text() -> void:
	var player := get_node_or_null("../../Player")
	if player == null:
		text = "INVENTORY: --"
		return
	text = "ENERGY %d/100\nG %d  SM %d  DR %d  FA %d  MK %d" % [int(player.energy), player.grenades, player.smoke_grenades, player.energy_drinks, player.first_aid_kits, player.medkits]
