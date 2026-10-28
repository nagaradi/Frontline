
extends Area3D

@export var ammo_amount: int = 30
var player_nearby: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("WEAPON PICKUP READY")

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_nearby = true
		print("PICKUP AVAILABLE - press E or Pickup button")

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_nearby = false

func _process(_delta: float) -> void:
	if player_nearby and Input.is_key_pressed(KEY_E):
		pickup_weapon()

func pickup_weapon() -> void:
	if not player_nearby:
		return

	var player = get_node_or_null("../Player")
	if player == null:
		return

	if player.has_method("pickup_ammo"):
		player.pickup_ammo(ammo_amount)
		print("PICKED UP AMMO: ", ammo_amount)
		queue_free()
