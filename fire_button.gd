extends Button
## Hold FIRE to keep shooting. The player's weapon cooldown controls the rate of fire.

@onready var player: CharacterBody3D = get_node_or_null("../../Player") as CharacterBody3D
var firing := false

func _ready() -> void:
	text = "FIRE"
	button_down.connect(_on_fire_down)
	button_up.connect(_on_fire_up)

func _process(_delta: float) -> void:
	if not firing:
		return
	if not is_instance_valid(player):
		player = get_node_or_null("../../Player") as CharacterBody3D
	if is_instance_valid(player) and player.has_method("shoot"):
		player.shoot()

func _on_fire_down() -> void:
	firing = true
	if is_instance_valid(player) and player.has_method("shoot"):
		player.shoot()
	else:
		push_warning("Frontline FIRE button: Player node not found.")

func _on_fire_up() -> void:
	firing = false

func _exit_tree() -> void:
	firing = false
