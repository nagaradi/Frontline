extends Button
## Reliable touch/mouse fire control. Player is resolved through its group,
## so the button does not depend on a fragile scene-relative node path.

var player: CharacterBody3D
var firing := false
var retry_timer := 0.0

func _ready() -> void:
	text = "●"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	z_index = 100
	button_down.connect(_on_fire_down)
	button_up.connect(_on_fire_up)
	_resolve_player()
	pressed.connect(_on_pressed_fallback)

func _resolve_player() -> void:
	var players := get_tree().get_nodes_in_group("players")
	for candidate in players:
		if candidate is CharacterBody3D and is_instance_valid(candidate):
			player = candidate as CharacterBody3D
			return
	var scene := get_tree().current_scene
	if scene != null:
		player = scene.find_child("Player", true, false) as CharacterBody3D

func _process(delta: float) -> void:
	if not firing:
		return
	if not is_instance_valid(player):
		retry_timer -= delta
		if retry_timer <= 0.0:
			retry_timer = 0.25
			_resolve_player()
	if is_instance_valid(player) and player.has_method("shoot"):
		player.shoot()

func _on_fire_down() -> void:
	firing = true
	_resolve_player()
	if is_instance_valid(player):
		player.shoot()

func _on_pressed_fallback() -> void:
	# Covers devices that emit pressed without a reliable down signal.
	if not is_instance_valid(player):
		_resolve_player()
	if is_instance_valid(player):
		player.shoot()

func _on_fire_up() -> void:
	firing = false

func _exit_tree() -> void:
	firing = false
