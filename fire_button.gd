extends Button
## Mobile-safe FIRE control. Resolves the player from the active scene and supports touch/mouse input.

var player: CharacterBody3D
var firing := false

func _ready() -> void:
	text = "FIRE"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	z_index = 10
	pressed.connect(_fire_once)
	button_down.connect(_on_fire_down)
	button_up.connect(_on_fire_up)
	gui_input.connect(_on_gui_input)
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

func _fire_once() -> void:
	if not is_instance_valid(player):
		_resolve_player()
	if is_instance_valid(player) and player.has_method("shoot"):
		player.shoot()
	else:
		push_warning("Frontline FIRE: Player node could not be found.")

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		firing = event.pressed
		if event.pressed:
			_fire_once()
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		firing = event.pressed
		if event.pressed:
			_fire_once()
			accept_event()

func _on_fire_down() -> void:
	firing = true
	_fire_once()

func _on_fire_up() -> void:
	firing = false

func _exit_tree() -> void:
	firing = false
