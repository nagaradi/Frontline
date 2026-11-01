extends Button
## Mobile-safe FIRE control. Resolves the player from the active scene and supports touch/mouse input.

var player: CharacterBody3D
var firing := false

func _ready() -> void:
	text = "●"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	z_index = 50
	# Button's native down/up signals work for Android touch and mouse.
	button_down.connect(_on_fire_down)
	button_up.connect(_on_fire_up)
	_resolve_player()

func _resolve_player() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		player = scene.get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		player = get_node_or_null("../../Player") as CharacterBody3D

func _process(_delta: float) -> void:
	if not firing:
		return
	if not is_instance_valid(player):
		_resolve_player()
	if is_instance_valid(player) and player.has_method("shoot"):
		player.shoot()

func _on_fire_down() -> void:
	firing = true
	if not is_instance_valid(player):
		_resolve_player()
	if is_instance_valid(player) and player.has_method("shoot"):
		player.shoot()
	else:
		push_warning("Frontline FIRE: Player node could not be found.")

func _on_fire_up() -> void:
	firing = false

func _exit_tree() -> void:
	firing = false
