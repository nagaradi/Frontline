extends Button

var aiming := false

func _ready() -> void:
	text = "AIM"
	pressed.connect(_on_aim_pressed)

func _on_aim_pressed() -> void:
	var player := get_node_or_null("../../Player")
	if player == null:
		return
	var spring := player.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	var camera := player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	if spring == null or camera == null:
		print("AIM: camera nodes not found")
		return
	aiming = not aiming
	spring.spring_length = 2.2 if aiming else 5.0
	camera.fov = 52.0 if aiming else 75.0
	if player.has_method("set_aiming"):
		player.set_aiming(aiming)
	text = "AIM ON" if aiming else "AIM"
	modulate = Color(1.0, 0.78, 0.35) if aiming else Color.WHITE
