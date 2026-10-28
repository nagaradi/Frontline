extends Label

func _ready() -> void:
    add_theme_font_size_override("font_size", 22)
    update_weapon_text()

func _process(_delta: float) -> void:
    update_weapon_text()

func update_weapon_text() -> void:
    var player = get_node_or_null("../../Player")
    if player == null:
        text = "WEAPON: --"
        return
    var index: int = player.weapon_index
    var weapon_name: String = player.weapon_names[index]
    var mag_size: int = player.magazine_sizes[index]
    text = "WEAPON: %s  |  MAG: %d" % [weapon_name, mag_size]
